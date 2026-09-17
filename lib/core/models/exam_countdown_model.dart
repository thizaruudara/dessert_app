import 'package:cloud_firestore/cloud_firestore.dart';

class ExamCountdownConfig {
  final String id;
  final String examYear;
  final DateTime targetDate;
  final bool isEnabled;
  final String customTitle;
  final String? notes;
  final DateTime? updatedAt;
  final String? updatedBy;

  const ExamCountdownConfig({
    required this.id,
    required this.examYear,
    required this.targetDate,
    this.isEnabled = true,
    this.customTitle = '',
    this.notes,
    this.updatedAt,
    this.updatedBy,
  });

  static String normalizeDocId(String examYear) {
    return examYear
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  factory ExamCountdownConfig.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawDate = data['targetDate'];
    DateTime target;
    if (rawDate is Timestamp) {
      target = rawDate.toDate();
    } else if (rawDate is String) {
      target = DateTime.tryParse(rawDate) ?? DateTime.now().add(const Duration(days: 100));
    } else {
      target = DateTime.now().add(const Duration(days: 100));
    }

    final rawUpdated = data['updatedAt'];
    DateTime? updated;
    if (rawUpdated is Timestamp) {
      updated = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      updated = DateTime.tryParse(rawUpdated);
    }

    return ExamCountdownConfig(
      id: doc.id,
      examYear: data['examYear']?.toString() ?? doc.id,
      targetDate: target,
      isEnabled: data['isEnabled'] is bool ? data['isEnabled'] as bool : true,
      customTitle: data['customTitle']?.toString() ?? '',
      notes: data['notes']?.toString(),
      updatedAt: updated,
      updatedBy: data['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'examYear': examYear,
      'targetDate': Timestamp.fromDate(targetDate),
      'isEnabled': isEnabled,
      'customTitle': customTitle,
      'notes': notes,
      'updatedAt': Timestamp.now(),
      'updatedBy': updatedBy,
    };
  }

  ExamCountdownConfig copyWith({
    String? id,
    String? examYear,
    DateTime? targetDate,
    bool? isEnabled,
    String? customTitle,
    String? notes,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return ExamCountdownConfig(
      id: id ?? this.id,
      examYear: examYear ?? this.examYear,
      targetDate: targetDate ?? this.targetDate,
      isEnabled: isEnabled ?? this.isEnabled,
      customTitle: customTitle ?? this.customTitle,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
