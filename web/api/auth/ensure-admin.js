const { getAdmin } = require('../_lib/firebase-admin');
const { sendError, methodNotAllowed, getBody, normalizePhone, authEmail, requireUser } = require('../_lib/http');
const { isConfiguredAdminPhone } = require('../_lib/admin-phones');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return methodNotAllowed(res);
  try {
    const admin = getAdmin();
    const db = admin.firestore();
    const token = await requireUser(req, admin);
    const phoneDigits = normalizePhone(getBody(req).phone);
    if (token.firebase?.sign_in_provider !== 'password' || token.email !== authEmail(phoneDigits)) {
      const error = new Error('The signed-in account does not match this phone number.');
      error.status = 403; error.code = 'permission-denied'; throw error;
    }

    const phoneLink = await db.collection('account_phone_index').doc(phoneDigits).get();
    if (!phoneLink.exists || phoneLink.get('uid') !== token.uid) {
      const error = new Error('This phone number is not linked to the signed-in account.');
      error.status = 403; error.code = 'permission-denied'; throw error;
    }
    const profileRef = db.collection('users').doc(token.uid);
    const profile = await profileRef.get();
    if (!profile.exists || normalizePhone(profile.get('phone')) !== phoneDigits) {
      const error = new Error('The account profile does not match this phone number.');
      error.status = 403; error.code = 'permission-denied'; throw error;
    }

    const authUser = await admin.auth().getUser(token.uid);
    const customClaims = { ...authUser.customClaims };
    if (isConfiguredAdminPhone(phoneDigits)) customClaims.admin = true;
    const isAdmin = customClaims.admin === true;
    if (authUser.customClaims?.admin !== isAdmin) {
      if (isAdmin) customClaims.admin = true;
      else delete customClaims.admin;
      await admin.auth().setCustomUserClaims(token.uid, customClaims);
    }
    await profileRef.set({ role: isAdmin ? 'admin' : 'student' }, { merge: true });
    return res.status(200).json({ result: { isAdmin } });
  } catch (error) {
    return sendError(res, error);
  }
};
