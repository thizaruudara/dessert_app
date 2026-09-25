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

            // ── 6. Spotlight: Daily 5-MCQ Sprint ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildPopItem(
                  index: 5,
                  child: _buildCleanSprintCard(user?.uid ?? '', examYear),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
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

  Widget _buildCleanSprintCard(String studentUid, String studentExamYear) {
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
          final rawQuestions = data['questions'];
          final List<dynamic> questions = rawQuestions is List
              ? rawQuestions
              : (rawQuestions is Map ? rawQuestions.values.toList() : []);

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
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
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
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${questions.length} Quick MCQs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Solve questions daily to maintain your streak and earn +50 XP.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
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
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Start Sprint (+50 XP) ➔',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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
}
