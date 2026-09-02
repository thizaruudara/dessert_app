import 'package:cloud_firestore/cloud_firestore.dart';

class PaperSlot {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final int maxCapacity;
  final int registeredCount;

  PaperSlot({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.maxCapacity = 200,
    this.registeredCount = 0,
  });

  factory PaperSlot.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseTime(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final now = DateTime.now();
    return PaperSlot(
      id: id,
      name: map['name'] ?? (id == 'slot1' ? 'Morning Session (උදෑසන සැසිය)' : 'Evening Session (සවස සැසිය)'),
      startTime: parseTime(map['startTime'], now),
      endTime: parseTime(map['endTime'], now.add(const Duration(hours: 3))),
      maxCapacity: map['maxCapacity'] ?? 200,
      registeredCount: map['registeredCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'maxCapacity': maxCapacity,
      'registeredCount': registeredCount,
    };
  }

  bool isUpcoming(DateTime now) => now.isBefore(startTime);
  bool isLive(DateTime now) => now.isAfter(startTime) && now.isBefore(endTime);
  bool isEnded(DateTime now) => now.isAfter(endTime);
}

class PaperSession {
  final String id;
  final String title;
  final String subject;
  final String examYear;
  final String date;
  final int durationMinutes;
  final String? pdfUrl;
  final String? paperImageUrl;
  final String status; // 'upcoming', 'active', 'ended'
  final PaperSlot slot1;
  final PaperSlot? slot2;
  final DateTime createdAt;

  PaperSession({
    required this.id,
    required this.title,
    required this.subject,
    required this.examYear,
    required this.date,
    required this.durationMinutes,
    this.pdfUrl,
    this.paperImageUrl,
    this.status = 'upcoming',
    required this.slot1,
    this.slot2,
    required this.createdAt,
  });

  factory PaperSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final now = DateTime.now();

    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? now;
      return now;
    }

    return PaperSession(
      id: doc.id,
      title: data['title'] ?? 'A/L Examination Paper',
      subject: data['subject'] ?? 'Combined Mathematics',
      examYear: data['examYear'] ?? '2027 A/L',
      date: data['date'] ?? now.toIso8601String().split('T')[0],
      durationMinutes: data['durationMinutes'] ?? 180,
      pdfUrl: data['pdfUrl'],
      paperImageUrl: data['paperImageUrl'],
      status: data['status'] ?? 'upcoming',
      slot1: PaperSlot.fromMap('slot1', data['slot1'] as Map<String, dynamic>? ?? {}),
      slot2: data['slot2'] != null ? PaperSlot.fromMap('slot2', data['slot2'] as Map<String, dynamic>) : null,
      createdAt: parseTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'title': title,
      'subject': subject,
      'examYear': examYear,
      'date': date,
      'durationMinutes': durationMinutes,
      'status': status,
      'slot1': slot1.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (slot2 != null) {
      map['slot2'] = slot2!.toMap();
    }
    if (pdfUrl != null && pdfUrl!.trim().isNotEmpty) {
      map['pdfUrl'] = pdfUrl!.trim();
    }
    if (paperImageUrl != null && paperImageUrl!.trim().isNotEmpty) {
      map['paperImageUrl'] = paperImageUrl!.trim();
    }
    return map;
  }
}

class PaperRegistration {
  final String id;
  final String paperId;
  final String studentId;
  final String studentName;
  final String studentPhone;
  final String selectedSlot; // 'slot1' or 'slot2'
  final String status; // 'registered', 'in_exam', 'submitted', 'absent'
  final DateTime registeredAt;
  final DateTime? joinedAt;
  final DateTime? submittedAt;
  final DateTime? lastCameraPing;
  final bool isCameraActive;
  final String? cameraSnapshotUrl;
  final String? submissionUrl;
  final List<String> submissionPhotos;

  PaperRegistration({
    required this.id,
    required this.paperId,
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    required this.selectedSlot,
    this.status = 'registered',
    required this.registeredAt,
    this.joinedAt,
    this.submittedAt,
    this.lastCameraPing,
    this.isCameraActive = false,
    this.cameraSnapshotUrl,
    this.submissionUrl,
    this.submissionPhotos = const [],
  });

  factory PaperRegistration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawPhotos = data['submissionPhotos'];
    final List<String> photos = rawPhotos is List
        ? rawPhotos.map((e) => e.toString()).toList()
        : (data['submissionUrl'] != null ? [data['submissionUrl'].toString()] : []);

    return PaperRegistration(
      id: doc.id,
      paperId: data['paperId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'Student',
      studentPhone: data['studentPhone'] ?? '',
      selectedSlot: data['selectedSlot'] ?? 'slot1',
      status: data['status'] ?? 'registered',
      registeredAt: parseTime(data['registeredAt']) ?? DateTime.now(),
      joinedAt: parseTime(data['joinedAt']),
      submittedAt: parseTime(data['submittedAt']),
      lastCameraPing: parseTime(data['lastCameraPing']),
      isCameraActive: data['isCameraActive'] ?? false,
      cameraSnapshotUrl: data['cameraSnapshotUrl'],
      submissionUrl: data['submissionUrl'],
      submissionPhotos: photos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paperId': paperId,
      'studentId': studentId,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'selectedSlot': selectedSlot,
      'status': status,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'lastCameraPing': lastCameraPing != null ? Timestamp.fromDate(lastCameraPing!) : null,
      'isCameraActive': isCameraActive,
      'cameraSnapshotUrl': cameraSnapshotUrl,
      'submissionUrl': submissionUrl,
      'submissionPhotos': submissionPhotos,
    };
  }
}

class ProctorAlert {
  final String id;
  final String paperId;
  final String studentId;
  final String senderName;
  final String message;
  final String type; // 'warning', 'info', 'urgent'
  final bool isRead;
  final DateTime createdAt;

  ProctorAlert({
    required this.id,
    required this.paperId,
    required this.studentId,
    required this.senderName,
    required this.message,
    this.type = 'warning',
    this.isRead = false,
    required this.createdAt,
  });

  factory ProctorAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ProctorAlert(
      id: doc.id,
      paperId: data['paperId'] ?? '',
      studentId: data['studentId'] ?? '',
      senderName: data['senderName'] ?? 'Proctor / Admin',
      message: data['message'] ?? '',
      type: data['type'] ?? 'warning',
      isRead: data['isRead'] ?? false,
      createdAt: parseTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paperId': paperId,
      'studentId': studentId,
      'senderName': senderName,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
