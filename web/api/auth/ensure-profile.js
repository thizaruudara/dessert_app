const { getAdmin } = require('../_lib/firebase-admin');
const { sendError, methodNotAllowed, getBody, normalizePhone, authEmail, requireUser } = require('../_lib/http');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return methodNotAllowed(res);
  try {
    const admin = getAdmin();
    const db = admin.firestore();
    const token = await requireUser(req, admin);
    const body = getBody(req);
    if (token.firebase?.sign_in_provider !== 'password') {
      const error = new Error('Use a registered Firebase Authentication account.');
      error.status = 403; error.code = 'permission-denied'; throw error;
    }
    const phoneDigits = normalizePhone(body.phone);
    if (token.email !== authEmail(phoneDigits)) {
      const error = new Error('The signed-in account does not match this phone number.');
      error.status = 403; error.code = 'permission-denied'; throw error;
    }
    const name = String(body.name || 'Student').trim().slice(0, 100);
    const examYear = String(body.examYear || '2027 A/L').slice(0, 30);
    const profileRef = db.collection('users').doc(token.uid);
    const phoneRef = db.collection('account_phone_index').doc(phoneDigits);
    const legacyMatches = await db.collection('users').limit(5000).get();
    const legacyMatch = legacyMatches.docs.find((item) =>
      String(item.get('phone') || '').replace(/\D/g, '') === phoneDigits && item.id !== token.uid && !item.get('migratedTo'));
    if (legacyMatch) {
      const error = new Error('An account already uses this phone number. Sign in to your existing account.');
      error.status = 409; error.code = 'already-exists'; throw error;
    }
    await db.runTransaction(async (transaction) => {
      const [profileSnap, phoneSnap] = await Promise.all([transaction.get(profileRef), transaction.get(phoneRef)]);
      if (phoneSnap.exists && phoneSnap.get('uid') !== token.uid) {
        const error = new Error('An account already uses this phone number.');
        error.status = 409; error.code = 'already-exists'; throw error;
      }
      if (!profileSnap.exists) transaction.create(profileRef, {
        uid: token.uid, name, phone: `+${phoneDigits}`, role: 'student', credits: 0,
        examYear, studentId: `EP-${phoneDigits.slice(-4)}`, avatarUrl: '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(phoneRef, { uid: token.uid }, { merge: true });
    });
    return res.status(200).json({ result: { uid: token.uid } });
  } catch (error) {
    return sendError(res, error);
  }
};
