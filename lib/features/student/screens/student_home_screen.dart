import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/dessert_model.dart';
import '../../../core/widgets/media_image_view.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../../core/widgets/ambient_mesh_background.dart';
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

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  String? _lastListenedUid;
  late AnimationController _enterAnimCtrl;

  @override
  void initState() {
    super.initState();
    _checkAndListen();

    // Staggered pop-up entrance animation controller
    _enterAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Trigger pop-up as soon as screen mounts after the splash swap-up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _enterAnimCtrl.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndListen();
  }

  @override
  void dispose() {
    _enterAnimCtrl.dispose();
    super.dispose();
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

  /// Helper to create a staggered pop-up animation for a section
  Widget _buildStaggeredSection({
    required int index,
    required Widget child,
  }) {
    // 8 staggered sections with overlapping spring pops
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _enterAnimCtrl,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    final fadeAnim = CurvedAnimation(
      parent: _enterAnimCtrl,
      curve: Interval(start, (start + 0.22).clamp(0.0, 1.0), curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: _enterAnimCtrl,
      builder: (context, _) {
        final scale = Tween<double>(begin: 0.86, end: 1.0).evaluate(animation);
        final opacity = Tween<double>(begin: 0.0, end: 1.0).evaluate(fadeAnim);
        final offsetY = Tween<double>(begin: 24.0, end: 0.0).evaluate(animation);

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final desserts = context.watch<DessertsProvider>();
    final credits = context.watch<CreditsProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Scholar';
    final examYear = user?.examYear ?? '2027 A/L';
    final totalCredits = user?.credits ?? credits.totalCredits;
    final approvedCount = desserts.desserts.where((d) => d.isApproved).length;
    final pendingCount = desserts.pendingDesserts.length;
    final totalCount = desserts.desserts.length;

    final currentLevel = (totalCredits ~/ 100) + 1;
    final levelProgress = (totalCredits % 100) / 100.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: AmbientMeshBackground(
        baseColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
        child: RefreshIndicator(
          color: const Color(0xFF38BDF8),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          onRefresh: () async {
            if (auth.user != null) {
              await context.read<DessertsProvider>().refreshStudentDesserts(
                    auth.user!.uid,
                    studentPhone: auth.user!.phone,
                  );
            }
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── 1. Minimalist Header Bar ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 14,
                    20,
                    14,
                  ),
                  child: _buildStaggeredSection(
                    index: 0,
                    child: _buildHeader(
                      context: context,
                      isDark: isDark,
                      displayName: displayName,
                      examYear: examYear,
                      totalCredits: totalCredits,
                      userAvatarUrl: user?.avatarUrl,
                      approvedCount: approvedCount,
                      totalCount: totalCount,
                    ),
                  ),
                ),
              ),

              // ── 2. XP & Progress Bar Card ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: _buildStaggeredSection(
                    index: 1,
                    child: _buildXpProgressBar(
                      isDark: isDark,
                      currentLevel: currentLevel,
                      totalCredits: totalCredits,
                      levelProgress: levelProgress,
                    ),
                  ),
                ),
              ),

              // ── 3. Exam Countdown Card ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: _buildStaggeredSection(
                    index: 2,
                    child: ExamCountdownWidget(examYear: examYear),
                  ),
                ),
              ),

              // ── 4. Quick Action Grid (Pill Style) ───────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: _buildStaggeredSection(
                    index: 3,
                    child: _buildQuickActions(context: context, isDark: isDark),
                  ),
                ),
              ),

              // ── 5. Daily MCQ Sprint Spotlight ───────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: _buildStaggeredSection(
                    index: 4,
                    child: _buildDailyMcqSprintSpotlight(user?.uid ?? '', examYear, isDark),
                  ),
                ),
              ),

              // ── 6. Daily Quests ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: _buildStaggeredSection(
                    index: 5,
                    child: DailyQuestsWidget(
                      totalSubmissions: totalCount,
                      onOpenLeaderboard: () => context.go('/student/leaderboard'),
                    ),
                  ),
                ),
              ),

              // ── 7. Upcoming Paper Spotlight ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: _buildStaggeredSection(
                    index: 6,
                    child: _buildUpcomingPaperSpotlight(examYear, isDark),
                  ),
                ),
              ),

              // ── 8. Learning Performance Line Chart ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: _buildStaggeredSection(
                    index: 7,
                    child: StudentProgressChart(
                      desserts: desserts.desserts,
                      totalCredits: totalCredits,
                    ),
                  ),
                ),
              ),

              // ── 9. Compact Stats Bar ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _buildStaggeredSection(
                    index: 8,
                    child: _buildStatsRow(
                      isDark: isDark,
                      totalCount: totalCount,
                      approvedCount: approvedCount,
                      pendingCount: pendingCount,
                    ),
                  ),
                ),
              ),

              // ── 10. Recent Activity Section Header ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/student/desserts'),
                        child: Text(
                          'View all',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 11. Submissions List Feed ───────────────────────────────
              if (desserts.loading && desserts.desserts.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildSkeletonTile(isDark),
                      childCount: 2,
                    ),
                  ),
                )
              else if (desserts.desserts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: _buildEmptyState(
                      isDark: isDark,
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
                        final d = desserts.desserts.take(5).toList()[i];
                        return DessertListTile(
                          dessert: d,
                          onTap: () => context.push('/student/dessert/${d.id}'),
                        );
                      },
                      childCount: desserts.desserts.take(5).length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI SUB-COMPONENTS (Clean, Minimal, High-End)
  // ─────────────────────────────────────────────────────────────────────────

  /// Minimal Top Header
  Widget _buildHeader({
    required BuildContext context,
    required bool isDark,
    required String displayName,
    required String examYear,
    required int totalCredits,
    required String? userAvatarUrl,
    required int approvedCount,
    required int totalCount,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar with subtle glow
        GestureDetector(
          onTap: () {
            HapticFeedbackService.light();
            context.go('/student/profile');
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF38BDF8).withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 23,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              child: ClipOval(
                child: userAvatarUrl != null && userAvatarUrl.isNotEmpty
                    ? MediaImageView(
                        url: userAvatarUrl,
                        fit: BoxFit.cover,
                        width: 46,
                        height: 46,
                      )
                    : const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 24),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Greeting and Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_getGreeting()},',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF38BDF8),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Target Badge Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFF0284C7).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.10)
                        : const Color(0xFF0284C7).withOpacity(0.18),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$examYear • $totalCredits pts ⚡',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Badges Trophy Pill
        GestureDetector(
          onTap: () {
            HapticFeedbackService.light();
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
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFFFBBF24).withOpacity(0.3)
                    : const Color(0xFFF59E0B).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  'Badges',
                  style: GoogleFonts.poppins(
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Streak Flame Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B00), Color(0xFFEA580C)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withOpacity(0.28),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '3d',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 3),
              const Text('🔥', style: TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }

  /// Minimal XP Progress Bar
  Widget _buildXpProgressBar({
    required bool isDark,
    required int currentLevel,
    required int totalCredits,
    required double levelProgress,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131B2E).withOpacity(0.85)
            : Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF38BDF8),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF38BDF8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Level $currentLevel Cadet  ➔  Level ${currentLevel + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              Text(
                '${(levelProgress * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress Bar Track
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              width: double.infinity,
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: levelProgress.clamp(0.04, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0284C7),
                          Color(0xFF38BDF8),
                          Color(0xFF818CF8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF38BDF8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Minimal Pill-Shaped Quick Actions Grid
  Widget _buildQuickActions({
    required BuildContext context,
    required bool isDark,
  }) {
    return Row(
      children: [
        _buildPillAction(
          isDark: isDark,
          icon: Icons.flash_on_rounded,
          label: 'MCQ',
          accentColor: const Color(0xFFF97316),
          onTap: () {
            HapticFeedbackService.light();
            context.push('/student/sprint');
          },
        ),
        const SizedBox(width: 10),
        _buildPillAction(
          isDark: isDark,
          icon: Icons.chat_bubble_outline_rounded,
          label: 'AI Tutor',
          accentColor: const Color(0xFF8B5CF6),
          onTap: () {
            HapticFeedbackService.light();
            _openWhatsAppTutor();
          },
        ),
        const SizedBox(width: 10),
        _buildPillAction(
          isDark: isDark,
          icon: Icons.camera_alt_outlined,
          label: 'Submit',
          accentColor: const Color(0xFF0284C7),
          onTap: () {
            HapticFeedbackService.light();
            context.go('/student/desserts');
          },
        ),
        const SizedBox(width: 10),
        _buildPillAction(
          isDark: isDark,
          icon: Icons.emoji_events_outlined,
          label: 'Ranks',
          accentColor: const Color(0xFFEAB308),
          onTap: () {
            HapticFeedbackService.light();
            context.go('/student/leaderboard');
          },
        ),
      ],
    );
  }

  Widget _buildPillAction({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131B2E).withOpacity(0.85)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(isDark ? 0.16 : 0.10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Daily MCQ Sprint Card
  Widget _buildDailyMcqSprintSpotlight(String studentUid, String studentExamYear, bool isDark) {
    try {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('daily_sprints').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const SizedBox.shrink();
          final allDocs = (snapshot.data?.docs ?? []).toList()
            ..sort((a, b) {
              final aDate = a.data()['targetDate']?.toString() ?? '';
              final bDate = b.data()['targetDate']?.toString() ?? '';
              return bDate.compareTo(aDate);
            });

          if (allDocs.isEmpty) return const SizedBox.shrink();

          final matchingDocs = allDocs.where((d) {
            final docExamYear = d.data()['examYear']?.toString();
            if (docExamYear == null || docExamYear.isEmpty || docExamYear == 'All Batches') return true;
            if (studentExamYear.isEmpty) return true;
            return docExamYear.toLowerCase().trim() == studentExamYear.toLowerCase().trim();
          }).toList();

          final docs = matchingDocs.isNotEmpty ? matchingDocs : allDocs;
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

          QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;
          for (final d in docs) {
            if (d.data()['targetDate'] == todayStr) {
              activeDoc = d;
              break;
            }
          }
          activeDoc ??= docs.first;

          final data = activeDoc.data();
          final targetDate = data['targetDate']?.toString() ?? todayStr;
          final title = data['title']?.toString() ?? 'Daily MCQ Sprint';
          final unit = data['unit']?.toString() ?? 'General Physics';
          final rawQuestions = data['questions'];
          final List<dynamic> questions = rawQuestions is List
              ? rawQuestions
              : (rawQuestions is Map ? rawQuestions.values.toList() : []);
          final isToday = targetDate == todayStr;

          int parseNum(dynamic val, int fallback) {
            if (val is num) return val.toInt();
            if (val is String) return int.tryParse(val) ?? fallback;
            return fallback;
          }

          if (studentUid.isEmpty) {
            return _buildSprintSpotlightCard(
              isDark: isDark,
              targetDate: targetDate,
              title: title,
              unit: unit,
              questionsCount: questions.length,
              isToday: isToday,
              hasAttempted: false,
              score: 0,
              total: questions.isNotEmpty ? questions.length : 5,
              xpEarned: 0,
            );
          }

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
              final score = parseNum(attemptData?['score'], 0);
              final total = parseNum(attemptData?['total'], questions.isNotEmpty ? questions.length : 5);
              final xpEarned = parseNum(attemptData?['xpEarned'], 0);

              return _buildSprintSpotlightCard(
                isDark: isDark,
                targetDate: targetDate,
                title: title,
                unit: unit,
                questionsCount: questions.length,
                isToday: isToday,
                hasAttempted: hasAttempted,
                score: score,
                total: total,
                xpEarned: xpEarned,
              );
            },
          );
        },
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSprintSpotlightCard({
    required bool isDark,
    required String targetDate,
    required String title,
    required String unit,
    required int questionsCount,
    required bool isToday,
    required bool hasAttempted,
    required int score,
    required int total,
    required int xpEarned,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedbackService.light();
        context.push('/student/sprint?date=$targetDate');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF131B2E).withOpacity(0.85)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasAttempted
                ? const Color(0xFF10B981).withOpacity(isDark ? 0.35 : 0.4)
                : const Color(0xFFF97316).withOpacity(isDark ? 0.35 : 0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (hasAttempted ? const Color(0xFF10B981) : const Color(0xFFF97316))
                        .withOpacity(isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hasAttempted ? '✅' : '🔥', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        isToday ? "TODAY'S 5-MCQ SPRINT" : "DAILY MCQ SPRINT",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hasAttempted
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF97316),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  targetDate,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$questionsCount Questions • $unit',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            if (hasAttempted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completed! Score: $score / $total (+$xpEarned XP)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 16),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Start Sprint (+50 XP)',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Upcoming Paper Spotlight
  Widget _buildUpcomingPaperSpotlight(String examYear, bool isDark) {
    try {
      return StreamBuilder<List<UpcomingPaper>>(
        stream: PaperLeaderboardService().streamUpcomingPapers(examYear: examYear),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const SizedBox.shrink();
          final papers = snapshot.data ?? [];
          if (papers.isEmpty) return const SizedBox.shrink();
          final paper = papers.first;
          final hasHints = paper.hints.isNotEmpty;

          return GestureDetector(
            onTap: () {
              HapticFeedbackService.light();
              context.go('/student/papers');
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF131B2E).withOpacity(0.85)
                    : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(isDark ? 0.35 : 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔮', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              'UPCOMING PAPER',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF818CF8),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        paper.subject,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    paper.title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${paper.examYear} • ${paper.durationMinutes} Minutes Exam',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  if (hasHints) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Hint: ${paper.hints}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View Scope ➔',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  /// Compact 3-Stat Row
  Widget _buildStatsRow({
    required bool isDark,
    required int totalCount,
    required int approvedCount,
    required int pendingCount,
  }) {
    return Row(
      children: [
        _buildStatItem(
          isDark: isDark,
          label: 'Submitted',
          value: '$totalCount',
          icon: Icons.send_rounded,
          color: const Color(0xFF38BDF8),
        ),
        const SizedBox(width: 10),
        _buildStatItem(
          isDark: isDark,
          label: 'Approved',
          value: '$approvedCount',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(width: 10),
        _buildStatItem(
          isDark: isDark,
          label: 'In Review',
          value: '$pendingCount',
          icon: Icons.hourglass_top_rounded,
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF131B2E).withOpacity(0.85)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonTile(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E).withOpacity(0.6) : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 130,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 70,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool isDark, required VoidCallback onSubmit}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E).withOpacity(0.85) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          const Text('🚀', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(
            'Ready to start your streak?',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Submit your homework photos to earn XP and rank up on the leaderboard!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.send_rounded, size: 15),
            label: Text(
              'Submit Homework 📸',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
