import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/media_image_view.dart';
import '../../auth/providers/auth_provider.dart';

class StudentLeaderboardScreen extends StatefulWidget {
  const StudentLeaderboardScreen({super.key});

  @override
  State<StudentLeaderboardScreen> createState() => _StudentLeaderboardScreenState();
}

class _StudentLeaderboardScreenState extends State<StudentLeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().user?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Leaderboard 🏆'),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .orderBy('credits', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('No students ranked yet', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  const Text('Submit your desserts to earn credits!', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          }

          final students = snap.data!.docs
              .map((d) => UserModel.fromFirestore(d))
              .where((u) => u.name.isNotEmpty && !u.name.startsWith('Student ('))
              .toList();

          if (students.isEmpty) {
            return const Center(child: Text('No active student rankings'));
          }

          final topThree = students.take(3).toList();
          final remaining = students.length > 3 ? students.sublist(3) : <UserModel>[];

          // Find current user's rank
          int currentUserRank = -1;
          UserModel? currentStudent;
          for (int i = 0; i < students.length; i++) {
            if (students[i].uid == currentUserId) {
              currentUserRank = i + 1;
              currentStudent = students[i];
              break;
            }
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── Top 3 Podium Card ───────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: _buildPodiumSection(topThree),
                    ),
                  ),

                  // ── Section Title ──────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'All Rankings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${students.length} Students',
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Ranked Students List ───────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index < 3) {
                            return _buildRankTile(students[index], index + 1, currentUserId);
                          }
                          final student = remaining[index - 3];
                          return _buildRankTile(student, index + 1, currentUserId);
                        },
                        childCount: students.length,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Sticky "Your Rank" Bottom Capsule ──────────────
              if (currentUserRank > 0 && currentStudent != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: _buildYourRankCapsule(currentUserRank, currentStudent),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodiumSection(List<UserModel> topThree) {
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('✨', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'Top Achievers',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              SizedBox(width: 6),
              Text('✨', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 2nd Place
              if (second != null)
                _buildPodiumColumn(second, 2, 70, const Color(0xFF94A3B8), '🥈'),
              // 1st Place (Center & Highest)
              if (first != null)
                _buildPodiumColumn(first, 1, 95, AppColors.gold, '👑'),
              // 3rd Place
              if (third != null)
                _buildPodiumColumn(third, 3, 55, const Color(0xFFB45309), '🥉'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(UserModel user, int rank, double podiumHeight, Color color, String crownEmoji) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown / Rank Icon
        Text(crownEmoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),

        // Avatar with Border
        Container(
          width: rank == 1 ? 58 : 48,
          height: rank == 1 ? 58 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: rank == 1 ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                ? MediaImageView(url: user.avatarUrl!, fit: BoxFit.cover)
                : Container(
                    color: color.withOpacity(0.15),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '👤',
                        style: TextStyle(
                          fontSize: rank == 1 ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),

        // Name
        SizedBox(
          width: 85,
          child: Text(
            user.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: rank == 1 ? 13 : 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),

        // Points
        Text(
          '${user.credits} pts',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),

        // Podium Base
        Container(
          width: 75,
          height: podiumHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.2),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: rank == 1 ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankTile(UserModel student, int rank, String? currentUserId) {
    final isCurrentUser = student.uid == currentUserId;

    Color rankColor;
    if (rank == 1) {
      rankColor = AppColors.gold;
    } else if (rank == 2) {
      rankColor = const Color(0xFF94A3B8);
    } else if (rank == 3) {
      rankColor = const Color(0xFFB45309);
    } else {
      rankColor = AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.backgroundSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? AppColors.primary : AppColors.border,
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: isCurrentUser
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
          ),

          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isCurrentUser ? AppColors.primary : AppColors.border),
            ),
            child: ClipOval(
              child: (student.avatarUrl != null && student.avatarUrl!.isNotEmpty)
                  ? MediaImageView(url: student.avatarUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: Center(
                        child: Text(
                          student.name.isNotEmpty ? student.name[0].toUpperCase() : '👤',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  rank <= 3 ? '⭐ Top Scholar' : (student.credits > 200 ? '🔥 Distinction' : '📚 Active Learner'),
                  style: TextStyle(
                    fontSize: 11,
                    color: rank <= 3 ? AppColors.gold : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Credits Awarded
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${student.credits}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourRankCapsule(int rank, UserModel student) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Your Rank #$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Keep submitting homework to climb the ranks!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Text(
            '${student.credits} pts',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
