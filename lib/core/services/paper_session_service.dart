import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/paper_session_model.dart';

class PaperSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (_) {}
    }
  }

  // ── 1. Create or Update Paper Session ──────────────────────────────────────
  Future<String> createOrUpdatePaperSession(PaperSession session) async {
    await _ensureAuth();
    final isNewSession = session.id.isEmpty;
    final docRef = isNewSession
        ? _firestore.collection('paper_sessions').doc()
        : _firestore.collection('paper_sessions').doc(session.id);

    await docRef.set(session.toMap(), SetOptions(merge: true));

    // Asynchronously dispatch FCM push notification to topic 'paper_sessions'
    if (isNewSession) {
      unawaited(() async {
        try {
          final client = HttpClient();
          final request = await client.postUrl(
            Uri.parse('https://edupeak-telegram-bot.vercel.app/api/paper-broadcast'),
          );
          request.headers.set('Content-Type', 'application/json');
          request.add(utf8.encode(jsonEncode({
            'title': session.title,
            'subject': session.subject,
            'examYear': session.examYear,
            'date': session.date,
            'durationMinutes': session.durationMinutes,
          })));
          await request.close();
          client.close();
        } catch (e) {
          debugPrint('FCM paper broadcast request error: $e');
        }
      }());
    }

    return docRef.id;
  }

  // ── 2. Update Slot Times (Admin Instant Reschedule) ───────────────────────
  Future<void> updateSlotTimes(
    String paperId, {
    PaperSlot? slot1,
    PaperSlot? slot2,
  }) async {
    await _ensureAuth();
    final Map<String, dynamic> updates = {};
    if (slot1 != null) updates['slot1'] = slot1.toMap();
    if (slot2 != null) updates['slot2'] = slot2.toMap();

    if (updates.isNotEmpty) {
      await _firestore.collection('paper_sessions').doc(paperId).update(updates);
    }
  }

  // ── 3. Stream Upcoming & Active Sessions ──────────────────────────────────
  Stream<List<PaperSession>> streamSessions({String? examYear}) {
    return _firestore.collection('paper_sessions').snapshots(includeMetadataChanges: true).map((snapshot) {
      final list = <PaperSession>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(PaperSession.fromFirestore(doc));
        } catch (e, stack) {
          debugPrint('Error parsing paper session document ${doc.id}: $e\n$stack');
        }
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      if (examYear != null && examYear.trim().isNotEmpty && examYear != 'All' && examYear != 'All Batches') {
        final cleanExamYear = examYear.replaceAll(' ', '').toUpperCase();
        return list.where((p) {
          final pYear = p.examYear.replaceAll(' ', '').toUpperCase();
          return pYear == cleanExamYear ||
                 pYear == 'ALLBATCHES' ||
                 pYear == 'ALL' ||
                 p.examYear == examYear ||
                 p.examYear == 'All Batches' ||
                 p.examYear == 'All';
        }).toList();
      }
      return list;
    }).handleError((error, stack) {
      debugPrint('Firestore streamSessions error: $error\n$stack');
      return <PaperSession>[];
    });
  }

  // ── 3b. One-shot Fetch for Fast Initial Render & Pull-to-Refresh ──────────
  Future<List<PaperSession>> getSessions({String? examYear}) async {
    try {
      final snapshot = await _firestore.collection('paper_sessions').get(const GetOptions(source: Source.serverAndCache));
      final list = <PaperSession>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(PaperSession.fromFirestore(doc));
        } catch (e) {
          debugPrint('Error parsing paper session in getSessions ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      if (examYear != null && examYear.trim().isNotEmpty && examYear != 'All' && examYear != 'All Batches') {
        final cleanExamYear = examYear.replaceAll(' ', '').toUpperCase();
        return list.where((p) {
          final pYear = p.examYear.replaceAll(' ', '').toUpperCase();
          return pYear == cleanExamYear ||
                 pYear == 'ALLBATCHES' ||
                 pYear == 'ALL' ||
                 p.examYear == examYear ||
                 p.examYear == 'All Batches' ||
                 p.examYear == 'All';
        }).toList();
      }
      return list;
    } catch (e) {
      debugPrint('Error in getSessions: $e');
      return [];
    }
  }

  // ── 4. Stream Single Paper Session ─────────────────────────────────────────
  Stream<PaperSession?> streamPaperSession(String paperId) {
    if (paperId.isEmpty) return Stream.value(null);
    return _firestore.collection('paper_sessions').doc(paperId).snapshots(includeMetadataChanges: true).map((doc) {
      if (!doc.exists) return null;
      try {
        return PaperSession.fromFirestore(doc);
      } catch (e) {
        debugPrint('Error parsing single paper session $paperId: $e');
        return null;
      }
    }).handleError((e) {
      debugPrint('Error in streamPaperSession: $e');
      return null;
    });
  }

  // ── 5. Register Student for Slot 1 or Slot 2 ──────────────────────────────
  Future<void> registerStudentSlot({
    required String paperId,
    required String studentId,
    required String studentName,
    required String studentPhone,
    required String slotId, // 'slot1' or 'slot2'
  }) async {
    await _ensureAuth();
    final regDocId = '${paperId}_$studentId';
    final regRef = _firestore.collection('paper_registrations').doc(regDocId);

    await _firestore.runTransaction((transaction) async {
      final regSnap = await transaction.get(regRef);
      final paperRef = _firestore.collection('paper_sessions').doc(paperId);
      final paperSnap = await transaction.get(paperRef);

      if (!paperSnap.exists) throw Exception('Paper session does not exist');
      final Map<String, dynamic> paperData = paperSnap.data() ?? <String, dynamic>{};
      final Map<String, dynamic>? regData = regSnap.data();
      final previousSlot = regSnap.exists && regData != null ? regData['selectedSlot'] as String? : null;

      Map<String, dynamic> safeSlotMap(dynamic val) {
        if (val is Map) return Map<String, dynamic>.from(val);
        return <String, dynamic>{};
      }

      // Update slot counts on paper_sessions
      if (previousSlot != null && previousSlot != slotId) {
        // Switching slot
        final prevSlotMap = safeSlotMap(paperData[previousSlot]);
        final nextSlotMap = safeSlotMap(paperData[slotId]);
        final prevCount = ((prevSlotMap['registeredCount'] is num) ? (prevSlotMap['registeredCount'] as num).toInt() : 1) - 1;
        final newCount = ((nextSlotMap['registeredCount'] is num) ? (nextSlotMap['registeredCount'] as num).toInt() : 0) + 1;
        transaction.update(paperRef, {
          '$previousSlot.registeredCount': prevCount < 0 ? 0 : prevCount,
          '$slotId.registeredCount': newCount,
        });
      } else if (!regSnap.exists) {
        // New registration
        final nextSlotMap = safeSlotMap(paperData[slotId]);
        final currentCount = ((nextSlotMap['registeredCount'] is num) ? (nextSlotMap['registeredCount'] as num).toInt() : 0) + 1;
        transaction.update(paperRef, {
          '$slotId.registeredCount': currentCount,
        });
      }

      transaction.set(
        regRef,
        {
          'paperId': paperId,
          'studentId': studentId,
          'studentName': studentName,
          'studentPhone': studentPhone,
          'selectedSlot': slotId,
          'status': 'registered',
          'registeredAt': FieldValue.serverTimestamp(),
          'isCameraActive': false,
        },
        SetOptions(merge: true),
      );
    });
  }

  // ── 6. Stream Student's Registration for a Paper ──────────────────────────
  Stream<PaperRegistration?> streamStudentRegistration(String paperId, String studentId) {
    if (paperId.isEmpty || studentId.isEmpty) return Stream.value(null);
    final regDocId = '${paperId}_$studentId';
    return _firestore.collection('paper_registrations').doc(regDocId).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        return PaperRegistration.fromFirestore(doc);
      } catch (e) {
        debugPrint('Error parsing student registration for $regDocId: $e');
        return null;
      }
    }).handleError((e) {
      debugPrint('Error in streamStudentRegistration: $e');
      return null;
    });
  }

  // ── 7. Update Student Proctored Heartbeat & Live Camera State ──────────────
  Future<void> updateCameraHeartbeat({
    required String paperId,
    required String studentId,
    required bool isCameraActive,
    String? studentName,
    String? studentPhone,
    String? slotId,
    String? cameraSnapshotUrl,
    String? status,
    List<String>? submissionPhotos,
    int? agoraUid,
  }) async {
    await _ensureAuth();
    final regDocId = '${paperId}_$studentId';
    final Map<String, dynamic> updates = {
      'paperId': paperId,
      'studentId': studentId,
      'isCameraActive': isCameraActive,
      'lastCameraPing': FieldValue.serverTimestamp(),
    };
    if (agoraUid != null && agoraUid > 0) {
      updates['agoraUid'] = agoraUid;
    }
    if (studentName != null && studentName.trim().isNotEmpty) {
      updates['studentName'] = studentName.trim();
    }
    if (studentPhone != null && studentPhone.trim().isNotEmpty) {
      updates['studentPhone'] = studentPhone.trim();
    }
    if (slotId != null && slotId.trim().isNotEmpty) {
      updates['selectedSlot'] = slotId.trim();
    }
    if (cameraSnapshotUrl != null) {
      updates['cameraSnapshotUrl'] = cameraSnapshotUrl;
    }
    if (submissionPhotos != null && submissionPhotos.isNotEmpty) {
      updates['submissionPhotos'] = submissionPhotos;
      updates['submissionUrl'] = submissionPhotos.first;
    }
    if (status != null) {
      updates['status'] = status;
      if (status == 'in_exam') {
        updates['joinedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'submitted') {
        updates['submittedAt'] = FieldValue.serverTimestamp();
      }
    }

    await _firestore.collection('paper_registrations').doc(regDocId).set(updates, SetOptions(merge: true));
  }

  // ── 8. Stream All Students in a Session / Slot (For Admin Invigilator Grid) ─
  Stream<List<PaperRegistration>> streamSlotRegistrations(String paperId, String? slotId) {
    if (paperId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('paper_registrations')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${paperId}_')
        .where(FieldPath.documentId, isLessThanOrEqualTo: '${paperId}_\uf8ff')
        .snapshots()
        .map((snapshot) {
      final all = <PaperRegistration>[];
      for (final doc in snapshot.docs) {
        try {
          all.add(PaperRegistration.fromFirestore(doc));
        } catch (e) {
          debugPrint('Error parsing slot registration ${doc.id}: $e');
        }
      }
      if (slotId == null || slotId.isEmpty) return all;
      return all.where((reg) {
        final regSlot = (reg.selectedSlot.isEmpty || reg.selectedSlot == 'null') ? 'slot1' : reg.selectedSlot;
        return regSlot == slotId;
      }).toList();
    }).handleError((e) {
      debugPrint('Error in streamSlotRegistrations: $e');
      return <PaperRegistration>[];
    });
  }

  // ── 9. Send Direct Proctor Alert / Message to Student ─────────────────────
  Future<void> sendProctorAlert({
    required String paperId,
    required String studentId,
    required String senderName,
    required String message,
    String type = 'warning',
  }) async {
    await _ensureAuth();
    await _firestore.collection('proctor_alerts').add({
      'paperId': paperId,
      'studentId': studentId,
      'senderName': senderName,
      'message': message,
      'type': type,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  // ── 10. Broadcast Alert to ALL Active Students in Session ─────────────────
  Future<void> broadcastProctorAlert({
    required String paperId,
    required String senderName,
    required String message,
    String type = 'info',
  }) async {
    await _ensureAuth();
    await _firestore.collection('proctor_alerts').add({
      'paperId': paperId,
      'studentId': 'ALL',
      'senderName': senderName,
      'message': message,
      'type': type,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  // ── 11. Stream Direct Alerts for a Student ────────────────────────────────
  Stream<List<ProctorAlert>> streamStudentAlerts({
    required String paperId,
    required String studentId,
  }) {
    if (paperId.isEmpty || studentId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('proctor_alerts')
        .where('paperId', isEqualTo: paperId)
        .snapshots()
        .map((snapshot) {
      final list = <ProctorAlert>[];
      for (final doc in snapshot.docs) {
        try {
          final alert = ProctorAlert.fromFirestore(doc);
          if (alert.studentId == studentId || alert.studentId == 'ALL') {
            list.add(alert);
          }
        } catch (e) {
          debugPrint('Error parsing proctor alert ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((e) {
      debugPrint('Error in streamStudentAlerts: $e');
      return <ProctorAlert>[];
    });
  }

  // ── 12. Mark Alert as Read ────────────────────────────────────────────────
  Future<void> markAlertRead(String alertId) async {
    await _ensureAuth();
    await _firestore.collection('proctor_alerts').doc(alertId).update({'isRead': true});
  }

  // ── 13. Delete Paper Session & Associated Registrations / Alerts ───────────
  Future<void> deletePaperSession(String paperId) async {
    await _ensureAuth();
    await _firestore.collection('paper_sessions').doc(paperId).delete();

    try {
      final regs = await _firestore.collection('paper_registrations').where('paperId', isEqualTo: paperId).get();
      for (final doc in regs.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    try {
      final alerts = await _firestore.collection('proctor_alerts').where('paperId', isEqualTo: paperId).get();
      for (final doc in alerts.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  // ── 14. End Paper Session Manually (Admin Only) ───────────────────────────
  Future<void> endPaperSession(String paperId) async {
    await _ensureAuth();
    final now = Timestamp.now();
    await _firestore.collection('paper_sessions').doc(paperId).update({
      'status': 'ended',
      'currentPhase': 'ended',
      'endedAt': now,
    });
    unawaited(broadcastProctorAlert(
      paperId: paperId,
      senderName: 'Admin / Examiner',
      message: '🛑 මෙම විභාග සැසිය නිල වශයෙන් අවසන් විය. (Exam session ended by Admin)',
      type: 'urgent',
    ).catchError((e) => debugPrint('End session alert error: $e')));
  }

  // ── 15. Start / Set Active Paper Session Manually (Admin Only) ────────────
  Future<void> startPaperSession(String paperId) async {
    await _ensureAuth();
    final now = Timestamp.now();
    await _firestore.collection('paper_sessions').doc(paperId).update({
      'status': 'active',
      'currentPhase': 'writing',
      'startedAt': now,
      'writingStartedAt': now,
    });
  }

  // ── 16. Re-open Ended Session (Admin Only) ────────────────────────────────
  Future<void> reopenPaperSession(String paperId) async {
    await _ensureAuth();
    final now = Timestamp.now();
    await _firestore.collection('paper_sessions').doc(paperId).update({
      'status': 'active',
      'currentPhase': 'writing',
      'isTimeUp': false,
      'reopenedAt': now,
      'writingStartedAt': now,
    });
  }

  // ── 17. Trigger Time Up (Admin Only) ──────────────────────────────────────
  Future<void> triggerTimeUp(String paperId) async {
    await _ensureAuth();
    final now = Timestamp.now();
    await _firestore.collection('paper_sessions').doc(paperId).update({
      'isTimeUp': true,
      'currentPhase': 'time_up',
      'timeUpAt': now,
    });
    // Broadcast high-priority alert to all students in background
    unawaited(broadcastProctorAlert(
      paperId: paperId,
      senderName: 'Admin / Examiner',
      message: '⏰ වේලාව අවසන් විය! (Time is Up!) කරුණාකර ලිවීම නවතා ඔබගේ පිළිතුරු පත්‍ර In-App Scanner එක හරහා Scan කර දැන්ම Submit කරන්න.',
      type: 'urgent',
    ).catchError((e) => debugPrint('Trigger time up alert error: $e')));
  }

  // ── 18. Reset Time Up (Admin Only) ────────────────────────────────────────
  Future<void> resetTimeUp(String paperId) async {
    await _ensureAuth();
    final now = Timestamp.now();
    await _firestore.collection('paper_sessions').doc(paperId).update({
      'isTimeUp': false,
      'currentPhase': 'writing',
      'writingStartedAt': now,
    });
  }

  // ── 19. Set Session Phase Manually (Admin Only) ───────────────────────────
  Future<void> setSessionPhase(String paperId, String phase) async {
    await _ensureAuth();
    final nowTimestamp = Timestamp.now();
    final Map<String, dynamic> updates = {
      'currentPhase': phase,
    };

    String? alertMessage;
    String alertType = 'info';

    if (phase == 'waiting') {
      updates['status'] = 'upcoming';
      updates['isTimeUp'] = false;
    } else if (phase == 'package_opening') {
      updates['status'] = 'active';
      updates['isTimeUp'] = false;
      updates['packageOpeningStartedAt'] = nowTimestamp;
      alertMessage = '📦 ප්‍රශ්න පත්‍ර පාර්සලය කැමරාව ඉදිරියේ විවෘත කරන්න! (Open your exam parcel in front of the camera now!)';
      alertType = 'urgent';
    } else if (phase == 'writing') {
      updates['status'] = 'active';
      updates['isTimeUp'] = false;
      updates['writingStartedAt'] = nowTimestamp;
      alertMessage = '✍️ විභාගය ආරම්භ විය! දැන් පිළිතුරු ලිවීම ආරම්භ කරන්න. (Exam Writing has started!)';
      alertType = 'info';
    } else if (phase == 'time_up') {
      updates['status'] = 'active';
      updates['isTimeUp'] = true;
      updates['timeUpAt'] = nowTimestamp;
      alertMessage = '⏰ වේලාව අවසන් විය! ලිවීම නවතා ඔබගේ පිළිතුරු පත්‍ර In-App Scanner එකෙන් Scan කර දැන්ම Submit කරන්න.';
      alertType = 'urgent';
    } else if (phase == 'ended') {
      updates['status'] = 'ended';
      updates['endedAt'] = nowTimestamp;
      alertMessage = '🛑 මෙම විභාග සැසිය නිල වශයෙන් අවසන් විය. (Session Ended by Examiner)';
      alertType = 'urgent';
    }

    // ⚡ 1. UPDATE SESSION DOCUMENT FIRST! (Immediate real-time push to all student streams)
    await _firestore.collection('paper_sessions').doc(paperId).update(updates);

    // ⚡ 2. Broadcast proctor alert in background without blocking the session phase transition
    if (alertMessage != null) {
      unawaited(
        broadcastProctorAlert(
          paperId: paperId,
          senderName: 'Admin / Examiner',
          message: alertMessage,
          type: alertType,
        ).catchError((e) => debugPrint('Broadcast alert error: $e')),
      );
    }
  }
}
