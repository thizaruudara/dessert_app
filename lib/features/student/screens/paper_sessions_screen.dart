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
  List<PaperSession>? _cachedSessions;
  bool _initialFetchDone = false;
  bool _showAllBatches = false;

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
    final targetYear = _showAllBatches ? null : user?.examYear;
    if (_sessionsStream == null || _lastExamYear != targetYear) {
      _lastExamYear = targetYear;
      _sessionsStream = _paperService.streamSessions(examYear: targetYear);
      _loadInitialData(targetYear);
    }
  }

  Future<void> _loadInitialData(String? examYear) async {
    try {
      final data = await _paperService.getSessions(examYear: examYear);
      if (mounted) {
        setState(() {
          _cachedSessions = data;
          _initialFetchDone = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial paper sessions: $e');
      if (mounted) {
        setState(() {
          _initialFetchDone = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _refreshSessions(String? examYear) async {
    final targetYear = _showAllBatches ? null : examYear;
    final data = await _paperService.getSessions(examYear: targetYear);
    if (mounted) {
      setState(() {
        _cachedSessions = data;
        _sessionsStream = _paperService.streamSessions(examYear: targetYear);
      });
    }
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
            Expanded(
              child: Column(
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
                    _showAllBatches
                        ? 'සියලු Batches • සජීවී විභාග සහ අධීක්ෂණ සැසි'
                        : (user?.examYear != null
                            ? '${user!.examYear} • සජීවී විභාග සහ අධීක්ෂණ සැසි'
                            : 'සජීවී විභාග සහ අධීක්ෂණ සැසි'),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _refreshSessions(user?.examYear),
            icon: const Icon(Icons.refresh, color: Color(0xFF818CF8), size: 22),
            tooltip: 'Refresh Sessions',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF1E293B),
        onRefresh: () async => _refreshSessions(user?.examYear),
        child: StreamBuilder<List<PaperSession>>(
          stream: _sessionsStream,
          initialData: _cachedSessions,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString(), user?.examYear);
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData &&
                !_initialFetchDone) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6366F1)),
                    SizedBox(height: 16),
                    Text(
                      'විභාග සැසි ලබාගනිමින් පවතී...',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            final sessions = snapshot.data ?? _cachedSessions ?? [];
            if (sessions.isEmpty) {
              return _buildEmptyState(user?.examYear);
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                return _buildPaperSessionCard(sessions[index], user?.id ?? '');
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String? userExamYear) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Icon(Icons.menu_book_rounded, size: 48, color: Color(0xFF64748B)),
          ),
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
          _showAllBatches
              ? 'දැනට කිසිදු Paper Session එකක් සැලසුම් කර නොමැත.'
              : 'ඔබගේ කණ්ඩායම (${userExamYear ?? "2027 A/L"}) සඳහා ඉදිරි විභාග සැසි මෙහි දිස්වනු ඇත.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF6366F1)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _showAllBatches = !_showAllBatches;
                final target = _showAllBatches ? null : userExamYear;
                _sessionsStream = _paperService.streamSessions(examYear: target);
                _loadInitialData(target);
              });
            },
            icon: Icon(_showAllBatches ? Icons.filter_alt : Icons.all_inclusive, color: const Color(0xFF818CF8), size: 18),
            label: Text(
              _showAllBatches ? 'මගේ Batch එක පමණක් බලන්න' : 'සියලු Batches වල Sessions බලන්න',
              style: GoogleFonts.poppins(color: const Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error, String? userExamYear) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'සැසි තොරතුරු ලබාගැනීමට නොහැකි විය',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'අන්තර්ජාල සම්බන්ධතාවය පරීක්ෂා කර නැවත උත්සාහ කරන්න.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _refreshSessions(userExamYear),
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
            label: Text(
              'නැවත උත්සාහ කරන්න (Retry)',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
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

        final targetSlot = selectedSlot;
        final bool isEnded = session.isEnded;
        final bool isWaiting = session.isWaiting;
        final bool isPackageOpening = session.isPackageOpening;
        final bool isWriting = session.isWriting;
        final bool isTimeUp = session.isTimeUp;
        final bool isLive = !isEnded && !isWaiting && (session.isActive || isPackageOpening || isWriting || isTimeUp);
        final bool isUpcoming = !isEnded && isWaiting;

        // 10-Minute Package Opening Phase (directly synchronized with examiner trigger)
        int packageRemainingSecs = 600;
        if (session.packageOpeningStartedAt != null) {
          final elapsed = _now.difference(session.packageOpeningStartedAt!).inSeconds;
          if (elapsed >= 0 && elapsed <= 600) {
            packageRemainingSecs = 600 - elapsed;
          } else if (isPackageOpening) {
            packageRemainingSecs = 600;
          }
        }

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
                                        ? (isPackageOpening
                                            ? '📦 පැකේජය විවෘත කිරීමේ කාලය (Package Opening)'
                                            : (isWriting
                                                ? '✍️ විභාගය ක්‍රියාත්මකයි (Exam Writing in Progress)'
                                                : (isTimeUp
                                                    ? '⏰ වේලාව අවසන් (Time Up - Scan Answers)'
                                                    : 'විභාග සැසිය සක්‍රීයයි (Session is Live)!')))
                                        : isEnded
                                            ? 'සැසිය අවසන් (Session Completed)'
                                            : (isWaiting
                                                ? '⏳ විභාග පොරොත්තු ශාලාව විවෘතයි (Waiting Room Open)'
                                                : '${targetSlot.name} ආරම්භ වීමට:'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isLive
                                        ? (isPackageOpening
                                            ? 'කැමරාව ඉදිරියේ පාර්සලය විවෘත කරන්න (${(packageRemainingSecs ~/ 60).toString().padLeft(2, '0')}:${(packageRemainingSecs % 60).toString().padLeft(2, '0')})'
                                            : (isWriting
                                                ? 'දැන් පිළිතුරු ලිවීම ආරම්භ කරන්න (Exam Live)'
                                                : (isTimeUp
                                                    ? 'පිළිතුරු පත්‍ර Scan කර දැන්ම Submit කරන්න'
                                                    : 'වහාම Exam Room එකට පිවිසෙන්න')))
                                        : isEnded
                                            ? 'ස්තුතියි, සැසිය අවසන් කර ඇත.'
                                            : (isWaiting
                                                ? 'පොරොත්තු ශාලාවට පිවිසෙන්න (Self-Check)'
                                                : '$hours : $minutes : $seconds'),
                                    style: GoogleFonts.poppins(
                                      fontSize: isLive || isEnded || isWaiting ? 13 : 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: (isLive && !isPackageOpening) || isEnded || isWaiting ? 0 : 2,
                                      color: isLive
                                          ? (isPackageOpening
                                              ? const Color(0xFFF59E0B)
                                              : (isTimeUp ? const Color(0xFFEF4444) : const Color(0xFF4ADE80)))
                                          : isEnded
                                              ? const Color(0xFF94A3B8)
                                              : (isWaiting ? const Color(0xFF818CF8) : const Color(0xFFF59E0B)),
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: session.isEnded
                              ? const Color(0xFF475569)
                              : selectedSlotId == null
                                  ? const Color(0xFF334155)
                                  : isLive
                                      ? (isTimeUp ? const Color(0xFFEF4444) : const Color(0xFF22C55E))
                                      : isUpcoming
                                          ? const Color(0xFF6366F1)
                                          : const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: (isLive && !session.isEnded) ? 4 : 0,
                        ),
                        onPressed: session.isEnded
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🛑 මෙම විභාග සැසිය නිල වශයෙන් අවසන් කර ඇත. නැවත ඇතුල් විය නොහැක (Session Ended).'),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                              }
                            : () {
                                final auth = context.read<AuthProvider>().userModel;
                                final effectiveSlotId = selectedSlotId ?? 'slot1';
                                if (auth != null) {
                                  _paperService.registerStudentSlot(
                                    paperId: session.id,
                                    studentId: auth.id,
                                    studentName: auth.name,
                                    studentPhone: auth.phone,
                                    slotId: effectiveSlotId,
                                  ).catchError((e) => debugPrint('Auto slot reg on enter: $e'));
                                }
                                final targetUrl = '/student/papers/exam/${session.id}?slot=$effectiveSlotId';
                                try {
                                  context.push(targetUrl);
                                } catch (e) {
                                  debugPrint('Student exam route push failed: $e, trying go');
                                  context.go(targetUrl);
                                }
                              },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              session.isEnded
                                  ? Icons.cancel_outlined
                                  : isLive
                                      ? (isTimeUp ? Icons.document_scanner : Icons.videocam)
                                      : isUpcoming
                                          ? Icons.meeting_room
                                          : Icons.check_circle_outline,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                session.isEnded
                                    ? '🛑 විභාග සැසිය අවසන් විය (Ended)'
                                    : selectedSlotId == null
                                        ? 'පළමුව සැසියක් (Slot) තෝරන්න'
                                        : isLive
                                            ? (isPackageOpening
                                                ? 'Open Package in Camera Room (පාර්සලය විවෘත කරන්න)'
                                                : 'Enter Live Exam Room (කැමරාව ON කරන්න)')
                                            : isUpcoming
                                                ? 'Enter Waiting Room (පොරොත්තු ශාලාව)'
                                                : 'View Paper / Submissions',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.25,
                                ),
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
