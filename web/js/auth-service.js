// EduPeak Auth Service
// Supports Student Registration, Phone Login, Admin Detection & Demo Quick-Login
import { db, collection, doc, getDoc, getDocs, setDoc, query, where, serverTimestamp } from './firebase-config.js';

export class AuthService {
  constructor() {
    this.currentUser = null;
    this.listeners = [];
    this.loadPersistedUser();
  }

  isPhoneAdmin(phone) {
    if (!phone) return false;
    const digits = phone.replace(/\D/g, '');
    return (
      digits.includes('770557769') ||
      digits.includes('707938883') ||
      digits.includes('701068489') ||
      digits.endsWith('770557769') ||
      digits.endsWith('707938883') ||
      digits.endsWith('701068489')
    );
  }

  loadPersistedUser() {
    try {
      const saved = localStorage.getItem('edupeak_user');
      if (saved) {
        this.currentUser = JSON.parse(saved);
      }
    } catch (_) {}
  }

  saveSession(user) {
    this.currentUser = user;
    try {
      localStorage.setItem('edupeak_user', JSON.stringify(user));
    } catch (_) {}
    this.notify();
  }

  clearSession() {
    this.currentUser = null;
    try {
      localStorage.removeItem('edupeak_user');
    } catch (_) {}
    this.notify();
  }

  onAuthStateChanged(callback) {
    this.listeners.push(callback);
    callback(this.currentUser);
    return () => {
      this.listeners = this.listeners.filter(l => l !== callback);
    };
  }

  notify() {
    this.listeners.forEach(l => l(this.currentUser));
  }

  async register({ name, phone, password, examYear }) {
    const cleanPhone = phone.trim();
    if (!cleanPhone || !name || !password) {
      throw new Error('Please fill in all required fields.');
    }

    // Check if phone already registered in Firestore
    try {
      const usersRef = collection(db, 'users');
      const q = query(usersRef, where('phone', '==', cleanPhone));
      const snap = await getDocs(q);

      if (!snap.empty) {
        const existingData = snap.docs[0].data();
        if (existingData.password) {
          throw new Error('An account already exists with this phone number. Please sign in.');
        }
      }

      const uid = 'usr_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
      const isAdmin = this.isPhoneAdmin(cleanPhone);

      const userData = {
        uid: uid,
        name: name.trim(),
        phone: cleanPhone,
        password: password,
        role: isAdmin ? 'admin' : 'student',
        credits: 50, // Welcome bonus
        examYear: examYear || '2026 A/L',
        studentId: 'EP-' + cleanPhone.slice(-4),
        avatarUrl: '',
        createdAt: new Date().toISOString()
      };

      // Write to Firestore
      await setDoc(doc(db, 'users', uid), userData);

      this.saveSession(userData);
      return userData;
    } catch (err) {
      console.error('[Auth] Register error:', err);
      throw err;
    }
  }

  async login({ phone, password }) {
    const cleanPhone = phone.trim();
    if (!cleanPhone || !password) {
      throw new Error('Please enter your phone number and password.');
    }

    try {
      const usersRef = collection(db, 'users');
      const q = query(usersRef, where('phone', '==', cleanPhone));
      const snap = await getDocs(q);

      if (snap.empty) {
        throw new Error('No account found with this phone number. Please register first.');
      }

      const userDoc = snap.docs[0];
      const userData = userDoc.data();

      if (userData.password && userData.password !== password) {
        throw new Error('Incorrect password. Please try again.');
      }

      // Check if admin phone
      if (this.isPhoneAdmin(cleanPhone) && userData.role !== 'admin') {
        userData.role = 'admin';
        setDoc(doc(db, 'users', userDoc.id), { role: 'admin' }, { merge: true }).catch(() => {});
      }

      this.saveSession(userData);
      return userData;
    } catch (err) {
      console.error('[Auth] Login error:', err);
      throw err;
    }
  }

  // Quick Demo Login for instant testing & evaluation
  loginDemo(role = 'student') {
    const isTeacher = role === 'admin';
    const demoUser = {
      uid: isTeacher ? 'demo_teacher_01' : 'demo_student_01',
      name: isTeacher ? 'Prof. Senanayake (Admin)' : 'Kasun Perera',
      phone: isTeacher ? '0770557769' : '0712345678',
      role: isTeacher ? 'admin' : 'student',
      credits: isTeacher ? 9999 : 340,
      examYear: '2026 A/L',
      studentId: isTeacher ? 'EP-ADMIN' : 'EP-5678',
      avatarUrl: '',
      createdAt: new Date().toISOString()
    };

    this.saveSession(demoUser);
    return demoUser;
  }

  async updateProfile(updates = {}) {
    if (!this.currentUser) return null;
    const updatedUser = { ...this.currentUser, ...updates };
    this.saveSession(updatedUser);

    try {
      if (updatedUser.uid) {
        await setDoc(doc(db, 'users', updatedUser.uid), updates, { merge: true });
      }
    } catch (e) {
      console.warn('[Auth] Error updating profile in Firestore:', e);
    }
    return updatedUser;
  }

  async addCredits(amount) {
    if (!this.currentUser || !amount) return;
    const newCredits = (this.currentUser.credits || 0) + amount;
    return this.updateProfile({ credits: newCredits });
  }

  logout() {
    this.clearSession();
  }
}

export const authService = new AuthService();
