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
    const isExplicitlyLoggedOut = localStorage.getItem('edupeak_is_logged_out') === 'true';
    let initialUser = null;

    if (!isExplicitlyLoggedOut) {
      try {
        const stored = localStorage.getItem('edupeak_cached_user');
        if (stored) {
          const parsed = JSON.parse(stored);
          // Purge legacy mock demo student if present in local storage
          if (parsed && (parsed.uid === 'EP-2027' || parsed.phone === '0770557769')) {
            localStorage.removeItem('edupeak_cached_user');
            initialUser = null;
          } else {
            initialUser = parsed;
          }
        } else {
          initialUser = null;
        }
      } catch (_) {}
    }

    this.currentUser = initialUser;
    this.listeners = [];
    this.loading = !initialUser;
    this.initialAuthReady = new Promise((resolve) => {
      this.resolveInitialAuth = resolve;
      if (initialUser) {
        // Resolve immediately so UI unlocks directly to dashboard
        resolve();
      } else {
        this.loading = false;
        resolve();
      }
      // Absolute safety timeout: Never let initial auth stall longer than 2.5 seconds
      setTimeout(() => {
        if (this.loading) {
          console.warn('[Auth] Initial auth safety timeout reached, unlocking UI.');
          this.loading = false;
          if (this.resolveInitialAuth) {
            this.resolveInitialAuth();
            this.resolveInitialAuth = null;
          }
        }
      }, 2500);
    });

    let hasCheckedRestoredAccount = false;
    this.unsubscribeFirebase = onAuthStateChanged(auth, async (firebaseUser) => {
      try {
        if (firebaseUser) {
          let profile = await this.readProfile(firebaseUser.uid);
          // A persisted session skips the password-login method below. Recheck
          // the server allowlist during restoration so an admin is routed to
          // the correct dashboard without a login-screen flash.
          if (profile && !hasCheckedRestoredAccount) {
            hasCheckedRestoredAccount = true;
            if (firebaseUser.providerData.some((provider) => provider.providerId === 'password')) {
              try {
                await Promise.race([
                  callBackend('auth/ensure-admin', {
                    phone: `+${normalizedPhone(profile.phone)}`,
                  }),
                  new Promise((_, reject) => setTimeout(() => reject(new Error('ensure-admin timeout')), 1500))
                ]);
                await firebaseUser.getIdToken(true);
                profile = await this.readProfile(firebaseUser.uid);
              } catch (error) {
                console.warn('[Auth] Admin access verification non-fatal/timed out:', error);
              }
            }
          }
          if (profile) {
            this.currentUser = profile;
            localStorage.setItem('edupeak_cached_user', JSON.stringify(profile));
            localStorage.removeItem('edupeak_is_logged_out');
          }
        } else {
          // If Firebase says no user:
          if (localStorage.getItem('edupeak_is_logged_out') === 'true') {
            this.currentUser = null;
          }
        }
      } finally {
        this.loading = false;
        this.resolveInitialAuth?.();
        this.resolveInitialAuth = null;
        this.notify();
      }
    });
  }

  waitForInitialAuth() { return this.initialAuthReady; }

  async readProfile(uid) {
    try {
      const profileSnap = await Promise.race([
        getDoc(doc(db, 'users', uid)),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Profile fetch timeout')), 2500))
      ]);
      if (profileSnap && profileSnap.exists()) {
        const claims = await getIdTokenResult(auth.currentUser);
        return { uid, id: uid, ...profileSnap.data(), role: claims.claims.admin === true ? 'admin' : 'student' };
      }
    } catch (error) {
      console.warn('[Auth] Profile load failed or timed out:', error);
    }
    // Fallback: build minimal profile from auth.currentUser so user is never locked out
    const user = auth.currentUser;
    if (user && user.uid === uid) {
      return {
        uid,
        id: uid,
        name: user.displayName || 'Scholar',
        phone: user.email ? user.email.replace(/[^0-9]/g, '') : '',
        role: 'student'
      };
    }
    return null;
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
    localStorage.setItem('edupeak_cached_user', JSON.stringify(profile));
    localStorage.removeItem('edupeak_is_logged_out');
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
    try {
      await Promise.race([
        callBackend('auth/ensure-admin', { phone: `+${normalizedPhone(phone)}` }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('ensure-admin timeout')), 1500))
      ]);
      await credential.user.getIdToken(true);
    } catch (adminErr) {
      console.warn('[Auth] ensure-admin non-fatal warning:', adminErr);
    }
    const profile = await this.readProfile(credential.user.uid);
    if (!profile) throw new Error('Account profile is unavailable. Contact the institute administrator.');
    this.currentUser = profile;
    localStorage.setItem('edupeak_cached_user', JSON.stringify(profile));
    localStorage.removeItem('edupeak_is_logged_out');
    this.notify();
    return profile;
  }

  async updateProfile(updates = {}) {
    if (!this.currentUser) return null;
    const allowed = {};
    for (const key of ['name', 'avatarUrl', 'photoUrl', 'examYear']) {
      if (Object.hasOwn(updates, key)) allowed[key] = updates[key];
    }
    // Optimistic local update: ensure currentUser and localStorage are immediately updated
    this.currentUser = { ...this.currentUser, ...allowed };
    try {
      localStorage.setItem('edupeak_cached_user', JSON.stringify(this.currentUser));
      if (allowed.examYear) localStorage.setItem('edupeak_exam_batch', allowed.examYear);
    } catch (_) {}
    this.notify();

    // Persist to Firestore with timeout safety so network or permissions never block UI
    try {
      const uid = this.currentUser.uid || this.currentUser.id;
      if (uid) {
        await Promise.race([
          setDoc(doc(db, 'users', uid), allowed, { merge: true }),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Update timeout')), 2500))
        ]);
      }
    } catch (e) {
      console.warn('[Auth] Remote profile update note (saved locally):', e);
    }

    return this.currentUser;
  }

  async logout() {
    localStorage.setItem('edupeak_is_logged_out', 'true');
    localStorage.removeItem('edupeak_cached_user');
    await signOut(auth).catch(() => {});
    this.currentUser = null;
    this.notify();
  }
}

export const authService = new AuthService();
