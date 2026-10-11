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
  const clean = String(identifier).trim().toLowerCase();

  try {
    // Try matching by email first, then by student ID or phone
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .or(`email.ilike.${clean},id.eq.${clean},phone.eq.${clean}`)
      .limit(1)
      .maybeSingle();

    if (error) {
      console.warn('[Supabase] Failed to fetch student profile:', error);
      return null;
    }
    return data;
  } catch (err) {
    console.error('[Supabase] Exception in getStudentProfile:', err);
    return null;
  }
}

/**
 * Check if student has paid and unlocked the active monthly "Super Paper Class".
 * Note: Free base courses and "1st lesson free" trials do NOT unlock exam/homework access.
 * Student must have a verified paid enrollment (payment_status: 'paid'/'approved') or approved order.
 */
export async function checkSuperPaperSubscription(studentId, examYear = '2027 A/L', studentEmail = null, studentPhone = null) {
  if (!studentId && !studentEmail) {
    return {
      isSubscribed: false,
      reason: 'NO_STUDENT_ID',
      enrollUrl: 'https://edupeak.lk/courses.html',
      message: 'Student identification missing.'
    };
  }

  try {
    // 1. Fetch active Super Paper Class courses
    const { data: courses, error: coursesError } = await supabase
      .from('courses')
      .select('*')
      .or('title.ilike.%Super Paper Class%,parent_course_id.ilike.%super-paper%')
      .eq('active', true)
      .order('created_at', { ascending: false });

    if (coursesError || !courses || courses.length === 0) {
      console.warn('[Supabase] Could not fetch Super Paper Class courses:', coursesError);
      return {
        isSubscribed: false,
        reason: 'COURSES_UNAVAILABLE',
        currentCourse: null,
        enrollUrl: 'https://edupeak.lk/courses.html',
        monthName: 'Current Month',
        message: 'Could not connect to EduPeak course directory. Please verify your connection.'
      };
    }

    // Exclude free base courses (e.g. crs-base-super-paper-2027) which are free to enroll
    // Focus only on paid monthly child courses (which have parent_course_id or month_name)
    const paidMonthlyCourses = courses.filter(c => {
      const isBase = c.is_base_course === true || String(c.id).startsWith('crs-base-');
      const feeStr = String(c.fee || c.price || '').toLowerCase();
      const isFree = feeStr.includes('free') || c.fee === 0 || c.fee === '0';
      return !isBase && !isFree && (c.parent_course_id || c.month_name);
    });

    // If student has a matching batch (e.g. 2027 A/L), prioritize that batch
    const batchMatches = paidMonthlyCourses.filter(c => !examYear || c.examyear === examYear || c.level === examYear);
    const activeMonthlyCourse = batchMatches.length > 0
      ? batchMatches[0]
      : (paidMonthlyCourses[0] || courses.find(c => !c.is_base_course) || courses[0]);

    if (!activeMonthlyCourse) {
      return {
        isSubscribed: false,
        reason: 'NO_ACTIVE_COURSE',
        currentCourse: null,
        enrollUrl: 'https://edupeak.lk/courses.html',
        monthName: 'Current Month',
        message: 'No active Super Paper Class monthly course currently open.'
      };
    }

    // Direct checkout URL for the specific monthly course on edupeak.lk
    const enrollUrl = `https://edupeak.lk/checkout.html?course=${encodeURIComponent(activeMonthlyCourse.id)}`;
    const monthName = activeMonthlyCourse.month_name || activeMonthlyCourse.title;

    // 2. Check student's paid enrollment in enrollments table
    // 1st lesson free / free trials DO NOT grant access. payment_status must be 'paid' or 'approved'.
    const studentKeys = [studentId, studentEmail, studentPhone].filter(Boolean);
    let isPaid = false;
    let paidEnrollment = null;

    for (const key of studentKeys) {
      const { data: enr, error: enrollError } = await supabase
        .from('enrollments')
        .select('*')
        .eq('student_id', key)
        .eq('course_id', activeMonthlyCourse.id)
        .limit(1)
        .maybeSingle();

      if (enr) {
        const pStatus = String(enr.payment_status || '').toLowerCase().trim();
        if (pStatus === 'paid' || pStatus === 'approved') {
          isPaid = true;
          paidEnrollment = enr;
          break;
        }
      }
    }

    // 3. Fallback: Check approved orders in broadcast_schedules (order-*) if not in enrollments
    if (!isPaid && (studentEmail || studentId)) {
      try {
        const { data: orders } = await supabase
          .from('broadcast_schedules')
          .select('id, status, coursetitle')
          .like('id', 'order-%')
          .in('status', ['order_approved', 'approved', 'Approved'])
          .limit(25);

        if (orders && orders.length > 0) {
          for (const ord of orders) {
            try {
              const p = typeof ord.coursetitle === 'string' ? JSON.parse(ord.coursetitle) : ord.coursetitle;
              if (p && (p.courseId === activeMonthlyCourse.id || p.course_id === activeMonthlyCourse.id)) {
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
        console.warn('[Supabase] broadcast_schedules orders check:', err);
      }
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
      enrollUrl: 'https://edupeak.lk/courses.html',
      message: 'Failed to verify payment status.'
    };
  }
}
