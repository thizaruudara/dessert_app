import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/models/paper_session_model.dart';
import '../../../core/services/paper_session_service.dart';
import '../../auth/providers/auth_provider.dart';

class LiveExamRoomScreen extends StatefulWidget {
  final String paperId;
  final String slotId;

  const LiveExamRoomScreen({
    super.key,
    required this.paperId,
    required this.slotId,
  });

  @override
  State<LiveExamRoomScreen> createState() => _LiveExamRoomScreenState();
}

class _LiveExamRoomScreenState extends State<LiveExamRoomScreen> {
  final PaperSessionService _paperService = PaperSessionService();
  late final Stream<PaperSession?> _sessionStream = _paperService.streamPaperSession(widget.paperId);
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  Timer? _heartbeatTimer;
  Timer? _examCountdownTimer;
  DateTime _now = DateTime.now();

  StreamSubscription<List<ProctorAlert>>? _alertSubscription;
  final Set<String> _shownAlertIds = {};

  // Floating self preview position
  Offset _previewPosition = const Offset(16, 80);

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startTimers();
    _listenForProctorAlerts();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _isCameraPermissionGranted = true;
      });

      try {
        final cameras = await availableCameras();
        // Prefer front camera for student proctoring
        final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          frontCam,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          _sendHeartbeat(true);
        }
      } catch (e) {
        debugPrint('Camera init error: $e');
      }
    } else {
      setState(() {
        _isCameraPermissionGranted = false;
      });
    }
  }

  void _startTimers() {
    _examCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });

    // Send proctor heartbeat every 15 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _sendHeartbeat(_isCameraInitialized);
    });
  }

  Future<void> _sendHeartbeat(bool isActive) async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;

    String? snapshotBase64;
    if (isActive && _cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();
        snapshotBase64 = base64Encode(bytes);
      } catch (e) {
        debugPrint('Snapshot capture error: $e');
      }
    }

    await _paperService.updateCameraHeartbeat(
      paperId: widget.paperId,
      studentId: user.id,
      isCameraActive: isActive,
      cameraSnapshotUrl: snapshotBase64,
      status: 'in_exam',
    );
  }

  void _listenForProctorAlerts() {
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _alertSubscription = _paperService
          .streamStudentAlerts(paperId: widget.paperId, studentId: user.id)
          .listen((alerts) {
        for (final alert in alerts) {
          if (!alert.isRead && !_shownAlertIds.contains(alert.id)) {
            _shownAlertIds.add(alert.id);
            _showProctorAlertDialog(alert);
          }
        }
      });
    }
  }

  void _showProctorAlertDialog(ProctorAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alert.type == 'urgent'
                    ? const Color(0xFFEF4444).withOpacity(0.2)
                    : const Color(0xFFF59E0B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                alert.type == 'urgent' ? Icons.warning_amber_rounded : Icons.info_outline,
                color: alert.type == 'urgent' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'විභාග පරීක්ෂක පණිවිඩය',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'From: ${alert.senderName}',
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
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: alert.type == 'urgent' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            ),
          ),
          child: Text(
            alert.message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFFE2E8F0),
              height: 1.5,
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                _paperService.markAlertRead(alert.id);
                Navigator.of(ctx).pop();
              },
              child: Text(
                'තේරුම් ගතිමි (Acknowledge)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sendHeartbeat(false);
    _heartbeatTimer?.cancel();
    _examCountdownTimer?.cancel();
    _alertSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaperSession?>(
      stream: _sessionStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
          );
        }

        final session = snapshot.data!;
        final slot = widget.slotId == 'slot2' ? session.slot2 : session.slot1;
        Duration remaining = slot.endTime.difference(_now);
        if (remaining.isNegative) remaining = Duration.zero;

        final hours = remaining.inHours.toString().padLeft(2, '0');
        final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
        final isUrgent = remaining.inMinutes < 15;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
              onPressed: () {
                _showExitWarningDialog();
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  '${slot.name} • අධීක්ෂණ සැසිය',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
            actions: [
              // Live Timer Pill
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? const Color(0xFFEF4444).withOpacity(0.2)
                      : const Color(0xFF22C55E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF4ADE80),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$hours:$minutes:$seconds',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF4ADE80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Main Question Paper Viewer
              Positioned.fill(
                child: _buildPaperContent(session),
              ),

              // Floating Draggable Self Camera Preview (Privacy Safe: Only Self is Visible)
              Positioned(
                left: _previewPosition.dx,
                top: _previewPosition.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _previewPosition += details.delta;
                    });
                  },
                  child: _buildFloatingSelfCamera(),
                ),
              ),

              // Bottom Submission Bar
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: Color(0xFF4ADE80), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'කැමරා අධීක්ෂණය සක්‍රීයයි',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'ගුරුභවතුන් සජීවීව පරීක්ෂා කරයි',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          _showSubmissionDialog();
                        },
                        icon: const Icon(Icons.upload_file, size: 16, color: Colors.white),
                        label: Text(
                          'Submit Paper',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
      },
    );
  }

  Widget _buildFloatingSelfCamera() {
    return Container(
      width: 110,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isCameraInitialized && _cameraController != null)
              CameraPreview(_cameraController!)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off, color: Color(0xFFEF4444), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      'Camera Off',
                      style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'YOU (SELF)',
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
          ],
        ),
      ),
    );
  }

  Widget _buildPaperContent(PaperSession session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Color(0xFF818CF8), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📌 විභාග උපදෙස් (Exam Instructions):',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. විභාගය අතරතුර කැමරාව ක්‍රියාත්මකව තබා ගන්න.\n'
                        '2. වෙනත් tabs හෝ apps වෙත මාරු නොවන්න.\n'
                        '3. නියමිත වේලාව අවසන් වූ පසු පිළිතුරු පත්‍රයේ ඡායාරූප Submit Button එකෙන් Upload කරන්න.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Question Paper Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 48),
                const SizedBox(height: 12),
                Text(
                  'Question Paper Document',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ප්‍රශ්න පත්‍රය PDF ආකාරයෙන් බැලීමට පහත Button එක භාවිතා කරන්න',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    // Opens full PDF
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening Question Paper PDF...'),
                        backgroundColor: Color(0xFF6366F1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 16, color: Colors.white),
                  label: Text(
                    'View / Download PDF Paper',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSubmissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'පිළිතුරු පත්‍රය භාරදීම (Submit Paper)',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          'ඔබගේ අතින් ලියන ලද පිළිතුරු පත්‍රවල ඡායාරූප (Photos) හෝ PDF ගොනුව Upload කිරීමට සූදානම්ද?',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'තව ලියනවා (Cancel)',
              style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              final user = context.read<AuthProvider>().userModel;
              if (user != null) {
                _paperService.updateCameraHeartbeat(
                  paperId: widget.paperId,
                  studentId: user.id,
                  isCameraActive: false,
                  status: 'submitted',
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ පිළිතුරු පත්‍රය සාර්ථකව භාරදෙන ලදී!'),
                  backgroundColor: Color(0xFF22C55E),
                ),
              );
              context.pop();
            },
            child: Text(
              'Confirm Submit',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'විභාග ශාලාවෙන් පිටවීම?',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          'විභාග සැසිය අතරතුර පිටවීම ගුරුභවතුන්ට සටහන් වේ. ඔබට පිටවීමට අවශ්‍යද?',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('නැත (Stay)', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
            },
            child: Text('පිටවෙන්න (Exit)', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
