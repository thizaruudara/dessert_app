import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, admin }

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String? email;
  final UserRole role;
  final int credits;
  final String? studentId;
  final String? avatarUrl;
  final String? examYear;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    required this.credits,
    this.email,
    this.studentId,
    this.avatarUrl,
    this.examYear,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isStudent => role == UserRole.student;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.student,
      credits: data['credits'] ?? 0,
      studentId: data['studentId'],
      avatarUrl: data['avatarUrl'] ?? data['photoUrl'],
      examYear: data['examYear']?.toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'role': role.name,
      'credits': credits,
      'studentId': studentId,
      'avatarUrl': avatarUrl,
      'photoUrl': avatarUrl,
      'examYear': examYear,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    UserRole? role,
    int? credits,
    String? avatarUrl,
    String? studentId,
    String? examYear,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phone: phone,
      email: email ?? this.email,
      role: role ?? this.role,
      credits: credits ?? this.credits,
      studentId: studentId ?? this.studentId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      examYear: examYear ?? this.examYear,
      createdAt: createdAt,
    );
  }
}
