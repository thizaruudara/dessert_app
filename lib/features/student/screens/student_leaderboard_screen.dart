import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // Track expanded paper leaderboard IDs. The latest board (index 0) will be expanded by default.
  final Set<String> _expandedBoardIds = {};
  bool _hasInitializedExpandedBoard = false;

  // Admin Exam Year filter selection
  String _adminSelectedBatch = 'All Batches';
  final List<String> _batchFilterOptions = const [
    'All Batches',
    '2024 A/L',
    '2025 A/L',
    '2026 A/L',
    '2027 A/L',
    '2028 A/L',
    '2029 A/L',
  ];

  final PaperLeaderboardService _leaderboardService = PaperLeaderboardService();

  final List<Map<String, dynamic>> _leagues = const [
    {'name': 'All Scholars', 'emoji': '🌐', 'minXp': 0, 'maxXp': 999999, 'color': Color(0xFF227AFF)},
    {'name': 'Diamond', 'emoji': '💎', 'minXp': 500, 'maxXp': 999999, 'color': Color(0xFF06B6D4)},
    {'name': 'Gold', 'emoji': '🥇', 'minXp': 250, 'maxXp': 499, 'color': Color(0xFFF59E0B)},
    {'name': 'Silver', 'emoji': '🥈', 'minXp': 100, 'maxXp': 249, 'color': Color(0xFF94A3B8)},
    {'name': 'Bronze', 'emoji': '🥉', 'minXp': 0, 'maxXp': 99, 'color': Color(0xFFB45309)},
  ];

  bool _matchesExamYear(String? studentYear, String? targetYear) {
    if (studentYear == null || studentYear.trim().isEmpty) return false;
    if (targetYear == null || targetYear.trim().isEmpty) return true;
    if (targetYear == 'All' || targetYear == 'All Batches') return true;
    final sClean = studentYear.replaceAll(' ', '').toUpperCase();
    final tClean = targetYear.replaceAll(' ', '').toUpperCase();
    if (sClean == tClean) return true;
    if (sClean.contains(tClean) || tClean.contains(sClean)) return true;
    final sDigits = RegExp(r'\b(20\d\d)\b').firstMatch(studentYear)?.group(1);
    final tDigits = RegExp(r'\b(20\d\d)\b').firstMatch(targetYear)?.group(1);
    if (sDigits != null && tDigits != null && sDigits == tDigits) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.uid;
    final currentStudent = auth.userModel;
    final isAdmin = auth.isAdmin;
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
                ? _buildDessertLeaderboard(
                    currentUserId: currentUserId,
                    currentStudent: currentStudent,
                    isAdmin: isAdmin,
                    isDark: isDark,
                  )
                : _buildPaperLeaderboard(
                    currentStudent: currentStudent,
                    currentUserId: currentUserId,
                    isAdmin: isAdmin,
                    isDark: isDark,
                  ),
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

  // ── Batch Selector Chips (For Admin to inspect each exam year separately) ──
  Widget _buildBatchSelector({
    required String selectedBatch,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _batchFilterOptions.length,
        itemBuilder: (context, index) {
          final batch = _batchFilterOptions[index];
          final isSelected = selectedBatch == batch;
          return GestureDetector(
            onTap: () {
              HapticFeedbackService.selection();
              onSelected(batch);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
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
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      batch,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Student Batch Header Banner ───────────────────────────────────────────
  Widget _buildStudentBatchBanner({
    required String? batch,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final displayBatch = (batch != null && batch.trim().isNotEmpty) ? batch : 'General Batch';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🎓', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              displayBatch,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESSERT LEADERBOARD (XP Leagues, Strictly Batch-Isolated for Students)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDessertLeaderboard({
    required String? currentUserId,
    required UserModel? currentStudent,
    required bool isAdmin,
    required bool isDark,
  }) {
    final activeLeague = _leagues[_selectedLeagueIndex];

    return Column(
      children: [
        // If Admin: Provide batch filter chips to inspect every batch separately
        if (isAdmin)
          _buildBatchSelector(
            selectedBatch: _adminSelectedBatch,
            onSelected: (batch) {
              setState(() => _adminSelectedBatch = batch);
            },
            isDark: isDark,
          )
        else
          // Student: Batch indicator letting them know they are only competing with their peers
          _buildStudentBatchBanner(
            batch: currentStudent?.examYear,
            title: '${currentStudent?.examYear ?? "Your Batch"} Standings',
            subtitle: 'Showing leaderboard for your exam year',
            isDark: isDark,
          ),

        // League Selector Tabs
        Container(
          height: 44,
          margin: const EdgeInsets.only(top: 2, bottom: 4),
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
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

        // Stream Rankings (strictly filtered by Exam Year)
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
                  .toList();

              // ── BATCH ISOLATION LOGIC ─────────────────────────────
              if (isAdmin) {
                // Admin can filter by any selected batch or view all
                if (_adminSelectedBatch != 'All Batches') {
                  allStudents = allStudents.where((u) => _matchesExamYear(u.examYear, _adminSelectedBatch)).toList();
                }
              } else {
                // Students only see peers from their exact exam year
                final studentBatch = currentStudent?.examYear;
                if (studentBatch != null && studentBatch.trim().isNotEmpty) {
                  allStudents = allStudents.where((u) => _matchesExamYear(u.examYear, studentBatch)).toList();
                }
              }

              allStudents.sort((a, b) => b.credits.compareTo(a.credits));

              final minXp = activeLeague['minXp'] as int;
              final maxXp = activeLeague['maxXp'] as int;

              final students = _selectedLeagueIndex == 0
                  ? allStudents
                  : allStudents.where((u) => u.credits >= minXp && u.credits <= maxXp).toList();

              if (students.isEmpty) {
                final currentBatchName = isAdmin
                    ? _adminSelectedBatch
                    : (currentStudent?.examYear ?? 'your batch');
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(activeLeague['emoji'], style: const TextStyle(fontSize: 44)),
                      const SizedBox(height: 10),
                      Text(
                        'No students in $currentBatchName yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Earn XP by submitting study desserts to take the #1 rank!',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              final topThree = students.take(3).toList();

              int currentUserRank = -1;
              UserModel? loggedInUser;
              for (int i = 0; i < students.length; i++) {
                if (students[i].uid == currentUserId) {
                  currentUserRank = i + 1;
                  loggedInUser = students[i];
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
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
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
                  if (currentUserRank > 0 && loggedInUser != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _buildYourRankCapsule(currentUserRank, loggedInUser, isDark),
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
  // PAPER LEADERBOARD (Accordion: Latest Expanded by Default, Filtered by Batch)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPaperLeaderboard({
    required UserModel? currentStudent,
    required String? currentUserId,
    required bool isAdmin,
    required bool isDark,
  }) {
    // Exam Year filter
    final targetExamYear = isAdmin
        ? (_adminSelectedBatch == 'All Batches' ? null : _adminSelectedBatch)
        : currentStudent?.examYear;

    return StreamBuilder<List<PaperLeaderboard>>(
      stream: _leaderboardService.streamPaperLeaderboards(examYear: targetExamYear),
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
          final displayBatch = isAdmin
              ? _adminSelectedBatch
              : (currentStudent?.examYear ?? 'your batch');
          return Column(
            children: [
              if (isAdmin)
                _buildBatchSelector(
                  selectedBatch: _adminSelectedBatch,
                  onSelected: (batch) {
                    setState(() {
                      _adminSelectedBatch = batch;
                      _hasInitializedExpandedBoard = false;
                      _expandedBoardIds.clear();
                    });
                  },
                  isDark: isDark,
                ),
              Expanded(
                child: Center(
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
                          'No Paper Leaderboards for $displayBatch',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
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
                ),
              ),
            ],
          );
        }

        // Auto-expand the latest (first) board by default on first load
        if (!_hasInitializedExpandedBoard && leaderboards.isNotEmpty) {
          _expandedBoardIds.add(leaderboards.first.id);
          _hasInitializedExpandedBoard = true;
        }

        return Column(
          children: [
            // If Admin: show batch filter selector so admin can view each batch separately
            if (isAdmin)
              _buildBatchSelector(
                selectedBatch: _adminSelectedBatch,
                onSelected: (batch) {
                  setState(() {
                    _adminSelectedBatch = batch;
                    _hasInitializedExpandedBoard = false;
                    _expandedBoardIds.clear();
                  });
                },
                isDark: isDark,
              )
            else
              // Student: batch header banner
              _buildStudentBatchBanner(
                batch: currentStudent?.examYear,
                title: '${currentStudent?.examYear ?? "Your Batch"} Paper Results',
                subtitle: 'Official exam evaluations for your batch',
                isDark: isDark,
              ),

            // Multiple leaderboards in expandable accordion cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                itemCount: leaderboards.length,
                itemBuilder: (context, index) {
                  final board = leaderboards[index];
                  final isLatest = index == 0;
                  final isExpanded = _expandedBoardIds.contains(board.id);

                  return _buildPaperAccordionCard(
                    board: board,
                    isLatest: isLatest,
                    isExpanded: isExpanded,
                    currentStudent: currentStudent,
                    currentUserId: currentUserId,
                    isDark: isDark,
                    onToggle: () {
                      HapticFeedbackService.selection();
                      setState(() {
                        if (isExpanded) {
                          _expandedBoardIds.remove(board.id);
                        } else {
                          _expandedBoardIds.add(board.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Expandable Paper Leaderboard Accordion Card ───────────────────────────
  Widget _buildPaperAccordionCard({
    required PaperLeaderboard board,
    required bool isLatest,
    required bool isExpanded,
    required UserModel? currentStudent,
    required String? currentUserId,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    final dateFormat = DateFormat('yyyy MMM dd');
    final entries = board.entries;
    final topThree = entries.take(3).toList();

    // Check if logged-in student has an entry in this leaderboard
    PaperLeaderboardEntry? myEntry;
    final studentPhoneClean = currentStudent?.phone.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final studentName = currentStudent?.name.toLowerCase().trim() ?? '';
    for (final e in entries) {
      final ePhoneClean = e.studentPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if ((currentUserId != null && e.studentId == currentUserId) ||
          (studentPhoneClean.isNotEmpty && ePhoneClean.isNotEmpty && studentPhoneClean == ePhoneClean) ||
          (studentName.isNotEmpty && e.studentName.toLowerCase().trim() == studentName)) {
        myEntry = e;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLatest
              ? const Color(0xFF6366F1).withOpacity(0.6)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isLatest ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLatest
                ? const Color(0xFF6366F1).withOpacity(0.08)
                : const Color(0x060F172A),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tappable Header ───────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(20),
              bottom: isExpanded ? Radius.zero : const Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Tags Row
                  Row(
                    children: [
                      // Subject & Batch Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⚡ ${board.subject} • ${board.examYear}',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Latest Badge if newest board
                      if (isLatest) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✨ LATEST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      Text(
                        dateFormat.format(board.publishedAt),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),

                      const Spacer(),

                      // Animated Chevron
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: isExpanded ? 0.5 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Paper Title
                  Text(
                    board.paperTitle,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Meta Info Pills
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          'Max: ${board.totalMarks.toInt()} Marks',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entries.length} Candidates',
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // If logged-in student has result
                      if (myEntry != null) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                'You: #${myEntry.rank} (${myEntry.marks.toInt()} pts)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Collapsed Quick Winner Snippet
                  if (!isExpanded && entries.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Text('👑', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Rank 1: ${entries.first.studentName} (${entries.first.marks.toInt()} marks - ${entries.first.grade})',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            'Expand ▾',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expanded Content (Podium & Candidate Rankings) ────────
          if (isExpanded) ...[
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top 3 Podium
                  if (topThree.length >= 2) ...[
                    _buildPaperPodiumSection(topThree, board.totalMarks, isDark),
                    const SizedBox(height: 16),
                  ],

                  // Table Header
                  Row(
                    children: [
                      const Text(
                        'Full Candidate Rankings',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                      const Spacer(),
                      Text(
                        '${entries.length} ranked',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Candidate Rank List
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('No candidate records published yet.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    ...entries.map((entry) {
                      final isCurrent = myEntry != null &&
                          entry.rank == myEntry.rank &&
                          entry.studentName == myEntry.studentName;

                      return _buildPaperRankTile(
                        entry: entry,
                        totalMarks: board.totalMarks,
                        isCurrentUser: isCurrent,
                        isDark: isDark,
                      );
                    }),

                  // Sticky User Rank Capsule inside this paper
                  if (myEntry != null) ...[
                    const SizedBox(height: 12),
                    _buildYourPaperRankCapsule(myEntry, board.totalMarks, isDark),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
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
