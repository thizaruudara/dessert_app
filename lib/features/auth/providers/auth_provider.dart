import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  String? _currentExamYear;

  UserModel? get user => _user;
  UserModel? get userModel => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get currentPhone => _currentPhone;
  String? get currentName => _currentName;
  String? get currentExamYear => _currentExamYear;

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
          var u = UserModel.fromFirestore(q.docs.first);
          if (isPhoneAdmin(u.phone) && !u.isAdmin) {
            u = u.copyWith(role: UserRole.admin);
            q.docs.first.reference.update({'role': 'admin'}).catchError((_) {});
          }
          _user = u;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error restoring saved session: $e');
    }
  }

  static bool isPhoneAdmin(String? phone) {
    if (phone == null) return false;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.contains('770557769') ||
        digits.contains('707938883') ||
        digits.contains('701068489') ||
        digits.endsWith('770557769') ||
        digits.endsWith('707938883') ||
        digits.endsWith('701068489');
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
        var u = UserModel.fromFirestore(doc);
        if (isPhoneAdmin(u.phone) && !u.isAdmin) {
          u = u.copyWith(role: UserRole.admin);
          doc.reference.update({'role': 'admin'}).catchError((_) {});
        }
        _user = u;
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// ── 1. Register with Password (Instant, No OTP required!) ────────────────
  Future<bool> registerWithPassword({
    required String name,
    required String phone,
    required String password,
    required String examYear,
  }) async {
    _setLoading(true);
    _error = null;
    _currentPhone = phone;
    _currentName = name;
    _currentExamYear = examYear;

    try {
      // 1. Check if user already exists
      final existing = await _db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
      if (existing.docs.isNotEmpty) {
        // User already exists, check if has password
        final existingData = existing.docs.first.data();
        if (existingData['password'] != null && existingData['password'].toString().isNotEmpty) {
          _error = 'An account already exists with this phone number. Please sign in.';
          _setLoading(false);
          notifyListeners();
          return false;
        }
      }

      // 2. Sign in anonymously to Firebase Auth for security rules if not signed in
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        try {
          final anonResult = await _auth.signInAnonymously();
          currentUser = anonResult.user;
        } catch (_) {}
      }

      final uid = currentUser?.uid ?? phone.replaceAll(RegExp(r'\D'), '');
      final isTargetAdmin = isPhoneAdmin(phone);

      if (existing.docs.isNotEmpty) {
        // Update existing record with password & details
        final docRef = existing.docs.first.reference;
        await docRef.update({
          'name': name,
          'password': password,
          'examYear': examYear,
          'role': isTargetAdmin ? 'admin' : (existing.docs.first.data()['role'] ?? 'student'),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final updatedDoc = await docRef.get();
        _user = UserModel.fromFirestore(updatedDoc);
      } else {
        // Create new user profile document
        final newDocRef = _db.collection('users').doc(uid);
        final newUser = UserModel(
          uid: uid,
          name: name,
          phone: phone,
          role: isTargetAdmin ? UserRole.admin : UserRole.student,
          credits: 0,
          examYear: examYear,
          password: password,
          createdAt: DateTime.now(),
        );

        await newDocRef.set(newUser.toFirestore());
        _user = newUser;
      }

      // 3. Persist session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_uid', _user!.uid);
      await prefs.setString('saved_phone', phone);

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// ── 2. Login with Password (Instant 1-second sign-in) ──────────────────────
  Future<bool> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    _currentPhone = phone;

    try {
      // 1. Query user by phone
      final userQuery = await _db.collection('users').where('phone', isEqualTo: phone).limit(1).get();

      if (userQuery.docs.isEmpty) {
        // If it's the designated admin phone, auto-create
        if (isPhoneAdmin(phone)) {
          return await registerWithPassword(
            name: 'Teacher / Admin',
            phone: phone,
            password: password,
            examYear: '2025 A/L',
          );
        }

        _error = 'No account found with this phone number. Please register first.';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final doc = userQuery.docs.first;
      final data = doc.data();
      final storedPassword = data['password']?.toString();

      // Check matching password
      final isMatch = storedPassword != null && storedPassword == password;

      if (!isMatch) {
        _error = 'Incorrect password. You can also log in via WhatsApp OTP below.';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // Sign in anonymously if needed
      if (_auth.currentUser == null) {
        try {
          await _auth.signInAnonymously();
        } catch (_) {}
      }

      var u = UserModel.fromFirestore(doc);
      if (isPhoneAdmin(phone) && !u.isAdmin) {
        u = u.copyWith(role: UserRole.admin);
        doc.reference.update({'role': 'admin'}).catchError((_) {});
      }
      _user = u;

      // Persist session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_uid', _user!.uid);
      await prefs.setString('saved_phone', phone);

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// ── 3. Generate & Save WhatsApp OTP for Chat-Based Login ─────────────────
  Future<String> prepareWhatsAppLoginOtp(String phoneNumber) async {
    _currentPhone = phoneNumber;
    final rng = Random.secure();
    final randomOtp = (100000 + rng.nextInt(900000)).toString();
    final expiresAt = DateTime.now().millisecondsSinceEpoch + 10 * 60 * 1000;

    try {
      await _db.collection('otp_verifications').doc(phoneNumber).set({
        'otp': randomOtp,
        'phone': phoneNumber,
        'name': _currentName ?? 'Student',
        'expiresAt': expiresAt,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error writing WhatsApp OTP doc: $e');
    }

    return randomOtp;
  }

  /// Step 1 — Send OTP (via WhatsApp + Direct Webhook)
  Future<bool> sendOtp(String phoneNumber, {String? name, String? examYear}) async {
    _setLoading(true);
    _error = null;
    _currentPhone = phoneNumber;
    _currentName = name;
    _currentExamYear = examYear;

    try {
      // 1. Submit WhatsApp OTP request to Firestore (with 3s timeout)
      try {
        await _db.collection('otp_requests').add({
          'phone': phoneNumber,
          'name': name ?? 'Student',
          'examYear': examYear,
          'requestedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Firestore OTP write notice: $e');
      }

      // 2. Trigger direct API call in background (fire-and-forget, non-blocking)
      _triggerDirectOtpAsync(phoneNumber, name ?? 'Student');

      // 3. Also trigger Firebase Phone Auth fallback in background
      try {
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
          timeout: const Duration(seconds: 30),
        );
      } catch (_) {}

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return true; // Still return true so user can navigate to OTP screen
    }
  }

  /// ── 4. Request Telegram OTP (Direct vs 1st-time Deep Link) ────────────────
  Future<Map<String, dynamic>> requestTelegramOtp(String phone, {String? name}) async {
    _currentPhone = phone;
    _currentName = name;
    final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse('https://edupeak-telegram-bot.vercel.app/api/send-otp'));
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(jsonEncode({
        'phone': cleanDigits,
        'name': name ?? 'Student',
      })));
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('Error calling send-otp API: $e');
      return {
        'success': true,
        'mode': 'deep_link',
        'deepLink': 'https://t.me/edupeakbot?start=otp_$cleanDigits',
      };
    }
  }

  void _triggerDirectOtpAsync(String phone, String name) {
    Future.microtask(() async {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        final req = await client.postUrl(Uri.parse('https://edupeak-telegram-bot.vercel.app/api/send-otp'));
        req.headers.set('Content-Type', 'application/json');
        req.add(utf8.encode(jsonEncode({
          'phone': phone.replaceAll(RegExp(r'\D'), ''),
          'name': name,
        })));
        final res = await req.close().timeout(const Duration(seconds: 6));
        debugPrint('📲 Direct OTP API Response: ${res.statusCode}');
        client.close();
      } catch (httpErr) {
        debugPrint('Direct OTP HTTP notice: $httpErr');
      }
    });
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

      // 2. Fallback to Firebase Phone Auth verificationId
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

      final bool isTargetAdmin = isPhoneAdmin(targetPhone);

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
        if (isTargetAdmin && existingDoc.data()['role'] != 'admin') {
          updates['role'] = 'admin';
        }
        if (updates.isNotEmpty) {
          await existingDoc.reference.update(updates);
        }
        final updatedDoc = await existingDoc.reference.get();
        var u = UserModel.fromFirestore(updatedDoc);
        if (isTargetAdmin && !u.isAdmin) {
          u = u.copyWith(role: UserRole.admin);
        }
        _user = u;
      } else {
        final docRef = _db.collection('users').doc(uid);
        final doc = await docRef.get();
        if (doc.exists) {
          var u = UserModel.fromFirestore(doc);
          if (isTargetAdmin && !u.isAdmin) {
            u = u.copyWith(role: UserRole.admin);
            doc.reference.update({'role': 'admin'}).catchError((_) {});
          }
          _user = u;
        } else {
          // Create new user profile
          final newUser = UserModel(
            uid: uid,
            name: targetName.isNotEmpty ? targetName : (isTargetAdmin ? 'Teacher Admin' : 'Student'),
            phone: targetPhone,
            role: isTargetAdmin ? UserRole.admin : UserRole.student,
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
