const { getAdmin } = require('../_lib/firebase-admin');
const { sendError, methodNotAllowed, handleCors, getBody, requireUser } = require('../_lib/http');

module.exports = async function handler(req, res) {
  if (handleCors(req, res)) return;
  if (req.method !== 'POST') return methodNotAllowed(res);

  try {
    const admin = getAdmin();
    const db = admin.firestore();
    const token = await requireUser(req, admin);
    const body = getBody(req);

    // Verify caller is admin
    const callerSnap = await db.collection('users').doc(token.uid).get();
    const callerData = callerSnap.data() || {};
    if (callerData.role !== 'admin' && !callerData.isAdmin) {
      const err = new Error('Only administrators can broadcast exam notifications.');
      err.status = 403;
      err.code = 'permission-denied';
      throw err;
    }

    const paperId = String(body.paperId || '').slice(0, 160);
    const action = String(body.action || 'scheduled'); // 'scheduled' | 'live' | 'time_up' | 'hint'
    const examYear = String(body.examYear || 'All Batches');
    const customTitle = body.title ? String(body.title).slice(0, 200) : null;
    const customMessage = body.message ? String(body.message).slice(0, 400) : null;

    let paperTitle = customTitle || 'Physics Examination Paper';
    if (paperId && !customTitle) {
      const paperSnap = await db.collection('paper_sessions').doc(paperId).get();
      if (paperSnap.exists) {
        paperTitle = paperSnap.data()?.title || paperTitle;
      }
    }

    let title = '📅 Paper Session Update';
    let message = customMessage || `Update regarding "${paperTitle}".`;
    let tag = `paper-${paperId || Date.now()}`;
    const targetUrl = './index.html?tab=papers';

    if (action === 'live') {
      title = '🔴 Live Exam Started!';
      message = customMessage || `"${paperTitle}" (${examYear}) is now LIVE! Tap to enter exam hall.`;
      tag = `live-exam-${paperId}`;
    } else if (action === 'time_up') {
      title = '⏰ Exam Time Is Up!';
      message = customMessage || `Writing time has ended for "${paperTitle}". Scan and submit your answers now!`;
      tag = `timeup-exam-${paperId}`;
    } else if (action === 'scheduled') {
      title = '📅 New Paper Session Scheduled!';
      message = customMessage || `"${paperTitle}" (${examYear}) has been scheduled. Tap to register your slot!`;
      tag = `scheduled-exam-${paperId}`;
    } else if (action === 'hint') {
      title = '💡 New Paper Hint & Scope Published!';
      message = customMessage || `Exclusive scope & formulas published for "${paperTitle}" (${examYear}).`;
      tag = `paper-hint-${paperId}`;
    }

    const payloadData = {
      title,
      body: message,
      url: targetUrl,
      route: targetUrl,
      tag,
      paperId: String(paperId || ''),
      examYear: String(examYear),
      type: action === 'live' ? 'live_exam' : 'paper_session',
    };

    // 1. Send to FCM topic 'paper_sessions'
    try {
      await admin.messaging().send({
        topic: 'paper_sessions',
        notification: { title, body: message },
        data: payloadData,
        android: {
          priority: 'high',
          notification: {
            channelId: 'edupeak_high_importance_channel',
            priority: 'high',
            sound: 'default',
          },
        },
        webpush: {
          notification: {
            title,
            body: message,
            icon: './icons/icon-192.png',
            badge: './icons/icon-192.png',
            vibrate: [300, 100, 300, 100, 300],
            requireInteraction: true,
            tag,
          },
          fcmOptions: {
            link: targetUrl,
          },
        },
      });
    } catch (topicErr) {
      console.warn('[Broadcast API] Topic notice:', topicErr.message);
    }

    // 2. Multicast directly to student device tokens
    let tokensSent = 0;
    try {
      const snap = await db.collection('users').where('role', '==', 'student').get();
      const tokens = new Set();

      snap.forEach((docSnap) => {
        const u = docSnap.data() || {};
        const studentYear = String(u.examYear || '');
        if (
          examYear &&
          examYear !== 'All' &&
          examYear !== 'All Batches' &&
          studentYear &&
          !studentYear.includes(examYear.replace(/\s*A\/L/i, '').trim())
        ) {
          return;
        }

        if (typeof u.fcmToken === 'string' && !u.fcmToken.startsWith('web_token_') && !u.fcmToken.startsWith('{')) {
          tokens.add(u.fcmToken);
        }
        if (Array.isArray(u.fcmTokens)) {
          u.fcmTokens.forEach((t) => {
            if (typeof t === 'string' && !t.startsWith('web_token_') && !t.startsWith('{')) {
              tokens.add(t);
            }
          });
        }
      });

      if (tokens.size > 0) {
        const messages = Array.from(tokens).map((token) => ({
          token,
          notification: { title, body: message },
          data: payloadData,
          android: {
            priority: 'high',
            notification: {
              channelId: 'edupeak_high_importance_channel',
              priority: 'high',
              sound: 'default',
            },
          },
          webpush: {
            notification: {
              title,
              body: message,
              icon: './icons/icon-192.png',
              badge: './icons/icon-192.png',
              vibrate: [300, 100, 300, 100, 300],
              requireInteraction: true,
              tag,
            },
            fcmOptions: {
              link: targetUrl,
            },
          },
        }));

        for (let i = 0; i < messages.length; i += 500) {
          const batch = messages.slice(i, i + 500);
          if (admin.messaging().sendEach) {
            await admin.messaging().sendEach(batch);
          } else {
            await Promise.all(batch.map((m) => admin.messaging().send(m)));
          }
        }
        tokensSent = tokens.size;
      }
    } catch (multicastErr) {
      console.warn('[Broadcast API] Multicast notice:', multicastErr.message);
    }

    return res.status(200).json({
      result: {
        success: true,
        action,
        tokensSent,
        paperId,
        title,
      },
    });
  } catch (error) {
    return sendError(res, error);
  }
};
