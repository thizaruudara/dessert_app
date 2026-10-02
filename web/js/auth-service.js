// EduPeak Authentication. Firebase Auth is the sole credential store.
import {
  auth, db, doc, getDoc, setDoc, onAuthStateChanged,
  signInWithEmailAndPassword, createUserWithEmailAndPassword,
  signInWithCustomToken, signOut, updateProfile, getIdTokenResult
} from './firebase-config.js';
import { callBackend } from './backend-api.js';


function normalizedPhone(phone) {
  let digits = String(phone || '').replace(/\D/g, '');
  if (digits.startsWith('0')) digits = `94${digits.slice(1)}`;
  else if (digits.length === 9) digits = `94${digits}`;
  if (!digits) throw new Error('Enter a valid phone number.');
  return digits;
}

function authEmail(phone) {
  return `p${normalizedPhone(phone)}@users.edupeak.app`;
}

export class AuthService {
  constructor() {
    this.currentUser = null;
    this.listeners = [];
    this.loading = true;
    this.unsubscribeFirebase = onAuthStateChanged(auth, async (firebaseUser) => {
      this.currentUser = firebaseUser ? await this.readProfile(firebaseUser.uid) : null;
      this.loading = false;
      this.notify();
    });
  }

  async readProfile(uid) {
    try {
      const profileSnap = await getDoc(doc(db, 'users', uid));
      if (!profileSnap.exists()) return null;
      const claims = await getIdTokenResult(auth.currentUser, true);
      return { uid, id: uid, ...profileSnap.data(), role: claims.claims.admin === true ? 'admin' : 'student' };
    } catch (error) {
      console.error('[Auth] Profile load failed:', error);
      return null;
    }
  }

  onAuthStateChanged(callback) {
    this.listeners.push(callback);
    callback(this.currentUser);
    return () => { this.listeners = this.listeners.filter((listener) => listener !== callback); };
  }

  notify() { this.listeners.forEach((listener) => listener(this.currentUser)); }

  async ensureProfile(firebaseUser, { name, phone, examYear }) {
    await callBackend('auth/ensure-profile', { name, phone: `+${normalizedPhone(phone)}`, examYear });
    const profile = await this.readProfile(firebaseUser.uid);
    if (!profile) throw new Error('Your account was created, but its profile could not be loaded. Please sign in again.');
    this.currentUser = profile;
    this.notify();
    return profile;
  }

  async register({ name, phone, password, examYear }) {
    const cleanName = String(name || '').trim();
    if (!cleanName || !phone || !password) throw new Error('Please fill in all required fields.');
    if (password.length < 8) throw new Error('Use a password with at least 8 characters.');
    const credential = await createUserWithEmailAndPassword(auth, authEmail(phone), password);
    try {
      await updateProfile(credential.user, { displayName: cleanName });
      return await this.ensureProfile(credential.user, { name: cleanName, phone, examYear });
    } catch (error) {
      try { await credential.user.delete(); } catch (_) {}
      await signOut(auth);
      throw error;
    }
  }

  async login({ phone, password }) {
    if (!phone || !password) throw new Error('Please enter your phone number and password.');
    let credential;
    try {
      credential = await signInWithEmailAndPassword(auth, authEmail(phone), password);
    } catch (error) {
      if (['auth/user-not-found', 'auth/invalid-credential', 'auth/wrong-password', 'auth/invalid-login-credentials'].includes(error.code)) {
        try {
          const result = await callBackend('auth/upgrade-legacy', { phone: `+${normalizedPhone(phone)}`, password }, { authenticated: false });
          credential = await signInWithCustomToken(auth, result.token);
        } catch (migrationError) {
          if (migrationError.code === 'unauthenticated') {
            throw new Error('Phone or password is incorrect. If you no longer know your old password, contact the institute to reset your account.');
          }
          throw migrationError;
        }
      } else {
        throw error;
      }
    }
    await callBackend('auth/ensure-admin', { phone: `+${normalizedPhone(phone)}` });
    await credential.user.getIdToken(true);
    const profile = await this.readProfile(credential.user.uid);
    if (!profile) throw new Error('Account profile is unavailable. Contact the institute administrator.');
    this.currentUser = profile;
    this.notify();
    return profile;
  }

  async updateProfile(updates = {}) {
    if (!this.currentUser) return null;
    const allowed = {};
    for (const key of ['name', 'avatarUrl', 'photoUrl', 'examYear']) {
      if (Object.hasOwn(updates, key)) allowed[key] = updates[key];
    }
    await setDoc(doc(db, 'users', this.currentUser.uid), allowed, { merge: true });
    this.currentUser = { ...this.currentUser, ...allowed };
    this.notify();
    return this.currentUser;
  }

  async logout() {
    await signOut(auth);
    this.currentUser = null;
    this.notify();
  }
}

export const authService = new AuthService();
