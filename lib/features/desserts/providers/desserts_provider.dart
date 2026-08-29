import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/dessert_model.dart';
import '../../../core/models/user_model.dart';

class DessertsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<DessertModel> _desserts = [];
  bool _loading = false;
  String? _error;

  List<DessertModel> get desserts => _desserts;
  bool get loading => _loading;
  String? get error => _error;

  List<DessertModel> get pendingDesserts =>
      _desserts.where((d) => d.isPending).toList();
  List<DessertModel> get reviewedDesserts =>
      _desserts.where((d) => !d.isPending).toList();

  /// Listen to all submissions (admin view)
  void listenToAllDesserts() {
    _db
        .collection('desserts')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .listen((snap) {
      _desserts = snap.docs.map(DessertModel.fromFirestore).toList();
      notifyListeners();
    });
  }

  /// Listen to a specific student's submissions (matches studentId or studentPhone)
  void listenToStudentDesserts(String studentId, {String? studentPhone}) {
    _loading = true;
    notifyListeners();

    final cleanPhone = (studentPhone ?? '').replaceAll(RegExp(r'\s+'), '');

    _db
        .collection('desserts')
        .snapshots()
        .listen((snap) {
      _desserts = snap.docs
          .map(DessertModel.fromFirestore)
          .where((d) =>
              d.studentId == studentId ||
              (cleanPhone.isNotEmpty &&
                  d.studentPhone.replaceAll(RegExp(r'\s+'), '') == cleanPhone))
          .toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      _loading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    });
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
