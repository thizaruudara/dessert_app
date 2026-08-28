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

  UserModel? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

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

  /// Step 1 — send OTP
  Future<void> sendOtp(String phoneNumber) async {
    _setLoading(true);
    _error = null;
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _error = e.message ?? 'Verification failed';
          _setLoading(false);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _setLoading(false);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  /// Step 2 — verify OTP and login/register
  Future<bool> verifyOtp(String otp, {String? name}) async {
    if (_verificationId == null) {
      _error = 'No verification session. Please send OTP first.';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final result = await _auth.signInWithCredential(credential);
      final uid = result.user!.uid;
      final phone = result.user!.phoneNumber ?? '';

      // Check if user exists
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        // New user — create with student role by default
        final newUser = UserModel(
          uid: uid,
          name: name ?? 'Student',
          phone: phone,
          role: UserRole.student,
          credits: 0,
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(uid).set(newUser.toFirestore());
        _user = newUser;
      } else {
        _user = UserModel.fromFirestore(doc);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
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
