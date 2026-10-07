const crypto = require('crypto');
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
    const uid = token.uid;
    const date = String(body.date || '');
    const answers = body.answers;
    const timeTakenSeconds = Math.max(0, Math.min(86400, Number(body.timeTakenSeconds) || 0));
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !answers || typeof answers !== 'object' || Array.isArray(answers)) {
      const error = new Error('A sprint date and answer map are required.');
      error.status = 400; error.code = 'invalid-argument'; throw error;
    }
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      const error = new Error('Student profile is unavailable.');
      error.status = 412; error.code = 'failed-precondition'; throw error;
    }
    const profile = userSnap.data();
    const sprintSnap = await db.collection('daily_sprints').where('targetDate', '==', date).get();
    const matching = sprintSnap.docs.filter((item) => {
      const year = String(item.get('examYear') || 'All Batches');
      return year === 'All Batches' || year === String(profile.examYear || '');
    });
    matching.sort((a, b) => Number(a.get('examYear') === 'All Batches') - Number(b.get('examYear') === 'All Batches'));
    const sprintDoc = matching[0];
    const questions = sprintDoc?.get('questions');
    if (!Array.isArray(questions) || questions.length === 0 || questions.length > 100) {
      const error = new Error('No sprint is published for your batch on this date.');
      error.status = 404; error.code = 'not-found'; throw error;
    }
    let score = 0;
    const safeAnswers = {};
    questions.forEach((question, index) => {
      const selected = Number(answers[String(index)]);
      if (!Number.isInteger(selected) || selected < 0 || selected >= (question.options || []).length) {
        const error = new Error('Every question must have a valid selected answer.');
        error.status = 400; error.code = 'invalid-argument'; throw error;
      }
      safeAnswers[String(index)] = selected;
      if (selected === Number(question.correctIndex)) score += 1;
    });
    const hash = crypto.createHash('sha256').update(`${sprintDoc.id}|${uid}`).digest('hex').slice(0, 48);
    const attemptRef = db.collection('sprint_attempts').doc(hash);
    const creditRef = db.collection('credits_history').doc(`sprint_${hash}`);
    const xpEarned = score * 10;
    await db.runTransaction(async (transaction) => {
      const [attemptSnap, currentUser] = await Promise.all([transaction.get(attemptRef), transaction.get(userRef)]);
      if (attemptSnap.exists) {
        const error = new Error('You have already completed this sprint.');
        error.status = 409; error.code = 'already-exists'; throw error;
      }
      if (!currentUser.exists) {
        const error = new Error('Student profile is unavailable.');
        error.status = 412; error.code = 'failed-precondition'; throw error;
      }
      transaction.create(attemptRef, {
        studentId: uid, studentName: String(profile.name || 'Student').slice(0, 100),
        phone: String(profile.phone || '').slice(0, 30), examYear: String(profile.examYear || '').slice(0, 30),
        date, sprintId: sprintDoc.id, score, totalQuestions: questions.length,
        timeTakenSeconds, timeTakenFormatted: `${Math.floor(timeTakenSeconds / 60)}m ${timeTakenSeconds % 60}s`,
        answers: safeAnswers, xpEarned, createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, { credits: admin.firestore.FieldValue.increment(xpEarned) });
      if (xpEarned > 0) transaction.create(creditRef, {
        studentId: uid, amount: xpEarned, type: 'sprint', sprintId: sprintDoc.id, date,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    return res.status(200).json({ result: { success: true, score, totalQuestions: questions.length, xpEarned } });
  } catch (error) {
    return sendError(res, error);
  }
};
