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

  // ── 2. Paper Sessions (Online Exam Hall) ──────────────────────────────────
  async getPaperSessions() {
    try {
      const ref = collection(db, 'paper_sessions');
      const snap = await getDocs(ref);
      if (!snap.empty) {
        return snap.docs.map(d => ({ id: d.id, ...d.data() }));
      }
    } catch (_) {}
    return this.getMockPaperSessions();
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
    return this.getMockLeaderboard();
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

  getMockPaperSessions() {
    return [
      {
        id: 'paper_001',
        title: '2026 A/L Island-Wide Physics Model Paper 04',
        subject: 'Full Syllabus (Mechanics, Waves, Electricity, Modern Physics)',
        examDate: new Date(Date.now() + 86400000 * 2).toISOString(),
        durationMinutes: 120,
        totalMarks: 100,
        isLive: true,
        proctoringRequired: true,
        slots: [
          { id: 'slot_1', name: 'Morning Session (08:30 AM - 10:30 AM)', seatsLeft: 42 },
          { id: 'slot_2', name: 'Evening Session (04:00 PM - 06:00 PM)', seatsLeft: 78 }
        ]
      },
      {
        id: 'paper_002',
        title: 'Speed Sprint Paper: Mechanics & Oscillations',
        subject: 'Unit 01 & Unit 02 Rapid Timed Drill',
        examDate: new Date(Date.now() + 86400000 * 6).toISOString(),
        durationMinutes: 60,
        totalMarks: 50,
        isLive: false,
        proctoringRequired: true,
        slots: [
          { id: 'slot_sprint', name: 'Standard Slot (07:00 PM - 08:00 PM)', seatsLeft: 120 }
        ]
      }
    ];
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
