import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/paper_session_model.dart';
import '../../../core/services/paper_session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_navigation_bar.dart';
import '../../auth/providers/auth_provider.dart';

class StudentShell extends StatefulWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  final PaperSessionService _paperService = PaperSessionService();
  StreamSubscription<List<PaperSession>>? _paperSessionsSub;
  bool _isPaperPopupShowing = false;
  String? _lastListenedExamYear;

  final _tabs = const [
    '/student',
    '/student/papers',
    '/student/leaderboard',
    '/student/desserts',
    '/student/profile',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPaperNotificationListener();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final currentYear = auth.userModel?.examYear ?? '2027 A/L';
    if (currentYear != _lastListenedExamYear) {
      _setupPaperNotificationListener();
    }
  }

  @override
  void dispose() {
    _paperSessionsSub?.cancel();
    super.dispose();
  }

  void _setupPaperNotificationListener() {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    final examYear = user?.examYear ?? '2027 A/L';
    _lastListenedExamYear = examYear;

    _paperSessionsSub?.cancel();
    _paperSessionsSub = _paperService.streamSessions(examYear: examYear).listen((sessions) {
      _checkForNewScheduledPapers(sessions, examYear);
    });
  }

  Future<void> _checkForNewScheduledPapers(List<PaperSession> sessions, String userExamYear) async {
    if (_isPaperPopupShowing || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      for (final session in sessions) {
        // Only alert for active/upcoming sessions, not ended
        if (session.isEnded) continue;

        // Match student's batch
        final matchesBatch = session.examYear == userExamYear ||
            session.examYear == 'All Batches' ||
            session.examYear == 'All';
        if (!matchesBatch) continue;

        final key = 'seen_paper_popup_${session.id}';
        final hasSeen = prefs.getBool(key) ?? false;
        if (!hasSeen) {
          _showNewPaperScheduledDialog(session, prefs, key);
          break; // Show one popup at a time
        }
      }
    } catch (e) {
      debugPrint('Paper scheduled popup check error: $e');
    }
  }

  void _showNewPaperScheduledDialog(PaperSession session, SharedPreferences prefs, String key) {
    if (_isPaperPopupShowing || !mounted) return;
    _isPaperPopupShowing = true;

    final dateFormat = DateFormat('yyyy MMMM dd (EEEE)');
    final timeFormat = DateFormat('hh:mm a');
    final parsedDate = DateTime.tryParse(session.date) ?? DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Color(0xFF818CF8), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Paper Scheduled!',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'නව විභාග සැසියක් එක්කර ඇත',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Session Card Preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                        ),
                        child: Text(
                          session.subject,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.4)),
                        ),
                        child: Text(
                          session.examYear,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFC084FC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    session.title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(parsedDate),
                        style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '${timeFormat.format(session.slot1.startTime)} • ${session.durationMinutes} Mins',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '📦 ඔබගේ විභාග සැසිය (Morning / Evening Slot) දැන්ම වෙන්කර සූදානම් වන්න.',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                     style: OutlinedButton.styleFrom(
                       side: const BorderSide(color: Color(0xFF475569)),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       padding: const EdgeInsets.symmetric(vertical: 11),
                     ),
                     onPressed: () async {
                       await prefs.setBool(key, true);
                       if (ctx.mounted) Navigator.of(ctx).pop();
                       _isPaperPopupShowing = false;
                     },
                     child: Text(
                       'Dismiss',
                       style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                     ),
                   ),
                 ),
                 const SizedBox(width: 10),
                 Expanded(
                   flex: 2,
                   child: ElevatedButton.icon(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF6366F1),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       padding: const EdgeInsets.symmetric(vertical: 11),
                     ),
                     onPressed: () async {
                       await prefs.setBool(key, true);
                       if (ctx.mounted) Navigator.of(ctx).pop();
                       _isPaperPopupShowing = false;
                       context.go('/student/papers');
                     },
                     icon: const Icon(Icons.assignment_turned_in_outlined, size: 16, color: Colors.white),
                     label: Text(
                       'View & Pick Slot',
                       style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                     ),
                   ),
                 ),
               ],
             ),
           ],
         ),
       ),
     ).then((_) {
       _isPaperPopupShowing = false;
     });
  }

  final _items = const [
    LiquidNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LiquidNavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: 'Papers',
    ),
    LiquidNavItem(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_rounded,
      label: 'Ranks',
    ),
    LiquidNavItem(
      icon: Icons.folder_special_outlined,
      activeIcon: Icons.folder_special_rounded,
      label: 'Desserts',
    ),
    LiquidNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i] || (i == 0 && location == '/student')) {
        return i;
      }
    }
    for (int i = _tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabs[i])) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final location = GoRouterState.of(context).uri.path;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: false,
      backgroundColor: isDark ? const Color(0xFF0B0F19) : AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.015),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(location),
          child: widget.child,
        ),
      ),
      bottomNavigationBar: LiquidNavigationBar(
        selectedIndex: selectedIndex,
        onItemSelected: (i) {
          if (selectedIndex != i) {
            context.go(_tabs[i]);
          }
        },
        items: _items,
        barColor: isDark ? const Color(0xFF111827) : Colors.white,
        borderColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        activeCircleGradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF227AFF), Color(0xFF1565D8)],
              ),
        activeIconColor: Colors.white,
        inactiveIconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        activeTextColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF227AFF),
      ),
    );
  }
}
