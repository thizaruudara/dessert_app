import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/paper_session_model.dart';
import '../../../core/services/paper_session_service.dart';
import '../../auth/providers/auth_provider.dart';

class PaperSessionsScreen extends StatefulWidget {
  const PaperSessionsScreen({super.key});

  @override
  State<PaperSessionsScreen> createState() => _PaperSessionsScreenState();
}

class _PaperSessionsScreenState extends State<PaperSessionsScreen> {
  final PaperSessionService _paperService = PaperSessionService();
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();
  Stream<List<PaperSession>>? _sessionsStream;
  String? _lastExamYear;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().userModel;
    if (_sessionsStream == null || _lastExamYear != user?.examYear) {
      _lastExamYear = user?.examYear;
      _sessionsStream = _paperService.streamSessions(examYear: user?.examYear);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;

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
              child: const Icon(Icons.assignment_outlined, color: Color(0xFF818CF8), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paper Writing Sessions',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'සජීවී විභාග සහ අධීක්ෂණ සැසි',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<PaperSession>>(
        stream: _sessionsStream ?? _paperService.streamSessions(examYear: user?.examYear),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          }

          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              return _buildPaperSessionCard(sessions[index], user?.id ?? '');
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
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
              child: const Icon(Icons.menu_book_rounded, size: 48, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Text(
              'නව Paper Sessions සූදානම් වෙමින් පවතී',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ඉදිරි විභාග සැසි සහ වේලාවන් මෙහි දිස්වනු ඇත. ඔබගේ slot එක තෝරාගෙන සූදානම් වන්න!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperSessionCard(PaperSession session, String studentId) {
    final dateFormat = DateFormat('yyyy MMMM dd (EEEE)');
    final timeFormat = DateFormat('hh:mm a');

    return StreamBuilder<PaperRegistration?>(
      stream: _paperService.streamStudentRegistration(session.id, studentId),
      builder: (context, regSnap) {
        final registration = regSnap.data;
        final selectedSlotId = registration?.selectedSlot ?? (session.slot2 == null ? 'slot1' : null);
        final selectedSlot = (selectedSlotId == 'slot2' && session.slot2 != null) ? session.slot2! : session.slot1;

        // Calculate countdown to the selected slot or slot 1 fallback
        final targetSlot = selectedSlot;
        final isLive = targetSlot.isLive(_now);
        final isUpcoming = targetSlot.isUpcoming(_now);
        final isEnded = targetSlot.isEnded(_now);

        Duration remaining = isUpcoming ? targetSlot.startTime.difference(_now) : Duration.zero;
        if (remaining.isNegative) remaining = Duration.zero;

        final hours = remaining.inHours.toString().padLeft(2, '0');
        final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLive ? const Color(0xFF22C55E) : const Color(0xFF334155),
              width: isLive ? 1.5 : 1,
            ),
            boxShadow: [
              if (isLive)
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
                          ),
                          child: Text(
                            session.subject,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFA5B4FC),
                            ),
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
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF22C55E)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'LIVE NOW',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4ADE80),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      session.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          dateFormat.format(DateTime.tryParse(session.date) ?? DateTime.now()),
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          '${session.durationMinutes} Minutes',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Session Slots Selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.slot2 != null
                          ? 'කරුණාකර ඔබගේ විභාග සැසිය (Slot) තෝරන්න:'
                          : 'විභාග සැසිය (Exam Session):',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (session.slot2 != null)
                      Row(
                        children: [
                          Expanded(
                            child: _buildSlotCard(
                              slot: session.slot1,
                              slotId: 'slot1',
                              isSelected: selectedSlotId == 'slot1',
                              paperId: session.id,
                              timeFormat: timeFormat,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSlotCard(
                              slot: session.slot2!,
                              slotId: 'slot2',
                              isSelected: selectedSlotId == 'slot2',
                              paperId: session.id,
                              timeFormat: timeFormat,
                            ),
                          ),
                        ],
                      )
                    else
                      _buildSlotCard(
                        slot: session.slot1,
                        slotId: 'slot1',
                        isSelected: selectedSlotId == 'slot1',
                        paperId: session.id,
                        timeFormat: timeFormat,
                      ),

                    const SizedBox(height: 16),

                    // Countdown & Status Box
                    if (selectedSlotId != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isLive
                              ? const Color(0xFF22C55E).withOpacity(0.1)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLive
                                ? const Color(0xFF22C55E).withOpacity(0.5)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isLive ? Icons.sensors : Icons.access_time_filled,
                              color: isLive ? const Color(0xFF4ADE80) : const Color(0xFFF59E0B),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLive
                                        ? 'විභාග සැසිය සක්‍රීයයි (Session is Live)!'
                                        : isEnded
                                            ? 'සැසිය අවසන් (Session Completed)'
                                            : '${targetSlot.name} ආරම්භ වීමට:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isLive
                                        ? 'වහාම Exam Room එකට පිවිසෙන්න'
                                        : isEnded
                                            ? 'ස්තුතියි, ඔබගේ පිළිතුරු ලැබී ඇත.'
                                            : '$hours : $minutes : $seconds',
                                    style: GoogleFonts.poppins(
                                      fontSize: isLive || isEnded ? 13 : 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: isLive || isEnded ? 0 : 2,
                                      color: isLive
                                          ? const Color(0xFF4ADE80)
                                          : isEnded
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedSlotId == null
                              ? const Color(0xFF334155)
                              : isLive
                                  ? const Color(0xFF22C55E)
                                  : isUpcoming
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF334155),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: isLive ? 4 : 0,
                        ),
                        onPressed: selectedSlotId == null
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('කරුණාකර ඉහතින් Morning හෝ Evening සැසියක් තෝරන්න.'),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                              }
                            : () {
                                context.push('/student/papers/exam/${session.id}?slot=$selectedSlotId');
                              },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isLive
                                  ? Icons.videocam
                                  : isUpcoming
                                      ? Icons.meeting_room
                                      : Icons.check_circle_outline,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedSlotId == null
                                  ? 'පළමුව සැසියක් (Slot) තෝරන්න'
                                  : isLive
                                      ? 'Enter Live Exam Room (කැමරාව ON කරන්න)'
                                      : isUpcoming
                                          ? 'Exam Room පූර්ව පරීක්ෂාව (Preview)'
                                          : 'View Paper / Submissions',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotCard({
    required PaperSlot slot,
    required String slotId,
    required bool isSelected,
    required String paperId,
    required DateFormat timeFormat,
  }) {
    final auth = context.read<AuthProvider>().userModel;

    return InkWell(
      onTap: () async {
        if (auth == null) return;
        try {
          await _paperService.registerStudentSlot(
            paperId: paperId,
            studentId: auth.id,
            studentName: auth.name,
            studentPhone: auth.phone,
            slotId: slotId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${slot.name} සාර්ථකව වෙන්කර ගන්නා ලදී!'),
                backgroundColor: const Color(0xFF22C55E),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('වෙන්කර ගැනීමට නොහැකි විය: $e'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.15)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  slotId == 'slot1' ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                  size: 16,
                  color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    slotId == 'slot1' ? 'Slot 1 (Morning)' : 'Slot 2 (Evening)',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF818CF8) : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, size: 16, color: Color(0xFF6366F1)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${timeFormat.format(slot.startTime)} - ${timeFormat.format(slot.endTime)}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '${slot.registeredCount} / ${slot.maxCapacity} Seats',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
