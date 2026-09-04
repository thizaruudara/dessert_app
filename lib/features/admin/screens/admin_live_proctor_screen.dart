import 'dart:async';
import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/paper_session_model.dart';
import '../../../core/services/agora_rtc_service.dart';
import '../../../core/services/paper_session_service.dart';

class AdminLiveProctorScreen extends StatefulWidget {
  final String paperId;

  const AdminLiveProctorScreen({
    super.key,
    required this.paperId,
  });

  @override
  State<AdminLiveProctorScreen> createState() => _AdminLiveProctorScreenState();
}

class _AdminLiveProctorScreenState extends State<AdminLiveProctorScreen> with SingleTickerProviderStateMixin {
  final PaperSessionService _paperService = PaperSessionService();
  late TabController _tabController;
  late final Stream<PaperSession?> _sessionStream = _paperService.streamPaperSession(widget.paperId);
  late final Stream<List<PaperRegistration>> _slot1Stream = _paperService.streamSlotRegistrations(widget.paperId, 'slot1');
  late final Stream<List<PaperRegistration>> _slot2Stream = _paperService.streamSlotRegistrations(widget.paperId, 'slot2');
  late final Stream<List<PaperRegistration>> _allRegistrationsStream = _paperService.streamSlotRegistrations(widget.paperId, null);
  Timer? _statusTicker;

  // Real-time Agora Video Monitoring
  RtcEngine? _agoraEngine;
  final Set<int> _activeStreamingUids = {};
  bool _isAgoraInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initAgoraMonitoring();
    // Periodically update offline calculation every 4s
    _statusTicker = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initAgoraMonitoring() async {
    try {
      await Permission.camera.request();
      await Permission.microphone.request();

      _agoraEngine = await AgoraRtcService.createAndInitEngine(
        eventHandler: RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('Agora Admin monitor joined channel: ${connection.channelId}');
            if (mounted) {
              setState(() {
                _isAgoraInitialized = true;
              });
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('Agora Admin detected remote student streaming: $remoteUid');
            if (mounted) {
              setState(() {
                _activeStreamingUids.add(remoteUid);
              });
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('Agora Admin detected student stream offline: $remoteUid');
            if (mounted) {
              setState(() {
                _activeStreamingUids.remove(remoteUid);
              });
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('Agora Admin monitor error: $err - $msg');
          },
        ),
      );

      final channelName = AgoraRtcService.getChannelName(widget.paperId);
      await AgoraRtcService.joinAsAudience(
        engine: _agoraEngine!,
        channelId: channelName,
        uid: 1, // Admin monitor UID
      );
    } catch (e) {
      debugPrint('Agora Admin monitor init error: $e');
    }
  }

  @override
  void dispose() {
    _statusTicker?.cancel();
    _tabController.dispose();
    AgoraRtcService.leaveAndRelease(_agoraEngine);
    _agoraEngine = null;
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaperSession?>(
      stream: _sessionStream,
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live Invigilator Monitor',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Text(
                  session?.title ?? 'Exam Proctoring Center',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
            actions: [
              if (session != null) ...[
                if (!session.isEnded) ...[
                  // Trigger Time Up Button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: session.isTimeUp ? const Color(0xFFEA580C) : const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _confirmTriggerTimeUp(session),
                      icon: const Icon(Icons.alarm_on, size: 15, color: Colors.black),
                      label: Text(
                        session.isTimeUp ? 'Time Up (Sent)' : 'Time Up',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ),

                  // End Session Button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _confirmEndSession(session),
                      icon: const Icon(Icons.stop_circle_outlined, size: 15, color: Colors.white),
                      label: Text(
                        'End Session',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFFFCA5A5), size: 14),
                          const SizedBox(width: 4),
                          Text('Ended', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFFCA5A5))),
                        ],
                      ),
                    ),
                  ),
              ],
              IconButton(
                icon: const Icon(Icons.campaign_outlined, color: Color(0xFFF59E0B), size: 22),
                tooltip: 'Broadcast Announcement to All Students',
                onPressed: () => _showBroadcastDialog(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6366F1),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF94A3B8),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wb_sunny_outlined, size: 15),
                      const SizedBox(width: 5),
                      Text(session?.slot2 != null ? 'Slot 1' : 'Slot 1 (Live)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.nights_stay_outlined, size: 15),
                      const SizedBox(width: 5),
                      Text(session?.slot2 != null ? 'Slot 2' : 'Slot 2 (None)'),
                    ],
                  ),
                ),
                Tab(
                  child: StreamBuilder<List<PaperRegistration>>(
                    stream: _allRegistrationsStream,
                    builder: (context, snap) {
                      final submissionsCount = (snap.data ?? []).where((s) => s.status == 'submitted' || s.submissionPhotos.isNotEmpty).length;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_turned_in_rounded, size: 15, color: Color(0xFF4ADE80)),
                          const SizedBox(width: 5),
                          Text('Answers ($submissionsCount)'),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildSessionPhaseControlBar(session),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSlotProctorGrid('slot1', session),
                    _buildSlotProctorGrid('slot2', session),
                    _buildSubmittedAnswersSection(session),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotProctorGrid(String slotId, PaperSession? session) {
    return StreamBuilder<List<PaperRegistration>>(
      stream: slotId == 'slot1' ? _slot1Stream : _slot2Stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        final students = snapshot.data ?? [];
        final liveCount = students.where((s) => s.isOnline).length;
        final submittedCount = students.where((s) => s.status == 'submitted').length;

        return Column(
          children: [
            // Top Analytics Stats Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1E293B).withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge('Registered', '${students.length}', const Color(0xFF818CF8)),
                  _buildStatBadge('🟢 Live Cameras', '$liveCount', const Color(0xFF22C55E)),
                  _buildStatBadge('🔴 Inactive', '${students.length - liveCount - submittedCount}', const Color(0xFFEF4444)),
                  _buildStatBadge('✅ Submitted', '$submittedCount', const Color(0xFF38BDF8)),
                ],
              ),
            ),

            // Grid View
            Expanded(
              child: students.isEmpty
                  ? Center(
                      child: Text(
                        slotId == 'slot2' && session?.slot2 == null
                            ? 'මෙම Paper එක සඳහා 2nd Slot එකක් සකසා නොමැත.\n(Single Slot Session)'
                            : 'මෙම සැසිය සඳහා තවම ශිෂ්‍යයින් ලියාපදිංචි වී නොමැත.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        return _buildStudentProctorCard(students[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildStudentProctorCard(PaperRegistration reg) {
    final isLive = reg.isOnline;
    final isSubmitted = reg.status == 'submitted';
    final studentUid = reg.computedAgoraUid;
    final bool isStreamingVideo = _isAgoraInitialized && _agoraEngine != null && _activeStreamingUids.contains(studentUid);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSubmitted
              ? const Color(0xFF38BDF8)
              : isStreamingVideo
                  ? const Color(0xFF22C55E)
                  : isLive
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFEF4444),
          width: (isStreamingVideo || isLive) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Camera Preview Area / Live Real-Time Stream (Tap to view full screen)
          Expanded(
            child: InkWell(
              onTap: () => _showFullScreenStudentViewer(reg),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isStreamingVideo)
                        AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _agoraEngine!,
                            canvas: VideoCanvas(uid: studentUid),
                            connection: RtcConnection(
                              channelId: AgoraRtcService.getChannelName(widget.paperId),
                            ),
                          ),
                        )
                      else if (reg.cameraSnapshotUrl != null && reg.cameraSnapshotUrl!.isNotEmpty)
                        Builder(
                          builder: (_) {
                            try {
                              final raw = reg.cameraSnapshotUrl!;
                              if (raw.startsWith('http')) {
                                return Image.network(raw, fit: BoxFit.cover);
                              } else {
                                final bytes = base64Decode(raw.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''));
                                return Image.memory(bytes, fit: BoxFit.cover);
                              }
                            } catch (_) {
                              return _buildCameraPlaceholder(isSubmitted, isLive);
                            }
                          },
                        )
                      else
                        _buildCameraPlaceholder(isSubmitted, isLive),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSubmitted
                                ? const Color(0xFF38BDF8).withOpacity(0.85)
                                : isStreamingVideo
                                    ? const Color(0xFF22C55E).withOpacity(0.9)
                                    : isLive
                                        ? const Color(0xFF3B82F6).withOpacity(0.85)
                                        : const Color(0xFFEF4444).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSubmitted
                                  ? const Color(0xFF38BDF8)
                                  : isStreamingVideo
                                      ? const Color(0xFF22C55E)
                                      : isLive
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFFEF4444),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isStreamingVideo) ...[
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isSubmitted
                                    ? 'SUBMITTED'
                                    : isStreamingVideo
                                        ? 'LIVE'
                                        : isLive
                                            ? 'ONLINE'
                                            : 'OFFLINE',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.fullscreen, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Student Details & Actions
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reg.studentName,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  reg.studentPhone.isNotEmpty ? reg.studentPhone : 'ID: ${reg.studentId.substring(0, 6)}...',
                  style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 8),
                if (reg.submissionPhotos.isNotEmpty || reg.status == 'submitted') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _showStudentSubmissionViewer(reg),
                      icon: const Icon(Icons.collections_rounded, size: 13, color: Colors.white),
                      label: Text(
                        'View Answers (${reg.submissionPhotos.length})',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _showFullScreenStudentViewer(reg),
                          icon: const Icon(Icons.fullscreen, size: 13, color: Color(0xFF38BDF8)),
                          label: Text(
                            'Full View',
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _showDirectMessageSheet(reg),
                          icon: const Icon(Icons.message_outlined, size: 13, color: Colors.white),
                          label: Text(
                            'Alert',
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder(bool isSubmitted, bool isLive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSubmitted
                ? Icons.task_alt
                : isLive
                    ? Icons.videocam
                    : Icons.videocam_off,
            size: 32,
            color: isSubmitted
                ? const Color(0xFF38BDF8)
                : isLive
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
          ),
          const SizedBox(height: 6),
          Text(
            isSubmitted
                ? 'Paper Submitted'
                : isLive
                    ? 'Proctor Stream Active'
                    : 'Camera Offline',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isLive ? const Color(0xFF4ADE80) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  void _showDirectMessageSheet(PaperRegistration student) {
    final msgCtrl = TextEditingController();

    final quickWarnings = [
      'කරුණාකර ඔබගේ මේසය සහ පිළිතුරු පත්‍රය පෙනෙන සේ කැමරාව සකසන්න. (Please adjust camera angle)',
      'ඔබගේ මුහුණ සහ පරිසරය පැහැදිලිව නොපෙනේ. (Please improve lighting/position)',
      'විභාග කාලය අවසන් වීමට විනාඩි 15 ක් ඉතිරිව ඇත. (15 Minutes Remaining)',
      'කරුණාකර අවධානයෙන් පිළිතුරු ලියන්න. වෙනත් කටයුතු වලින් වළකින්න.',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.send_to_mobile, color: Color(0xFF818CF8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Proctor Alert (ශිෂ්‍යයාට පණිවිඩයක්)',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'To: ${student.studentName} (${student.studentPhone})',
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'ක්ෂණික අනතුරු ඇඟවීම් (Quick Warnings):',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: quickWarnings.map((warn) {
                return ActionChip(
                  backgroundColor: const Color(0xFF0F172A),
                  label: Text(
                    warn,
                    style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFE2E8F0)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    msgCtrl.text = warn;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'පණිවිඩය මෙහි ටයිප් කරන්න...',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                onPressed: () async {
                  if (msgCtrl.text.trim().isEmpty) return;
                  await _paperService.sendProctorAlert(
                    paperId: widget.paperId,
                    studentId: student.studentId,
                    senderName: 'Admin / Teacher',
                    message: msgCtrl.text.trim(),
                    type: 'warning',
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Alert sent instantly to ${student.studentName}!'),
                        backgroundColor: const Color(0xFF22C55E),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.send, size: 16, color: Colors.white),
                label: Text(
                  'Send Instant Alert to Student',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentSubmissionViewer(PaperRegistration student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          final photos = student.submissionPhotos;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF4ADE80), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.studentName,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '${student.studentPhone} • Submitted: ${photos.length} Answer Items',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (photos.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, size: 36, color: Color(0xFF64748B)),
                        const SizedBox(height: 8),
                        Text(
                          'No answer sheet photos attached yet.',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  for (int i = 0; i < photos.length; i++) ...[
                    Builder(
                      builder: (_) {
                        final photo = photos[i];
                        final isHttp = photo.startsWith('http://') || photo.startsWith('https://');
                        final isStorageImage = isHttp &&
                            (photo.contains('firebasestorage') ||
                                photo.contains('.jpg') ||
                                photo.contains('.jpeg') ||
                                photo.contains('.png') ||
                                photo.contains('.webp'));

                        if (isStorageImage) {
                          // Firebase Cloud Storage Answer Sheet Image (with Zoom)
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Page ${i + 1}',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.zoom_in, color: Color(0xFF94A3B8), size: 16),
                                    ],
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                                  child: InteractiveViewer(
                                    panEnabled: true,
                                    minScale: 0.8,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      photo,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          height: 250,
                                          alignment: Alignment.center,
                                          child: CircularProgressIndicator(
                                            value: progress.expectedTotalBytes != null
                                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                                : null,
                                            color: const Color(0xFF22C55E),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 120,
                                        alignment: Alignment.center,
                                        child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.broken_image, color: Color(0xFFEF4444), size: 28),
                                            SizedBox(height: 6),
                                            Text('Failed to load image', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (isHttp) {
                          // Drive / Web Link
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link, color: Color(0xFF38BDF8), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Attached Document / Drive Link',
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      Text(
                                        photo,
                                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF38BDF8)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, color: Color(0xFF38BDF8), size: 18),
                                  onPressed: () async {
                                    final uri = Uri.tryParse(photo);
                                    if (uri != null && await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Base64 Answer Sheet Image (legacy fallback)
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Page ${i + 1}',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.zoom_in, color: Color(0xFF94A3B8), size: 16),
                                    ],
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                                  child: InteractiveViewer(
                                    panEnabled: true,
                                    minScale: 0.8,
                                    maxScale: 4.0,
                                    child: Image.memory(
                                      base64Decode(
                                        photo.contains(',') ? photo.split(',')[1] : photo,
                                      ),
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }


  void _showFullScreenStudentViewer(PaperRegistration student) {
    final studentUid = student.computedAgoraUid;
    final bool isStreaming = _isAgoraInitialized && _agoraEngine != null && _activeStreamingUids.contains(studentUid);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenStudentViewerScreen(
          initialRegistration: student,
          paperService: _paperService,
          agoraEngine: _agoraEngine,
          isAgoraStreaming: isStreaming,
          channelId: AgoraRtcService.getChannelName(widget.paperId),
          onSendAlert: (s) => _showDirectMessageSheet(s),
          onViewAnswers: (s) => _showStudentSubmissionViewer(s),
        ),
      ),
    );
  }

  void _confirmEndSession(PaperSession session) {
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
          'ඔබට මෙම Paper Session එක අවසන් කිරීමට අවශ්‍ය බව සහතිකද?\n\nසැසිය අවසන් කළ පසු සියලුම සිසුන්ගේ විභාග කාමරය වසා දැමෙන අතර නව submissions ලබාගත නොහැක.',
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

  void _showBroadcastDialog() {
    final broadcastCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Room-wide Broadcast (සියලු දෙනාටම නිවේදනයක්)',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: TextField(
          controller: broadcastCtrl,
          maxLines: 3,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'උදා: ප්‍රශ්න අංක 04 හි පැහැදිලි කිරීමක්...',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () async {
              if (broadcastCtrl.text.trim().isEmpty) return;
              await _paperService.broadcastProctorAlert(
                paperId: widget.paperId,
                senderName: 'Admin / Examiner',
                message: broadcastCtrl.text.trim(),
                type: 'info',
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📢 Broadcast sent to all students!'), backgroundColor: Color(0xFF22C55E)),
                );
              }
            },
            child: Text('Broadcast Alert', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmTriggerTimeUp(PaperSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.alarm_on, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Trigger Time Up (වේලාව අවසන් කරන්නද?)',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          'සියලුම සිසුන්ට ලිවීම නවත්වා, පිළිතුරු පත්‍රවල ඡායාරූප (Photos) ලබාගෙන App එක හරහා Submit කරන ලෙස Alert එකක් යැවීමට අවශ්‍ය බව සහතිකද?',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFCBD5E1), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _paperService.triggerTimeUp(session.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⏰ Time Up Alert sent to all students!'),
                      backgroundColor: Color(0xFFF59E0B),
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
            child: Text('Trigger Time Up (දන්වන්න)', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPhaseControlBar(PaperSession? session) {
    if (session == null) return const SizedBox.shrink();

    final phase = session.currentPhase;
    Color phaseColor;
    String phaseLabel;
    IconData phaseIcon;

    switch (phase) {
      case 'package_opening':
        phaseColor = const Color(0xFFF59E0B);
        phaseLabel = '📦 Package Opening (10 Mins Active)';
        phaseIcon = Icons.inventory_2_rounded;
        break;
      case 'writing':
        phaseColor = const Color(0xFF22C55E);
        phaseLabel = '✍️ Exam Writing In Progress';
        phaseIcon = Icons.edit_note_rounded;
        break;
      case 'time_up':
        phaseColor = const Color(0xFFEA580C);
        phaseLabel = '⏰ Time is Up (Collecting Answers)';
        phaseIcon = Icons.alarm_on_rounded;
        break;
      case 'ended':
        phaseColor = const Color(0xFFEF4444);
        phaseLabel = '🛑 Session Ended';
        phaseIcon = Icons.cancel_outlined;
        break;
      case 'waiting':
      default:
        phaseColor = const Color(0xFF818CF8);
        phaseLabel = '⏳ Waiting Room (Students Waiting)';
        phaseIcon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: phaseColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: phaseColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(phaseIcon, size: 14, color: phaseColor),
                    const SizedBox(width: 6),
                    Text(
                      phaseLabel,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: phaseColor),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Manual Phase Controls',
                style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (phase == 'waiting') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmSetPhase(
                      session,
                      'package_opening',
                      'Start Package Opening (ප්‍රශ්න පත්‍ර විවෘත කිරීම)',
                      'සිසුන්ට මුද්‍රා තැබූ ප්‍රශ්න පත්‍ර පාර්සලය කැමරාව ඉදිරියේ විවෘත කිරීමට විනාඩි 10 ක කාලය ආරම්භ කිරීමට අවශ්‍ය බව සහතිකද?',
                      const Color(0xFFF59E0B),
                    ),
                    icon: const Icon(Icons.inventory_2, size: 14, color: Colors.black),
                    label: Text(
                      'Start Package Opening (10m)',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF22C55E)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmSetPhase(
                      session,
                      'writing',
                      'Directly Start Exam (විභාගය ආරම්භ කරන්න)',
                      'Package Opening අදියර මගහැර කෙලින්ම පිළිතුරු ලිවීමේ අදියර ආරම්භ කිරීමට අවශ්‍ය බව සහතිකද?',
                      const Color(0xFF22C55E),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Color(0xFF22C55E)),
                    label: Text(
                      'Start Writing Direct',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF22C55E)),
                    ),
                  ),
                ] else if (phase == 'package_opening') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmSetPhase(
                      session,
                      'writing',
                      'Start Exam Writing (ලිවීම අරඹන්න)',
                      'ප්‍රශ්න පත්‍ර පාර්සල් විවෘත කිරීම අවසන් කර සිසුන්ට පිළිතුරු ලිවීම ආරම්භ කිරීමට Alert එකක් යැවීමට අවශ්‍යද?',
                      const Color(0xFF22C55E),
                    ),
                    icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                    label: Text(
                      'Start Exam Writing (ලිවීම අරඹන්න)',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmSetPhase(
                      session,
                      'package_opening',
                      'Restart 10m Timer (කාලය නැවත අරඹන්න)',
                      'ප්‍රශ්න පත්‍ර විවෘත කිරීමේ විනාඩි 10 ක කාලය නැවත 10:00 සිට ආරම්භ කිරීමට අවශ්‍යද?',
                      const Color(0xFFF59E0B),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 14, color: Colors.black),
                    label: Text(
                      'Restart 10m Timer',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmEndSession(session),
                    icon: const Icon(Icons.stop_circle_outlined, size: 14, color: Colors.white),
                    label: Text(
                      'End Session',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ] else if (phase == 'writing') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmTriggerTimeUp(session),
                    icon: const Icon(Icons.alarm_on, size: 14, color: Colors.black),
                    label: Text(
                      '⏰ Trigger Time Up (වේලාව අවසන්)',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmEndSession(session),
                    icon: const Icon(Icons.stop_circle_outlined, size: 14, color: Colors.white),
                    label: Text(
                      'End Session',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ] else if (phase == 'time_up') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmEndSession(session),
                    icon: const Icon(Icons.stop_circle_outlined, size: 14, color: Colors.white),
                    label: Text(
                      'End Session (සැසිය අවසන් කරන්න)',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmSetPhase(
                      session,
                      'writing',
                      'Resume Exam Writing',
                      'නැවතත් ලිවීමේ අදියර ක්‍රියාත්මක කිරීමට අවශ්‍යද?',
                      const Color(0xFF38BDF8),
                    ),
                    icon: const Icon(Icons.replay, size: 14, color: Color(0xFF38BDF8)),
                    label: Text(
                      'Resume Writing',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8)),
                    ),
                  ),
                ] else if (phase == 'ended') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmSetPhase(
                      session,
                      'writing',
                      'Reopen Paper Session',
                      'මෙම අවසන් වූ සැසිය නැවත විවෘත කිරීමට අවශ්‍ය බව සහතිකද?',
                      const Color(0xFF6366F1),
                    ),
                    icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                    label: Text(
                      'Reopen Session (නැවත අරඹන්න)',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _confirmSetPhase(PaperSession session, String targetPhase, String title, String description, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(description, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFCBD5E1), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _paperService.setSessionPhase(session.id, targetPhase);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Phase updated to: $targetPhase'),
                      backgroundColor: color,
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
            child: Text('Confirm', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedAnswersSection(PaperSession? session) {
    return StreamBuilder<List<PaperRegistration>>(
      stream: _allRegistrationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        final allStudents = snapshot.data ?? [];
        final submittedStudents = allStudents.where((s) => s.status == 'submitted' || s.submissionPhotos.isNotEmpty).toList();
        submittedStudents.sort((a, b) {
          final aTime = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        return Column(
          children: [
            // Top Analytics Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in, color: Color(0xFF4ADE80), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submitted Answer Sheets (ලැබුණු පිළිතුරු පත්‍ර)',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${submittedStudents.length} of ${allStudents.length} Students Submitted',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF22C55E)),
                    ),
                    child: Text(
                      '${submittedStudents.length} Submitted',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4ADE80)),
                    ),
                  ),
                ],
              ),
            ),

            // Students Answer Sheet List
            Expanded(
              child: submittedStudents.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1E293B),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: const Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'තවමත් පිළිතුරු පත්‍ර ලැබී නොමැත',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'සිසුන් පිළිතුරු පත්‍ර ඡායාරූප ගෙන Submit කළ පසු ඒවා ශිෂ්‍ය නාමය සමඟ මෙහි සජීවීව දිස්වනු ඇත.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: submittedStudents.length,
                      itemBuilder: (context, index) {
                        final student = submittedStudents[index];
                        return _buildSubmittedStudentItem(student, index + 1);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubmittedStudentItem(PaperRegistration student, int index) {
    final photos = student.submissionPhotos;
    final submittedTimeStr = student.submittedAt != null
        ? '${student.submittedAt!.hour.toString().padLeft(2, '0')}:${student.submittedAt!.minute.toString().padLeft(2, '0')}'
        : 'Submitted';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Phone, Status badge
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF6366F1)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.studentName,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${student.studentPhone.isNotEmpty ? student.studentPhone : "No phone"} • ${student.selectedSlot.toUpperCase()} • $submittedTimeStr',
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF22C55E)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${photos.length} Pages',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4ADE80)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Thumbnail Preview Strip (if photos attached)
          if (photos.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 64,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (context, pIdx) {
                    final photoItem = photos[pIdx];
                    final isHttp = photoItem.startsWith('http://') || photoItem.startsWith('https://');
                    final isStorageImage = isHttp &&
                        (photoItem.contains('firebasestorage') ||
                            photoItem.contains('.jpg') ||
                            photoItem.contains('.jpeg') ||
                            photoItem.contains('.png') ||
                            photoItem.contains('.webp'));
                    final isLink = isHttp && !isStorageImage;

                    return Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF475569)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: isStorageImage
                            ? Image.network(
                                photoItem,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image, color: Color(0xFFEF4444), size: 20),
                                ),
                              )
                            : isLink
                                ? const Center(child: Icon(Icons.link, color: Color(0xFF38BDF8), size: 22))
                                : Builder(
                                    builder: (_) {
                                      try {
                                        final clean = photoItem.contains(',') ? photoItem.split(',')[1] : photoItem;
                                        return Image.memory(
                                          base64Decode(clean),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Icon(Icons.image, color: Color(0xFF64748B), size: 20),
                                          ),
                                        );
                                      } catch (_) {
                                        return const Center(child: Icon(Icons.broken_image, color: Color(0xFFEF4444), size: 20));
                                      }
                                    },
                                  ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Footer Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showStudentSubmissionViewer(student),
                      icon: const Icon(Icons.zoom_in, size: 16, color: Colors.white),
                      label: Text(
                        'Inspect All Pages (${photos.length})',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                if (student.studentPhone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF22C55E)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _makePhoneCall(student.studentPhone),
                      icon: const Icon(Icons.phone, size: 14, color: Color(0xFF4ADE80)),
                      label: Text(
                        'Call',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4ADE80)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showDirectMessageSheet(student),
                    icon: const Icon(Icons.message_outlined, size: 14, color: Color(0xFF818CF8)),
                    label: Text(
                      'Alert',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF818CF8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenStudentViewerScreen extends StatefulWidget {
  final PaperRegistration initialRegistration;
  final PaperSessionService paperService;
  final RtcEngine? agoraEngine;
  final bool isAgoraStreaming;
  final String channelId;
  final void Function(PaperRegistration) onSendAlert;
  final void Function(PaperRegistration) onViewAnswers;

  const _FullScreenStudentViewerScreen({
    required this.initialRegistration,
    required this.paperService,
    this.agoraEngine,
    this.isAgoraStreaming = false,
    this.channelId = '',
    required this.onSendAlert,
    required this.onViewAnswers,
  });

  @override
  State<_FullScreenStudentViewerScreen> createState() => _FullScreenStudentViewerScreenState();
}

class _FullScreenStudentViewerScreenState extends State<_FullScreenStudentViewerScreen> {
  final TransformationController _transformationController = TransformationController();
  bool _showControls = true;
  Timer? _statusTicker;

  @override
  void initState() {
    super.initState();
    _statusTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTicker?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaperRegistration?>(
      stream: widget.paperService.streamStudentRegistration(
        widget.initialRegistration.paperId,
        widget.initialRegistration.studentId,
      ),
      initialData: widget.initialRegistration,
      builder: (context, snapshot) {
        final reg = snapshot.data ?? widget.initialRegistration;
        final isLive = reg.isOnline;
        final isSubmitted = reg.status == 'submitted';

        return Scaffold(
          backgroundColor: const Color(0xFF090D16),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Interactive Full-Screen Live Video Feed ────────────────
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 5.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Builder(
                      builder: (context) {
                        if (widget.agoraEngine != null && widget.isAgoraStreaming) {
                          return SizedBox.expand(
                            child: AgoraVideoView(
                              controller: VideoViewController.remote(
                                rtcEngine: widget.agoraEngine!,
                                canvas: VideoCanvas(uid: reg.computedAgoraUid),
                                connection: RtcConnection(channelId: widget.channelId),
                              ),
                            ),
                          );
                        }
                        final raw = reg.cameraSnapshotUrl;
                        if (raw != null && raw.isNotEmpty) {
                          try {
                            if (raw.startsWith('http')) {
                              return Image.network(
                                raw,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => _buildOfflinePlaceholder(isSubmitted, isLive, reg),
                              );
                            } else {
                              final clean = raw.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
                              return Image.memory(
                                base64Decode(clean),
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => _buildOfflinePlaceholder(isSubmitted, isLive, reg),
                              );
                            }
                          } catch (_) {
                            return _buildOfflinePlaceholder(isSubmitted, isLive, reg);
                          }
                        }
                        return _buildOfflinePlaceholder(isSubmitted, isLive, reg);
                      },
                    ),
                  ),
                ),
              ),

              // ── 2. Top App Bar / Status Overlay ──────────────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                top: _showControls ? 0 : -120,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 12,
                    left: 12,
                    right: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    reg.studentName,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSubmitted
                                        ? const Color(0xFF38BDF8).withOpacity(0.2)
                                        : widget.isAgoraStreaming
                                            ? const Color(0xFF22C55E).withOpacity(0.2)
                                            : isLive
                                                ? const Color(0xFF3B82F6).withOpacity(0.2)
                                                : const Color(0xFFEF4444).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSubmitted
                                          ? const Color(0xFF38BDF8)
                                          : widget.isAgoraStreaming
                                              ? const Color(0xFF22C55E)
                                              : isLive
                                                  ? const Color(0xFF3B82F6)
                                                  : const Color(0xFFEF4444),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSubmitted
                                              ? const Color(0xFF38BDF8)
                                              : isLive
                                                  ? const Color(0xFF22C55E)
                                                  : const Color(0xFFEF4444),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isSubmitted
                                            ? 'SUBMITTED'
                                            : isLive
                                                ? 'LIVE PROCTOR'
                                                : 'OFFLINE',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isSubmitted
                                              ? const Color(0xFF38BDF8)
                                              : isLive
                                                  ? const Color(0xFF4ADE80)
                                                  : const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${reg.studentPhone.isNotEmpty ? reg.studentPhone : "No phone"} • ${reg.selectedSlot.toUpperCase()}',
                              style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (reg.studentPhone.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.phone, color: Color(0xFF4ADE80), size: 18),
                            tooltip: 'Call Student',
                            onPressed: () => _makePhoneCall(reg.studentPhone),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.restart_alt, color: Colors.white, size: 18),
                          tooltip: 'Reset Zoom',
                          onPressed: _resetZoom,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 3. Bottom Control & Actions Bar ───────────────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                bottom: _showControls ? 0 : -140,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: 14,
                    bottom: MediaQuery.of(context).padding.bottom + 14,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.95),
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status strip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pinch, color: Color(0xFF94A3B8), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Pinch to Zoom Desk/Paper',
                              style: GoogleFonts.poppins(color: const Color(0xFFCBD5E1), fontSize: 10),
                            ),
                            const SizedBox(width: 12),
                            Container(width: 1, height: 10, color: const Color(0xFF475569)),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.sync,
                              size: 12,
                              color: isLive ? const Color(0xFF4ADE80) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reg.lastCameraPing != null
                                  ? 'Ping: ${DateTime.now().difference(reg.lastCameraPing!).inSeconds}s ago'
                                  : 'No Ping',
                              style: GoogleFonts.poppins(
                                color: isLive ? const Color(0xFF4ADE80) : const Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons Row
                      Row(
                        children: [
                          if (reg.submissionPhotos.isNotEmpty || reg.status == 'submitted') ...[
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => widget.onViewAnswers(reg),
                                  icon: const Icon(Icons.collections_bookmark_rounded, size: 16, color: Colors.white),
                                  label: Text(
                                    'View Answers (${reg.submissionPhotos.length})',
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => widget.onSendAlert(reg),
                                icon: const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.white),
                                label: Text(
                                  'Direct Warning / Alert',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildOfflinePlaceholder(bool isSubmitted, bool isLive, PaperRegistration reg) {
    return Container(
      color: const Color(0xFF090D16),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E293B),
              border: Border.all(
                color: isSubmitted
                    ? const Color(0xFF38BDF8)
                    : isLive
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                width: 2,
              ),
            ),
            child: Icon(
              isSubmitted
                  ? Icons.task_alt
                  : isLive
                      ? Icons.videocam
                      : Icons.videocam_off,
              size: 48,
              color: isSubmitted
                  ? const Color(0xFF38BDF8)
                  : isLive
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isSubmitted
                ? 'Paper Submitted'
                : isLive
                    ? 'Connecting to Live Camera Stream...'
                    : 'Student Camera Offline',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLive
                ? 'Waiting for video frame from ${reg.studentName}...'
                : 'Student may have minimized the app or network is interrupted.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

