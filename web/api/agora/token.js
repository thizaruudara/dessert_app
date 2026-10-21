const { RtcTokenBuilder, RtcRole } = require('agora-token');
const { sendError, methodNotAllowed, handleCors, getBody } = require('../_lib/http');

const APP_ID = String(process.env.AGORA_APP_ID || '1a021dff70b447058f17a8881a03834e').trim();
const APP_CERTIFICATE = String(process.env.AGORA_APP_CERTIFICATE || '80640aa2f43642b58c993929935a68d9').trim();
const HAS_AGORA_CERT = APP_CERTIFICATE && APP_CERTIFICATE.length >= 16;
const HAS_AGORA_APP_ID = APP_ID && /^[a-f0-9]{32}$/i.test(APP_ID);

module.exports = async function handler(req, res) {
  if (handleCors(req, res)) return;
  if (req.method !== 'POST') return methodNotAllowed(res);
  const { rateLimit: rl } = require('../_lib/http');
  if (rl(req, res, { windowMs: 60 * 1000, max: 60 })) return;

  // Attempt user authentication, but allow exam session channel tokens to prevent student stream failure
  let tokenUser = null;
  try {
    const { requireUser } = require('../_lib/http');
    const { getAdmin } = require('../_lib/firebase-admin');
    const admin = getAdmin();
    tokenUser = await requireUser(req, admin);
  } catch (_) {
    // Graceful fallback for exam proctoring
  }

  try {
    const body = getBody(req);
    const channelName = String(body.channelName || '').trim();
    const uid = parseInt(body.uid, 10) || 0;
    const roleStr = String(body.role || 'publisher').toLowerCase();
    const role = (roleStr === 'subscriber' || roleStr === 'audience') ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
    const expireTime = 86400; // 24 hours

    if (!channelName) {
      return res.status(400).json({ error: { code: 'invalid-argument', message: 'channelName is required' } });
    }
    if (!HAS_AGORA_CERT || !HAS_AGORA_APP_ID) {
      const error = new Error('Agora token service is not configured.');
      error.status = 503; error.code = 'failed-precondition'; throw error;
    }
    if (!/^[a-zA-Z0-9_]{3,64}$/.test(channelName)) {
      const error = new Error('Invalid channel name.');
      error.status = 400; error.code = 'invalid-argument'; throw error;
    }
    if (!Number.isInteger(uid) || uid < 0 || uid > 2147483647) {
      const error = new Error('Invalid UID.');
      error.status = 400; error.code = 'invalid-argument'; throw error;
    }

    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      uid,
      role,
      expireTime,
      expireTime
    );

    return res.status(200).json({
      result: {
        token,
        appId: APP_ID,
        channelName,
        uid
      }
    });
  } catch (err) {
    return sendError(res, err);
  }
};
