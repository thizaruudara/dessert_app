const { getAdmin } = require('../_lib/firebase-admin');
const { sendError, methodNotAllowed, getBody, requireUser } = require('../_lib/http');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return methodNotAllowed(res);
  try {
    const admin = getAdmin();
    const db = admin.firestore();
    const token = await requireUser(req, admin);
    const body = getBody(req);
    const uid = token.uid;
    const paperId = String(body.paperId || '').slice(0, 160);
    const slotId = String(body.slotId || '');
    if (!paperId || !['slot1', 'slot2'].includes(slotId)) {
      const error = new Error('Choose a valid paper session and slot.');
      error.status = 400; error.code = 'invalid-argument'; throw error;
    }
    const paperRef = db.collection('paper_sessions').doc(paperId);
    const userRef = db.collection('users').doc(uid);
    const regRef = db.collection('paper_registrations').doc(`${paperId}_${uid}`);
    await db.runTransaction(async (transaction) => {
      const [paperSnap, userSnap, regSnap] = await Promise.all([
        transaction.get(paperRef), transaction.get(userRef), transaction.get(regRef),
      ]);
      if (!paperSnap.exists || !userSnap.exists) {
        const error = new Error('The account or paper session was not found.');
        error.status = 404; error.code = 'not-found'; throw error;
      }
      const user = userSnap.data();
      const paper = paperSnap.data();
      const prevSlot = regSnap.exists ? regSnap.get('selectedSlot') : null;
      const count = Number((paper[slotId] || {}).registeredCount || 0);
      const capacity = Number((paper[slotId] || {}).maxCapacity || 0);
      if (prevSlot !== slotId && capacity > 0 && count >= capacity) {
        const error = new Error('This exam slot is full.');
        error.status = 429; error.code = 'resource-exhausted'; throw error;
      }
      const updates = {};
      if (prevSlot && prevSlot !== slotId && paper[prevSlot]) {
        updates[`${prevSlot}.registeredCount`] = Math.max(0, Number(paper[prevSlot].registeredCount || 0) - 1);
      }
      if (prevSlot !== slotId) updates[`${slotId}.registeredCount`] = count + 1;
      if (Object.keys(updates).length) transaction.update(paperRef, updates);
      transaction.set(regRef, {
        paperId, studentId: uid, studentName: String(user.name || 'Student'),
        studentPhone: String(user.phone || ''), selectedSlot: slotId,
        status: 'registered', registeredAt: admin.firestore.FieldValue.serverTimestamp(),
        isCameraActive: false,
      }, { merge: true });
    });
    return res.status(200).json({ result: { success: true, registrationId: `${paperId}_${uid}` } });
  } catch (error) {
    return sendError(res, error);
  }
};
