import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/dessert_model.dart';
import '../../../core/widgets/media_image_view.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../desserts/providers/desserts_provider.dart';
import '../../credits/providers/credits_provider.dart';
import '../widgets/dessert_list_tile.dart';
import '../widgets/student_progress_chart.dart';
import '../widgets/exam_countdown_widget.dart';
import '../widgets/daily_quests_widget.dart';
import '../widgets/trophy_room_sheet.dart';
import '../../../core/models/upcoming_paper_model.dart';
import '../../../core/services/paper_leaderboard_service.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String? _lastListenedUid;

  @override
  void initState() {
    super.initState();
    _checkAndListen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndListen();
  }

  void _checkAndListen() {
    final auth = context.read<AuthProvider>();
    if (auth.user != null && auth.user!.uid != _lastListenedUid) {
      _lastListenedUid = auth.user!.uid;
      context.read<DessertsProvider>().listenToStudentDesserts(
            auth.user!.uid,
            studentPhone: auth.user!.phone,
          );
      context.read<CreditsProvider>().updateCredits(auth.user!.credits);
    }
  }

  Future<void> _openWhatsAppTutor() async {
    final appUri = Uri.parse('tg://resolve?domain=edupeakbot&start=ask_tutor');
    final webUri = Uri.parse('https://t.me/edupeakbot?start=ask_tutor');
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final desserts = context.watch<DessertsProvider>();
    final credits = context.watch<CreditsProvider>();
    final user = auth.user;

    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Scholar';
    final examYear = user?.examYear ?? '2027 A/L';
    final totalCredits = user?.credits ?? credits.totalCredits;
    final approvedCount = desserts.desserts.where((d) => d.isApproved).length;
    final pendingCount = desserts.pendingDesserts.length;
    final totalCount = desserts.desserts.length;

    // XP calculation: 100 XP per Level
    final currentLevel = (totalCredits ~/ 100) + 1;
    final nextLevelXp = currentLevel * 100;
    final currentLevelProgress = (totalCredits % 100) / 100.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          if (auth.user != null) {
            await context.read<DessertsProvider>().refreshStudentDesserts(
                  auth.user!.uid,
                  studentPhone: auth.user!.phone,
                );
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Gen-Z Hero Header ────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E3A8A),
                      Color(0xFF2563EB),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Avatar, Greeting, Streak & Profile Action
                    Row(
                      children: [
                        // Avatar with glowing ring
                        GestureDetector(
                          onTap: () => context.go('/student/profile'),
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF1E293B),
                              child: ClipOval(
                                child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                                    ? MediaImageView(
                                        url: user.avatarUrl!,
                                        fit: BoxFit.cover,
                                        width: 48,
                                        height: 48,
                                      )
                                    : const Icon(Icons.person, color: Colors.white, size: 26),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name and Exam Year Tag
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 16),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '🎯 $examYear Target',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Badges Trophy Room Pill
                        GestureDetector(
                          onTap: () {
                            TrophyRoomSheet.show(
                              context,
                              totalCredits: totalCredits,
                              approvedSubmissions: approvedCount,
                              totalSubmissions: totalCount,
                              streakDays: 3,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🏆', style: TextStyle(fontSize: 13)),
                                SizedBox(width: 4),
                                Text(
                                  'Badges',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Streak Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFFF8800)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔥', style: TextStyle(fontSize: 13)),
                              SizedBox(width: 4),
                              Text(
                                '3d',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Gamified XP / Level Card ────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Level $currentLevel Cadet',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${totalCredits % 100} / 100 XP to Level ${currentLevel + 1}',
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Total XP badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1A000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$totalCredits pts',
                                  style: const TextStyle(
                                    color: Color(0xFF1E3A8A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Shimmer Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  width: double.infinity,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Container(
                                      height: 8,
                                      width: constraints.maxWidth * currentLevelProgress.clamp(0.05, 1.0),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF38BDF8), Color(0xFF60A5FA), Color(0xFF818CF8)],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Live A/L Exam Countdown Widget ──────────────────
                    ExamCountdownWidget(examYear: examYear),
                  ],
                ),
              ),
            ),

            // ── Main Body Content ─────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Quick Study Power-Ups ──────────────────────────
                  Row(
                    children: [
                      // Daily MCQ Sprint
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.bolt_rounded,
                          title: 'Daily MCQ',
                          subtitle: '5 Sprints 🔥',
                          gradient: const [Color(0xFFEA580C), Color(0xFFC2410C)],
                          onTap: () {
                            HapticFeedbackService.light();
                            context.push('/student/sprint');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Ask AI Tutor
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'AI Tutor',
                          subtitle: 'Instant 💬',
                          gradient: const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                          onTap: _openWhatsAppTutor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Drop Homework
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.camera_alt_outlined,
                          title: 'Submit HW',
                          subtitle: 'Earn XP 🚀',
                          gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          onTap: () {
                            HapticFeedbackService.light();
                            context.go('/student/desserts');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Leaderboard
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.emoji_events_outlined,
                          title: 'Ranks',
                          subtitle: 'Podium 👑',
                          gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                          onTap: () {
                            HapticFeedbackService.light();
                            context.go('/student/leaderboard');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Daily 5-MCQ Sprint Spotlight Card ───────────────
                  _buildDailyMcqSprintSpotlight(user?.uid ?? '', examYear),
                  const SizedBox(height: 12),

                  // ── Daily Quests & Mystery Reward Box ───────────────
                  DailyQuestsWidget(
                    totalSubmissions: totalCount,
                    onOpenLeaderboard: () => context.go('/student/leaderboard'),
                  ),
                  const SizedBox(height: 12),

                  // ── Upcoming Papers & Hints Spotlight ───────────────
                  _buildUpcomingPaperSpotlight(examYear),
                  const SizedBox(height: 12),

                  // ── Learning Progress & Line Chart ──────────────────
                  StudentProgressChart(
                    desserts: desserts.desserts,
                    totalCredits: totalCredits,
                  ),
                  const SizedBox(height: 20),

                  // ── Stats Row ──────────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        label: 'Submitted',
                        value: '$totalCount',
                        icon: Icons.send_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Approved',
                        value: '$approvedCount',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'In Review',
                        value: '$pendingCount',
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Recent Submissions Header ──────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity 📝',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/student/desserts'),
                        child: const Text('View all', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),

            // ── Recent Submissions Feed ───────────────────────────
            if (desserts.loading && desserts.desserts.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
              )
            else if (desserts.desserts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: _EmptyState(
                    onSubmit: () => context.go('/student/desserts'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final d = desserts.desserts.take(6).toList()[i];
                      return DessertListTile(
                        dessert: d,
                        onTap: () => context.push('/student/dessert/${d.id}'),
                      );
                    },
                    childCount: desserts.desserts.take(6).length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMcqSprintSpotlight(String studentUid, String studentExamYear) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('daily_sprints')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        final allDocs = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final aDate = a.data()['targetDate']?.toString() ?? '';
            final bDate = b.data()['targetDate']?.toString() ?? '';
            return bDate.compareTo(aDate);
          });

        if (allDocs.isEmpty) return const SizedBox.shrink();

        // Filter matching student exam year
        final matchingDocs = allDocs.where((d) {
          final docExamYear = d.data()['examYear']?.toString();
          if (docExamYear == null || docExamYear.isEmpty || docExamYear == 'All Batches') return true;
          if (studentExamYear.isEmpty) return true;
          return docExamYear.toLowerCase().trim() == studentExamYear.toLowerCase().trim();
        }).toList();

        final docs = matchingDocs.isNotEmpty ? matchingDocs : allDocs;

        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        // Match today's sprint, or show the latest available sprint
        final activeDoc = docs.firstWhere(
          (d) => d.data()['targetDate'] == todayStr,
          orElse: () => docs.first,
        );

        final data = activeDoc.data();
        final targetDate = data['targetDate']?.toString() ?? todayStr;
        final title = data['title']?.toString() ?? 'Daily MCQ Sprint';
        final unit = data['unit']?.toString() ?? 'General Physics';
        final questions = (data['questions'] as List<dynamic>?) ?? [];
        final isToday = targetDate == todayStr;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('sprint_attempts')
              .where('date', isEqualTo: targetDate)
              .where('studentId', isEqualTo: studentUid)
              .limit(1)
              .snapshots(),
          builder: (context, attemptSnap) {
            final attempts = attemptSnap.data?.docs ?? [];
            final hasAttempted = attempts.isNotEmpty;
            final attemptData = hasAttempted ? attempts.first.data() : null;
            final score = (attemptData?['score'] as num?)?.toInt() ?? 0;
            final total = (attemptData?['totalQuestions'] as num?)?.toInt() ?? (questions.isNotEmpty ? questions.length : 5);
            final xpEarned = (attemptData?['xpEarned'] as num?)?.toInt() ?? (score * 10);

            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: hasAttempted
                      ? const Color(0xFF10B981).withOpacity(0.5)
                      : const Color(0xFFF59E0B).withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasAttempted ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    HapticFeedbackService.light();
                    context.push('/student/sprint?date=$targetDate');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🔥', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(
                                    isToday ? 'TODAY\'S 5-MCQ SPRINT' : 'DAILY MCQ SPRINT',
                                    style: const TextStyle(
                                      color: Color(0xFFFBBF24),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                targetDate,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Sprint Title
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Subtitle
                        Text(
                          '⚡ ${questions.length} Quick Questions • Unit: $unit',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 14),

                        // Action / Status Area
                        if (hasAttempted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Completed! Score: $score / $total (+$xpEarned XP)',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'Review ➔',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Start Daily MCQ Sprint (+50 XP) ➔',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingPaperSpotlight(String examYear) {
    return StreamBuilder<List<UpcomingPaper>>(
      stream: PaperLeaderboardService().streamUpcomingPapers(examYear: examYear),
      builder: (context, snapshot) {
        final papers = snapshot.data ?? [];
        if (papers.isEmpty) return const SizedBox.shrink();
        final paper = papers.first;
        final hasHints = paper.hints.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedbackService.light();
                context.go('/student/papers');
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔮', style: TextStyle(fontSize: 12)),
                              SizedBox(width: 4),
                              Text(
                                'UPCOMING PAPER',
                                style: TextStyle(
                                  color: Color(0xFFA5B4FC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            paper.subject,
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      paper.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${paper.examYear} • ${paper.durationMinutes} Minutes Exam',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    if (hasHints) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Hint: ${paper.hints}',
                                style: const TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [
                        Text(
                          'View Scope & All Hints ➔',
                          style: TextStyle(
                            color: Color(0xFF818CF8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSubmit;
  const _EmptyState({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.backgroundSoft,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🚀', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ready to start your streak?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Send your homework photos to EduPeak on WhatsApp to earn your first XP and rank up!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Submit Homework 📸'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}
