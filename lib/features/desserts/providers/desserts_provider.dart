import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/dessert_model.dart';
import '../../../core/models/user_model.dart';

class DessertsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<DessertModel> _desserts = [];
  bool _loading = false;
  String? _error;
  StreamSubscription? _dessertSub;
  String? _activeStudentId;

  List<DessertModel> get desserts => _desserts;
  bool get loading => _loading;
  String? get error => _error;

  List<DessertModel> get pendingDesserts =>
      _desserts.where((d) => d.isPending).toList();
  List<DessertModel> get reviewedDesserts =>
      _desserts.where((d) => !d.isPending).toList();

  @override
  void dispose() {
    _dessertSub?.cancel();
    super.dispose();
  }

  /// Listen to all submissions (admin view)
  void listenToAllDesserts() {
    _dessertSub?.cancel();
    _loading = true;
    notifyListeners();

    _dessertSub = _db
        .collection('desserts')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .listen((snap) {
      _desserts = snap.docs.map(DessertModel.fromFirestore).toList();
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to all desserts: $e');
      _error = e.toString();
      _loading = false;
      notifyListeners();
    });
  }

  /// Listen to a specific student's submissions (matches studentId or phone number)
  void listenToStudentDesserts(String studentId, {String? studentPhone}) {
    if (_activeStudentId == studentId && _desserts.isNotEmpty) {
      return; // Already actively listening and data loaded
    }
    _activeStudentId = studentId;
    _dessertSub?.cancel();
    _loading = true;
    notifyListeners();

    final rawPhone = (studentPhone ?? '').replaceAll(RegExp(r'\D'), '');
    final last7 = rawPhone.length >= 7 ? rawPhone.substring(rawPhone.length - 7) : rawPhone;

    bool matchesStudent(DessertModel d) {
      if (d.studentId == studentId) return true;
      if (last7.isNotEmpty) {
        final dPhone = d.studentPhone.replaceAll(RegExp(r'\D'), '');
        if (dPhone.isNotEmpty && (dPhone.contains(last7) || dPhone.endsWith(rawPhone) || rawPhone.endsWith(dPhone))) {
          return true;
        }
      }
      return false;
    }

    // 1. Instant one-time get with timeout & cache fallback for zero-delay initial load on VPN / Wi-Fi
    _db
        .collection('desserts')
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => _db.collection('desserts').get(const GetOptions(source: Source.cache)),
        )
        .then((snap) {
      _desserts = snap.docs
          .map(DessertModel.fromFirestore)
          .where(matchesStudent)
          .toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      _loading = false;
      _error = null;
      notifyListeners();
    }).catchError((e) {
      debugPrint('One-time desserts get error: $e');
      _loading = false;
      notifyListeners();
    });

    // 2. Real-time stream for live updates
    _dessertSub = _db.collection('desserts').snapshots().listen((snap) {
      _desserts = snap.docs
          .map(DessertModel.fromFirestore)
          .where(matchesStudent)
          .toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Desserts stream error: $e');
      _loading = false;
      _error = e.toString();
      notifyListeners();
    });
  }

  /// Manual refresh
  Future<void> refreshStudentDesserts(String studentId, {String? studentPhone}) async {
    final rawPhone = (studentPhone ?? '').replaceAll(RegExp(r'\D'), '');
    final last7 = rawPhone.length >= 7 ? rawPhone.substring(rawPhone.length - 7) : rawPhone;

    try {
      final snap = await _db
          .collection('desserts')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => _db.collection('desserts').get(const GetOptions(source: Source.cache)),
          );
      _desserts = snap.docs
          .map(DessertModel.fromFirestore)
          .where((d) {
            if (d.studentId == studentId) return true;
            if (last7.isNotEmpty) {
              final dPhone = d.studentPhone.replaceAll(RegExp(r'\D'), '');
              return dPhone.contains(last7) || dPhone.endsWith(rawPhone) || rawPhone.endsWith(dPhone);
            }
            return false;
          })
          .toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  /// Admin: approve a dessert and award credits
  Future<void> approveDessert({
    required DessertModel dessert,
    required UserModel admin,
    required int credits,
    String? feedback,
  }) async {
    _setLoading(true);
    try {
      final batch = _db.batch();

      // Update dessert
      batch.update(_db.collection('desserts').doc(dessert.id), {
        'status': 'approved',
        'adminFeedback': feedback ?? 'Great work! ✅',
        'reviewedBy': admin.uid,
        'creditsAwarded': credits,
        'reviewedAt': Timestamp.now(),
      });

      // Increment student's credits
      batch.update(_db.collection('users').doc(dessert.studentId), {
        'credits': FieldValue.increment(credits),
      });

      await batch.commit();
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  /// Admin: reject a dessert
  Future<void> rejectDessert({
    required DessertModel dessert,
    required UserModel admin,
    String? feedback,
  }) async {
    _setLoading(true);
    try {
      await _db.collection('desserts').doc(dessert.id).update({
        'status': 'rejected',
        'adminFeedback': feedback ?? 'Needs improvement ❌',
        'reviewedBy': admin.uid,
        'creditsAwarded': 0,
        'reviewedAt': Timestamp.now(),
      });
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }
}
