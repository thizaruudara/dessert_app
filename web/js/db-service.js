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

export class DbService {
  constructor() {
    this.dessertListeners = [];
  }

  // ── 1. Desserts (Homework Submissions) ─────────────────────────────────────
  async getStudentDesserts(studentId, studentPhone, studentName) {
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
    return list;
  }

  // Real-time listener for student's homework status
  listenToStudentDesserts(studentId, studentPhone, callback, studentName) {
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

    try {
      window.dispatchEvent(new CustomEvent('edupeak:dessert-submitted', { detail: newDoc }));
      localStorage.setItem('edupeak_last_sync_event', JSON.stringify({ type: 'dessert-submitted', data: newDoc, timestamp: Date.now() }));
    } catch (_) {}

    return newDoc;
  }

  // Get student accumulated credits from local cache, submissions, and leaderboard
  async getStudentCredits(studentId, studentPhone, studentIndex, studentName) {
    let credits = 0;
    const cleanPhone = String(studentPhone || '').replace(/\D/g, '');
    const cleanName = String(studentName || '').toLowerCase().trim();
    const cleanId = String(studentId || '').trim();
    const cleanIdx = String(studentIndex || '').trim();

    // 1. Check live Firestore leaderboard_public (authoritative source for student XP)
    const idsToFetch = Array.from(new Set([cleanIdx, cleanId].filter(Boolean)));
    for (const fetchId of idsToFetch) {
      try {
        const lbSnap = await Promise.race([
          getDoc(doc(db, 'leaderboard_public', fetchId)),
          new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 1800))
        ]).catch(() => null);
        if (lbSnap && lbSnap.exists()) {
          const lbCredits = Number(lbSnap.data()?.credits) || 0;
          if (lbCredits > 0) credits = Math.max(credits, lbCredits);
        }
      } catch (_) {}
    }

    // 2. Read live credits from Firestore users collection
    for (const fetchId of idsToFetch) {
      try {
        const uSnap = await Promise.race([
          getDoc(doc(db, 'users', fetchId)),
          new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 1800))
        ]).catch(() => null);
        if (uSnap && uSnap.exists()) {
          const uCredits = Number(uSnap.data()?.credits) || 0;
          if (uCredits > 0) credits = Math.max(credits, uCredits);
        }
      } catch (_) {}
    }

    // 3. Sum up all approved dessert submissions for this student from localDesserts & Firestore
    let approvedDessertCredits = 0;
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
    if (approvedDessertCredits > 0) {
      credits = Math.max(credits, approvedDessertCredits);
    }

    // 4. Check local leaderboard cache and sanitize any +155 contamination
    try {
      const localLb = JSON.parse(localStorage.getItem('edupeak_local_leaderboard') || '[]');
      const entry = localLb.find(x => {
        const xPhone = String(x.studentPhone || '').replace(/\D/g, '');
        const xId = String(x.id || '').trim();
        const xName = String(x.name || '').toLowerCase().trim();
        if (cleanId && xId === cleanId) return true;
        if (cleanIdx && xId === cleanIdx) return true;
        if (cleanPhone && xPhone && (xPhone.endsWith(cleanPhone.slice(-9)) || cleanPhone.endsWith(dPhone.slice(-9)))) return true;
        if (cleanName && xName && xName === cleanName) return true;
        return false;
      });
      if (entry && entry.credits) {
        let entryCr = Number(entry.credits) || 0;
        if (entryCr > 0 && approvedDessertCredits > 0 && entryCr === approvedDessertCredits + 155) {
          entryCr = approvedDessertCredits;
          entry.credits = approvedDessertCredits;
          localStorage.setItem('edupeak_local_leaderboard', JSON.stringify(localLb));
        }
        credits = Math.max(credits, entryCr);
      }
    } catch (_) {}

    // 5. Inspect localStorage cached keys and sanitize legacy +155 contamination
    const keysToCheck = [
      cleanId && `edupeak_credits_${cleanId}`,
      cleanIdx && `edupeak_credits_${cleanIdx}`,
      cleanPhone && `edupeak_credits_${cleanPhone}`,
      studentPhone && `edupeak_credits_${studentPhone}`,
      cleanName && `edupeak_credits_${cleanName}`
    ].filter(Boolean);

    for (const k of keysToCheck) {
      try {
        const val = localStorage.getItem(k);
        if (val) {
          let num = Number(val) || 0;
          // Auto-heal legacy mock offset (e.g., 200 + 155 = 355)
          if (num > 0 && credits > 0 && num === credits + 155) {
            num = credits;
            localStorage.setItem(k, String(credits));
          } else if (credits === 0 && num === 155) {
            num = 0;
            localStorage.setItem(k, '0');
          }
          credits = Math.max(credits, num);
        }
      } catch (_) {}
    }

    // Always sanitize localStorage with authoritative credits
    if (credits > 0) {
      for (const k of keysToCheck) {
        try {
          localStorage.setItem(k, String(credits));
        } catch (_) {}
      }
    }

    return credits > 0 ? credits : 0;
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

        for (const loc of localList) {
          if (!list.some(d => d.id === loc.id || (d.submittedAt && d.submittedAt === loc.submittedAt))) {
            list.push(loc);
          }
        }
        list.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));
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
      name.includes('senanayake') ||
      name.includes('staff') ||
      name.includes('instructor')
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

  // Admin: Get student roster (strictly excludes admin/teacher/staff accounts)
  async getAllStudents() {
    let list = [];
    try {
      const usersRef = collection(db, 'users');
      const snap = await Promise.race([
        getDocs(usersRef),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3500))
      ]);
      if (!snap.empty) {
        list = snap.docs
          .map(d => ({ id: d.id, ...d.data() }))
          .filter(u => !this.isStaffOrAdmin(u));
      }
    } catch (_) {}

    const map = new Map();
    for (const u of list) {
      if (this.isStaffOrAdmin(u)) continue;
      const key = (u.phone || u.studentId || u.id || u.name).toLowerCase().trim();
      map.set(key, { ...u });
    }

    // Incorporate students from local submissions (such as Test User)
    try {
      const localDesserts = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
      for (const d of localDesserts) {
        if (!d.studentName) continue;
        if (this.isStaffOrAdmin({ name: d.studentName, phone: d.studentPhone, id: d.studentId, role: d.role })) continue;
        const key = (d.studentPhone || d.studentId || d.studentName).toLowerCase().trim();
        if (!map.has(key)) {
          map.set(key, {
            id: d.studentId || ('st_' + key.replace(/\s+/g, '_')),
            name: d.studentName,
            phone: d.studentPhone || '',
            examYear: d.examYear || '2027 A/L',
            credits: Number(d.creditsAwarded) || 0,
            studentId: d.studentId || '',
            role: 'student'
          });
        }
      }
    } catch (_) {}

    // Calculate exact, accurate credits for all students in parallel
    const students = Array.from(map.values()).filter(u => !this.isStaffOrAdmin(u));
    await Promise.all(students.map(async (st) => {
      const trueCredits = await this.getStudentCredits(
        st.id,
        st.phone,
        st.studentId,
        st.name
      );
      st.credits = Math.max(Number(st.credits) || 0, trueCredits);
    }));

    return students;
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
      mcqCount: Math.min(100, Math.max(1, Number(raw.mcqCount) || 50)),
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
      syllabusTopics: Array.isArray(raw.syllabusTopics) ? raw.syllabusTopics : [],
      hints: raw.hints || '',
      instructions: raw.instructions || ''
    };
  }

  getMockPaperSessions(examYear) {
    return [];
  }

  getMockUpcomingPapers(examYear) {
    return [];
  }

  async getPaperSessions(examYear) {
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
        return result;
      }
    } catch (e) {
      console.warn('[DB] getPaperSessions note/timeout:', e?.message || e);
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
        callback(result);
      }, (err) => {
        console.warn('[DB] streamPaperSessions error:', err);
      });
    } catch (e) {
      console.warn('[DB] streamPaperSessions setup error:', e);
      return () => {};
    }
  }

  async getUpcomingPapers(examYear) {
    try {
      const ref = collection(db, 'upcoming_papers');
      const snap = await Promise.race([
        getDocs(ref),
        new Promise((_, reject) => setTimeout(() => reject(new Error('getUpcomingPapers timeout')), 2800))
      ]);
      if (!snap.empty) {
        const list = snap.docs.map(d => this.normalizeUpcomingPaper(d.data(), d.id)).filter(Boolean);
        if (examYear && examYear !== 'All' && examYear !== 'All Batches') {
          return list.filter(p => this.matchesYear(p.examYear, examYear));
        }
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
    reviewDetails,
    isSubmitted
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
      if (forceResetTimer) {
        updates.packageOpeningStartedAt = nowIso;
      }
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
      if (forceResetTimer) {
        updates.writingStartedAt = nowIso;
      }
      updates.packageOpeningEndedAt = nowIso;
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
  getSeedScholars() {
    return [];
  }

  async getLeaderboard(batch) {
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

    // Read local leaderboard cache
    let localLb = [];
    try {
      localLb = JSON.parse(localStorage.getItem('edupeak_local_leaderboard') || '[]');
    } catch (_) {}

    // Read approved dessert submissions to aggregate real XP for students
    const dessertCreditMap = {};
    const dessertBatchMap = {};
    try {
      const localDesserts = JSON.parse(localStorage.getItem('edupeak_local_desserts') || '[]');
      localDesserts.forEach(d => {
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

    // No fake seed scholars - use only real verified scholars

    // 2. Local leaderboard entries
    for (const s of localLb) {
      if (!s.name) continue;
      const key = s.name.toLowerCase().trim();
      const existing = map.get(key) || {};
      map.set(key, { ...existing, ...s, credits: Number(s.credits) || existing.credits || 0 });
    }

    // 3. Firestore entries
    for (const s of firestoreList) {
      if (!s.name) continue;
      const key = s.name.toLowerCase().trim();
      const existing = map.get(key) || {};
      map.set(key, { ...existing, ...s, credits: Math.max(Number(s.credits) || 0, existing.credits || 0) });
    }

    // 4. Incorporate aggregated dessert XP
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

    // 5. Check if current student has direct local credits
    try {
      const currentStoredUser = JSON.parse(localStorage.getItem('edupeak_auth_user') || 'null');
      if (currentStoredUser && currentStoredUser.name) {
        const key = currentStoredUser.name.toLowerCase().trim();
        const customCredits = localStorage.getItem(`edupeak_credits_${currentStoredUser.uid || currentStoredUser.id}`);
        if (customCredits && map.has(key)) {
          map.get(key).credits = Math.max(map.get(key).credits, Number(customCredits));
        }
      }
    } catch (_) {}

    const allStudents = Array.from(map.values());

    // 6. Filter by batch
    const normalizeBatch = (b) => String(b || '').replace(/\s+/g, '').toUpperCase();
    const targetBatchNorm = normalizeBatch(batch);

    const filtered = allStudents.filter(student => {
      if (student.role !== 'student' || this.isStaffOrAdmin(student)) return false;
      if (!batch || batch === 'All Batches' || targetBatchNorm === 'ALL' || targetBatchNorm === 'ALLBATCHES') return true;
      const sBatchNorm = normalizeBatch(student.examYear);
      return sBatchNorm === targetBatchNorm || sBatchNorm === 'ALL' || sBatchNorm === 'ALLBATCHES';
    });

    // 7. Sort descending by credits
    filtered.sort((a, b) => (b.credits - a.credits) || a.name.localeCompare(b.name));

    // 8. Assign ranks
    filtered.forEach((s, idx) => {
      s.rank = idx + 1;
    });

    return filtered;
  }

  streamLeaderboard(batch, callback) {
    let active = true;
    const fetchAndNotify = async () => {
      if (!active) return;
      try {
        const list = await this.getLeaderboard(batch);
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

  async getPaperLeaderboards() {
    try {
      const ref = collection(db, 'paper_leaderboards');
      const snapshot = await Promise.race([
        getDocs(ref),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Paper leaderboards timeout')), 2800))
      ]);
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
    } catch (e) {
      console.warn('[DB] getPaperLeaderboards error:', e);
      return [];
    }
  }

  async savePaperLeaderboard(leaderboard) {
    try {
      const isNew = !leaderboard.id;
      const ref = collection(db, 'paper_leaderboards');
      if (isNew) {
        const docRef = await addDoc(ref, {
          ...leaderboard,
          publishedAt: leaderboard.publishedAt || new Date().toISOString()
        });
        return docRef.id;
      } else {
        await setDoc(doc(db, 'paper_leaderboards', leaderboard.id), {
          ...leaderboard,
          publishedAt: leaderboard.publishedAt || new Date().toISOString()
        }, { merge: true });
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
      const snap = await Promise.race([
        getDoc(docRef),
        new Promise((_, reject) => setTimeout(() => reject(new Error('getDailyInsight timeout')), 2000))
      ]);
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
    return [];
  }

}

export const dbService = new DbService();
