import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/media_image_view.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../../core/services/paper_leaderboard_service.dart';
import '../../../core/models/upcoming_paper_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../desserts/providers/desserts_provider.dart';
import '../../credits/providers/credits_provider.dart';
import '../widgets/exam_countdown_widget.dart';
import '../widgets/trophy_room_sheet.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with TickerProviderStateMixin {
  String? _lastListenedUid;
  late AnimationController _enterAnimCtrl;

  // Physics Micro-Insight rotator offset
  int _conceptOffset = 0;

  // Motivational quote rotator
  int _quoteIndex = 0;
  Timer? _quoteTimer;
  final List<String> _quotes = [
    '“Success is the sum of small efforts repeated day in and day out.”',
    '“Master today’s concepts, conquer tomorrow’s physics exam.”',
    '“Every problem you solve brings you one rank closer to your island dream.”',
    '“Discipline is choosing between what you want now and what you want most.”',
    '“Consistency always beats raw talent. Keep pushing forward!”',
  ];

  @override
  void initState() {
    super.initState();
    _checkAndListen();

    // Staggered pop-up entrance animation controller
    _enterAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Rotate quotes smoothly every 6 seconds
    _quoteTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) {
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % _quotes.length;
        });
      }
    });

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
    _quoteTimer?.cancel();
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

  /// Staggered pop-up animation wrapper for each element
  Widget _buildPopItem({required int index, required Widget child}) {
    final start = (index * 0.12).clamp(0.0, 0.6);
    final end = (start + 0.40).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _enterAnimCtrl,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: _enterAnimCtrl,
      builder: (context, _) {
        final scale = Tween<double>(begin: 0.90, end: 1.0).evaluate(animation);
        final opacity = Tween<double>(begin: 0.0, end: 1.0).evaluate(animation);
        final translateY = Tween<double>(begin: 20.0, end: 0.0).evaluate(animation);

        return Transform.translate(
          offset: Offset(0, translateY),
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
    final credits = context.watch<CreditsProvider>();
    final user = auth.user;

    final desserts = context.watch<DessertsProvider>();
    final approvedCount = desserts.desserts.where((d) => d.isApproved).length;
    final totalCount = desserts.desserts.length;
    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Scholar';
    final examYear = user?.examYear ?? '2027 A/L';
    final totalCredits = user?.credits ?? credits.totalCredits;

    final currentLevel = (totalCredits ~/ 100) + 1;
    final levelProgress = (totalCredits % 100) / 100.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
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
            // ── 1. Top Bar (Avatar & Streak Pill) ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 16,
                  20,
                  6,
                ),
                child: _buildPopItem(
                  index: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedbackService.light();
                          context.go('/student/profile');
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEFF6FF),
                                border: Border.all(color: const Color(0xFF2563EB), width: 1.8),
                              ),
                              child: ClipOval(
                                child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                                    ? MediaImageView(
                                        url: user.avatarUrl!,
                                        fit: BoxFit.cover,
                                        width: 44,
                                        height: 44,
                                      )
                                    : Center(
                                        child: Text(
                                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFF2563EB),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  '$examYear Scholar',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Tappable Streak & Trophy Pill
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '3 Days',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFEA580C),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. Live Animated Hero Banner: Big Student Name & Live Quote ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildPopItem(
                  index: 1,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E3A8A), // Deep Royal Navy
                          Color(0xFF2563EB), // Vibrant Electric Blue
                          Color(0xFF0284C7), // Sky Cyan Glow
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Subtle background decoration glow ring
                        Positioned(
                          right: -15,
                          bottom: -20,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Daily Inspiration Header Badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF38BDF8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF38BDF8),
                                              blurRadius: 5,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'DAILY INSPIRATION',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFE0F2FE),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.format_quote_rounded,
                                  color: Colors.white.withOpacity(0.40),
                                  size: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Live Animated Rotating Quote with generous line height and no cutoff
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 600),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.15),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                _quotes[_quoteIndex],
                                key: ValueKey<int>(_quoteIndex),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 3. Minimalist Level & XP Progress ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildPopItem(
                  index: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('⚡', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  'Level $currentLevel Cadet',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$totalCredits / ${(currentLevel) * 100} XP',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 6,
                            width: double.infinity,
                            color: const Color(0xFFF1F5F9),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: levelProgress.clamp(0.04, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 4. Original Exam Countdown ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildPopItem(
                  index: 3,
                  child: ExamCountdownWidget(examYear: examYear),
                ),
              ),
            ),

            // ── 5. Quick Actions (Original Exact Icon Layout & Gradient Tile Style) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildPopItem(
                  index: 4,
                  child: Row(
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
                ),
              ),
            ),

            // ── 6. Spotlight: Daily 5-MCQ Sprint (Real Firestore Stream) ─────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildPopItem(
                  index: 5,
                  child: _buildCleanSprintCard(user?.uid ?? '', examYear),
                ),
              ),
            ),

            // ── 7. Upcoming Live Exam Room & Paper Session (Real Firestore Stream) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildPopItem(
                  index: 6,
                  child: _buildUpcomingPaperShowcase(examYear),
                ),
              ),
            ),

            // ── 8. High-Yield Physics Concept & Formula Vault ────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildPopItem(
                  index: 7,
                  child: _buildPhysicsConceptVaultCard(),
                ),
              ),
            ),

            // ── 9. AI Study Assistant Fast-Prompt Launchers ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildPopItem(
                  index: 8,
                  child: _buildAiPromptLaunchersCard(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  /// Exact previous action tile style with rich rounded gradient icon box
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                    color: gradient.first.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// ── 6. Daily 5-MCQ Sprint Card with guaranteed dynamic fallback ─────────
  Widget _buildCleanSprintCard(String studentUid, String studentExamYear) {
    try {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('daily_sprints').snapshots(),
        builder: (context, snapshot) {
          final allDocs = (snapshot.data?.docs ?? []).toList()
            ..sort((a, b) {
              final aDate = a.data()['targetDate']?.toString() ?? '';
              final bDate = b.data()['targetDate']?.toString() ?? '';
              return bDate.compareTo(aDate);
            });

          if (allDocs.isEmpty) {
            return const SizedBox.shrink();
          }

          final matchingDocs = allDocs.where((d) {
            final docExamYear = d.data()['examYear']?.toString();
            if (docExamYear == null || docExamYear.isEmpty || docExamYear == 'All Batches') return true;
            if (studentExamYear.isEmpty) return true;
            return docExamYear.toLowerCase().trim() == studentExamYear.toLowerCase().trim();
          }).toList();

          final docs = matchingDocs.isNotEmpty ? matchingDocs : allDocs;
          if (docs.isEmpty) {
            return const SizedBox.shrink();
          }

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
          final rawQuestions = data['questions'];
          final List<dynamic> questions = rawQuestions is List
              ? rawQuestions
              : (rawQuestions is Map ? rawQuestions.values.toList() : []);
          final qCount = questions.length;

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 4),
                          Text(
                            "TODAY'S SPRINT",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFEA580C),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$qCount Quick MCQs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Solve 5 questions daily to maintain your streak and earn +50 XP towards your island rank.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    HapticFeedbackService.light();
                    context.push('/student/sprint?date=$targetDate');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Start Sprint (+50 XP)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  /// ── 7. Upcoming Live Exam Room & Paper Session Showcase (Real Firestore) ─
  Widget _buildUpcomingPaperShowcase(String examYear) {
    return StreamBuilder<List<UpcomingPaper>>(
      stream: PaperLeaderboardService().streamUpcomingPapers(examYear: examYear),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // Zero fake data! Only renders when admin publishes real papers.
        }

        final papers = snapshot.data!;
        final paper = papers.first;
        final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(paper.scheduledDate);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                            boxShadow: [
                              BoxShadow(color: Color(0xFF10B981), blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'UPCOMING EVALUATION',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF047857),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                paper.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              if (paper.syllabusTopics.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  paper.syllabusTopics.join(' • '),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPaperInfoPill(Icons.timer_outlined, '${paper.durationMinutes}m Duration'),
                  const SizedBox(width: 8),
                  _buildPaperInfoPill(
                    Icons.description_outlined,
                    paper.paperStructure.isNotEmpty ? paper.paperStructure : 'MCQ + Essays',
                  ),
                  const SizedBox(width: 8),
                  _buildPaperInfoPill(Icons.school_outlined, paper.examYear),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  HapticFeedbackService.light();
                  context.go('/student/papers');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Exam Room & Select Slot',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaperInfoPill(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF2563EB)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ── 8. Physics Concept Vault & Formula Spotlight Card (Bilingual + Daily Refresh) ─────
  _PhysicsDailyConcept _getCurrentPhysicsConcept() {
    final now = DateTime.now();
    // Deterministic calendar day seed: refreshes automatically at midnight
    final daySeed = (now.year * 366 + now.month * 31 + now.day);
    final index = (daySeed + _conceptOffset) % _physicsConcepts.length;
    return _physicsConcepts[index];
  }

  void _shufflePhysicsConcept() {
    HapticFeedbackService.light();
    setState(() {
      _conceptOffset++;
    });
  }

  Widget _buildPhysicsConceptVaultCard() {
    final concept = _getCurrentPhysicsConcept();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚛️', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      'PHYSICS MICRO-INSIGHT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2563EB),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'අද දවසේ සූත්‍රය • Daily',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'මාරු කරන්න (Shuffle Concept)',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _shufflePhysicsConcept,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 15,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${concept.unitSinhala} • ${concept.unitEnglish}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
                height: 1.3,
              ),
              children: [
                TextSpan(text: concept.titleSinhala),
                TextSpan(
                  text: '  (${concept.titleEnglish})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                concept.formula,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D4ED8),
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      'විභාග උපදෙස (Exam Tip):',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  concept.tipSinhala,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF78350F),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'En: ${concept.tipEnglish}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF92400E).withOpacity(0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _openTutorWithTopic(concept.topicCode),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB), size: 15),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'මේ ගැන AI Tutor ගෙන් අසන්න (Ask AI Tutor) 💬',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ── 9. AI Study Assistant Fast-Prompt Launchers ──────────────────────────
  Widget _buildAiPromptLaunchersCard() {
    final List<Map<String, String>> promptTopics = [
      {
        'title': '⚡ ලෙන්ස්ගේ නියමය සහ ප්‍රේරණය (Lenz\'s Law & Induction)',
        'code': 'topic_lenz_law',
      },
      {
        'title': '🎯 වක්‍ර මාර්ගවල බැංකු නැංවීම (Banking of Roads)',
        'code': 'topic_circular_motion',
      },
      {
        'title': '💡 ඩොප්ලර් ආචරණය (Doppler Frequency Shifts)',
        'code': 'topic_doppler_effect',
      },
      {
        'title': '⚛️ ප්‍රකාශ විද්‍යුත් ආචරණය (Photoelectric Effect)',
        'code': 'topic_photoelectric',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_outlined, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Tutor Quick Inquiries',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ඔබට අපැහැදිලි ඕනෑම A/L භෞතික විද්‍යා සංකල්පයක් පිළිබඳව AI Tutor ගෙන් ක්ෂණික පැහැදිලි කිරීමක් ලබාගන්න (Sinhala & English).',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...promptTopics.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openTutorWithTopic(item['code']!),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title']!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_outward_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _openTutorWithTopic(String topicCode) async {
    HapticFeedbackService.light();
    final appUri = Uri.parse('tg://resolve?domain=edupeakbot&start=$topicCode');
    final webUri = Uri.parse('https://t.me/edupeakbot?start=$topicCode');
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
}

/// ── Physics Micro-Insight Concept Model & Curated A/L Bank ──────────────────
class _PhysicsDailyConcept {
  final String titleSinhala;
  final String titleEnglish;
  final String unitSinhala;
  final String unitEnglish;
  final String formula;
  final String tipSinhala;
  final String tipEnglish;
  final String topicCode;

  const _PhysicsDailyConcept({
    required this.titleSinhala,
    required this.titleEnglish,
    required this.unitSinhala,
    required this.unitEnglish,
    required this.formula,
    required this.tipSinhala,
    required this.tipEnglish,
    required this.topicCode,
  });
}

const List<_PhysicsDailyConcept> _physicsConcepts = [
  _PhysicsDailyConcept(
    titleSinhala: 'කාර්යය-ශක්ති ප්‍රමේයය',
    titleEnglish: 'Work-Energy Theorem & Friction Losses',
    unitSinhala: 'යාන්ත්‍ර විද්‍යාව',
    unitEnglish: 'Mechanics',
    formula: 'W_net  =  ΔK  =  ½ m v²  -  ½ m u²',
    tipSinhala: 'ආනත තලයක චලිතයේදී ඝර්ෂණයට එරෙහි කාර්යය (W_f = -f · s) යාන්ත්‍රික ශක්ති සමීකරණයට පෙර වෙන්ව සලකා බලන්න.',
    tipEnglish: 'Always compute work done against friction W_f = -f · s separately before equating mechanical energy at the base of an incline.',
    topicCode: 'topic_work_energy',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'වක්‍ර මාර්ගවල බැංකු නැංවීම',
    titleEnglish: 'Banking of Roads & Circular Motion',
    unitSinhala: 'වෘත්ත චලිතය',
    unitEnglish: 'Circular Motion',
    formula: 'tan θ  =  v² / (r · g)',
    tipSinhala: 'ඝර්ෂණය රහිත උපරිම ආරක්ෂිත ප්‍රවේගය (v) සඳහා අභිකේන්ද්‍ර බලය සැපයෙන්නේ අභිලම්භ ප්‍රතික්‍රියාවේ තිරස් සංරචකය (R sin θ) මගිනි.',
    tipEnglish: 'For frictionless optimal banking speed v, the centripetal force is provided solely by the horizontal normal component R sin θ.',
    topicCode: 'topic_circular_motion',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'ඩොප්ලර් ආචරණය',
    titleEnglish: 'Doppler Effect in Sound Waves',
    unitSinhala: 'තරංග හා දෝලන',
    unitEnglish: 'Waves & Sound',
    formula: 'f\'  =  f₀ [ (v ± v₀) / (v ∓ v_s) ]',
    tipSinhala: 'ප්‍රභවය සහ නිරීක්ෂකයා එකිනෙකා වෙත ළඟා වන විට සංඛ්‍යාතය වැඩි වන බව (f\' > f₀) ලකුණු තේරීමේදී මතක තබා ගන්න.',
    tipEnglish: 'Apparent frequency increases when source and observer approach each other, and decreases when moving apart.',
    topicCode: 'topic_doppler_effect',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'ලෙන්ස්ගේ නියමය සහ වි.ගා.බ. ප්‍රේරණය',
    titleEnglish: "Lenz's Law & Faraday Induction",
    unitSinhala: 'විද්‍යුත් චුම්භකත්වය',
    unitEnglish: 'Electromagnetism',
    formula: 'ε  =  - N ( ΔΦ / Δt )',
    tipSinhala: 'සෘණ ලකුණෙන් දැක්වෙන්නේ ප්‍රේරිත ධාරාව සැමවිටම එය ඇතිවීමට හේතු වූ චුම්භක ස්‍රාව වෙනසට විරුද්ධ වන බවයි (ශක්ති සංස්ථිති නියමය).',
    tipEnglish: 'The negative sign indicates induced current magnetic field opposes the original flux change (Conservation of Energy).',
    topicCode: 'topic_lenz_law',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'වියෝග ප්‍රවේගය (මිදීමේ ප්‍රවේගය)',
    titleEnglish: 'Gravitational Escape Velocity',
    unitSinhala: 'ගුරුත්වාකර්ෂණ ක්ෂේත්‍ර',
    unitEnglish: 'Gravitational Fields',
    formula: 'v_e  =  √( 2 G M / R )  =  √( 2 g R )',
    tipSinhala: 'වියෝග ප්‍රවේගය ප්‍රක්ෂේපිත වස්තුවේ ස්කන්ධය හෝ විදින කෝණය මත රඳා නොපවතී; එය ග්‍රහලෝකයේ ස්කන්ධය හා අරය මත පමණක් රඳා පවතී.',
    tipEnglish: 'Escape velocity is independent of projectile mass and angle; it depends solely on the planet mass and radius.',
    topicCode: 'topic_escape_velocity',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'ධාරිත්‍රකයක ගබඩා වන ශක්තිය',
    titleEnglish: 'Electrostatic Energy in Capacitors',
    unitSinhala: 'ස්ථිති විද්‍යුතය',
    unitEnglish: 'Electrostatics',
    formula: 'U  =  ½ C V²  =  ½ Q V  =  ½ Q² / C',
    tipSinhala: 'බැටරියෙන් සපයන ශක්තිය (Q V) වන අතර, ඉන් හරියටම අඩක් ප්‍රතිරෝධ මගින් තාපය ලෙස හානි වී ඉතිරි අර්ධය (½ Q V) පමණක් විද්‍යුත් ක්ෂේත්‍රයේ ගබඩා වේ.',
    tipEnglish: 'The charging source delivers work W = QV, but exactly 50% is dissipated as thermal loss, leaving U = ½QV in the capacitor field.',
    topicCode: 'topic_capacitors',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'තාපගති විද්‍යාවේ පළමු නියමය',
    titleEnglish: 'First Law of Thermodynamics',
    unitSinhala: 'තාප භෞතික විද්‍යාව',
    unitEnglish: 'Thermal Physics',
    formula: 'ΔQ  =  ΔU  +  ΔW  (ΔW = P ΔV)',
    tipSinhala: 'සමපරිමා ක්‍රියාවලිවලදී පරිමාව වෙනස් නොවන බැවින් ΔW = 0 වන අතර ලබාදෙන සියලු තාපය අභ්‍යන්තර ශක්තිය වැඩිකරයි (ΔQ = ΔU).',
    tipEnglish: 'In isochoric processes ΔW = 0 since volume is constant, so all absorbed heat increases internal energy ΔQ = ΔU.',
    topicCode: 'topic_thermodynamics',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'ප්‍රකාශ විද්‍යුත් ආචරණය',
    titleEnglish: 'Photoelectric Effect & Photons',
    unitSinhala: 'නූතන භෞතික විද්‍යාව',
    unitEnglish: 'Modern Physics',
    formula: 'h f  =  Φ  +  ½ m v_max²  =  Φ  +  e V_s',
    tipSinhala: 'නැවැත්වීමේ විභවය (V_s) රඳා පවතින්නේ ආලෝකයේ සංඛ්‍යාතය (f) මත පමණි; ආලෝක තීව්‍රතාව වැඩි කළද V_s වෙනස් නොවේ.',
    tipEnglish: 'Stopping potential V_s depends solely on frequency f and metal work function Φ, never on incident light intensity.',
    topicCode: 'topic_photoelectric',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'බර්නූලිගේ මූලධර්මය',
    titleEnglish: "Bernoulli's Principle & Fluid Flow",
    unitSinhala: 'තරල විද්‍යාව',
    unitEnglish: 'Hydrodynamics',
    formula: 'P  +  ½ ρ v²  +  ρ g h  =  Constant',
    tipSinhala: 'තිරස් නලයක ද්‍රව ප්‍රවේගය (v) වැඩි වන සිහින් ස්ථානවල පීඩනය (P) අඩුවේ (Venturi ආචරණය).',
    tipEnglish: 'For horizontal streamline flow, locations with higher velocity experience lower fluid pressure (Venturi effect).',
    topicCode: 'topic_bernoulli',
  ),
  _PhysicsDailyConcept(
    titleSinhala: 'පොටෙන්ෂියෝමීටරය හා අභ්‍යන්තර ප්‍රතිරෝධය',
    titleEnglish: 'Potentiometer & Internal Resistance',
    unitSinhala: 'ධාරා විද්‍යුතය',
    unitEnglish: 'Current Electricity',
    formula: 'r  =  R [ ( l₁ - l₂ ) / l₂ ]',
    tipSinhala: 'සමතුලිත අවස්ථාවේදී කෝෂයෙන් ධාරාවක් නොගලා යන බැවින් අග්‍රස්ථ විභව අන්තරය වෙනුවට නිවැරදිම විද්‍යුත් ගාමක බලය (EMF) මැනේ.',
    tipEnglish: 'At balance point zero current flows through the galvanometer, measuring the true EMF without internal resistance voltage drops.',
    topicCode: 'topic_potentiometer',
  ),
];
