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

// ── Meta WhatsApp & Gemini Config ───────────────────────────────────────────
const VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN || 'dessert_secret_2026';
const ACCESS_TOKEN = process.env.WHATSAPP_ACCESS_TOKEN || 'EAAPB4Ug7ZABgBScDWq0kZCAQSRItrKyZAHqA6RWghMiiRdeGWiAvtQCsYlo3sG1xKtH7BeQAymfrzPWiTIlfyPe8NVSUtg4r4kojIPg2aZBQQQljZBFZAqtwBr3URuwL3SqtyNN7j8zIzbgHC5sDeShKvmWptlxYdPRCf3KN5kbOJSee43qNvB2DMZChjdirQZDZD';
const PHONE_NUMBER_ID = process.env.WHATSAPP_PHONE_NUMBER_ID || '1259475067252677';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';

// ── Direct HTTP OTP Dispatch Endpoint ─────────────────────────────────────────
app.post('/api/send-otp', async (req, res) => {
  try {
    const { phone, name } = req.body;
    if (!phone) return res.status(400).json({ error: 'Phone required' });

    const studentName = name || 'Student';
    const randomOtp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

    await db.collection('otp_verifications').doc(phone).set({
      otp: randomOtp,
      phone: phone,
      name: studentName,
      expiresAt: expiresAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const targetWaNumber = phone.replace(/\D/g, '');
    await sendWhatsAppOtp(targetWaNumber, randomOtp, studentName);
    console.log(`📲 Direct API: WhatsApp OTP [${randomOtp}] dispatched to ${phone} (${studentName})`);

    return res.status(200).json({ success: true, message: 'OTP sent successfully' });
  } catch (err) {
    console.error('Error in /api/send-otp:', err);
    return res.status(500).json({ error: err.message });
  }
});

// ── Health Check ─────────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.send(`
    <div style="font-family:sans-serif;text-align:center;padding:40px;background:#0D0F1A;color:#fff;min-height:100vh;">
      <h1 style="color:#6C63FF;font-size:36px;">🍰 EduPeak AI Webhook Server is LIVE!</h1>
      <p style="color:#9B9EC8;font-size:16px;">Dual-Engine: <b>A/L Academic Tutor (Gemini AI)</b> + <b>Multi-Photo Dessert Submissions</b></p>
      <div style="margin-top:30px;background:#1E2138;display:inline-block;padding:20px 30px;border-radius:12px;border:1px solid #2E3154;text-align:left;">
        <p><b>Webhook Endpoint:</b> <code>/whatsappWebhook</code></p>
        <p><b>Direct OTP Endpoint:</b> <code>/api/send-otp</code></p>
        <p><b>Verify Token:</b> <code>dessert_secret_2026</code></p>
        <p><b>AI Model:</b> <code>Gemini 3.6 Flash with Firestore Multi-Turn Memory</code></p>
        <p><b>Multi-Photo Batching:</b> 🟢 Active</p>
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
    return res.status(200).send('EVENT_RECEIVED');
  }
});

// ── Multi-Photo Album Batch Buffer ─────────────────────────────────────────
// WhatsApp sends each photo in an album as a separate webhook event.
// We buffer photos for 3.5 seconds to combine them into 1 SINGLE dessert submission in Firestore & Admin!
const pendingPhotoBatches = new Map();

function handlePhotoSubmission(studentId, studentName, senderPhone, rawSender, mediaUrl, caption, messageId, userRef) {
  let batch = pendingPhotoBatches.get(senderPhone);

  if (batch) {
    if (batch.timer) clearTimeout(batch.timer);
    if (mediaUrl) batch.mediaUrls.push(mediaUrl);
    if (caption && caption !== 'Photo dessert homework' && !batch.captions.includes(caption)) {
      batch.captions.push(caption);
    }
    if (messageId) batch.messageIds.push(messageId);
  } else {
    batch = {
      studentId,
      studentName,
      senderPhone,
      rawSender,
      userRef,
      mediaUrls: mediaUrl ? [mediaUrl] : [],
      captions: caption && caption !== 'Photo dessert homework' ? [caption] : [],
      messageIds: messageId ? [messageId] : [],
      timer: null,
    };
    pendingPhotoBatches.set(senderPhone, batch);
  }

  // Set debounce timer: wait 3.5 seconds for any remaining photos sent in the same batch
  batch.timer = setTimeout(async () => {
    try {
      pendingPhotoBatches.delete(senderPhone);
      const finalMediaUrls = batch.mediaUrls;
      const finalCaption = batch.captions.length > 0 ? batch.captions.join(' | ') : 'Dessert homework submission';
      const photoCount = finalMediaUrls.length;

      // 1. Save 1 SINGLE Dessert Document to Firestore with all photos
      const dessertRef = db.collection('desserts').doc();
      const dessertData = {
        id: dessertRef.id,
        studentId: batch.studentId,
        studentName: batch.studentName,
        studentPhone: batch.senderPhone,
        type: 'image',
        caption: finalCaption,
        mediaUrls: finalMediaUrls,
        status: 'pending',
        creditsAwarded: 0,
        adminFeedback: null,
        whatsappMessageId: batch.messageIds.join(','),
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedAt: null,
      };

      await dessertRef.set(dessertData);
      if (batch.userRef) {
        await batch.userRef.update({ awaitingDessert: false });
      }
      console.log(`🍰 Multi-photo dessert saved to Firestore! ID: ${dessertRef.id} (${photoCount} photos) for ${batch.studentName}`);

      // 2. Send 1 SINGLE WhatsApp confirmation reply
      const countText = photoCount > 1 ? ` (${photoCount} Photos Attached)` : '';
      await sendInteractiveButtons(
        batch.rawSender,
        `🍰 *Dessert Received!*${countText}\n\nHi ${batch.studentName}, your homework with *${photoCount}* ${photoCount === 1 ? 'photo' : 'photos'} has been received and added to your *EduPeak Student Portal*.\n\nYour teachers will review all photos together and award credits soon! ⭐`,
        [
          { id: 'btn_check_credits', title: '⭐ Check Credits' },
          { id: 'btn_ask_tutor', title: '📚 Ask A/L Tutor' },
        ]
      );
    } catch (e) {
      console.error('Error saving multi-photo dessert submission:', e);
    }
  }, 3500);
}

// ── Conversational AI + A/L Tutor + Homework Handler ─────────────────────────
async function handleMessage(message, contact) {
  const rawSender = message.from; // e.g. "94770557769"
  const senderPhone = rawSender.startsWith('+') ? rawSender : '+' + rawSender;
  const cleanPhone = senderPhone.replace(/\s+/g, '');
  const waProfileName = contact?.profile?.name || '';
  const msgType = message.type; // 'text', 'image', 'document', 'interactive'

  // Extract button reply ID if user clicked an interactive button
  const buttonReplyId = message.interactive?.button_reply?.id;
  const buttonReplyTitle = message.interactive?.button_reply?.title;

  let textBody = '';
  if (msgType === 'text') {
    textBody = message.text?.body?.trim() || '';
  } else if (msgType === 'interactive') {
    textBody = buttonReplyTitle || '';
  }

  console.log(`📥 Received from ${senderPhone} (${waProfileName}): Type=${msgType}, Text="${textBody}", Button="${buttonReplyId}"`);

  // 1. Fetch User Record from Firestore
  let userDoc = null;
  let userRef = null;

  const q1 = await db.collection('users').where('phone', '==', senderPhone).limit(1).get();
  if (!q1.empty) {
    userDoc = q1.docs[0];
    userRef = userDoc.ref;
  } else {
    const q2 = await db.collection('users').where('phone', '==', cleanPhone).limit(1).get();
    if (!q2.empty) {
      userDoc = q2.docs[0];
      userRef = userDoc.ref;
    }
  }

  const userData = userDoc ? userDoc.data() : null;
  const hasRealName = userData?.name && !userData.name.startsWith('Student (') && userData.name !== 'Student';

  // ── Flow 1: First-Time Student (Ask & Register Full Name) ────────────────────
  if (!userData || !hasRealName || userData.awaitingName) {
    if (!userData) {
      // First time student: Create draft user profile and ask for name
      const newRef = db.collection('users').doc();
      await newRef.set({
        id: newRef.id,
        name: waProfileName || '',
        phone: senderPhone,
        role: 'student',
        credits: 0,
        awaitingName: true,
        awaitingDessert: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await sendWhatsAppText(
        rawSender,
        `👋 *Welcome to EduPeak Institute!* 🎓🍰\n\nPlease reply with your *Full Name* to activate your student account:`
      );
      return;
    }

    if (userData.awaitingName) {
      let extractedName = textBody;
      extractedName = extractedName
        .replace(/^(my name is|i am|this is|i'm|name is)\s+/i, '')
        .replace(/[\uE000-\uF8FF\uFFFD\u0000-\u001F\u007F-\u009F]/g, '')
        .trim();
      if (!extractedName || extractedName.length < 2) {
        extractedName = (waProfileName || 'Student').replace(/[\uE000-\uF8FF\uFFFD\u0000-\u001F\u007F-\u009F]/g, '').trim();
      }

      await userRef.update({
        name: extractedName,
        awaitingName: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`👤 Student name registered: ${extractedName} (${senderPhone})`);

      await sendInteractiveButtons(
        rawSender,
        `🎉 Nice to meet you, *${extractedName}*!\n\nYour EduPeak account is now active. I am your 24/7 AI Assistant & A/L Tutor! 🧠\n\nHow can I help you today?`,
        [
          { id: 'btn_submit_yes', title: '🍰 Submit Dessert' },
          { id: 'btn_ask_tutor', title: '📚 Ask A/L Question' },
          { id: 'btn_check_credits', title: '⭐ My Credits' },
        ]
      );
      return;
    }
  }

  const studentName = userData.name || waProfileName || 'Student';
  const studentId = userDoc.id;

  // ── Flow 1.5: Instant OTP Request on WhatsApp ───────────────────────────────
  if (textBody.toLowerCase().includes('otp') || textBody.toLowerCase().includes('login') || textBody.toLowerCase().includes('code')) {
    const randomOtp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000;

    await db.collection('otp_verifications').doc(senderPhone).set({
      otp: randomOtp,
      phone: senderPhone,
      name: studentName,
      expiresAt: expiresAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await sendWhatsAppText(
      rawSender,
      `🍰 *EduPeak Verification Code*\n\nHello ${studentName}! 👋\n\nYour 6-digit login code is:\n\n👉 *${randomOtp}*\n\n⏱️ This code is valid for 10 minutes.\nEnter this code in the EduPeak App to log in!`
    );
    console.log(`📲 Chat-Initiated OTP [${randomOtp}] sent to ${senderPhone}`);
    return;
  }

  // ── Flow 2: Interactive Button Click Handlers ──────────────────────────────
  if (buttonReplyId === 'btn_submit_yes' || textBody.toLowerCase() === 'submit dessert') {
    await userRef.update({ awaitingDessert: true });
    await sendWhatsAppText(
      rawSender,
      `📸 *Dessert Homework Submission*\n\nPlease send your dessert photos (you can send multiple photos at once!) with a short description or recipe note.\n\nThey will be uploaded together to your *EduPeak Student Portal* for teacher grading! 🍰`
    );
    return;
  }

  if (buttonReplyId === 'btn_ask_tutor') {
    await userRef.update({ awaitingDessert: false });
    await sendWhatsAppText(
      rawSender,
      `📚 *EduPeak A/L AI Tutor*\n\nHi ${studentName}! Ask me any question related to your Sri Lankan G.C.E. A/L Syllabus (Maths, Physics, Chemistry, Biology, ICT, Accounting, Economics, etc.).\n\nYou can ask in English, Sinhala (සිංහල), or Singlish!`
    );
    return;
  }

  if (buttonReplyId === 'btn_check_credits' || textBody.toLowerCase().includes('credit')) {
    const credits = userData.credits || 0;
    const dSnap = await db.collection('desserts').where('studentPhone', '==', senderPhone).get();
    const totalSubmissions = dSnap.size;
    const approved = dSnap.docs.filter(d => d.data().status === 'approved').length;

    await sendInteractiveButtons(
      rawSender,
      `⭐ *EduPeak Student Report*\n\n👤 *Student:* ${studentName}\n📞 *Phone:* ${senderPhone}\n⭐ *Credits Earned:* ${credits} pts\n🍰 *Total Submissions:* ${totalSubmissions}\n✅ *Approved:* ${approved}\n\nKeep up the great work! 🧁`,
      [
        { id: 'btn_submit_yes', title: '🍰 Submit Dessert' },
        { id: 'btn_ask_tutor', title: '📚 Ask A/L Tutor' },
      ]
    );
    return;
  }

  if (buttonReplyId === 'btn_later') {
    await userRef.update({ awaitingDessert: false });
    await sendWhatsAppText(
      rawSender,
      `👍 No problem, *${studentName}*! Message anytime with your A/L questions or when your dessert is ready. 🎓🍰`
    );
    return;
  }

  // ── Flow 3: Photo / Dessert Submission (Handles Single & Multiple Photos) ───
  if (msgType === 'image') {
    const caption = message.image?.caption || 'Photo dessert homework';
    const mediaId = message.image?.id;
    let dataUrl = null;

    if (mediaId && ACCESS_TOKEN) {
      try {
        console.log(`🖼️ Fetching photo binary from Meta for ID: ${mediaId}...`);
        const mRes = await axios.get(`https://graph.facebook.com/v19.0/${mediaId}`, {
          headers: { Authorization: `Bearer ${ACCESS_TOKEN}` }
        });
        if (mRes.data?.url) {
          const imgRes = await axios.get(mRes.data.url, {
            headers: { Authorization: `Bearer ${ACCESS_TOKEN}` },
            responseType: 'arraybuffer'
          });
          const base64 = Buffer.from(imgRes.data).toString('base64');
          const mimeType = mRes.data.mime_type || 'image/jpeg';
          dataUrl = `data:${mimeType};base64,${base64}`;
          console.log(`✅ Photo downloaded successfully (${(base64.length / 1024).toFixed(1)} KB)`);
        }
      } catch (err) {
        console.error('Error downloading image from Meta:', err.response?.data || err.message);
      }
    }

    // Queue into intelligent multi-photo batch buffer
    handlePhotoSubmission(
      studentId,
      studentName,
      senderPhone,
      rawSender,
      dataUrl,
      caption,
      message.id,
      userRef
    );
    return;
  }

  // ── Flow 4: Gemini AI A/L Academic Tutor with Multi-Turn Memory ──────────────
  if (textBody) {
    try {
      // 1. Fetch recent conversation history from Firestore for memory
      const historySnap = await db.collection('users')
        .doc(studentId)
        .collection('chat_history')
        .orderBy('timestamp', 'desc')
        .limit(6)
        .get();

      const historyDocs = historySnap.docs.reverse();
      const contents = [];

      // Add conversation history
      for (const doc of historyDocs) {
        const d = doc.data();
        if (d.role === 'user' || d.role === 'model') {
          contents.push({
            role: d.role,
            parts: [{ text: d.text }]
          });
        }
      }

      // Add current user turn
      contents.push({
        role: 'user',
        parts: [{ text: textBody }]
      });

      const systemPrompt = `You are "EduPeak AI" - the smart 24/7 academic tutor and virtual assistant for EduPeak Institute in Sri Lanka.
Student Name: ${studentName}.
Role:
1. Answer questions clearly about the Sri Lankan G.C.E. Advanced Level (A/L) syllabus across Science, Maths, Commerce, Tech, and Arts streams (Physics, Chemistry, Combined Maths, Biology, ICT, Accounting, Economics, Business Studies, etc.).
2. You can also answer questions about pastry, dessert culinary arts, or institute details.
3. If the student wants to submit homework, remind them they can send photos of their dessert creation here anytime (they can send multiple photos in one go!).
4. Respond in the same language the student asks in (English, Sinhala සිංහල, Singlish, or Tamil தமிழ்).
5. Format your answers clearly using WhatsApp markdown (*bold*, bullet points, numbered steps, simple formulas). Keep explanations concise and easy to understand for a student.`;

      // Call Gemini 3.6 Flash
      const geminiApiKey = GEMINI_API_KEY || process.env.GEMINI_API_KEY;
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${geminiApiKey}`;
      const gRes = await axios.post(geminiUrl, {
        contents: contents,
        systemInstruction: {
          parts: [{ text: systemPrompt }]
        }
      });

      let aiReply = gRes.data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || `Hi ${studentName}! How can I help you with your studies or dessert homework today? 🍰`;
      aiReply = formatForWhatsApp(aiReply);

      // Save user question and AI reply to Firestore memory
      const historyRef = db.collection('users').doc(studentId).collection('chat_history');
      await historyRef.add({
        role: 'user',
        text: textBody,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      await historyRef.add({
        role: 'model',
        text: aiReply,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Send AI response to WhatsApp
      await sendInteractiveButtons(
        rawSender,
        aiReply,
        [
          { id: 'btn_submit_yes', title: '🍰 Submit Dessert' },
          { id: 'btn_check_credits', title: '⭐ My Credits' },
        ]
      );
      return;
    } catch (err) {
      console.error('Gemini A/L Tutor processing error:', err.response?.data || err.message);
      // Fallback
      await sendInteractiveButtons(
        rawSender,
        `Hi *${studentName}*! 🍰\nHow can I help you today? Would you like to submit dessert homework or check your student credits?`,
        [
          { id: 'btn_submit_yes', title: '🍰 Submit Dessert' },
          { id: 'btn_check_credits', title: '⭐ My Credits' },
        ]
      );
    }
  }
}

// ── WhatsApp Text Formatting Helper ─────────────────────────────────────────
function formatForWhatsApp(text) {
  if (!text) return '';
  return text
    // Replace markdown headers with WhatsApp bold (*Title*)
    .replace(/^#{1,6}\s*(.+)$/gm, '*$1*')
    // Replace triple asterisks ***text*** with *text*
    .replace(/\*\*\*(.*?)\*\*\*/g, '*$1*')
    // Replace standard double asterisks **text** with single *text* for WhatsApp bold
    .replace(/\*\*(.*?)\*\*/g, '*$1*')
    // Replace bullet dashes and asterisks with clean bullet symbol •
    .replace(/^[\*\-]\s+/gm, '• ')
    // Clean up empty lines and trailing whitespace
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

// ── WhatsApp Message Dispatch Utilities ─────────────────────────────────────
async function sendWhatsAppOtp(to, otp, studentName) {
  try {
    if (!ACCESS_TOKEN) {
      console.warn('⚠️ sendWhatsAppOtp: No ACCESS_TOKEN configured');
      return false;
    }
    const url = `https://graph.facebook.com/v19.0/${PHONE_NUMBER_ID}/messages`;

    // 1. Try sending Meta Authentication Template (Authorized for ANY student worldwide)
    try {
      const templatePayload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: to,
        type: 'template',
        template: {
          name: 'edupeak_otp',
          language: { code: 'en_US' },
          components: [
            {
              type: 'body',
              parameters: [{ type: 'text', text: otp }]
            },
            {
              type: 'button',
              sub_type: 'url',
              index: '0',
              parameters: [{ type: 'text', text: otp }]
            }
          ]
        }
      };

      const tRes = await axios.post(url, templatePayload, {
        headers: { Authorization: `Bearer ${ACCESS_TOKEN}`, 'Content-Type': 'application/json' },
      });
      console.log(`✅ Template OTP [${otp}] delivered successfully to ${to} (Message ID: ${tRes.data?.messages?.[0]?.id})`);
      return true;
    } catch (templateErr) {
      const errMsg = templateErr.response?.data?.error?.message || templateErr.message;
      console.log(`ℹ️ Template dispatch info: ${errMsg} — attempting direct message format...`);
    }

    // 2. Direct message format
    const messageBody = `🍰 *EduPeak Verification*\n\nHello ${studentName}! 👋\n\nYour 6-digit login code is:\n\n👉 *${otp}*\n\n⏱️ This code is valid for 10 minutes.\n🔒 Do not share this code with anyone.`;
    const textRes = await axios.post(
      url,
      {
        messaging_product: 'whatsapp',
        to: to,
        type: 'text',
        text: { body: messageBody },
      },
      {
        headers: { Authorization: `Bearer ${ACCESS_TOKEN}`, 'Content-Type': 'application/json' },
      }
    );
    console.log(`✅ Direct text OTP [${otp}] delivered to ${to} (Message ID: ${textRes.data?.messages?.[0]?.id})`);
    return true;
  } catch (err) {
    console.error(`❌ Meta WhatsApp API Dispatch Failed for ${to}:`, JSON.stringify(err.response?.data || err.message));
    return false;
  }
}

async function sendWhatsAppText(to, body) {
  try {
    if (!ACCESS_TOKEN) return;
    const url = `https://graph.facebook.com/v19.0/${PHONE_NUMBER_ID}/messages`;
    await axios.post(
      url,
      {
        messaging_product: 'whatsapp',
        to: to,
        type: 'text',
        text: { body: body },
      },
      {
        headers: { Authorization: `Bearer ${ACCESS_TOKEN}`, 'Content-Type': 'application/json' },
      }
    );
  } catch (e) {
    console.error('Error sending WhatsApp text:', e.response?.data || e.message);
  }
}

async function sendInteractiveButtons(to, bodyText, buttons) {
  try {
    if (!ACCESS_TOKEN) return;
    const url = `https://graph.facebook.com/v19.0/${PHONE_NUMBER_ID}/messages`;
    await axios.post(
      url,
      {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: to,
        type: 'interactive',
        interactive: {
          type: 'button',
          header: {
            type: 'text',
            text: '🎓 EduPeak AI Institute',
          },
          body: {
            text: bodyText.length > 1024 ? bodyText.substring(0, 1020) + '...' : bodyText,
          },
          action: {
            buttons: buttons.slice(0, 3).map(b => ({
              type: 'reply',
              reply: {
                id: b.id,
                title: b.title,
              },
            })),
          },
        },
      },
      {
        headers: { Authorization: `Bearer ${ACCESS_TOKEN}`, 'Content-Type': 'application/json' },
      }
    );
  } catch (e) {
    console.error('Error sending interactive buttons, falling back to text:', e.response?.data || e.message);
    await sendWhatsAppText(to, bodyText);
  }
}

// ── Live Firestore OTP Delivery Listener ────────────────────────────────────
console.log('📲 WhatsApp OTP delivery listener: ACTIVE 🟢');
db.collection('otp_requests').onSnapshot(snapshot => {
  snapshot.docChanges().forEach(async change => {
    if (change.type === 'added') {
      const data = change.doc.data();
      const phone = data.phone;
      const name = data.name || 'Student';

      if (!phone) return;

      const randomOtp = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

      try {
        await db.collection('otp_verifications').doc(phone).set({
          otp: randomOtp,
          phone: phone,
          name: name,
          expiresAt: expiresAt,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const targetWaNumber = phone.replace(/\D/g, '');
        await sendWhatsAppOtp(targetWaNumber, randomOtp, name);
        console.log(`📲 Firestore Listener: WhatsApp OTP [${randomOtp}] sent to ${phone} (${name})`);

        await change.doc.ref.delete();
      } catch (err) {
        console.error(`❌ Failed to process OTP for ${phone}:`, err.message);
      }
    }
  });
});

// ── Start Server ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Webhook server running on http://localhost:${PORT}`);
  console.log(`🔗 Webhook endpoint: http://localhost:${PORT}/whatsappWebhook`);
});
