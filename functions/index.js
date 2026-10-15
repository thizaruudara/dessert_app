const functions = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

// Passwords belong to Firebase Authentication. Legacy accounts are upgraded
// exactly once after their existing password has been checked server-side.
function normalizePhone(value) {
  let digits = String(value || "").replace(/\D/g, "");
  if (digits.startsWith("0")) digits = `94${digits.slice(1)}`;
  else if (digits.length === 9) digits = `94${digits}`;
  if (!digits) throw new HttpsError("invalid-argument", "Enter a valid phone number.");
  return digits;
}

function authEmail(phoneDigits) {
  return `p${phoneDigits}@users.edupeak.app`;
}

exports.upgradeLegacyAccount = onCall(async (request) => {
  const phoneDigits = normalizePhone(request.data?.phone);
  const password = String(request.data?.password || "");
  if (password.length < 8) throw new HttpsError("invalid-argument", "Password must be at least 8 characters.");

  const ip = String(request.rawRequest?.ip || "unknown");
  const throttleId = crypto.createHash("sha256").update(`${ip}|${phoneDigits}`).digest("hex");
  const throttleRef = db.collection("auth_migration_attempts").doc(throttleId);
  await db.runTransaction(async (transaction) => {
    const attemptSnap = await transaction.get(throttleRef);
    const now = Date.now();
    const data = attemptSnap.data() || {};
    const attempts = data.windowStart && now - data.windowStart < 10 * 60 * 1000 ? Number(data.attempts || 0) : 0;
    if (attempts >= 8) throw new HttpsError("resource-exhausted", "Too many sign-in attempts. Wait 10 minutes and try again.");
    transaction.set(throttleRef, { windowStart: attempts ? data.windowStart : now, attempts: attempts + 1 });
  });

  const matches = await db.collection("users").limit(5000).get();
  const legacy = matches.docs.find((item) => String(item.get("phone") || "").replace(/\D/g, "") === phoneDigits);
  if (!legacy || !legacy.get("password") || legacy.get("password") !== password) {
    throw new HttpsError("unauthenticated", "Account not found or password incorrect. Use account recovery to continue.");
  }

  const email = authEmail(phoneDigits);
  let authUser;
  try {
    authUser = await admin.auth().createUser({ email, password, disabled: false });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This account has already started migration. Sign in with Firebase Authentication or reset its password.");
    }
    throw new HttpsError("internal", "Could not migrate account.");
  }

  const profile = { ...legacy.data() };
  delete profile.password;
  profile.uid = authUser.uid;
  profile.phone = `+${phoneDigits}`;
  // Legacy client-side role assignments are not trusted during migration.
  profile.role = "student";
  profile.migratedAt = admin.firestore.FieldValue.serverTimestamp();

  const profileRef = db.collection("users").doc(authUser.uid);
  const phoneRef = db.collection("account_phone_index").doc(phoneDigits);
  try {
    await db.runTransaction(async (transaction) => {
      const phoneSnap = await transaction.get(phoneRef);
      if (phoneSnap.exists) throw new HttpsError("already-exists", "This phone number is already linked to an account.");
      transaction.create(profileRef, profile);
      transaction.create(phoneRef, { uid: authUser.uid });
    });
  } catch (error) {
    await admin.auth().deleteUser(authUser.uid).catch(() => {});
    throw error;
  }
  for (const collectionName of ["desserts", "sprint_attempts", "proctor_alerts", "credits_history"]) {
    const oldRefs = (await db.collection(collectionName).where("studentId", "==", legacy.id).get()).docs.map((item) => item.ref);
    for (let offset = 0; offset < oldRefs.length; offset += 400) {
      const batch = db.batch();
      oldRefs.slice(offset, offset + 400).forEach((ref) => batch.update(ref, { studentId: authUser.uid }));
      await batch.commit();
    }
  }
  const oldRegistrations = (await db.collection("paper_registrations").where("studentId", "==", legacy.id).get()).docs;
  for (const registration of oldRegistrations) {
    const data = registration.data();
    const newId = `${String(data.paperId || "")}_${authUser.uid}`;
    if (!data.paperId) continue;
    const batch = db.batch();
    batch.set(db.collection("paper_registrations").doc(newId), { ...data, studentId: authUser.uid }, { merge: true });
    batch.delete(registration.ref);
    await batch.commit();
  }
  await legacy.ref.update({ password: admin.firestore.FieldValue.delete(), role: "student", migratedTo: authUser.uid });
  return { token: await admin.auth().createCustomToken(authUser.uid) };
});

exports.ensureUserProfile = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  if (request.auth.token.firebase?.sign_in_provider !== "password") {
    throw new HttpsError("permission-denied", "Use a registered Firebase Authentication account.");
  }
  const uid = request.auth.uid;
  const phoneDigits = normalizePhone(request.data?.phone);
  if (request.auth.token.email !== authEmail(phoneDigits)) {
    throw new HttpsError("permission-denied", "The signed-in account does not match this phone number.");
  }
  const name = String(request.data?.name || "Student").trim().slice(0, 100);
  const examYear = String(request.data?.examYear || "2027 A/L").slice(0, 30);
  const profileRef = db.collection("users").doc(uid);
  const phoneRef = db.collection("account_phone_index").doc(phoneDigits);
  const legacyMatches = await db.collection("users").limit(5000).get();
  const legacyMatch = legacyMatches.docs.find((item) => String(item.get("phone") || "").replace(/\D/g, "") === phoneDigits && item.id !== uid && !item.get("migratedTo"));
  if (legacyMatch) {
    throw new HttpsError("already-exists", "An account already uses this phone number. Sign in to your existing account.");
  }

  await db.runTransaction(async (transaction) => {
    const [profileSnap, phoneSnap] = await Promise.all([transaction.get(profileRef), transaction.get(phoneRef)]);
    if (phoneSnap.exists && phoneSnap.get("uid") !== uid) {
      throw new HttpsError("already-exists", "An account already uses this phone number.");
    }
    if (!profileSnap.exists) {
      transaction.create(profileRef, {
        uid, name, phone: `+${phoneDigits}`, role: "student", credits: 0,
        examYear, studentId: `EP-${phoneDigits.slice(-4)}`, avatarUrl: "",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    transaction.set(phoneRef, { uid }, { merge: true });
  });
  return { uid };
});

exports.registerPaperSlot = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = request.auth.uid;
  const paperId = String(request.data?.paperId || "").slice(0, 160);
  const slotId = String(request.data?.slotId || "");
  if (!paperId || !["slot1", "slot2"].includes(slotId)) {
    throw new HttpsError("invalid-argument", "Choose a valid paper session and slot.");
  }
  const paperRef = db.collection("paper_sessions").doc(paperId);
  const userRef = db.collection("users").doc(uid);
  const regRef = db.collection("paper_registrations").doc(`${paperId}_${uid}`);
  await db.runTransaction(async (transaction) => {
    const [paperSnap, userSnap, regSnap] = await Promise.all([
      transaction.get(paperRef), transaction.get(userRef), transaction.get(regRef)
    ]);
    if (!paperSnap.exists || !userSnap.exists) throw new HttpsError("not-found", "The account or paper session was not found.");
    const user = userSnap.data();
    const paper = paperSnap.data();
    const prevSlot = regSnap.exists ? regSnap.get("selectedSlot") : null;
    const slot = paper[slotId] || {};
    const count = Number(slot.registeredCount || 0);
    const capacity = Number(slot.maxCapacity || 0);
    if (prevSlot !== slotId && capacity > 0 && count >= capacity) {
      throw new HttpsError("resource-exhausted", "This exam slot is full.");
    }
    const updates = {};
    if (prevSlot && prevSlot !== slotId && paper[prevSlot]) {
      updates[`${prevSlot}.registeredCount`] = Math.max(0, Number(paper[prevSlot].registeredCount || 0) - 1);
    }
    if (prevSlot !== slotId) updates[`${slotId}.registeredCount`] = count + 1;
    if (Object.keys(updates).length) transaction.update(paperRef, updates);
    transaction.set(regRef, {
      paperId, studentId: uid, studentName: String(user.name || "Student"),
      studentPhone: String(user.phone || ""), selectedSlot: slotId,
      status: "registered", registeredAt: admin.firestore.FieldValue.serverTimestamp(),
      isCameraActive: false
    }, { merge: true });
  });
  return { success: true, registrationId: `${paperId}_${uid}` };
});

// Sprint answers are graded on the server so clients cannot submit inflated
// scores or grant themselves leaderboard credits.
exports.submitSprintAttempt = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = request.auth.uid;
  const date = String(request.data?.date || "");
  const answers = request.data?.answers;
  const timeTakenSeconds = Math.max(0, Math.min(86400, Number(request.data?.timeTakenSeconds) || 0));
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !answers || typeof answers !== "object" || Array.isArray(answers)) {
    throw new HttpsError("invalid-argument", "A sprint date and answer map are required.");
  }

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) throw new HttpsError("failed-precondition", "Student profile is unavailable.");
  const profile = userSnap.data();
  const sprintSnap = await db.collection("daily_sprints").where("targetDate", "==", date).get();
  const matching = sprintSnap.docs.filter((item) => {
    const year = String(item.get("examYear") || "All Batches");
    return year === "All Batches" || year === String(profile.examYear || "");
  });
  matching.sort((a, b) => Number(a.get("examYear") === "All Batches") - Number(b.get("examYear") === "All Batches"));
  const sprintDoc = matching[0];
  const questions = sprintDoc?.get("questions");
  if (!Array.isArray(questions) || questions.length === 0 || questions.length > 100) {
    throw new HttpsError("not-found", "No sprint is published for your batch on this date.");
  }

  let score = 0;
  const safeAnswers = {};
  questions.forEach((question, index) => {
    const selected = Number(answers[String(index)]);
    if (!Number.isInteger(selected) || selected < 0 || selected >= (question.options || []).length) {
      throw new HttpsError("invalid-argument", "Every question must have a valid selected answer.");
    }
    safeAnswers[String(index)] = selected;
    if (selected === Number(question.correctIndex)) score += 1;
  });

  const hash = crypto.createHash("sha256").update(`${sprintDoc.id}|${uid}`).digest("hex").slice(0, 48);
  const attemptRef = db.collection("sprint_attempts").doc(hash);
  const creditRef = db.collection("credits_history").doc(`sprint_${hash}`);
  const xpEarned = score * 10;
  await db.runTransaction(async (transaction) => {
    const [attemptSnap, currentUser] = await Promise.all([transaction.get(attemptRef), transaction.get(userRef)]);
    if (attemptSnap.exists) throw new HttpsError("already-exists", "You have already completed this sprint.");
    if (!currentUser.exists) throw new HttpsError("failed-precondition", "Student profile is unavailable.");
    transaction.create(attemptRef, {
      studentId: uid,
      studentName: String(profile.name || "Student").slice(0, 100),
      phone: String(profile.phone || "").slice(0, 30),
      examYear: String(profile.examYear || "").slice(0, 30),
      date,
      sprintId: sprintDoc.id,
      score,
      totalQuestions: questions.length,
      timeTakenSeconds,
      timeTakenFormatted: `${Math.floor(timeTakenSeconds / 60)}m ${timeTakenSeconds % 60}s`,
      answers: safeAnswers,
      xpEarned,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    transaction.update(userRef, { credits: admin.firestore.FieldValue.increment(xpEarned) });
    if (xpEarned > 0) {
      transaction.create(creditRef, {
        studentId: uid, amount: xpEarned, type: "sprint", sprintId: sprintDoc.id, date,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });
  return { success: true, score, totalQuestions: questions.length, xpEarned };
});

// Keep a minimal, non-sensitive leaderboard projection separate from private
// user profiles so student clients never need to list names, phones, and tokens.
exports.publishLeaderboardProfile = functions.firestore
  .onDocumentWritten("users/{uid}", async (event) => {
    const after = event.data?.after;
    const uid = event.params.uid;
    const publicRef = db.collection("leaderboard_public").doc(uid);
    if (!after?.exists) {
      await publicRef.delete().catch(() => {});
      return;
    }
    const data = after.data();
    if (data.role === "admin" || data.migratedTo) {
      await publicRef.delete().catch(() => {});
      return;
    }
    await publicRef.set({
      name: String(data.name || "Student").slice(0, 100),
      examYear: String(data.examYear || "").slice(0, 30),
      credits: Number.isFinite(Number(data.credits)) ? Number(data.credits) : 0,
      avatarUrl: String(data.avatarUrl || data.photoUrl || "").slice(0, 2048),
      studentId: String(data.studentId || "").slice(0, 30),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

// ── WhatsApp Business API Webhook ─────────────────────────────────
// Configure this URL in Meta Developer Console as webhook for your
// WhatsApp Business phone number.
//
// Webhook URL: https://<REGION>-<PROJECT_ID>.cloudfunctions.net/whatsappWebhook

const WHATSAPP_VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN;
const WHATSAPP_APP_SECRET = process.env.WHATSAPP_APP_SECRET;

exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
  // ── GET: Webhook verification by Meta ─────────────────────────
  if (req.method === "GET") {
    const mode = req.query["hub.mode"];
    const token = req.query["hub.verify_token"];
    const challenge = req.query["hub.challenge"];

    if (WHATSAPP_VERIFY_TOKEN && mode === "subscribe" && token === WHATSAPP_VERIFY_TOKEN) {
      console.log("Webhook verified");
      return res.status(200).send(challenge);
    }
    return res.status(403).send("Forbidden");
  }

  // ── POST: Incoming WhatsApp message ───────────────────────────
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  if (!WHATSAPP_APP_SECRET || !req.rawBody) return res.status(503).send("Webhook signature validation is not configured");
  const signature = req.get("x-hub-signature-256") || "";
  const expected = `sha256=${crypto.createHmac("sha256", WHATSAPP_APP_SECRET).update(req.rawBody).digest("hex")}`;
  const suppliedBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  if (suppliedBuffer.length !== expectedBuffer.length || !crypto.timingSafeEqual(suppliedBuffer, expectedBuffer)) {
    return res.status(401).send("Invalid webhook signature");
  }

  try {
    const body = req.body;
    const entry = body?.entry?.[0];
    const changes = entry?.changes?.[0];
    const value = changes?.value;
    const messages = value?.messages;

    if (!messages || messages.length === 0) {
      return res.status(200).send("OK");
    }

    for (const message of messages) {
      await processMessage(message, value?.contacts?.[0]);
    }

    return res.status(200).send("OK");
  } catch (err) {
    console.error("Webhook error:", err);
    return res.status(200).send("OK"); // Always return 200 to WA
  }
});

async function processMessage(message, contact) {
  const senderPhone = "+" + message.from; // e.g. +14155552671
  const messageId = message.id;
  const timestamp = new Date(parseInt(message.timestamp) * 1000);

  // Find student by phone number
  const usersSnap = await db
    .collection("users")
    .where("phone", "==", senderPhone)
    .where("role", "==", "student")
    .limit(1)
    .get();

  if (usersSnap.empty) {
    console.warn("Unknown sender:", senderPhone);
    // Optionally reply: "Your number is not registered. Please download the Dessert app."
    return;
  }

  const studentDoc = usersSnap.docs[0];
  const student = studentDoc.data();

  // Build the dessert document
  let caption = null;
  let mediaUrls = [];
  let type = "text";

  if (message.type === "text") {
    caption = message.text?.body || "";
    type = "text";
  } else if (message.type === "image") {
    const mediaId = message.image?.id;
    const url = await downloadMediaToStorage(mediaId, "image", student.uid || studentDoc.id);
    mediaUrls = [url];
    caption = message.image?.caption || null;
    type = "image";
  } else if (message.type === "document") {
    const mediaId = message.document?.id;
    const url = await downloadMediaToStorage(mediaId, "document", student.uid || studentDoc.id);
    mediaUrls = [url];
    caption = message.document?.caption || null;
    type = "file";
  } else {
    console.log("Unsupported message type:", message.type);
    return;
  }

  // Create dessert in Firestore
  const dessertRef = db.collection("desserts").doc();
  await dessertRef.set({
    studentId: studentDoc.id,
    studentName: student.name || contact?.profile?.name || "Unknown",
    studentPhone: senderPhone,
    caption,
    mediaUrls,
    type,
    status: "pending",
    creditsAwarded: 0,
    submittedAt: admin.firestore.Timestamp.fromDate(timestamp),
    reviewedAt: null,
    adminFeedback: null,
    reviewedBy: null,
    whatsappMessageId: messageId,
  });

  console.log(`New dessert created: ${dessertRef.id} from ${senderPhone}`);

  // Send FCM notification to all admins
  await notifyAdmins(student.name || "A student", dessertRef.id);
}

async function notifyAdmins(studentName, dessertId) {
  // All admins are subscribed to the "admins" FCM topic
  await admin.messaging().sendToTopic("admins", {
    notification: {
      title: "🍰 New Dessert Submitted!",
      body: `${studentName} just submitted their homework. Tap to review.`,
    },
    data: {
      route: "/admin/review/" + dessertId,
      dessertId,
    },
  });
}

async function downloadMediaToStorage(mediaId, mediaType, studentId) {
  // This requires calling the WhatsApp API to get a temporary URL,
  // then downloading and uploading to Firebase Storage.
  // Implementation depends on your WA token and project.
  //
  // Steps:
  // 1. GET https://graph.facebook.com/v18.0/{mediaId} with WA token → get download URL
  // 2. Download the file
  // 3. Upload to Firebase Storage under desserts/{studentId}/{mediaId}
  // 4. Return the public download URL
  //
  // For now, return a placeholder:
  return `https://placeholder.url/${mediaId}`;
}

// ── Firestore Trigger: On Dessert Reviewed ────────────────────────
exports.onDessertReviewed = functions.firestore
  .onDocumentUpdated("desserts/{dessertId}", async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    // Only act when status changes from pending to something
    if (!before || !after || before.status !== "pending" || after.status === "pending") return;

    const studentId = after.studentId;
    const isApproved = after.status === "approved";

    // Get student profile
    const studentDoc = await db.collection("users").doc(studentId).get();
    if (!studentDoc.exists) return;
    const student = studentDoc.data() || {};

    // Collect all valid FCM registration tokens
    const tokens = new Set();
    if (typeof student.fcmToken === "string" && !student.fcmToken.startsWith("web_token_") && !student.fcmToken.startsWith("{")) {
      tokens.add(student.fcmToken);
    }
    if (Array.isArray(student.fcmTokens)) {
      student.fcmTokens.forEach((t) => {
        if (typeof t === "string" && !t.startsWith("web_token_") && !t.startsWith("{")) {
          tokens.add(t);
        }
      });
    }

    if (tokens.size === 0) {
      console.log(`No registered push token found for student ${studentId}`);
      return;
    }

    const title = isApproved
      ? "🎉 Dessert Approved!"
      : "📝 Dessert Reviewed";
    const body = isApproved
      ? `You earned +${after.creditsAwarded || 0} credits!`
      : "Your teacher left feedback. Tap to view.";

    const messages = Array.from(tokens).map((token) => ({
      token,
      notification: { title, body },
      data: {
        route: "/student/dessert/" + event.params.dessertId,
        dessertId: event.params.dessertId,
        type: "dessert_review",
      },
      webpush: {
        notification: {
          title,
          body,
          icon: "./icons/icon-192.png",
          badge: "./icons/icon-192.png",
          vibrate: [200, 100, 200],
          requireInteraction: true,
        },
        fcmOptions: {
          link: "./index.html",
        },
      },
    }));

    try {
      if (admin.messaging().sendEach) {
        await admin.messaging().sendEach(messages);
      } else {
        await Promise.all(messages.map((m) => admin.messaging().send(m)));
      }
      console.log(`Sent dessert review push notification to ${messages.length} device(s) of student ${studentId}`);
    } catch (err) {
      console.warn("Failed to send review push notification:", err.message);
    }
  });

// ── Firestore Trigger: Auto-Subscribe Student Push Tokens to Topics ──
// Ensures students receive background push notifications even when the web app is closed.
exports.onStudentTokenUpdated = functions.firestore
  .onDocumentWritten("users/{uid}", async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const data = after.data() || {};
    if (data.role && data.role !== "student") return;

    const token = data.fcmToken;
    if (!token || typeof token !== "string" || token.startsWith("web_token_") || token.startsWith("{")) {
      return;
    }

    const before = event.data?.before;
    const prevToken = before?.exists ? before.data()?.fcmToken : null;
    if (token === prevToken) return;

    try {
      await admin.messaging().subscribeToTopic(token, "announcements");
      await admin.messaging().subscribeToTopic(token, "paper_sessions");
      console.log(`Subscribed student ${event.params.uid} push token to topics announcements & paper_sessions`);
    } catch (err) {
      console.warn("Could not subscribe token to topics:", err.message);
    }
  });

// ── Helper: Broadcast FCM push message to student devices & topic ──
async function broadcastPushNotification({
  title,
  body,
  tag,
  url = "./index.html?tab=papers",
  dataPayload = {},
  examYear = "All Batches"
}) {
  const safeData = {
    title: String(title),
    body: String(body),
    url: String(url),
    route: String(url),
    tag: String(tag || `edupeak-${Date.now()}`),
    ...dataPayload
  };

  // 1. Topic multicast (reaches all subscribed devices)
  try {
    await admin.messaging().send({
      topic: "paper_sessions",
      notification: { title, body },
      data: safeData,
      android: {
        priority: "high",
        notification: {
          channelId: "edupeak_high_importance_channel",
          priority: "high",
          sound: "default"
        }
      },
      webpush: {
        notification: {
          title,
          body,
          icon: "./icons/icon-192.png",
          badge: "./icons/icon-192.png",
          vibrate: [300, 100, 300, 100, 300],
          requireInteraction: true,
          tag: safeData.tag
        },
        fcmOptions: {
          link: url
        }
      }
    });
    console.log(`[FCM] Topic broadcast sent: ${title}`);
  } catch (topicErr) {
    console.warn("[FCM] Topic broadcast notice:", topicErr.message);
  }

  // 2. Direct device multicast for guaranteed background delivery
  try {
    let query = db.collection("users").where("role", "==", "student");
    const snap = await query.get();
    const tokens = new Set();

    snap.forEach((docSnap) => {
      const u = docSnap.data() || {};
      const studentYear = String(u.examYear || "");
      if (
        examYear &&
        examYear !== "All" &&
        examYear !== "All Batches" &&
        studentYear &&
        !studentYear.includes(examYear.replace(/\s*A\/L/i, "").trim())
      ) {
        return; // Filter by student batch
      }

      if (typeof u.fcmToken === "string" && !u.fcmToken.startsWith("web_token_") && !u.fcmToken.startsWith("{")) {
        tokens.add(u.fcmToken);
      }
      if (Array.isArray(u.fcmTokens)) {
        u.fcmTokens.forEach((t) => {
          if (typeof t === "string" && !t.startsWith("web_token_") && !t.startsWith("{")) {
            tokens.add(t);
          }
        });
      }
    });

    if (tokens.size > 0) {
      const messages = Array.from(tokens).map((token) => ({
        token,
        notification: { title, body },
        data: safeData,
        android: {
          priority: "high",
          notification: {
            channelId: "edupeak_high_importance_channel",
            priority: "high",
            sound: "default"
          }
        },
        webpush: {
          notification: {
            title,
            body,
            icon: "./icons/icon-192.png",
            badge: "./icons/icon-192.png",
            vibrate: [300, 100, 300, 100, 300],
            requireInteraction: true,
            tag: safeData.tag
          },
          fcmOptions: {
            link: url
          }
        }
      }));

      for (let i = 0; i < messages.length; i += 500) {
        const batch = messages.slice(i, i + 500);
        if (admin.messaging().sendEach) {
          await admin.messaging().sendEach(batch);
        } else {
          await Promise.all(batch.map((m) => admin.messaging().send(m)));
        }
      }
      console.log(`[FCM] Direct push delivered to ${tokens.size} student device(s)`);
    }
  } catch (directErr) {
    console.warn("[FCM] Direct device multicast notice:", directErr.message);
  }
}

// ── Firestore Trigger: On Paper Session Created or Updated ────────
// Sends push notifications even when the webapp / browser tab is completely closed.
exports.onPaperSessionWritten = functions.firestore
  .onDocumentWritten("paper_sessions/{paperId}", async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const paperId = event.params.paperId;

    if (!after) return; // Document deleted
    if (after.notifyStudents === false) return;

    const title = after.title || "Physics Examination Paper";
    const examYear = after.examYear || "All Batches";

    const isNewlyCreated = !before;
    const wasLive = before && (before.isLive || before.status === "active" || before.currentPhase === "package_opening" || before.currentPhase === "writing");
    const isNowLive = after.isLive || after.status === "active" || after.currentPhase === "package_opening" || after.currentPhase === "writing";
    const justWentLive = !wasLive && isNowLive;

    const wasTimeUp = before && (before.isTimeUp || before.currentPhase === "time_up");
    const isNowTimeUp = after.isTimeUp || after.currentPhase === "time_up";
    const justTimeUp = !wasTimeUp && isNowTimeUp;

    if (justWentLive) {
      if (after.notifyOnStart === false) return;
      await broadcastPushNotification({
        title: "🔴 Live Exam Started!",
        body: `"${title}" (${examYear}) is now LIVE! Tap to enter exam room.`,
        tag: `live-exam-${paperId}`,
        url: "./index.html?tab=papers",
        dataPayload: { paperId, type: "live_exam", examYear },
        examYear
      });
    } else if (justTimeUp) {
      await broadcastPushNotification({
        title: "⏰ Exam Time Is Up!",
        body: `Writing time has ended for "${title}". Scan & submit your answer sheets now!`,
        tag: `timeup-exam-${paperId}`,
        url: "./index.html?tab=papers",
        dataPayload: { paperId, type: "time_up", examYear },
        examYear
      });
    } else if (isNewlyCreated || (before.status !== "scheduled" && after.status === "scheduled")) {
      await broadcastPushNotification({
        title: "📅 New Paper Session Scheduled!",
        body: `"${title}" (${examYear}) is scheduled. Tap to register your exam slot!`,
        tag: `paper-scheduled-${paperId}`,
        url: "./index.html?tab=papers",
        dataPayload: { paperId, type: "paper_scheduled", examYear },
        examYear
      });
    }
  });

// ── Firestore Trigger: On Paper Hint Published ────────────────────
exports.onPaperHintWritten = functions.firestore
  .onDocumentWritten("paper_hints/{hintId}", async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;
    if (after.notifyStudents === false) return;
    if (before && before.title === after.title) return; // Prevent duplicate notifications on minor edits

    const title = after.title || after.paperName || "Model Paper";
    const examYear = after.examYear || "All Batches";

    await broadcastPushNotification({
      title: "💡 New Paper Hint & Scope Published!",
      body: `Exclusive formulas & guidance published for "${title}" (${examYear}). Review now!`,
      tag: `paper-hint-${event.params.hintId}`,
      url: "./index.html?tab=papers",
      dataPayload: { hintId: event.params.hintId, type: "paper_hint", examYear },
      examYear
    });
  });

// ── Firestore Trigger: On Paper Leaderboard Published ─────────────
exports.onPaperLeaderboardWritten = functions.firestore
  .onDocumentWritten("paper_leaderboards/{boardId}", async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after || before) return; // Only notify on initial publish
    if (after.notifyStudents === false) return;

    const title = after.paperTitle || after.title || "Physics Paper";
    const examYear = after.examYear || "All Batches";

    await broadcastPushNotification({
      title: "🏆 Leaderboard Published!",
      body: `Rankings & marks for "${title}" (${examYear}) are now available. Tap to check your rank!`,
      tag: `leaderboard-${event.params.boardId}`,
      url: "./index.html?tab=ranks",
      dataPayload: { boardId: event.params.boardId, type: "leaderboard", examYear },
      examYear
    });
  });

// ── Firestore Trigger: On Invigilator / Proctor Alert ─────────────
exports.onProctorAlertCreated = functions.firestore
  .onDocumentCreated("proctor_alerts/{alertId}", async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const studentId = data.studentId;
    if (!studentId || studentId === "all") return; // Targeted alerts only

    const userSnap = await db.collection("users").doc(studentId).get();
    if (!userSnap.exists) return;
    const user = userSnap.data() || {};

    const tokens = new Set();
    if (typeof user.fcmToken === "string" && !user.fcmToken.startsWith("web_token_") && !user.fcmToken.startsWith("{")) {
      tokens.add(user.fcmToken);
    }
    if (Array.isArray(user.fcmTokens)) {
      user.fcmTokens.forEach((t) => {
        if (typeof t === "string" && !t.startsWith("web_token_") && !t.startsWith("{")) {
          tokens.add(t);
        }
      });
    }

    if (tokens.size === 0) return;

    const title = "⚠️ Invigilator Proctor Alert";
    const body = data.message || "Please check your exam camera and desk area.";

    const messages = Array.from(tokens).map((token) => ({
      token,
      notification: { title, body },
      data: {
        route: "./index.html?tab=papers",
        type: "proctor_alert",
        alertId: event.params.alertId
      },
      webpush: {
        notification: {
          title,
          body,
          icon: "./icons/icon-192.png",
          badge: "./icons/icon-192.png",
          vibrate: [400, 150, 400],
          requireInteraction: true,
          tag: `proctor-alert-${event.params.alertId}`
        },
        fcmOptions: {
          link: "./index.html?tab=papers"
        }
      }
    }));

    try {
      if (admin.messaging().sendEach) {
        await admin.messaging().sendEach(messages);
      } else {
        await Promise.all(messages.map((m) => admin.messaging().send(m)));
      }
    } catch (err) {
      console.warn("Proctor alert direct push error:", err.message);
    }
  });


