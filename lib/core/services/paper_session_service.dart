import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final docRef = session.id.isEmpty
        ? _firestore.collection('paper_sessions').doc()
        : _firestore.collection('paper_sessions').doc(session.id);

    await docRef.set(session.toMap(), SetOptions(merge: true));
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
    return _firestore.collection('paper_sessions').snapshots().map((snapshot) {
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
    return _firestore.collection('paper_sessions').doc(paperId).snapshots().map((doc) {
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
      final rawPaperData = paperSnap.data();
      final paperData = (rawPaperData is Map) ? Map<String, dynamic>.from(rawPaperData) : <String, dynamic>{};
      final rawRegData = regSnap.data();
      final regData = (rawRegData is Map) ? Map<String, dynamic>.from(rawRegData) : null;
      final previousSlot = regSnap.exists && regData != null ? regData['selectedSlot'] as String? : null;

      // Update slot counts on paper_sessions
      if (previousSlot != null && previousSlot != slotId) {
        // Switching slot
        final prevSlotMap = (paperData[previousSlot] is Map) ? Map<String, dynamic>.from(paperData[previousSlot] as Map) : {};
        final nextSlotMap = (paperData[slotId] is Map) ? Map<String, dynamic>.from(paperData[slotId] as Map) : {};
        final prevCount = ((prevSlotMap['registeredCount'] is num) ? (prevSlotMap['registeredCount'] as num).toInt() : 1) - 1;
        final newCount = ((nextSlotMap['registeredCount'] is num) ? (nextSlotMap['registeredCount'] as num).toInt() : 0) + 1;
        transaction.update(paperRef, {
          '$previousSlot.registeredCount': prevCount < 0 ? 0 : prevCount,
          '$slotId.registeredCount': newCount,
        });
      } else if (!regSnap.exists) {
        // New registration
        final nextSlotMap = (paperData[slotId] is Map) ? Map<String, dynamic>.from(paperData[slotId] as Map) : {};
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
  }) async {
    await _ensureAuth();
    final regDocId = '${paperId}_$studentId';
    final Map<String, dynamic> updates = {
      'paperId': paperId,
      'studentId': studentId,
      'isCameraActive': isCameraActive,
      'lastCameraPing': FieldValue.serverTimestamp(),
    };
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
      'createdAt': FieldValue.serverTimestamp(),
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
      'createdAt': FieldValue.serverTimestamp(),
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
    await _firestore.collection('paper_sessions').doc(paperId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 15. Start / Set Active Paper Session Manually (Admin Only) ────────────
  Future<void> startPaperSession(String paperId) async {
    await _ensureAuth();
    await _firestore.collection('paper_sessions').doc(paperId).update({
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 16. Re-open Ended Session (Admin Only) ────────────────────────────────
  Future<void> reopenPaperSession(String paperId) async {
    await _ensureAuth();
    await _firestore.collection('paper_sessions').doc(paperId).update({
      'status': 'active',
      'reopenedAt': FieldValue.serverTimestamp(),
    });
  }
}
