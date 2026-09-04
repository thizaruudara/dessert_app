import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

  // Camera flip and availability
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;

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
    _cameraController = CameraController(
      camera,
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
        final slot = (widget.slotId == 'slot2' && session.slot2 != null) ? session.slot2! : session.slot1;

        final bool isEnded = session.isEnded;
        final bool isUpcoming = !isEnded && _now.isBefore(slot.startTime);
        final bool isLive = !isEnded && !isUpcoming;

        // 10-Minute Package Opening Phase (First 10 minutes of live session)
        final Duration elapsedSinceStart = isLive ? _now.difference(slot.startTime) : Duration.zero;
        final bool isPackageOpeningPhase = isLive && elapsedSinceStart.inSeconds >= 0 && elapsedSinceStart.inSeconds < 600;
        final int packageOpeningSecsLeft = isPackageOpeningPhase ? (600 - elapsedSinceStart.inSeconds) : 0;

        // Real Exam Writing Phase (starts 10 mins after slot.startTime)
        final DateTime realExamStart = slot.startTime.add(const Duration(minutes: 10));
        final DateTime realExamEnd = realExamStart.add(Duration(minutes: session.durationMinutes));
        final bool isRealExamPhase = isLive && !isPackageOpeningPhase;
        final bool isOvertime = isRealExamPhase && _now.isAfter(realExamEnd);
        final Duration examWritingTimeLeft = isRealExamPhase && !isOvertime ? realExamEnd.difference(_now) : Duration.zero;
        final Duration overtimeDuration = isOvertime ? _now.difference(realExamEnd) : Duration.zero;

        Duration durationToShow;
        String timerPrefix;
        Color timerColor;
        IconData timerIcon;

        if (isEnded) {
          durationToShow = Duration.zero;
          timerPrefix = 'Session Ended';
          timerColor = const Color(0xFFEF4444);
          timerIcon = Icons.cancel_outlined;
        } else if (isUpcoming) {
          durationToShow = slot.startTime.difference(_now);
          timerPrefix = 'Starts in: ';
          timerColor = const Color(0xFFF59E0B);
          timerIcon = Icons.hourglass_top_rounded;
        } else if (isPackageOpeningPhase) {
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
                  '${slot.name} • සජීවී කැමරා විභාගය',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
            actions: [
              if (_availableCameras.length > 1)
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full Screen Camera View (NO PDF)
              _buildFullScreenCameraView(),

              // 2. Top Phase Banner (Package Opening or Exam Writing)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _buildPhaseNoticeBanner(
                  isPackageOpening: isPackageOpeningPhase,
                  isUpcoming: isUpcoming,
                  isOvertime: isOvertime,
                  isEnded: isEnded,
                  packageSecsLeft: packageOpeningSecsLeft,
                ),
              ),

              // 3. Bottom Submission Bar
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: _buildBottomExamControlBar(isEnded),
              ),
            ],
          ),
        );
      },
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
    required bool isUpcoming,
    required bool isOvertime,
    required bool isEnded,
    required int packageSecsLeft,
  }) {
    if (isEnded) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'මෙම විභාග සැසිය ගුරුභවතුන් විසින් අවසන් කර ඇත (Session ended by Admin).',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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
          color: const Color(0xFF0F172A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 14)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2, color: Color(0xFFF59E0B), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '📦 ප්‍රශ්න පත්‍ර පාර්සලය විවෘත කිරීම',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$mins:$secs',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'නිවසට ලැබුණු මුද්‍රා තැබූ පාර්සලය කැමරාව ඉදිරියේ පමණක් විවෘත කරන්න.',
                    style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFE2E8F0)),
                  ),
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
                'නියමිත වේලාව අවසන්! කරුණාකර පිළිතුරු පත්‍ර ඡායාරූප ගෙන Submit කරන්න.',
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

  Widget _buildBottomExamControlBar(bool isEnded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.92),
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
              backgroundColor: isEnded ? const Color(0xFF334155) : const Color(0xFF6366F1),
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
    );
  }

  void _showSubmissionDialog() {
    final ImagePicker picker = ImagePicker();
    final List<String> capturedPhotosBase64 = [];
    final List<File> localPhotoFiles = [];
    final pdfLinkCtrl = TextEditingController();
    bool isUploading = false;

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
                  maxWidth: 1200,
                  maxHeight: 1600,
                  imageQuality: 80,
                );
                if (photo != null) {
                  final bytes = await File(photo.path).readAsBytes();
                  final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                  setSheetState(() {
                    localPhotoFiles.add(File(photo.path));
                    capturedPhotosBase64.add(base64);
                  });
                }
              } else {
                final List<XFile> photos = await picker.pickMultiImage(
                  maxWidth: 1200,
                  maxHeight: 1600,
                  imageQuality: 80,
                );
                if (photos.isNotEmpty) {
                  for (final photo in photos) {
                    final bytes = await File(photo.path).readAsBytes();
                    final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                    localPhotoFiles.add(File(photo.path));
                    capturedPhotosBase64.add(base64);
                  }
                  setSheetState(() {});
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
                                              capturedPhotosBase64.removeAt(index);
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

                              setSheetState(() => isUploading = true);

                              final List<String> allSubmissions = List.from(capturedPhotosBase64);
                              final driveLink = pdfLinkCtrl.text.trim();
                              if (driveLink.isNotEmpty) {
                                allSubmissions.add(driveLink);
                              }

                              try {
                                await _paperService.updateCameraHeartbeat(
                                  paperId: widget.paperId,
                                  studentId: user.id,
                                  isCameraActive: false,
                                  status: 'submitted',
                                  submissionPhotos: allSubmissions,
                                );

                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ පිළිතුරු පත්‍ර (${allSubmissions.length} Items) සාර්ථකව භාරදෙන ලදී!'),
                                      backgroundColor: const Color(0xFF22C55E),
                                    ),
                                  );
                                  context.pop();
                                }
                              } catch (e) {
                                setSheetState(() => isUploading = false);
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
                        isUploading ? 'Submitting Answer Sheets...' : 'Submit & Finish Exam (විභාගය අවසන් කරන්න)',
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
