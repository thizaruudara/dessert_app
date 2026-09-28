// EduPeak Firestore Database Service
// Real-time synchronization for Desserts (Homework), Paper Sessions, Leaderboard & Sprints
import { 
  db, 
  collection, 
  doc, 
  getDoc, 
  getDocs, 
  setDoc, 
  addDoc, 
  updateDoc, 
  deleteDoc, 
  query, 
  where, 
  orderBy, 
  limit, 
  onSnapshot, 
  serverTimestamp 
} from './firebase-config.js';

export class DbService {
  constructor() {
    this.dessertListeners = [];
  }

  // ── 1. Desserts (Homework Submissions) ─────────────────────────────────────
  async getStudentDesserts(studentId, studentPhone) {
    try {
      const dessertsRef = collection(db, 'desserts');
      let q = query(dessertsRef, orderBy('submittedAt', 'desc'), limit(50));
      
      const snap = await getDocs(q);
      const list = [];
      snap.forEach(docSnap => {
        const data = docSnap.data();
        if (data.studentId === studentId || data.studentPhone === studentPhone) {
          list.push({ id: docSnap.id, ...data });
        }
      });
      if (list.length === 0) {
        return this.getMockDesserts(studentId);
      }
      return list;
    } catch (e) {
      console.warn('[DB] Fallback to local sample desserts if offline/empty:', e);
      return this.getMockDesserts(studentId);
    }
  }

  // Real-time listener for student's homework status
  listenToStudentDesserts(studentId, studentPhone, callback) {
    try {
      const dessertsRef = collection(db, 'desserts');
      const q = query(dessertsRef, orderBy('submittedAt', 'desc'), limit(40));

      return onSnapshot(q, (snapshot) => {
        const list = [];
        snapshot.forEach(docSnap => {
          const data = docSnap.data();
          if (data.studentId === studentId || data.studentPhone === studentPhone) {
            list.push({ id: docSnap.id, ...data });
          }
        });
        if (list.length === 0) {
          callback(this.getMockDesserts(studentId));
        } else {
          callback(list);
        }
      }, (err) => {
        console.warn('[DB] Desserts snapshot listener error, using fallback:', err);
        callback(this.getMockDesserts(studentId));
      });
    } catch (_) {
      callback(this.getMockDesserts(studentId));
      return () => {};
    }
  }

  // Submit new Dessert homework (from Camera Scanner or file)
  async submitDessert({ studentId, studentName, studentPhone, subject, caption, mediaUrls }) {
    try {
      const dessertsRef = collection(db, 'desserts');
      const newDoc = {
        studentId: studentId || 'anon',
        studentName: studentName || 'Scholar',
        studentPhone: studentPhone || '',
        subject: subject || 'Physics Mechanics',
        caption: caption || 'Daily Dessert Submission',
        mediaUrls: mediaUrls || [],
        type: mediaUrls && mediaUrls.length > 0 ? 'image' : 'text',
        status: 'pending',
        creditsAwarded: 0,
        adminFeedback: null,
        reviewedBy: null,
        reviewedAt: null,
        submittedAt: new Date().toISOString()
      };

      const docRef = await addDoc(dessertsRef, newDoc);
      return { id: docRef.id, ...newDoc };
    } catch (e) {
      console.error('[DB] Error saving dessert submission to Firestore:', e);
      // Return optimistic submission object
      return {
        id: 'local_' + Date.now(),
        studentId,
        studentName,
        studentPhone,
        subject,
        caption,
        mediaUrls,
        type: 'image',
        status: 'pending',
        creditsAwarded: 0,
        submittedAt: new Date().toISOString()
      };
    }
  }

  // Admin: Review & grade homework
  async reviewDessert(dessertId, { status, adminFeedback, creditsAwarded, reviewedBy }) {
    try {
      const dessertRef = doc(db, 'desserts', dessertId);
      await updateDoc(dessertRef, {
        status: status, // 'approved' or 'rejected'
        adminFeedback: adminFeedback || '',
        creditsAwarded: Number(creditsAwarded) || 0,
        reviewedBy: reviewedBy || 'Admin',
        reviewedAt: new Date().toISOString()
      });
      return true;
    } catch (e) {
      console.error('[DB] Error updating dessert review:', e);
      return false;
    }
  }

  // Admin: Get all student submissions for grading
  async getAllDessertsForAdmin() {
    try {
      const dessertsRef = collection(db, 'desserts');
      const q = query(dessertsRef, orderBy('submittedAt', 'desc'), limit(100));
      const snap = await getDocs(q);
      const list = [];
      snap.forEach(docSnap => {
        list.push({ id: docSnap.id, ...docSnap.data() });
      });
      if (list.length > 0) return list;
    } catch (e) {
      console.warn('[DB] Admin desserts fetch fallback:', e);
    }
    return [];
  }

  // Admin: Save or update paper session
  async savePaperSession(session) {
    try {
      const ref = collection(db, 'paper_sessions');
      const docRef = await addDoc(ref, {
        ...session,
        createdAt: new Date().toISOString()
      });
      return { id: docRef.id, ...session };
    } catch (e) {
      console.warn('[DB] Saved paper locally:', e);
      return { id: 'paper_' + Date.now(), ...session };
    }
  }

  // Admin: Get student roster
  async getAllStudents() {
    try {
      const usersRef = collection(db, 'users');
      const snap = await getDocs(usersRef);
      if (!snap.empty) {
        return snap.docs.map(d => ({ id: d.id, ...d.data() }));
      }
    } catch (_) {}
    return [];
  }

  matchesYear(paperYear, targetYear) {
    if (!targetYear || targetYear === 'All' || targetYear === 'All Batches') return true;
    const cleanTarget = targetYear.replace(/\s+/g, '').toUpperCase();
    const cleanPaper = (paperYear || '').replace(/\s+/g, '').toUpperCase();
    if (cleanPaper === cleanTarget || cleanPaper === 'ALLBATCHES' || cleanPaper === 'ALL') return true;
    const yearMatch = targetYear.match(/\b(20\d\d)\b/);
    if (yearMatch && cleanPaper.includes(yearMatch[1])) return true;
    if (cleanTarget.includes(cleanPaper)) return true;
    return false;
  }

  // ── 2. Paper Sessions (Online Exam Hall - 1:1 Mobile Parity) ───────────────
  async getPaperSessions(examYear) {
    try {
      const ref = collection(db, 'paper_sessions');
      const snap = await getDocs(ref);
      if (!snap.empty) {
        const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        return list.filter(p => this.matchesYear(p.examYear, examYear));
      }
    } catch (_) {}
    return [];
  }

  async getPaperSession(paperId) {
    if (!paperId) return null;
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      const snap = await getDoc(docRef);
      if (snap.exists()) {
        return { id: snap.id, ...snap.data() };
      }
    } catch (e) {
      console.warn('[DB] getPaperSession error:', e);
    }
    return null;
  }

  streamPaperSession(paperId, callback) {
    if (!paperId) return () => {};
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      return onSnapshot(docRef, (docSnap) => {
        if (docSnap.exists()) {
          callback({ id: docSnap.id, ...docSnap.data() });
        } else {
          callback(null);
        }
      }, (err) => {
        console.warn('[DB] streamPaperSession error:', err);
      });
    } catch (e) {
      console.warn('[DB] streamPaperSession setup error:', e);
      return () => {};
    }
  }

  async getUpcomingPapers(examYear) {
    try {
      const ref = collection(db, 'upcoming_papers');
      const snap = await getDocs(ref);
      if (!snap.empty) {
        const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        return list.filter(p => this.matchesYear(p.examYear, examYear));
      }
    } catch (_) {}
    return [];
  }

  async registerStudentSlot({ paperId, studentId, studentName, studentPhone, slotId }) {
    const regKey = `edupeak_reg_${paperId}_${studentId}`;
    const regData = {
      paperId,
      studentId,
      studentName,
      studentPhone,
      selectedSlot: slotId,
      status: 'registered',
      isCameraActive: false,
      registeredAt: new Date().toISOString()
    };
    try {
      localStorage.setItem(regKey, JSON.stringify(regData));
      const ref = doc(db, 'paper_registrations', `${paperId}_${studentId}`);
      await setDoc(ref, regData, { merge: true });
    } catch (_) {}
    return regData;
  }

  getStudentRegistration(paperId, studentId) {
    try {
      const regKey = `edupeak_reg_${paperId}_${studentId}`;
      const saved = localStorage.getItem(regKey);
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return null;
  }

  async getSlotRegistrations(paperId, slotId) {
    if (!paperId) return [];
    try {
      const ref = collection(db, 'paper_registrations');
      const q = query(ref, where('paperId', '==', paperId));
      const snap = await getDocs(q);
      const list = [];
      snap.forEach(d => {
        const data = { id: d.id, ...d.data() };
        if (!slotId || slotId === 'all' || data.selectedSlot === slotId || (!data.selectedSlot && slotId === 'slot1')) {
          list.push(data);
        }
      });
      return list;
    } catch (e) {
      console.warn('[DB] getSlotRegistrations error:', e);
      return [];
    }
  }

  streamSlotRegistrations(paperId, slotId, callback) {
    if (!paperId) return () => {};
    try {
      const ref = collection(db, 'paper_registrations');
      const q = query(ref, where('paperId', '==', paperId));
      return onSnapshot(q, (snapshot) => {
        const all = [];
        snapshot.forEach(d => {
          all.push({ id: d.id, ...d.data() });
        });
        if (!slotId || slotId === 'all') {
          callback(all);
        } else {
          callback(all.filter(r => (r.selectedSlot || 'slot1') === slotId));
        }
      }, (err) => {
        console.warn('[DB] streamSlotRegistrations error:', err);
      });
    } catch (e) {
      console.warn('[DB] streamSlotRegistrations setup error:', e);
      return () => {};
    }
  }

  // 1:1 Phase Controller matching admin_live_proctor_screen.dart
  async setSessionPhase(paperId, phase, { forceResetTimer = false } = {}) {
    if (!paperId) return;
    const nowIso = new Date().toISOString();
    const updates = { currentPhase: phase };
    let alertMessage = null;
    let alertType = 'info';

    if (phase === 'waiting') {
      updates.status = 'upcoming';
      updates.isTimeUp = false;
    } else if (phase === 'package_opening') {
      updates.status = 'active';
      updates.isTimeUp = false;
      if (forceResetTimer) {
        updates.packageOpeningStartedAt = nowIso;
      }
      alertMessage = '📦 ප්‍රශ්න පත්‍ර පාර්සලය කැමරාව ඉදිරියේ විවෘත කරන්න! (Open your exam parcel in front of the camera now!)';
      alertType = 'urgent';
    } else if (phase === 'writing') {
      updates.status = 'active';
      updates.isTimeUp = false;
      if (forceResetTimer) {
        updates.writingStartedAt = nowIso;
      }
      updates.packageOpeningEndedAt = nowIso;
      alertMessage = '✍️ විභාගය ආරම්භ විය! දැන් පිළිතුරු ලිවීම ආරම්භ කරන්න. (Exam Writing has started!)';
      alertType = 'info';
    } else if (phase === 'time_up') {
      updates.status = 'active';
      updates.isTimeUp = true;
      updates.timeUpAt = nowIso;
      alertMessage = '⏰ වේලාව අවසන් විය! ලිවීම නවතා ඔබගේ පිළිතුරු පත්‍ර In-App Scanner එකෙන් Scan කර දැන්ම Submit කරන්න.';
      alertType = 'urgent';
    } else if (phase === 'ended') {
      updates.status = 'ended';
      updates.endedAt = nowIso;
      alertMessage = '🛑 මෙම විභාග සැසිය නිල වශයෙන් අවසන් විය. (Session Ended by Examiner)';
      alertType = 'urgent';
    }

    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      await updateDoc(docRef, updates);
    } catch (e) {
      console.warn('[DB] setSessionPhase updateDoc error:', e);
    }

    if (alertMessage) {
      this.broadcastProctorAlert({
        paperId,
        senderName: 'Admin / Examiner',
        message: alertMessage,
        type: alertType
      }).catch(() => {});
    }
  }

  async triggerTimeUp(paperId) {
    if (!paperId) return;
    const nowIso = new Date().toISOString();
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      await updateDoc(docRef, {
        isTimeUp: true,
        currentPhase: 'time_up',
        timeUpAt: nowIso
      });
    } catch (e) {
      console.warn('[DB] triggerTimeUp error:', e);
    }
    this.broadcastProctorAlert({
      paperId,
      senderName: 'Admin / Examiner',
      message: '⏰ වේලාව අවසන් විය! (Time is Up!) කරුණාකර ලිවීම නවතා ඔබගේ පිළිතුරු පත්‍ර In-App Scanner එක හරහා Scan කර දැන්ම Submit කරන්න.',
      type: 'urgent'
    }).catch(() => {});
  }

  async endPaperSession(paperId) {
    if (!paperId) return;
    const nowIso = new Date().toISOString();
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      await updateDoc(docRef, {
        status: 'ended',
        currentPhase: 'ended',
        endedAt: nowIso
      });
    } catch (e) {
      console.warn('[DB] endPaperSession error:', e);
    }
    this.broadcastProctorAlert({
      paperId,
      senderName: 'Admin / Examiner',
      message: '🛑 මෙම විභාග සැසිය නිල වශයෙන් අවසන් විය. (Exam session ended by Admin)',
      type: 'urgent'
    }).catch(() => {});
  }

  async startPaperSession(paperId) {
    if (!paperId) return;
    return this.setSessionPhase(paperId, 'package_opening', { forceResetTimer: true });
  }

  async reopenPaperSession(paperId) {
    if (!paperId) return;
    return this.setSessionPhase(paperId, 'waiting');
  }

  async deletePaperSession(paperId) {
    if (!paperId) return;
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      await deleteDoc(docRef);
    } catch (e) {
      console.warn('[DB] deletePaperSession error:', e);
    }
  }

  async updateSlotTimes(paperId, { slot1, slot2 }) {
    if (!paperId) return;
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      const updates = {};
      if (slot1) updates.slot1 = slot1;
      if (slot2) updates.slot2 = slot2;
      await updateDoc(docRef, updates);
    } catch (e) {
      console.warn('[DB] updateSlotTimes error:', e);
    }
  }

  async sendProctorAlert({ paperId, studentId, studentPhone, senderName, message, type = 'warning' }) {
    if (!paperId || !studentId) return;
    try {
      const alertsRef = collection(db, 'proctor_alerts');
      await addDoc(alertsRef, {
        paperId,
        studentId,
        studentPhone: studentPhone || '',
        senderName: senderName || 'Admin / Teacher',
        message,
        type,
        isRead: false,
        createdAt: new Date().toISOString()
      });
    } catch (e) {
      console.warn('[DB] sendProctorAlert error:', e);
    }
  }

  async broadcastProctorAlert({ paperId, senderName, message, type = 'info' }) {
    if (!paperId) return;
    try {
      const alertsRef = collection(db, 'proctor_alerts');
      await addDoc(alertsRef, {
        paperId,
        studentId: 'ALL',
        senderName: senderName || 'Admin / Examiner',
        message,
        type,
        isRead: false,
        createdAt: new Date().toISOString()
      });
    } catch (e) {
      console.warn('[DB] broadcastProctorAlert error:', e);
    }
  }

  // ── 3. Daily MCQ Sprint ──────────────────────────────────────────────────
  getDailySprint(dateStr) {
    return {
      id: 'sprint_' + (dateStr || 'today'),
      title: 'Daily High-Yield Physics Sprint',
      targetDate: dateStr || new Date().toISOString().split('T')[0],
      durationSeconds: 180,
      xpBonus: 75,
      questions: [
        {
          id: 'q1',
          text: 'A block of mass m slides down an inclined plane of angle θ with constant velocity. What is the coefficient of kinetic friction μk?',
          options: ['sin θ', 'cos θ', 'tan θ', 'cot θ', '1 / tan θ'],
          correctIndex: 2,
          explanation: 'When velocity is constant, the net force along the incline is zero: mg sin θ = fk = μk mg cos θ. Therefore, μk = tan θ.'
        },
        {
          id: 'q2',
          text: 'What happens to the capacitance of a parallel plate capacitor when a dielectric slab of dielectric constant k is fully inserted between the plates?',
          options: ['Decreases by k', 'Increases by k', 'Remains unchanged', 'Decreases by k²', 'Increases to infinity'],
          correctIndex: 1,
          explanation: 'Inserting a dielectric slab increases capacitance according to C = k * C0, where k > 1 is the dielectric constant.'
        },
        {
          id: 'q3',
          text: 'In simple harmonic motion, at which position does the particle have maximum kinetic energy?',
          options: ['At maximum displacement +A', 'At maximum displacement -A', 'At the equilibrium position (x = 0)', 'At x = A / 2', 'At x = A / √2'],
          correctIndex: 2,
          explanation: 'At the equilibrium position (x = 0), potential energy is minimum (zero) and velocity is maximum (v = ωA), giving maximum kinetic energy.'
        },
        {
          id: 'q4',
          text: 'Two identical sinusoidal waves of frequency f and amplitude A travel in opposite directions along a stretched string. The resulting standing wave has amplitude at an antinode equal to:',
          options: ['0', 'A / 2', 'A', '2A', '4A'],
          correctIndex: 3,
          explanation: 'At an antinode, constructive interference of the two opposing waves with amplitude A produces an antinode amplitude of 2A.'
        },
        {
          id: 'q5',
          text: 'A light ray passes from a denser medium with refractive index n1 into a rarer medium with refractive index n2. The critical angle θc is given by:',
          options: ['sin⁻¹(n1 / n2)', 'sin⁻¹(n2 / n1)', 'tan⁻¹(n2 / n1)', 'cos⁻¹(n2 / n1)', 'n1 * n2'],
          correctIndex: 1,
          explanation: 'By Snell\'s Law for critical angle (refracted angle = 90°): n1 sin(θc) = n2 sin(90°), hence sin(θc) = n2 / n1, where n1 > n2.'
        }
      ]
    };
  }

  // ── 4. Leaderboard ───────────────────────────────────────────────────────
  async getLeaderboard() {
    try {
      const usersRef = collection(db, 'users');
      const q = query(usersRef, orderBy('credits', 'desc'), limit(25));
      const snap = await getDocs(q);
      if (!snap.empty) {
        return snap.docs.map((d, index) => ({
          rank: index + 1,
          id: d.id,
          name: d.data().name || 'Student',
          examYear: d.data().examYear || '2026 A/L',
          credits: d.data().credits || 0,
          avatarUrl: d.data().avatarUrl || ''
        }));
      }
    } catch (_) {}
    return [];
  }

  // ── 5. Daily Physics Insight ─────────────────────────────────────────────
  getDailyInsight() {
    const insights = [
      {
        concept: "Bernoulli’s Principle & Fluid Dynamics",
        formula: "P + ½ρv² + ρgh = constant",
        summary: "In a horizontal streamline flow, where fluid speed increases, static pressure decreases simultaneously.",
        examTip: "Common A/L MCQ trap: The pitot tube measures stagnation pressure where v = 0!",
        tags: ["Fluids", "Mechanics", "Hydrodynamics"]
      },
      {
        concept: "Doppler Effect in Sound",
        formula: "f' = f [(v ± v_o) / (v ∓ v_s)]",
        summary: "The observed frequency increases as the sound source approaches the observer, and decreases as it recedes.",
        examTip: "Always fix the observer direction and sign convention: sound velocity v always points from source to observer.",
        tags: ["Waves", "Sound", "Oscillations"]
      },
      {
        concept: "Faraday’s Law & Lenz’s Rule",
        formula: "ε = -N (dΦ / dt)",
        summary: "The induced electromotive force in any closed circuit is equal to the negative of the time rate of change of magnetic flux through the circuit.",
        examTip: "The minus sign represents Lenz's law: the induced current opposes the change in flux that produces it.",
        tags: ["Electromagnetism", "Induction", "Fields"]
      }
    ];

    const dayOfYear = Math.floor((new Date() - new Date(new Date().getFullYear(), 0, 0)) / (1000 * 60 * 60 * 24));
    return insights[dayOfYear % insights.length];
  }

  // ── Mock Data Fallbacks ───────────────────────────────────────────────────
  getMockDesserts(studentId) {
    return [
      {
        id: 'des_001',
        studentId: studentId || 'usr_1',
        studentName: 'Scholar',
        subject: 'Mechanics: Circular Motion & Gravitation',
        caption: 'Solved all 10 past paper structured essay problems with full free-body diagrams.',
        mediaUrls: ['./icons/exam_3d_countdown.jpg'],
        type: 'image',
        status: 'approved',
        creditsAwarded: 50,
        adminFeedback: 'Excellent free-body diagram clarity! Centripetal force derivations are perfectly aligned with A/L marking schemes.',
        reviewedBy: 'Prof. Senanayake',
        submittedAt: new Date(Date.now() - 86400000 * 1.5).toISOString(),
        reviewedAt: new Date(Date.now() - 86400000 * 0.8).toISOString()
      },
      {
        id: 'des_002',
        studentId: studentId || 'usr_1',
        studentName: 'Scholar',
        subject: 'Thermal Physics: Calorimetry & Gas Laws',
        caption: 'Calculation of specific heat capacity and isothermal expansion curves.',
        mediaUrls: [],
        type: 'text',
        status: 'pending',
        creditsAwarded: 0,
        adminFeedback: null,
        reviewedBy: null,
        submittedAt: new Date(Date.now() - 3600000 * 4).toISOString(),
        reviewedAt: null
      },
      {
        id: 'des_003',
        studentId: studentId || 'usr_1',
        studentName: 'Scholar',
        subject: 'Wave Optics: Young\'s Double Slit Interference',
        caption: 'Fringe width derivation and intensity distribution graph.',
        mediaUrls: [],
        type: 'text',
        status: 'rejected',
        creditsAwarded: 10,
        adminFeedback: 'Path difference calculation has a sign error on line 4. Please revise and resubmit for full marks.',
        reviewedBy: 'Teacher Assistant',
        submittedAt: new Date(Date.now() - 86400000 * 4).toISOString(),
        reviewedAt: new Date(Date.now() - 86400000 * 3).toISOString()
      }
    ];
  }

  getMockPaperSessions(examYear) {
    const now = Date.now();
    const list = [
      {
        id: 'paper_001',
        title: '2027 A/L Speed Paper 01 (Physics)',
        subject: 'Physics',
        examYear: '2027 A/L',
        date: new Date().toISOString(),
        durationMinutes: 150,
        status: 'active',
        currentPhase: 'package_opening', // 10-Minute Package Opening Phase
        packageOpeningStartedAt: new Date(now - 3.5 * 60 * 1000).toISOString(), // ~6.5 mins left
        writingStartedAt: null,
        slot1: {
          id: 'slot1',
          name: 'Slot 1 (Morning)',
          startTime: new Date(now - 3.5 * 60 * 1000).toISOString(),
          endTime: new Date(now + 150 * 60 * 1000).toISOString(),
          registeredCount: 42,
          maxCapacity: 100
        },
        slot2: {
          id: 'slot2',
          name: 'Slot 2 (Evening)',
          startTime: new Date(now + 8 * 3600 * 1000).toISOString(),
          endTime: new Date(now + 10.5 * 3600 * 1000).toISOString(),
          registeredCount: 18,
          maxCapacity: 100
        }
      },
      {
        id: 'paper_002',
        title: '2027 A/L Unit 01 Mechanics Speed Paper',
        subject: 'Physics',
        examYear: '2027 A/L',
        date: new Date(now + 86400000 * 3).toISOString(),
        durationMinutes: 120,
        status: 'upcoming',
        currentPhase: 'waiting', // Waiting Room Phase
        packageOpeningStartedAt: null,
        writingStartedAt: null,
        slot1: {
          id: 'slot1',
          name: 'Slot 1 (Morning)',
          startTime: new Date(now + 86400000 * 3 + 8 * 3600 * 1000).toISOString(),
          endTime: new Date(now + 86400000 * 3 + 10 * 3600 * 1000).toISOString(),
          registeredCount: 85,
          maxCapacity: 150
        },
        slot2: {
          id: 'slot2',
          name: 'Slot 2 (Evening)',
          startTime: new Date(now + 86400000 * 3 + 16 * 3600 * 1000).toISOString(),
          endTime: new Date(now + 86400000 * 3 + 18 * 3600 * 1000).toISOString(),
          registeredCount: 30,
          maxCapacity: 150
        }
      },
      {
        id: 'paper_003',
        title: '2026 A/L Island-Wide Comprehensive Paper 04',
        subject: 'Physics',
        examYear: '2026 A/L',
        date: new Date(now - 86400000 * 2).toISOString(),
        durationMinutes: 180,
        status: 'ended',
        currentPhase: 'ended',
        packageOpeningStartedAt: null,
        writingStartedAt: null,
        slot1: {
          id: 'slot1',
          name: 'Slot 1 (Morning)',
          startTime: new Date(now - 86400000 * 2).toISOString(),
          endTime: new Date(now - 86400000 * 2 + 180 * 60000).toISOString(),
          registeredCount: 140,
          maxCapacity: 150
        },
        slot2: null
      }
    ];

    return list.filter(p => this.matchesYear(p.examYear, examYear));
  }

  getMockUpcomingPapers(examYear) {
    const now = Date.now();
    const list = [
      {
        id: 'upcoming_001',
        title: '2027 A/L Final Preparation Paper 02',
        subject: 'Physics',
        examYear: '2027 A/L',
        scheduledDate: new Date(now + 86400000 * 3.5).toISOString(),
        durationMinutes: 180,
        paperStructure: 'Section A (MCQ 50) + Section B (Structured Essay 4)',
        syllabusTopics: [
          'Units & Dimensions',
          'Kinematics & Vector Resolution',
          "Newton's Laws & Friction Losses",
          'Work, Energy & Power Theorem',
          'Circular & Gravitational Motion',
          'Rotational Dynamics'
        ],
        hints: '💡 Special Focus: Vector resolution on tilted inclined planes and friction boundary conditions (f_s <= μ_s * R). In Section B, ensure free-body diagrams clearly mark normal reactions at contact points. Calculation speed is tested heavily in the first 10 MCQ problems.',
        instructions: 'Students must join with camera positioned at 45 degrees showing both writing table and hands. Package opening will be initiated exactly 10 minutes prior to writing commencement.',
        status: 'upcoming'
      },
      {
        id: 'upcoming_002',
        title: '2026 A/L Island-Wide Comprehensive Paper 05',
        subject: 'Physics',
        examYear: '2026 A/L',
        scheduledDate: new Date(now + 86400000 * 6.5).toISOString(),
        durationMinutes: 180,
        paperStructure: 'Full Examination Syllabus Blueprint',
        syllabusTopics: [
          'Waves & Sound Oscillations',
          'Physical Optics & Interference',
          'Current Electricity & Kirchhoff Laws',
          'Magnetic Fields & Biot-Savart Law',
          'Thermal Physics & Heat Capacities',
          'Photoelectric Effect & Quantum Physics'
        ],
        hints: '💡 Special Focus: Wave interference fringe shifts when inserting thin glass plates into Young slit apparatus. Be ready for non-linear temperature coefficient problems in platinum resistance thermometers.',
        instructions: 'Official 100-page examination booklet strictly required. Digital smart watches and secondary communication devices are strictly prohibited in the exam chamber.',
        status: 'upcoming'
      }
    ];

    return list.filter(p => this.matchesYear(p.examYear, examYear));
  }

  getMockLeaderboard() {
    return [
      { rank: 1, id: 'u1', name: 'Danushka Wickramasinghe', examYear: '2026 A/L', credits: 1420, avatarUrl: '' },
      { rank: 2, id: 'u2', name: 'Minoli Senarath', examYear: '2026 A/L', credits: 1280, avatarUrl: '' },
      { rank: 3, id: 'u3', name: 'Sachintha Fernando', examYear: '2027 A/L', credits: 1190, avatarUrl: '' },
      { rank: 4, id: 'u4', name: 'Dinuka Rajapaksha', examYear: '2026 A/L', credits: 940, avatarUrl: '' },
      { rank: 5, id: 'u5', name: 'Kavindu Jayawardena', examYear: '2026 A/L', credits: 890, avatarUrl: '' },
      { rank: 6, id: 'u6', name: 'Anuki Dissanayake', examYear: '2027 A/L', credits: 810, avatarUrl: '' },
      { rank: 7, id: 'u7', name: 'Thejana Gunawardana', examYear: '2026 A/L', credits: 760, avatarUrl: '' },
      { rank: 8, id: 'u8', name: 'Praveen Silva', examYear: '2028 A/L', credits: 710, avatarUrl: '' }
    ];
  }
}

export const dbService = new DbService();
