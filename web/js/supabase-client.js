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
    const { data: byPhone } = await supabase
      .from('profiles')
      .select('*')
      .eq('phone', clean)
      .limit(1)
      .maybeSingle();

    if (byPhone) return byPhone;

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

    // All valid courses for Super Paper Class
    const validCourseIds = Array.from(new Set([
      targetCourseId,
      'crs-phy-muu3k9m4',
      'crs-base-super-paper-2027',
      ...(courses || []).map(c => c.id)
    ].filter(Boolean)));

    // 2. Fetch all paid/approved enrollments for any Super Paper course
    const { data: enrollments } = await supabase
      .from('enrollments')
      .select('student_id, course_id, payment_status')
      .in('course_id', validCourseIds);

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

    // 3. Fetch profiles to check enrolled_courses in Supabase
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

      const hasCourse = list.some(cId => 
        validCourseIds.includes(cId) || 
        String(cId).toLowerCase().includes('super-paper') || 
        String(cId).toLowerCase().includes('muu3k9m4')
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

    // 4. Fetch approved orders from broadcast_schedules in batch
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
        if (validCourseIds.includes(cId) || String(p?.courseTitle || '').includes('October 2027') || String(p?.courseTitle || '').toLowerCase().includes('super paper')) {
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

        // Check local st.enrolledCourses array
        if (!hasFullAccess && st.enrolledCourses) {
          const list = Array.isArray(st.enrolledCourses) ? st.enrolledCourses : [];
          if (list.some(c => validCourseIds.includes(c) || String(c).toLowerCase().includes('super-paper') || String(c).includes('muu3k9m4'))) {
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
  const targetCourseId = 'crs-phy-muu3k9m4';
  const baseCourseId = 'crs-base-super-paper-2027';

  // 1. Upsert or update enrollments table for target courses
  const { data: existingEnr } = await supabase
    .from('enrollments')
    .select('id, course_id, payment_status')
    .eq('student_id', sId)
    .in('course_id', [targetCourseId, baseCourseId]);

  const now = new Date().toISOString();
  if (existingEnr && existingEnr.length > 0) {
    for (const enr of existingEnr) {
      await supabase
        .from('enrollments')
        .update({ payment_status: 'paid', enrolled_at: now })
        .eq('id', enr.id);
    }
  } else {
    await supabase
      .from('enrollments')
      .insert([
        {
          student_id: sId,
          course_id: targetCourseId,
          payment_status: 'paid',
          enrolled_at: now,
          attendance_mode: student.attendanceMode || 'online'
        },
        {
          student_id: sId,
          course_id: baseCourseId,
          payment_status: 'paid',
          enrolled_at: now,
          attendance_mode: student.attendanceMode || 'online'
        }
      ]);
  }

  // 2. Update profiles table enrolled_courses if profile exists
  try {
    const { data: prof } = await supabase
      .from('profiles')
      .select('id, enrolled_courses')
      .or(`id.eq.${sId},phone.eq.${student.phone || ''}`)
      .limit(1)
      .maybeSingle();

    if (prof) {
      let list = Array.isArray(prof.enrolled_courses) ? prof.enrolled_courses : [];
      if (!list.includes(targetCourseId)) list.push(targetCourseId);
      if (!list.includes(baseCourseId)) list.push(baseCourseId);
      await supabase
        .from('profiles')
        .update({ enrolled_courses: list })
        .eq('id', prof.id);
    }
  } catch (err) {
    console.warn('[Supabase] grantSuperPaperAccess profile update notice:', err);
  }

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
  const targetCourseId = 'crs-phy-muu3k9m4';
  const baseCourseId = 'crs-base-super-paper-2027';

  // 1. Update enrollments to revoked
  const { data: existingEnr } = await supabase
    .from('enrollments')
    .select('id')
    .eq('student_id', sId)
    .in('course_id', [targetCourseId, baseCourseId]);

  if (existingEnr && existingEnr.length > 0) {
    for (const enr of existingEnr) {
      await supabase
        .from('enrollments')
        .update({ payment_status: 'revoked' })
        .eq('id', enr.id);
    }
  } else {
    await supabase
      .from('enrollments')
      .insert({
        student_id: sId,
        course_id: targetCourseId,
        payment_status: 'revoked',
        attendance_mode: 'online'
      });
  }

  // 2. Remove from profile enrolled_courses
  try {
    const { data: prof } = await supabase
      .from('profiles')
      .select('id, enrolled_courses')
      .or(`id.eq.${sId},phone.eq.${student.phone || ''}`)
      .limit(1)
      .maybeSingle();

    if (prof && Array.isArray(prof.enrolled_courses)) {
      const list = prof.enrolled_courses.filter(c => c !== targetCourseId && c !== baseCourseId && !String(c).includes('super-paper'));
      await supabase
        .from('profiles')
        .update({ enrolled_courses: list })
        .eq('id', prof.id);
    }
  } catch (err) {
    console.warn('[Supabase] revokeSuperPaperAccess profile update notice:', err);
  }

  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('edupeak:student-access-changed', {
      detail: { studentId: sId, action: 'revoked' }
    }));
  }

  return { success: true };
}



