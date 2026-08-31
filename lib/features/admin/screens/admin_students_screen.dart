import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/user_model.dart';
import '../../../core/theme/app_theme.dart';

class AdminStudentsScreen extends StatelessWidget {
  const AdminStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.textMuted)),
            );
          }
          final docs = snap.data?.docs ?? [];
          final students = docs
              .map((d) => UserModel.fromFirestore(d))
              .toList()
            ..sort((a, b) => b.credits.compareTo(a.credits));

          if (students.isEmpty) {
            return const Center(
              child: Text('No students registered yet', style: TextStyle(color: AppColors.textMuted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (_, i) {
              return _StudentCard(user: students[i], rank: i + 1);
            },
          );
        },
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final UserModel user;
  final int rank;
  const _StudentCard({required this.user, required this.rank});

  @override
  Widget build(BuildContext context) {
    final medalEmoji = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '#$rank';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rank <= 3 ? AppColors.gold.withOpacity(0.06) : AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank <= 3 ? AppColors.gold.withOpacity(0.3) : AppColors.darkBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              rank <= 3 ? medalEmoji : '#$rank',
              style: TextStyle(
                fontSize: rank <= 3 ? 24 : 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(user.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${user.credits} pts',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
