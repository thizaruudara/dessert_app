const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ── WhatsApp Business API Webhook ─────────────────────────────────
// Configure this URL in Meta Developer Console as webhook for your
// WhatsApp Business phone number.
//
// Webhook URL: https://<REGION>-<PROJECT_ID>.cloudfunctions.net/whatsappWebhook

const WHATSAPP_VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN || "CHANGE_ME";

exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
  // ── GET: Webhook verification by Meta ─────────────────────────
  if (req.method === "GET") {
    const mode = req.query["hub.mode"];
    const token = req.query["hub.verify_token"];
    const challenge = req.query["hub.challenge"];

    if (mode === "subscribe" && token === WHATSAPP_VERIFY_TOKEN) {
      console.log("Webhook verified");
      return res.status(200).send(challenge);
    }
    return res.status(403).send("Forbidden");
  }

  // ── POST: Incoming WhatsApp message ───────────────────────────
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

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
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only act when status changes from pending to something
    if (before.status !== "pending" || after.status === "pending") return;

    const studentId = after.studentId;
    const isApproved = after.status === "approved";

    // Get student FCM token
    const studentDoc = await db.collection("users").doc(studentId).get();
    if (!studentDoc.exists) return;
    const student = studentDoc.data();
    if (!student.fcmToken) return;

    const title = isApproved
      ? "🎉 Dessert Approved!"
      : "📝 Dessert Reviewed";
    const body = isApproved
      ? `You earned +${after.creditsAwarded} credits!`
      : "Your teacher left feedback. Tap to view.";

    await admin.messaging().send({
      token: student.fcmToken,
      notification: { title, body },
      data: {
        route: "/student/dessert/" + event.params.dessertId,
      },
    });
  });
