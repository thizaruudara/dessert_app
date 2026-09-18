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

  /// Streams a single countdown config for a specific student's exam year.
  /// Matches resiliently across document ID formats (e.g. '2027_al', '2027_a_l', '2027 A/L', or 4-digit year '2027').
  Stream<ExamCountdownConfig?> streamConfigForYear(String examYear) {
    final targetYear = _extractYear(examYear);
    final norm = ExamCountdownConfig.normalizeDocId(examYear);
    final clean = norm.replaceAll('_', '');

    return _countdownsRef.snapshots().map((snapshot) {
      ExamCountdownConfig? bestMatch;

      for (final doc in snapshot.docs) {
        final config = ExamCountdownConfig.fromFirestore(doc);
        bool matches = false;

        // 1. Direct ID or normalized ID match
        if (doc.id.toLowerCase() == norm ||
            ExamCountdownConfig.normalizeDocId(config.examYear) == norm) {
          matches = true;
        } else {
          // 2. Clean alphanumeric match (e.g., '2027al' == '2027al')
          final cfgClean = ExamCountdownConfig.normalizeDocId(config.examYear).replaceAll('_', '');
          final docClean = doc.id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (cfgClean == clean || docClean == clean) {
            matches = true;
          } else if (_extractYear(config.examYear) == targetYear) {
            // 3. Extracted 4-digit year match (e.g. 2027 == 2027)
            matches = true;
          }
        }

        if (matches) {
          if (bestMatch == null) {
            bestMatch = config;
          } else {
            // If multiple matching configs exist, prefer the one with the latest update
            final bestTime = bestMatch.updatedAt ?? DateTime(2020);
            final currTime = config.updatedAt ?? DateTime(2020);
            if (currTime.isAfter(bestTime)) {
              bestMatch = config;
            }
          }
        }
      }
      return bestMatch;
    });
  }

  /// One-time fetch for a specific year with resilient matching
  Future<ExamCountdownConfig?> getConfigForYear(String examYear) async {
    try {
      final targetYear = _extractYear(examYear);
      final norm = ExamCountdownConfig.normalizeDocId(examYear);
      final clean = norm.replaceAll('_', '');

      final snapshot = await _countdownsRef.get();
      ExamCountdownConfig? bestMatch;

      for (final doc in snapshot.docs) {
        final config = ExamCountdownConfig.fromFirestore(doc);
        bool matches = false;

        if (doc.id.toLowerCase() == norm ||
            ExamCountdownConfig.normalizeDocId(config.examYear) == norm) {
          matches = true;
        } else {
          final cfgClean = ExamCountdownConfig.normalizeDocId(config.examYear).replaceAll('_', '');
          final docClean = doc.id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (cfgClean == clean || docClean == clean) {
            matches = true;
          } else if (_extractYear(config.examYear) == targetYear) {
            matches = true;
          }
        }

        if (matches) {
          if (bestMatch == null) {
            bestMatch = config;
          } else {
            final bestTime = bestMatch.updatedAt ?? DateTime(2020);
            final currTime = config.updatedAt ?? DateTime(2020);
            if (currTime.isAfter(bestTime)) {
              bestMatch = config;
            }
          }
        }
      }
      return bestMatch;
    } catch (e) {
      debugPrint('Error getting countdown config: $e');
    }
    return null;
  }

  /// Save or update a countdown config, reusing existing matching doc ID if present
  Future<void> saveConfig(ExamCountdownConfig config) async {
    String docId = config.id.isNotEmpty
        ? config.id
        : ExamCountdownConfig.normalizeDocId(config.examYear);

    try {
      final directDoc = await _countdownsRef.doc(docId).get();
      if (!directDoc.exists) {
        final targetYear = _extractYear(config.examYear);
        final snap = await _countdownsRef.get();
        for (final d in snap.docs) {
          if (_extractYear(d.data()['examYear']?.toString() ?? '') == targetYear) {
            docId = d.id;
            break;
          }
        }
      }
    } catch (_) {}

    await _countdownsRef.doc(docId).set(
          config.toMap(),
          SetOptions(merge: true),
        );
  }

  /// One-tap toggle whether students of this exam year can see the countdown
  Future<void> toggleVisibility(String idOrExamYear, bool isEnabled) async {
    String docId = idOrExamYear;
    try {
      final directDoc = await _countdownsRef.doc(docId).get();
      if (!directDoc.exists) {
        final targetYear = _extractYear(idOrExamYear);
        final snap = await _countdownsRef.get();
        for (final d in snap.docs) {
          if (_extractYear(d.data()['examYear']?.toString() ?? '') == targetYear ||
              _extractYear(d.id) == targetYear) {
            docId = d.id;
            break;
          }
        }
      }
    } catch (_) {}

    await _countdownsRef.doc(docId).set(
      {
        'isEnabled': isEnabled,
        'updatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }

  /// Update the exact target exam date and time
  Future<void> updateTargetDateTime({
    required String idOrExamYear,
    required DateTime targetDate,
    String? customTitle,
  }) async {
    String docId = idOrExamYear;
    try {
      final directDoc = await _countdownsRef.doc(docId).get();
      if (!directDoc.exists) {
        final targetYear = _extractYear(idOrExamYear);
        final snap = await _countdownsRef.get();
        for (final d in snap.docs) {
          if (_extractYear(d.data()['examYear']?.toString() ?? '') == targetYear ||
              _extractYear(d.id) == targetYear) {
            docId = d.id;
            break;
          }
        }
      }
    } catch (_) {}

    final data = <String, dynamic>{
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
    try {
      final directDoc = await _countdownsRef.doc(docId).get();
      if (directDoc.exists) {
        await _countdownsRef.doc(docId).delete();
        return;
      }
      final targetYear = _extractYear(docId);
      final snap = await _countdownsRef.get();
      for (final d in snap.docs) {
        if (_extractYear(d.data()['examYear']?.toString() ?? '') == targetYear ||
            _extractYear(d.id) == targetYear) {
          await _countdownsRef.doc(d.id).delete();
          break;
        }
      }
    } catch (e) {
      debugPrint('Error deleting config: $e');
    }
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
