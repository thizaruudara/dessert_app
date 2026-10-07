import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/backend_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserModel? _user;
  bool _isAdmin = false;
  bool _loading = true;
  bool _authInitialized = false;
  final Completer<void> _initialAuthReady = Completer<void>();
  StreamSubscription<User?>? _authSubscription;
  String? _error;
  String? _currentPhone;
  String? _currentName;
  String? _currentExamYear;

  UserModel? get user => _user;
  UserModel? get userModel => _user;
  bool get loading => _loading;
  bool get authInitialized => _authInitialized;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _isAdmin;
  String? get currentPhone => _currentPhone;
  String? get currentName => _currentName;
  String? get currentExamYear => _currentExamYear;

  AuthProvider() {
    _initAuth();
  }

  Future<void> get initialAuthReady => _initialAuthReady.future;

  Future<void> _initAuth() async {
    // Identity is restored exclusively by Firebase Auth. A local UID or phone
    // value is never treated as proof of identity.
    _authSubscription = _auth.authStateChanges().listen(
      _onAuthStateChanged,
      onError: (Object error) {
        _error = error.toString();
        _loading = false;
        _finishInitialAuth();
      },
    );
  }

  String _normalizedPhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = '94${digits.substring(1)}';
    if (digits.length == 9) digits = '94$digits';
    return digits;
  }

  String _authEmail(String phone) => 'p${_normalizedPhone(phone)}@users.edupeak.app';

  Future<void> _ensureProfile({required String name, required String phone, required String examYear}) async {
    await BackendApiService.post('auth/ensure-profile', {
      'name': name,
      'phone': '+${_normalizedPhone(phone)}',
      'examYear': examYear,
    });
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Authentication expired. Sign in again.');
    await _fetchUser(uid);
    if (_user == null) throw StateError('Account profile could not be loaded.');
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null || firebaseUser.isAnonymous) {
      if (firebaseUser?.isAnonymous == true) await _auth.signOut();
      _user = null;
      _isAdmin = false;
      _loading = false;
      _finishInitialAuth();
      notifyListeners();
      return;
    }
    await _fetchUser(firebaseUser.uid);
    if (!_authInitialized) {
      _loading = false;
      _finishInitialAuth();
    }
    notifyListeners();
  }

  void _finishInitialAuth() {
    if (_authInitialized) return;
    _authInitialized = true;
    if (!_initialAuthReady.isCompleted) _initialAuthReady.complete();
    notifyListeners();
  }

  Future<void> _fetchUser(String uid) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        doc = await _db
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Fetch user server timeout on Wi-Fi, trying cache: $e');
        try {
          doc = await _db
              .collection('users')
              .doc(uid)
              .get(const GetOptions(source: Source.cache));
        } catch (_) {}
      }

      if (doc != null && doc.exists) {
        // Use the restored token on startup. Login explicitly refreshes claims
        // after ensure-admin, so forcing a network refresh here only delays
        // session restoration on every cold launch.
        final claims = await _auth.currentUser?.getIdTokenResult();
        _isAdmin = claims?.claims?['admin'] == true;
        final profile = UserModel.fromFirestore(doc);
        _user = profile.copyWith(role: _isAdmin ? UserRole.admin : UserRole.student);
      } else {
        _user = null;
        _isAdmin = false;
      }
    } catch (e) {
      _error = e.toString();
      _isAdmin = false;
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

    UserCredential? createdCredential;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: _authEmail(phone), password: password);
      createdCredential = credential;
      await credential.user?.updateDisplayName(name.trim());
      await _ensureProfile(name: name.trim(), phone: phone, examYear: examYear);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      try {
        await createdCredential?.user?.delete();
        await _auth.signOut();
      } catch (_) {}
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
      UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(email: _authEmail(phone), password: password);
      } on FirebaseAuthException catch (error) {
        if (!['user-not-found', 'invalid-credential', 'invalid-login-credentials', 'wrong-password'].contains(error.code)) rethrow;
        final result = await BackendApiService.post('auth/upgrade-legacy', {
          'phone': '+${_normalizedPhone(phone)}',
          'password': password,
        }, authenticated: false);
        credential = await _auth.signInWithCustomToken(result['token'] as String);
      }
      final uid = credential.user?.uid;
      if (uid == null) throw StateError('Sign in did not return an authenticated user.');
      await BackendApiService.post('auth/ensure-admin', {
        'phone': '+${_normalizedPhone(phone)}',
      });
      await credential.user?.getIdToken(true);
      await _fetchUser(uid);
      if (_user == null) throw StateError('Account profile is unavailable. Contact the institute administrator.');
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
  // Legacy chat-issued codes used a publicly writable Firestore collection.
  // They are disabled; sign-in uses Firebase Authentication only.
  Future<String> prepareWhatsAppLoginOtp(String phoneNumber) async => '';

  Future<bool> sendOtp(String phoneNumber, {String? name, String? examYear}) async {
    _error = 'One-time-code login is temporarily disabled during the account security upgrade. Sign in with your password.';
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>> requestTelegramOtp(String phone, {String? name}) async => {
    'success': false,
    'mode': 'disabled',
    'message': 'Use Firebase Authentication sign-in instead.',
  };

  Future<bool> verifyOtp(String otp, {String? name, String? phone, String? examYear}) async {
    _error = 'One-time-code login is disabled. Use your password to sign in.';
    notifyListeners();
    return false;
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
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
