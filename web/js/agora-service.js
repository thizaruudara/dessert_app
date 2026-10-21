// EduPeak Web Agora RTC Service
// Provides real-time 720p HD WebRTC video broadcasting for students
// and multi-stream live surveillance monitoring for proctors, matching Flutter 1:1.

import AgoraRTC from 'agora-rtc-sdk-ng';
import { auth } from './firebase-config.js';

export const AGORA_APP_ID = '1a021dff70b447058f17a8881a03834e';
export const AGORA_APP_CERTIFICATE = '80640aa2f43642b58c993929935a68d9';

// Native browser CRC32 calculation table
const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[i] = c >>> 0;
  }
  return table;
})();

function calcCrc32(str) {
  let crc = 0xFFFFFFFF;
  const bytes = new TextEncoder().encode(String(str || ''));
  for (let i = 0; i < bytes.length; i++) {
    crc = (crc >>> 8) ^ CRC_TABLE[(crc ^ bytes[i]) & 0xFF];
  }
  return (crc ^ 0xFFFFFFFF) >>> 0;
}

class ByteBuf {
  constructor(initialCap = 1024) {
    this.buffer = new Uint8Array(initialCap);
    this.view = new DataView(this.buffer.buffer);
    this.pos = 0;
  }
  ensure(extra) {
    if (this.pos + extra > this.buffer.length) {
      const next = new Uint8Array(Math.max(this.buffer.length * 2, this.pos + extra));
      next.set(this.buffer);
      this.buffer = next;
      this.view = new DataView(this.buffer.buffer);
    }
  }
  putUint16(v) {
    this.ensure(2);
    this.view.setUint16(this.pos, v, true);
    this.pos += 2;
    return this;
  }
  putUint32(v) {
    this.ensure(4);
    this.view.setUint32(this.pos, v, true);
    this.pos += 4;
    return this;
  }
  putBytes(bytes) {
    this.putUint16(bytes.length);
    this.ensure(bytes.length);
    this.buffer.set(bytes, this.pos);
    this.pos += bytes.length;
    return this;
  }
  putString(str) {
    return this.putBytes(new TextEncoder().encode(String(str || '')));
  }
  putTreeMapUInt32(map) {
    const keys = Object.keys(map);
    this.putUint16(keys.length);
    for (const k of keys) {
      this.putUint16(Number(k));
      this.putUint32(Number(map[k]));
    }
    return this;
  }
  pack() {
    return this.buffer.slice(0, this.pos);
  }
}

// Generates a valid HMAC-SHA256 signed Agora RTC v006 token directly via Web Crypto API
export async function generateClientAgoraToken(channelName, uid, role = 'publisher', expireSeconds = 86400) {
  try {
    const appId = AGORA_APP_ID;
    const appCert = AGORA_APP_CERTIFICATE;
    const ts = Math.floor(Date.now() / 1000) + expireSeconds;
    const salt = Math.floor(Math.random() * 0xffffffff);
    const uidStr = (!uid || uid === 0) ? '' : String(uid);

    const messages = { 1: ts };
    if (role === 'publisher' || role === 'host') {
      messages[2] = ts;
      messages[3] = ts;
      messages[4] = ts;
    }

    const msgBuf = new ByteBuf();
    msgBuf.putUint32(salt);
    msgBuf.putUint32(ts);
    msgBuf.putTreeMapUInt32(messages);
    const m = msgBuf.pack();

    const enc = new TextEncoder();
    const toSign = new Uint8Array(appId.length + channelName.length + uidStr.length + m.length);
    let offset = 0;
    toSign.set(enc.encode(appId), offset); offset += appId.length;
    toSign.set(enc.encode(channelName), offset); offset += channelName.length;
    toSign.set(enc.encode(uidStr), offset); offset += uidStr.length;
    toSign.set(m, offset);

    const subtleCrypto = (typeof window !== 'undefined' && window.crypto && window.crypto.subtle)
      ? window.crypto.subtle
      : (typeof crypto !== 'undefined' && crypto.subtle ? crypto.subtle : null);

    if (!subtleCrypto) return '';

    const key = await subtleCrypto.importKey(
      'raw',
      enc.encode(appCert),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
    const sigBuf = await subtleCrypto.sign('HMAC', key, toSign);
    const sig = new Uint8Array(sigBuf);

    const contentBuf = new ByteBuf();
    contentBuf.putBytes(sig);
    contentBuf.putUint32(calcCrc32(channelName));
    contentBuf.putUint32(calcCrc32(uidStr));
    contentBuf.putBytes(m);
    const content = contentBuf.pack();

    let binStr = '';
    const len = content.length;
    for (let i = 0; i < len; i++) {
      binStr += String.fromCharCode(content[i]);
    }
    const b64 = (typeof btoa === 'function')
      ? btoa(binStr)
      : (typeof Buffer !== 'undefined' ? Buffer.from(content).toString('base64') : '');

    return '006' + appId + b64;
  } catch (err) {
    console.warn('[Agora] Client token generator notice:', err);
    return '';
  }
}

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

// Matches Flutter PaperRegistration.computedAgoraUid 1:1 (prioritizes student phone, then ID)
export function getComputedAgoraUid(student) {
  if (!student) return 1001;
  if (student.agoraUid && Number(student.agoraUid) > 0) return Number(student.agoraUid);
  const idToUse = student.studentPhone || student.phone || student.studentId || student.id || student.uid || '';
  return getNumericUid(idToUse);
}

// Format channel name matching Flutter AgoraRtcService.getChannelName
export function getChannelName(paperId) {
  const sanitized = String(paperId || '').replace(/[^a-zA-Z0-9_]/g, '_');
  return `exam_${sanitized}`;
}

// Fetch token: prefers instant client HMAC-SHA256 token, with server endpoint fallback
export async function fetchAgoraToken(channelName, uid, role = 'publisher') {
  // 1. Instant client-side generation using Web Crypto (Zero latency, zero network dependency)
  try {
    const localToken = await generateClientAgoraToken(channelName, uid, role);
    if (localToken && localToken.length > 50) {
      console.log(`[Agora] Authenticated via secure client token (Channel: ${channelName}, UID: ${uid})`);
      return localToken;
    }
  } catch (localErr) {
    console.warn('[Agora] Client token generator notice:', localErr);
  }

  // 2. Server endpoint fallback if Web Crypto is unavailable
  try {
    const headers = { 'Content-Type': 'application/json' };
    const user = auth?.currentUser;
    if (user && typeof user.getIdToken === 'function') {
      try {
        const idToken = await user.getIdToken();
        if (idToken) headers.Authorization = `Bearer ${idToken}`;
      } catch (_) {}
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 3500);
    const res = await fetch('/api/agora/token', {
      method: 'POST',
      headers,
      body: JSON.stringify({ channelName, uid, role }),
      signal: controller.signal
    });
    clearTimeout(timer);
    if (res.ok) {
      const data = await res.json();
      if (data?.result?.token) {
        return data.result.token;
      }
    }
  } catch (err) {
    console.warn('[Agora] Server token fetch notice:', err.message);
  }
  return '';
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
    if (this.isBroadcasting && this.localVideoTrack) return this.uid;
    const channelName = getChannelName(paperId);
    this.uid = getNumericUid(studentId);

    try {
      this.client = AgoraRTC.createClient({ mode: 'live', codec: 'vp8' });
      await this.client.setClientRole('host');

      const token = await fetchAgoraToken(channelName, this.uid, 'publisher');
      await this.client.join(AGORA_APP_ID, channelName, token || null, this.uid);

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
            frameRate: 24,
            bitrateMin: 400,
            bitrateMax: 1200
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

      const token = await fetchAgoraToken(this.channelName, adminUid, 'audience');
      await this.client.join(AGORA_APP_ID, this.channelName, token || null, adminUid);
      this.isConnected = true;
      console.log(`[Agora Admin] Joined proctor audience on channel: ${this.channelName}`);

      // Auto-subscribe to any existing remote broadcasters already streaming in channel
      if (this.client.remoteUsers && this.client.remoteUsers.length > 0) {
        for (const rUser of this.client.remoteUsers) {
          if (rUser.hasVideo && !rUser.videoTrack) {
            try {
              await this.client.subscribe(rUser, 'video');
              this.remoteUsers.set(Number(rUser.uid), rUser);
              if (this.onStreamChange) this.onStreamChange(Number(rUser.uid), rUser, true);
            } catch (autoErr) {
              console.warn('[Agora Admin] Auto-subscribe error for existing stream:', autoErr);
            }
          }
        }
      }
    } catch (err) {
      console.error('[Agora Admin] Failed to connect audience:', err);
    }
  }

  hasStream(uid) {
    if (Array.isArray(uid)) {
      return uid.some(u => this.hasStream(u));
    }
    const num = Number(uid);
    if (!isNaN(num)) {
      const user = this.remoteUsers.get(num);
      if (user && user.videoTrack) return true;
    }
    // Fallback: if only 1 remote user exists in channel with active video, match it
    if (this.remoteUsers.size === 1) {
      for (const user of this.remoteUsers.values()) {
        if (user && user.videoTrack) return true;
      }
    }
    return false;
  }

  getActiveUid(uidOrCandidates) {
    if (Array.isArray(uidOrCandidates)) {
      for (const u of uidOrCandidates) {
        const num = Number(u);
        const user = this.remoteUsers.get(num);
        if (user && user.videoTrack) return num;
      }
    } else {
      const num = Number(uidOrCandidates);
      const user = this.remoteUsers.get(num);
      if (user && user.videoTrack) return num;
    }
    // Fallback: if single remote stream exists
    if (this.remoteUsers.size === 1) {
      for (const [rUid, user] of this.remoteUsers.entries()) {
        if (user && user.videoTrack) return rUid;
      }
    }
    return null;
  }

  playRemoteVideo(uid, domElement, options = {}) {
    let targetUid = Number(uid);
    let user = !isNaN(targetUid) ? this.remoteUsers.get(targetUid) : null;
    if (!user || !user.videoTrack) {
      const resolved = this.getActiveUid(uid);
      if (resolved !== null) {
        targetUid = resolved;
        user = this.remoteUsers.get(targetUid);
      }
    }
    if (user && user.videoTrack && domElement) {
      try {
        domElement.innerHTML = '';
        user.videoTrack.play(domElement, options);
        return true;
      } catch (err) {
        console.warn(`[Agora Admin] playRemoteVideo failed for UID ${targetUid}:`, err);
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
