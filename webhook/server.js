const express = require('express');
const admin = require('firebase-admin');
const axios = require('axios');
const path = require('path');

const fs = require('fs');

// ── Initialize Firebase Admin ────────────────────────────────────────────────
let credential;
if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
  try {
    const jsonStr = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64.trim(), 'base64').toString('utf8');
    const sa = JSON.parse(jsonStr);
    credential = admin.credential.cert(sa);
  } catch (e) {
    console.error('Error parsing FIREBASE_SERVICE_ACCOUNT_BASE64:', e);
  }
}

if (!credential && process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    const sa = typeof process.env.FIREBASE_SERVICE_ACCOUNT === 'string'
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
      : process.env.FIREBASE_SERVICE_ACCOUNT;
    if (sa.private_key) {
      sa.private_key = sa.private_key.replace(/\\n/g, '\n');
    }
    credential = admin.credential.cert(sa);
  } catch (e) {
    console.error('Error parsing FIREBASE_SERVICE_ACCOUNT env var:', e);
  }
}

if (!credential && fs.existsSync(path.join(__dirname, 'serviceAccountKey.json'))) {
  const serviceAccount = require('./serviceAccountKey.json');
  credential = admin.credential.cert(serviceAccount);
}

if (!credential) {
  credential = admin.credential.applicationDefault();
}

admin.initializeApp({
  credential,
  storageBucket: 'dessert-institute.firebasestorage.app',
});

const db = admin.firestore();
const app = express();
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Serve static frontend demo
app.use(express.static(path.join(__dirname, '../demo')));

// ── Live Firestore API Endpoints for Web App ─────────────────────────────────
app.get('/api/users', async (req, res) => {
  try {
    const snap = await db.collection('users').get();
    const users = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json(users);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/desserts', async (req, res) => {
  try {
    const snap = await db.collection('desserts').orderBy('submittedAt', 'desc').get();
    const desserts = snap.docs.map(d => {
      const data = d.data();
      return {
        id: d.id,
        ...data,
        submittedAt: data.submittedAt ? data.submittedAt.toMillis() : Date.now(),
        reviewedAt: data.reviewedAt ? data.reviewedAt.toMillis() : null,
      };
    });
    res.json(desserts);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/review', async (req, res) => {
  try {
    const { id, approve, credits, feedback } = req.body;
    const dessertRef = db.collection('desserts').doc(id);
    const dessertDoc = await dessertRef.get();
    if (!dessertDoc.exists) return res.status(404).json({ error: 'Not found' });

    const dessert = dessertDoc.data();
    const newStatus = approve ? 'approved' : 'rejected';
    const creditsAwarded = approve ? parseInt(credits || 10) : 0;

    await dessertRef.update({
      status: newStatus,
      creditsAwarded: creditsAwarded,
      adminFeedback: feedback || (approve ? 'Great work! ✅' : 'Needs improvement. ❌'),
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (approve && dessert.studentId) {
      await db.collection('users').doc(dessert.studentId).update({
        credits: admin.firestore.FieldValue.increment(creditsAwarded),
      });
    }

    // Send WhatsApp notification to student about the review result!
    if (dessert.studentPhone) {
      const resultText = approve
        ? `🎉 *Dessert Approved!*\n\nYour homework has been reviewed and marked as correct! ✅\n\n⭐ *+${creditsAwarded} Credits* added to your score!\nTeacher Feedback: "${feedback || 'Great work!'}"`
        : `❌ *Dessert Needs Improvement*\n\nYour teacher reviewed your homework.\nFeedback: "${feedback || 'Please try again'}"`;
      
      const cleanPhone = dessert.studentPhone.replace(/\+/g, '').replace(/\s+/g, '');
      await sendWhatsAppReply(cleanPhone, resultText);
    }

    res.json({ success: true, status: newStatus, creditsAwarded });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/user/photo', async (req, res) => {
  try {
    const { userId, photoUrl, name } = req.body;
    if (!photoUrl) return res.status(400).json({ error: 'Missing photoUrl' });

    let updated = false;
    if (userId) {
      const docRef = db.collection('users').doc(userId);
      const doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({ photoUrl });
        updated = true;
      }
    }

    if (!updated && name) {
      const q = await db.collection('users').where('name', '==', name).get();
      if (!q.empty) {
        await q.docs[0].ref.update({ photoUrl });
        updated = true;
      }
    }

    if (!updated) {
      const all = await db.collection('users').get();
      for (const doc of all.docs) {
        if (doc.data().name?.includes('ThiZaru') || doc.id === userId) {
          await doc.ref.update({ photoUrl });
        }
      }
    }

    console.log(`📸 Updated DP photo in Firestore for ${name || userId}`);
    res.json({ success: true });
  } catch (e) {
    console.error('Error saving user photo:', e);
    res.status(500).json({ error: e.message });
  }
});

// ── Meta WhatsApp Config ────────────────────────────────────────────────────
const VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN || 'dessert_secret_2026';
const ACCESS_TOKEN = process.env.WHATSAPP_ACCESS_TOKEN || 'EAAPB4Ug7ZABgBSVyqonxSGZC3ZBZAZAozq1RwMt4OSZA3MTuHD2jhtWDjAnrQnGQUz7Kn7VZBXUY7ZAw4pDxFuT3szkZCZArPQ326XYu80ejMzaYfCzTNuyKblZCJrXfB66T9lbhgZBCAQgZCOuZBSq1bVaX3QnJIMynANC1ZAmpG60PD0re9tZBz0OVBlu8prPPZB2unUAZDZD';
const PHONE_NUMBER_ID = process.env.WHATSAPP_PHONE_NUMBER_ID || '1259475067252677';

// ── Health Check ─────────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.send(`
    <div style="font-family:sans-serif;text-align:center;padding:40px;background:#0D0F1A;color:#fff;min-height:100vh;">
      <h1 style="color:#6C63FF;font-size:36px;">🍰 Dessert Webhook Server is LIVE!</h1>
      <p style="color:#9B9EC8;font-size:16px;">Connected to Firebase Project: <b>dessert-institute</b></p>
      <div style="margin-top:30px;background:#1E2138;display:inline-block;padding:20px 30px;border-radius:12px;border:1px solid #2E3154;text-align:left;">
        <p><b>Webhook Endpoint:</b> <code>/whatsappWebhook</code></p>
        <p><b>Verify Token:</b> <code>dessert_secret_2026</code></p>
        <p><b>Status:</b> 🟢 Ready to receive WhatsApp homework</p>
      </div>
    </div>
  `);
});

// ── Meta Webhook Verification (GET) ──────────────────────────────────────────
app.get('/whatsappWebhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  console.log(`[Webhook Verification] mode=${mode}, token=${token}`);

  if (mode === 'subscribe' && token === VERIFY_TOKEN) {
    console.log('✅ Webhook verified successfully with Meta!');
    return res.status(200).send(challenge);
  }
  console.error('❌ Verification failed. Token mismatch.');
  return res.status(403).send('Forbidden');
});

// ── Incoming WhatsApp Messages (POST) ────────────────────────────────────────
app.post('/whatsappWebhook', async (req, res) => {
  try {
    const body = req.body;
    console.log('[Incoming Webhook Event]:', JSON.stringify(body, null, 2));

    const entry = body?.entry?.[0];
    const changes = entry?.changes?.[0];
    const value = changes?.value;
    const messages = value?.messages;

    if (!messages || messages.length === 0) {
      return res.status(200).send('EVENT_RECEIVED');
    }

    for (const message of messages) {
      await handleMessage(message, value?.contacts?.[0]);
    }

    return res.status(200).send('EVENT_RECEIVED');
  } catch (err) {
    console.error('Error handling webhook POST:', err);
    return res.status(200).send('EVENT_RECEIVED'); // Always return 200 to Meta
  }
});

async function handleMessage(message, contact) {
  const rawSender = message.from; // e.g. "919876543210" or "15556780059"
  const senderPhone = rawSender.startsWith('+') ? rawSender : '+' + rawSender;
  const senderName = contact?.profile?.name || 'Student (' + senderPhone + ')';
  const msgType = message.type; // 'text', 'image', 'document'
  
  let caption = '';
  let mediaUrls = [];

  if (msgType === 'text') {
    caption = message.text?.body || '';
  } else if (msgType === 'image') {
    caption = message.image?.caption || 'Photo homework submission';
    const mediaId = message.image?.id;
    if (mediaId && ACCESS_TOKEN) {
      try {
        console.log(`🖼️ Fetching photo media URL from Meta for ID: ${mediaId}...`);
        const mRes = await axios.get(`https://graph.facebook.com/v19.0/${mediaId}`, {
          headers: { Authorization: `Bearer ${ACCESS_TOKEN}` }
        });
        if (mRes.data?.url) {
          console.log(`⬇️ Downloading image binary from Meta...`);
          const imgRes = await axios.get(mRes.data.url, {
            headers: { Authorization: `Bearer ${ACCESS_TOKEN}` },
            responseType: 'arraybuffer'
          });
          const base64 = Buffer.from(imgRes.data).toString('base64');
          const mimeType = mRes.data.mime_type || 'image/jpeg';
          const dataUrl = `data:${mimeType};base64,${base64}`;
          mediaUrls.push(dataUrl);
          console.log(`✅ Photo downloaded and attached successfully!`);
        }
      } catch (err) {
        console.error('Error downloading image from Meta:', err.response?.data || err.message);
      }
    }
  } else if (msgType === 'document') {
    caption = message.document?.filename ? `Document: ${message.document.filename}` : 'Document submission';
  } else {
    caption = `Unsupported message type: ${msgType}`;
  }

  console.log(`📥 Received submission from ${senderName} (${senderPhone}): "${caption}"`);

  // 1. Find or create student in Firestore
  let studentId = null;
  const usersSnap = await db.collection('users')
    .where('phone', '==', senderPhone)
    .limit(1)
    .get();

  if (!usersSnap.empty) {
    studentId = usersSnap.docs[0].id;
  } else {
    // Check without '+' or formatted
    const cleanPhone = senderPhone.replace(/\s+/g, '');
    const altSnap = await db.collection('users')
      .where('phone', '==', cleanPhone)
      .limit(1)
      .get();

    if (!altSnap.empty) {
      studentId = altSnap.docs[0].id;
    } else {
      // Auto-create student profile
      const newRef = db.collection('users').doc();
      studentId = newRef.id;
      await newRef.set({
        id: studentId,
        name: senderName,
        phone: senderPhone,
        role: 'student',
        credits: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`👤 Created new student profile: ${senderName} (ID: ${studentId})`);
    }
  }

  // 2. Save Dessert submission to Firestore
  const dessertRef = db.collection('desserts').doc();
  const dessertData = {
    id: dessertRef.id,
    studentId: studentId,
    studentName: senderName,
    studentPhone: senderPhone,
    type: msgType === 'image' ? 'image' : msgType === 'document' ? 'file' : 'text',
    caption: caption,
    mediaUrls: mediaUrls,
    status: 'pending',
    creditsAwarded: 0,
    adminFeedback: null,
    whatsappMessageId: message.id,
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedAt: null,
  };

  await dessertRef.set(dessertData);
  console.log(`🍰 Dessert saved to Firestore with ID: ${dessertRef.id}`);

  // 3. Send automated WhatsApp confirmation reply to student
  await sendWhatsAppReply(
    rawSender,
    `🍰 *Dessert Received!*\n\nHi ${senderName}, your homework has been received and sent to your teachers for review.\n\nYou will earn credits once approved! ⭐`
  );
}

async function sendWhatsAppReply(to, text) {
  try {
    if (!ACCESS_TOKEN || ACCESS_TOKEN === 'CHANGE_ME') {
      console.log('No WhatsApp access token configured. Skipping reply.');
      return;
    }

    const url = `https://graph.facebook.com/v19.0/${PHONE_NUMBER_ID}/messages`;
    await axios.post(
      url,
      {
        messaging_product: 'whatsapp',
        to: to,
        type: 'text',
        text: { body: text },
      },
      {
        headers: {
          Authorization: `Bearer ${ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
      }
    );
    console.log(`📤 Automated WhatsApp reply sent to ${to}`);
  } catch (err) {
    console.error('Error sending WhatsApp confirmation reply:', err.response?.data || err.message);
  }
}

// ── Real-Time WhatsApp OTP Listener ───────────────────────────────────────────
db.collection('otp_requests').onSnapshot(snapshot => {
  snapshot.docChanges().forEach(async change => {
    if (change.type === 'added') {
      const data = change.doc.data();
      const phone = data.phone;
      const name = data.name || 'Student';
      const docId = change.doc.id;

      if (!phone) return;

      // Generate 6-digit random code
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const cleanPhone = phone.replace(/\+/g, '').replace(/\s+/g, '');

      // Store in otp_verifications collection
      await db.collection('otp_verifications').doc(phone).set({
        phone: phone,
        otp: otp,
        name: name,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: Date.now() + 5 * 60 * 1000, // 5 minutes
      });

      // Send via WhatsApp Meta Cloud API
      await sendWhatsAppReply(
        cleanPhone,
        `🍰 *Dessert Institute Verification*\n\nHello ${name}! 👋\n\nYour 6-digit login code is:\n\n👉 *${otp}*\n\n⏱️ This code is valid for 5 minutes.\n🔒 Do not share this code with anyone.`
      );

      console.log(`📲 WhatsApp OTP [${otp}] sent to ${phone} (${name})`);

      // Delete the request document
      await db.collection('otp_requests').doc(docId).delete();
    }
  });
});

// ── Start Server ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Webhook server running on http://localhost:${PORT}`);
  console.log(`🔗 Webhook endpoint: http://localhost:${PORT}/whatsappWebhook`);
  console.log(`📲 WhatsApp OTP delivery listener: ACTIVE 🟢`);
});
