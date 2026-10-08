const { RtcTokenBuilder, RtcRole } = require('agora-token');
const { sendError, methodNotAllowed, handleCors, getBody } = require('../_lib/http');

const APP_ID = '1a021dff70b447058f17a8881a03834e';
const APP_CERTIFICATE = '80640aa2f43642b58c993929935a68d9';

module.exports = async function handler(req, res) {
  if (handleCors(req, res)) return;
  if (req.method !== 'POST') return methodNotAllowed(res);
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
