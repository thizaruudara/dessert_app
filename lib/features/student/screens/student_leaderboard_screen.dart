import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/paper_leaderboard_model.dart';
import '../../../core/services/paper_leaderboard_service.dart';
import '../../../core/widgets/media_image_view.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../auth/providers/auth_provider.dart';

class StudentLeaderboardScreen extends StatefulWidget {
  const StudentLeaderboardScreen({super.key});

  @override
  State<StudentLeaderboardScreen> createState() => _StudentLeaderboardScreenState();
}

class _StudentLeaderboardScreenState extends State<StudentLeaderboardScreen> {
  // 0: Dessert Leaderboard, 1: Paper Leaderboard
  int _selectedBoardType = 0;
  int _selectedLeagueIndex = 0;
  String? _selectedPaperLeaderboardId;

  final PaperLeaderboardService _leaderboardService = PaperLeaderboardService();

  final List<Map<String, dynamic>> _leagues = const [
    {'name': 'All Scholars', 'emoji': '🌐', 'minXp': 0, 'maxXp': 999999, 'color': Color(0xFF227AFF)},
    {'name': 'Diamond', 'emoji': '💎', 'minXp': 500, 'maxXp': 999999, 'color': Color(0xFF06B6D4)},
    {'name': 'Gold', 'emoji': '🥇', 'minXp': 250, 'maxXp': 499, 'color': Color(0xFFF59E0B)},
    {'name': 'Silver', 'emoji': '🥈', 'minXp': 100, 'maxXp': 249, 'color': Color(0xFF94A3B8)},
    {'name': 'Bronze', 'emoji': '🥉', 'minXp': 0, 'maxXp': 99, 'color': Color(0xFFB45309)},
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.uid;
    final currentStudent = auth.userModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : AppColors.background,
      appBar: AppBar(
        title: Text(
          _selectedBoardType == 0 ? 'Dessert Leaderboard 🧁' : 'Paper Leaderboard 📝',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF111827) : AppColors.surface,
      ),
      body: Column(
        children: [
          // ── Segmented Control: Dessert vs Paper ─────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildBoardTabButton(
                    index: 0,
                    title: '🧁 Dessert Leaderboard',
                    subtitle: 'XP & Activity Leagues',
                    isSelected: _selectedBoardType == 0,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildBoardTabButton(
                    index: 1,
                    title: '📝 Paper Leaderboard',
                    subtitle: 'Exam Marks & Ranks',
                    isSelected: _selectedBoardType == 1,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Body: Dessert Board or Paper Board ────────────
          Expanded(
            child: _selectedBoardType == 0
                ? _buildDessertLeaderboard(currentUserId, isDark)
                : _buildPaperLeaderboard(currentStudent, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardTabButton({
    required int index,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedbackService.selection();
        setState(() => _selectedBoardType = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF227AFF) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? const Color(0xFF227AFF) : Colors.black).withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primary)
                    : (isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white70 : AppColors.textSecondary)
                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESSERT LEADERBOARD (Original XP Leagues)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDessertLeaderboard(String? currentUserId, bool isDark) {
    final activeLeague = _leagues[_selectedLeagueIndex];

    return Column(
      children: [
        // League Selector Tabs
        Container(
          height: 44,
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _leagues.length,
            itemBuilder: (context, index) {
              final league = _leagues[index];
              final isSelected = _selectedLeagueIndex == index;
              final Color leagueColor = league['color'];

              return GestureDetector(
                onTap: () {
                  HapticFeedbackService.selection();
                  setState(() => _selectedLeagueIndex = index);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? leagueColor.withOpacity(0.18)
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? leagueColor
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: leagueColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(league['emoji'], style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        league['name'],
                        style: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.white : leagueColor)
                              : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Weekly Reset Banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withOpacity(0.12),
                const Color(0xFF227AFF).withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Text('⚡', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Weekly League ends in 2d 14h • Top 5 Promoted 🟢',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stream Rankings
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No students ranked yet', style: TextStyle(color: AppColors.textMuted)),
                );
              }

              var allStudents = snap.data!.docs
                  .map((d) => UserModel.fromFirestore(d))
                  .where((u) {
                    if (u.isAdmin) return false;
                    final cleanPhone = u.phone.replaceAll(RegExp(r'[^0-9]'), '');
                    if (cleanPhone.contains('711388991')) return false;
                    return u.name.isNotEmpty && !u.name.startsWith('Student (');
                  })
                  .toList()
                ..sort((a, b) => b.credits.compareTo(a.credits));

              final minXp = activeLeague['minXp'] as int;
              final maxXp = activeLeague['maxXp'] as int;

              final students = _selectedLeagueIndex == 0
                  ? allStudents
                  : allStudents.where((u) => u.credits >= minXp && u.credits <= maxXp).toList();

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(activeLeague['emoji'], style: const TextStyle(fontSize: 44)),
                      const SizedBox(height: 10),
                      Text(
                        'No students in ${activeLeague['name']} League yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Earn more XP credits to enter this tier!',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                );
              }

              final topThree = students.take(3).toList();

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
                      // Podium Section
                      if (_selectedLeagueIndex == 0 && topThree.length >= 2)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: _buildPodiumSection(topThree, isDark),
                          ),
                        ),

                      // Ranked List
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final student = students[index];
                              final rank = index + 1;
                              final isCurrentUser = student.uid == currentUserId;
                              final isPromoted = rank <= 5;

                              return _buildRankTile(
                                student: student,
                                rank: rank,
                                isCurrentUser: isCurrentUser,
                                isPromoted: isPromoted,
                                isDark: isDark,
                              );
                            },
                            childCount: students.length,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Sticky Your Rank Capsule
                  if (currentUserRank > 0 && currentStudent != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _buildYourRankCapsule(currentUserRank, currentStudent, isDark),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAPER LEADERBOARD (Marks, Ranks, Exam Evaluations)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPaperLeaderboard(UserModel? currentStudent, bool isDark) {
    return StreamBuilder<List<PaperLeaderboard>>(
      stream: _leaderboardService.streamPaperLeaderboards(examYear: currentStudent?.examYear),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.textMuted)),
          );
        }

        final leaderboards = snapshot.data ?? [];
        if (leaderboards.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.military_tech_outlined, size: 50, color: Color(0xFF818CF8)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Paper Leaderboards Published Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Official rankings and marks will be published by admins after each paper evaluation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          );
        }

        // Active selected paper
        PaperLeaderboard activeBoard = leaderboards.first;
        if (_selectedPaperLeaderboardId != null) {
          final found = leaderboards.where((b) => b.id == _selectedPaperLeaderboardId);
          if (found.isNotEmpty) activeBoard = found.first;
        }

        final entries = activeBoard.entries;
        final topThree = entries.take(3).toList();

        // Check if current student is in this leaderboard
        PaperLeaderboardEntry? myEntry;
        final studentPhoneClean = currentStudent?.phone.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        final studentName = currentStudent?.name.toLowerCase().trim() ?? '';
        for (final e in entries) {
          final ePhoneClean = e.studentPhone.replaceAll(RegExp(r'[^0-9]'), '');
          if ((currentStudent != null && e.studentId == currentStudent.uid) ||
              (studentPhoneClean.isNotEmpty && ePhoneClean.isNotEmpty && studentPhoneClean == ePhoneClean) ||
              (studentName.isNotEmpty && e.studentName.toLowerCase().trim() == studentName)) {
            myEntry = e;
            break;
          }
        }

        return Column(
          children: [
            // ── Paper Selector Pills ──────────────────────────
            if (leaderboards.length > 1)
              Container(
                height: 44,
                margin: const EdgeInsets.only(top: 4, bottom: 6),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: leaderboards.length,
                  itemBuilder: (context, index) {
                    final board = leaderboards[index];
                    final isSelected = board.id == activeBoard.id;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedbackService.selection();
                        setState(() => _selectedPaperLeaderboardId = board.id);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1).withOpacity(0.18)
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.assignment_outlined, size: 14, color: Color(0xFF818CF8)),
                            const SizedBox(width: 6),
                            Text(
                              board.paperTitle,
                              style: TextStyle(
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF6366F1))
                                    : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ── Paper Details Summary Card ─────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Color(0xFF818CF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeBoard.paperTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${activeBoard.subject} • ${activeBoard.examYear} • Max: ${activeBoard.totalMarks.toInt()} Marks',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entries.length} Candidates',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Paper Podium & Candidates List ──────────────────
            Expanded(
              child: Stack(
                children: [
                  CustomScrollView(
                    slivers: [
                      if (topThree.length >= 2)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: _buildPaperPodiumSection(topThree, activeBoard.totalMarks, isDark),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final entry = entries[index];
                              final isCurrent = myEntry != null && entry.rank == myEntry.rank && entry.studentName == myEntry.studentName;

                              return _buildPaperRankTile(
                                entry: entry,
                                totalMarks: activeBoard.totalMarks,
                                isCurrentUser: isCurrent,
                                isDark: isDark,
                              );
                            },
                            childCount: entries.length,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Sticky Your Rank Pill for Paper
                  if (myEntry != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _buildYourPaperRankCapsule(myEntry, activeBoard.totalMarks, isDark),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaperPodiumSection(List<PaperLeaderboardEntry> topThree, double totalMarks, bool isDark) {
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('🎖️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'Top Exam Performers',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
              SizedBox(width: 6),
              Text('🎖️', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (second != null) _buildPaperPodiumColumn(second, 2, 70, const Color(0xFF94A3B8), '🥈', totalMarks, isDark),
              if (first != null) _buildPaperPodiumColumn(first, 1, 95, const Color(0xFFF59E0B), '👑', totalMarks, isDark),
              if (third != null) _buildPaperPodiumColumn(third, 3, 55, const Color(0xFFB45309), '🥉', totalMarks, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaperPodiumColumn(
    PaperLeaderboardEntry entry,
    int rank,
    double podiumHeight,
    Color color,
    String crownEmoji,
    double totalMarks,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(crownEmoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Container(
          width: rank == 1 ? 58 : 48,
          height: rank == 1 ? 58 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: rank == 1 ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: (entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty)
                ? MediaImageView(url: entry.avatarUrl!, fit: BoxFit.cover)
                : Container(
                    color: color.withOpacity(0.15),
                    child: Center(
                      child: Text(
                        entry.studentName.isNotEmpty ? entry.studentName[0].toUpperCase() : '👤',
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
        const SizedBox(height: 6),
        SizedBox(
          width: 85,
          child: Text(
            entry.studentName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: rank == 1 ? 13 : 11.5,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '${entry.marks.toInt()} / ${totalMarks.toInt()}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Grade ${entry.grade}',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildPaperRankTile({
    required PaperLeaderboardEntry entry,
    required double totalMarks,
    required bool isCurrentUser,
    required bool isDark,
  }) {
    Color gradeColor;
    switch (entry.grade.toUpperCase()) {
      case 'A':
        gradeColor = const Color(0xFF10B981);
        break;
      case 'B':
        gradeColor = const Color(0xFF227AFF);
        break;
      case 'C':
        gradeColor = const Color(0xFFF59E0B);
        break;
      case 'S':
        gradeColor = const Color(0xFF8B5CF6);
        break;
      default:
        gradeColor = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFF6366F1).withOpacity(0.12)
            : (isDark ? const Color(0xFF111827) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF6366F1)
              : (entry.rank <= 3
                  ? const Color(0xFFF59E0B).withOpacity(0.3)
                  : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0))),
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.rank <= 3
                  ? const Color(0xFFF59E0B).withOpacity(0.15)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            ),
            child: Center(
              child: Text(
                entry.rank == 1 ? '🥇' : (entry.rank == 2 ? '🥈' : (entry.rank == 3 ? '🥉' : '${entry.rank}')),
                style: TextStyle(
                  fontSize: entry.rank <= 3 ? 16 : 13,
                  fontWeight: FontWeight.w800,
                  color: entry.rank <= 3 ? const Color(0xFFF59E0B) : (isDark ? Colors.white70 : AppColors.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1E293B),
            child: ClipOval(
              child: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                  ? MediaImageView(url: entry.avatarUrl!, fit: BoxFit.cover, width: 36, height: 36)
                  : Text(entry.studentName.isNotEmpty ? entry.studentName[0].toUpperCase() : '👤',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Remarks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                if (entry.remarks.isNotEmpty)
                  Text(
                    entry.remarks,
                    style: TextStyle(color: gradeColor, fontSize: 10.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Grade Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: gradeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gradeColor.withOpacity(0.4)),
            ),
            child: Text(
              entry.grade,
              style: TextStyle(
                color: gradeColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),

          // Score Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.marks.toStringAsFixed(entry.marks.truncateToDouble() == entry.marks ? 0 : 1)} marks',
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourPaperRankCapsule(PaperLeaderboardEntry entry, double totalMarks, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6366F1)),
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your Standing in this Paper',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Grade ${entry.grade}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '${entry.marks.toInt()} / ${totalMarks.toInt()}',
            style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS (Shared)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPodiumSection(List<UserModel> topThree, bool isDark) {
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        ),
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
                'Top Podium Achievers',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              SizedBox(width: 6),
              Text('✨', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (second != null) _buildPodiumColumn(second, 2, 70, const Color(0xFF94A3B8), '🥈', isDark),
              if (first != null) _buildPodiumColumn(first, 1, 95, const Color(0xFFF59E0B), '👑', isDark),
              if (third != null) _buildPodiumColumn(third, 3, 55, const Color(0xFFB45309), '🥉', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(UserModel user, int rank, double podiumHeight, Color color, String crownEmoji, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(crownEmoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Container(
          width: rank == 1 ? 58 : 48,
          height: rank == 1 ? 58 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: rank == 1 ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
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
        const SizedBox(height: 6),
        SizedBox(
          width: 85,
          child: Text(
            user.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: rank == 1 ? 13 : 11.5,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '${user.credits} pts',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _buildRankTile({
    required UserModel student,
    required int rank,
    required bool isCurrentUser,
    required bool isPromoted,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFF227AFF).withOpacity(0.12)
            : (isDark ? const Color(0xFF111827) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF227AFF)
              : (isPromoted
                  ? const Color(0xFF10B981).withOpacity(0.3)
                  : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0))),
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Rank number badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rank <= 3
                  ? const Color(0xFFF59E0B).withOpacity(0.15)
                  : (isPromoted ? const Color(0xFF10B981).withOpacity(0.12) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
            ),
            child: Center(
              child: Text(
                rank == 1 ? '🥇' : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '$rank')),
                style: TextStyle(
                  fontSize: rank <= 3 ? 16 : 13,
                  fontWeight: FontWeight.w800,
                  color: isPromoted ? const Color(0xFF10B981) : (isDark ? Colors.white70 : AppColors.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1E293B),
            child: ClipOval(
              child: student.avatarUrl != null && student.avatarUrl!.isNotEmpty
                  ? MediaImageView(url: student.avatarUrl!, fit: BoxFit.cover, width: 36, height: 36)
                  : Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '👤',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Tag
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF227AFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                if (isPromoted)
                  const Text(
                    '▲ Promotion Zone',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),

          // Points Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${student.credits} pts',
              style: const TextStyle(
                color: Color(0xFFD97706),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourRankCapsule(int rank, UserModel student, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF227AFF)),
            child: Text(
              '#$rank',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your Standing in this League',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Text(
            '${student.credits} XP',
            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
