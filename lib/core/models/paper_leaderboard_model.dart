import 'package:cloud_firestore/cloud_firestore.dart';

class PaperLeaderboardEntry {
  final int rank;
  final String studentId;
  final String studentName;
  final String studentPhone;
  final String indexNumber;
  final double marks;
  final String grade; // 'A', 'B', 'C', 'S', 'F'
  final String remarks;
  final String? avatarUrl;

  PaperLeaderboardEntry({
    required this.rank,
    this.studentId = '',
    required this.studentName,
    this.studentPhone = '',
    this.indexNumber = '',
    required this.marks,
    this.grade = 'A',
    this.remarks = '',
    this.avatarUrl,
  });

  factory PaperLeaderboardEntry.fromMap(Map<dynamic, dynamic> map) {
    double parseMarks(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseRank(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 1;
      return 1;
    }

    return PaperLeaderboardEntry(
      rank: parseRank(map['rank']),
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? 'Scholar',
      studentPhone: map['studentPhone']?.toString() ?? '',
      indexNumber: map['indexNumber']?.toString() ?? '',
      marks: parseMarks(map['marks']),
      grade: map['grade']?.toString() ?? 'A',
      remarks: map['remarks']?.toString() ?? '',
      avatarUrl: map['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rank': rank,
      'studentId': studentId,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'indexNumber': indexNumber,
      'marks': marks,
      'grade': grade,
      'remarks': remarks,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }

  PaperLeaderboardEntry copyWith({
    int? rank,
    String? studentId,
    String? studentName,
    String? studentPhone,
    String? indexNumber,
    double? marks,
    String? grade,
    String? remarks,
    String? avatarUrl,
  }) {
    return PaperLeaderboardEntry(
      rank: rank ?? this.rank,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhone: studentPhone ?? this.studentPhone,
      indexNumber: indexNumber ?? this.indexNumber,
      marks: marks ?? this.marks,
      grade: grade ?? this.grade,
      remarks: remarks ?? this.remarks,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class PaperLeaderboard {
  final String id;
  final String paperTitle;
  final String subject;
  final String examYear;
  final String paperDate;
  final double totalMarks;
  final DateTime publishedAt;
  final List<PaperLeaderboardEntry> entries;

  PaperLeaderboard({
    required this.id,
    required this.paperTitle,
    required this.subject,
    required this.examYear,
    required this.paperDate,
    this.totalMarks = 100.0,
    required this.publishedAt,
    required this.entries,
  });

  factory PaperLeaderboard.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final Map<String, dynamic> data = (rawData is Map)
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    double parseTotal(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 100.0;
      return 100.0;
    }

    final rawEntries = data['entries'];
    final List<PaperLeaderboardEntry> parsedEntries = [];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        if (item is Map) {
          parsedEntries.add(PaperLeaderboardEntry.fromMap(item));
        }
      }
    }
    parsedEntries.sort((a, b) => a.rank.compareTo(b.rank));

    return PaperLeaderboard(
      id: doc.id,
      paperTitle: data['paperTitle']?.toString() ?? 'Paper Evaluation Leaderboard',
      subject: data['subject']?.toString() ?? 'Physics',
      examYear: data['examYear']?.toString() ?? '2027 A/L',
      paperDate: data['paperDate']?.toString() ?? '',
      totalMarks: parseTotal(data['totalMarks']),
      publishedAt: parseTime(data['publishedAt']),
      entries: parsedEntries,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paperTitle': paperTitle,
      'subject': subject,
      'examYear': examYear,
      'paperDate': paperDate,
      'totalMarks': totalMarks,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'entries': entries.map((e) => e.toMap()).toList(),
    };
  }
}
