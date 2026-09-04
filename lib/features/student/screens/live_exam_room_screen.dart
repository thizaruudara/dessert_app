import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/models/paper_session_model.dart';
import '../../../core/services/agora_rtc_service.dart';
import '../../../core/services/notification_service.dart';
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
  RtcEngine? _agoraEngine;
  VideoViewController? _localVideoViewController;
  int _studentNumericUid = 0;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  String? _cameraErrorMessage;
  Timer? _heartbeatTimer;
  Timer? _examCountdownTimer;
  DateTime _now = DateTime.now();
  bool _isCurrentlyWaiting = true;
  String _currentStudentId = '';
  DateTime? _localPackageOpeningStartTime;
  DateTime? _lastObservedPackageOpeningStartedAt;
  DateTime? _localWritingStartTime;
  DateTime? _lastObservedWritingStartedAt;

  StreamSubscription<List<ProctorAlert>>? _alertSubscription;
  final Set<String> _shownAlertIds = {};

  bool _isSendingHeartbeat = false;
  bool _hasExitedDueToEnd = false;
  bool _hasPromptedTimeUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenKeepOnService.setKeepScreenOn(true);
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _currentStudentId = user.id;
    }
    _ensureStudentRegistered();
    _initCamera();
    _startTimers();
    _listenForProctorAlerts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfAlreadySubmitted();
    });
  }

  Future<void> _checkIfAlreadySubmitted() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    try {
      final reg = await _paperService.getStudentRegistration(widget.paperId, user.id);
      if (reg != null && (reg.isSubmitted || reg.status == 'submitted')) {
        if (!mounted) return;
        _heartbeatTimer?.cancel();
        _examCountdownTimer?.cancel();
        _alertSubscription?.cancel();
        _localVideoViewController?.dispose();
        _localVideoViewController = null;
        AgoraRtcService.leaveAndRelease(_agoraEngine);
        _agoraEngine = null;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Paper Already Submitted',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Text(
              'ඔබ මෙම විභාගයේ පිළිතුරු පත්‍ර දැනටමත් සාර්ථකව භාරදී ඇත. නැවත විභාග ශාලාවට පිවිසීමට අවශ්‍ය නොවේ.',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFCBD5E1)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (mounted) context.go('/student/papers');
                },
                child: Text('හරි (OK)', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Check submitted on enter error: $e');
    }
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
    final studentId = _currentStudentId.isNotEmpty
        ? _currentStudentId
        : (mounted ? context.read<AuthProvider>().userModel?.id ?? '' : '');
    if (studentId.isEmpty) return;
    try {
      await _paperService.updateCameraHeartbeat(
        paperId: widget.paperId,
        studentId: studentId,
        isCameraActive: false,
        agoraUid: _studentNumericUid,
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

    // Dispose local controller and Agora engine
    _localVideoViewController?.dispose();
    _localVideoViewController = null;
    AgoraRtcService.leaveAndRelease(_agoraEngine);
    _agoraEngine = null;

    ScreenKeepOnService.setKeepScreenOn(false);

    // Immediately mark offline in Firestore when leaving exam room
    _setOfflineStatus();

    super.dispose();
  }

  Future<void> _ensureStudentRegistered() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    try {
      final reg = await _paperService.getStudentRegistration(widget.paperId, user.id);
      if (reg != null && (reg.isSubmitted || reg.status == 'submitted')) {
        return; // Already submitted, do not re-register or overwrite!
      }
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
    await Permission.microphone.request();

    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _isCameraPermissionGranted = true;
          _cameraErrorMessage = null;
        });
      }

      try {
        final user = context.read<AuthProvider>().userModel;
        final idToHash = (user != null && user.phone.isNotEmpty) ? user.phone : (user?.id ?? widget.slotId);
        _studentNumericUid = AgoraRtcService.getNumericUid(idToHash);

        _agoraEngine = await AgoraRtcService.createAndInitEngine(
          eventHandler: RtcEngineEventHandler(
            onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
              debugPrint('Agora Student joined: ${connection.channelId} (uid: $_studentNumericUid)');
              if (mounted) {
                _sendHeartbeat(true);
              }
            },
            onError: (ErrorCodeType err, String msg) {
              debugPrint('Agora Student error: $err - $msg');
            },
          ),
        );

        await _agoraEngine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        await _agoraEngine!.startPreview();

        _localVideoViewController?.dispose();
        _localVideoViewController = VideoViewController(
          rtcEngine: _agoraEngine!,
          canvas: const VideoCanvas(uid: 0),
        );

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _cameraErrorMessage = null;
          });
        }

        final channelName = AgoraRtcService.getChannelName(widget.paperId);
        unawaited(
          AgoraRtcService.joinAsBroadcaster(
            engine: _agoraEngine!,
            channelId: channelName,
            uid: _studentNumericUid,
          ),
        );
      } catch (e) {
        debugPrint('Agora Camera init error: $e');
        if (mounted) {
          setState(() {
            _cameraErrorMessage = e.toString();
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isCameraPermissionGranted = false;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _agoraEngine?.switchCamera();
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
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

    // Send proctor heartbeat every 4 seconds (Super-smooth proctoring without heavy images)
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

      final reg = await _paperService.getStudentRegistration(widget.paperId, user.id);
      if (reg != null && (reg.isSubmitted || reg.status == 'submitted')) {
        // Stop heartbeat if submitted so presence drops cleanly
        _heartbeatTimer?.cancel();
        return;
      }

      await _paperService.updateCameraHeartbeat(
        paperId: widget.paperId,
        studentId: user.id,
        studentName: user.name,
        studentPhone: user.phone,
        slotId: widget.slotId.isNotEmpty ? widget.slotId : 'slot1',
        isCameraActive: isActive,
        agoraUid: _studentNumericUid,
        status: 'in_exam',
      );
    } catch (e) {
      debugPrint('Heartbeat error: $e');
    } finally {
      _isSendingHeartbeat = false;
    }
  }

  void _listenForProctorAlerts() {
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _alertSubscription?.cancel();
      _alertSubscription = _paperService
          .streamStudentAlerts(
            paperId: widget.paperId,
            studentId: user.id,
            studentPhone: user.phone,
          )
          .listen((alerts) {
        for (final alert in alerts) {
          if (!alert.isRead && !_shownAlertIds.contains(alert.id)) {
            _shownAlertIds.add(alert.id);
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
    // 1. Heavy haptic feedback to physically notify student
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 250), () => HapticFeedback.heavyImpact());
    } catch (_) {}

    // 2. Also trigger native lock screen & heads-up notification in case screen is locked or minimized
    NotificationService.showNotification(
      title: '⚠️ Proctor Alert: ${alert.title}',
      body: alert.message,
    );

    // 3. Show prominent floating in-app banner
    _showBroadcastAlertNotification(alert);

    // 4. Show modal Alert Dialog
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

        // Package Opening Countdown (10 Minutes):
        // Completely immune to device clock discrepancies. Counts down locally from 10:00.
        // If the examiner triggers or restarts the 10m timer (packageOpeningStartedAt changes),
        // we automatically reset the local reference time to restart the 10m countdown.
        int packageOpeningSecsLeft = 600;
        if (isPackageOpening) {
          if (_localPackageOpeningStartTime == null ||
              (session.packageOpeningStartedAt != null &&
                  session.packageOpeningStartedAt != _lastObservedPackageOpeningStartedAt)) {
            _lastObservedPackageOpeningStartedAt = session.packageOpeningStartedAt;
            _localPackageOpeningStartTime = DateTime.now();
          }
          final elapsed = _now.difference(_localPackageOpeningStartTime!).inSeconds;
          packageOpeningSecsLeft = (600 - elapsed).clamp(0, 600);
        } else {
          _localPackageOpeningStartTime = null;
          _lastObservedPackageOpeningStartedAt = null;
        }

        // Real Exam Writing Phase:
        // Counts down the full durationMinutes set by examiner.
        // Immune to past timestamps or clock skew between examiner and student.
        if (isWriting) {
          if (_localWritingStartTime == null ||
              (session.writingStartedAt != null &&
                  session.writingStartedAt != _lastObservedWritingStartedAt)) {
            _lastObservedWritingStartedAt = session.writingStartedAt;
            _localWritingStartTime = DateTime.now();
          }
        } else {
          _localWritingStartTime = null;
          _lastObservedWritingStartedAt = null;
        }

        final int totalWritingSeconds = session.durationMinutes * 60;
        final int writingElapsed = _localWritingStartTime != null
            ? _now.difference(_localWritingStartTime!).inSeconds
            : 0;
        final bool isOvertime = isWriting && writingElapsed > totalWritingSeconds;
        final Duration examWritingTimeLeft = isWriting && !isOvertime
            ? Duration(seconds: (totalWritingSeconds - writingElapsed).clamp(0, totalWritingSeconds))
            : Duration.zero;
        final Duration overtimeDuration = isOvertime
            ? Duration(seconds: writingElapsed - totalWritingSeconds)
            : Duration.zero;

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
                ? '⏰ Time Up'
                : isWaiting
                    ? '⏳ Waiting'
                    : isPackageOpening
                        ? (packageOpeningSecsLeft <= 0 ? '📦 00:00' : '$timerPrefix$minutes:$seconds')
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
                if (isEnded) {
                  context.go('/student/papers');
                } else {
                  _showExitWarningDialog();
                }
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.title,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isWaiting
                      ? 'පොරොත්තු ශාලාව (Waiting)'
                      : isPackageOpening
                          ? 'පාර්සල් විවෘත කිරීම'
                          : '${slot.name} • සජීවී විභාගය',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              if (!isWaiting && _isCameraInitialized && _agoraEngine != null)
                IconButton(
                  tooltip: 'Switch Camera (Flip)',
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 18),
                  onPressed: _switchCamera,
                ),
              // Live Timer Pill (Compact, fits all screens)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: timerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: timerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(timerIcon, size: 13, color: timerColor),
                    const SizedBox(width: 4),
                    Text(
                      timerString,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_outlined, color: Color(0xFF22C55E), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'කැමරා පූර්ව පරීක්ෂාව (Self-Check)',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                          _isCameraInitialized ? '🟢 Online' : '🔴 Offline',
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
                    child: _isCameraInitialized && _localVideoViewController != null
                        ? AgoraVideoView(
                            controller: _localVideoViewController!,
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 2),
                                const SizedBox(height: 10),
                                Text(
                                  _cameraErrorMessage != null
                                      ? 'කැමරා දෝෂයක්: $_cameraErrorMessage'
                                      : 'කැමරාව සක්‍රීය වෙමින් පවතී...',
                                  style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                                if (_cameraErrorMessage != null) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _initCamera,
                                    icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF818CF8)),
                                    label: const Text('නැවත උත්සාහ කරන්න (Retry)', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11)),
                                  ),
                                ],
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
                      if (_isCameraInitialized && _agoraEngine != null)
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

    if (!_isCameraInitialized || _localVideoViewController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6366F1)),
            const SizedBox(height: 16),
            Text(
              _cameraErrorMessage != null
                  ? 'කැමරා දෝෂයක්: $_cameraErrorMessage'
                  : 'කැමරාව ආරම්භ වෙමින් පවතී...',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (_cameraErrorMessage != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _initCamera,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text('නැවත උත්සාහ කරන්න (Retry)', style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: AgoraVideoView(
        controller: _localVideoViewController!,
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
      final isFrozenAtZero = packageSecsLeft <= 0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFrozenAtZero ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            width: 2,
          ),
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
                    color: (isFrozenAtZero ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFrozenAtZero ? Icons.timer_off_rounded : Icons.inventory_2,
                    color: isFrozenAtZero ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFrozenAtZero
                            ? '⏱️ විනාඩි 10 අවසන් (Time Stopped)'
                            : '📦 ප්‍රශ්න පත්‍ර පාර්සලය විවෘත කිරීම (10 Mins)',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isFrozenAtZero ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                        ),
                      ),
                      Text(
                        isFrozenAtZero
                            ? 'පරීක්ෂකවරයා විභාගය ආරම්භ කරන තෙක් රැඳී සිටින්න (Frozen at 00:00)'
                            : 'කැමරාව ඉදිරියේ පමණක් පාර්සලය විවෘත කරන්න',
                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFE2E8F0)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFrozenAtZero ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$mins:$secs',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isFrozenAtZero ? Colors.white : Colors.black,
                    ),
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
                  Text(
                    isFrozenAtZero
                        ? '3. ⏳ විභාගය ආරම්භ කරන තෙක් පත්‍රය මේසය මත තබා සූදානම්ව සිටින්න'
                        : '3. 📄 පත්‍රය මේසය මත තබා ලිවීමට සූදානම් වන්න (Place on desk)',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isFrozenAtZero ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80),
                      fontWeight: isFrozenAtZero ? FontWeight.bold : FontWeight.normal,
                    ),
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
              if (mounted) {
                context.go('/student/papers');
              }
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
    _localVideoViewController?.dispose();
    _localVideoViewController = null;
    await AgoraRtcService.leaveAndRelease(_agoraEngine);
    _agoraEngine = null;
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
      context.go('/student/papers');
      return;
    }

    // 4. If cancelled or backed out without submitting, re-initialize proctor camera and timers
    if (mounted) {
      _initCamera();
      _startTimers();
    }
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
              if (mounted) {
                context.go('/student/papers');
              }
            },
            child: Text('පිටවෙන්න (Exit)', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
