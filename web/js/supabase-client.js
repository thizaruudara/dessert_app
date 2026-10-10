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
 * Check if student is actively enrolled and paid for the current month's "Super Paper Class"
 */
export async function checkSuperPaperSubscription(studentId, examYear = '2027 A/L') {
  if (!studentId) {
    return {
      isSubscribed: false,
      reason: 'NO_STUDENT_ID',
      message: 'Student ID missing.'
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
      // Fallback: If courses cannot be queried, do not lock out
      return {
        isSubscribed: true,
        currentCourse: null,
        message: 'Courses status unavailable, granting access.'
      };
    }

    // Identify monthly courses (e.g., month_name is present or title has month)
    // Filter matching student exam batch if specified
    const monthlyCourses = courses.filter(c => c.month_name || (c.parent_course_id && c.parent_course_id !== ''));
    
    // Pick the most recent active monthly course
    // If student has a matching batch, prioritize that batch
    const batchMatches = monthlyCourses.filter(c => !examYear || c.examyear === examYear);
    const activeMonthlyCourse = batchMatches.length > 0 ? batchMatches[0] : monthlyCourses[0] || courses[0];

    if (!activeMonthlyCourse) {
      return { isSubscribed: true, currentCourse: null };
    }

    // 2. Check student enrollment for this active monthly course
    const { data: enrollment, error: enrollError } = await supabase
      .from('enrollments')
      .select('*')
      .eq('student_id', studentId)
      .eq('course_id', activeMonthlyCourse.id)
      .limit(1)
      .maybeSingle();

    if (enrollError) {
      console.warn('[Supabase] Error checking enrollment:', enrollError);
    }

    const isPaid = enrollment && String(enrollment.payment_status).toLowerCase() === 'paid';

    if (isPaid) {
      return {
        isSubscribed: true,
        currentCourse: activeMonthlyCourse,
        enrollment,
        monthName: activeMonthlyCourse.month_name || activeMonthlyCourse.title
      };
    }

    return {
      isSubscribed: false,
      reason: 'UNPAID_OR_NOT_ENROLLED',
      currentCourse: activeMonthlyCourse,
      monthName: activeMonthlyCourse.month_name || activeMonthlyCourse.title,
      message: `You are not enrolled in ${activeMonthlyCourse.title || 'the current Super Paper Class'}. Please purchase this month's course on edupeak.lk.`
    };
  } catch (err) {
    console.error('[Supabase] checkSuperPaperSubscription error:', err);
    return {
      isSubscribed: false,
      reason: 'ERROR',
      message: 'Failed to verify subscription status.'
    };
  }
}
