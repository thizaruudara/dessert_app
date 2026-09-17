import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/exam_countdown_model.dart';

class ExamCountdownService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _countdownsRef =>
      _firestore.collection('exam_countdowns');

  /// Streams all countdown configs sorted by exam year
  Stream<List<ExamCountdownConfig>> streamAllConfigs() {
    return _countdownsRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ExamCountdownConfig.fromFirestore(doc))
          .toList();

      // Sort by year extracted from examYear string (e.g. 2024, 2025, 2026...)
      list.sort((a, b) {
        final yearA = _extractYear(a.examYear);
        final yearB = _extractYear(b.examYear);
        return yearA.compareTo(yearB);
      });

      return list;
    });
  }

  /// Streams a single countdown config for a specific student's exam year
  Stream<ExamCountdownConfig?> streamConfigForYear(String examYear) {
    final docId = ExamCountdownConfig.normalizeDocId(examYear);
    return _countdownsRef.doc(docId).snapshots().map((doc) {
      if (doc.exists) {
        return ExamCountdownConfig.fromFirestore(doc);
      }
      return null;
    });
  }

  /// One-time fetch for a specific year
  Future<ExamCountdownConfig?> getConfigForYear(String examYear) async {
    try {
      final docId = ExamCountdownConfig.normalizeDocId(examYear);
      final doc = await _countdownsRef.doc(docId).get();
      if (doc.exists) {
        return ExamCountdownConfig.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error getting countdown config: $e');
    }
    return null;
  }

  /// Save or update a countdown config
  Future<void> saveConfig(ExamCountdownConfig config) async {
    final docId = config.id.isNotEmpty
        ? config.id
        : ExamCountdownConfig.normalizeDocId(config.examYear);

    await _countdownsRef.doc(docId).set(
          config.toMap(),
          SetOptions(merge: true),
        );
  }

  /// One-tap toggle whether students of this exam year can see the countdown
  Future<void> toggleVisibility(String examYear, bool isEnabled) async {
    final docId = ExamCountdownConfig.normalizeDocId(examYear);
    await _countdownsRef.doc(docId).set(
      {
        'examYear': examYear,
        'isEnabled': isEnabled,
        'updatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }

  /// Update the exact target exam date and time
  Future<void> updateTargetDateTime({
    required String examYear,
    required DateTime targetDate,
    String? customTitle,
  }) async {
    final docId = ExamCountdownConfig.normalizeDocId(examYear);
    final data = <String, dynamic>{
      'examYear': examYear,
      'targetDate': Timestamp.fromDate(targetDate),
      'updatedAt': Timestamp.now(),
    };
    if (customTitle != null) {
      data['customTitle'] = customTitle;
    }

    await _countdownsRef.doc(docId).set(data, SetOptions(merge: true));
  }

  /// Delete a batch configuration
  Future<void> deleteConfig(String docId) async {
    await _countdownsRef.doc(docId).delete();
  }

  /// Pre-populate standard A/L batches if no countdowns exist yet
  Future<void> seedDefaultConfigsIfEmpty() async {
    try {
      final snap = await _countdownsRef.limit(1).get();
      if (snap.docs.isEmpty) {
        final defaults = [
          ExamCountdownConfig(
            id: '2024_al',
            examYear: '2024 A/L',
            targetDate: DateTime(2024, 11, 25, 8, 30),
            isEnabled: false,
            customTitle: '2024 A/L Physics Final Exam',
          ),
          ExamCountdownConfig(
            id: '2025_al',
            examYear: '2025 A/L',
            targetDate: DateTime(2025, 11, 25, 8, 30),
            isEnabled: true,
            customTitle: '2025 A/L Physics Final Exam',
          ),
          ExamCountdownConfig(
            id: '2026_al',
            examYear: '2026 A/L',
            targetDate: DateTime(2026, 11, 25, 8, 30),
            isEnabled: true,
            customTitle: '2026 A/L Physics Final Exam',
          ),
          ExamCountdownConfig(
            id: '2027_al',
            examYear: '2027 A/L',
            targetDate: DateTime(2027, 11, 25, 8, 30),
            isEnabled: true,
            customTitle: '2027 A/L Physics Final Exam',
          ),
          ExamCountdownConfig(
            id: '2028_al',
            examYear: '2028 A/L',
            targetDate: DateTime(2028, 11, 25, 8, 30),
            isEnabled: true,
            customTitle: '2028 A/L Physics Final Exam',
          ),
        ];

        final batch = _firestore.batch();
        for (final item in defaults) {
          batch.set(_countdownsRef.doc(item.id), item.toMap());
        }
        await batch.commit();
        debugPrint('Successfully seeded default exam countdowns');
      }
    } catch (e) {
      debugPrint('Error seeding exam countdowns: $e');
    }
  }

  int _extractYear(String examYear) {
    final match = RegExp(r'\d{4}').firstMatch(examYear);
    return match != null ? int.parse(match.group(0)!) : 2027;
  }
}
