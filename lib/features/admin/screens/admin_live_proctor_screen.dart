import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/paper_session_model.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              IconButton(
                icon: const Icon(Icons.campaign_outlined, color: Color(0xFFF59E0B), size: 24),
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
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wb_sunny_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Slot 1 (Morning)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nights_stay_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Slot 2 (Evening)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSlotProctorGrid('slot1'),
              _buildSlotProctorGrid('slot2'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotProctorGrid(String slotId) {
    return StreamBuilder<List<PaperRegistration>>(
      stream: slotId == 'slot1' ? _slot1Stream : _slot2Stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        final students = snapshot.data ?? [];
        final liveCount = students.where((s) => s.isCameraActive).length;
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
    final isLive = reg.isCameraActive;
    final isSubmitted = reg.status == 'submitted';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSubmitted
              ? const Color(0xFF38BDF8)
              : isLive
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Camera Preview Area / Live Image Stream
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: Container(
                color: const Color(0xFF0F172A),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (reg.cameraSnapshotUrl != null && reg.cameraSnapshotUrl!.isNotEmpty)
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
                          color: isLive ? const Color(0xFF22C55E).withOpacity(0.8) : const Color(0xFFEF4444).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isLive ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                        ),
                        child: Text(
                          isSubmitted ? 'SUBMITTED' : isLive ? 'ONLINE' : 'OFFLINE',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Student Details & Action
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
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showDirectMessageSheet(reg),
                    icon: const Icon(Icons.message_outlined, size: 13, color: Colors.white),
                    label: Text(
                      'Direct Alert',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
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
}
