// EduPeak Web Agora RTC Service
// Provides real-time 720p HD WebRTC video broadcasting for students
// and multi-stream live surveillance monitoring for proctors, matching Flutter 1:1.

import AgoraRTC from 'agora-rtc-sdk-ng';

// Agora App ID is never hardcoded - fetched securely from /api/agora/token (env-only + authenticated)
let CACHED_AGORA_APP_ID = '';
export function getAgoraAppId() { return CACHED_AGORA_APP_ID; }

// Generates a deterministic positive 32-bit integer UID matching Flutter AgoraRtcService.getNumericUid
export function getNumericUid(id) {
  if (!id) return 1001;
  const digits = String(id).replace(/[^0-9]/g, '');
  if (digits.length >= 6) {
    const sub = digits.length > 8 ? digits.slice(-8) : digits;
    const parsed = parseInt(sub, 10);
    if (parsed > 0 && parsed <= 2147483647) return parsed;
  }
  let hash = 0;
  const str = String(id);
  for (let i = 0; i < str.length; i++) {
    hash = (31 * hash + str.charCodeAt(i)) & 0x7FFFFFFF;
  }
  return hash <= 0 ? 1001 : hash;
}

// Format channel name matching Flutter AgoraRtcService.getChannelName
export function getChannelName(paperId) {
  const sanitized = String(paperId || '').replace(/[^a-zA-Z0-9_]/g, '_');
  return `exam_${sanitized}`;
}

// Fetch token from server endpoint (authenticated; requires Firebase ID token)
export async function fetchAgoraToken(channelName, uid, role = 'publisher') {
  try {
    const apiBase = (typeof window !== 'undefined' && !window.location.hostname.includes('vercel.app'))
      ? 'https://edupeak-web.vercel.app/api'
      : '/api';
    // Attach Firebase ID token if available for authenticated token minting
    let authHeader = {};
    try {
      const { auth } = await import('./firebase-config.js');
      const token = await auth.currentUser?.getIdToken?.();
      if (token) authHeader = { 'Authorization': `Bearer ${token}` };
    } catch (_) {}
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 1200);
    const res = await fetch(`${apiBase}/agora/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeader },
      body: JSON.stringify({ channelName, uid, role }),
      signal: controller.signal
    });
    clearTimeout(timer);
    if (res.ok) {
      const data = await res.json();
      if (data?.result?.token) {
        if (data.result.appId) CACHED_AGORA_APP_ID = String(data.result.appId).trim();
        return { token: data.result.token, appId: data.result.appId || CACHED_AGORA_APP_ID };
      }
    }
    if (res.status === 503) throw new Error('Agora service not configured');
  } catch (err) {
    console.warn('[Agora] Token fetch failed:', err.message);
    throw err;
  }
  throw new Error('Agora token fetch failed');
}

// ── Student Broadcaster ──────────────────────────────────────────────
export class AgoraStudentBroadcaster {
  constructor() {
    this.client = null;
    this.localVideoTrack = null;
    this.isBroadcasting = false;
    this.uid = 0;
  }

  async start({ paperId, studentId, mediaStream = null }) {
    if (this.isBroadcasting) return this.uid;
    const channelName = getChannelName(paperId);
    this.uid = getNumericUid(studentId);

    try {
      this.client = AgoraRTC.createClient({ mode: 'live', codec: 'vp8' });
      await this.client.setClientRole('host');

      const tokenData = await fetchAgoraToken(channelName, this.uid, 'publisher');
      await this.client.join(tokenData.appId, channelName, tokenData.token, this.uid);

      // Create video track from existing mediaStream if available, or create camera track
      if (mediaStream && mediaStream.getVideoTracks().length > 0) {
        this.localVideoTrack = AgoraRTC.createCustomVideoTrack({
          mediaStreamTrack: mediaStream.getVideoTracks()[0]
        });
      } else {
        this.localVideoTrack = await AgoraRTC.createCameraVideoTrack({
          encoderConfig: {
            width: 1280,
            height: 720,
            frameRate: 20,
            bitrateMin: 400,
            bitrateMax: 1000
          },
          facingMode: 'user'
        });
      }

      await this.client.publish([this.localVideoTrack]);
      this.isBroadcasting = true;
      console.log(`[Agora] Student broadcaster active: Channel ${channelName}, UID ${this.uid}`);
      return this.uid;
    } catch (err) {
      console.error('[Agora] Student broadcaster failed to start:', err);
      this.stop();
      return null;
    }
  }

  async stop() {
    this.isBroadcasting = false;
    try {
      if (this.localVideoTrack) {
        this.localVideoTrack.stop();
        this.localVideoTrack.close();
        this.localVideoTrack = null;
      }
      if (this.client) {
        await this.client.leave();
        this.client = null;
      }
    } catch (e) {
      console.warn('[Agora] Stop error:', e);
    }
  }
}

// ── Admin Proctor Audience (Multi-Stream Viewer) ─────────────────────
export class AgoraAdminAudience {
  constructor() {
    this.client = null;
    this.channelName = '';
    this.remoteUsers = new Map(); // uid -> remote user
    this.onStreamChange = null; // callback(uid, user, isPublished)
    this.isConnected = false;
  }

  async start(paperId, onStreamChange = null) {
    if (this.isConnected && this.channelName === getChannelName(paperId)) return;
    await this.stop();

    this.channelName = getChannelName(paperId);
    this.onStreamChange = onStreamChange;
    const adminUid = 900000 + Math.floor(Math.random() * 90000);

    try {
      this.client = AgoraRTC.createClient({ mode: 'live', codec: 'vp8' });
      await this.client.setClientRole('audience');

      this.client.on('user-published', async (user, mediaType) => {
        try {
          await this.client.subscribe(user, mediaType);
          if (mediaType === 'video') {
            this.remoteUsers.set(Number(user.uid), user);
            console.log(`[Agora Admin] Student published video: UID ${user.uid}`);
            if (this.onStreamChange) this.onStreamChange(Number(user.uid), user, true);
          }
        } catch (subErr) {
          console.warn(`[Agora Admin] Subscribe error for UID ${user.uid}:`, subErr);
        }
      });

      this.client.on('user-unpublished', (user, mediaType) => {
        if (mediaType === 'video') {
          this.remoteUsers.delete(Number(user.uid));
          console.log(`[Agora Admin] Student unpublished video: UID ${user.uid}`);
          if (this.onStreamChange) this.onStreamChange(Number(user.uid), user, false);
        }
      });

      this.client.on('user-left', (user) => {
        this.remoteUsers.delete(Number(user.uid));
        if (this.onStreamChange) this.onStreamChange(Number(user.uid), user, false);
      });

      const tokenData2 = await fetchAgoraToken(this.channelName, adminUid, 'audience');
      await this.client.join(tokenData2.appId, this.channelName, tokenData2.token, adminUid);
      this.isConnected = true;
      console.log(`[Agora Admin] Joined proctor audience on channel: ${this.channelName}`);
    } catch (err) {
      console.error('[Agora Admin] Failed to connect audience:', err);
    }
  }

  hasStream(uid) {
    const user = this.remoteUsers.get(Number(uid));
    return !!(user && user.videoTrack);
  }

  playRemoteVideo(uid, domElement, options = {}) {
    const user = this.remoteUsers.get(Number(uid));
    if (user && user.videoTrack && domElement) {
      try {
        domElement.innerHTML = '';
        user.videoTrack.play(domElement, options);
        return true;
      } catch (err) {
        console.warn(`[Agora Admin] playRemoteVideo failed for UID ${uid}:`, err);
      }
    }
    return false;
  }

  async stop() {
    this.isConnected = false;
    this.remoteUsers.clear();
    try {
      if (this.client) {
        await this.client.leave();
        this.client = null;
      }
    } catch (e) {
      console.warn('[Agora Admin] Leave error:', e);
    }
  }
}
