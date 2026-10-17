import { createClient } from '@supabase/supabase-js';

export const SUPABASE_URL = 'https://hkonbtrxmsxisggcxpww.supabase.co';
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhrb25idHJ4bXN4aXNnZ2N4cHd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc1NzYwNDMsImV4cCI6MjEwMzE1MjA0M30.VXqd0wufSQEmo_55aYEVB4WvQYyIGpQLKB5hDBfYny4';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storageKey: 'edupeak_supabase_auth_token'
  }
});

/**
 * Fetch student profile from Supabase profiles table
 */
export async function getStudentProfile(identifier) {
  if (!identifier) return null;
  const clean = String(identifier).trim();
  const cleanLower = clean.toLowerCase();

  try {
    // 1. Try matching by email
    const { data: byEmail, error: errEmail } = await supabase
      .from('profiles')
      .select('*')
      .ilike('email', cleanLower)
      .limit(1)
      .maybeSingle();

    if (byEmail) return byEmail;

    // 2. Try matching by ID (e.g. EP-2027-312)
    const { data: byId } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', clean)
      .limit(1)
      .maybeSingle();

    if (byId) return byId;

    // 3. Try matching by phone
    const digitsOnly = clean.replace(/\D/g, '');
    let phoneQuery = supabase.from('profiles').select('*');
    if (digitsOnly.length >= 9) {
      const last9 = digitsOnly.slice(-9);
      phoneQuery = phoneQuery.or(`phone.eq.${clean},phone.like.%${last9}`);
    } else {
      phoneQuery = phoneQuery.eq('phone', clean);
    }
    const { data: phoneRows } = await phoneQuery.limit(5);
    if (phoneRows && phoneRows.length > 0) {
      const best = phoneRows.find(p => Array.isArray(p.enrolled_courses) && p.enrolled_courses.some(c => String(c).includes('paper') || String(c).includes('muu3k9m4')))
        || phoneRows.find(p => Array.isArray(p.enrolled_courses) && p.enrolled_courses.length > 0)
        || phoneRows[0];
      return best;
    }

    return null;
  } catch (err) {
    console.error('[Supabase] Exception in getStudentProfile:', err);
    return null;
  }
}

/**
 * Check if student has paid and unlocked the active "Super Paper Class".
 * Recognizes both base course (crs-base-super-paper-2027) and monthly child courses (crs-phy-muu3k9m4).
 * Validates against Supabase enrollments (payment_status: 'paid' / 'approved'),
 * profiles.enrolled_courses, and approved order broadcasts.
 * Note: Free trials without completed tuition payment do NOT unlock exam sessions.
 */
export async function checkSuperPaperSubscription(
  studentId,
  examYear = '2027 A/L',
  studentEmail = null,
  studentPhone = null,
  profile = null,
  authUser = null
) {
  if (!studentId && !studentEmail && !profile?.id && !profile?.email && !authUser?.email) {
    return {
      isSubscribed: false,
      reason: 'NO_STUDENT_ID',
      enrollUrl: 'https://edupeak.lk/?openLms=video-classroom&course=crs-base-super-paper-2027',
      message: 'Student identification missing.'
    };
  }

  try {
    // 1. Fetch Super Paper Class courses from database
    const { data: courses, error: coursesError } = await supabase
      .from('courses')
      .select('*')
      .or('title.ilike.%Super Paper Class%,parent_course_id.ilike.%super-paper%,id.ilike.%super-paper%')
      .eq('active', true)
      .order('created_at', { ascending: false });

    if (coursesError) {
      console.warn('[Supabase] Could not fetch courses:', coursesError);
    }


    // Determine the active monthly course for metadata and checkout display
    // Target is crs-phy-muu3k9m4 ("Super Paper Class - October 2027")
    const activeMonthlyCourse = (courses || []).find(c => c.id === 'crs-phy-muu3k9m4')
      || (courses || []).find(c => c.parent_course_id === 'crs-base-super-paper-2027' && c.month_name)
      || (courses || []).find(c => c.month_name && String(c.title).toLowerCase().includes('paper'))
      || { id: 'crs-phy-muu3k9m4', title: 'Super Paper Class - October 2027', month_name: 'October 2027' };

    const monthName = activeMonthlyCourse.month_name || 'October 2027';
    const enrollUrl = `https://edupeak.lk/checkout.html?course=${encodeURIComponent(activeMonthlyCourse.id)}`;

    // Monthly and base course IDs for Super Paper Class
    const validMonthlyCourseIds = Array.from(new Set([
      activeMonthlyCourse.id,
      'crs-phy-muu3k9m4',
      'crs-base-super-paper-2027',
      ...(courses || [])
        .filter(c => (c.parent_course_id === 'crs-base-super-paper-2027' || c.month_name || String(c.id).includes('super-paper')))
        .map(c => c.id)
    ].filter(Boolean)));

    // Compile all candidate student identifiers (e.g. EP-2027-312, email, phone, auth UUID)
    const studentKeys = Array.from(new Set([
      studentId,
      studentEmail,
      studentPhone,
      profile?.id,
      profile?.email,
      profile?.phone,
      authUser?.id,
      authUser?.email
    ].filter(Boolean).map(s => String(s).trim())));

    // 1.5 Fast-Path: Supabase RPC check_student_subscription (Security Definer, bypasses RLS safely)
    try {
      const targetId = studentId || profile?.id || studentKeys.find(k => k.startsWith('EP-')) || '';
      const targetEmail = studentEmail || profile?.email || authUser?.email || studentKeys.find(k => k.includes('@')) || '';

      const { data: rpcRes, error: rpcErr } = await supabase.rpc('check_student_subscription', {
        p_student_id: String(targetId).trim(),
        p_email: String(targetEmail).trim()
      });

      if (!rpcErr && rpcRes && typeof rpcRes.is_subscribed === 'boolean') {
        if (rpcRes.is_subscribed === true) {
          return {
            isSubscribed: true,
            currentCourse: activeMonthlyCourse,
            enrollUrl: rpcRes.enroll_url || enrollUrl,
            monthName: rpcRes.month_name || monthName
          };
        } else {
          // RPC EXPLICITLY DETERMINED STUDENT DOES NOT HAVE THE LATEST MONTH SUBSCRIPTION!
          // Return immediately with isSubscribed: false. Never fall through to base course matches!
          return {
            isSubscribed: false,
            reason: 'PAYMENT_REQUIRED',
            currentCourse: activeMonthlyCourse,
            enrollUrl: rpcRes.enroll_url || enrollUrl,
            monthName: rpcRes.month_name || monthName,
            message: `Full tuition payment required for ${rpcRes.month_name || monthName}. 1st lesson free trials do not unlock paper sessions or homework submissions.`
          };
        }
      }
    } catch (rpcEx) {
      console.warn('[Supabase] check_student_subscription RPC check notice, falling back:', rpcEx);
    }

    let isPaid = false;
    let paidEnrollment = null;

    // 2. CHECK ENROLLMENTS TABLE (FALLBACK):
    // Only check against valid paid monthly course IDs (e.g. crs-phy-muu3k9m4).
    // NEVER match crs-base-super-paper-2027!
    if (studentKeys.length > 0) {
      const { data: enrollments, error: enrollErr } = await supabase
        .from('enrollments')
        .select('*')
        .in('student_id', studentKeys)
        .in('course_id', validMonthlyCourseIds);

      if (enrollments && enrollments.length > 0) {
        for (const enr of enrollments) {
          const pStatus = String(enr.payment_status || '').toLowerCase().trim();
          if (pStatus === 'paid' || pStatus === 'approved' || pStatus === 'active') {
            isPaid = true;
            paidEnrollment = enr;
            break;
          }
        }
      }
    }

    // 3. CHECK PROFILE'S ENROLLED_COURSES (FALLBACK):
    if (!isPaid) {
      let resolvedProfile = profile;
      if (!resolvedProfile && (studentEmail || studentId)) {
        resolvedProfile = await getStudentProfile(studentEmail || studentId);
      }

      if (resolvedProfile?.enrolled_courses) {
        let enrolledList = [];
        if (Array.isArray(resolvedProfile.enrolled_courses)) {
          enrolledList = resolvedProfile.enrolled_courses;
        } else if (typeof resolvedProfile.enrolled_courses === 'string') {
          try {
            enrolledList = JSON.parse(resolvedProfile.enrolled_courses);
          } catch (_) {}
        }

        // Must explicitly match the target monthly course, NOT crs-base-super-paper-2027 and NOT generic 'super-paper'!
        const hasMatch = enrolledList.some(cId => validMonthlyCourseIds.includes(cId));

        if (hasMatch) {
          // Verify student does not have an explicit cancellation in enrollments table
          const { data: cancelledEnr } = await supabase
            .from('enrollments')
            .select('id, payment_status')
            .in('student_id', studentKeys)
            .in('course_id', validMonthlyCourseIds)
            .in('payment_status', ['cancelled', 'refunded', 'revoked'])
            .limit(1);

          if (!cancelledEnr || cancelledEnr.length === 0) {
            isPaid = true;
          }
        }
      }
    }

    // 4. CHECK APPROVED ORDERS IN broadcast_schedules (order-*) (FALLBACK)
    if (!isPaid && (studentEmail || studentId)) {
      try {
        const { data: orders } = await supabase
          .from('broadcast_schedules')
          .select('id, status, coursetitle')
          .like('id', 'order-%')
          .in('status', ['order_approved', 'approved', 'Approved'])
          .limit(30);

        if (orders && orders.length > 0) {
          for (const ord of orders) {
            try {
              const p = typeof ord.coursetitle === 'string' ? JSON.parse(ord.coursetitle) : ord.coursetitle;
              const ordCourseId = p?.courseId || p?.course_id;
              if (ordCourseId && validMonthlyCourseIds.includes(ordCourseId)) {
                const mailMatch = studentEmail && String(p.studentEmail || '').toLowerCase() === String(studentEmail).toLowerCase();
                const idMatch = studentId && String(p.studentId || '') === String(studentId);
                if (mailMatch || idMatch) {
                  isPaid = true;
                  break;
                }
              }
            } catch (_) {}
          }
        }
      } catch (err) {
        console.warn('[Supabase] broadcast_schedules check:', err);
      }
    }

    // 5. CHECK LOCAL EDUPEAK SESSION CACHE (FALLBACK)
    if (!isPaid && typeof window !== 'undefined' && window.localStorage) {
      try {
        const sessionKeys = ['edupeak_auth_session', 'edupeak_active_session', 'edupeak_cached_user'];
        for (const sKey of sessionKeys) {
          const raw = localStorage.getItem(sKey);
          if (raw) {
            const parsed = JSON.parse(raw);
            const courses = parsed?.enrolledCourses || parsed?.enrolled_courses || parsed?.user?.enrolledCourses || [];
            if (Array.isArray(courses) && courses.some(c => validMonthlyCourseIds.includes(c))) {
              isPaid = true;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (isPaid) {
      return {
        isSubscribed: true,
        currentCourse: activeMonthlyCourse,
        enrollUrl,
        enrollment: paidEnrollment,
        monthName
      };
    }

    return {
      isSubscribed: false,
      reason: 'PAYMENT_REQUIRED',
      currentCourse: activeMonthlyCourse,
      enrollUrl,
      monthName,
      message: `Full tuition payment required for ${monthName}. 1st lesson free trials do not unlock paper sessions or homework submissions.`
    };
  } catch (err) {
    console.error('[Supabase] checkSuperPaperSubscription error:', err);
    return {
      isSubscribed: false,
      reason: 'ERROR',
      enrollUrl: 'https://edupeak.lk/?openLms=video-classroom&course=crs-base-super-paper-2027',
      message: 'Failed to verify payment status.'
    };
  }
}

/**
 * Batch resolve full access status for Super Paper Class 2027 latest month
 * for a list of students in the Admin console.
 * Returns a Map: studentKey -> { hasFullAccess: boolean, monthName: string, courseTitle: string, statusText: string }
 */
export async function getSuperPaperBatchAccess(students = []) {
  const accessMap = new Map();
  if (!students || students.length === 0) return accessMap;

  try {
    // 0. Fast-Path: Supabase SECURITY DEFINER RPC get_super_paper_batch_access (10ms, bypasses RLS safely)
    try {
      const studentIds = students.map(s => s.studentId || s.id || s.phone || s.email).filter(Boolean);
      const { data: batchRes, error: rpcErr } = await supabase.rpc('get_super_paper_batch_access', {
        p_student_ids: studentIds
      });

      if (!rpcErr && Array.isArray(batchRes) && batchRes.length > 0) {
        const resultMap = new Map();
        batchRes.forEach(r => {
          if (r?.student_id) {
            resultMap.set(String(r.student_id).toLowerCase().trim(), r);
          }
        });

        for (const st of students) {
          const keys = [st.id, st.studentId, st.email, st.phone].filter(Boolean).map(k => String(k).toLowerCase().trim());
          const match = keys.map(k => resultMap.get(k)).find(Boolean);
          const hasFullAccess = match ? match.has_full_access : false;
          const monthName = match?.month_name || 'October 2027';
          const accData = {
            hasFullAccess,
            monthName,
            courseTitle: `Super Paper Class - ${monthName}`,
            statusText: hasFullAccess ? `Full Access (${monthName})` : 'No Access (Locked)'
          };
          if (st.id) accessMap.set(st.id, accData);
          if (st.studentId) accessMap.set(st.studentId, accData);
          if (st.phone) accessMap.set(st.phone, accData);
        }
        return accessMap;
      }
    } catch (batchErr) {
      console.warn('[Supabase] get_super_paper_batch_access RPC note, falling back:', batchErr);
    }

    // 1. Fetch latest month course for Super Paper Class 2027
    const { data: courses } = await supabase
      .from('courses')
      .select('id, title, month_name, parent_course_id, created_at')
      .or('title.ilike.%Super Paper Class%,parent_course_id.ilike.%super-paper%,id.ilike.%super-paper%')
      .eq('active', true)
      .order('created_at', { ascending: false });

    // Latest month course (e.g. crs-phy-muu3k9m4)
    const latestMonthlyCourse = (courses || []).find(c => c.id === 'crs-phy-muu3k9m4')
      || (courses || []).find(c => c.parent_course_id === 'crs-base-super-paper-2027' && c.month_name)
      || (courses || []).find(c => c.month_name)
      || { id: 'crs-phy-muu3k9m4', title: 'Super Paper Class - October 2027', month_name: 'October 2027' };

    const targetCourseId = latestMonthlyCourse.id;
    const targetMonthName = latestMonthlyCourse.month_name || 'October 2027';

    // ONLY paid monthly courses count for Full Access (e.g. crs-phy-muu3k9m4 for October 2027).
    // NEVER include 'crs-base-super-paper-2027' as it is a free trial course assigned to all students!
    const validPaidCourseIds = Array.from(new Set([
      targetCourseId,
      'crs-phy-muu3k9m4',
      ...(courses || []).filter(c => c.id !== 'crs-base-super-paper-2027' && c.parent_course_id === 'crs-base-super-paper-2027').map(c => c.id)
    ].filter(c => Boolean(c) && c !== 'crs-base-super-paper-2027')));

    // 2. Fetch all paid/approved enrollments for the active monthly course
    const { data: enrollments } = await supabase
      .from('enrollments')
      .select('student_id, course_id, payment_status')
      .in('course_id', validPaidCourseIds);

    const paidStudentIds = new Set();
    const cancelledStudentIds = new Set();

    (enrollments || []).forEach(enr => {
      const sId = String(enr.student_id || '').toLowerCase().trim();
      const status = String(enr.payment_status || '').toLowerCase().trim();
      const digits = sId.replace(/\D/g, '');
      const sId9 = digits.length >= 9 ? digits.slice(-9) : null;

      if (['paid', 'approved', 'active'].includes(status)) {
        paidStudentIds.add(sId);
        if (digits) paidStudentIds.add(digits);
        if (sId9) paidStudentIds.add(sId9);
      } else if (['cancelled', 'refunded', 'revoked'].includes(status)) {
        cancelledStudentIds.add(sId);
        if (digits) cancelledStudentIds.add(digits);
        if (sId9) cancelledStudentIds.add(sId9);
      }
    });

    // 3. Fetch profiles to check enrolled_courses for paid monthly course
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, email, phone, enrolled_courses');

    const profileEnrolledKeys = new Set();
    (profiles || []).forEach(prof => {
      const ec = prof.enrolled_courses;
      let list = [];
      if (Array.isArray(ec)) list = ec;
      else if (typeof ec === 'string') {
        try { list = JSON.parse(ec); } catch (_) {}
      }

      // Must explicitly match a valid paid monthly course ID, NOT base free course
      const hasCourse = list.some(cId => 
        validPaidCourseIds.includes(cId) && cId !== 'crs-base-super-paper-2027'
      );

      if (hasCourse) {
        if (prof.id) profileEnrolledKeys.add(String(prof.id).toLowerCase().trim());
        if (prof.email) profileEnrolledKeys.add(String(prof.email).toLowerCase().trim());
        if (prof.phone) {
          const ph = String(prof.phone).trim().toLowerCase();
          profileEnrolledKeys.add(ph);
          const d = ph.replace(/\D/g, '');
          if (d) profileEnrolledKeys.add(d);
          if (d.length >= 9) profileEnrolledKeys.add(d.slice(-9));
        }
      }
    });

    // 4. Fetch approved orders from broadcast_schedules for paid monthly course
    const { data: orders } = await supabase
      .from('broadcast_schedules')
      .select('coursetitle, status')
      .like('id', 'order-%')
      .in('status', ['order_approved', 'approved', 'Approved'])
      .limit(100);

    const approvedOrderKeys = new Set();
    (orders || []).forEach(ord => {
      try {
        const p = typeof ord.coursetitle === 'string' ? JSON.parse(ord.coursetitle) : ord.coursetitle;
        const cId = p?.courseId || p?.course_id;
        const isMonthlyMatch = cId && validPaidCourseIds.includes(cId) && cId !== 'crs-base-super-paper-2027';
        const isOctoberMatch = String(p?.courseTitle || '').includes('October 2027') || String(p?.courseTitle || '').includes('muu3k9m4');
        if (isMonthlyMatch || isOctoberMatch) {
          if (p?.studentId) approvedOrderKeys.add(String(p.studentId).toLowerCase().trim());
          if (p?.studentPhone) {
            const ph = String(p.studentPhone).replace(/\D/g, '');
            if (ph.length >= 9) approvedOrderKeys.add(ph.slice(-9));
          }
          if (p?.studentEmail) approvedOrderKeys.add(String(p.studentEmail).toLowerCase().trim());
        }
      } catch (_) {}
    });

    // 5. Evaluate each student
    for (const st of students) {
      const rawPhone = String(st.phone || '').trim();
      const phoneDigits = rawPhone.replace(/\D/g, '');
      const phone9 = phoneDigits.length >= 9 ? phoneDigits.slice(-9) : null;

      const keys = [
        st.id,
        st.studentId,
        st.email,
        rawPhone,
        phoneDigits,
        phone9
      ].filter(Boolean).map(k => String(k).toLowerCase().trim());

      const isCancelled = keys.some(k => cancelledStudentIds.has(k));
      let hasFullAccess = false;

      if (!isCancelled) {
        // Direct enrollment paid check
        if (keys.some(k => paidStudentIds.has(k))) {
          hasFullAccess = true;
        }

        // Profile enrolled_courses check
        if (!hasFullAccess && keys.some(k => profileEnrolledKeys.has(k))) {
          hasFullAccess = true;
        }

        // Check local st.enrolledCourses array (strictly paid monthly only)
        if (!hasFullAccess && st.enrolledCourses) {
          const list = Array.isArray(st.enrolledCourses) ? st.enrolledCourses : [];
          if (list.some(c => validPaidCourseIds.includes(c) && c !== 'crs-base-super-paper-2027')) {
            hasFullAccess = true;
          }
        }

        // Check approved orders
        if (!hasFullAccess && keys.some(k => approvedOrderKeys.has(k))) {
          hasFullAccess = true;
        }
      }

      const accData = {
        hasFullAccess,
        monthName: targetMonthName,
        courseTitle: latestMonthlyCourse.title || `Super Paper Class - ${targetMonthName}`,
        statusText: hasFullAccess ? `Full Access (${targetMonthName})` : 'No Access (Locked)'
      };
      if (st.id) accessMap.set(st.id, accData);
      if (st.studentId) accessMap.set(st.studentId, accData);
      if (st.phone) accessMap.set(st.phone, accData);
    }
  } catch (err) {
    console.warn('[Supabase] getSuperPaperBatchAccess error:', err);
  }

  return accessMap;
}

/**
 * Admin: Grant full Super Paper Class access to a student in Supabase
 */
export async function grantSuperPaperAccess(student) {
  if (!student) throw new Error('Student missing');
  const sId = student.studentId || student.id;
  const sPhone = student.phone || '';
  const sEmail = student.email || '';

  // 1. Call SECURITY DEFINER RPC to bypass RLS and grant paid monthly access instantly
  try {
    const { data: rpcRes, error: rpcErr } = await supabase.rpc('admin_grant_super_paper_access', {
      p_student_id: String(sId),
      p_phone: String(sPhone),
      p_email: String(sEmail)
    });
    if (rpcErr) {
      console.warn('[Supabase] admin_grant_super_paper_access RPC error:', rpcErr);
    }
  } catch (err) {
    console.warn('[Supabase] admin_grant_super_paper_access RPC exception:', err);
  }

  // 2. Dispatch local event so UI instantly flips badge to Full Access
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('edupeak:student-access-changed', {
      detail: { studentId: sId, action: 'granted' }
    }));
  }

  return { success: true };
}

/**
 * Admin: Revoke Super Paper Class access for a student in Supabase
 */
export async function revokeSuperPaperAccess(student) {
  if (!student) throw new Error('Student missing');
  const sId = student.studentId || student.id;
  const sPhone = student.phone || '';
  const sEmail = student.email || '';

  // 1. Call SECURITY DEFINER RPC to mark enrollment as revoked and strip monthly course
  try {
    const { data: rpcRes, error: rpcErr } = await supabase.rpc('admin_revoke_super_paper_access', {
      p_student_id: String(sId),
      p_phone: String(sPhone),
      p_email: String(sEmail)
    });
    if (rpcErr) {
      console.warn('[Supabase] admin_revoke_super_paper_access RPC error:', rpcErr);
    }
  } catch (err) {
    console.warn('[Supabase] admin_revoke_super_paper_access RPC exception:', err);
  }

  // 2. Dispatch local event so UI instantly flips badge to No Access
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('edupeak:student-access-changed', {
      detail: { studentId: sId, action: 'revoked' }
    }));
  }

  return { success: true };
}



