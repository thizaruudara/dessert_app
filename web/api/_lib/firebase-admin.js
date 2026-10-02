const { cert, getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

function getAdminApp() {
  const existing = getApps()[0];
  if (existing) return existing;

  const rawCredentials = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!rawCredentials) {
    const error = new Error('Backend is not configured. Add FIREBASE_SERVICE_ACCOUNT_JSON to Vercel Environment Variables.');
    error.status = 503;
    error.code = 'backend-not-configured';
    throw error;
  }

  let credentials;
  try {
    credentials = JSON.parse(rawCredentials);
  } catch (_) {
    const error = new Error('Backend credentials are invalid.');
    error.status = 503;
    error.code = 'backend-not-configured';
    throw error;
  }

  return initializeApp({
    credential: cert(credentials),
    projectId: process.env.FIREBASE_PROJECT_ID || credentials.project_id,
  });
}

function getAdmin() {
  const app = getAdminApp();
  const firestore = () => getFirestore(app);
  firestore.FieldValue = FieldValue;
  return {
    auth: () => getAuth(app),
    firestore,
  };
}

module.exports = { getAdmin };
