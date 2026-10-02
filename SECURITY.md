# Security migration and deployment

The application uses Firebase Authentication for identity and Firestore / Storage for data. The web UI is hosted on Vercel, and its privileged API routes run as Vercel Functions using Firebase Admin credentials stored only in Vercel Environment Variables. Firestore and Storage rules remain the enforcement layer for direct client access.

## Deploying the migration

1. In Firebase Console, enable **Authentication → Sign-in method → Email/Password**. The app maps each normalized Sri Lankan phone number to a private synthetic email for Firebase Authentication; students still enter their phone number and password.
2. In Vercel project `edupeak-web`, add `FIREBASE_SERVICE_ACCOUNT_JSON` as a Production environment variable containing the Firebase Admin service-account JSON, and `FIREBASE_PROJECT_ID=dessert-institute`. Never commit the service-account JSON or paste it into chat. Grant the service account only the Firebase Authentication and Firestore permissions required by the API.
3. The web and Android apps call the Vercel endpoints in `web/api` for legacy account migration, profile provisioning, paper-slot registration, and sprint scoring. The mobile clients need public HTTPS access to those endpoints; Vercel Authentication protection must not block student traffic. Deploy the web project after setting its environment variables, and rebuild the APK after the API migration is complete.
4. Rotate the WhatsApp access token that was previously present in source, the Meta app secret if it was exposed, and any service-account key that may have been used locally. Removing a secret from the current file does not remove it from Git history or revoke it.
   The old APK also contained a shared `X-Admin-Secret` for the external `edupeak-telegram-bot.vercel.app` broadcast API. That header was removed from the client. Rotate that value on the Vercel service and require a verified Firebase ID token with the `admin` claim for `/api/broadcast` and `/api/paper-broadcast`; those broadcast calls will fail until the external service accepts that auth flow.
5. Existing phone/password accounts migrate on their first successful sign-in. Their old password is checked once by the Vercel API, then the profile copy no longer stores it. Accounts with forgotten or shorter-than-eight-character passwords need administrator-assisted recovery.
6. Existing administrator assignments are deliberately not trusted. After the account owner signs in and migrates, grant admin access from a trusted machine with `node functions/scripts/set-admin.js FIREBASE_AUTH_UID`. Admin access is held in a Firebase Auth custom claim; a profile field or phone number alone is not sufficient.

## Important behavior changes

- Telegram/WhatsApp OTP login is disabled because the previous verification codes were stored in client-readable Firestore. Password login now uses Firebase Authentication.
- Students cannot edit their credit totals or publish exam content. Admin review and configuration require an admin custom claim.
- Student leaderboards use a minimal public projection without phone numbers or notification tokens.
- The new password accounts use a synthetic email address and do not support Firebase's email reset flow. Do not use the Firebase email-reset endpoint for these accounts; provide account recovery through a verified institute administrator.
- New sign-ups still use the phone number as the account name but do not verify phone ownership by SMS. Phone verification should be added before allowing first-time registration in a public release.
- Existing Firebase Storage download-token URLs remain bearer links. Revoke or replace existing download tokens if any protected homework URL was exposed before the rule change.

## Webhook configuration

POST webhook events are accepted only when Meta's `X-Hub-Signature-256` matches the configured app secret. The legacy `/api/send-otp` endpoint returns `410 Gone` and no longer writes OTP values to Firestore.

## Backend migration status

The client-callable Firebase functions have Vercel API replacements. Firestore-triggered jobs and the WhatsApp webhook in `functions/index.js` have not yet been moved; do not remove or disable any existing production functions until those behaviors have an approved replacement.
