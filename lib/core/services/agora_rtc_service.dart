import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_generator/agora_token_generator.dart';

class AgoraRtcService {
  // Agora App ID & Primary Certificate configured for Dessert App
  static const String appId = '1a021dff70b447058f17a8881a03834e';
  static const String appCertificate = '80640aa2f43642b58c993929935a68d9';

  /// Generates a deterministic, positive 32-bit integer UID for Agora from a string ID or phone number
  static int getNumericUid(String id) {
    if (id.isEmpty) return 1001;

    // If ID contains phone digits, use the last 8 digits
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 6) {
      final sub = digits.length > 8 ? digits.substring(digits.length - 8) : digits;
      final parsed = int.tryParse(sub);
      if (parsed != null && parsed > 0 && parsed <= 2147483647) {
        return parsed;
      }
    }

    // Otherwise standard positive 31-bit string hash
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = (31 * hash + id.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash <= 0 ? 1001 : hash;
  }

  /// Format standardized exam channel name from paper ID
  static String getChannelName(String paperId) {
    // Agora channel names: alphanumeric and underscores only
    final sanitized = paperId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'exam_$sanitized';
  }

  /// Generates a valid HMAC-SHA256 signed Agora RTC token for joining channel
  static String generateRtcToken({
    required String channelName,
    required int uid,
    int expireSeconds = 86400, // Valid for 24 hours
  }) {
    try {
      return RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCertificate,
        channelName: channelName,
        uid: uid,
        tokenExpireSeconds: expireSeconds,
      );
    } catch (e) {
      debugPrint('Error generating Agora token: $e');
      return '';
    }
  }

  /// Create and initialize an Agora RTC Engine instance
  static Future<RtcEngine> createAndInitEngine({
    required RtcEngineEventHandler eventHandler,
  }) async {
    final engine = createAgoraRtcEngine();
    await engine.initialize(
      const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    engine.registerEventHandler(eventHandler);

    // Enable video module
    await engine.enableVideo();

    // Optimize video encoding for student desks and handwriting:
    // 360 x 640 @ 15fps, 350kbps: crystal clear for exam papers,
    // ultra-low mobile data usage (~2.5 MB/min), zero lag over mobile Wi-Fi!
    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 360, height: 640),
        frameRate: 15,
        bitrate: 350,
        orientationMode: OrientationMode.orientationModeAdaptative,
      ),
    );

    // Set audio profile for exams (mute student mics by default to prevent ambient classroom noise)
    await engine.setAudioProfile(
      profile: AudioProfileType.audioProfileSpeechStandard,
      scenario: AudioScenarioType.audioScenarioDefault,
    );

    return engine;
  }

  /// Student Joins as Broadcaster (streams video of desk/paper)
  static Future<void> joinAsBroadcaster({
    required RtcEngine engine,
    required String channelId,
    required int uid,
  }) async {
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.startPreview();

    // Generate secure token using Primary Certificate
    final token = generateRtcToken(channelName: channelId, uid: uid);

    await engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: false, // keep mic muted for quiet exams
        autoSubscribeAudio: false,
        autoSubscribeVideo: false,
      ),
    );
    debugPrint('Agora: Broadcaster joined channel $channelId with UID $uid');
  }

  /// Admin Joins as Monitor / Audience (receives all student video streams)
  static Future<void> joinAsAudience({
    required RtcEngine engine,
    required String channelId,
    int uid = 1,
  }) async {
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);

    // Generate secure token for Admin monitor
    final token = generateRtcToken(channelName: channelId, uid: uid);

    await engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleAudience,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        autoSubscribeAudio: false,
        autoSubscribeVideo: true, // receive all student streams
      ),
    );
    debugPrint('Agora: Admin joined channel $channelId with UID $uid');
  }

  /// Leave channel and clean up engine
  static Future<void> leaveAndRelease(RtcEngine? engine) async {
    if (engine == null) return;
    try {
      await engine.leaveChannel();
    } catch (e) {
      debugPrint('Agora leave error: $e');
    }
    try {
      await engine.release();
    } catch (e) {
      debugPrint('Agora release error: $e');
    }
  }
}
