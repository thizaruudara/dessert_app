import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Report containing statistics of deleted records across all collections
class StudentDeletionReport {
  final int submissionsDeleted;
  final int sprintAttemptsDeleted;
  final int registrationsDeleted;
  final int alertsDeleted;
  final int creditsHistoryDeleted;
  final int announcementsDeleted;
  final int totalDocumentsDeleted;
  final bool success;
  final String? error;

  const StudentDeletionReport({
    required this.submissionsDeleted,
    required this.sprintAttemptsDeleted,
    required this.registrationsDeleted,
    required this.alertsDeleted,
    required this.creditsHistoryDeleted,
    required this.announcementsDeleted,
    required this.totalDocumentsDeleted,
    required this.success,
    this.error,
  });
}

/// Service providing comprehensive cascade deletion of a student and all related data
class StudentManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Deletes a list of document references in safe batches (<= 400 per commit)
  static Future<int> _deleteBatchDocs(List<DocumentReference> docRefs) async {
    if (docRefs.isEmpty) return 0;
    int deleted = 0;
    const chunkSize = 400; // Under Firestore's 500-op batch limit
    for (int i = 0; i < docRefs.length; i += chunkSize) {
      final chunk = docRefs.sublist(
        i,
        i + chunkSize > docRefs.length ? docRefs.length : i + chunkSize,
      );
      final batch = _firestore.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
      deleted += chunk.length;
    }
    return deleted;
  }

  /// Performs a complete, cascade deletion of a student and ALL associated data:
  /// 1. Submissions & Homework (`desserts` and `submissions` collections)
  /// 2. Media files stored in Firebase Storage (submission photos, attachments)
  /// 3. Dessert reviews (`dessert_reviews` collection)
  /// 4. Daily MCQ Sprint attempts (`sprint_attempts` collection)
  /// 5. Live exam registrations (`paper_registrations` collection) & slot count adjustment
  /// 6. Live exam proctor alerts (`proctor_alerts` collection)
  /// 7. Credit transaction logs (`credits_history` collection)
  /// 8. Targeted announcements (`announcements` collection)
  /// 9. OTP requests & pending verifications (`otp_verifications`, `otp_requests`)
  /// 10. Subcollections under `users/{uid}` (e.g. notifications, history, etc.)
  /// 11. Profile picture in Firebase Storage (if custom uploaded)
  /// 12. Main student document in `users/{uid}`
  static Future<StudentDeletionReport> deleteStudentCascade(UserModel student) async {
    int totalSubsDeleted = 0;
    int totalSprintAttemptsDeleted = 0;
    int totalRegsDeleted = 0;
    int totalAlertsDeleted = 0;
    int totalCreditsHistoryDeleted = 0;
    int totalAnnouncementsDeleted = 0;
    int totalDocsDeleted = 0;

    try {
      final rawPhone = student.phone.trim();
      final cleanDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
      final Set<String> phoneVariants = {
        if (rawPhone.isNotEmpty) rawPhone,
        if (cleanDigits.isNotEmpty) cleanDigits,
        if (cleanDigits.isNotEmpty)
          cleanDigits.startsWith('94') ? '+$cleanDigits' : '+94$cleanDigits',
        if (cleanDigits.isNotEmpty)
          cleanDigits.startsWith('94')
              ? '0${cleanDigits.substring(2)}'
              : (cleanDigits.startsWith('0') ? cleanDigits : '0$cleanDigits'),
      };

      // ── 1. Clean Submissions (`desserts` collection) ───────────────────────
      final Map<String, DocumentSnapshot> dessertDocsMap = {};

      try {
        final snapByUid = await _firestore
            .collection('desserts')
            .where('studentId', isEqualTo: student.uid)
            .get();
        for (final doc in snapByUid.docs) {
          dessertDocsMap[doc.id] = doc;
        }
      } catch (e) {
        debugPrint('Notice querying desserts by uid: $e');
      }

      if (student.studentId != null && student.studentId!.isNotEmpty) {
        try {
          final snapByCustId = await _firestore
              .collection('desserts')
              .where('studentId', isEqualTo: student.studentId)
              .get();
          for (final doc in snapByCustId.docs) {
            dessertDocsMap[doc.id] = doc;
          }
        } catch (_) {}
      }

      for (final phone in phoneVariants) {
        try {
          final snapByPhone = await _firestore
              .collection('desserts')
              .where('studentPhone', isEqualTo: phone)
              .get();
          for (final doc in snapByPhone.docs) {
            dessertDocsMap[doc.id] = doc;
          }
        } catch (_) {}
      }

      final List<String> collectedDessertIds = dessertDocsMap.keys.toList();

      // Delete media files from Firebase Storage for each dessert
      for (final doc in dessertDocsMap.values) {
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final mediaList = data['mediaUrls'];
          if (mediaList is List) {
            for (final url in mediaList) {
              final strUrl = url.toString();
              if (strUrl.contains('firebasestorage.googleapis.com')) {
                _storage.refFromURL(strUrl).delete().catchError((_) {});
              }
            }
          }
          final singleUrl = data['fileUrl']?.toString();
          if (singleUrl != null && singleUrl.contains('firebasestorage.googleapis.com')) {
            _storage.refFromURL(singleUrl).delete().catchError((_) {});
          }
        } catch (e) {
          debugPrint('Notice deleting dessert storage media: $e');
        }
      }

      // Delete dessert documents from Firestore
      final dessertRefs = dessertDocsMap.values.map((d) => d.reference).toList();
      totalSubsDeleted += await _deleteBatchDocs(dessertRefs);

      // ── 2. Clean Legacy/Mirror `submissions` collection ────────────────────
      final Map<String, DocumentReference> subDocsMap = {};
      for (final field in ['studentId', 'userId']) {
        try {
          final s = await _firestore.collection('submissions').where(field, isEqualTo: student.uid).get();
          for (final d in s.docs) {
            subDocsMap[d.id] = d.reference;
          }
        } catch (_) {}
      }
      for (final phone in phoneVariants) {
        for (final field in ['phone', 'studentPhone']) {
          try {
            final s = await _firestore.collection('submissions').where(field, isEqualTo: phone).get();
            for (final d in s.docs) {
              subDocsMap[d.id] = d.reference;
            }
          } catch (_) {}
        }
      }
      totalSubsDeleted += await _deleteBatchDocs(subDocsMap.values.toList());

      // ── 3. Clean `dessert_reviews` collection ─────────────────────────────
      final Map<String, DocumentReference> reviewDocsMap = {};
      try {
        final revByStudent = await _firestore
            .collection('dessert_reviews')
            .where('studentId', isEqualTo: student.uid)
            .get();
        for (final d in revByStudent.docs) {
          reviewDocsMap[d.id] = d.reference;
        }
      } catch (_) {}

      for (final dId in collectedDessertIds) {
        try {
          final revByDessert = await _firestore
              .collection('dessert_reviews')
              .where('dessertId', isEqualTo: dId)
              .get();
          for (final d in revByDessert.docs) {
            reviewDocsMap[d.id] = d.reference;
          }
        } catch (_) {}
      }
      await _deleteBatchDocs(reviewDocsMap.values.toList());

      // ── 4. Clean MCQ Sprint Attempts (`sprint_attempts` collection) ────────
      final Map<String, DocumentReference> sprintDocsMap = {};
      try {
        final spByUid = await _firestore
            .collection('sprint_attempts')
            .where('studentId', isEqualTo: student.uid)
            .get();
        for (final d in spByUid.docs) {
          sprintDocsMap[d.id] = d.reference;
        }
      } catch (_) {}

      for (final phone in phoneVariants) {
        try {
          final spByPhone = await _firestore
              .collection('sprint_attempts')
              .where('phone', isEqualTo: phone)
              .get();
          for (final d in spByPhone.docs) {
            sprintDocsMap[d.id] = d.reference;
          }
        } catch (_) {}
      }
      totalSprintAttemptsDeleted += await _deleteBatchDocs(sprintDocsMap.values.toList());

      // ── 5. Clean Live Exam Registrations (`paper_registrations`) ───────────
      final Map<String, DocumentSnapshot> regDocsMap = {};
      try {
        final regByUid = await _firestore
            .collection('paper_registrations')
            .where('studentId', isEqualTo: student.uid)
            .get();
        for (final d in regByUid.docs) {
          regDocsMap[d.id] = d;
        }
      } catch (_) {}

      for (final phone in phoneVariants) {
        try {
          final regByPhone = await _firestore
              .collection('paper_registrations')
              .where('studentPhone', isEqualTo: phone)
              .get();
          for (final d in regByPhone.docs) {
            regDocsMap[d.id] = d;
          }
        } catch (_) {}
      }

      // Decrement paper slot registeredCounts in paper_sessions for each registration
      for (final regDoc in regDocsMap.values) {
        try {
          final regData = regDoc.data() as Map<String, dynamic>? ?? {};
          final paperId = regData['paperId']?.toString();
          final slotId = regData['selectedSlot']?.toString();

          if (paperId != null && paperId.isNotEmpty && slotId != null && slotId.isNotEmpty) {
            final paperRef = _firestore.collection('paper_sessions').doc(paperId);
            final paperSnap = await paperRef.get();
            if (paperSnap.exists) {
              final paperData = paperSnap.data() ?? {};
              final slotMap = paperData[slotId];
              if (slotMap is Map) {
                final currentCount = (slotMap['registeredCount'] as num?)?.toInt() ?? 1;
                await paperRef.update({
                  '$slotId.registeredCount': currentCount > 0 ? currentCount - 1 : 0,
                }).catchError((_) {});
              }
            }
          }
        } catch (e) {
          debugPrint('Notice adjusting slot count on paper registration delete: $e');
        }
      }
      final regRefs = regDocsMap.values.map((d) => d.reference).toList();
      totalRegsDeleted += await _deleteBatchDocs(regRefs);

      // ── 6. Clean Exam Proctor Alerts (`proctor_alerts` collection) ────────
      final Map<String, DocumentReference> alertDocsMap = {};
      try {
        final alertsByUid = await _firestore
            .collection('proctor_alerts')
            .where('studentId', isEqualTo: student.uid)
            .get();
        for (final d in alertsByUid.docs) {
          alertDocsMap[d.id] = d.reference;
        }
      } catch (_) {}

      for (final phone in phoneVariants) {
        try {
          final alertsByPhone = await _firestore
              .collection('proctor_alerts')
              .where('studentPhone', isEqualTo: phone)
              .get();
          for (final d in alertsByPhone.docs) {
            alertDocsMap[d.id] = d.reference;
          }
        } catch (_) {}
      }
      totalAlertsDeleted += await _deleteBatchDocs(alertDocsMap.values.toList());

      // ── 7. Clean Credit Transaction History (`credits_history` collection) ─
      final Map<String, DocumentReference> creditDocsMap = {};
      for (final field in ['studentId', 'userId']) {
        try {
          final cr = await _firestore.collection('credits_history').where(field, isEqualTo: student.uid).get();
          for (final d in cr.docs) {
            creditDocsMap[d.id] = d.reference;
          }
        } catch (_) {}
      }
      for (final phone in phoneVariants) {
        try {
          final cr = await _firestore.collection('credits_history').where('phone', isEqualTo: phone).get();
          for (final d in cr.docs) {
            creditDocsMap[d.id] = d.reference;
          }
        } catch (_) {}
      }
      totalCreditsHistoryDeleted += await _deleteBatchDocs(creditDocsMap.values.toList());

      // ── 8. Clean Student Announcements (`announcements` collection) ───────
      final Map<String, DocumentReference> annDocsMap = {};
      try {
        final annByUid = await _firestore
            .collection('announcements')
            .where('targetStudentId', isEqualTo: student.uid)
            .get();
        for (final d in annByUid.docs) {
          annDocsMap[d.id] = d.reference;
        }
      } catch (_) {}

      for (final phone in phoneVariants) {
        try {
          final annByPhone = await _firestore
              .collection('announcements')
              .where('targetStudentPhone', isEqualTo: phone)
              .get();
          for (final d in annByPhone.docs) {
            annDocsMap[d.id] = d.reference;
          }
        } catch (_) {}
      }
      totalAnnouncementsDeleted += await _deleteBatchDocs(annDocsMap.values.toList());

      // ── 9. Clean OTP Verifications & Requests ──────────────────────────────
      for (final phone in phoneVariants) {
        try {
          await _firestore.collection('otp_verifications').doc(phone).delete().catchError((_) {});
        } catch (_) {}
        try {
          final otpReqs = await _firestore.collection('otp_requests').where('phone', isEqualTo: phone).get();
          await _deleteBatchDocs(otpReqs.docs.map((d) => d.reference).toList());
        } catch (_) {}
      }

      // ── 10. Clean Subcollections under `users/{uid}` ───────────────────────
      const knownSubcollections = [
        'notifications',
        'desserts',
        'sprint_attempts',
        'credits_history',
        'chat_history',
        'submissions',
      ];
      for (final sub in knownSubcollections) {
        try {
          final subSnap = await _firestore
              .collection('users')
              .doc(student.uid)
              .collection(sub)
              .get();
          if (subSnap.docs.isNotEmpty) {
            await _deleteBatchDocs(subSnap.docs.map((d) => d.reference).toList());
          }
        } catch (_) {}
      }

      // ── 11. Delete Profile Picture from Firebase Storage ───────────────────
      if (student.avatarUrl != null &&
          student.avatarUrl!.contains('firebasestorage.googleapis.com')) {
        try {
          await _storage.refFromURL(student.avatarUrl!).delete().catchError((_) {});
        } catch (_) {}
      }

      // ── 12. Delete Main Student Document (`users/{uid}`) ───────────────────
      await _firestore.collection('users').doc(student.uid).delete();
      totalDocsDeleted = totalSubsDeleted +
          totalSprintAttemptsDeleted +
          totalRegsDeleted +
          totalAlertsDeleted +
          totalCreditsHistoryDeleted +
          totalAnnouncementsDeleted +
          1; // +1 for user document itself

      return StudentDeletionReport(
        submissionsDeleted: totalSubsDeleted,
        sprintAttemptsDeleted: totalSprintAttemptsDeleted,
        registrationsDeleted: totalRegsDeleted,
        alertsDeleted: totalAlertsDeleted,
        creditsHistoryDeleted: totalCreditsHistoryDeleted,
        announcementsDeleted: totalAnnouncementsDeleted,
        totalDocumentsDeleted: totalDocsDeleted,
        success: true,
      );
    } catch (e) {
      debugPrint('Error during student cascade deletion: $e');
      return StudentDeletionReport(
        submissionsDeleted: totalSubsDeleted,
        sprintAttemptsDeleted: totalSprintAttemptsDeleted,
        registrationsDeleted: totalRegsDeleted,
        alertsDeleted: totalAlertsDeleted,
        creditsHistoryDeleted: totalCreditsHistoryDeleted,
        announcementsDeleted: totalAnnouncementsDeleted,
        totalDocumentsDeleted: totalDocsDeleted,
        success: false,
        error: e.toString(),
      );
    }
  }
}
