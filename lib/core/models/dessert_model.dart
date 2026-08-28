import 'package:cloud_firestore/cloud_firestore.dart';

enum DessertStatus { pending, approved, rejected }
enum DessertType { text, image, file, mixed }

class DessertModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentPhone;
  final String? subject;
  final String? caption;   // Text content from WhatsApp message
  final List<String> mediaUrls; // Image/file URLs stored in Firebase Storage
  final DessertType type;
  final DessertStatus status;
  final String? adminFeedback;
  final String? reviewedBy;
  final int creditsAwarded;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String whatsappMessageId; // Track original WA message

  const DessertModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    this.subject,
    this.caption,
    this.mediaUrls = const [],
    required this.type,
    required this.status,
    this.adminFeedback,
    this.reviewedBy,
    this.creditsAwarded = 0,
    required this.submittedAt,
    this.reviewedAt,
    required this.whatsappMessageId,
  });

  bool get isPending => status == DessertStatus.pending;
  bool get isApproved => status == DessertStatus.approved;
  bool get isRejected => status == DessertStatus.rejected;

  factory DessertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DessertModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'Unknown',
      studentPhone: data['studentPhone'] ?? '',
      subject: data['subject'],
      caption: data['caption'],
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      type: _parseType(data['type']),
      status: _parseStatus(data['status']),
      adminFeedback: data['adminFeedback'],
      reviewedBy: data['reviewedBy'],
      creditsAwarded: data['creditsAwarded'] ?? 0,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      whatsappMessageId: data['whatsappMessageId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'subject': subject,
      'caption': caption,
      'mediaUrls': mediaUrls,
      'type': type.name,
      'status': status.name,
      'adminFeedback': adminFeedback,
      'reviewedBy': reviewedBy,
      'creditsAwarded': creditsAwarded,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'whatsappMessageId': whatsappMessageId,
    };
  }

  DessertModel copyWith({
    DessertStatus? status,
    String? adminFeedback,
    String? reviewedBy,
    int? creditsAwarded,
    DateTime? reviewedAt,
  }) {
    return DessertModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      studentPhone: studentPhone,
      subject: subject,
      caption: caption,
      mediaUrls: mediaUrls,
      type: type,
      status: status ?? this.status,
      adminFeedback: adminFeedback ?? this.adminFeedback,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      creditsAwarded: creditsAwarded ?? this.creditsAwarded,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      whatsappMessageId: whatsappMessageId,
    );
  }

  static DessertStatus _parseStatus(String? s) {
    switch (s) {
      case 'approved': return DessertStatus.approved;
      case 'rejected': return DessertStatus.rejected;
      default: return DessertStatus.pending;
    }
  }

  static DessertType _parseType(String? t) {
    switch (t) {
      case 'image': return DessertType.image;
      case 'file': return DessertType.file;
      case 'mixed': return DessertType.mixed;
      default: return DessertType.text;
    }
  }
}
