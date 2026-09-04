import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/paper_session_model.dart';
import '../../../core/services/paper_session_service.dart';

class AdminPaperSessionsScreen extends StatefulWidget {
  const AdminPaperSessionsScreen({super.key});

  @override
  State<AdminPaperSessionsScreen> createState() => _AdminPaperSessionsScreenState();
}

class _AdminPaperSessionsScreenState extends State<AdminPaperSessionsScreen> {
  final PaperSessionService _paperService = PaperSessionService();
  late final Stream<List<PaperSession>> _sessionsStream = _paperService.streamSessions();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_turned_in, color: Color(0xFF818CF8), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paper Writing Manager',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  'විභාග සැසි සහ සජීවී කැමරා අධීක්ෂණය',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showCreatePaperDialog(),
            icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1), size: 28),
            tooltip: 'Create New Paper Session',
          ),
        ],
      ),
      body: StreamBuilder<List<PaperSession>>(
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: () => _showCreatePaperDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Paper Session',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
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
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.note_add_outlined, size: 48, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Text(
              'තවම Paper Sessions නිර්මාණය කර නොමැත',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'නව විභාග සැසියක් නිර්මාණය කර Slot 1 සහ Slot 2 වේලාවන් සකසන්න.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
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
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges & Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        session.subject,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFA5B4FC)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        session.examYear,
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.isEnded
                            ? const Color(0xFFEF4444).withOpacity(0.2)
                            : (session.isActive || DateTime.now().isAfter(session.slot1.startTime))
                                ? const Color(0xFF22C55E).withOpacity(0.2)
                                : const Color(0xFFF59E0B).withOpacity(0.2),
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
                              ? const Color(0xFFFCA5A5)
                              : (session.isActive || DateTime.now().isAfter(session.slot1.startTime))
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFFCD34D),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar_outlined, size: 20, color: Color(0xFF38BDF8)),
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
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(DateTime.tryParse(session.date) ?? DateTime.now()),
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      '${session.durationMinutes} Mins',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
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
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
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
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${timeFormat.format(session.slot1.startTime)} - ${timeFormat.format(session.slot1.endTime)}',
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '👥 ${session.slot1.registeredCount} Registered',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
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
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.nights_stay_outlined, size: 15, color: Color(0xFF818CF8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Slot 2 (Evening)',
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${timeFormat.format(session.slot2!.startTime)} - ${timeFormat.format(session.slot2!.endTime)}',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '👥 ${session.slot2!.registeredCount} Registered',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
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
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      context.push('/admin/papers/proctor/${session.id}');
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
                            color: const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFFFCA5A5)),
                              const SizedBox(width: 6),
                              Text(
                                'සැසිය අවසන් කර ඇත (Session Ended)',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFFFCA5A5)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _reopenSession(session),
                        icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF38BDF8)),
                        label: Text('Reopen', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF38BDF8))),
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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'End Paper Session?',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          'ඔබට මෙම Paper Session එක අවසන් කිරීමට අවශ්‍ය බව සහතිකද?\n\nසැසිය අවසන් කළ පසු සිසුන්ට විභාග කාමරයට පිවිසීමට හෝ නව පිළිතුරු පත්‍ර Submit කිරීමට නොහැක.',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFCBD5E1), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
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
    String selectedSubject = 'Combined Mathematics';
    final List<String> subjectOptions = [
      'Combined Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'ICT',
      'General / Other',
    ];

    String selectedExamYear = '2027 A/L';
    final List<String> examYearOptions = [
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
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'New Paper Writing Session',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                Text('Subject', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSubject,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
                      items: subjectOptions.map((sub) {
                        return DropdownMenuItem<String>(
                          value: sub,
                          child: Text(
                            sub,
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
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
                          Text('Exam Year', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedExamYear,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1E293B),
                                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
                                items: examYearOptions.map((yr) {
                                  return DropdownMenuItem<String>(
                                    value: yr,
                                    child: Text(
                                      yr,
                                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
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
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                        onChanged: (val) {
                          final d = int.tryParse(val) ?? 180;
                          setDlgState(() {
                            slot1End = calcEnd(slot1Start, d);
                            slot2End = calcEnd(slot2Start, d);
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Duration (Mins)',
                          labelStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.markunread_mailbox_outlined, color: Color(0xFF818CF8), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📦 Physical Paper Delivery: සිසුන්ගේ නිවෙස් වලට කුරියර් කර ඇති මුද්‍රිත ප්‍රශ්න පත්‍රය කැමරාව ඉදිරියේ විවෘත කිරීමට ප්‍රථම විනාඩි 10 ක කාලයක් ස්වයංක්‍රීයව හිමිවේ.',
                          style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFFC7D2FE), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '📅 Examination Date:',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
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
                    icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF38BDF8)),
                    label: Text(
                      dateFormat.format(selectedDate),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '⚡ Session Format (සැසි ගණන):',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFA5B4FC)),
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
                            color: slotCount == 1 ? const Color(0xFF6366F1).withOpacity(0.3) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: slotCount == 1 ? const Color(0xFF6366F1) : const Color(0xFF334155),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '1 Session Slot',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: slotCount == 1 ? FontWeight.bold : FontWeight.w500,
                                color: slotCount == 1 ? Colors.white : const Color(0xFF94A3B8),
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
                            color: slotCount == 2 ? const Color(0xFF6366F1).withOpacity(0.3) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: slotCount == 2 ? const Color(0xFF6366F1) : const Color(0xFF334155),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '2 Session Slots',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: slotCount == 2 ? FontWeight.bold : FontWeight.w500,
                                color: slotCount == 2 ? Colors.white : const Color(0xFF94A3B8),
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
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
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
                        child: Text('Start: ${slot1Start.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final t = await showTimePicker(context: context, initialTime: slot1End);
                                if (t != null) setDlgState(() => slot1End = t);
                              },
                        child: Text('End: ${slot1End.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                if (slotCount == 2) ...[
                  const SizedBox(height: 12),
                  Text(
                    '🌙 Slot 2 (Evening Session Times):',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF818CF8)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
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
                          child: Text('Start: ${slot2Start.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final t = await showTimePicker(context: context, initialTime: slot2End);
                                  if (t != null) setDlgState(() => slot2End = t);
                                },
                          child: Text('End: ${slot2End.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
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
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🛑 Manual Session End: විභාග සැසිය ස්වයංක්‍රීයව අවසන් නොවේ. විභාගය අවසන් වූ පසු Admin විසින් "End Session" බොත්තම ඔබා එය අවසන් කළ යුතුය.',
                          style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFFFDE68A), height: 1.4),
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
              child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
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
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Change Session Times (වේලාවන් වෙනස් කිරීම)',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.slot2 != null ? 'Slot 1 (Morning Session):' : 'Exam Session Times:',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: s1Start);
                        if (t != null) setDlgState(() => s1Start = t);
                      },
                      child: Text('Start: ${s1Start.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: s1End);
                        if (t != null) setDlgState(() => s1End = t);
                      },
                      child: Text('End: ${s1End.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              if (session.slot2 != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Slot 2 (Evening Session):',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF818CF8)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: s2Start);
                          if (t != null) setDlgState(() => s2Start = t);
                        },
                        child: Text('Start: ${s2Start.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: s2End);
                          if (t != null) setDlgState(() => s2End = t);
                        },
                        child: Text('End: ${s2End.format(context)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
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
              child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
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
        backgroundColor: const Color(0xFF1E293B),
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
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this paper session?',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.subject} • ${session.examYear}',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'මෙම සැසිය සහ ඊට අදාළ සියලුම ශිෂ්‍ය ලියාපදිංචි දත්ත මකා දැමෙනු ඇත.',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFF87171)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
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
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
