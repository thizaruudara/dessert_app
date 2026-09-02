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
      final list = snapshot.docs.map((doc) => PaperSession.fromFirestore(doc)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      if (examYear != null && examYear.trim().isNotEmpty && examYear != 'All') {
        final norm = examYear.replaceAll(RegExp(r'\D'), '');
        if (norm.isEmpty) return list;
        return list.where((p) {
          if (p.examYear.toLowerCase() == 'all') return true;
          final pNorm = p.examYear.replaceAll(RegExp(r'\D'), '');
          return pNorm.isEmpty || norm == pNorm || p.examYear.toLowerCase().contains(norm);
        }).toList();
      }
      return list;
    });
  }

  // ── 4. Stream Single Paper Session ─────────────────────────────────────────
  Stream<PaperSession?> streamPaperSession(String paperId) {
    return _firestore.collection('paper_sessions').doc(paperId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PaperSession.fromFirestore(doc);
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
      final paperData = paperSnap.data() as Map<String, dynamic>;
      final regData = regSnap.data() as Map<String, dynamic>?;
      final previousSlot = regSnap.exists && regData != null ? regData['selectedSlot'] as String? : null;

      // Update slot counts on paper_sessions
      if (previousSlot != null && previousSlot != slotId) {
        // Switching slot
        final prevCount = (paperData[previousSlot]?['registeredCount'] ?? 1) - 1;
        final newCount = (paperData[slotId]?['registeredCount'] ?? 0) + 1;
        transaction.update(paperRef, {
          '$previousSlot.registeredCount': prevCount < 0 ? 0 : prevCount,
          '$slotId.registeredCount': newCount,
        });
      } else if (!regSnap.exists) {
        // New registration
        final currentCount = (paperData[slotId]?['registeredCount'] ?? 0) + 1;
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
    final regDocId = '${paperId}_$studentId';
    return _firestore.collection('paper_registrations').doc(regDocId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PaperRegistration.fromFirestore(doc);
    });
  }

  // ── 7. Update Student Proctored Heartbeat & Live Camera State ──────────────
  Future<void> updateCameraHeartbeat({
    required String paperId,
    required String studentId,
    required bool isCameraActive,
    String? cameraSnapshotUrl,
    String? status,
  }) async {
    await _ensureAuth();
    final regDocId = '${paperId}_$studentId';
    final Map<String, dynamic> updates = {
      'isCameraActive': isCameraActive,
      'lastCameraPing': FieldValue.serverTimestamp(),
    };
    if (cameraSnapshotUrl != null) {
      updates['cameraSnapshotUrl'] = cameraSnapshotUrl;
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
    Query query = _firestore.collection('paper_registrations').where('paperId', isEqualTo: paperId);
    if (slotId != null && slotId.isNotEmpty) {
      query = query.where('selectedSlot', isEqualTo: slotId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PaperRegistration.fromFirestore(doc)).toList();
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
    return _firestore
        .collection('proctor_alerts')
        .where('paperId', isEqualTo: paperId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ProctorAlert.fromFirestore(doc))
          .where((alert) => alert.studentId == studentId || alert.studentId == 'ALL')
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── 12. Mark Alert as Read ────────────────────────────────────────────────
  Future<void> markAlertRead(String alertId) async {
    await _firestore.collection('proctor_alerts').doc(alertId).update({'isRead': true});
  }
}
