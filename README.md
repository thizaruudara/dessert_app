# 🍰 Dessert — Institute Homework Submission App

A cross-platform Flutter app (Android + iOS) for submitting and reviewing homework ("Desserts") via WhatsApp, with an admin review panel and a student credit system.

---

## 📱 Features

### Student Portal
- **Phone OTP login** via Firebase Auth
- **Home screen** with credit score, level badge, and recent submissions
- **My Desserts** — full submission history with status (Pending / Approved / Rejected)
- **Submit guide** — step-by-step WhatsApp submission instructions + direct chat link
- **Submission detail** — view teacher feedback and credits earned

### Admin Panel
- **Dashboard** with tabbed view: Pending / Approved / Rejected
- **Review screen** — view student submission, set credit amount (0–50), write feedback
- **Approve ✅** or **Reject ❌** with one tap
- **Students leaderboard** — all students ranked by credits (🥇🥈🥉)
- **Push notifications** — FCM notification for every new submission

### WhatsApp Integration
- Students send homework (text/image/PDF) to institute's **WhatsApp Business** number
- Firebase Cloud Function receives messages via webhook
- Automatically matches sender phone → student account in Firestore
- Creates a `dessert` document and notifies all admins via FCM

---

## 🏗 Architecture

```
Flutter App (single codebase → Android + iOS)
    ↕
Firebase (Firestore + Auth + FCM + Storage + Cloud Functions)
    ↕ webhook
WhatsApp Business Cloud API (Meta)
```

### Directory Structure
```
dessert_app/
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart          ← replace with flutterfire output
│   ├── core/
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   └── dessert_model.dart
│   │   ├── router/
│   │   │   └── app_router.dart        ← role-based routing
│   │   ├── services/
│   │   │   └── notification_service.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   └── features/
│       ├── auth/                       ← phone OTP login
│       ├── student/                    ← student portal
│       ├── admin/                      ← admin panel
│       ├── desserts/                   ← shared dessert provider
│       └── credits/                    ← credit level system
├── functions/
│   └── index.js                        ← WhatsApp webhook + FCM triggers
├── firestore.rules                     ← security rules
├── storage.rules
└── firestore.indexes.json
```

---

## 🚀 Setup Guide

### Step 1 — Create a Firebase Project
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project (e.g. `dessert-institute`)
3. Enable **Authentication** → Phone
4. Enable **Firestore Database** (production mode)
5. Enable **Firebase Storage**
6. Enable **Cloud Messaging**

### Step 2 — Connect Flutter to Firebase
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (generates lib/firebase_options.dart automatically)
flutterfire configure --project=dessert-institute
```

### Step 3 — Android Setup
- Download `google-services.json` from Firebase Console → Project Settings → Android
- Place it at `android/app/google-services.json`

### Step 4 — iOS Setup
- Download `GoogleService-Info.plist` from Firebase Console → Project Settings → iOS
- Place it in `ios/Runner/GoogleService-Info.plist`
- Run `cd ios && pod install`

### Step 5 — Set Up WhatsApp Business API
1. Create a [Meta Developer account](https://developers.facebook.com)
2. Create a **WhatsApp Business** app
3. Get a phone number (or use the test number Meta provides)
4. Set the webhook URL to your Cloud Function URL:
   ```
   https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/whatsappWebhook
   ```
5. Subscribe to `messages` events
6. Set `WHATSAPP_VERIFY_TOKEN` in Cloud Functions environment:
   ```bash
   firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN
   ```

### Step 6 — Deploy Cloud Functions
```bash
cd dessert_app
npm install -g firebase-tools
firebase login
firebase deploy --only functions
```

### Step 7 — Set Admin Role
To promote a user to admin, update their Firestore document:
```
Collection: users
Document: <user_uid>
Field: role = "admin"
```

### Step 8 — Update WhatsApp Number in App
Edit [`lib/features/student/screens/student_submit_guide_screen.dart`](lib/features/student/screens/student_submit_guide_screen.dart):
```dart
const String kInstituteWhatsAppNumber = '+YOUR_ACTUAL_NUMBER';
```

### Step 9 — Run the App
```bash
flutter pub get
flutter run
```

---

## 🔐 Security

- Students can only read/see **their own** submissions
- Admins can read and update **all** submissions  
- Credits can **only** be updated by admins or Cloud Functions — students cannot modify their own credit count
- Firebase Storage is write-protected (only Cloud Functions can write media)

---

## 💳 Credit System

| Action | Credits |
|--------|---------|
| Correct Dessert | +10 pts (configurable 0–50 per review) |
| Rejected Dessert | +0 pts |

| Level | Required |
|-------|---------|
| 🌱 Newcomer | 0–49 pts |
| 🥉 Bronze Scholar | 50–199 pts |
| 🥈 Silver Scholar | 200–499 pts |
| 🏆 Gold Scholar | 500+ pts |
