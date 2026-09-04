import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/models/paper_session_model.dart';
import '../../../core/services/paper_session_service.dart';
import '../../../core/services/screen_keep_on_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'in_app_document_scanner_screen.dart';

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

class _LiveExamRoomScreenState extends State<LiveExamRoomScreen> with WidgetsBindingObserver {
  final PaperSessionService _paperService = PaperSessionService();
  late final Stream<PaperSession?> _sessionStream = _paperService.streamPaperSession(widget.paperId);
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  Timer? _heartbeatTimer;
  Timer? _examCountdownTimer;
  DateTime _now = DateTime.now();
  final DateTime _enteredRoomAt = DateTime.now().subtract(const Duration(seconds: 10));
  bool _isCurrentlyWaiting = true;

  StreamSubscription<List<ProctorAlert>>? _alertSubscription;
  final Set<String> _shownAlertIds = {};

  // Camera flip and availability
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isSendingHeartbeat = false;
  bool _hasExitedDueToEnd = false;
  bool _hasPromptedTimeUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenKeepOnService.setKeepScreenOn(true);
    _ensureStudentRegistered();
    _initCamera();
    _startTimers();
    _listenForProctorAlerts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // 1. Immediately pause background heartbeat timer so it does NOT fire while app is in background
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      // 2. Immediately report camera inactive when student leaves the app or turns off screen
      _setOfflineStatus();
    } else if (state == AppLifecycleState.resumed) {
      if (_isCameraInitialized) {
        _startTimers();
        _sendHeartbeat(true);
      }
    }
  }

  Future<void> _setOfflineStatus() async {
    try {
      final user = context.read<AuthProvider>().userModel;
      if (user == null) return;
      await _paperService.updateCameraHeartbeat(
        paperId: widget.paperId,
        studentId: user.id,
        isCameraActive: false,
      );
    } catch (e) {
      debugPrint('Error reporting student offline status: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _examCountdownTimer?.cancel();
    _examCountdownTimer = null;
    _alertSubscription?.cancel();
    _alertSubscription = null;
    _cameraController?.dispose();
    _cameraController = null;
    ScreenKeepOnService.setKeepScreenOn(false);

    // Immediately mark offline in Firestore when leaving exam room
    _setOfflineStatus();

    super.dispose();
  }

  Future<void> _ensureStudentRegistered() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    try {
      await _paperService.registerStudentSlot(
        paperId: widget.paperId,
        studentId: user.id,
        studentName: user.name,
        studentPhone: user.phone,
        slotId: widget.slotId.isNotEmpty ? widget.slotId : 'slot1',
      );
    } catch (e) {
      debugPrint('Auto-registration ensure: $e');
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _isCameraPermissionGranted = true;
      });

      try {
        _availableCameras = await availableCameras();
        if (_availableCameras.isEmpty) return;

        // Prefer front camera for proctoring
        final frontIndex = _availableCameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;

        await _startCameraController(_availableCameras[_selectedCameraIndex]);
      } catch (e) {
        debugPrint('Camera init error: $e');
      }
    } else {
      setState(() {
        _isCameraPermissionGranted = false;
      });
    }
  }

  Future<void> _startCameraController(CameraDescription camera) async {
    // Use ResolutionPreset.low for invigilator snapshots:
    // Super lightweight (~20-30 KB), prevents Wi-Fi network congestion,
    // avoids Firestore 1MB document limit, and uploads in milliseconds!
    _cameraController = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
      _sendHeartbeat(true);
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _cameraController?.dispose();
    setState(() {
      _isCameraInitialized = false;
    });
    await _startCameraController(_availableCameras[_selectedCameraIndex]);
  }

  void _startTimers() {
    _examCountdownTimer?.cancel();
    _examCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });

    // Send proctor heartbeat every 4 seconds (Super-smooth proctoring optimized for 5 students)
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _sendHeartbeat(_isCameraInitialized);
    });
  }

  Future<void> _sendHeartbeat(bool isActive) async {
    if (!isActive) {
      await _setOfflineStatus();
      return;
    }

    if (_isSendingHeartbeat) return;
    _isSendingHeartbeat = true;

    try {
      final user = context.read<AuthProvider>().userModel;
      if (user == null) return;

      String? snapshotBase64;
      // Only capture heavy camera photo snapshots during live active exam phases, NOT while in the waiting room
      if (isActive && !_isCurrentlyWaiting && _cameraController != null && _cameraController!.value.isInitialized) {
        try {
          final image = await _cameraController!.takePicture();
          final bytes = await image.readAsBytes();
          snapshotBase64 = base64Encode(bytes);
          try {
            File(image.path).delete().catchError((_) => image as FileSystemEntity);
          } catch (_) {}
        } catch (e) {
          debugPrint('Snapshot capture error: $e');
        }
      }

      await _paperService.updateCameraHeartbeat(
        paperId: widget.paperId,
        studentId: user.id,
        studentName: user.name,
        studentPhone: user.phone,
        slotId: widget.slotId.isNotEmpty ? widget.slotId : 'slot1',
        isCameraActive: isActive,
        cameraSnapshotUrl: snapshotBase64,
        status: 'in_exam',
      );
    } finally {
      _isSendingHeartbeat = false;
    }
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
            // Skip old historical alerts that occurred before student entered room
            if (alert.createdAt.isBefore(_enteredRoomAt)) {
              continue;
            }
            if (alert.studentId == 'ALL') {
              _showBroadcastAlertNotification(alert);
            } else {
              _showProctorAlertDialog(alert);
            }
          }
        }
      });
    }
  }

  void _showBroadcastAlertNotification(ProctorAlert alert) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 75),
        backgroundColor: alert.type == 'urgent'
            ? const Color(0xFFEF4444)
            : const Color(0xFF6366F1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                alert.type == 'urgent' ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.senderName.isNotEmpty ? alert.senderName : 'Examiner Notice (විභාග පරීක්ෂක)',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.message,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProctorAlertDialog(ProctorAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: true,
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
        final slot = (widget.slotId == 'slot2' && session.slot2 != null) ? session.slot2! : session.slot1;

        final bool isEnded = session.isEnded;
        final bool isTimeUp = session.isTimeUp;
        final bool isWaiting = session.isWaiting;
        final bool isPackageOpening = session.isPackageOpening;
        final bool isWriting = session.isWriting;

        _isCurrentlyWaiting = isWaiting;

        // Auto-exit if session was ended by admin
        if (isEnded && !_hasExitedDueToEnd) {
          _hasExitedDueToEnd = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleSessionEndedByAdmin();
          });
        } else if (isTimeUp && !_hasPromptedTimeUp && !isEnded) {
          _hasPromptedTimeUp = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTimeUpDialog();
          });
        }

        // Package Opening Countdown (10 Minutes from packageOpeningStartedAt)
        int packageOpeningSecsLeft = 600;
        if (session.packageOpeningStartedAt != null) {
          final elapsed = _now.difference(session.packageOpeningStartedAt!).inSeconds;
          packageOpeningSecsLeft = (600 - elapsed).clamp(0, 600);
        }

        // Real Exam Writing Phase
        DateTime examStartTime = session.writingStartedAt ?? slot.startTime;
        DateTime examEndTime = examStartTime.add(Duration(minutes: session.durationMinutes));
        final bool isOvertime = isWriting && _now.isAfter(examEndTime);
        final Duration examWritingTimeLeft = isWriting && !isOvertime ? examEndTime.difference(_now) : Duration.zero;
        final Duration overtimeDuration = isOvertime ? _now.difference(examEndTime) : Duration.zero;

        Duration durationToShow;
        String timerPrefix;
        Color timerColor;
        IconData timerIcon;

        if (isEnded) {
          durationToShow = Duration.zero;
          timerPrefix = 'Session Ended';
          timerColor = const Color(0xFFEF4444);
          timerIcon = Icons.cancel_outlined;
        } else if (isTimeUp) {
          durationToShow = Duration.zero;
          timerPrefix = '⏰ TIME UP';
          timerColor = const Color(0xFFEF4444);
          timerIcon = Icons.alarm_on;
        } else if (isWaiting) {
          durationToShow = Duration.zero;
          timerPrefix = '⏳ Waiting';
          timerColor = const Color(0xFF818CF8);
          timerIcon = Icons.hourglass_top_rounded;
        } else if (isPackageOpening) {
          durationToShow = Duration(seconds: packageOpeningSecsLeft);
          timerPrefix = '📦 Open: ';
          timerColor = const Color(0xFFF59E0B);
          timerIcon = Icons.inventory_2_outlined;
        } else if (!isOvertime) {
          durationToShow = examWritingTimeLeft;
          final bool isUrgent = durationToShow.inMinutes < 15;
          timerPrefix = '📝 ';
          timerColor = isUrgent ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
          timerIcon = Icons.timer_outlined;
        } else {
          durationToShow = overtimeDuration;
          timerPrefix = '⏱️ Extra: +';
          timerColor = const Color(0xFFF59E0B);
          timerIcon = Icons.alarm_on;
        }

        if (durationToShow.isNegative) durationToShow = Duration.zero;

        final hours = durationToShow.inHours.toString().padLeft(2, '0');
        final minutes = (durationToShow.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (durationToShow.inSeconds % 60).toString().padLeft(2, '0');
        final String timerString = isEnded
            ? 'Ended'
            : isTimeUp
                ? '⏰ Time is Up'
                : isWaiting
                    ? '⏳ Waiting for Examiner'
                    : (durationToShow.inHours > 0
                        ? '$timerPrefix$hours:$minutes:$seconds'
                        : '$timerPrefix$minutes:$seconds');

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
                  isWaiting
                      ? 'පොරොත්තු ශාලාව (Waiting Room)'
                      : '${slot.name} • සජීවී කැමරා විභාගය',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
            actions: [
              if (!isWaiting && _availableCameras.length > 1)
                IconButton(
                  tooltip: 'Switch Camera (Flip)',
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20),
                  onPressed: _switchCamera,
                ),
              // Live Timer Pill
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: timerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: timerColor),
                ),
                child: Row(
                  children: [
                    Icon(timerIcon, size: 14, color: timerColor),
                    const SizedBox(width: 6),
                    Text(
                      timerString,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: isWaiting
              ? _buildWaitingRoomView(session, slot)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Full Screen Camera View (NO PDF)
                    _buildFullScreenCameraView(),

                    // 2. Top Phase Banner (Package Opening, Exam Writing, or Time Up)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: _buildPhaseNoticeBanner(
                        isPackageOpening: isPackageOpening,
                        isWriting: isWriting,
                        isOvertime: isOvertime,
                        isEnded: isEnded,
                        isTimeUp: isTimeUp,
                        packageSecsLeft: packageOpeningSecsLeft,
                      ),
                    ),

                    // 3. Bottom Submission Bar
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: _buildBottomExamControlBar(isEnded, isTimeUp),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildWaitingRoomView(PaperSession session, PaperSlot slot) {
    final startTimeStr = '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Waiting Notice Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.25),
                  const Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFA5B4FC), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'විභාග පොරොත්තු ශාලාව (Waiting Room)',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'නියමිත වේලාව: $startTimeStr (${slot.name})',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'විභාගය නියමිත වේලාවට ස්වයංක්‍රීයව ආරම්භ නොවේ. විභාග පරීක්ෂක විසින් විභාගය ආරම්භ කරන තෙක් කරුණාකර මෙම තිරයේ රැඳී සිටින්න. ඔවුන් සැසිය ආරම්භ කළ වහාම තිරය සජීවී විභාගයට මාරු වේ.',
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFCBD5E1), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Camera Self-Check Box (Preview & Angle Guide)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_outlined, color: Color(0xFF22C55E), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'කැමරා පූර්ව පරීක්ෂාව (Self-Check Preview)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isCameraInitialized
                              ? const Color(0xFF22C55E).withOpacity(0.2)
                              : const Color(0xFFEF4444).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isCameraInitialized ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          ),
                        ),
                        child: Text(
                          _isCameraInitialized ? '🟢 Online' : '🔴 Camera Offline',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isCameraInitialized ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    color: Colors.black,
                    child: _isCameraInitialized && _cameraController != null
                        ? CameraPreview(_cameraController!)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 2),
                                const SizedBox(height: 10),
                                Text(
                                  'කැමරාව සක්‍රීය වෙමින් පවතී...',
                                  style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ඔබගේ මුහුණ සහ විභාග මේසය පැහැදිලිව පෙනෙන සේ දුරකථනය ස්ථාවරව තබන්න.',
                          style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ),
                      if (_availableCameras.length > 1)
                        TextButton.icon(
                          onPressed: _switchCamera,
                          icon: const Icon(Icons.flip_camera_ios, size: 14, color: Color(0xFF818CF8)),
                          label: Text(
                            'Flip',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF818CF8)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Exam Preparations & Instructions Checklist
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.checklist_rounded, color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'විභාග උපදෙස් (Exam Checklist)',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildWaitingChecklistRow(
                  icon: Icons.inventory_2_outlined,
                  title: 'මුද්‍රා තැබූ ප්‍රශ්න පත්‍ර පාර්සලය මේසය මත තබාගන්න',
                  subtitle: 'පරීක්ෂක විසින් විධානය දෙන තුරු කිසිසේත්ම විවෘත නොකරන්න.',
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 10),
                _buildWaitingChecklistRow(
                  icon: Icons.cut,
                  title: 'පාර්සලය විවෘත කිරීමට කතුරක්/බ්ලේඩයක් සූදානම් කරගන්න',
                  subtitle: 'කැමරාව ඉදිරියේ පළමු මිනිත්තු 10 තුළ විවෘත කළ යුතුය.',
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 10),
                _buildWaitingChecklistRow(
                  icon: Icons.lightbulb_outline,
                  title: 'ප්‍රමාණවත් ආලෝකය සහ ස්ථාවර ආධාරකයක් භාවිතා කරන්න',
                  subtitle: 'දුරකථනය නොසෙල්වෙන සේ මේසය මත රඳවා තබන්න.',
                  color: const Color(0xFF22C55E),
                ),
                const SizedBox(height: 10),
                _buildWaitingChecklistRow(
                  icon: Icons.phonelink_lock,
                  title: 'මෙම තිරයෙන් ඉවත් නොවන්න',
                  subtitle: 'තිරය ස්වයංක්‍රීයව ක්‍රියා විරහිත නොවන පරිදි සකසා ඇත (Screen Keep On).',
                  color: const Color(0xFFA5B4FC),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Realtime Connection Pulse Status
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '📡 Examiner Connection: Active • Waiting to Start...',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWaitingChecklistRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullScreenCameraView() {
    if (!_isCameraPermissionGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                'කැමරා අවසරය අවශ්‍යයි',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'විභාග අධීක්ෂණය සඳහා කරුණාකර කැමරා අවසරය ලබා දෙන්න.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initCamera,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                child: const Text('Allow Camera (අවසර දෙන්න)', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: 16),
            Text('කැමරාව ආරම්භ වෙමින් පවතී...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 720,
          height: _cameraController!.value.previewSize?.width ?? 1280,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildPhaseNoticeBanner({
    required bool isPackageOpening,
    required bool isWriting,
    required bool isOvertime,
    required bool isEnded,
    required bool isTimeUp,
    required int packageSecsLeft,
  }) {
    if (isEnded) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'මෙම විභාග සැසිය ගුරුභවතුන් විසින් අවසන් කරන ලදී (Session ended by Admin).',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (isTimeUp) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.5), blurRadius: 12)],
        ),
        child: Row(
          children: [
            const Icon(Icons.alarm_on, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '⏰ වේලාව අවසන් විය! (TIME IS UP)',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'ලිවීම නවතා පිළිතුරු පත්‍ර Scan කර දැන්ම Submit කරන්න.',
                    style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFFEE2E2)),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _openDocumentScanner,
              icon: const Icon(Icons.document_scanner, size: 14, color: Color(0xFFEF4444)),
              label: Text(
                'Scan & Submit',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      );
    }

    if (isPackageOpening) {
      final mins = (packageSecsLeft ~/ 60).toString().padLeft(2, '0');
      final secs = (packageSecsLeft % 60).toString().padLeft(2, '0');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 14)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2, color: Color(0xFFF59E0B), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📦 ප්‍රශ්න පත්‍ර පාර්සලය විවෘත කිරීම (10 Mins)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                      ),
                      Text(
                        'කැමරාව ඉදිරියේ පමණක් පාර්සලය විවෘත කරන්න',
                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFE2E8F0)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$mins:$secs',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. 🏷️ මුද්‍රා තැබූ පාර්සලය කැමරාවට පෙන්වන්න (Show sealed parcel)', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('2. ✂️ කැමරාව ඉදිරියේම කපා විවෘත කරන්න (Cut open on camera)', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('3. 📄 පත්‍රය මේසය මත තබා ලිවීමට සූදානම් වන්න (Place on desk)', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF4ADE80))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isOvertime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.alarm_on, color: Color(0xFFEF4444), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'නියමිත වේලාව අවසන්! කරුණාකර පිළිතුරු පත්‍ර Scan කර Submit කරන්න.',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFFCA5A5)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '✍️ පිළිතුරු ලිවීම සක්‍රීයයි - ලිවීම් මේසය සහ ඔබ කැමරාව ඉදිරියේ තබාගන්න.',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomExamControlBar(bool isEnded, bool isTimeUp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTimeUp ? const Color(0xFFEF4444) : const Color(0xFF334155),
          width: isTimeUp ? 1.5 : 1,
        ),
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
              color: isTimeUp
                  ? const Color(0xFFEF4444).withOpacity(0.2)
                  : const Color(0xFF22C55E).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTimeUp ? Icons.alarm_on : Icons.shield_outlined,
              color: isTimeUp ? const Color(0xFFEF4444) : const Color(0xFF4ADE80),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isTimeUp ? 'වේලාව අවසන් කර ඇත' : 'කැමරා අධීක්ෂණය සක්‍රීයයි',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isTimeUp ? const Color(0xFFFCA5A5) : Colors.white,
                  ),
                ),
                Text(
                  isTimeUp ? 'පිළිතුරු පත්‍ර Submit කරන්න' : 'ගුරුභවතුන් සජීවීව පරීක්ෂා කරයි',
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
              backgroundColor: isEnded
                  ? const Color(0xFF334155)
                  : isTimeUp
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () {
              _openDocumentScanner();
            },
            icon: Icon(
              isTimeUp ? Icons.document_scanner : Icons.upload_file,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              isTimeUp ? 'Scan & Submit' : 'Submit Paper',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSessionEndedByAdmin() {
    ScreenKeepOnService.setKeepScreenOn(false);
    _heartbeatTimer?.cancel();
    _examCountdownTimer?.cancel();
    _alertSubscription?.cancel();
    _sendHeartbeat(false);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'සැසිය අවසන් විය',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          'මෙම විභාග සැසිය ගුරුභවතුන් විසින් නිල වශයෙන් අවසන් කරන ලදී (Session ended by Admin). ඔබව විභාග ශාලාවෙන් ඉවත් කෙරේ.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFCBD5E1), height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.pop();
            },
            child: Text('හරි (Exit Room)', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTimeUpDialog() {
    if (!mounted) return;
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
                color: const Color(0xFFEF4444).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm_on, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '⏰ වේලාව අවසන් විය!',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time is Up! කරුණාකර ලිවීම නවත්වන්න.',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFFCA5A5)),
            ),
            const SizedBox(height: 8),
            Text(
              'ගුරුභවතුන් විසින් විභාගයේ වේලාව අවසන් කර ඇත. කරුණාකර ලිවීම නවත්වා ඔබගේ පිළිතුරු පත්‍ර In-App Document Scanner එක හරහා පැහැදිලිව Scan කර දැන්ම Submit කරන්න.',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFCBD5E1), height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _openDocumentScanner();
              },
              icon: const Icon(Icons.document_scanner, color: Colors.white, size: 18),
              label: Text(
                '📄 Scan Answers with Camera (ස්කෑන් කරන්න)',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocumentScanner() async {
    // 1. Temporarily pause proctor heartbeat & release front proctor camera
    // to prevent Android camera device contention when opening rear scanner
    _heartbeatTimer?.cancel();
    await _cameraController?.dispose();
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }

    // 2. Open In-App Rear Document Scanner Screen
    if (!mounted) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => InAppDocumentScannerScreen(
          paperId: widget.paperId,
          slotId: widget.slotId,
        ),
      ),
    );

    // 3. If submitted, exit exam room cleanly
    if (submitted == true && mounted) {
      context.pop();
      return;
    }

    // 4. If cancelled or backed out without submitting, re-initialize proctor camera and timers
    if (mounted) {
      _initCamera();
      _startTimers();
    }
  }

  void _showSubmissionDialog() {
    final ImagePicker picker = ImagePicker();
    final List<File> localPhotoFiles = [];
    final pdfLinkCtrl = TextEditingController();
    bool isUploading = false;
    String uploadStatus = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickPhotos(ImageSource source) async {
            try {
              if (source == ImageSource.camera) {
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1600,
                  maxHeight: 2000,
                  imageQuality: 85,
                );
                if (photo != null) {
                  setSheetState(() {
                    localPhotoFiles.add(File(photo.path));
                  });
                }
              } else {
                final List<XFile> photos = await picker.pickMultiImage(
                  maxWidth: 1600,
                  maxHeight: 2000,
                  imageQuality: 85,
                );
                if (photos.isNotEmpty) {
                  setSheetState(() {
                    for (final photo in photos) {
                      localPhotoFiles.add(File(photo.path));
                    }
                  });
                }
              }
            } catch (e) {
              debugPrint('Error picking answer sheet photos: $e');
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF4ADE80), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit Answer Sheets',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'පිළිතුරු පත්‍රවල ඡායාරූප (Photos) Upload කරන්න',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Photo Capture / Add Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isUploading ? null : () => pickPhotos(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          label: Text(
                            'Take Photo (Camera)',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isUploading ? null : () => pickPhotos(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF38BDF8)),
                          label: Text(
                            'From Gallery',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Photos Preview Grid
                  if (localPhotoFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '📸 Uploaded Pages (${localPhotoFiles.length} Pages):',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: localPhotoFiles.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 90,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF475569)),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    localPhotoFiles[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Page ${index + 1}',
                                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: isUploading
                                        ? null
                                        : () {
                                            setSheetState(() {
                                              localPhotoFiles.removeAt(index);
                                            });
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text(
                    'Optional: PDF / Drive Link (විකල්ප PDF ලින්ක් එක):',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: pdfLinkCtrl,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://drive.google.com/.../answers.pdf',
                      hintStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),

                  if (uploadStatus.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              uploadStatus,
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Finalize Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isUploading
                          ? null
                          : () async {
                              final user = context.read<AuthProvider>().userModel;
                              if (user == null) return;

                              final driveLink = pdfLinkCtrl.text.trim();
                              if (localPhotoFiles.isEmpty && driveLink.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('කරුණාකර අවම වශයෙන් එක් පිළිතුරු පිටුවක් හෝ Drive ලින්ක් එකක් ඇතුළත් කරන්න.'),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() {
                                isUploading = true;
                                uploadStatus = 'Starting upload...';
                              });

                              try {
                                final storage = FirebaseStorage.instance;
                                final List<String> uploadedUrls = [];

                                for (int i = 0; i < localPhotoFiles.length; i++) {
                                  setSheetState(() {
                                    uploadStatus = 'Uploading page ${i + 1} of ${localPhotoFiles.length}...';
                                  });
                                  final file = localPhotoFiles[i];
                                  final filename = 'p${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                  final ref = storage.ref().child('paper_submissions/${widget.paperId}/${user.id}/$filename');
                                  final uploadTask = await ref.putFile(
                                    file,
                                    SettableMetadata(contentType: 'image/jpeg'),
                                  );
                                  final downloadUrl = await uploadTask.ref.getDownloadURL();
                                  uploadedUrls.add(downloadUrl);
                                }

                                if (driveLink.isNotEmpty) {
                                  uploadedUrls.add(driveLink);
                                }

                                setSheetState(() {
                                  uploadStatus = 'Saving submission records...';
                                });

                                await _paperService.updateCameraHeartbeat(
                                  paperId: widget.paperId,
                                  studentId: user.id,
                                  isCameraActive: false,
                                  status: 'submitted',
                                  submissionPhotos: uploadedUrls,
                                );

                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ පිළිතුරු පත්‍ර (${uploadedUrls.length} Items) සාර්ථකව භාරදෙන ලදී!'),
                                      backgroundColor: const Color(0xFF22C55E),
                                    ),
                                  );
                                  context.pop();
                                }
                              } catch (e) {
                                setSheetState(() {
                                  isUploading = false;
                                  uploadStatus = '';
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Submission Error: $e'),
                                      backgroundColor: const Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: Text(
                        isUploading ? 'Uploading Answer Sheets...' : 'Submit & Finish Exam (විභාගය අවසන් කරන්න)',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
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
