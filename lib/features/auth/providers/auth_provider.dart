import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserModel? _user;
  bool _loading = false;
  String? _error;
  String? _verificationId;
  String? _currentPhone;
  String? _currentName;

  UserModel? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get currentPhone => _currentPhone;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    // 1. Try loading saved session from SharedPreferences
    await _loadPersistedSession();

    // 2. Also listen to Firebase Auth state
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _loadPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString('saved_uid');
      final savedPhone = prefs.getString('saved_phone');

      if (savedUid != null && savedUid.isNotEmpty) {
        await _fetchUser(savedUid);
      }

      if (_user == null && savedPhone != null && savedPhone.isNotEmpty) {
        final q = await _db.collection('users').where('phone', isEqualTo: savedPhone).limit(1).get();
        if (q.docs.isNotEmpty) {
          _user = UserModel.fromFirestore(q.docs.first);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error restoring saved session: $e');
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      // If we already loaded a session from SharedPreferences, keep it
      if (_user == null) {
        notifyListeners();
      }
      return;
    }
    await _fetchUser(firebaseUser.uid);
  }

  Future<void> _fetchUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Step 1 — Send OTP (via WhatsApp + Firebase Phone Auth)
  Future<bool> sendOtp(String phoneNumber, {String? name, String? examYear}) async {
    _setLoading(true);
    _error = null;
    _currentPhone = phoneNumber;
    _currentName = name;
    _currentExamYear = examYear;

    try {
      // 1. Submit WhatsApp OTP request to Firestore
      await _db.collection('otp_requests').add({
        'phone': phoneNumber,
        'name': name ?? 'Student',
        'examYear': examYear,
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // 2. Also trigger direct API call to wake up Render & send OTP instantly
      try {
        final client = HttpClient();
        final req = await client.postUrl(Uri.parse('https://edupeak-webhook.onrender.com/api/send-otp'));
        req.headers.set('Content-Type', 'application/json');
        req.add(utf8.encode(jsonEncode({
          'phone': phoneNumber,
          'name': name ?? 'Student',
        })));
        final res = await req.close();
        debugPrint('📲 Direct OTP API Response: ${res.statusCode}');
        client.close();
      } catch (httpErr) {
        debugPrint('Direct OTP HTTP notice: $httpErr');
      }

      // 3. Also trigger Firebase Phone Auth in background if available (test numbers)
      _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Firebase phone auth fallback notice: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Step 2 — Verify OTP and persist session
  Future<bool> verifyOtp(String otp, {String? name, String? phone, String? examYear}) async {
    _setLoading(true);
    _error = null;
    final targetPhone = phone ?? _currentPhone ?? '';
    final targetName = name ?? _currentName ?? '';
    final targetExamYear = examYear ?? _currentExamYear;

    try {
      bool isVerified = false;

      // 1. Check WhatsApp OTP verification document in Firestore
      if (targetPhone.isNotEmpty) {
        final doc = await _db.collection('otp_verifications').doc(targetPhone).get();
        if (doc.exists) {
          final data = doc.data()!;
          final storedOtp = data['otp']?.toString();
          final expiresAt = data['expiresAt'] as int? ?? 0;

          if (storedOtp == otp && DateTime.now().millisecondsSinceEpoch < expiresAt) {
            isVerified = true;
            // Clean up used OTP
            await _db.collection('otp_verifications').doc(targetPhone).delete();
          }
        }
      }

      // 2. Universal Master / Test code fallback
      if (otp == '123456') {
        isVerified = true;
      }

      // 3. Fallback to Firebase Phone Auth verificationId
      if (!isVerified && _verificationId != null) {
        try {
          final credential = PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: otp,
          );
          final result = await _auth.signInWithCredential(credential);
          if (result.user != null) isVerified = true;
        } catch (_) {}
      }

      if (!isVerified) {
        _error = 'Invalid or expired OTP code. Please check your WhatsApp.';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // Ensure user is signed in to Firebase Auth for Firestore rules
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        try {
          final anonResult = await _auth.signInAnonymously();
          currentUser = anonResult.user;
        } catch (e) {
          debugPrint('Anonymous auth fallback notice: $e');
        }
      }

      final uid = currentUser?.uid ?? targetPhone.replaceAll(RegExp(r'\D'), '');

      // Check or create user profile in Firestore
      final userQuery = await _db.collection('users').where('phone', isEqualTo: targetPhone).limit(1).get();

      if (userQuery.docs.isNotEmpty) {
        final existingDoc = userQuery.docs.first;
        final updates = <String, dynamic>{};
        if (targetName.isNotEmpty && (existingDoc.data()['name'] == null || existingDoc.data()['name'].toString().isEmpty || existingDoc.data()['name'].toString().startsWith('Student ('))) {
          updates['name'] = targetName;
        }
        if (targetExamYear != null && targetExamYear.isNotEmpty) {
          updates['examYear'] = targetExamYear;
        }
        if (updates.isNotEmpty) {
          await existingDoc.ref.update(updates);
        }
        final updatedDoc = await existingDoc.ref.get();
        _user = UserModel.fromFirestore(updatedDoc);
      } else {
        final docRef = _db.collection('users').doc(uid);
        final doc = await docRef.get();
        if (doc.exists) {
          _user = UserModel.fromFirestore(doc);
        } else {
          // Create new student profile
          final newUser = UserModel(
            uid: uid,
            name: targetName.isNotEmpty ? targetName : 'Student',
            phone: targetPhone,
            role: UserRole.student,
            credits: 0,
            examYear: targetExamYear,
            createdAt: DateTime.now(),
          );
          await docRef.set(newUser.toFirestore());
          _user = newUser;
        }
      }

      // Persist session to SharedPreferences so reopening the app stays logged in
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_uid', _user!.uid);
      await prefs.setString('saved_phone', targetPhone);

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Update Profile Picture (DP)
  Future<bool> updateProfilePhoto(String base64OrUrl) async {
    if (_user == null) return false;
    _setLoading(true);
    try {
      await _db.collection('users').doc(_user!.uid).update({
        'avatarUrl': base64OrUrl,
        'photoUrl': base64OrUrl,
      });

      _user = _user!.copyWith(avatarUrl: base64OrUrl);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Update Profile Name
  Future<bool> updateProfileName(String newName) async {
    if (_user == null || newName.trim().isEmpty) return false;
    _setLoading(true);
    try {
      await _db.collection('users').doc(_user!.uid).update({
        'name': newName.trim(),
      });

      _user = _user!.copyWith(name: newName.trim());
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_uid');
      await prefs.remove('saved_phone');
      await _auth.signOut();
    } catch (_) {}
    _user = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_user != null) {
      await _fetchUser(_user!.uid);
    }
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }
}
