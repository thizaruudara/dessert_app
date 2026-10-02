// Run only from a trusted workstation with Firebase Admin credentials:
// node functions/scripts/set-admin.js FIREBASE_AUTH_UID
const admin = require('firebase-admin');

const uid = process.argv[2];
if (!uid || !/^[A-Za-z0-9:_-]{1,128}$/.test(uid)) {
  console.error('Usage: node functions/scripts/set-admin.js FIREBASE_AUTH_UID');
  process.exit(2);
}

admin.initializeApp();
async function grantAdmin() {
  const user = await admin.auth().getUser(uid);
  await admin.auth().setCustomUserClaims(uid, { ...user.customClaims, admin: true });
  await admin.firestore().collection('users').doc(uid).set({ role: 'admin' }, { merge: true });
  console.log(`Admin access granted to ${uid}. The user must sign out and back in to refresh their token.`);
}

grantAdmin().then(() => process.exit(0)).catch((error) => {
  console.error('Could not grant admin access:', error.message);
  process.exit(1);
});
