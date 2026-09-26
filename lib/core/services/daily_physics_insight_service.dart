import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_physics_insight_model.dart';

class DailyPhysicsInsightService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _insightDocRef =>
      _firestore.collection('system_config').doc('daily_physics_insight');

  /// Real-time stream of the physics insight configuration.
  Stream<DailyPhysicsInsightModel> streamInsight() {
    return _insightDocRef.snapshots().map((doc) {
      if (!doc.exists) {
        return DailyPhysicsInsightModel.defaultRandom();
      }
      return DailyPhysicsInsightModel.fromFirestore(doc);
    });
  }

  /// Get current insight configuration once.
  Future<DailyPhysicsInsightModel> getInsight() async {
    final doc = await _insightDocRef.get();
    if (!doc.exists) {
      return DailyPhysicsInsightModel.defaultRandom();
    }
    return DailyPhysicsInsightModel.fromFirestore(doc);
  }

  /// Reset to automatic random daily rotation.
  Future<void> setRandomDailyMode({String? adminName}) async {
    await _insightDocRef.set({
      'isCustom': false,
      'updatedAt': FieldValue.serverTimestamp(),
      if (adminName != null) 'updatedBy': adminName,
    }, SetOptions(merge: true));
  }

  /// Pin a custom concept crafted or selected by admin.
  Future<void> saveCustomInsight(
    DailyPhysicsInsightModel model, {
    String? adminName,
  }) async {
    final data = model.copyWith(
      isCustom: true,
      updatedBy: adminName,
    ).toFirestore();

    await _insightDocRef.set(data, SetOptions(merge: true));
  }
}
