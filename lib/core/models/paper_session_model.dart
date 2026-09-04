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

  factory PaperSlot.fromMap(String id, Map<dynamic, dynamic> map) {
    DateTime parseTime(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final now = DateTime.now();
    return PaperSlot(
      id: id,
      name: map['name']?.toString() ?? (id == 'slot1' ? 'Morning Session (උදෑසන සැසිය)' : 'Evening Session (සවස සැසිය)'),
      startTime: parseTime(map['startTime'], now),
      endTime: parseTime(map['endTime'], now.add(const Duration(hours: 3))),
      maxCapacity: (map['maxCapacity'] is num)
          ? (map['maxCapacity'] as num).toInt()
          : (int.tryParse(map['maxCapacity']?.toString() ?? '') ?? 200),
      registeredCount: (map['registeredCount'] is num)
          ? (map['registeredCount'] as num).toInt()
          : (int.tryParse(map['registeredCount']?.toString() ?? '') ?? 0),
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
  final String currentPhase; // 'waiting', 'package_opening', 'writing', 'time_up', 'ended'
  final bool isTimeUp;
  final PaperSlot slot1;
  final PaperSlot? slot2;
  final DateTime createdAt;
  final DateTime? packageOpeningStartedAt;
  final DateTime? writingStartedAt;

  bool get isEnded => status == 'ended' || currentPhase == 'ended';
  bool get isActive => status == 'active' && currentPhase != 'ended' && currentPhase != 'waiting';
  bool get isUpcoming => status == 'upcoming' || currentPhase == 'waiting';
  bool get isWaiting => currentPhase == 'waiting';
  bool get isPackageOpening => currentPhase == 'package_opening';
  bool get isWriting => currentPhase == 'writing';

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
    this.currentPhase = 'waiting',
    this.isTimeUp = false,
    required this.slot1,
    this.slot2,
    required this.createdAt,
    this.packageOpeningStartedAt,
    this.writingStartedAt,
  });

  factory PaperSession.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final Map<String, dynamic> data = (rawData is Map)
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    final now = DateTime.now();

    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? now;
      return now;
    }

    DateTime? parseOptionalTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    Map<dynamic, dynamic> safeMap(dynamic val) {
      if (val is Map) return val;
      return const {};
    }

    final rawDuration = data['durationMinutes'];
    final int parsedDuration = (rawDuration is num)
        ? rawDuration.toInt()
        : (int.tryParse(rawDuration?.toString() ?? '') ?? 180);

    final String rawStatus = data['status']?.toString() ?? 'upcoming';
    final bool rawTimeUp = data['isTimeUp'] == true || rawStatus == 'time_up';

    String parsedPhase = data['currentPhase']?.toString() ?? '';
    if (parsedPhase.isEmpty) {
      if (rawStatus == 'ended') {
        parsedPhase = 'ended';
      } else if (rawTimeUp) {
        parsedPhase = 'time_up';
      } else if (rawStatus == 'active') {
        parsedPhase = 'writing';
      } else {
        parsedPhase = 'waiting';
      }
    }

    return PaperSession(
      id: doc.id,
      title: data['title']?.toString() ?? 'A/L Examination Paper',
      subject: data['subject']?.toString() ?? 'Combined Mathematics',
      examYear: data['examYear']?.toString() ?? '2027 A/L',
      date: data['date']?.toString() ?? now.toIso8601String().split('T')[0],
      durationMinutes: parsedDuration,
      pdfUrl: data['pdfUrl']?.toString(),
      paperImageUrl: data['paperImageUrl']?.toString(),
      status: rawStatus,
      currentPhase: parsedPhase,
      isTimeUp: rawTimeUp,
      slot1: PaperSlot.fromMap('slot1', safeMap(data['slot1'])),
      slot2: (data['slot2'] is Map) ? PaperSlot.fromMap('slot2', safeMap(data['slot2'])) : null,
      createdAt: parseTime(data['createdAt']),
      packageOpeningStartedAt: parseOptionalTime(data['packageOpeningStartedAt']),
      writingStartedAt: parseOptionalTime(data['writingStartedAt']),
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
      'currentPhase': currentPhase,
      'isTimeUp': isTimeUp,
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
    if (packageOpeningStartedAt != null) {
      map['packageOpeningStartedAt'] = Timestamp.fromDate(packageOpeningStartedAt!);
    }
    if (writingStartedAt != null) {
      map['writingStartedAt'] = Timestamp.fromDate(writingStartedAt!);
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

  bool get isOnline {
    if (!isCameraActive) return false;
    if (lastCameraPing == null) return false;
    return DateTime.now().difference(lastCameraPing!).inSeconds < 10;
  }

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
    final rawData = doc.data();
    final Map<String, dynamic> data = (rawData is Map)
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    DateTime? parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawPhotos = data['submissionPhotos'];
    final List<String> photos = rawPhotos is List
        ? rawPhotos.map((e) => e.toString()).toList()
        : (data['submissionUrl'] != null ? [data['submissionUrl'].toString()] : []);

    final idParts = doc.id.split('_');
    final fallbackPaperId = idParts.isNotEmpty ? idParts[0] : '';
    final fallbackStudentId = idParts.length > 1 ? idParts.sublist(1).join('_') : '';

    final String parsedPaperId = (data['paperId'] != null && data['paperId'].toString().trim().isNotEmpty)
        ? data['paperId'].toString().trim()
        : fallbackPaperId;

    final String parsedStudentId = (data['studentId'] != null && data['studentId'].toString().trim().isNotEmpty)
        ? data['studentId'].toString().trim()
        : fallbackStudentId;

    final String parsedSlot = (data['selectedSlot'] != null && data['selectedSlot'].toString().trim().isNotEmpty && data['selectedSlot'] != 'null')
        ? data['selectedSlot'].toString().trim()
        : 'slot1';

    return PaperRegistration(
      id: doc.id,
      paperId: parsedPaperId,
      studentId: parsedStudentId,
      studentName: data['studentName'] != null && data['studentName'].toString().trim().isNotEmpty
          ? data['studentName'].toString().trim()
          : 'Student',
      studentPhone: data['studentPhone']?.toString() ?? '',
      selectedSlot: parsedSlot,
      status: data['status']?.toString() ?? 'registered',
      registeredAt: parseTime(data['registeredAt']) ?? DateTime.now(),
      joinedAt: parseTime(data['joinedAt']),
      submittedAt: parseTime(data['submittedAt']),
      lastCameraPing: parseTime(data['lastCameraPing']),
      isCameraActive: data['isCameraActive'] == true,
      cameraSnapshotUrl: data['cameraSnapshotUrl']?.toString(),
      submissionUrl: data['submissionUrl']?.toString(),
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
    final rawData = doc.data();
    final Map<String, dynamic> data = (rawData is Map)
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ProctorAlert(
      id: doc.id,
      paperId: data['paperId']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'Proctor / Admin',
      message: data['message']?.toString() ?? '',
      type: data['type']?.toString() ?? 'warning',
      isRead: data['isRead'] == true,
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
