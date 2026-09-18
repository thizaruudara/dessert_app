import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/paper_session_model.dart';
import '../../../core/models/upcoming_paper_model.dart';
import '../../../core/models/paper_leaderboard_model.dart';
import '../../../core/services/paper_session_service.dart';
import '../../../core/services/paper_leaderboard_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminPaperSessionsScreen extends StatefulWidget {
  const AdminPaperSessionsScreen({super.key});

  @override
  State<AdminPaperSessionsScreen> createState() => _AdminPaperSessionsScreenState();
}

class _AdminPaperSessionsScreenState extends State<AdminPaperSessionsScreen> {
  final PaperSessionService _paperService = PaperSessionService();
  final PaperLeaderboardService _leaderboardService = PaperLeaderboardService();
  late final Stream<List<PaperSession>> _sessionsStream = _paperService.streamSessions();
  int _selectedAdminTab = 0; // 0: Live Sessions, 1: Upcoming Papers, 2: Paper Leaderboards

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.assignment_turned_in, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paper Examination Hub',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  _selectedAdminTab == 0
                      ? 'සජීවී විභාග සැසි සහ කැමරා අධීක්ෂණය'
                      : (_selectedAdminTab == 1 ? 'ඉදිරි විභාග සහ Hints කළමනාකරණය' : 'Paper ප්‍රතිඵල සහ Leaderboard නිර්මාණය'),
                  style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/admin/countdowns'),
            icon: const Icon(Icons.timer_outlined, color: AppColors.primary, size: 24),
            tooltip: 'A/L Exam Target Dates & Countdowns',
          ),
          IconButton(
            onPressed: () {
              if (_selectedAdminTab == 0) {
                _showCreatePaperDialog();
              } else if (_selectedAdminTab == 1) {
                _showUpcomingPaperDialog();
              } else {
                _showPaperLeaderboardEditorDialog();
              }
            },
            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
            tooltip: _selectedAdminTab == 0
                ? 'Create New Live Session'
                : (_selectedAdminTab == 1 ? 'Add Upcoming Paper & Hints' : 'Create Paper Leaderboard'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Admin 3-Tab Segmented Selector ───────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildAdminTabButton(
                    index: 0,
                    title: '🔴 Live Sessions',
                    isSelected: _selectedAdminTab == 0,
                  ),
                ),
                Expanded(
                  child: _buildAdminTabButton(
                    index: 1,
                    title: '🔮 Upcoming Papers',
                    isSelected: _selectedAdminTab == 1,
                  ),
                ),
                Expanded(
                  child: _buildAdminTabButton(
                    index: 2,
                    title: '🏆 Leaderboard',
                    isSelected: _selectedAdminTab == 2,
                  ),
                ),
              ],
            ),
          ),

          // ── Active View Body ────────────────────────────────
          Expanded(
            child: _selectedAdminTab == 0
                ? _buildLiveSessionsView()
                : (_selectedAdminTab == 1
                    ? _buildAdminUpcomingPapersView()
                    : _buildAdminPaperLeaderboardsView()),
          ),
        ],
      ),
      floatingActionButton: _buildAdminFab(),
    );
  }

  Widget _buildAdminTabButton({
    required int index,
    required String title,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedAdminTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget? _buildAdminFab() {
    if (_selectedAdminTab == 0) {
      return FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showCreatePaperDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Live Session',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    } else if (_selectedAdminTab == 1) {
      return FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showUpcomingPaperDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Upcoming Paper',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    } else {
      return FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showPaperLeaderboardEditorDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Create Leaderboard',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    }
  }

  Widget _buildLiveSessionsView() {
    return StreamBuilder<List<PaperSession>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        final sessions = snapshot.data ?? [];
        if (sessions.isEmpty) {
          return _buildEmptyAdminState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            return _buildAdminPaperCard(sessions[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyAdminState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.note_add_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'තවම Paper Sessions නිර්මාණය කර නොමැත',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'නව විභාග සැසියක් නිර්මාණය කර Slot 1 සහ Slot 2 වේලාවන් සකසන්න.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showCreatePaperDialog(),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: Text(
                'Create First Paper Session',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminPaperCard(PaperSession session) {
    final dateFormat = DateFormat('yyyy MMMM dd (EEEE)');
    final timeFormat = DateFormat('hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges & Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        session.subject,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        session.examYear,
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.isEnded
                            ? const Color(0xFFEF4444).withOpacity(0.12)
                            : (session.isActive || DateTime.now().isAfter(session.slot1.startTime))
                                ? const Color(0xFF22C55E).withOpacity(0.12)
                                : const Color(0xFFF59E0B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: session.isEnded
                              ? const Color(0xFFEF4444)
                              : (session.isActive || DateTime.now().isAfter(session.slot1.startTime))
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFF59E0B),
                        ),
                      ),
                      child: Text(
                        session.isEnded
                            ? '🔴 Ended'
                            : (session.isActive || DateTime.now().isAfter(session.slot1.startTime))
                                ? '🟢 Live'
                                : '🟡 Upcoming',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: session.isEnded
                              ? const Color(0xFFDC2626)
                              : (session.isActive || DateTime.now().isAfter(session.slot1.startTime))
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar_outlined, size: 20, color: AppColors.primary),
                      tooltip: 'Change Session Times (Slot 1 / Slot 2)',
                      onPressed: () => _showEditTimesDialog(session),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                      tooltip: 'Delete Paper Session (සැසිය මකා දැමීම)',
                      onPressed: () => _showDeleteConfirmation(session),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  session.title,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(DateTime.tryParse(session.date) ?? DateTime.now()),
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.timer_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      '${session.durationMinutes} Mins',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wb_sunny_outlined, size: 15, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 6),
                                Text(
                                  session.slot2 != null ? 'Slot 1 (Morning)' : 'Exam Session Time',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${timeFormat.format(session.slot1.startTime)} - ${timeFormat.format(session.slot1.endTime)}',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '👥 ${session.slot1.registeredCount} Registered',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (session.slot2 != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.nights_stay_outlined, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Slot 2 (Evening)',
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${timeFormat.format(session.slot2!.startTime)} - ${timeFormat.format(session.slot2!.endTime)}',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '👥 ${session.slot2!.registeredCount} Registered',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final targetUrl = '/admin/papers/proctor/${session.id}';
                      try {
                        context.push(targetUrl);
                      } catch (e) {
                        debugPrint('Admin proctor push failed: $e, trying go');
                        context.go(targetUrl);
                      }
                    },
                    icon: const Icon(Icons.videocam_outlined, size: 18, color: Colors.white),
                    label: Text(
                      'Live Camera Proctor Monitor (අධීක්ෂණ මධ්‍යස්ථානය)',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (!session.isEnded) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showEndSessionConfirmation(session),
                          icon: const Icon(Icons.stop_circle_outlined, size: 16, color: Color(0xFFEF4444)),
                          label: Text(
                            'End Session (සැසිය අවසන් කරන්න)',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
                          ),
                        ),
                      ),
                      if (!session.isActive && DateTime.now().isBefore(session.slot1.startTime)) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF22C55E)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _startSessionNow(session),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Color(0xFF22C55E)),
                          label: Text(
                            'Start Now',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF22C55E)),
                          ),
                        ),
                      ],
                    ] else ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFFDC2626)),
                              const SizedBox(width: 6),
                              Text(
                                'සැසිය අවසන් කර ඇත (Session Ended)',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _reopenSession(session),
                        icon: const Icon(Icons.refresh, size: 14, color: AppColors.primary),
                        label: Text('Reopen', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEndSessionConfirmation(PaperSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'End Paper Session?',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'ඔබට මෙම Paper Session එක අවසන් කිරීමට අවශ්‍ය බව සහතිකද?\n\nසැසිය අවසන් කළ පසු සිසුන්ට විභාග කාමරයට පිවිසීමට හෝ නව පිළිතුරු පත්‍ර Submit කිරීමට නොහැක.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _paperService.endPaperSession(session.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Paper Session එක සාර්ථකව අවසන් කරන ලදී (Session Ended).'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              }
            },
            child: Text('End Session (අවසන් කරන්න)', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _startSessionNow(PaperSession session) async {
    try {
      await _paperService.startPaperSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 සැසිය සක්‍රීය කරන ලදී (Session is now Live)!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _reopenSession(PaperSession session) async {
    try {
      await _paperService.reopenPaperSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ සැසිය නැවත සක්‍රීය කරන ලදී (Session Re-opened).'),
            backgroundColor: Color(0xFF38BDF8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _showCreatePaperDialog() {
    final titleCtrl = TextEditingController();
    String selectedSubject = 'Physics';
    final List<String> subjectOptions = [
      'Physics',
    ];

    String selectedExamYear = '2027 A/L';
    final List<String> examYearOptions = [
      '2024 A/L',
      '2025 A/L',
      '2026 A/L',
      '2027 A/L',
      '2028 A/L',
      '2029 A/L',
      'All Batches',
    ];

    final durationCtrl = TextEditingController(text: '180');

    int slotCount = 1; // Default: 1 Slot
    DateTime selectedDate = DateTime.now();

    // Helper to calculate end time from start time + duration + 10 mins package unboxing
    TimeOfDay calcEnd(TimeOfDay start, int duration) {
      final totalMins = start.hour * 60 + start.minute + duration + 10; // +10 min physical package unboxing
      final h = (totalMins ~/ 60) % 24;
      final m = totalMins % 60;
      return TimeOfDay(hour: h, minute: m);
    }

    final initialNow = DateTime.now();
    TimeOfDay slot1Start = TimeOfDay(hour: initialNow.hour, minute: ((initialNow.minute / 5).ceil() * 5) % 60);
    TimeOfDay slot1End = calcEnd(slot1Start, 180);
    TimeOfDay slot2Start = const TimeOfDay(hour: 14, minute: 0);
    TimeOfDay slot2End = calcEnd(const TimeOfDay(hour: 14, minute: 0), 180);
    bool isSubmitting = false;
    String? validationError;

    final dateFormat = DateFormat('yyyy-MM-dd (EEEE)');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'New Paper Writing Session',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Paper Title / Topic *', titleCtrl, 'e.g. Unit Test 03 - Mechanics'),
                if (validationError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    validationError!,
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFEF4444)),
                  ),
                ],
                const SizedBox(height: 10),
                Text('Subject', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSubject,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                      items: subjectOptions.map((sub) {
                        return DropdownMenuItem<String>(
                          value: sub,
                          child: Text(
                            sub,
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (val) {
                              if (val != null) setDlgState(() => selectedSubject = val);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Exam Year', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedExamYear,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                                items: examYearOptions.map((yr) {
                                  return DropdownMenuItem<String>(
                                    value: yr,
                                    child: Text(
                                      yr,
                                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: isSubmitting
                                    ? null
                                    : (val) {
                                        if (val != null) setDlgState(() => selectedExamYear = val);
                                      },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
                        onChanged: (val) {
                          final d = int.tryParse(val) ?? 180;
                          setDlgState(() {
                            slot1End = calcEnd(slot1Start, d);
                            slot2End = calcEnd(slot2Start, d);
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Duration (Mins)',
                          labelStyle: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.backgroundSoft,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Physical paper note (no PDF)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.markunread_mailbox_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📦 Physical Paper Delivery: සිසුන්ගේ නිවෙස් වලට කුරියර් කර ඇති මුද්‍රිත ප්‍රශ්න පත්‍රය කැමරාව ඉදිරියේ විවෘත කිරීමට ප්‍රථම විනාඩි 10 ක කාලයක් ස්වයංක්‍රීයව හිමිවේ.',
                          style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textPrimary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '📅 Examination Date:',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 7)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) setDlgState(() => selectedDate = d);
                          },
                    icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                    label: Text(
                      dateFormat.format(selectedDate),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '⚡ Session Format (සැසි ගණන):',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setDlgState(() => slotCount = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: slotCount == 1 ? AppColors.primary.withOpacity(0.12) : AppColors.backgroundSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: slotCount == 1 ? AppColors.primary : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '1 Session Slot',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: slotCount == 1 ? FontWeight.bold : FontWeight.w500,
                                color: slotCount == 1 ? AppColors.primary : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDlgState(() => slotCount = 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: slotCount == 2 ? AppColors.primary.withOpacity(0.12) : AppColors.backgroundSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: slotCount == 2 ? AppColors.primary : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '2 Session Slots',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: slotCount == 2 ? FontWeight.bold : FontWeight.w500,
                                color: slotCount == 2 ? AppColors.primary : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  slotCount == 1 ? '⏰ Examination Time (විභාග වේලාව):' : '⏰ Slot 1 (Morning Session Times):',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD97706)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final t = await showTimePicker(context: context, initialTime: slot1Start);
                                if (t != null) {
                                  final dur = int.tryParse(durationCtrl.text) ?? 180;
                                  setDlgState(() {
                                    slot1Start = t;
                                    slot1End = calcEnd(t, dur);
                                  });
                                }
                              },
                        child: Text('Start: ${slot1Start.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final t = await showTimePicker(context: context, initialTime: slot1End);
                                if (t != null) setDlgState(() => slot1End = t);
                              },
                        child: Text('End: ${slot1End.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary)),
                      ),
                    ),
                  ],
                ),
                if (slotCount == 2) ...[
                  const SizedBox(height: 12),
                  Text(
                    '🌙 Slot 2 (Evening Session Times):',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final t = await showTimePicker(context: context, initialTime: slot2Start);
                                  if (t != null) {
                                    final dur = int.tryParse(durationCtrl.text) ?? 180;
                                    setDlgState(() {
                                      slot2Start = t;
                                      slot2End = calcEnd(t, dur);
                                    });
                                  }
                                },
                          child: Text('Start: ${slot2Start.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final t = await showTimePicker(context: context, initialTime: slot2End);
                                  if (t != null) setDlgState(() => slot2End = t);
                                },
                          child: Text('End: ${slot2End.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Notice about manual ending
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🛑 Manual Session End: විභාග සැසිය ස්වයංක්‍රීයව අවසන් නොවේ. විභාගය අවසන් වූ පසු Admin විසින් "End Session" බොත්තම ඔබා එය අවසන් කළ යුතුය.',
                          style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF92400E), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        setDlgState(() => validationError = 'කරුණාකර Paper Title එක ඇතුළත් කරන්න (Please enter Paper Title)');
                        return;
                      }

                      setDlgState(() {
                        isSubmitting = true;
                        validationError = null;
                      });

                      try {
                        final dateStr = selectedDate.toIso8601String().split('T')[0];
                        final slot1StartDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot1Start.hour, slot1Start.minute);
                        var slot1EndDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot1End.hour, slot1End.minute);

                        // Prevent 12:xx AM mistaken for 12:xx PM or end earlier than start
                        if (slot1EndDt.isBefore(slot1StartDt)) {
                          if (slot1End.hour == 0 && slot1Start.hour <= 12) {
                            slot1EndDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 12, slot1End.minute);
                          }
                          if (slot1EndDt.isBefore(slot1StartDt)) {
                            slot1EndDt = slot1EndDt.add(const Duration(days: 1));
                          }
                        }

                        PaperSlot? slot2;
                        if (slotCount == 2) {
                          final slot2StartDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot2Start.hour, slot2Start.minute);
                          var slot2EndDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot2End.hour, slot2End.minute);
                          if (slot2EndDt.isBefore(slot2StartDt)) {
                            if (slot2End.hour == 0 && slot2Start.hour <= 12) {
                              slot2EndDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 12, slot2End.minute);
                            }
                            if (slot2EndDt.isBefore(slot2StartDt)) {
                              slot2EndDt = slot2EndDt.add(const Duration(days: 1));
                            }
                          }
                          slot2 = PaperSlot(id: 'slot2', name: 'Evening Session (සවස සැසිය)', startTime: slot2StartDt, endTime: slot2EndDt);
                        }

                        // Sessions ALWAYS start in 'upcoming' status and 'waiting' phase.
                        // Admin manually triggers package opening or writing phases!
                        const initialStatus = 'upcoming';
                        const initialPhase = 'waiting';

                        final newSession = PaperSession(
                          id: '',
                          title: title,
                          subject: selectedSubject,
                          examYear: selectedExamYear,
                          date: dateStr,
                          durationMinutes: int.tryParse(durationCtrl.text) ?? 180,
                          pdfUrl: null, // Physical paper package sent home, no PDF
                          status: initialStatus,
                          currentPhase: initialPhase,
                          slot1: PaperSlot(
                            id: 'slot1',
                            name: slotCount == 2 ? 'Morning Session (උදෑසන සැසිය)' : 'Exam Session (විභාග සැසිය)',
                            startTime: slot1StartDt,
                            endTime: slot1EndDt,
                          ),
                          slot2: slot2,
                          createdAt: DateTime.now(),
                        );

                        await _paperService.createOrUpdatePaperSession(newSession);

                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ New Paper Session Created Successfully!'),
                              backgroundColor: Color(0xFF22C55E),
                            ),
                          );
                        }
                      } catch (e, stack) {
                        debugPrint('Error creating paper session: $e\n$stack');
                        setDlgState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Failed to create paper: ${e.toString()}'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Create Paper',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTimesDialog(PaperSession session) {
    TimeOfDay s1Start = TimeOfDay.fromDateTime(session.slot1.startTime);
    TimeOfDay s1End = TimeOfDay.fromDateTime(session.slot1.endTime);
    TimeOfDay s2Start = session.slot2 != null ? TimeOfDay.fromDateTime(session.slot2!.startTime) : const TimeOfDay(hour: 14, minute: 0);
    TimeOfDay s2End = session.slot2 != null ? TimeOfDay.fromDateTime(session.slot2!.endTime) : const TimeOfDay(hour: 17, minute: 15);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Change Session Times (වේලාවන් වෙනස් කිරීම)',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.slot2 != null ? 'Slot 1 (Morning Session):' : 'Exam Session Times:',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFD97706)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: s1Start);
                        if (t != null) setDlgState(() => s1Start = t);
                      },
                      child: Text('Start: ${s1Start.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: s1End);
                        if (t != null) setDlgState(() => s1End = t);
                      },
                      child: Text('End: ${s1End.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary)),
                    ),
                  ),
                ],
              ),
              if (session.slot2 != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Slot 2 (Evening Session):',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: s2Start);
                          if (t != null) setDlgState(() => s2Start = t);
                        },
                        child: Text('Start: ${s2Start.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: s2End);
                          if (t != null) setDlgState(() => s2End = t);
                        },
                        child: Text('End: ${s2End.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
              onPressed: () async {
                try {
                  final baseDate = session.slot1.startTime;
                  final s1StartDt = DateTime(baseDate.year, baseDate.month, baseDate.day, s1Start.hour, s1Start.minute);
                  var s1EndDt = DateTime(baseDate.year, baseDate.month, baseDate.day, s1End.hour, s1End.minute);
                  if (s1EndDt.isBefore(s1StartDt)) {
                    if (s1End.hour == 0 && s1Start.hour <= 12) {
                      s1EndDt = DateTime(baseDate.year, baseDate.month, baseDate.day, 12, s1End.minute);
                    }
                    if (s1EndDt.isBefore(s1StartDt)) {
                      s1EndDt = s1EndDt.add(const Duration(days: 1));
                    }
                  }

                  final updatedSlot1 = PaperSlot(
                    id: 'slot1',
                    name: session.slot1.name,
                    startTime: s1StartDt,
                    endTime: s1EndDt,
                    maxCapacity: session.slot1.maxCapacity,
                    registeredCount: session.slot1.registeredCount,
                  );

                  PaperSlot? updatedSlot2;
                  if (session.slot2 != null) {
                    final s2StartDt = DateTime(baseDate.year, baseDate.month, baseDate.day, s2Start.hour, s2Start.minute);
                    var s2EndDt = DateTime(baseDate.year, baseDate.month, baseDate.day, s2End.hour, s2End.minute);
                    if (s2EndDt.isBefore(s2StartDt)) {
                      if (s2End.hour == 0 && s2Start.hour <= 12) {
                        s2EndDt = DateTime(baseDate.year, baseDate.month, baseDate.day, 12, s2End.minute);
                      }
                      if (s2EndDt.isBefore(s2StartDt)) {
                        s2EndDt = s2EndDt.add(const Duration(days: 1));
                      }
                    }

                    updatedSlot2 = PaperSlot(
                      id: 'slot2',
                      name: session.slot2!.name,
                      startTime: s2StartDt,
                      endTime: s2EndDt,
                      maxCapacity: session.slot2!.maxCapacity,
                      registeredCount: session.slot2!.registeredCount,
                    );
                  }

                  await _paperService.updateSlotTimes(session.id, slot1: updatedSlot1, slot2: updatedSlot2);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Session Times Updated Successfully!'), backgroundColor: Color(0xFF22C55E)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Error updating times: $e'), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              child: Text('Save Changes', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(PaperSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Session?',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this paper session?',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.subject} • ${session.examYear}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'මෙම සැසිය සහ ඊට අදාළ සියලුම ශිෂ්‍ය ලියාපදිංචි දත්ත මකා දැමෙනු ඇත.',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFDC2626)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _paperService.deletePaperSession(session.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🗑️ Paper session deleted successfully.'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting paper: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete Paper',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.backgroundSoft,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: UPCOMING PAPERS & HINTS (ADMIN MANAGEMENT)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAdminUpcomingPapersView() {
    return StreamBuilder<List<UpcomingPaper>>(
      stream: _leaderboardService.streamUpcomingPapers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final papers = snapshot.data ?? [];
        if (papers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.auto_stories_outlined, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Upcoming Papers Added Yet',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add upcoming exam papers to provide students with syllabus scopes and hints.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showUpcomingPaperDialog(),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: Text(
                      'Add First Upcoming Paper',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: papers.length,
          itemBuilder: (context, index) {
            return _buildAdminUpcomingPaperCard(papers[index]);
          },
        );
      },
    );
  }

  Widget _buildAdminUpcomingPaperCard(UpcomingPaper paper) {
    final dateFormat = DateFormat('yyyy MMMM dd (EEEE)');
    final timeFormat = DateFormat('hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    paper.subject,
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  paper.examYear,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  tooltip: 'Edit Paper',
                  onPressed: () => _showUpcomingPaperDialog(paper),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Delete Paper',
                  onPressed: () => _deleteUpcomingPaper(paper.id),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.title,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      '${dateFormat.format(paper.scheduledDate)} at ${timeFormat.format(paper.scheduledDate)} (${paper.durationMinutes} mins)',
                      style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
                if (paper.paperStructure.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.assignment_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        paper.paperStructure,
                        style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
                if (paper.syllabusTopics.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: paper.syllabusTopics.map((topic) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          topic,
                          style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (paper.hints.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            paper.hints,
                            style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF92400E), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpcomingPaperDialog([UpcomingPaper? existing]) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    const String lockedSubject = 'Physics';
    String selectedExamYear = existing?.examYear ?? '2027 A/L';
    final List<String> examYearOptions = [
      '2024 A/L',
      '2025 A/L',
      '2026 A/L',
      '2027 A/L',
      '2028 A/L',
      '2029 A/L',
      'All Batches',
    ];
    if (!examYearOptions.contains(selectedExamYear)) {
      selectedExamYear = '2027 A/L';
    }
    final paperStructureOptions = const [
      'Part I',
      'Part II',
      'Part I + Part II',
    ];
    String selectedPaperStructure = existing?.paperStructure ?? 'Part I + Part II';
    if (!paperStructureOptions.contains(selectedPaperStructure)) {
      if (selectedPaperStructure.contains('Part I') && !selectedPaperStructure.contains('Part II')) {
        selectedPaperStructure = 'Part I';
      } else if (selectedPaperStructure.contains('Part II') && !selectedPaperStructure.contains('Part I')) {
        selectedPaperStructure = 'Part II';
      } else {
        selectedPaperStructure = 'Part I + Part II';
      }
    }
    final durationCtrl = TextEditingController(text: existing?.durationMinutes.toString() ?? '180');
    final topicsCtrl = TextEditingController(text: existing?.syllabusTopics.join(', ') ?? '');
    final hintsCtrl = TextEditingController(text: existing?.hints ?? '');
    final instructionsCtrl = TextEditingController(text: existing?.instructions ?? '');

    DateTime selectedDate = existing?.scheduledDate ?? DateTime.now().add(const Duration(days: 3));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_stories, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Upcoming Paper' : 'Add Upcoming Paper & Hints',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField('Paper Title', titleCtrl, 'e.g. Physics Model Paper 03 - Mechanics'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Subject', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSoft,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      const Text('⚡', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Physics',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.lock, size: 13, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Exam Batch / Year', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSoft,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedExamYear,
                                      isExpanded: true,
                                      dropdownColor: Colors.white,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 18),
                                      items: examYearOptions.map((year) {
                                        return DropdownMenuItem(
                                          value: year,
                                          child: Text(
                                            year,
                                            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setDialogState(() => selectedExamYear = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField('Duration (Minutes)', durationCtrl, '180'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Paper Structure', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSoft,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedPaperStructure,
                                      isExpanded: true,
                                      dropdownColor: Colors.white,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 18),
                                      items: paperStructureOptions.map((opt) {
                                        return DropdownMenuItem(
                                          value: opt,
                                          child: Text(
                                            opt,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12.5,
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedPaperStructure = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Scheduled Date & Time Pickers
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedDate = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      selectedTime.hour,
                                      selectedTime.minute,
                                    );
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                              label: Text(
                                DateFormat('yyyy-MM-dd').format(selectedDate),
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedTime = picked;
                                    selectedDate = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      picked.hour,
                                      picked.minute,
                                    );
                                  });
                                }
                              },
                              icon: const Icon(Icons.access_time, size: 14, color: AppColors.primary),
                              label: Text(
                                selectedTime.format(context),
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        'Syllabus & Tested Topics (Comma separated)',
                        topicsCtrl,
                        'Trigonometry, Limits, Complex Numbers, Quadratic Eq',
                      ),
                      const SizedBox(height: 12),

                      // Exclusive Hints
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Exam Preparation Hints & Clues',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: hintsCtrl,
                            maxLines: 3,
                            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Share special hints, tricky sections, or key formulas to review...',
                              hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                              filled: true,
                              fillColor: AppColors.backgroundSoft,
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildTextField('Exam Rules & Instructions', instructionsCtrl, 'e.g. Blue pens only, no calculators allowed'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;

                    final topicsList = topicsCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    final newPaper = UpcomingPaper(
                      id: existing?.id ?? '',
                      title: title,
                      subject: lockedSubject,
                      examYear: selectedExamYear,
                      scheduledDate: selectedDate,
                      durationMinutes: int.tryParse(durationCtrl.text.trim()) ?? 180,
                      paperStructure: selectedPaperStructure,
                      syllabusTopics: topicsList,
                      hints: hintsCtrl.text.trim(),
                      instructions: instructionsCtrl.text.trim(),
                      status: 'upcoming',
                      createdAt: existing?.createdAt ?? DateTime.now(),
                    );

                    Navigator.pop(ctx);
                    await _leaderboardService.saveUpcomingPaper(newPaper);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? '✅ Upcoming paper updated!' : '🔮 New Upcoming Paper & Hints published!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  child: Text(
                    isEdit ? 'Save Changes' : 'Publish Upcoming Paper',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteUpcomingPaper(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Upcoming Paper?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: Text('Are you sure you want to remove this upcoming paper and its hints?', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _leaderboardService.deleteUpcomingPaper(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🗑️ Upcoming paper deleted.'), backgroundColor: Color(0xFFEF4444)),
                );
              }
            },
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: PAPER LEADERBOARDS CREATOR & MANAGER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAdminPaperLeaderboardsView() {
    return StreamBuilder<List<PaperLeaderboard>>(
      stream: _leaderboardService.streamPaperLeaderboards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
                      color: AppColors.backgroundSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.gold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Paper Leaderboards Created Yet',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'After evaluating a paper, create a leaderboard here to rank candidates and publish marks.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showPaperLeaderboardEditorDialog(),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: Text(
                      'Create First Paper Leaderboard',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaderboards.length,
          itemBuilder: (context, index) {
            return _buildAdminLeaderboardCard(leaderboards[index]);
          },
        );
      },
    );
  }

  Widget _buildAdminLeaderboardCard(PaperLeaderboard board) {
    final dateFormat = DateFormat('yyyy MMM dd');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🏆 Leaderboard',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${board.subject} • ${board.examYear}',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  tooltip: 'Edit Leaderboard & Marks',
                  onPressed: () => _showPaperLeaderboardEditorDialog(board),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Delete Leaderboard',
                  onPressed: () => _deletePaperLeaderboard(board.id),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  board.paperTitle,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Published: ${dateFormat.format(board.publishedAt)} • Max: ${board.totalMarks.toInt()} Marks',
                      style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${board.entries.length} Candidates',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Top 3 Candidates Preview
                if (board.entries.isNotEmpty) ...[
                  Text(
                    'Top Performers:',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  ...board.entries.take(3).map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(e.rank == 1 ? '🥇' : (e.rank == 2 ? '🥈' : '🥉'), style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.studentName,
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${e.marks.toInt()} marks (${e.grade})',
                            style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaperLeaderboardEditorDialog([PaperLeaderboard? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaperLeaderboardEditorDialog(
        existing: existing,
        onSave: (newBoard) async {
          await _leaderboardService.savePaperLeaderboard(newBoard);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(existing != null ? '✅ Paper leaderboard updated!' : '🏆 New Paper Leaderboard published!'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  void _deletePaperLeaderboard(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Leaderboard?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: Text('Are you sure you want to delete this paper leaderboard?', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _leaderboardService.deletePaperLeaderboard(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🗑️ Paper leaderboard deleted.'), backgroundColor: Color(0xFFEF4444)),
                );
              }
            },
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// HIGH-CONTRAST PAPER LEADERBOARD EDITOR (PHYSICS ONLY & PERSISTENT INPUTS)
// ══════════════════════════════════════════════════════════════════════════

class _CandidateRowController {
  final TextEditingController nameCtrl;
  final TextEditingController marksCtrl;
  final TextEditingController remarksCtrl;
  String grade;
  int rank;

  _CandidateRowController({
    required String name,
    required double marks,
    required this.grade,
    required String remarks,
    required this.rank,
  })  : nameCtrl = TextEditingController(text: name),
        marksCtrl = TextEditingController(
          text: marks > 0 ? (marks % 1 == 0 ? marks.toInt().toString() : marks.toString()) : '',
        ),
        remarksCtrl = TextEditingController(text: remarks);

  void dispose() {
    nameCtrl.dispose();
    marksCtrl.dispose();
    remarksCtrl.dispose();
  }
}

class _PaperLeaderboardEditorDialog extends StatefulWidget {
  final PaperLeaderboard? existing;
  final Function(PaperLeaderboard) onSave;

  const _PaperLeaderboardEditorDialog({this.existing, required this.onSave});

  @override
  State<_PaperLeaderboardEditorDialog> createState() => _PaperLeaderboardEditorDialogState();
}

class _PaperLeaderboardEditorDialogState extends State<_PaperLeaderboardEditorDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _totalMarksCtrl;

  // Locked exclusively to Physics for physics teacher
  static const String _lockedSubject = 'Physics';

  late String _selectedExamYear;
  final List<String> _examYearOptions = [
    '2024 A/L',
    '2025 A/L',
    '2026 A/L',
    '2027 A/L',
    '2028 A/L',
    '2029 A/L',
    'All Batches',
  ];

  late List<_CandidateRowController> _rows;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.paperTitle ?? '');
    _totalMarksCtrl = TextEditingController(
      text: widget.existing != null
          ? (widget.existing!.totalMarks % 1 == 0
              ? widget.existing!.totalMarks.toInt().toString()
              : widget.existing!.totalMarks.toString())
          : '100',
    );

    _selectedExamYear = widget.existing?.examYear ?? '2027 A/L';
    if (!_examYearOptions.contains(_selectedExamYear)) {
      _selectedExamYear = '2027 A/L';
    }

    _rows = (widget.existing?.entries ?? []).map((e) {
      return _CandidateRowController(
        name: e.studentName,
        marks: e.marks,
        grade: e.grade,
        remarks: e.remarks,
        rank: e.rank,
      );
    }).toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalMarksCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addStudentRow() {
    setState(() {
      _rows.add(
        _CandidateRowController(
          name: '',
          marks: 0.0,
          grade: 'A',
          remarks: '',
          rank: _rows.length + 1,
        ),
      );
    });
  }

  void _autoRank() {
    setState(() {
      _rows.sort((a, b) {
        final mA = double.tryParse(a.marksCtrl.text.trim()) ?? 0.0;
        final mB = double.tryParse(b.marksCtrl.text.trim()) ?? 0.0;
        return mB.compareTo(mA);
      });
      for (int i = 0; i < _rows.length; i++) {
        _rows[i].rank = i + 1;
      }
    });
  }

  void _onMarksChanged(_CandidateRowController row) {
    final text = row.marksCtrl.text.trim();
    final score = double.tryParse(text) ?? 0.0;
    String newGrade = 'A';
    if (score >= 75) {
      newGrade = 'A';
    } else if (score >= 65) {
      newGrade = 'B';
    } else if (score >= 50) {
      newGrade = 'C';
    } else if (score >= 35) {
      newGrade = 'S';
    } else {
      newGrade = 'F';
    }

    if (row.grade != newGrade) {
      setState(() {
        row.grade = newGrade;
      });
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF10B981);
      case 'B':
        return const Color(0xFF3B82F6);
      case 'C':
        return const Color(0xFFF59E0B);
      case 'S':
        return const Color(0xFFA855F7);
      default:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final screenWidth = MediaQuery.of(context).size.width;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.emoji_events, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEdit ? 'Edit Paper Leaderboard' : 'Create Paper Leaderboard',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: screenWidth > 640 ? 620 : double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Paper Title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paper Title', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _titleCtrl,
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Physics Model Paper 03 - Mechanics',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.backgroundSoft,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subject (Locked to Physics) + Exam Year (Dropdown) + Total Marks
              Row(
                children: [
                  // Locked Subject
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subject', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              const Text('⚡', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(
                                _lockedSubject,
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              const Spacer(),
                              const Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Exam Year / Batch Dropdown
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Exam Year / Batch', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedExamYear,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 18),
                              items: _examYearOptions.map((year) {
                                return DropdownMenuItem(
                                  value: year,
                                  child: Text(
                                    year,
                                    style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedExamYear = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Total Marks
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Marks', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _totalMarksCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.backgroundSoft,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Candidates header + Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ranked Candidates (${_rows.length})',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _autoRank,
                        icon: const Icon(Icons.sort, size: 14, color: AppColors.primary),
                        label: Text('Auto-Rank', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _addStudentRow,
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: Text('+ Add Student', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_rows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.group_add_outlined, color: AppColors.textMuted, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Click "+ Add Student" above to start entering candidate scores and ranks.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Column Labels Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text('#', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Text('Student Name', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text('Marks', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 58,
                        child: Text('Grade', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text('Accolade / Note', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Candidate Rows with Crystal Clear Contrast
                ...List.generate(_rows.length, (idx) {
                  final r = _rows[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x040F172A),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Rank Badge
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: r.rank == 1
                                ? const Color(0xFFF59E0B).withOpacity(0.15)
                                : (r.rank == 2
                                    ? const Color(0xFF94A3B8).withOpacity(0.15)
                                    : (r.rank == 3
                                        ? const Color(0xFFB45309).withOpacity(0.15)
                                        : AppColors.backgroundSoft)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: r.rank <= 3 ? const Color(0xFFF59E0B) : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              r.rank == 1 ? '🥇' : (r.rank == 2 ? '🥈' : (r.rank == 3 ? '🥉' : '${r.rank}')),
                              style: GoogleFonts.poppins(fontSize: r.rank <= 3 ? 14 : 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Student Name
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              controller: r.nameCtrl,
                              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'Student Name',
                                hintStyle: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.backgroundSoft,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Marks Input (Never converts 10 to 1.0 or 80 to 8.0)
                        SizedBox(
                          width: 72,
                          height: 42,
                          child: TextField(
                            controller: r.marksCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _onMarksChanged(r),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '0-100',
                              hintStyle: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textMuted),
                              filled: true,
                              fillColor: AppColors.backgroundSoft,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Grade Dropdown
                        Container(
                          height: 42,
                          width: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _getGradeColor(r.grade).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getGradeColor(r.grade)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: r.grade,
                              dropdownColor: Colors.white,
                              icon: const SizedBox.shrink(),
                              alignment: Alignment.center,
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _getGradeColor(r.grade)),
                              items: ['A', 'B', 'C', 'S', 'F'].map((g) {
                                return DropdownMenuItem(
                                  value: g,
                                  child: Center(
                                    child: Text(g, style: TextStyle(color: _getGradeColor(g), fontWeight: FontWeight.bold)),
                                  ),
                                );
                              }).toList(),
                              onChanged: (g) {
                                if (g != null) setState(() => r.grade = g);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Accolade / Note
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              controller: r.remarksCtrl,
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Accolade / Note',
                                hintStyle: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.backgroundSoft,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Delete Row Button
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                          splashRadius: 16,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () {
                            setState(() {
                              final removed = _rows.removeAt(idx);
                              removed.dispose();
                              for (int i = 0; i < _rows.length; i++) {
                                _rows[i].rank = i + 1;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            final title = _titleCtrl.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a paper title'), backgroundColor: Color(0xFFEF4444)),
              );
              return;
            }

            _autoRank();

            final total = double.tryParse(_totalMarksCtrl.text.trim()) ?? 100.0;
            final entries = _rows.map((r) {
              return PaperLeaderboardEntry(
                rank: r.rank,
                studentName: r.nameCtrl.text.trim().isNotEmpty ? r.nameCtrl.text.trim() : 'Candidate ${r.rank}',
                marks: double.tryParse(r.marksCtrl.text.trim()) ?? 0.0,
                grade: r.grade,
                remarks: r.remarksCtrl.text.trim(),
              );
            }).toList();

            final newBoard = PaperLeaderboard(
              id: widget.existing?.id ?? '',
              paperTitle: title,
              subject: _lockedSubject,
              examYear: _selectedExamYear,
              paperDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
              totalMarks: total,
              publishedAt: widget.existing?.publishedAt ?? DateTime.now(),
              entries: entries,
            );

            Navigator.pop(context);
            widget.onSave(newBoard);
          },
          child: Text(
            isEdit ? 'Save Changes' : 'Publish Leaderboard',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
