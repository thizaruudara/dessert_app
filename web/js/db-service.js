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
import { callBackend } from './backend-api.js';

export class DbService {
  constructor() {
    this.dessertListeners = [];
  }

  // ── 1. Desserts (Homework Submissions) ─────────────────────────────────────
  async getStudentDesserts(studentId, studentPhone) {
    if (!studentId && !studentPhone) return this.getMockDesserts ? this.getMockDesserts() : [];
    try {
      const dessertsRef = collection(db, 'desserts');
      const q = studentId
        ? query(dessertsRef, where('studentId', '==', String(studentId)), limit(50))
        : query(dessertsRef, where('studentPhone', '==', String(studentPhone)), limit(50));
      
      const snap = await getDocs(q);
      const list = [];
      snap.forEach(docSnap => {
        const data = docSnap.data();
        if ((studentId && data.studentId === studentId) || (studentPhone && data.studentPhone === studentPhone)) {
          list.push({ id: docSnap.id, ...data });
        }
      });
      list.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));
      return list;
    } catch (e) {
      console.warn('[DB] Student dessert query failed, falling back:', e);
      return this.getMockDesserts ? this.getMockDesserts(studentId) : [];
    }
  }

  // Real-time listener for student's homework status
  listenToStudentDesserts(studentId, studentPhone, callback) {
    if (!studentId && !studentPhone) return () => {};
    try {
      const dessertsRef = collection(db, 'desserts');
      const q = studentId
        ? query(dessertsRef, where('studentId', '==', String(studentId)), limit(40))
        : query(dessertsRef, where('studentPhone', '==', String(studentPhone)), limit(40));

      return onSnapshot(q, (snapshot) => {
        const list = [];
        snapshot.forEach(docSnap => {
          const data = docSnap.data();
          if (data.studentId === studentId || data.studentPhone === studentPhone) {
            list.push({ id: docSnap.id, ...data });
          }
        });
        list.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));
        callback(list);
      }, (err) => {
        console.warn('[DB] Desserts snapshot listener error:', err);
        callback([]);
      });
    } catch (_) {
      callback([]);
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
      throw e;
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
      throw e;
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

  // Admin: Delete student account and associated data
  async deleteStudent(studentId) {
    if (!studentId) return;
    try {
      await deleteDoc(doc(db, 'users', studentId));
      await deleteDoc(doc(db, 'students', studentId)).catch(() => {});
    } catch (e) {
      console.warn('[DB] deleteStudent error:', e);
    }
  }

  matchesYear(paperYear, targetYear) {
    if (!targetYear || targetYear === 'All' || targetYear === 'All Batches') return true;
    if (!paperYear || paperYear === 'All' || paperYear === 'All Batches') return true;
    const cleanTarget = targetYear.replace(/\s+/g, '').toUpperCase();
    const cleanPaper = (paperYear || '').replace(/\s+/g, '').toUpperCase();
    if (cleanPaper === cleanTarget || cleanPaper === 'ALLBATCHES' || cleanPaper === 'ALL') return true;
    const yearMatch = targetYear.match(/\b(20\d\d)\b/);
    if (yearMatch && cleanPaper.includes(yearMatch[1])) return true;
    if (cleanTarget.includes(cleanPaper) || cleanPaper.includes(cleanTarget)) return true;
    return false;
  }

  // Unified status computation across Admin and Student views
  computeSessionStatus(session) {
    if (!session) {
      return { isEnded: false, isLive: false, isWaiting: false, isUpcoming: true, isPackageOpening: false, isWriting: false, isTimeUp: false, statusText: 'upcoming' };
    }
    const isEnded = !!(session.isEnded || session.status === 'ended' || session.currentPhase === 'ended');
    if (isEnded) {
      return { isEnded: true, isLive: false, isWaiting: false, isUpcoming: false, isPackageOpening: false, isWriting: false, isTimeUp: false, statusText: 'ended' };
    }
    const isPackageOpening = session.currentPhase === 'package_opening';
    const isWriting = session.currentPhase === 'writing';
    const isTimeUp = session.currentPhase === 'time_up' || !!session.isTimeUp;
    
    // Check if slot 1 start time has passed
    let isAfterSlot1 = false;
    if (session.slot1?.startTime) {
      const s1 = new Date(session.slot1.startTime);
      if (!isNaN(s1.getTime())) {
        isAfterSlot1 = new Date() >= s1;
      }
    }

    const isLive = !!(
      session.isLive ||
      session.status === 'active' ||
      session.status === 'live' ||
      isPackageOpening ||
      isWriting ||
      isTimeUp ||
      isAfterSlot1
    );

    const isWaiting = !isLive && session.currentPhase === 'waiting';
    const isUpcoming = !isLive && !isEnded;

    return {
      isEnded,
      isLive,
      isWaiting,
      isUpcoming,
      isPackageOpening,
      isWriting,
      isTimeUp,
      statusText: isLive ? 'live' : (isEnded ? 'ended' : 'upcoming')
    };
  }

  // ── 2. Paper Sessions (Online Exam Hall - 1:1 Mobile Parity) ───────────────
  normalizePaperSession(raw, id) {
    if (!raw) return null;
    const now = new Date();
    const todayIso = now.toISOString().split('T')[0];

    const parseTime = (val, fallbackIso) => {
      if (!val) return fallbackIso;
      if (typeof val?.toDate === 'function') {
        try { return val.toDate().toISOString(); } catch (_) {}
      }
      if (typeof val === 'string') {
        const d = new Date(val);
        if (!isNaN(d.getTime())) return d.toISOString();
      }
      return fallbackIso;
    };

    const duration = Number(raw.durationMinutes) || 120;

    // Morning Slot default (08:30 AM today)
    const defStart1 = new Date(now);
    defStart1.setHours(8, 30, 0, 0);
    const defEnd1 = new Date(defStart1.getTime() + duration * 60000);

    // Evening Slot default (04:00 PM today)
    const defStart2 = new Date(now);
    defStart2.setHours(16, 0, 0, 0);
    const defEnd2 = new Date(defStart2.getTime() + duration * 60000);

    let rawSlot1 = raw.slot1;
    let rawSlot2 = raw.slot2;

    if (Array.isArray(raw.slots)) {
      if (!rawSlot1 && raw.slots[0]) rawSlot1 = raw.slots[0];
      if (!rawSlot2 && raw.slots[1]) rawSlot2 = raw.slots[1];
    }

    const slot1 = {
      id: rawSlot1?.id || 'slot1',
      name: rawSlot1?.name || 'Slot 1 (Morning / උදෑසන සැසිය)',
      startTime: parseTime(rawSlot1?.startTime, defStart1.toISOString()),
      endTime: parseTime(rawSlot1?.endTime, defEnd1.toISOString()),
      maxCapacity: Number(rawSlot1?.maxCapacity || rawSlot1?.capacity || 100),
      registeredCount: Number(rawSlot1?.registeredCount || (rawSlot1?.seatsLeft !== undefined ? Math.max(0, 100 - rawSlot1.seatsLeft) : 48))
    };

    let slot2 = null;
    if (rawSlot2 || (Array.isArray(raw.slots) && raw.slots.length > 1)) {
      slot2 = {
        id: rawSlot2?.id || 'slot2',
        name: rawSlot2?.name || 'Slot 2 (Evening / සවස සැසිය)',
        startTime: parseTime(rawSlot2?.startTime, defStart2.toISOString()),
        endTime: parseTime(rawSlot2?.endTime, defEnd2.toISOString()),
        maxCapacity: Number(rawSlot2?.maxCapacity || rawSlot2?.capacity || 100),
        registeredCount: Number(rawSlot2?.registeredCount || (rawSlot2?.seatsLeft !== undefined ? Math.max(0, 100 - rawSlot2.seatsLeft) : 32))
      };
    }

    const rawStatus = raw.status || 'upcoming';
    const isEnded = !!(raw.isEnded || rawStatus === 'ended' || raw.currentPhase === 'ended');
    let phase = raw.currentPhase || '';
    if (!phase) {
      if (isEnded) phase = 'ended';
      else if (raw.isTimeUp) phase = 'time_up';
      else if (rawStatus === 'active') phase = 'writing';
      else phase = 'waiting';
    }

    const isLive = !isEnded && (raw.isLive === true || rawStatus === 'active' || rawStatus === 'live' || phase === 'package_opening' || phase === 'writing' || phase === 'time_up');

    return {
      ...raw,
      id: id || raw.id || 'paper_' + Date.now(),
      title: raw.title || 'A/L Physics Paper Session',
      subject: raw.subject || 'A/L Physics',
      paperType: raw.paperType || 'essay',
      mcqCount: Math.min(50, Math.max(1, Number(raw.mcqCount) || 50)),
      mcqAnswerKey: raw.mcqAnswerKey || {},
      examYear: raw.examYear || 'All Batches',
      date: raw.date || todayIso,
      durationMinutes: duration,
      totalMarks: Number(raw.totalMarks) || 100,
      status: isEnded ? 'ended' : (isLive ? 'active' : rawStatus),
      currentPhase: phase,
      isEnded,
      isLive,
      isTimeUp: !!raw.isTimeUp,
      slot1,
      slot2,
      packageOpeningStartedAt: parseTime(raw.packageOpeningStartedAt, null),
      writingStartedAt: parseTime(raw.writingStartedAt, null),
      endedAt: parseTime(raw.endedAt, null)
    };
  }

  normalizeUpcomingPaper(raw, id) {
    if (!raw) return null;
    const now = new Date();
    const defSched = new Date(now.getTime() + 86400000 * 3);
    defSched.setHours(8, 30, 0, 0);

    const parseTime = (val, fallbackIso) => {
      if (!val) return fallbackIso;
      if (typeof val?.toDate === 'function') {
        try { return val.toDate().toISOString(); } catch (_) {}
      }
      if (typeof val === 'string') {
        const d = new Date(val);
        if (!isNaN(d.getTime())) return d.toISOString();
      }
      return fallbackIso;
    };

    return {
      ...raw,
      id: id || raw.id || 'upcoming_' + Date.now(),
      title: raw.title || 'A/L Physics Model Paper',
      subject: raw.subject || 'A/L Physics',
      examYear: raw.examYear || '2027 A/L',
      scheduledDate: parseTime(raw.scheduledDate, defSched.toISOString()),
      durationMinutes: Number(raw.durationMinutes) || 180,
      paperStructure: raw.paperStructure || '50 MCQs & 4 Structured Essay Questions',
      syllabusTopics: Array.isArray(raw.syllabusTopics) && raw.syllabusTopics.length > 0 
        ? raw.syllabusTopics 
        : ['Mechanics & Dynamics', 'Newtonian Gravitation', 'Circular Motion & Rotational Inertia'],
      hints: raw.hints || 'විභාගයට පෙර Mechanics පාඩමේ Free Body Diagrams සහ ගම්‍යතා සංස්ථිති මූලධර්ම හොඳින් පුහුණු වන්න.',
      instructions: raw.instructions || 'කරුණාකර නියමිත වේලාවට පෙර නිල විභාග පොත් පිංච සහ කැල්කියුලේටර සූදානම් කර තබාගන්න.'
    };
  }

  getMockPaperSessions(examYear) {
    const now = new Date();
    const todayIso = now.toISOString().split('T')[0];

    const s1Start = new Date(now);
    s1Start.setHours(8, 30, 0, 0);
    const s1End = new Date(now);
    s1End.setHours(10, 30, 0, 0);

    const s2Start = new Date(now);
    s2Start.setHours(16, 0, 0, 0);
    const s2End = new Date(now);
    s2End.setHours(18, 0, 0, 0);

    const list = [
      {
        id: 'mock_paper_01',
        title: '2027 A/L Physics Evaluation Paper 04 - Mechanics & Dynamics',
        subject: 'A/L Physics',
        examYear: '2027 A/L',
        date: todayIso,
        durationMinutes: 120,
        totalMarks: 100,
        status: 'upcoming',
        currentPhase: 'waiting',
        isTimeUp: false,
        slot1: {
          id: 'slot1',
          name: 'Slot 1 (Morning / උදෑසන සැසිය)',
          startTime: s1Start.toISOString(),
          endTime: s1End.toISOString(),
          maxCapacity: 100,
          registeredCount: 48
        },
        slot2: {
          id: 'slot2',
          name: 'Slot 2 (Evening / සවස සැසිය)',
          startTime: s2Start.toISOString(),
          endTime: s2End.toISOString(),
          maxCapacity: 100,
          registeredCount: 35
        }
      },
      {
        id: 'mock_paper_02',
        title: '2026 A/L Physics Grand Revision Test 02 - Oscillations & Waves',
        subject: 'A/L Physics',
        examYear: '2026 A/L',
        date: todayIso,
        durationMinutes: 180,
        totalMarks: 100,
        status: 'upcoming',
        currentPhase: 'waiting',
        isTimeUp: false,
        slot1: {
          id: 'slot1',
          name: 'Slot 1 (Morning / උදෑසන සැසිය)',
          startTime: s1Start.toISOString(),
          endTime: s1End.toISOString(),
          maxCapacity: 150,
          registeredCount: 84
        },
        slot2: {
          id: 'slot2',
          name: 'Slot 2 (Evening / සවස සැසිය)',
          startTime: s2Start.toISOString(),
          endTime: s2End.toISOString(),
          maxCapacity: 150,
          registeredCount: 62
        }
      }
    ];

    if (!examYear || examYear === 'All' || examYear === 'All Batches') return list;
    const filtered = list.filter(p => this.matchesYear(p.examYear, examYear));
    return filtered.length > 0 ? filtered : list;
  }

  getMockUpcomingPapers(examYear) {
    const now = new Date();
    const d1 = new Date(now.getTime() + 86400000 * 3);
    d1.setHours(8, 30, 0, 0);

    const d2 = new Date(now.getTime() + 86400000 * 7);
    d2.setHours(13, 30, 0, 0);

    const list = [
      {
        id: 'upcoming_01',
        title: '2027 A/L Mechanics Comprehensive Mock 01',
        subject: 'A/L Physics',
        examYear: '2027 A/L',
        scheduledDate: d1.toISOString(),
        durationMinutes: 180,
        paperStructure: '50 MCQs + 4 Structured Essays',
        syllabusTopics: ['Newtonian Mechanics', 'Rotational Dynamics', 'Hydrostatics & Surface Tension', 'Viscosity'],
        hints: 'Bernoulli මූලධර්මය සහ දුස්ස්‍රාවිතා සමීකරණ ආශ්‍රිත ප්‍රශ්න විශේෂයෙන් පුහුණු වන්න. 2018-2024 පසුගිය විභාග ප්‍රශ්න අධ්‍යයනය කරන්න.',
        instructions: 'නිල පිළිතුරු පත්‍ර සහ අවශ්‍ය මිනුම් උපකරණ සූදානම් කර තබාගන්න.'
      },
      {
        id: 'upcoming_02',
        title: '2026 A/L Island-Wide Physics Trial Examination',
        subject: 'A/L Physics',
        examYear: '2026 A/L',
        scheduledDate: d2.toISOString(),
        durationMinutes: 180,
        paperStructure: 'Full Standard Exam (Part I & Part II)',
        syllabusTopics: ['Waves & Oscillations', 'Thermal Physics', 'Electrostatics & Current Electricity'],
        hints: 'ඩොප්ලර් ආචරණය, තරංග ආක්‍රමණය සහ Kirchhoff නීති පරිපථ ගැටළු හොඳින් නැවත බලාගන්න.',
        instructions: 'විභාගයට මිනිත්තු 15 කට පෙර Waiting Room වෙත සම්බන්ධ වන්න.'
      }
    ];

    if (!examYear || examYear === 'All' || examYear === 'All Batches') return list;
    const filtered = list.filter(p => this.matchesYear(p.examYear, examYear));
    return filtered.length > 0 ? filtered : list;
  }

  async getPaperSessions(examYear) {
    try {
      const ref = collection(db, 'paper_sessions');
      const snap = await getDocs(ref);
      if (!snap.empty) {
        const list = snap.docs.map(d => this.normalizePaperSession(d.data(), d.id)).filter(Boolean);
        const filtered = list.filter(p => this.matchesYear(p.examYear, examYear));
        if (filtered.length > 0) return filtered;
        // If no paper matches student batch, but active/live or upcoming real papers exist in Firestore, return them!
        const liveOrUpcoming = list.filter(p => !p.isEnded && p.status !== 'ended' && p.currentPhase !== 'ended');
        if (liveOrUpcoming.length > 0) return liveOrUpcoming;
        if (list.length > 0) return list;
      }
    } catch (e) {
      console.warn('[DB] getPaperSessions error:', e);
    }
    return [];
  }

  async getPaperSession(paperId) {
    if (!paperId) return null;
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      const snap = await getDoc(docRef);
      if (snap.exists()) {
        return this.normalizePaperSession(snap.data(), snap.id);
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
          callback(this.normalizePaperSession(docSnap.data(), docSnap.id));
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
        const list = snap.docs.map(d => this.normalizeUpcomingPaper(d.data(), d.id)).filter(Boolean);
        const filtered = list.filter(p => this.matchesYear(p.examYear, examYear));
        if (filtered.length > 0) return filtered;
        if (list.length > 0 && (!examYear || examYear === 'All' || examYear === 'All Batches')) return list;
      }
    } catch (e) {
      console.warn('[DB] getUpcomingPapers error:', e);
    }
    return [];
  }

  async registerStudentSlot({ paperId, studentId, studentName, studentPhone, slotId }) {
    if (!paperId || !studentId) return null;
    const existing = await this.getStudentRegistration(paperId, studentId);
    if (existing && (existing.status === 'submitted' || existing.isSubmitted === true || (existing.submissionPhotos && existing.submissionPhotos.length > 0))) {
      return existing; // DO NOT OVERWRITE SUBMITTED STATE!
    }
    const regData = { paperId, studentId, studentName, studentPhone, selectedSlot: slotId, status: 'registered', isCameraActive: false, registeredAt: new Date().toISOString() };
    try {
      await callBackend('papers/register-slot', { paperId, slotId });
    } catch (error) {
      console.warn('[DB] Backend paper registration notice, saving direct record:', error);
      try {
        await setDoc(doc(db, 'paper_registrations', `${paperId}_${studentId}`), regData, { merge: true });
      } catch (directErr) {
        console.warn('[DB] Direct registration write error:', directErr);
      }
    }
    return regData;
  }

  async getStudentRegistration(paperId, studentId) {
    if (!paperId || !studentId) return null;
    try {
      const snap = await getDoc(doc(db, 'paper_registrations', `${paperId}_${studentId}`));
      return snap.exists() ? { id: snap.id, ...snap.data() } : null;
    } catch (error) {
      console.warn('[DB] getStudentRegistration error:', error);
      return null;
    }
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

  // ── Live Proctor Camera Heartbeat & Snapshot Synchronizer ──
  async updateCameraHeartbeat({
    paperId,
    studentId,
    isCameraActive,
    studentName,
    studentPhone,
    slotId,
    cameraSnapshotUrl,
    status,
    submissionPhotos,
    agoraUid,
    paperType,
    mcqAnswers,
    mcqScore,
    mcqTotal,
    mcqMarks,
    mcqPercentage,
    reviewDetails
  }) {
    if (!paperId || !studentId) return;
    try {
      const regDocId = `${paperId}_${studentId}`;
      const regRef = doc(db, 'paper_registrations', regDocId);
      const updates = {
        paperId,
        studentId,
        isCameraActive: !!isCameraActive,
        lastCameraPing: serverTimestamp()
      };
      if (studentName && String(studentName).trim()) {
        updates.studentName = String(studentName).trim();
      }
      if (studentPhone && String(studentPhone).trim()) {
        updates.studentPhone = String(studentPhone).trim();
      }
      if (slotId && String(slotId).trim()) {
        updates.selectedSlot = String(slotId).trim();
      }
      if (cameraSnapshotUrl && String(cameraSnapshotUrl).trim()) {
        const trimmed = String(cameraSnapshotUrl).trim();
        if (trimmed.length < 500000) {
          updates.cameraSnapshotUrl = trimmed;
        }
      }
      if (agoraUid) {
        updates.agoraUid = agoraUid;
      }
      if (paperType) {
        updates.paperType = paperType;
      }
      if (mcqAnswers) {
        updates.mcqAnswers = mcqAnswers;
      }
      if (mcqScore !== undefined && mcqScore !== null) {
        updates.mcqScore = Number(mcqScore);
      }
      if (mcqTotal !== undefined && mcqTotal !== null) {
        updates.mcqTotal = Number(mcqTotal);
      }
      if (mcqMarks !== undefined && mcqMarks !== null) {
        updates.mcqMarks = Number(mcqMarks);
      }
      if (mcqPercentage !== undefined && mcqPercentage !== null) {
        updates.mcqPercentage = Number(mcqPercentage);
      }
      if (reviewDetails && Array.isArray(reviewDetails)) {
        updates.reviewDetails = reviewDetails;
      }
      if (status) {
        updates.status = status;
        if (status === 'in_exam') {
          updates.joinedAt = serverTimestamp();
        } else if (status === 'submitted') {
          updates.submittedAt = serverTimestamp();
          updates.isSubmitted = true;
        }
      }
      if (submissionPhotos && Array.isArray(submissionPhotos) && submissionPhotos.length > 0) {
        updates.submissionPhotos = submissionPhotos;
        updates.submissionUrl = submissionPhotos[0];
        updates.isSubmitted = true;
        updates.status = 'submitted';
      }

      await setDoc(regRef, updates, { merge: true });
    } catch (e) {
      console.warn('[DB] updateCameraHeartbeat error:', e);
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
        isLive: false,
        isEnded: true,
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
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      await updateDoc(docRef, {
        status: 'active',
        currentPhase: 'waiting',
        isLive: true,
        isEnded: false
      });
    } catch (e) {
      console.warn('[DB] reopenPaperSession error:', e);
    }
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

  async updatePaperSession(paperId, updates) {
    if (!paperId || !updates) return false;
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      await updateDoc(docRef, updates);
      return true;
    } catch (e) {
      console.warn('[DB] updatePaperSession error:', e);
      return false;
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

  streamProctorAlerts(paperId, studentId, callback) {
    if (!paperId) return () => {};
    try {
      const alertsRef = collection(db, 'proctor_alerts');
      let targeted = [];
      let broadcast = [];
      const emit = () => callback([...targeted, ...broadcast].filter(item => !item.isRead));
      let stopTargeted = () => {};
      if (studentId) {
        stopTargeted = onSnapshot(query(alertsRef, where('paperId', '==', paperId), where('studentId', '==', studentId)), snapshot => {
          targeted = snapshot.docs.map(d => ({ id: d.id, ...d.data() })); emit();
        }, err => console.warn('[DB] targeted proctor alerts failed:', err));
      }
      const stopBroadcast = onSnapshot(query(alertsRef, where('paperId', '==', paperId), where('studentId', '==', 'ALL')), snapshot => {
        broadcast = snapshot.docs.map(d => ({ id: d.id, ...d.data() })); emit();
      }, err => console.warn('[DB] broadcast proctor alerts failed:', err));
      return () => { stopTargeted(); stopBroadcast(); };
    } catch (e) {
      console.warn('[DB] streamProctorAlerts catch:', e);
      return () => {};
    }
  }

  async markProctorAlertRead(alertId) {
    if (!alertId) return;
    try {
      const alertRef = doc(db, 'proctor_alerts', alertId);
      await updateDoc(alertRef, { isRead: true });
    } catch (e) {
      console.warn('[DB] markProctorAlertRead error:', e);
    }
  }

  streamStudentAlerts(paperId, studentId, callback) {
    return this.streamProctorAlerts(paperId, studentId, callback);
  }

  async markAlertRead(alertId) {
    return this.markProctorAlertRead(alertId);
  }

  async recordSprintAttempt(attemptData) {
    try {
      const result = await callBackend('sprints/submit-attempt', {
        date: attemptData.date,
        answers: attemptData.answers,
        timeTakenSeconds: attemptData.timeTakenSeconds
      });
      return result;
    } catch (e) {
      console.warn('[DB] recordSprintAttempt error:', e);
      throw e;
    }
  }

  async updateUserProfile(uid, updates) {
    if (!uid) return;
    try {
      const userRef = doc(db, 'users', uid);
      await setDoc(userRef, updates, { merge: true });
    } catch (e) {
      console.warn('[DB] updateUserProfile error:', e);
    }
  }

  // ── 3. Daily MCQ Sprint ──────────────────────────────────────────────────
  async getDailySprint(dateStr, examYear) {
    const targetDate = dateStr || new Date().toISOString().slice(0, 10);
    const snap = await getDocs(collection(db, 'daily_sprints'));
    const matching = snap.docs
      .map(d => ({ id: d.id, ...d.data() }))
      .filter(s => s.targetDate === targetDate && (!s.examYear || s.examYear === 'All Batches' || !examYear || s.examYear === examYear))
      .sort((a, b) => Number(a.examYear === 'All Batches') - Number(b.examYear === 'All Batches'));
    return matching[0] || null;
  }

  async getDailySprints() {
    const snapshot = await getDocs(collection(db, 'daily_sprints'));
    return snapshot.docs
      .map((sprintDoc) => ({ id: sprintDoc.id, ...sprintDoc.data() }))
      .sort((a, b) => String(b.targetDate || '').localeCompare(String(a.targetDate || '')));
  }

  async publishDailySprint({ title, subject, unit, targetDate, examYear, questions }) {
    const safeDate = String(targetDate || '');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(safeDate) || !Array.isArray(questions) || questions.length !== 5) {
      throw new Error('Enter a valid date and all five questions.');
    }
    const batch = String(examYear || 'All Batches');
    const docId = batch === 'All Batches'
      ? safeDate
      : `${safeDate}_${batch.replaceAll(' ', '_').replaceAll('/', '_')}`;
    await setDoc(doc(db, 'daily_sprints', docId), {
      title: `🔥 ${String(title || 'Daily 5-MCQ Sprint').trim()} - ${String(unit || '').trim()}`,
      subject: String(subject || 'Physics'),
      unit: String(unit || '').trim(),
      targetDate: safeDate,
      examYear: batch,
      xpPerQuestion: 10,
      questions: questions.map((question, index) => ({
        qNum: index + 1,
        question: String(question.question || '').trim(),
        options: (question.options || []).map((option) => String(option || '').trim()),
        correctIndex: Number(question.correctIndex) || 0,
        explanation: String(question.explanation || '').trim(),
      })),
      createdAt: new Date(),
    });
    return docId;
  }

  async deleteDailySprint(id) {
    if (!id) return;
    await deleteDoc(doc(db, 'daily_sprints', id));
  }

  // ── 4. Leaderboard ───────────────────────────────────────────────────────
  async getLeaderboard(batch) {
    const snapshot = await getDocs(collection(db, 'leaderboard_public'));
    return snapshot.docs.map((studentDoc) => {
      const student = studentDoc.data();
      return {
      rank: 0,
      id: studentDoc.id,
      role: 'student',
      name: student.name || 'Student',
      examYear: student.examYear || '',
      credits: Number(student.credits) || 0,
      avatarUrl: student.avatarUrl || student.photoUrl || '',
      };
    }).filter((student) => !batch || batch === 'All Batches'
      || String(student.examYear).replace(/\s+/g, '').toUpperCase() === String(batch).replace(/\s+/g, '').toUpperCase()
      || ['ALL', 'ALLBATCHES'].includes(String(student.examYear).replace(/\s+/g, '').toUpperCase()))
      .sort((a, b) => b.credits - a.credits || a.name.localeCompare(b.name));
  }

  async getPaperLeaderboards() {
    const snapshot = await getDocs(collection(db, 'paper_leaderboards'));
    return snapshot.docs.map((paperDoc) => {
      const data = paperDoc.data();
      const rawPublishedAt = data.publishedAt;
      const publishedAt = rawPublishedAt?.toDate
        ? rawPublishedAt.toDate()
        : new Date(rawPublishedAt || Date.now());
      const entries = Array.isArray(data.entries) ? data.entries.map((entry, index) => ({
        rank: Number(entry?.rank) || index + 1,
        studentId: String(entry?.studentId || ''),
        studentName: String(entry?.studentName || 'Student'),
        studentPhone: String(entry?.studentPhone || ''),
        indexNumber: String(entry?.indexNumber || ''),
        marks: Number(entry?.marks) || 0,
        grade: String(entry?.grade || 'F').toUpperCase(),
        remarks: String(entry?.remarks || ''),
      })).sort((a, b) => a.rank - b.rank) : [];

      return {
        id: paperDoc.id,
        paperTitle: String(data.paperTitle || 'Paper Evaluation Leaderboard'),
        subject: String(data.subject || 'Physics'),
        examYear: String(data.examYear || ''),
        paperDate: String(data.paperDate || ''),
        totalMarks: Number(data.totalMarks) || 100,
        publishedAt: Number.isNaN(publishedAt.getTime()) ? new Date(0) : publishedAt,
        entries,
      };
    }).sort((a, b) => b.publishedAt - a.publishedAt);
  }

  async getSprintAttempts(date) {
    const snapshot = await getDocs(query(
      collection(db, 'sprint_attempts'),
      where('date', '==', date),
      limit(200),
    ));
    return snapshot.docs
      .map((attempt) => ({ id: attempt.id, ...attempt.data() }))
      .sort((a, b) => Number(b.score || 0) - Number(a.score || 0)
        || Number(a.timeTakenSeconds || 0) - Number(b.timeTakenSeconds || 0));
  }

  // ── 5. Daily Physics Insight (1:1 with DailyPhysicsInsightService & Model) ──
  getPresetPhysicsInsights() {
    return [
      {
        isCustom: true,
        titleSinhala: 'කාර්යය-ශක්ති ප්‍රමේයය',
        titleEnglish: 'Work-Energy Theorem & Friction Losses',
        unitSinhala: 'යාන්ත්‍ර විද්‍යාව',
        unitEnglish: 'Mechanics',
        formula: 'W_net  =  ΔK  =  ½ m v²  -  ½ m u²',
        tipSinhala: 'ආනත තලයක චලිතයේදී ඝර්ෂණයට එරෙහි කාර්යය (W_f = -f · s) යාන්ත්‍රික ශක්ති සමීකරණයට පෙර වෙන්ව සලකා බලන්න.',
        tipEnglish: 'Always compute work done against friction W_f = -f · s separately before equating mechanical energy at the base of an incline.',
        topicCode: 'topic_work_energy'
      },
      {
        isCustom: true,
        titleSinhala: 'වක්‍ර මාර්ගවල බැංකු නැංවීම',
        titleEnglish: 'Banking of Roads & Circular Motion',
        unitSinhala: 'වෘත්ත චලිතය',
        unitEnglish: 'Circular Motion',
        formula: 'tan θ  =  v² / (r · g)',
        tipSinhala: 'ඝර්ෂණය රහිත උපරිම ආරක්ෂිත ප්‍රවේගය (v) සඳහා අභිකේන්ද්‍ර බලය සැපයෙන්නේ අභිලම්භ ප්‍රතික්‍රියාවේ තිරස් සංරචකය (R sin θ) මගිනි.',
        tipEnglish: 'For frictionless optimal banking speed v, the centripetal force is provided solely by the horizontal normal component R sin θ.',
        topicCode: 'topic_circular_motion'
      },
      {
        isCustom: true,
        titleSinhala: 'ඩොප්ලර් ආචරණය',
        titleEnglish: 'Doppler Effect in Sound Waves',
        unitSinhala: 'තරංග හා දෝලන',
        unitEnglish: 'Waves & Sound',
        formula: "f'  =  f₀ [ (v ± v₀) / (v ∓ v_s) ]",
        tipSinhala: 'ප්‍රභවය සහ නිරීක්ෂකයා එකිනෙකා වෙත ළඟා වන විට සංඛ්‍යාතය වැඩි වන බව (f\' > f₀) ලකුණු තේරීමේදී මතක තබා ගන්න.',
        tipEnglish: 'Apparent frequency increases when source and observer approach each other, and decreases when moving apart.',
        topicCode: 'topic_doppler_effect'
      },
      {
        isCustom: true,
        titleSinhala: 'ලෙන්ස්ගේ නියමය සහ වි.ගා.බ. ප්‍රේරණය',
        titleEnglish: "Lenz's Law & Faraday Induction",
        unitSinhala: 'විද්‍යුත් චුම්භකත්වය',
        unitEnglish: 'Electromagnetism',
        formula: 'ε  =  - N ( ΔΦ / Δt )',
        tipSinhala: 'සෘණ ලකුණෙන් දැක්වෙන්නේ ප්‍රේරිත ධාරාව සැමවිටම එය ඇතිවීමට හේතු වූ චුම්භක ස්‍රාව වෙනසට විරුද්ධ වන බවයි (ශක්ති සංස්ථිති නියමය).',
        tipEnglish: 'The negative sign indicates induced current magnetic field opposes the original flux change (Conservation of Energy).',
        topicCode: 'topic_lenz_law'
      },
      {
        isCustom: true,
        titleSinhala: 'වියෝග ප්‍රවේගය (මිදීමේ ප්‍රවේගය)',
        titleEnglish: 'Gravitational Escape Velocity',
        unitSinhala: 'ගුරුත්වාකර්ෂණ ක්ෂේත්‍ර',
        unitEnglish: 'Gravitational Fields',
        formula: 'v_e  =  √( 2 G M / R )  =  √( 2 g R )',
        tipSinhala: 'වියෝග ප්‍රවේගය ප්‍රක්ෂේපිත වස්තුවේ ස්කන්ධය හෝ විදින කෝණය මත රඳා නොපවතී; එය ග්‍රහලෝකයේ ස්කන්ධය හා අරය මත පමණක් රඳා පවතී.',
        tipEnglish: 'Escape velocity is independent of projectile mass and angle; it depends solely on the planet mass and radius.',
        topicCode: 'topic_escape_velocity'
      },
      {
        isCustom: true,
        titleSinhala: 'ධාරිත්‍රකයක ගබඩා වන ශක්තිය',
        titleEnglish: 'Electrostatic Energy in Capacitors',
        unitSinhala: 'ස්ථිති විද්‍යුතය',
        unitEnglish: 'Electrostatics',
        formula: 'U  =  ½ C V²  =  ½ Q V  =  ½ Q² / C',
        tipSinhala: 'බැටරියෙන් සපයන ශක්තිය (Q V) වන අතර, ඉන් හරියටම අඩක් ප්‍රතිරෝධ මගින් තාපය ලෙස හානි වී ඉතිරි අර්ධය (½ Q V) පමණක් විද්‍යුත් ක්ෂේත්‍රයේ ගබඩා වේ.',
        tipEnglish: 'The charging source delivers work W = QV, but exactly 50% is dissipated as thermal loss, leaving U = ½QV in the capacitor field.',
        topicCode: 'topic_capacitors'
      },
      {
        isCustom: true,
        titleSinhala: 'තාපගති විද්‍යාවේ පළමු නියමය',
        titleEnglish: 'First Law of Thermodynamics',
        unitSinhala: 'තාප භෞතික විද්‍යාව',
        unitEnglish: 'Thermal Physics',
        formula: 'ΔQ  =  ΔU  +  ΔW  (ΔW = P ΔV)',
        tipSinhala: 'සමපරිමා ක්‍රියාවලිවලදී පරිමාව වෙනස් නොවන බැවින් ΔW = 0 වන අතර ලබාදෙන සියලු තාපය අභ්‍යන්තර ශක්තිය වැඩිකරයි (ΔQ = ΔU).',
        tipEnglish: 'In isochoric processes ΔW = 0 since volume is constant, so all absorbed heat increases internal energy ΔQ = ΔU.',
        topicCode: 'topic_thermodynamics'
      },
      {
        isCustom: true,
        titleSinhala: 'ප්‍රකාශ විද්‍යුත් ආචරණය',
        titleEnglish: 'Photoelectric Effect & Photons',
        unitSinhala: 'නූතන භෞතික විද්‍යාව',
        unitEnglish: 'Modern Physics',
        formula: 'h f  =  Φ  +  ½ m v_max²  =  Φ  +  e V_s',
        tipSinhala: 'නැවැත්වීමේ විභවය (V_s) රඳා පවතින්නේ ආලෝකයේ සංඛ්‍යාතය (f) මත පමණි; ආලෝක තීව්‍රතාව වැඩි කළද V_s වෙනස් නොවේ.',
        tipEnglish: 'Stopping potential V_s depends solely on frequency f and metal work function Φ, never on incident light intensity.',
        topicCode: 'topic_photoelectric'
      },
      {
        isCustom: true,
        titleSinhala: 'බර්නූලිගේ මූලධර්මය',
        titleEnglish: "Bernoulli's Principle & Fluid Flow",
        unitSinhala: 'තරල විද්‍යාව',
        unitEnglish: 'Hydrodynamics',
        formula: 'P  +  ½ ρ v²  +  ρ g h  =  Constant',
        tipSinhala: 'තිරස් නලයක ද්‍රව ප්‍රවේගය (v) වැඩි වන සිහින් ස්ථානවල පීඩනය (P) අඩුවේ (Venturi ආචරණය).',
        tipEnglish: 'For horizontal streamline flow, locations with higher velocity experience lower fluid pressure (Venturi effect).',
        topicCode: 'topic_bernoulli'
      },
      {
        isCustom: true,
        titleSinhala: 'පොටෙන්ෂියෝමීටරය හා අභ්‍යන්තර ප්‍රතිරෝධය',
        titleEnglish: 'Potentiometer & Internal Resistance',
        unitSinhala: 'ධාරා විද්‍යුතය',
        unitEnglish: 'Current Electricity',
        formula: 'r  =  R [ ( l₁ - l₂ ) / l₂ ]',
        tipSinhala: 'සමතුලිත අවස්ථාවේදී කෝෂයෙන් ධාරාවක් නොගලා යන බැවින් අග්‍රස්ථ විභව අන්තරය වෙනුවට නිවැරදිම විද්‍යුත් ගාමක බලය (EMF) මැනේ.',
        tipEnglish: 'At balance point zero current flows through the galvanometer, measuring the true EMF without internal resistance voltage drops.',
        topicCode: 'topic_potentiometer'
      }
    ];
  }

  async getDailyInsight() {
    try {
      const docRef = doc(db, 'system_config', 'daily_physics_insight');
      const snap = await getDoc(docRef);
      if (snap.exists()) {
        const data = snap.data();
        if (data && data.isCustom) {
          return {
            isCustom: true,
            concept: data.titleEnglish || data.titleSinhala || 'Physics Daily Concept',
            formula: data.formula || '',
            summary: data.tipEnglish || data.tipSinhala || '',
            examTip: data.tipSinhala || data.tipEnglish || '',
            titleSinhala: data.titleSinhala || '',
            titleEnglish: data.titleEnglish || '',
            unitSinhala: data.unitSinhala || '',
            unitEnglish: data.unitEnglish || '',
            tipSinhala: data.tipSinhala || '',
            tipEnglish: data.tipEnglish || '',
            topicCode: data.topicCode || 'topic_custom'
          };
        }
      }
    } catch (e) {
      console.warn('Daily insight cloud fetch warning, falling back to rotation:', e);
    }

    const presets = this.getPresetPhysicsInsights();
    const dayOfYear = Math.floor((new Date() - new Date(new Date().getFullYear(), 0, 0)) / (1000 * 60 * 60 * 24));
    const p = presets[dayOfYear % presets.length];
    return {
      isCustom: false,
      concept: p.titleEnglish,
      formula: p.formula,
      summary: p.tipEnglish,
      examTip: p.tipSinhala,
      titleSinhala: p.titleSinhala,
      titleEnglish: p.titleEnglish,
      unitSinhala: p.unitSinhala,
      unitEnglish: p.unitEnglish,
      tipSinhala: p.tipSinhala,
      tipEnglish: p.tipEnglish,
      topicCode: p.topicCode
    };
  }

  async saveCustomPhysicsInsight(data, adminName = 'Admin') {
    try {
      const docRef = doc(db, 'system_config', 'daily_physics_insight');
      await setDoc(docRef, {
        isCustom: true,
        titleSinhala: (data.titleSinhala || '').trim(),
        titleEnglish: (data.titleEnglish || '').trim(),
        unitSinhala: (data.unitSinhala || '').trim(),
        unitEnglish: (data.unitEnglish || '').trim(),
        formula: (data.formula || '').trim(),
        tipSinhala: (data.tipSinhala || '').trim(),
        tipEnglish: (data.tipEnglish || '').trim(),
        topicCode: (data.topicCode || 'topic_custom').trim(),
        updatedAt: serverTimestamp(),
        updatedBy: adminName
      }, { merge: true });
      return true;
    } catch (e) {
      console.error('Error saving custom physics insight:', e);
      throw e;
    }
  }

  async setRandomPhysicsInsightMode(adminName = 'Admin') {
    try {
      const docRef = doc(db, 'system_config', 'daily_physics_insight');
      await setDoc(docRef, {
        isCustom: false,
        updatedAt: serverTimestamp(),
        updatedBy: adminName
      }, { merge: true });
      return true;
    } catch (e) {
      console.error('Error resetting to random physics insight:', e);
      throw e;
    }
  }

  // ── 6. Exam Countdowns (1:1 with ExamCountdownService & Model) ──────────────
  getDefaultExamCountdowns() {
    return [
      {
        id: '2025_al',
        examYear: '2025 A/L',
        customTitle: '2025 G.C.E. Advanced Level Examination',
        targetDate: new Date('2025-11-25T08:30:00Z').toISOString(),
        isEnabled: true,
        notes: 'Official National Examination Period'
      },
      {
        id: '2026_al',
        examYear: '2026 A/L',
        customTitle: '2026 G.C.E. Advanced Level Examination',
        targetDate: new Date('2026-11-25T08:30:00Z').toISOString(),
        isEnabled: true,
        notes: 'Official National Examination Period'
      },
      {
        id: '2027_al',
        examYear: '2027 A/L',
        customTitle: '2027 G.C.E. Advanced Level Examination',
        targetDate: new Date('2027-11-25T08:30:00Z').toISOString(),
        isEnabled: true,
        notes: 'Target date countdown active for 2027 batch'
      },
      {
        id: '2028_al',
        examYear: '2028 A/L',
        customTitle: '2028 G.C.E. Advanced Level Examination',
        targetDate: new Date('2028-11-25T08:30:00Z').toISOString(),
        isEnabled: true,
        notes: 'Target date countdown active for 2028 batch'
      },
      {
        id: '2029_al',
        examYear: '2029 A/L',
        customTitle: '2029 G.C.E. Advanced Level Examination',
        targetDate: new Date('2029-11-25T08:30:00Z').toISOString(),
        isEnabled: true,
        notes: 'Target date countdown active for 2029 batch'
      }
    ];
  }

  async getExamCountdowns() {
    try {
      const colRef = collection(db, 'exam_countdowns');
      const snap = await getDocs(colRef);
      if (!snap.empty) {
        const list = snap.docs.map(d => {
          const data = d.data();
          let target = data.targetDate;
          if (target && target.toDate) target = target.toDate().toISOString();
          else if (target && typeof target === 'string') target = new Date(target).toISOString();
          else target = new Date().toISOString();

          return {
            id: d.id,
            examYear: data.examYear || d.id,
            customTitle: data.customTitle || `${data.examYear || d.id} Exam`,
            targetDate: target,
            isEnabled: data.isEnabled !== false,
            notes: data.notes || ''
          };
        });

        // Sort by year
        list.sort((a, b) => {
          const numA = parseInt((a.examYear.match(/\d{4}/) || [0])[0]);
          const numB = parseInt((b.examYear.match(/\d{4}/) || [0])[0]);
          return numA - numB;
        });
        return list;
      }
    } catch (e) {
      console.warn('Error reading exam countdowns from Firestore:', e);
    }

    return this.getDefaultExamCountdowns();
  }

  async updateExamCountdown(id, data, adminName = 'Admin') {
    try {
      const docRef = doc(db, 'exam_countdowns', id);
      const payload = {
        ...data,
        updatedAt: serverTimestamp(),
        updatedBy: adminName
      };
      if (payload.targetDate && typeof payload.targetDate === 'string') {
        payload.targetDate = new Date(payload.targetDate);
      }
      await setDoc(docRef, payload, { merge: true });
      return true;
    } catch (e) {
      console.error('Error updating exam countdown:', e);
      throw e;
    }
  }

  async addExamCountdown(data, adminName = 'Admin') {
    try {
      const id = (data.examYear || 'exam').toLowerCase().replace(/[^a-z0-9]/g, '_');
      const docRef = doc(db, 'exam_countdowns', id);
      const payload = {
        examYear: data.examYear,
        customTitle: data.customTitle || `${data.examYear} Examination`,
        targetDate: new Date(data.targetDate),
        isEnabled: data.isEnabled !== false,
        notes: data.notes || '',
        updatedAt: serverTimestamp(),
        updatedBy: adminName
      };
      await setDoc(docRef, payload);
      return id;
    } catch (e) {
      console.error('Error adding exam countdown:', e);
      throw e;
    }
  }

  async deleteExamCountdown(id) {
    try {
      const docRef = doc(db, 'exam_countdowns', id);
      await deleteDoc(docRef);
      return true;
    } catch (e) {
      console.error('Error deleting exam countdown:', e);
      throw e;
    }
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

}

export const dbService = new DbService();
