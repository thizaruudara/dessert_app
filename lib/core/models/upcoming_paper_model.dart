import 'package:cloud_firestore/cloud_firestore.dart';

class UpcomingPaper {
  final String id;
  final String title;
  final String subject;
  final String examYear;
  final DateTime scheduledDate;
  final int durationMinutes;
  final String paperStructure;
  final List<String> syllabusTopics;
  final String hints;
  final String instructions;
  final String status; // 'upcoming', 'active', 'archived'
  final DateTime createdAt;

  UpcomingPaper({
    required this.id,
    required this.title,
    required this.subject,
    required this.examYear,
    required this.scheduledDate,
    required this.durationMinutes,
    this.paperStructure = '',
    this.syllabusTopics = const [],
    this.hints = '',
    this.instructions = '',
    this.status = 'upcoming',
    required this.createdAt,
  });

  bool get isUpcoming => scheduledDate.isAfter(DateTime.now());

  Duration get timeRemaining {
    final now = DateTime.now();
    if (scheduledDate.isAfter(now)) {
      return scheduledDate.difference(now);
    }
    return Duration.zero;
  }

  factory UpcomingPaper.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final Map<String, dynamic> data = (rawData is Map)
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawTopics = data['syllabusTopics'];
    List<String> topics = [];
    if (rawTopics is List) {
      topics = rawTopics.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawTopics is String && rawTopics.isNotEmpty) {
      topics = rawTopics.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final rawDuration = data['durationMinutes'];
    final int parsedDuration = (rawDuration is num)
        ? rawDuration.toInt()
        : (int.tryParse(rawDuration?.toString() ?? '') ?? 180);

    return UpcomingPaper(
      id: doc.id,
      title: data['title']?.toString() ?? 'Upcoming Exam Paper',
      subject: data['subject']?.toString() ?? 'Physics',
      examYear: data['examYear']?.toString() ?? '2027 A/L',
      scheduledDate: parseTime(data['scheduledDate']),
      durationMinutes: parsedDuration,
      paperStructure: data['paperStructure']?.toString() ?? '',
      syllabusTopics: topics,
      hints: data['hints']?.toString() ?? '',
      instructions: data['instructions']?.toString() ?? '',
      status: data['status']?.toString() ?? 'upcoming',
      createdAt: parseTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subject': subject,
      'examYear': examYear,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'durationMinutes': durationMinutes,
      'paperStructure': paperStructure,
      'syllabusTopics': syllabusTopics,
      'hints': hints,
      'instructions': instructions,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UpcomingPaper copyWith({
    String? id,
    String? title,
    String? subject,
    String? examYear,
    DateTime? scheduledDate,
    int? durationMinutes,
    String? paperStructure,
    List<String>? syllabusTopics,
    String? hints,
    String? instructions,
    String? status,
    DateTime? createdAt,
  }) {
    return UpcomingPaper(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      examYear: examYear ?? this.examYear,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      paperStructure: paperStructure ?? this.paperStructure,
      syllabusTopics: syllabusTopics ?? this.syllabusTopics,
      hints: hints ?? this.hints,
      instructions: instructions ?? this.instructions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
