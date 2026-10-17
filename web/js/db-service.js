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
  serverTimestamp,
  increment
} from './firebase-config.js';
import { callBackend } from './backend-api.js';
import { supabase, getSuperPaperBatchAccess, grantSuperPaperAccess, revokeSuperPaperAccess } from './supabase-client.js';

export function normalizePhone(rawPhone) {
  if (!rawPhone) return '';
  let cleaned = String(rawPhone).replace(/[^\d+]/g, '').trim();
  if (cleaned.startsWith('+94')) {
    cleaned = '0' + cleaned.slice(3);
  } else if (cleaned.startsWith('94') && cleaned.length >= 11) {
    cleaned = '0' + cleaned.slice(2);
  }
  return cleaned;
}

export class DbService {
  constructor() {
    this.dessertListeners = [];
    try {
      if (typeof localStorage !== 'undefined') {
        for (let i = 0; i < localStorage.length; i++) {
          const k = localStorage.key(i);
          if (k && (k.startsWith('edupeak_credits') || k.includes('credit'))) {
            const v = localStorage.getItem(k);
            if (v === '355' || v === '155' || v === '305') {
              localStorage.setItem(k, '200');
            }
          }
        }
        const localLb = JSON.parse(localStorage.getItem('edupeak_local_leaderboard') || '[]');
        let lbChanged = false;
        localLb.forEach(entry => {
          if (entry.credits === 355 || entry.credits === 155 || entry.credits === 305) {
            entry.credits = 200;
            lbChanged = true;
          }
        });
        if (lbChanged) localStorage.setItem('edupeak_local_leaderboard', JSON.stringify(localLb));
      }
    } catch (_) {}
    this._memCache = new Map();
    this._revalidating = new Set();
  }

  _isAdminActive() {
    try {
      if (typeof window !== 'undefined' && window.app && window.app.currentUser) {
        if (window.app.currentUser.role === 'admin' || window.app.currentMode === 'admin') return true;
      }
      if (typeof localStorage !== 'undefined') {
        const raw = localStorage.getItem('edupeak_cached_user') || localStorage.getItem('edupeak_auth_user');
        if (raw) {
          const u = JSON.parse(raw);
          if (u && (u.role === 'admin' || u.role === 'teacher')) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  getPersistentCache(key) {
    if (this._isAdminActive()) return null;
    try {
      if (typeof localStorage !== 'undefined') {
        const stored = localStorage.getItem(`edupeak_swr_${key}`) || localStorage.getItem(`edupeak_cached_${key}`);
        if (stored) {
          return JSON.parse(stored);
        }
      }
    } catch (_) {}
    return null;
  }

  setPersistentCache(key, data) {
    if (this._isAdminActive()) return;
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem(`edupeak_swr_${key}`, JSON.stringify(data));
      }
    } catch (_) {}
  }

  getCached(key, maxAgeMs = 120000) {
    if (this._isAdminActive()) return null;
    const item = this._memCache.get(key);
    if (item && (Date.now() - item.time < maxAgeMs)) {
      return item.data;
    }
    const persistent = this.getPersistentCache(key);
    if (persistent) {
      this._memCache.set(key, { data: persistent, time: Date.now() });
      return persistent;
    }
    return null;
  }

  setCache(key, data) {
    if (this._isAdminActive()) return;
    this._memCache.set(key, { data, time: Date.now() });
    this.setPersistentCache(key, data);
  }

  hasCacheForTab(tabName, user = null) {
    if (this._isAdminActive()) return false;
    const year = user?.examYear || '2027 A/L';
    const sId = user?.studentId || user?.uid || user?.id || '';
    const sPhone = user?.phone || '';
    const sName = user?.name || '';
    if (tabName === 'home') {
      return !!(this.getCached(`paper_sessions_${year}`) || this.getCached('daily_physics_insight'));
    }
    if (tabName === 'papers') {
      return !!(this.getCached(`paper_sessions_${year}`) || this.getCached(`paper_hints_${year}`));
    }
    if (tabName === 'ranks') {
      return !!(this.getCached(`leaderboard_${year}`) || this.getCached('leaderboard_all') || this.getCached('paper_leaderboards'));
    }
    if (tabName === 'desserts') {
      return !!(this.getCached(`desserts_${sId}_${sPhone}_${sName}`) || localStorage.getItem('edupeak_local_desserts'));
    }
    if (tabName === 'profile') {
      return !!(localStorage.getItem('edupeak_cached_user') || localStorage.getItem('edupeak_auth_user'));
    }
    return false;
  }

  invalidateCache(key) {
    if (!key) return;
    this._memCache.delete(key);
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.removeItem(`edupeak_swr_${key}`);
        localStorage.removeItem(`edupeak_cached_${key}`);
      }
    } catch (_) {}
  }

  invalidateRegistrationCache(paperId, studentId, phone = '') {
    if (studentId) {
      this.invalidateCache(`all_regs_${studentId}`);
      if (paperId) this.invalidateCache(`paper_reg_${paperId}_${studentId}`);
    }
    if (phone) {
      const norm = normalizePhone(phone);
      if (norm) {
        this.invalidateCache(`all_regs_${norm}`);
        if (paperId) this.invalidateCache(`paper_reg_${paperId}_${norm}`);
      }
    }
    this.clearCache('paper_sessions');
    this.clearCache('all_regs');
  }

  clearCache(prefix) {
    if (!prefix) {
      this._memCache.clear();
      try {
        if (typeof localStorage !== 'undefined') {
          for (let i = localStorage.length - 1; i >= 0; i--) {
            const k = localStorage.key(i);
            if (k && (k.startsWith('edupeak_swr_') || k.startsWith('edupeak_cached_'))) {
              localStorage.removeItem(k);
            }
          }
        }
      } catch (_) {}
      return;
    }
    for (const k of Array.from(this._memCache.keys())) {
      if (k.startsWith(prefix)) this._memCache.delete(k);
    }
    try {
      if (typeof localStorage !== 'undefined') {
        for (let i = localStorage.length - 1; i >= 0; i--) {
          const k = localStorage.key(i);
          if (k && (k.startsWith(`edupeak_swr_${prefix}`) || k.startsWith(`edupeak_cached_${prefix}`))) {
            localStorage.removeItem(k);
          }
        }
      }
    } catch (_) {}
  }

  // ── 1. Desserts (Homework Submissions) ─────────────────────────────────────
  async getStudentDesserts(studentId, studentPhone, studentName, { forceRefresh = false } = {}) {
    const cacheKey = `desserts_${studentId || ''}_${studentPhone || ''}_${studentName || ''}`;
    if (!forceRefresh && !this._isAdminActive()) {
      const cached = this.getCached(cacheKey);
      if (cached && Array.isArray(cached) && cached.length > 0) {
        if (!this._revalidating.has(cacheKey)) {
          this._revalidating.add(cacheKey);
          setTimeout(() => {
            this.getStudentDesserts(studentId, studentPhone, studentName, { forceRefresh: true })
              .then(fresh => {
                this._revalidating.delete(cacheKey);
                if (fresh && JSON.stringify(fresh) !== JSON.stringify(cached)) {
                  window.dispatchEvent(new CustomEvent('edupeak:swr-updated', { detail: { type: 'desserts', data: fresh } }));
                }
              }).catch(() => { this._revalidating.delete(cacheKey); });
          }, 400);
        }
        return cached;
      }
    }
    let localList = [];
    try {
      localList = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
    } catch (_) {}

    const cleanId = String(studentId || '').trim();
    const cleanPhone = String(studentPhone || '').replace(/\D/g, '');
    const cleanName = String(studentName || '').trim().toLowerCase();

    const list = [];
    try {
      const dessertsRef = collection(db, 'desserts');
      const q = query(dessertsRef, orderBy('submittedAt', 'desc'), limit(60));
      const snap = await Promise.race([
        getDocs(q),
        new Promise((_, reject) => setTimeout(() => reject(new Error('getStudentDesserts timeout')), 2800))
      ]);

      snap.forEach(docSnap => {
        const data = docSnap.data();
        const docId = docSnap.id;
        const dPhone = String(data.studentPhone || data.phone || '').replace(/\D/g, '');
        const dId = String(data.studentId || data.id || data.userUid || '').trim();
        const dName = String(data.studentName || '').trim().toLowerCase();

        const matchesStudent = (!cleanId && !cleanPhone && !cleanName) ||
          (cleanPhone && dPhone && (dPhone.endsWith(cleanPhone.slice(-9)) || cleanPhone.endsWith(dPhone.slice(-9)))) ||
          (cleanId && dId === cleanId) ||
          (cleanName && dName && cleanName === dName);

        if (matchesStudent) {
          list.push({ ...data, id: docId });
        }
      });
    } catch (e) {
      console.warn('[DB] Student dessert query note, falling back to local:', e?.message || e);
    }
    // Supabase fallback query
    if (list.length === 0 && supabase) {
      try {
        let sbQuery = supabase.from('dessert_submissions').select('*').order('submitted_at', { ascending: false }).limit(60);
        if (cleanId) sbQuery = sbQuery.eq('student_id', cleanId);
        else if (cleanPhone) sbQuery = sbQuery.eq('student_phone', cleanPhone);
        const { data: sbData, error: sbErr } = await sbQuery;
        if (!sbErr && sbData && sbData.length > 0) {
          sbData.forEach(item => {
            list.push({
              id: item.id,
              studentId: item.student_id,
              studentName: item.student_name,
              studentPhone: item.student_phone,
              examYear: item.exam_year,
              subject: item.subject,
              caption: item.caption,
              mediaUrls: item.media_urls || [],
              type: item.submission_type || 'image',
              status: item.status || 'pending',
              creditsAwarded: item.credits_awarded || 0,
              adminFeedback: item.admin_feedback,
              reviewedBy: item.reviewed_by,
              reviewedAt: item.reviewed_at,
              submittedAt: item.submitted_at
            });
          });
        }
      } catch (err) {
        console.warn('[DB] Supabase dessert query note:', err);
      }
    }


    // Merge with localList: Firestore status is authoritative!
    for (const loc of localList) {
      const locPhone = String(loc.studentPhone || loc.phone || '').replace(/\D/g, '');
      const locId = String(loc.studentId || loc.id || '').trim();
      const locName = String(loc.studentName || '').trim().toLowerCase();
      const matchesLoc = (!cleanId && !cleanPhone && !cleanName) ||
        (cleanPhone && locPhone && (locPhone.endsWith(cleanPhone.slice(-9)) || cleanPhone.endsWith(locPhone.slice(-9)))) ||
        (cleanId && locId === cleanId) ||
        (cleanName && locName && cleanName === locName);

      if (matchesLoc) {
        const fsMatch = list.find(fs =>
          fs.id === loc.id ||
          (fs.submittedAt && fs.submittedAt === loc.submittedAt) ||
          (fs.caption && fs.caption === loc.caption && locPhone && fs.studentPhone && locPhone.endsWith(cleanPhone.slice(-9)))
        );
        if (fsMatch) {
          if (fsMatch.status) loc.status = fsMatch.status;
          if (fsMatch.adminFeedback) loc.adminFeedback = fsMatch.adminFeedback;
          if (fsMatch.creditsAwarded !== undefined) loc.creditsAwarded = fsMatch.creditsAwarded;
          if (fsMatch.reviewedAt) loc.reviewedAt = fsMatch.reviewedAt;
        } else {
          list.push(loc);
        }
      }
    }

    try {
      localStorage.setItem('edupeak_local_desserts', JSON.stringify(list));
    } catch (_) {}

    list.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));
    this.setCache(cacheKey, list);
    return list;
  }

  // Real-time listener for student's homework status
  listenToStudentDesserts(studentId, studentPhone, arg3, arg4) {
    const callback = typeof arg3 === 'function' ? arg3 : (typeof arg4 === 'function' ? arg4 : () => {});
    const studentName = typeof arg3 === 'string' ? arg3 : (typeof arg4 === 'string' ? arg4 : '');
    const cleanId = String(studentId || '').trim();
    const cleanPhone = String(studentPhone || '').replace(/\D/g, '');
    const cleanName = String(studentName || '').trim().toLowerCase();

    try {
      const dessertsRef = collection(db, 'desserts');
      const q = query(dessertsRef, orderBy('submittedAt', 'desc'), limit(60));

      const unsub = onSnapshot(q, (snapshot) => {
        const list = [];
        snapshot.forEach(docSnap => {
          const data = docSnap.data();
          const docId = docSnap.id;
          const dPhone = String(data.studentPhone || data.phone || '').replace(/\D/g, '');
          const dId = String(data.studentId || data.id || data.userUid || '').trim();
          const dName = String(data.studentName || '').trim().toLowerCase();

          const matchesStudent = (!cleanId && !cleanPhone && !cleanName) ||
            (cleanPhone && dPhone && (dPhone.endsWith(cleanPhone.slice(-9)) || cleanPhone.endsWith(dPhone.slice(-9)))) ||
            (cleanId && dId === cleanId) ||
            (cleanName && dName && cleanName === dName);

          if (matchesStudent) {
            list.push({ ...data, id: docId });
          }
        });

        // Sync with local storage
        try {
          let localList = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
          for (const fsItem of list) {
            const idx = localList.findIndex(l =>
              l.id === fsItem.id ||
              (l.submittedAt && l.submittedAt === fsItem.submittedAt)
            );
            if (idx >= 0) {
              localList[idx] = { ...localList[idx], ...fsItem };
            } else {
              localList.unshift(fsItem);
            }
          }

          // Also pull in any locally staged submissions
          for (const loc of localList) {
            const locPhone = String(loc.studentPhone || loc.phone || '').replace(/\D/g, '');
            const locId = String(loc.studentId || loc.id || '').trim();
            const locName = String(loc.studentName || '').trim().toLowerCase();
            const matchesLoc = (!cleanId && !cleanPhone && !cleanName) ||
              (cleanPhone && locPhone && (locPhone.endsWith(cleanPhone.slice(-9)) || cleanPhone.endsWith(locPhone.slice(-9)))) ||
              (cleanId && locId === cleanId) ||
              (cleanName && locName && cleanName === locName);

            if (matchesLoc && !list.some(d => d.id === loc.id || (d.submittedAt && d.submittedAt === loc.submittedAt))) {
              list.push(loc);
            }
          }

          localStorage.setItem('edupeak_local_desserts', JSON.stringify(localList));
        } catch (_) {}

        list.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));
        const cacheKey = `student_desserts_${cleanId}_${cleanPhone}_${cleanName}`;
        this.setCache(cacheKey, list);
        callback(list);
      }, (err) => {
        console.warn('[DB] Desserts snapshot listener error:', err);
      });

      return unsub;
    } catch (e) {
      console.warn('[DB] listenToStudentDesserts setup error:', e);
      return () => {};
    }
  }

  // Submit new Dessert homework (from Camera Scanner or file)
  async submitDessert({ studentId, studentName, studentPhone, subject, caption, mediaUrls, examYear }) {
    const dessertsRef = collection(db, 'desserts');
    const docRef = doc(dessertsRef);
    const docId = docRef.id;

    const newDoc = {
      id: docId,
      studentId: String(studentId || 'student'),
      studentName: String(studentName || 'Student'),
      studentPhone: String(studentPhone || '').trim(),
      examYear: String(examYear || '2027 A/L'),
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

    // Always persist to local cache immediately so homework submission is never lost
    try {
      let localList = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
      localList = localList.filter(d => d.id !== docId);
      localList.unshift(newDoc);
      localStorage.setItem('edupeak_local_desserts', JSON.stringify(localList.slice(0, 50)));
    } catch (storageErr) {
      console.warn('[DB] LocalStorage save error:', storageErr);
    }

    try {
      await Promise.race([
        setDoc(docRef, newDoc),
        new Promise((_, reject) => setTimeout(() => reject(new Error('submitDessert timeout')), 3500))
      ]);
    } catch (e) {
      console.warn('[DB] submitDessert Firestore note (saved locally):', e);
    }
    // Mirror submission to Supabase dessert_submissions table
    if (supabase) {
      try {
        await supabase.from('dessert_submissions').insert([{
          id: docId,
          student_id: String(studentId || 'student'),
          student_name: String(studentName || 'Student'),
          student_phone: String(studentPhone || '').trim(),
          exam_year: String(examYear || '2027 A/L'),
          subject: subject || 'Physics Mechanics',
          caption: caption || 'Daily Dessert Submission',
          media_urls: mediaUrls || [],
          submission_type: mediaUrls && mediaUrls.length > 0 ? 'image' : 'text',
          status: 'pending',
          credits_awarded: 0,
          submitted_at: newDoc.submittedAt
        }]);
      } catch (sbErr) {
        console.warn('[DB] Supabase dessert_submissions insert note:', sbErr?.message || sbErr);
      }
    }


    try {
      window.dispatchEvent(new CustomEvent('edupeak:dessert-submitted', { detail: newDoc }));
      localStorage.setItem('edupeak_last_sync_event', JSON.stringify({ type: 'dessert-submitted', data: newDoc, timestamp: Date.now() }));
    } catch (_) {}

    return newDoc;
  }

  // ── Essay Answer Sheet Submissions ────────────────────────────────────────
  async submitEssayPaper({ paperId, paperTitle, studentId, studentName, studentBatch, mediaUrls, pageCount, note }) {
    const essayRef = collection(db, 'essay_submissions');
    const docRef = doc(essayRef);
    const docId = docRef.id;
    const nowIso = new Date().toISOString();

    const newDoc = {
      id: docId,
      paperId: String(paperId || ''),
      paperTitle: String(paperTitle || 'Exam Paper'),
      studentId: String(studentId || 'student'),
      studentName: String(studentName || 'Student'),
      studentBatch: String(studentBatch || '2027 A/L'),
      mediaUrls: mediaUrls || [],
      pageCount: Number(pageCount || (mediaUrls ? mediaUrls.length : 0)),
      note: String(note || '').trim(),
      status: 'pending',  // pending | reviewed | graded
      marks: null,
      adminComment: null,
      gradedBy: null,
      gradedAt: null,
      submittedAt: nowIso
    };

    // 1. Persist locally immediately
    try {
      let localList = JSON.parse(localStorage.getItem('edupeak_local_essay_submissions') || '[]');
      localList = localList.filter(d => d.id !== docId);
      localList.unshift(newDoc);
      localStorage.setItem('edupeak_local_essay_submissions', JSON.stringify(localList.slice(0, 100)));
      localStorage.setItem(`paper_submitted_${paperId}_${studentId}`, 'true');
      localStorage.setItem(`paper_submitted_${paperId}`, 'true');
    } catch (_) {}

    // 2. Write to essay_submissions collection in Firestore
    try {
      await Promise.race([
        setDoc(docRef, newDoc),
        new Promise((_, reject) => setTimeout(() => reject(new Error('submitEssayPaper timeout')), 4000))
      ]);
    } catch (e) {
      console.warn('[DB] submitEssayPaper Firestore note (saved locally):', e);
    }

    // 3. Keep paper_registrations in sync so live exam room marks it submitted
    if (paperId && studentId) {
      const regData = {
        paperId,
        studentId,
        studentName,
        status: 'submitted',
        isSubmitted: true,
        submittedAt: nowIso,
        submissionPhotos: mediaUrls || [],
        submissionUrl: mediaUrls && mediaUrls[0] ? mediaUrls[0] : null
      };

      // Instantly update cache so client immediately renders "Submitted"
      this.setCache(`paper_reg_${paperId}_${studentId}`, regData);
      const allRegs = this.getCached(`all_regs_${studentId}`);
      if (allRegs) {
        allRegs[paperId] = { ...(allRegs[paperId] || {}), ...regData };
        this.setCache(`all_regs_${studentId}`, allRegs);
      }
      this.invalidateRegistrationCache(paperId, studentId);

      try {
        const regRef = doc(db, 'paper_registrations', `${paperId}_${studentId}`);
        await setDoc(regRef, regData, { merge: true }).catch(() => {});
      } catch (_) {}
    }

    try {
      window.dispatchEvent(new CustomEvent('edupeak:essay-submitted', { detail: newDoc }));
    } catch (_) {}

    return newDoc;
  }

  async getEssaySubmissions({ paperId = null, limit: lim = 200 } = {}) {
    const results = [];
    const seenIds = new Set();

    // 1. Read from essay_submissions in Firestore with 2.5s timeout
    try {
      let q;
      if (paperId) {
        q = query(collection(db, 'essay_submissions'), where('paperId', '==', paperId), limit(lim));
      } else {
        q = query(collection(db, 'essay_submissions'), limit(lim));
      }
      const snap = await Promise.race([
        getDocs(q),
        new Promise((_, reject) => setTimeout(() => reject(new Error('getEssaySubmissions timeout')), 2500))
      ]);
      snap.forEach(d => {
        const item = { ...d.data(), id: d.id };
        if (!seenIds.has(item.id)) {
          seenIds.add(item.id);
          results.push(item);
        }
      });
    } catch (e) {
      console.warn('[DB] getEssaySubmissions Firestore note:', e.message);
    }

    // 2. Read from paper_registrations for any submissions uploaded via live exam room
    try {
      let regQ;
      if (paperId) {
        regQ = query(collection(db, 'paper_registrations'), where('paperId', '==', paperId), where('status', '==', 'submitted'), limit(lim));
      } else {
        regQ = query(collection(db, 'paper_registrations'), where('status', '==', 'submitted'), limit(lim));
      }
      const regSnap = await Promise.race([
        getDocs(regQ),
        new Promise((_, reject) => setTimeout(() => reject(new Error('regSnap timeout')), 2000))
      ]);
      regSnap.forEach(d => {
        const data = d.data();
        const subId = `reg_${d.id}`;
        if (!seenIds.has(subId) && !seenIds.has(d.id)) {
          seenIds.add(subId);
          results.push({
            id: subId,
            paperId: data.paperId || '',
            paperTitle: data.paperTitle || 'Live Exam Paper',
            studentId: data.studentId || '',
            studentName: data.studentName || 'Student',
            studentBatch: data.studentBatch || '2027 A/L',
            mediaUrls: data.submissionPhotos || (data.submissionUrl ? [data.submissionUrl] : []),
            pageCount: data.submissionPhotos ? data.submissionPhotos.length : 1,
            note: data.note || '',
            status: data.isGraded ? 'graded' : (data.status === 'submitted' ? 'pending' : 'pending'),
            marks: data.marks ?? null,
            adminComment: data.adminComment || null,
            gradedBy: data.gradedBy || null,
            gradedAt: data.gradedAt || null,
            submittedAt: data.submittedAt || new Date().toISOString()
          });
        }
      });
    } catch (_) {}

    // 3. Merge local cached essay submissions
    try {
      const local = JSON.parse(localStorage.getItem('edupeak_local_essay_submissions') || '[]');
      local.forEach(item => {
        if (!seenIds.has(item.id)) {
          seenIds.add(item.id);
          if (!paperId || item.paperId === paperId) {
            results.push(item);
          }
        }
      });
    } catch (_) {}

    // Sort descending by submittedAt
    results.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));
    return results;
  }

  async gradeEssaySubmission({ submissionId, marks, adminComment, gradedBy, questionMarks }) {
    const isRegSub = String(submissionId).startsWith('reg_');
    const actualId = isRegSub ? String(submissionId).replace(/^reg_/, '') : submissionId;

    try {
      let paperId = null;
      let studentId = null;
      let studentPhone = '';

      if (isRegSub) {
        const ref = doc(db, 'paper_registrations', actualId);
        const updatePayload = {
          marks: marks !== undefined && marks !== null ? Number(marks) : null,
          adminComment: String(adminComment || '').trim(),
          gradedBy: String(gradedBy || 'Admin'),
          gradedAt: new Date().toISOString(),
          isGraded: true,
          status: 'graded'
        };
        if (Array.isArray(questionMarks)) {
          updatePayload.questionMarks = questionMarks;
        }
        await setDoc(ref, updatePayload, { merge: true });

        // Retrieve paperId and studentId from registration ID (${paperId}_${studentId})
        const parts = actualId.split('_');
        if (parts.length >= 2) {
          paperId = parts[0];
          studentId = parts.slice(1).join('_');
        }
      } else {
        const ref = doc(db, 'essay_submissions', actualId);
        const updatePayload = {
          marks: marks !== undefined && marks !== null ? Number(marks) : null,
          adminComment: String(adminComment || '').trim(),
          gradedBy: String(gradedBy || 'Admin'),
          gradedAt: new Date().toISOString(),
          isGraded: true,
          status: 'graded'
        };
        if (Array.isArray(questionMarks)) {
          updatePayload.questionMarks = questionMarks;
        }
        await updateDoc(ref, updatePayload);

        // Also check if corresponding paper_registrations exists and update it
        try {
          const snap = await getDoc(ref);
          if (snap.exists()) {
            const data = snap.data();
            paperId = data.paperId || null;
            studentId = data.studentId || null;
            studentPhone = data.studentPhone || '';
            if (paperId && studentId) {
              const regDocId = `${paperId}_${studentId}`;
              await setDoc(doc(db, 'paper_registrations', regDocId), {
                marks: marks !== undefined && marks !== null ? Number(marks) : null,
                adminComment: String(adminComment || '').trim(),
                gradedBy: String(gradedBy || 'Admin'),
                gradedAt: new Date().toISOString(),
                isGraded: true,
                status: 'graded'
              }, { merge: true });
            }
          }
        } catch (_) {}
      }

      // Invalidate student caches so examination hub instantly reloads fresh released marks
      if (paperId || studentId) {
        this.invalidateRegistrationCache(paperId, studentId, studentPhone);
      }

      // Update local cache
      try {
        let local = JSON.parse(localStorage.getItem('edupeak_local_essay_submissions') || '[]');
        local = local.map(d => (d.id === submissionId || d.id === actualId) ? { ...d, marks, adminComment, gradedBy, gradedAt: new Date().toISOString(), isGraded: true, status: 'graded', questionMarks } : d);
        localStorage.setItem('edupeak_local_essay_submissions', JSON.stringify(local));
      } catch (_) {}
    } catch (e) {
      console.error('[DB] gradeEssaySubmission error:', e);
      throw e;
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  // Get student accumulated credits from local cache, submissions, and leaderboard
  async getStudentCredits(studentId, studentPhone, studentIndex, studentName, { forceRefresh = false } = {}) {
    const cacheKey = `credits_${studentId || ''}_${studentPhone || ''}_${studentIndex || ''}_${studentName || ''}`;
    if (!forceRefresh && !this._isAdminActive()) {
      const cached = this.getCached(cacheKey);
      if (cached !== null && cached !== undefined) {
        if (!this._revalidating.has(cacheKey)) {
          this._revalidating.add(cacheKey);
          setTimeout(() => {
            this.getStudentCredits(studentId, studentPhone, studentIndex, studentName, { forceRefresh: true })
              .then(fresh => {
                this._revalidating.delete(cacheKey);
                if (fresh !== undefined && fresh !== cached) {
                  if (window.app && window.app.currentUser) {
                    window.app.currentUser.credits = fresh;
                  }
                  window.dispatchEvent(new CustomEvent('edupeak:credits-updated', { detail: { credits: fresh } }));
                }
              }).catch(() => { this._revalidating.delete(cacheKey); });
          }, 400);
        }
        return cached;
      }
    }

    const cleanPhone = String(studentPhone || '').replace(/\D/g, '');
    const cleanName = String(studentName || '').toLowerCase().trim();
    const cleanId = String(studentId || '').trim();
    const cleanIdx = String(studentIndex || '').trim();

    let dbCredits = 0;

    // 1. Check live Firestore leaderboard_public
    const idsToFetch = Array.from(new Set([cleanIdx, cleanId].filter(Boolean)));
    for (const fetchId of idsToFetch) {
      try {
        const lbSnap = await Promise.race([
          getDoc(doc(db, 'leaderboard_public', fetchId)),
          new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 2000))
        ]).catch(() => null);
        if (lbSnap && lbSnap.exists()) {
          const lbCredits = Number(lbSnap.data()?.credits) || 0;
          if (lbCredits > 0) dbCredits = Math.max(dbCredits, lbCredits);
        }
      } catch (_) {}
    }

    // 2. Read live credits from Firestore users collection by direct IDs
    for (const fetchId of idsToFetch) {
      try {
        const uSnap = await Promise.race([
          getDoc(doc(db, 'users', fetchId)),
          new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 2000))
        ]).catch(() => null);
        if (uSnap && uSnap.exists()) {
          const uCredits = Number(uSnap.data()?.credits) || 0;
          if (uCredits > 0) dbCredits = Math.max(dbCredits, uCredits);
        }
      } catch (_) {}
    }

    // 3. Query Firestore users collection by phone variants
    if (cleanPhone) {
      const phoneVariants = [
        cleanPhone,
        '+94' + cleanPhone.slice(-9),
        '0' + cleanPhone.slice(-9),
        '94' + cleanPhone.slice(-9)
      ];
      try {
        const usersRef = collection(db, 'users');
        for (const pv of phoneVariants) {
          const qSnap = await getDocs(query(usersRef, where('phone', '==', pv))).catch(() => null);
          if (qSnap && !qSnap.empty) {
            qSnap.forEach(d => {
              const uCredits = Number(d.data()?.credits) || 0;
              if (uCredits > 0) dbCredits = Math.max(dbCredits, uCredits);
            });
            break;
          }
        }
      } catch (_) {}
    }

    // 4. Query Firestore users collection by studentId field
    if (cleanId) {
      try {
        const usersRef = collection(db, 'users');
        const qSnap = await getDocs(query(usersRef, where('studentId', '==', cleanId))).catch(() => null);
        if (qSnap && !qSnap.empty) {
          qSnap.forEach(d => {
            const uCredits = Number(d.data()?.credits) || 0;
            if (uCredits > 0) dbCredits = Math.max(dbCredits, uCredits);
          });
        }
      } catch (_) {}
    }

    // 5. Query live Firestore approved desserts submissions
    let approvedDessertCredits = 0;
    try {
      const dessertsRef = collection(db, 'desserts');
      const dSnap = await getDocs(query(dessertsRef, where('status', '==', 'approved'))).catch(() => null);
      if (dSnap && !dSnap.empty) {
        dSnap.forEach(docSnap => {
          const d = docSnap.data();
          const dPhone = String(d.studentPhone || d.phone || '').replace(/\D/g, '');
          const dId = String(d.studentId || d.id || '').trim();
          const dName = String(d.studentName || '').toLowerCase().trim();
          const matches = (cleanId && dId === cleanId) ||
            (cleanIdx && dId === cleanIdx) ||
            (cleanPhone && dPhone && (dPhone.endsWith(cleanPhone.slice(-9)) || cleanPhone.endsWith(dPhone.slice(-9)))) ||
            (cleanName && dName && dName === cleanName);
          if (matches) {
            approvedDessertCredits += Number(d.creditsAwarded) || 0;
          }
        });
      }
    } catch (_) {}

    // Fallback to local desserts cache if network was offline
    if (approvedDessertCredits === 0) {
      try {
        const localDesserts = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
        localDesserts.forEach(d => {
          if (d.status === 'approved') {
            const dPhone = String(d.studentPhone || d.phone || '').replace(/\D/g, '');
            const dId = String(d.studentId || d.id || '').trim();
            const dName = String(d.studentName || '').toLowerCase().trim();
            const matches = (cleanId && dId === cleanId) ||
              (cleanIdx && dId === cleanIdx) ||
              (cleanPhone && dPhone && (dPhone.endsWith(cleanPhone.slice(-9)) || cleanPhone.endsWith(dPhone.slice(-9)))) ||
              (cleanName && dName && dName === cleanName);
            if (matches) {
              approvedDessertCredits += Number(d.creditsAwarded) || 0;
            }
          }
        });
      } catch (_) {}
    }

    if (approvedDessertCredits > 0) {
      dbCredits = Math.max(dbCredits, approvedDessertCredits);
    }

    // Keys for local storage syncing
    const keysToCheck = [
      cleanId && `edupeak_credits_${cleanId}`,
      cleanIdx && `edupeak_credits_${cleanIdx}`,
      cleanPhone && `edupeak_credits_${cleanPhone}`,
      studentPhone && `edupeak_credits_${studentPhone}`,
      cleanName && `edupeak_credits_${cleanName}`
    ].filter(Boolean);

    // If database returned authoritative credits, synchronize all localStorage keys to true DB credits and return
    if (dbCredits > 0) {
      for (const k of keysToCheck) {
        try {
          localStorage.setItem(k, String(dbCredits));
        } catch (_) {}
      }
      this.setCache(cacheKey, dbCredits);
      return dbCredits;
    }

    // 6. Offline fallback only: check local cache, explicitly filtering out legacy contaminated values (355 / 155 / 305)
    let localCredits = 0;
    for (const k of keysToCheck) {
      try {
        const val = localStorage.getItem(k);
        if (val) {
          const num = Number(val) || 0;
          if (num > 0 && num !== 355 && num !== 155 && num !== 305) {
            localCredits = Math.max(localCredits, num);
          }
        }
      } catch (_) {}
    }

    const finalCredits = localCredits > 0 ? localCredits : 0;
    this.setCache(cacheKey, finalCredits);
    return finalCredits;
  }

  // Award XP credits to student, update local leaderboard, and sync to Firestore
  async awardStudentCredits({ studentId, studentName, studentPhone, examYear, credits }) {
    const xp = Number(credits) || 0;
    if (xp <= 0) return;

    const sId = studentId || ('st_' + (studentName || 'student').toLowerCase().replace(/\s+/g, '_'));
    const sName = studentName || 'Student';
    const sPhone = studentPhone || '';
    const cleanPhone = String(sPhone).replace(/\D/g, '');
    const sBatch = examYear || '2027 A/L';

    // 1. Get current accurate credits
    const currentCredits = await this.getStudentCredits(sId, sPhone, studentId, sName);
    const newTotalCredits = currentCredits + xp;

    // 2. Persist across all local storage aliases
    if (sId) localStorage.setItem(`edupeak_credits_${sId}`, String(newTotalCredits));
    if (studentId) localStorage.setItem(`edupeak_credits_${studentId}`, String(newTotalCredits));
    if (sPhone) localStorage.setItem(`edupeak_credits_${sPhone}`, String(newTotalCredits));
    if (cleanPhone) localStorage.setItem(`edupeak_credits_${cleanPhone}`, String(newTotalCredits));
    if (sName) localStorage.setItem(`edupeak_credits_${sName.toLowerCase().trim()}`, String(newTotalCredits));

    // 3. Update local leaderboard cache
    try {
      let localLb = JSON.parse(localStorage.getItem('edupeak_local_leaderboard') || '[]');
      let entry = localLb.find(x =>
        x.id === sId ||
        x.id === studentId ||
        (sPhone && x.studentPhone === sPhone) ||
        (cleanPhone && String(x.studentPhone || '').replace(/\D/g, '').endsWith(cleanPhone.slice(-9))) ||
        (x.name && x.name.toLowerCase() === sName.toLowerCase())
      );
      if (entry) {
        entry.credits = newTotalCredits;
        entry.examYear = sBatch;
        entry.lastActive = new Date().toISOString();
      } else {
        localLb.push({
          id: sId,
          name: sName,
          studentPhone: sPhone,
          examYear: sBatch,
          role: 'student',
          credits: newTotalCredits,
          avatarUrl: '',
          lastActive: new Date().toISOString()
        });
      }
      localStorage.setItem('edupeak_local_leaderboard', JSON.stringify(localLb));
    } catch (e) {
      console.warn('[DB] Local leaderboard save error:', e);
    }

    // 4. Update Firestore leaderboard_public & users with 3.5s timeout race
    const targetIds = Array.from(new Set([sId, studentId].filter(Boolean)));
    for (const tid of targetIds) {
      try {
        const lbRef = doc(db, 'leaderboard_public', tid);
        await Promise.race([
          setDoc(lbRef, {
            id: tid,
            name: sName,
            studentPhone: sPhone,
            examYear: sBatch,
            role: 'student',
            credits: newTotalCredits,
            lastActive: new Date().toISOString()
          }, { merge: true }),
          new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000))
        ]);
      } catch (_) {}

      try {
        const userRef = doc(db, 'users', tid);
        await Promise.race([
          setDoc(userRef, {
            credits: newTotalCredits,
            lastActive: new Date().toISOString()
          }, { merge: true }),
          new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000))
        ]);
      } catch (_) {}
    }

    // 5. Notify app components via CustomEvent
    try {
      window.dispatchEvent(new CustomEvent('edupeak:credits-updated', {
        detail: { studentId: sId, studentName: sName, studentPhone: sPhone, creditsAwarded: xp, totalCredits: newTotalCredits }
      }));
      localStorage.setItem('edupeak_last_sync_event', JSON.stringify({
        type: 'credits-updated',
        data: { studentId: sId, studentName: sName, studentPhone: sPhone, creditsAwarded: xp, totalCredits: newTotalCredits },
        timestamp: Date.now()
      }));
    } catch (_) {}
  }

  // Admin: Review & grade homework
  async reviewDessert(dessertId, { status, adminFeedback, creditsAwarded, reviewedBy, studentId, studentName, studentPhone, examYear, dessertObj }) {
    const reviewedAt = new Date().toISOString();
    const finalCredits = Number(creditsAwarded) || (status === 'approved' ? 100 : 0);
    const feedback = adminFeedback || (status === 'approved' ? 'Great work!' : 'Please revise.');
    const reviewer = reviewedBy || 'Lead Physics Faculty';

    let targetStudentId = studentId || dessertObj?.studentId;
    let targetStudentName = studentName || dessertObj?.studentName;
    let targetStudentPhone = studentPhone || dessertObj?.studentPhone;
    let targetExamYear = examYear || dessertObj?.examYear;

    // 1. Immediately update localStorage (optimistic update ensures UI is never blocked)
    try {
      let localList = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
      let matched = false;
      for (let i = 0; i < localList.length; i++) {
        const item = localList[i];
        if (item.id === dessertId || (dessertObj && (
          (item.submittedAt && item.submittedAt === dessertObj.submittedAt) ||
          (item.caption && item.caption === dessertObj.caption && item.studentPhone === targetStudentPhone)
        ))) {
          item.status = status;
          item.adminFeedback = feedback;
          item.creditsAwarded = finalCredits;
          item.reviewedBy = reviewer;
          item.reviewedAt = reviewedAt;
          if (!targetStudentId) targetStudentId = item.studentId;
          if (!targetStudentName) targetStudentName = item.studentName;
          if (!targetStudentPhone) targetStudentPhone = item.studentPhone;
          matched = true;
        }
      }
      if (!matched && dessertObj) {
        localList.unshift({
          ...dessertObj,
          id: dessertId,
          status,
          adminFeedback: feedback,
          creditsAwarded: finalCredits,
          reviewedBy: reviewer,
          reviewedAt,
          studentId: targetStudentId || '',
          studentName: targetStudentName || 'Student',
          studentPhone: targetStudentPhone || '',
          examYear: targetExamYear || '2027 A/L'
        });
      }
      localStorage.setItem('edupeak_local_desserts', JSON.stringify(localList));
    } catch (storageErr) {
      console.warn('[DB] Local storage update error:', storageErr);
    }

    // 2. If approved, award student credits & update leaderboards
    if (status === 'approved' && finalCredits > 0) {
      await this.awardStudentCredits({
        studentId: targetStudentId,
        studentName: targetStudentName,
        studentPhone: targetStudentPhone,
        examYear: targetExamYear,
        credits: finalCredits
      });
    }

    // 3. Persist review to Firestore with 3.5s timeout
    const updateData = {
      status,
      adminFeedback: feedback,
      creditsAwarded: finalCredits,
      reviewedBy: reviewer,
      reviewedAt,
      ...(targetStudentId ? { studentId: String(targetStudentId) } : {}),
      ...(targetStudentPhone ? { studentPhone: String(targetStudentPhone) } : {}),
      ...(targetStudentName ? { studentName: String(targetStudentName) } : {}),
      ...(targetExamYear ? { examYear: String(targetExamYear) } : {})
    };

    try {
      const dessertRef = doc(db, 'desserts', dessertId);
      await Promise.race([
        setDoc(dessertRef, updateData, { merge: true }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Firestore timeout')), 3500))
      ]);
    } catch (e) {
      console.warn('[DB] Firestore dessert review save note (safely saved locally):', e);
    }

    // Update by submittedAt in case the doc had an auto-generated Firestore ID
    try {
      if (dessertObj && dessertObj.submittedAt) {
        const dessertsRef = collection(db, 'desserts');
        const q = query(dessertsRef, where('submittedAt', '==', dessertObj.submittedAt), limit(3));
        const snap = await getDocs(q);
        snap.forEach(async dSnap => {
          if (dSnap.id !== dessertId) {
            try {
              await setDoc(doc(db, 'desserts', dSnap.id), updateData, { merge: true });
            } catch (_) {}
          }
        });
      }
    } catch (_) {}

    try {
      window.dispatchEvent(new CustomEvent('edupeak:dessert-reviewed', {
        detail: { id: dessertId, status, creditsAwarded: finalCredits, studentId: targetStudentId, studentPhone: targetStudentPhone }
      }));
      localStorage.setItem('edupeak_last_sync_event', JSON.stringify({
        type: 'dessert-reviewed',
        data: { id: dessertId, status, creditsAwarded: finalCredits, studentId: targetStudentId, studentPhone: targetStudentPhone },
        timestamp: Date.now()
      }));
    } catch (_) {}

    return true;
  }

  // Admin: Get all student submissions for grading
  async getAllDessertsForAdmin() {
    let localList = [];
    try {
      localList = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
    } catch (_) {}

    try {
      const dessertsRef = collection(db, 'desserts');
      const q = query(dessertsRef, orderBy('submittedAt', 'desc'), limit(100));
      const snap = await Promise.race([
        getDocs(q),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Firestore timeout')), 3500))
      ]);
      const list = [];
      snap.forEach(docSnap => {
        list.push({ ...docSnap.data(), id: docSnap.id });
      });

      // Overlay local review modifications so approved state is never overwritten by stale data
      for (let i = 0; i < list.length; i++) {
        const matchingLocal = localList.find(loc => loc.id === list[i].id || (loc.submittedAt && loc.submittedAt === list[i].submittedAt));
        if (matchingLocal && (matchingLocal.reviewedAt || matchingLocal.status !== 'pending')) {
          list[i] = { ...list[i], ...matchingLocal };
        }
      }

      const seen = new Set(list.map(d => d.id));
      for (const loc of localList) {
        if (!seen.has(loc.id)) {
          list.push(loc);
          seen.add(loc.id);
        }
      }
      list.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));
      if (list.length > 0) return list;
    } catch (e) {
      console.warn('[DB] Admin desserts fetch fallback:', e);
    }
    return localList || [];
  }

  // Admin: Real-time listener for incoming homework and reviews
  listenToAllDessertsForAdmin(callback) {
    try {
      const dessertsRef = collection(db, 'desserts');
      const q = query(dessertsRef, orderBy('submittedAt', 'desc'), limit(100));
      return onSnapshot(q, (snapshot) => {
        const list = [];
        snapshot.forEach(docSnap => {
          list.push({ ...docSnap.data(), id: docSnap.id });
        });

        let localList = [];
        try {
          localList = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
        } catch (_) {}

        // Overlay local review modifications so approved state is never overwritten by stale snapshot
        for (let i = 0; i < list.length; i++) {
          const matchingLocal = localList.find(loc => loc.id === list[i].id || (loc.submittedAt && loc.submittedAt === list[i].submittedAt));
          if (matchingLocal && (matchingLocal.reviewedAt || matchingLocal.status !== 'pending')) {
            list[i] = { ...list[i], ...matchingLocal };
          }
        }

        for (const loc of localList) {
          if (!list.some(d => d.id === loc.id || (d.submittedAt && d.submittedAt === loc.submittedAt))) {
            list.push(loc);
          }
        }
        list.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));
        this.setCache('all_desserts_admin', list);
        callback(list);
      }, (err) => {
        console.warn('[DB] listenToAllDessertsForAdmin snapshot error:', err);
      });
    } catch (e) {
      console.warn('[DB] listenToAllDessertsForAdmin setup error:', e);
      return () => {};
    }
  }

  // Admin: Save or update paper session
  async savePaperSession(session) {
    try {
      const isNew = !session.id;
      const ref = collection(db, 'paper_sessions');
      const payload = {
        ...session,
        status: session.status || 'scheduled',
        currentPhase: session.currentPhase || 'registration',
        isStarted: session.isStarted === true,
        isLive: session.isLive === true,
        isEnded: session.isEnded === true,
        notifyStudents: session.notifyStudents !== false,
        notifyOnStart: session.notifyOnStart !== false,
        updatedAt: new Date().toISOString()
      };
      if (isNew) {
        payload.createdAt = new Date().toISOString();
        payload.scheduledAt = session.scheduledAt || new Date().toISOString();
        const docRef = await addDoc(ref, payload);
        const res = { id: docRef.id, ...payload };
        if (payload.notifyStudents !== false) {
          this.broadcastSessionAlert(docRef.id, 'scheduled').catch(() => {});
        }
        return res;
      } else {
        const docRef = doc(db, 'paper_sessions', session.id);
        await setDoc(docRef, payload, { merge: true });
        const res = { id: session.id, ...payload };
        if (payload.notifyStudents !== false && payload.status === 'scheduled') {
          this.broadcastSessionAlert(session.id, 'scheduled').catch(() => {});
        }
        return res;
      }
    } catch (e) {
      console.warn('[DB] Saved paper locally:', e);
      throw e;
    }
  }

    isStaffOrAdmin(u) {
    if (!u) return false;
    const role = String(u.role || '').toLowerCase().trim();
    const name = String(u.name || '').toLowerCase().trim();
    const phone = String(u.phone || u.studentPhone || '').replace(/\D/g, '');
    const id = String(u.id || u.uid || u.studentId || '').toLowerCase().trim();

    if (u.isAdmin === true || u.isTeacher === true || u.isStaff === true) return true;
    if (role === 'admin' || role === 'teacher' || role === 'staff' || role === 'instructor') return true;
    if (
      name.includes('admin') ||
      name.includes('teacher') ||
      name.includes('prof.') ||
      name.includes('professor') ||
      name.includes('instructor') ||
      (name.includes('senanayake') && (role === 'admin' || role === 'teacher' || role === 'staff' || u.isTeacher || u.isAdmin || phone.endsWith('770557769'))) ||
      name === 'staff'
    ) {
      return true;
    }
    if (id.includes('admin') || id.includes('teacher') || id.includes('staff')) return true;
    if (phone.endsWith('770557769') || phone.endsWith('0770557769')) return true;

    try {
      const cachedAuth = JSON.parse(localStorage.getItem('edupeak_cached_user') || 'null');
      if (cachedAuth && (cachedAuth.role === 'admin' || cachedAuth.isAdmin)) {
        const cId = String(cachedAuth.uid || cachedAuth.id || '').toLowerCase().trim();
        const cPhone = String(cachedAuth.phone || '').replace(/\D/g, '');
        const cName = String(cachedAuth.name || '').toLowerCase().trim();
        if (cId && (id === cId || (u.uid && String(u.uid).toLowerCase().trim() === cId))) return true;
        if (cPhone && phone && (phone.endsWith(cPhone.slice(-9)) || cPhone.endsWith(phone.slice(-9)))) return true;
        if (cName && name === cName) return true;
      }
    } catch (_) {}

    return false;
  }

  // Admin: Get student roster - ONLY students who have logged into Dessert App
  async getAllStudents({ forceRefresh = false } = {}) {
    const cacheKey = 'all_admin_students';
    if (!forceRefresh) {
      const cached = this.getCached(cacheKey, 30000);
      if (cached && Array.isArray(cached)) return cached;
    }

    const map = new Map();

    // 1. Fetch registered students who have logged into Dessert App via Supabase RPC or dessert_app_logins
    try {
      const rpcPromise = supabase ? supabase.rpc('get_all_students_for_admin') : Promise.resolve({ data: null, error: true });
      const { data: supaStudents, error: supaErr } = await Promise.race([
        rpcPromise,
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 2000))
      ]).catch(() => ({ data: null, error: true }));

      if (!supaErr && Array.isArray(supaStudents)) {
        for (const u of supaStudents) {
          if (this.isStaffOrAdmin(u)) continue;
          const key = (u.studentId || u.id || u.phone || u.email || u.name).toLowerCase().trim();
          map.set(key, {
            id: u.id || u.studentId,
            studentId: u.studentId || u.id,
            name: u.name,
            phone: u.phone || '',
            email: u.email || '',
            examYear: u.examYear || '2027 A/L',
            role: 'student',
            enrolledCourses: u.enrolledCourses || [],
            attendanceMode: u.attendanceMode || 'online',
            school: u.school || '',
            district: u.district || '',
            loginCount: u.loginCount || 1,
            lastLoginAt: u.lastLoginAt || null,
            firstLoginAt: u.firstLoginAt || null,
            credits: Number(u.credits) || 0
          });
        }
      } else {
        // Fallback: Query dessert_app_logins directly with limit
        const { data: loginRows } = await supabase
          .from('dessert_app_logins')
          .select('*')
          .limit(300);

        if (loginRows && loginRows.length > 0) {
          for (const l of loginRows) {
            const key = (l.student_id || l.phone || l.email || l.name).toLowerCase().trim();
            map.set(key, {
              id: l.student_id,
              studentId: l.student_id,
              name: l.name,
              phone: l.phone || '',
              email: l.email || '',
              examYear: l.exam_year || '2027 A/L',
              role: 'student',
              enrolledCourses: [],
              attendanceMode: 'online',
              school: '',
              district: '',
              loginCount: l.login_count || 1,
              lastLoginAt: l.last_login_at || null,
              firstLoginAt: l.first_login_at || null,
              credits: 0
            });
          }
        }
      }
    } catch (e) {
      console.warn('[DB] Supabase getAllStudents error:', e);
    }

    // 2. Merge with Firestore users ONLY for verified Dessert App students in map
    try {
      const usersRef = collection(db, 'users');
      const snap = await Promise.race([
        getDocs(usersRef),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 2500))
      ]);
      if (snap && !snap.empty) {
        for (const d of snap.docs) {
          const u = { id: d.id, ...d.data() };
          if (this.isStaffOrAdmin(u)) continue;
          const key = (u.studentId || u.id || u.phone || u.name).toLowerCase().trim();
          if (map.has(key)) {
            const existing = map.get(key);
            map.set(key, {
              ...u,
              ...existing,
              name: existing.name || u.name,
              studentId: existing.studentId || existing.id || u.studentId || u.id,
              id: existing.id || u.id,
              credits: Math.max(Number(existing.credits) || 0, Number(u.credits) || 0)
            });
          }
        }
      }
    } catch (_) {}

    // 3. Fast In-Memory Batch Credit Resolution from cached leaderboard (Single query instead of N*5 individual requests)
    const students = Array.from(map.values()).filter(u => !this.isStaffOrAdmin(u));
    try {
      const lb = await this.getLeaderboard('all');
      const creditMap = new Map();
      if (Array.isArray(lb)) {
        for (const item of lb) {
          const c = Number(item.credits) || 0;
          if (c > 0) {
            if (item.id) creditMap.set(String(item.id).toLowerCase().trim(), c);
            if (item.studentPhone) creditMap.set(String(item.studentPhone).replace(/\D/g, '').slice(-9), c);
            if (item.name) creditMap.set(String(item.name).toLowerCase().trim(), c);
          }
        }
      }

      for (const st of students) {
        if (!st.credits || st.credits <= 0) {
          const idKey = st.studentId || st.id;
          const phoneKey = String(st.phone || '').replace(/\D/g, '').slice(-9);
          const nameKey = String(st.name || '').toLowerCase().trim();
          st.credits = (idKey && creditMap.get(idKey.toLowerCase().trim())) ||
                       (phoneKey && creditMap.get(phoneKey)) ||
                       (nameKey && creditMap.get(nameKey)) ||
                       0;
        }
      }
    } catch (_) {}

    this.setCache(cacheKey, students);
    return students;
  }

  // Admin: Resolve Super Paper Class access for students
  async getSuperPaperAccessMap(students = []) {
    return await getSuperPaperBatchAccess(students);
  }

  // Admin: Grant Super Paper Class access to a student
  async grantSuperPaperAccess(student) {
    return await grantSuperPaperAccess(student);
  }

  // Admin: Revoke Super Paper Class access for a student
  async revokeSuperPaperAccess(student) {
    return await revokeSuperPaperAccess(student);
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
      return { isEnded: false, isLive: false, isWaiting: false, isUpcoming: true, isScheduled: false, isPackageOpening: false, isWriting: false, isTimeUp: false, statusText: 'upcoming' };
    }
    const isEnded = !!(session.isEnded || session.status === 'ended' || session.currentPhase === 'ended');
    if (isEnded) {
      return { isEnded: true, isLive: false, isWaiting: false, isUpcoming: false, isScheduled: false, isPackageOpening: false, isWriting: false, isTimeUp: false, statusText: 'ended' };
    }
    const isPackageOpening = session.currentPhase === 'package_opening';
    const isWriting = session.currentPhase === 'writing';
    const isTimeUp = session.currentPhase === 'time_up' || !!session.isTimeUp;
    
    // Explicitly live / started session
    const isExplicitlyLive = !!(
      session.isLive === true ||
      session.isStarted === true ||
      session.status === 'active' ||
      session.status === 'live' ||
      isPackageOpening ||
      isWriting ||
      isTimeUp
    );

    // If session is scheduled for student registration and not yet started by admin
    const isScheduled = (session.status === 'scheduled' || session.currentPhase === 'registration' || session.isStarted === false) && !isExplicitlyLive;

    const isLive = isExplicitlyLive;
    const isWaiting = !isLive && session.currentPhase === 'waiting';
    const isUpcoming = (!isLive && !isEnded) || isScheduled;

    return {
      isEnded,
      isLive,
      isWaiting,
      isUpcoming,
      isScheduled,
      isPackageOpening,
      isWriting,
      isTimeUp,
      statusText: isLive ? 'live' : (isEnded ? 'ended' : (isScheduled ? 'scheduled' : 'upcoming'))
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

    const rawStatus = raw.status || 'scheduled';
    const isEnded = !!(raw.isEnded || rawStatus === 'ended' || raw.currentPhase === 'ended');
    let phase = raw.currentPhase || '';
    if (!phase) {
      if (isEnded) phase = 'ended';
      else if (raw.isTimeUp) phase = 'time_up';
      else if (rawStatus === 'active') phase = 'writing';
      else if (rawStatus === 'scheduled') phase = 'registration';
      else phase = 'registration';
    }

    const isLive = !isEnded && (raw.isLive === true || raw.isStarted === true || rawStatus === 'active' || rawStatus === 'live' || phase === 'package_opening' || phase === 'writing' || phase === 'time_up');
    const isScheduled = !isEnded && !isLive && (rawStatus === 'scheduled' || phase === 'registration' || raw.isStarted === false);

    return {
      ...raw,
      id: id || raw.id || 'paper_' + Date.now(),
      title: raw.title || 'A/L Physics Paper Session',
      subject: raw.subject || 'A/L Physics',
      paperType: raw.paperType || 'essay',
      mcqCount: Math.min(100, Math.max(1, Number(raw.mcqCount) || 50)),
      mcqAnswerKey: raw.mcqAnswerKey || {},
      paperPdfUrl: raw.paperPdfUrl || raw.pdfUrl || null,
      pdfUrl: raw.pdfUrl || raw.paperPdfUrl || null,
      examYear: raw.examYear || 'All Batches',
      date: raw.date || todayIso,
      durationMinutes: duration,
      totalMarks: Number(raw.totalMarks) || 100,
      status: isEnded ? 'ended' : (isLive ? 'active' : (isScheduled ? 'scheduled' : rawStatus)),
      currentPhase: phase,
      isEnded,
      isLive,
      isStarted: !!(raw.isStarted || isLive),
      isScheduled,
      isTimeUp: !!raw.isTimeUp,
      notifyStudents: raw.notifyStudents !== false,
      notifyOnStart: raw.notifyOnStart !== false,
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
      syllabusTopics: Array.isArray(raw.syllabusTopics) ? raw.syllabusTopics : [],
      hints: raw.hints || '',
      instructions: raw.instructions || ''
    };
  }

  normalizePaperHint(raw, id) {
    if (!raw) return null;
    const parseTime = (val) => {
      if (!val) return new Date();
      if (typeof val?.toDate === 'function') {
        try { return val.toDate(); } catch (_) {}
      }
      const d = new Date(val);
      return isNaN(d.getTime()) ? new Date() : d;
    };

    return {
      id: id || raw.id || 'hint_' + Date.now(),
      title: raw.title || raw.paperTitle || 'Special Paper Hints & Guidance',
      subject: raw.subject || 'A/L Physics',
      examYear: raw.examYear || 'All Batches',
      paperName: raw.paperName || raw.paperTitle || '',
      hints: raw.hints || raw.instructions || '',
      formulas: raw.formulas || '',
      scope: Array.isArray(raw.scope) ? raw.scope : (typeof raw.scope === 'string' ? raw.scope.split(',').map(s => s.trim()).filter(Boolean) : (Array.isArray(raw.syllabusTopics) ? raw.syllabusTopics : [])),
      notifyStudents: raw.notifyStudents !== false,
      isPublished: raw.isPublished !== false,
      publishedAt: parseTime(raw.publishedAt || raw.createdAt),
      createdAt: raw.createdAt || new Date().toISOString()
    };
  }

  getMockPaperSessions(examYear) {
    return [];
  }

  getMockUpcomingPapers(examYear) {
    return [];
  }

  async getPaperSessions(examYear, { forceRefresh = false } = {}) {
    const cacheKey = `paper_sessions_${examYear || 'all'}`;
    if (!forceRefresh && !this._isAdminActive()) {
      const cached = this.getCached(cacheKey);
      if (cached && Array.isArray(cached) && cached.length > 0) {
        if (!this._revalidating.has(cacheKey)) {
          this._revalidating.add(cacheKey);
          setTimeout(() => {
            this.getPaperSessions(examYear, { forceRefresh: true })
              .then(fresh => {
                this._revalidating.delete(cacheKey);
                if (fresh && JSON.stringify(fresh) !== JSON.stringify(cached)) {
                  window.dispatchEvent(new CustomEvent('edupeak:swr-updated', { detail: { type: 'papers', data: fresh } }));
                }
              }).catch(() => { this._revalidating.delete(cacheKey); });
          }, 300);
        }
        return cached;
      }
    }
    try {
      const ref = collection(db, 'paper_sessions');
      const snap = await Promise.race([
        getDocs(ref),
        new Promise((_, reject) => setTimeout(() => reject(new Error('getPaperSessions timeout')), 2800))
      ]);
      if (!snap.empty) {
        const list = snap.docs.map(d => this.normalizePaperSession(d.data(), d.id)).filter(Boolean);
        let result = list;
        if (examYear && examYear !== 'All' && examYear !== 'All Batches') {
          result = list.filter(p => this.matchesYear(p.examYear, examYear));
        }
        const getSessionOrderTime = (p) => {
          if (p.createdAt) {
            const t = new Date(p.createdAt).getTime();
            if (!isNaN(t)) return t;
          }
          if (p.date) {
            const t = new Date(p.date).getTime();
            if (!isNaN(t)) return t;
          }
          return 0;
        };
        result.sort((a, b) => {
          const aEnded = !!(a.isEnded || a.status === 'ended' || a.currentPhase === 'ended');
          const bEnded = !!(b.isEnded || b.status === 'ended' || b.currentPhase === 'ended');
          if (aEnded !== bEnded) return aEnded ? 1 : -1;
          return getSessionOrderTime(b) - getSessionOrderTime(a);
        });
        this.setCache(cacheKey, result);
        try { localStorage.setItem(`edupeak_cached_${cacheKey}`, JSON.stringify(result)); } catch (_) {}
        return result;
      }
    } catch (e) {
      console.warn('[DB] getPaperSessions SDK timeout/note, attempting REST fallback:', e?.message || e);
    }

    // ── Fallback 1: Firestore REST API (Fast HTTP fetch, bypasses SDK WebChannel latency) ──
    try {
      const restResp = await Promise.race([
        fetch('https://firestore.googleapis.com/v1/projects/dessert-institute/databases/(default)/documents/paper_sessions'),
        new Promise((_, reject) => setTimeout(() => reject(new Error('REST timeout')), 3000))
      ]);
      if (restResp && restResp.ok) {
        const restJson = await restResp.json();
        if (Array.isArray(restJson.documents) && restJson.documents.length > 0) {
          const list = restJson.documents.map(d => {
            const id = d.name ? d.name.split('/').pop() : null;
            const parsed = this._parseFirestoreRestFields(d.fields);
            return this.normalizePaperSession(parsed, id);
          }).filter(Boolean);

          let result = list;
          if (examYear && examYear !== 'All' && examYear !== 'All Batches') {
            result = list.filter(p => this.matchesYear(p.examYear, examYear));
          }
          if (result.length > 0) {
            this.setCache(cacheKey, result);
            try { localStorage.setItem(`edupeak_cached_${cacheKey}`, JSON.stringify(result)); } catch (_) {}
            return result;
          }
        }
      }
    } catch (restErr) {
      console.warn('[DB] getPaperSessions REST fallback error:', restErr?.message || restErr);
    }

    // ── Fallback 2: Cached sessions in localStorage ──
    try {
      const local = localStorage.getItem(`edupeak_cached_${cacheKey}`) || localStorage.getItem('edupeak_cached_paper_sessions_all');
      if (local) {
        const parsed = JSON.parse(local);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      }
    } catch (_) {}

    return [];
  }

  _parseFirestoreRestFields(fields) {
    if (!fields || typeof fields !== 'object') return {};
    const obj = {};
    for (const [k, v] of Object.entries(fields)) {
      if (v.stringValue !== undefined) obj[k] = v.stringValue;
      else if (v.booleanValue !== undefined) obj[k] = v.booleanValue;
      else if (v.integerValue !== undefined) obj[k] = Number(v.integerValue);
      else if (v.doubleValue !== undefined) obj[k] = Number(v.doubleValue);
      else if (v.timestampValue !== undefined) obj[k] = v.timestampValue;
      else if (v.nullValue !== undefined) obj[k] = null;
      else if (v.mapValue && v.mapValue.fields) obj[k] = this._parseFirestoreRestFields(v.mapValue.fields);
      else if (v.arrayValue && v.arrayValue.values) obj[k] = v.arrayValue.values.map(item => this._parseFirestoreRestFields({ val: item }).val);
      else obj[k] = v;
    }
    return obj;
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

  streamPaperSessions(examYear, callback) {
    if (this.useMockData) {
      callback(this.getMockPaperSessions(examYear));
      return () => {};
    }
    try {
      const ref = collection(db, 'paper_sessions');
      return onSnapshot(ref, (snapshot) => {
        const list = snapshot.docs.map(d => this.normalizePaperSession(d.data(), d.id)).filter(Boolean);
        let result = list;
        if (examYear && examYear !== 'All' && examYear !== 'All Batches') {
          result = list.filter(p => this.matchesYear(p.examYear, examYear));
        }
        const getSessionOrderTime = (p) => {
          if (p.createdAt) {
            const t = new Date(p.createdAt).getTime();
            if (!isNaN(t)) return t;
          }
          if (p.date) {
            const t = new Date(p.date).getTime();
            if (!isNaN(t)) return t;
          }
          return 0;
        };
        result.sort((a, b) => {
          const aEnded = !!(a.isEnded || a.status === 'ended' || a.currentPhase === 'ended');
          const bEnded = !!(b.isEnded || b.status === 'ended' || b.currentPhase === 'ended');
          if (aEnded !== bEnded) return aEnded ? 1 : -1;
          return getSessionOrderTime(b) - getSessionOrderTime(a);
        });
        const cacheKey = `paper_sessions_${examYear || 'all'}`;
        this.setCache(cacheKey, result);
        callback(result);
      }, (err) => {
        console.warn('[DB] streamPaperSessions error:', err);
      });
    } catch (e) {
      console.warn('[DB] streamPaperSessions setup error:', e);
      return () => {};
    }
  }

  async getUpcomingPapers(examYear, { forceRefresh = false } = {}) {
    const cacheKey = `upcoming_papers_${examYear || 'all'}`;
    if (!forceRefresh && !this._isAdminActive()) {
      const cached = this.getCached(cacheKey);
      if (cached && Array.isArray(cached) && cached.length > 0) {
        if (!this._revalidating.has(cacheKey)) {
          this._revalidating.add(cacheKey);
          setTimeout(() => {
            this.getUpcomingPapers(examYear, { forceRefresh: true })
              .then(fresh => {
                this._revalidating.delete(cacheKey);
                if (fresh && JSON.stringify(fresh) !== JSON.stringify(cached)) {
                  window.dispatchEvent(new CustomEvent('edupeak:swr-updated', { detail: { type: 'upcoming', data: fresh } }));
                }
              }).catch(() => { this._revalidating.delete(cacheKey); });
          }, 400);
        }
        return cached;
      }
    }
    try {
      const ref = collection(db, 'upcoming_papers');
      const snap = await Promise.race([
        getDocs(ref),
        new Promise((_, reject) => setTimeout(() => reject(new Error('getUpcomingPapers timeout')), 2800))
      ]);
      if (!snap.empty) {
        const list = snap.docs.map(d => this.normalizeUpcomingPaper(d.data(), d.id)).filter(Boolean);
        if (examYear && examYear !== 'All' && examYear !== 'All Batches') {
          const res = list.filter(p => this.matchesYear(p.examYear, examYear));
          this.setCache(cacheKey, res);
          try { localStorage.setItem(`edupeak_cached_${cacheKey}`, JSON.stringify(res)); } catch (_) {}
          return res;
        }
        this.setCache(cacheKey, list);
        try { localStorage.setItem(`edupeak_cached_${cacheKey}`, JSON.stringify(list)); } catch (_) {}
        return list;
      }
    } catch (e) {
      console.warn('[DB] getUpcomingPapers note/timeout:', e?.message || e);
    }
    return [];
  }

  streamUpcomingPapers(examYear, callback) {
    try {
      const ref = collection(db, 'upcoming_papers');
      return onSnapshot(ref, (snap) => {
        const list = snap.docs.map(d => this.normalizeUpcomingPaper(d.data(), d.id)).filter(Boolean);
        let result = list;
        if (examYear && examYear !== 'All' && examYear !== 'All Batches') {
          result = list.filter(p => this.matchesYear(p.examYear, examYear));
        }
        callback(result);
      }, (e) => {
        console.warn('[DB] streamUpcomingPapers error:', e);
      });
    } catch (e) {
      console.warn('[DB] streamUpcomingPapers setup error:', e);
      return () => {};
    }
  }

  async getPaperHints(examYear, { forceRefresh = false } = {}) {
    const cacheKey = `paper_hints_${examYear || 'all'}`;
    if (!forceRefresh && !this._isAdminActive()) {
      const cached = this.getCached(cacheKey);
      if (cached && Array.isArray(cached) && cached.length > 0) {
        if (!this._revalidating.has(cacheKey)) {
          this._revalidating.add(cacheKey);
          setTimeout(() => {
            this.getPaperHints(examYear, { forceRefresh: true })
              .then(fresh => {
                this._revalidating.delete(cacheKey);
                if (fresh && JSON.stringify(fresh) !== JSON.stringify(cached)) {
                  window.dispatchEvent(new CustomEvent('edupeak:swr-updated', { detail: { type: 'hints', data: fresh } }));
                }
              }).catch(() => { this._revalidating.delete(cacheKey); });
          }, 400);
        }
        return cached;
      }
    }
    try {
      const hintsRef = collection(db, 'paper_hints');
      const snap = await Promise.race([
        getDocs(hintsRef),
        new Promise((_, reject) => setTimeout(() => reject(new Error('getPaperHints timeout')), 3000))
      ]);
      let list = [];
      if (!snap.empty) {
        list = snap.docs.map(d => this.normalizePaperHint(d.data(), d.id)).filter(Boolean);
      }
      
      // Also include any hints from upcoming_papers so existing hints are preserved
      try {
        const upRef = collection(db, 'upcoming_papers');
        const upSnap = await getDocs(upRef);
        if (!upSnap.empty) {
          upSnap.docs.forEach(d => {
            const data = d.data();
            if (data && (data.hints || data.instructions)) {
              if (!list.some(h => h.id === d.id || h.title === data.title)) {
                list.push(this.normalizePaperHint(data, d.id));
              }
            }
          });
        }
      } catch (_) {}

      list.sort((a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime());

      if (examYear && examYear !== 'All' && examYear !== 'All Batches') {
        const res = list.filter(h => this.matchesYear(h.examYear, examYear) || h.examYear === 'All Batches' || h.examYear === 'All');
        this.setCache(cacheKey, res);
        try { localStorage.setItem(`edupeak_cached_${cacheKey}`, JSON.stringify(res)); } catch (_) {}
        return res;
      }
      this.setCache(cacheKey, list);
      try { localStorage.setItem(`edupeak_cached_${cacheKey}`, JSON.stringify(list)); } catch (_) {}
      return list;
    } catch (e) {
      console.warn('[DB] getPaperHints note/timeout:', e?.message || e);
    }
    return [];
  }

  streamPaperHints(examYear, callback) {
    try {
      const ref = collection(db, 'paper_hints');
      return onSnapshot(ref, (snap) => {
        let list = snap.docs.map(d => this.normalizePaperHint(d.data(), d.id)).filter(Boolean);
        list.sort((a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime());
        if (examYear && examYear !== 'All' && examYear !== 'All Batches') {
          list = list.filter(h => this.matchesYear(h.examYear, examYear) || h.examYear === 'All Batches' || h.examYear === 'All');
        }
        callback(list);
      }, (e) => {
        console.warn('[DB] streamPaperHints error:', e);
      });
    } catch (e) {
      console.warn('[DB] streamPaperHints setup error:', e);
      return () => {};
    }
  }

  async createPaperHint(hintData) {
    const id = hintData.id || `hint_${Date.now()}`;
    const payload = {
      ...hintData,
      id,
      notifyStudents: hintData.notifyStudents !== false,
      publishedAt: serverTimestamp(),
      createdAt: new Date().toISOString(),
      isPublished: true
    };
    await setDoc(doc(db, 'paper_hints', id), payload, { merge: true });
    this.clearCache('paper_hints');
    return payload;
  }

  async updatePaperHint(hintId, hintData) {
    if (!hintId) return;
    const ref = doc(db, 'paper_hints', hintId);
    await updateDoc(ref, {
      ...hintData,
      notifyStudents: hintData.notifyStudents !== false,
      updatedAt: serverTimestamp()
    });
    this.clearCache('paper_hints');
  }

  async deletePaperHint(hintId) {
    if (!hintId) return;
    await deleteDoc(doc(db, 'paper_hints', hintId));
    this.clearCache('paper_hints');
  }

  deduplicateRegistrations(registrations) {
    if (!Array.isArray(registrations)) return [];
    const map = new Map();

    for (const reg of registrations) {
      if (!reg) continue;
      const rawPhone = reg.studentPhone || reg.phone || '';
      const normPhone = normalizePhone(rawPhone);
      // Key by normalized phone if present; fallback to studentId / uid / id
      const key = (normPhone && normPhone.length >= 9) ? normPhone : (reg.studentId || reg.uid || reg.id);
      if (!key) continue;

      if (!map.has(key)) {
        map.set(key, { ...reg, studentPhone: normPhone || rawPhone });
      } else {
        const existing = map.get(key);
        const isSub = (reg.status === 'submitted' || reg.isSubmitted === true || (Array.isArray(reg.submissionPhotos) && reg.submissionPhotos.length > 0) || reg.mcqScore !== undefined);
        const existSub = (existing.status === 'submitted' || existing.isSubmitted === true || (Array.isArray(existing.submissionPhotos) && existing.submissionPhotos.length > 0) || existing.mcqScore !== undefined);

        const hasCam = !!(reg.isCameraActive && (reg.cameraSnapshotUrl || reg.lastCameraPing));
        const existCam = !!(existing.isCameraActive && (existing.cameraSnapshotUrl || existing.lastCameraPing));

        const merged = {
          ...existing,
          ...reg,
          studentPhone: normPhone || existing.studentPhone || rawPhone,
          status: (existSub || isSub) ? 'submitted' : (reg.status || existing.status),
          isSubmitted: existSub || isSub,
          submissionPhotos: (existSub && existing.submissionPhotos?.length) ? existing.submissionPhotos : (reg.submissionPhotos || existing.submissionPhotos || []),
          isCameraActive: existCam || hasCam,
          isOnline: reg.isOnline !== undefined ? reg.isOnline : existing.isOnline,
          cameraSnapshotUrl: reg.cameraSnapshotUrl || existing.cameraSnapshotUrl,
          lastCameraPing: reg.lastCameraPing || existing.lastCameraPing,
          selectedSlot: reg.selectedSlot || existing.selectedSlot || 'slot1'
        };
        map.set(key, merged);
      }
    }
    return Array.from(map.values());
  }

  async registerStudentSlot({ paperId, studentId, studentName, studentPhone, slotId }) {
    if (!paperId || !studentId) return null;
    const normPhone = normalizePhone(studentPhone);
    const cacheKey = `paper_reg_${paperId}_${studentId}`;

    // Fast-path: Check memory/local cache first before network query
    let existing = this.getCached(cacheKey);
    if (!existing) {
      existing = await this.getStudentRegistration(paperId, studentId);
      if (!existing && normPhone) {
        existing = await this.getStudentRegistration(paperId, normPhone);
      }
    }
    if (existing && (existing.status === 'submitted' || existing.isSubmitted === true || (existing.submissionPhotos && existing.submissionPhotos.length > 0))) {
      return existing; // DO NOT OVERWRITE SUBMITTED STATE!
    }
    const isSlotChange = existing && (existing.selectedSlot || existing.slotId) && (existing.selectedSlot !== slotId && existing.slotId !== slotId);
    const prevSlot = existing ? (existing.selectedSlot || existing.slotId || 'slot1') : null;
    const isNewReg = !existing;

    const regData = {
      paperId,
      studentId,
      studentName,
      studentPhone: normPhone || studentPhone || '',
      selectedSlot: slotId,
      slotId: slotId,
      status: 'registered',
      isCameraActive: false,
      registeredAt: new Date().toISOString()
    };

    // 1. INSTANT IN-MEMORY CACHE UPDATE (0ms response)
    this.setCache(cacheKey, regData);
    const allRegsKey = `all_regs_${studentId}`;
    const allRegs = this.getCached(allRegsKey);
    if (allRegs) {
      allRegs[paperId] = regData;
      this.setCache(allRegsKey, allRegs);
    }
    this.clearCache('paper_sessions');

    // 2. Fire-and-forget backend notification (never blocks user interaction)
    try {
      callBackend('papers/register-slot', { paperId, slotId }).catch(() => {});
    } catch (_) {}

    // 3. Fast direct Firestore write via SDK (handles offline/optimistic updates)
    const sessionRef = doc(db, 'paper_sessions', paperId);
    const writePromises = [
      setDoc(doc(db, 'paper_registrations', `${paperId}_${studentId}`), regData, { merge: true })
    ];
    if (isNewReg) {
      const fieldName = slotId === 'slot2' ? 'slot2.registeredCount' : 'slot1.registeredCount';
      writePromises.push(updateDoc(sessionRef, { [fieldName]: increment(1) }).catch(() => {}));
    } else if (isSlotChange) {
      const decField = prevSlot === 'slot2' ? 'slot2.registeredCount' : 'slot1.registeredCount';
      const incField = slotId === 'slot2' ? 'slot2.registeredCount' : 'slot1.registeredCount';
      writePromises.push(updateDoc(sessionRef, { [decField]: increment(-1), [incField]: increment(1) }).catch(() => {}));
    }

    Promise.all(writePromises).catch(directErr => {
      console.warn('[DB] Background Firestore registration write notice:', directErr);
    });

    return regData;
  }

  async getStudentRegistration(paperId, studentId, { forceRefresh = false } = {}) {
    if (!paperId || !studentId) return null;
    const cacheKey = `paper_reg_${paperId}_${studentId}`;
    if (!forceRefresh) {
      const cached = this.getCached(cacheKey, 60000);
      if (cached !== null && cached !== undefined) return cached;
    }
    try {
      const snap = await Promise.race([
        getDoc(doc(db, 'paper_registrations', `${paperId}_${studentId}`)),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 1500))
      ]);
      const res = snap && snap.exists() ? { id: snap.id, ...snap.data() } : null;
      this.setCache(cacheKey, res);
      return res;
    } catch (error) {
      return this.getCached(cacheKey) || null;
    }
  }

  async getStudentAllRegistrations(studentId, phone = '') {
    if (!studentId) return new Map();
    const cacheKey = `all_regs_${studentId}`;
    const cached = this.getCached(cacheKey, 60000);
    if (cached) return new Map(Object.entries(cached));

    const map = new Map();
    try {
      const regsRef = collection(db, 'paper_registrations');
      const q = query(regsRef, where('studentId', '==', studentId), limit(50));
      const snap = await Promise.race([
        getDocs(q),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 1800))
      ]);
      if (snap && !snap.empty) {
        snap.forEach(d => {
          const data = { id: d.id, ...d.data() };
          if (data.paperId) {
            map.set(data.paperId, data);
            this.setCache(`paper_reg_${data.paperId}_${studentId}`, data);
          }
        });
      }
      if (map.size === 0 && phone) {
        const normPhone = normalizePhone(phone);
        if (normPhone) {
          const qPhone = query(regsRef, where('studentPhone', '==', normPhone), limit(50));
          const snapPhone = await getDocs(qPhone).catch(() => null);
          if (snapPhone && !snapPhone.empty) {
            snapPhone.forEach(d => {
              const data = { id: d.id, ...d.data() };
              if (data.paperId) {
                map.set(data.paperId, data);
                this.setCache(`paper_reg_${data.paperId}_${studentId}`, data);
              }
            });
          }
        }
      }
      this.setCache(cacheKey, Object.fromEntries(map));
    } catch (e) {
      console.warn('[DB] getStudentAllRegistrations notice:', e);
    }
    return map;
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
        list.push(data);
      });
      const deduped = this.deduplicateRegistrations(list);
      if (!slotId || slotId === 'all') {
        return deduped;
      }
      return deduped.filter(r => (r.selectedSlot || 'slot1') === slotId);
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
        const deduped = this.deduplicateRegistrations(all);
        if (!slotId || slotId === 'all') {
          callback(deduped);
        } else {
          callback(deduped.filter(r => (r.selectedSlot || 'slot1') === slotId));
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
    reviewDetails,
    isSubmitted,
    isOnline
  }) {
    if (!paperId || !studentId) return;
    try {
      const regDocId = `${paperId}_${studentId}`;
      const regRef = doc(db, 'paper_registrations', regDocId);
      const updates = {
        paperId,
        studentId,
        isCameraActive: !!isCameraActive,
        isOnline: isOnline !== undefined ? !!isOnline : true,
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
      if (isSubmitted === true) {
        updates.isSubmitted = true;
        updates.status = 'submitted';
        updates.isCameraActive = false;
        if (!updates.submittedAt) updates.submittedAt = serverTimestamp();
      }
      if (status) {
        if (status === 'submitted') {
          updates.status = 'submitted';
          updates.isSubmitted = true;
          updates.isCameraActive = false;
          if (!updates.submittedAt) updates.submittedAt = serverTimestamp();
        } else if (status === 'in_exam') {
          updates.status = 'in_exam';
          updates.joinedAt = serverTimestamp();
        } else {
          updates.status = status;
        }
      }
      if (submissionPhotos && Array.isArray(submissionPhotos) && submissionPhotos.length > 0) {
        updates.submissionPhotos = submissionPhotos;
        updates.submissionUrl = submissionPhotos[0];
        updates.isSubmitted = true;
        updates.status = 'submitted';
        updates.isCameraActive = false;
      }

      // Safeguard: Check existing record so a submitted student can NEVER be reverted back to 'in_exam'
      try {
        const existingSnap = await getDoc(regRef);
        if (existingSnap.exists()) {
          const prev = existingSnap.data() || {};
          if (prev.isSubmitted === true || prev.status === 'submitted' || prev.submittedAt || (prev.submissionPhotos && prev.submissionPhotos.length > 0) || prev.mcqScore !== undefined) {
            updates.isSubmitted = true;
            updates.status = 'submitted';
            updates.isCameraActive = false;
            updates.cameraSnapshotUrl = null;
          }
        }
      } catch (_) {}

      await setDoc(regRef, updates, { merge: true });

      if (updates.isSubmitted === true || updates.status === 'submitted') {
        const cacheKey = `paper_reg_${paperId}_${studentId}`;
        this.setCache(cacheKey, { ...updates, paperId, studentId });
        const allRegsKey = `all_regs_${studentId}`;
        const allRegs = this.getCached(allRegsKey);
        if (allRegs) {
          allRegs[paperId] = { ...(allRegs[paperId] || {}), ...updates, paperId, studentId };
          this.setCache(allRegsKey, allRegs);
        }
        this.invalidateRegistrationCache(paperId, studentId, studentPhone);
      }
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
      updates.currentPhase = 'waiting';
      updates.isTimeUp = false;
      updates.timeUpAt = null;
      updates.isEnded = false;
      updates.endedAt = null;
      updates.isLive = false;
    } else if (phase === 'package_opening') {
      updates.status = 'active';
      updates.currentPhase = 'package_opening';
      updates.isTimeUp = false;
      updates.timeUpAt = null;
      updates.isEnded = false;
      updates.endedAt = null;
      updates.isLive = true;
      updates.packageOpeningStartedAt = nowIso;
      alertMessage = '📦 ප්‍රශ්න පත්‍ර පාර්සලය කැමරාව ඉදිරියේ විවෘත කරන්න! (Open your exam parcel in front of the camera now!)';
      alertType = 'urgent';
    } else if (phase === 'writing') {
      updates.status = 'active';
      updates.currentPhase = 'writing';
      updates.isTimeUp = false;
      updates.timeUpAt = null;
      updates.isEnded = false;
      updates.endedAt = null;
      updates.isLive = true;
      updates.packageOpeningEndedAt = nowIso;
      try {
        const docRef = doc(db, 'paper_sessions', paperId);
        const existingSnap = await getDoc(docRef);
        const existingData = existingSnap.exists() ? existingSnap.data() : null;
        if (forceResetTimer || !existingData?.writingStartedAt) {
          updates.writingStartedAt = nowIso;
        }
      } catch (_) {
        if (forceResetTimer) {
          updates.writingStartedAt = nowIso;
        }
      }
      alertMessage = '✍️ විභාගය ආරම්භ විය! දැන් පිළිතුරු ලිවීම ආරම්භ කරන්න. (Exam Writing has started!)';
      alertType = 'info';
    } else if (phase === 'time_up') {
      updates.status = 'active';
      updates.currentPhase = 'time_up';
      updates.isTimeUp = true;
      updates.timeUpAt = nowIso;
      updates.isEnded = false;
      updates.endedAt = null;
      updates.isLive = true;
      alertMessage = '⏰ වේලාව අවසන් විය! ලිවීම නවතා ඔබගේ පිළිතුරු පත්‍ර In-App Scanner එකෙන් Scan කර දැන්ම Submit කරන්න.';
      alertType = 'urgent';
    } else if (phase === 'ended') {
      updates.status = 'ended';
      updates.currentPhase = 'ended';
      updates.isTimeUp = false;
      updates.isEnded = true;
      updates.isLive = false;
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

    if (phase === 'package_opening' || phase === 'writing') {
      this.broadcastSessionAlert(paperId, 'live').catch(() => {});
    } else if (phase === 'time_up') {
      this.broadcastSessionAlert(paperId, 'time_up').catch(() => {});
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
        status: 'active',
        isEnded: false,
        endedAt: null,
        isLive: true,
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
        isTimeUp: false,
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

  async startPaperSession(paperId, { notifyStudents = true } = {}) {
    if (!paperId) return;
    const nowIso = new Date().toISOString();
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      await updateDoc(docRef, {
        status: 'active',
        currentPhase: 'package_opening',
        isLive: true,
        isStarted: true,
        startedAt: nowIso,
        packageOpeningStartedAt: nowIso,
        notifyOnStart: notifyStudents !== false,
        lastStartedTimestamp: Date.now()
      });
    } catch (e) {
      console.warn('[DB] startPaperSession updateDoc error:', e);
    }
    this.broadcastProctorAlert({
      paperId,
      senderName: 'Admin / Examiner',
      message: '📦 විභාග සැසිය ආරම්භ විය! කැමරාව ඉදිරියේ ප්‍රශ්න පත්‍ර පාර්සලය විවෘත කරන්න. (Exam is Live)',
      type: 'urgent'
    }).catch(() => {});
    if (notifyStudents !== false) {
      this.broadcastSessionAlert(paperId, 'live').catch(() => {});
    }
  }

  async broadcastSessionAlert(paperId, action = 'live', { title = null, message = null } = {}) {
    if (!paperId) return;
    try {
      const sess = await this.getPaperSession(paperId);
      const examYear = sess?.examYear || 'All Batches';
      const paperTitle = title || sess?.title || 'Physics Examination Paper';
      await callBackend('papers/broadcast', {
        paperId,
        action,
        examYear,
        title: paperTitle,
        message
      });
      console.log(`[DB] Broadcast triggered for paper ${paperId} (${action})`);
    } catch (err) {
      console.warn('[DB] broadcastSessionAlert notice:', err.message);
    }
  }

  async reopenPaperSession(paperId) {
    if (!paperId) return;
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      await updateDoc(docRef, {
        status: 'active',
        currentPhase: 'writing',
        isLive: true,
        isEnded: false,
        endedAt: null,
        isTimeUp: false,
        timeUpAt: null
      });
    } catch (e) {
      console.warn('[DB] reopenPaperSession error:', e);
    }
    this.broadcastProctorAlert({
      paperId,
      senderName: 'Admin / Examiner',
      message: '🔄 විභාග සැසිය නැවත විවෘත කරන ලදී. සිසුන්ට දැන් නැවත සම්බන්ධ විය හැක. (Session Reopened by Admin)',
      type: 'info'
    }).catch(() => {});
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

  async updateSlotTimes(paperId, { slot1, slot2, notifyStudents, notifyOnStart }) {
    if (!paperId) return;
    try {
      const docRef = doc(db, 'paper_sessions', paperId);
      const updates = {};
      if (slot1) updates.slot1 = slot1;
      if (slot2) updates.slot2 = slot2;
      if (notifyStudents !== undefined) updates.notifyStudents = notifyStudents;
      if (notifyOnStart !== undefined) updates.notifyOnStart = notifyOnStart;
      await updateDoc(docRef, updates);
      this.clearCache('paper_sessions');
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
  getSeedScholars() {
    return [];
  }

  async getLeaderboard(batch, { forceRefresh = false } = {}) {
    const cacheKey = `leaderboard_${batch || 'all'}`;
    if (!forceRefresh && !this._isAdminActive()) {
      const cached = this.getCached(cacheKey);
      if (cached && Array.isArray(cached) && cached.length > 0) {
        if (!this._revalidating.has(cacheKey)) {
          this._revalidating.add(cacheKey);
          setTimeout(() => {
            this.getLeaderboard(batch, { forceRefresh: true })
              .then(fresh => {
                this._revalidating.delete(cacheKey);
                if (fresh && JSON.stringify(fresh) !== JSON.stringify(cached)) {
                  window.dispatchEvent(new CustomEvent('edupeak:swr-updated', { detail: { type: 'ranks', data: fresh } }));
                }
              }).catch(() => { this._revalidating.delete(cacheKey); });
          }, 300);
        }
        return cached;
      }
    }

    try {
      // 1. Fetch from Supabase profiles (real verified student scholars)
      let supabaseList = [];
      try {
        if (supabase) {
          const { data: supaProfiles, error: supaErr } = await supabase
            .from('profiles')
            .select('id, name, full_name, email, phone, role, exam_year, credits')
            .limit(150);
          if (!supaErr && Array.isArray(supaProfiles)) {
            supabaseList = supaProfiles.map((p) => ({
              id: p.id,
              role: p.role || 'student',
              name: p.full_name || p.name || 'Student',
              examYear: p.exam_year || '2027 A/L',
              credits: Number(p.credits) || 0,
              avatarUrl: '',
              studentPhone: p.phone || ''
            }));
          }
        }
      } catch (e) {
        console.warn('[DB] Supabase leaderboard fetch note:', e);
      }

      // 2. Fetch from Firestore public leaderboard collection
      let firestoreList = [];
      try {
        const q = collection(db, 'leaderboard_public');
        const snapshot = await Promise.race([
          getDocs(q),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Firestore timeout')), 3500))
        ]);
        firestoreList = snapshot.docs.map((studentDoc) => {
          const student = studentDoc.data();
          return {
            rank: 0,
            id: studentDoc.id,
            role: 'student',
            name: student.name || 'Student',
            examYear: student.examYear || '2027 A/L',
            credits: Number(student.credits) || 0,
            avatarUrl: student.avatarUrl || student.photoUrl || '',
            studentPhone: student.studentPhone || student.phone || ''
          };
        });
      } catch (e) {
        console.warn('[DB] Firestore leaderboard fetch note:', e);
      }

      // 3. Read local leaderboard cache
      let localLb = [];
      try {
        localLb = JSON.parse(localStorage.getItem('edupeak_local_leaderboard') || '[]');
      } catch (_) {}

      // 4. Read approved dessert submissions to aggregate real XP for students
      const dessertCreditMap = {};
      const dessertBatchMap = {};
      try {
        const localDesserts = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
        localDesserts.forEach((d) => {
          if (d.status === 'approved') {
            const key = (d.studentName || d.studentId || '').trim();
            const amt = Number(d.creditsAwarded) || 0;
            if (key) {
              dessertCreditMap[key] = (dessertCreditMap[key] || 0) + amt;
              if (d.examYear) dessertBatchMap[key] = d.examYear;
            }
          }
        });
      } catch (_) {}

      const map = new Map();

      // Aggregate Supabase entries
      for (const s of supabaseList) {
        if (!s.name) continue;
        const key = s.name.toLowerCase().trim();
        map.set(key, { ...s, credits: Number(s.credits) || 0 });
      }

      // Aggregate local leaderboard entries
      for (const s of localLb) {
        if (!s.name) continue;
        const key = s.name.toLowerCase().trim();
        const existing = map.get(key) || {};
        map.set(key, { ...existing, ...s, credits: Math.max(Number(s.credits) || 0, existing.credits || 0) });
      }

      // Aggregate Firestore entries
      for (const s of firestoreList) {
        if (!s.name) continue;
        const key = s.name.toLowerCase().trim();
        const existing = map.get(key) || {};
        map.set(key, { ...existing, ...s, credits: Math.max(Number(s.credits) || 0, existing.credits || 0) });
      }

      // Incorporate aggregated dessert XP
      for (const [studentKey, awardedXp] of Object.entries(dessertCreditMap)) {
        const normKey = studentKey.toLowerCase().trim();
        let found = false;
        for (const [k, v] of map.entries()) {
          if (k === normKey || (v.id && v.id.toLowerCase() === normKey)) {
            v.credits = Math.max(v.credits, (v.credits || 0) + awardedXp);
            found = true;
            break;
          }
        }
        if (!found) {
          map.set(normKey, {
            id: 'student_' + studentKey.replace(/\s+/g, '_'),
            name: studentKey,
            role: 'student',
            examYear: dessertBatchMap[studentKey] || '2027 A/L',
            credits: awardedXp,
            avatarUrl: ''
          });
        }
      }

      // Check if current logged-in student has direct local credits or needs to be on board
      try {
        const currentStoredUser = JSON.parse(
          localStorage.getItem('edupeak_cached_user') ||
          localStorage.getItem('edupeak_auth_user') ||
          'null'
        );
        if (currentStoredUser && currentStoredUser.name && currentStoredUser.role === 'student') {
          const key = currentStoredUser.name.toLowerCase().trim();
          const customCredits = localStorage.getItem(`edupeak_credits_${currentStoredUser.uid || currentStoredUser.id}`);
          let cNum = Number(customCredits) || Number(currentStoredUser.credits) || 0;
          if (cNum === 355 || cNum === 155 || cNum === 305) cNum = 200;
          if (map.has(key)) {
            map.get(key).credits = Math.max(map.get(key).credits, cNum);
          } else {
            map.set(key, {
              id: currentStoredUser.uid || currentStoredUser.id || 'student_me',
              name: currentStoredUser.name,
              role: 'student',
              examYear: currentStoredUser.examYear || currentStoredUser.exam_year || '2027 A/L',
              credits: cNum,
              avatarUrl: currentStoredUser.avatarUrl || ''
            });
          }
        }
      } catch (_) {}

      const allStudents = Array.from(map.values());

      // Filter by batch
      const normalizeBatch = (b) => String(b || '').replace(/\s+/g, '').toUpperCase();
      const targetBatchNorm = normalizeBatch(batch);

      const filtered = allStudents.filter(student => {
        if (student.role !== 'student' || this.isStaffOrAdmin(student)) return false;
        if (!batch || batch === 'All Batches' || targetBatchNorm === 'ALL' || targetBatchNorm === 'ALLBATCHES') return true;
        const sBatchNorm = normalizeBatch(student.examYear);
        return sBatchNorm === targetBatchNorm || sBatchNorm === 'ALL' || sBatchNorm === 'ALLBATCHES';
      });

      // Sort descending by credits
      filtered.sort((a, b) => (b.credits - a.credits) || a.name.localeCompare(b.name));

      // Assign ranks
      filtered.forEach((s, idx) => {
        s.rank = idx + 1;
      });

      this.setCache(cacheKey, filtered);
      return filtered;
    } catch (err) {
      console.error('[DB] getLeaderboard unexpected error:', err);
      return [];
    }
  }

  streamLeaderboard(batch, callback) {
    let active = true;
    const fetchAndNotify = async () => {
      if (!active) return;
      try {
        const list = await this.getLeaderboard(batch, { forceRefresh: true });
        if (active) callback(list);
      } catch (err) {
        console.warn('[DB] streamLeaderboard error:', err);
      }
    };

    // Initial load
    fetchAndNotify();

    // Listen to local credits events
    const onCreditsUpdated = () => fetchAndNotify();
    window.addEventListener('edupeak:credits-updated', onCreditsUpdated);
    window.addEventListener('edupeak:dessert-reviewed', onCreditsUpdated);

    // Listen to Firestore if available
    let firestoreUnsub = null;
    try {
      const ref = collection(db, 'leaderboard_public');
      firestoreUnsub = onSnapshot(ref, () => {
        fetchAndNotify();
      }, (err) => {
        console.warn('[DB] firestore streamLeaderboard warning:', err);
      });
    } catch (_) {}

    return () => {
      active = false;
      window.removeEventListener('edupeak:credits-updated', onCreditsUpdated);
      window.removeEventListener('edupeak:dessert-reviewed', onCreditsUpdated);
      if (firestoreUnsub) {
        try { firestoreUnsub(); } catch (_) {}
      }
    };
  }

  async sendStudentPushNotification({ studentId, studentPhone, studentName, title, message, sender = 'Teacher' }) {
    const payload = {
      studentId: String(studentId || '').trim(),
      studentPhone: String(studentPhone || '').trim(),
      studentName: String(studentName || 'Student').trim(),
      title: String(title || '').trim(),
      message: String(message || '').trim(),
      sender: String(sender || 'Teacher').trim(),
      createdAt: serverTimestamp ? serverTimestamp() : new Date(),
      timestamp: Date.now(),
      read: false
    };

    try {
      if (db) {
        await addDoc(collection(db, 'student_notifications'), payload);
      }
    } catch (e) {
      console.warn('[DB] Firestore student notification note:', e);
    }

    try {
      if (typeof BroadcastChannel !== 'undefined') {
        const bc = new BroadcastChannel('edupeak_student_notifs');
        bc.postMessage(payload);
        bc.close();
      }
    } catch (_) {}

    return true;
  }

  streamStudentDirectNotifications(studentId, studentPhone, callback) {
    if (!db || (!studentId && !studentPhone)) return () => {};
    let initialized = false;
    const seenIds = new Set();
    const cleanPhone = String(studentPhone || '').replace(/\D/g, '');
    const cleanId = String(studentId || '').trim();

    try {
      const q = query(
        collection(db, 'student_notifications'),
        orderBy('timestamp', 'desc'),
        limit(20)
      );
      const unsubscribe = onSnapshot(q, (snapshot) => {
        if (!initialized) {
          initialized = true;
          snapshot.docs.forEach(d => seenIds.add(d.id));
          return;
        }
        snapshot.docChanges().forEach((change) => {
          if (change.type === 'added' && !seenIds.has(change.doc.id)) {
            seenIds.add(change.doc.id);
            const data = change.doc.data();
            const targetId = String(data.studentId || '').trim();
            const targetPhone = String(data.studentPhone || '').replace(/\D/g, '');
            const isForMe = (cleanId && targetId && cleanId === targetId) ||
              (cleanPhone && targetPhone && cleanPhone === targetPhone);
            if (isForMe) {
              callback({ id: change.doc.id, ...data });
            }
          }
        });
      }, (err) => {
        console.warn('[DB] streamStudentDirectNotifications warning:', err);
      });

      let bc = null;
      try {
        if (typeof BroadcastChannel !== 'undefined') {
          bc = new BroadcastChannel('edupeak_student_notifs');
          bc.onmessage = (event) => {
            const data = event.data;
            if (!data) return;
            const targetId = String(data.studentId || '').trim();
            const targetPhone = String(data.studentPhone || '').replace(/\D/g, '');
            const isForMe = (cleanId && targetId && cleanId === targetId) ||
              (cleanPhone && targetPhone && cleanPhone === targetPhone);
            if (isForMe) {
              callback(data);
            }
          };
        }
      } catch (_) {}

      return () => {
        try { unsubscribe(); } catch (_) {}
        try { if (bc) bc.close(); } catch (_) {}
      };
    } catch (e) {
      console.warn('[DB] streamStudentDirectNotifications error:', e);
      return () => {};
    }
  }

  streamPaperLeaderboards(callback) {
    try {
      const ref = collection(db, 'paper_leaderboards');
      return onSnapshot(ref, (snapshot) => {
        const list = snapshot.docs.map((paperDoc) => {
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
            notifyStudents: data.notifyStudents !== false,
            entries,
          };
        }).sort((a, b) => b.publishedAt - a.publishedAt);
        callback(list);
      }, (err) => {
        console.warn('[DB] streamPaperLeaderboards error:', err);
      });
    } catch (e) {
      console.warn('[DB] streamPaperLeaderboards setup error:', e);
      return () => {};
    }
  }

  async getPaperLeaderboards({ forceRefresh = false } = {}) {
    const cacheKey = 'paper_leaderboards';
    if (!forceRefresh && !this._isAdminActive()) {
      const cached = this.getCached(cacheKey);
      if (cached && Array.isArray(cached) && cached.length > 0) {
        if (!this._revalidating.has(cacheKey)) {
          this._revalidating.add(cacheKey);
          setTimeout(() => {
            this.getPaperLeaderboards({ forceRefresh: true })
              .then(fresh => {
                this._revalidating.delete(cacheKey);
                if (fresh && JSON.stringify(fresh) !== JSON.stringify(cached)) {
                  window.dispatchEvent(new CustomEvent('edupeak:swr-updated', { detail: { type: 'paper_leaderboards', data: fresh } }));
                }
              }).catch(() => { this._revalidating.delete(cacheKey); });
          }, 300);
        }
        return cached;
      }
    }
    try {
      const ref = collection(db, 'paper_leaderboards');
      const snapshot = await Promise.race([
        getDocs(ref),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Paper leaderboards timeout')), 2800))
      ]);
      const finalBoards = snapshot.docs.map((paperDoc) => {
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
          notifyStudents: data.notifyStudents !== false,
          entries,
        };
      }).sort((a, b) => b.publishedAt - a.publishedAt);
      this.setCache(cacheKey, finalBoards);
      return finalBoards;
    } catch (e) {
      console.warn('[DB] getPaperLeaderboards error:', e);
      return [];
    }
  }

  async savePaperLeaderboard(leaderboard) {
    try {
      const isNew = !leaderboard.id;
      const ref = collection(db, 'paper_leaderboards');
      const payload = {
        ...leaderboard,
        notifyStudents: leaderboard.notifyStudents !== false,
        publishedAt: leaderboard.publishedAt || new Date().toISOString()
      };
      if (isNew) {
        const docRef = await addDoc(ref, payload);
        this.clearCache('paper_leaderboards');
        return docRef.id;
      } else {
        await setDoc(doc(db, 'paper_leaderboards', leaderboard.id), payload, { merge: true });
        this.clearCache('paper_leaderboards');
        return leaderboard.id;
      }
    } catch (e) {
      console.warn('[DB] savePaperLeaderboard error:', e);
      throw e;
    }
  }

  async deletePaperLeaderboard(id) {
    if (!id) return;
    try {
      await deleteDoc(doc(db, 'paper_leaderboards', id));
    } catch (e) {
      console.warn('[DB] deletePaperLeaderboard error:', e);
      throw e;
    }
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

  streamSprintAttempts(date, callback) {
    try {
      const q = query(
        collection(db, 'sprint_attempts'),
        where('date', '==', date),
        limit(200)
      );
      return onSnapshot(q, (snapshot) => {
        const list = snapshot.docs
          .map((attempt) => ({ id: attempt.id, ...attempt.data() }))
          .sort((a, b) => Number(b.score || 0) - Number(a.score || 0)
            || Number(a.timeTakenSeconds || 0) - Number(b.timeTakenSeconds || 0));
        callback(list);
      }, (e) => {
        console.warn('[DB] streamSprintAttempts error:', e);
      });
    } catch (e) {
      console.warn('[DB] streamSprintAttempts setup error:', e);
      return () => {};
    }
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

  async getDailyInsight({ forceRefresh = false } = {}) {
    const cacheKey = 'daily_physics_insight';
    if (!forceRefresh && !this._isAdminActive()) {
      const cached = this.getCached(cacheKey);
      if (cached && cached.concept) {
        if (!this._revalidating.has(cacheKey)) {
          this._revalidating.add(cacheKey);
          setTimeout(() => {
            this.getDailyInsight({ forceRefresh: true })
              .then(fresh => {
                this._revalidating.delete(cacheKey);
                if (fresh && JSON.stringify(fresh) !== JSON.stringify(cached)) {
                  window.dispatchEvent(new CustomEvent('edupeak:swr-updated', { detail: { type: 'insight', data: fresh } }));
                }
              }).catch(() => { this._revalidating.delete(cacheKey); });
          }, 500);
        }
        return cached;
      }
    }
    try {
      const docRef = doc(db, 'system_config', 'daily_physics_insight');
      const snap = await Promise.race([
        getDoc(docRef),
        new Promise((_, reject) => setTimeout(() => reject(new Error('getDailyInsight timeout')), 600))
      ]);
      if (snap.exists()) {
        const data = snap.data();
        if (data && data.isCustom) {
          const customRes = {
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
          this.setCache(cacheKey, customRes);
          try { localStorage.setItem('edupeak_cached_daily_insight', JSON.stringify(customRes)); } catch (_) {}
          return customRes;
        }
      }
    } catch (e) {
      console.warn('Daily insight cloud fetch warning, falling back to rotation:', e);
    }

    const presets = this.getPresetPhysicsInsights();
    const dayOfYear = Math.floor((new Date() - new Date(new Date().getFullYear(), 0, 0)) / (1000 * 60 * 60 * 24));
    const p = presets[dayOfYear % presets.length];
    const fallbackInsight = {
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
    this.setCache(cacheKey, fallbackInsight);
    return fallbackInsight;
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
    return [];
  }

}

export const dbService = new DbService();
