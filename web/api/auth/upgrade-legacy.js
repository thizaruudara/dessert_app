const crypto = require('crypto');
const { getAdmin } = require('../_lib/firebase-admin');
const { sendError, methodNotAllowed, handleCors, getBody, normalizePhone, authEmail } = require('../_lib/http');
const { isConfiguredAdminPhone } = require('../_lib/admin-phones');

module.exports = async function handler(req, res) {
  if (handleCors(req, res)) return;
  if (req.method !== 'POST') return methodNotAllowed(res);
  try {
    const admin = getAdmin();
    const db = admin.firestore();
    const body = getBody(req);
    const phoneDigits = normalizePhone(body.phone);
    const password = String(body.password || '');
    // Existing APK accounts may have six-character passwords; Firebase Auth's
    // default minimum is six, so permit those only during legacy migration.
    if (password.length < 6 || password.length > 128) {
      const error = new Error('Password must be between 6 and 128 characters.');
      error.status = 400; error.code = 'invalid-argument'; throw error;
    }

    const ip = String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim().slice(0, 64);
    const throttleId = crypto.createHash('sha256').update(`${ip}|${phoneDigits}`).digest('hex');
    const throttleRef = db.collection('auth_migration_attempts').doc(throttleId);
    await db.runTransaction(async (transaction) => {
      const attemptSnap = await transaction.get(throttleRef);
      const now = Date.now();
      const data = attemptSnap.data() || {};
      const inWindow = data.windowStart && now - data.windowStart < 10 * 60 * 1000;
      const attempts = inWindow ? Number(data.attempts || 0) : 0;
      if (attempts >= 8) {
        const error = new Error('Too many sign-in attempts. Wait 10 minutes and try again.');
        error.status = 429; error.code = 'resource-exhausted'; throw error;
      }
      transaction.set(throttleRef, { windowStart: attempts ? data.windowStart : now, attempts: attempts + 1 });
    });

    const matches = await db.collection('users').limit(5000).get();
    const legacy = matches.docs.find((item) => String(item.get('phone') || '').replace(/\D/g, '') === phoneDigits);
    const storedPassword = legacy?.get('password');
    const supplied = Buffer.from(password);
    const stored = Buffer.from(String(storedPassword || ''));
    const passwordMatches = storedPassword && supplied.length === stored.length && crypto.timingSafeEqual(supplied, stored);
    if (!legacy || !passwordMatches) {
      const error = new Error('Account not found or password incorrect. Use account recovery to continue.');
      error.status = 401; error.code = 'unauthenticated'; throw error;
    }

    const email = authEmail(phoneDigits);
    const isAdmin = isConfiguredAdminPhone(phoneDigits);
    let authUser;
    try {
      authUser = await admin.auth().createUser({ email, password, disabled: false });
      if (isAdmin) await admin.auth().setCustomUserClaims(authUser.uid, { admin: true });
    } catch (cause) {
      if (cause.code === 'auth/email-already-exists') {
        const error = new Error('This account has already started migration. Sign in with Firebase Authentication or reset its password.');
        error.status = 409; error.code = 'already-exists'; throw error;
      }
      throw cause;
    }

    const profile = { ...legacy.data() };
    delete profile.password;
    profile.uid = authUser.uid;
    profile.phone = `+${phoneDigits}`;
    profile.role = isAdmin ? 'admin' : 'student';
    profile.migratedAt = admin.firestore.FieldValue.serverTimestamp();
    const profileRef = db.collection('users').doc(authUser.uid);
    const phoneRef = db.collection('account_phone_index').doc(phoneDigits);
    try {
      await db.runTransaction(async (transaction) => {
        const phoneSnap = await transaction.get(phoneRef);
        if (phoneSnap.exists) {
          const error = new Error('This phone number is already linked to an account.');
          error.status = 409; error.code = 'already-exists'; throw error;
        }
        transaction.create(profileRef, profile);
        transaction.create(phoneRef, { uid: authUser.uid });
      });
    } catch (error) {
      await admin.auth().deleteUser(authUser.uid).catch(() => {});
      throw error;
    }

    for (const collectionName of ['desserts', 'sprint_attempts', 'proctor_alerts', 'credits_history']) {
      const oldDocs = await db.collection(collectionName).where('studentId', '==', legacy.id).get();
      for (let offset = 0; offset < oldDocs.docs.length; offset += 400) {
        const batch = db.batch();
        oldDocs.docs.slice(offset, offset + 400).forEach((item) => batch.update(item.ref, { studentId: authUser.uid }));
        await batch.commit();
      }
    }

    const registrations = await db.collection('paper_registrations').where('studentId', '==', legacy.id).get();
    for (const registration of registrations.docs) {
      const data = registration.data();
      if (!data.paperId) continue;
      const batch = db.batch();
      batch.set(db.collection('paper_registrations').doc(`${String(data.paperId)}_${authUser.uid}`), { ...data, studentId: authUser.uid }, { merge: true });
      batch.delete(registration.ref);
      await batch.commit();
    }
    await legacy.ref.update({ password: admin.firestore.FieldValue.delete(), role: isAdmin ? 'admin' : 'student', migratedTo: authUser.uid });
    const token = await admin.auth().createCustomToken(authUser.uid);
    return res.status(200).json({ result: { token } });
  } catch (error) {
    return sendError(res, error);
  }
};
