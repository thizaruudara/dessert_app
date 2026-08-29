import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      notifyListeners();
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
  Future<bool> sendOtp(String phoneNumber, {String? name}) async {
    _setLoading(true);
    _error = null;
    _currentPhone = phoneNumber;
    _currentName = name;

    try {
      // 1. Submit WhatsApp OTP request to Firestore
      await _db.collection('otp_requests').add({
        'phone': phoneNumber,
        'name': name ?? 'Student',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // 2. Also trigger Firebase Phone Auth in background if available (test numbers)
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

  /// Step 2 — Verify OTP
  Future<bool> verifyOtp(String otp, {String? name, String? phone}) async {
    _setLoading(true);
    _error = null;
    final targetPhone = phone ?? _currentPhone ?? '';
    final targetName = name ?? _currentName ?? 'Student';

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
      final userQuery = await _db.collection('users').where('phone', '==', targetPhone).limit(1).get();

      if (userQuery.docs.isNotEmpty) {
        _user = UserModel.fromFirestore(userQuery.docs.first);
      } else {
        final docRef = _db.collection('users').doc(uid);
        final doc = await docRef.get();
        if (doc.exists) {
          _user = UserModel.fromFirestore(doc);
        } else {
          // Create new student profile
          final newUser = UserModel(
            uid: uid,
            name: targetName,
            phone: targetPhone,
            role: UserRole.student,
            credits: 0,
            createdAt: DateTime.now(),
          );
          await docRef.set(newUser.toFirestore());
          _user = newUser;
        }
      }

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
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_auth.currentUser != null) {
      await _fetchUser(_auth.currentUser!.uid);
    }
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }
}
