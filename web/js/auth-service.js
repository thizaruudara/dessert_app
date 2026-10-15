// EduPeak Authentication Service powered by Supabase Cloud
// Single Sign-On (SSO) with edupeak.lk and Monthly Course Subscription Verification

import { supabase, getStudentProfile, checkSuperPaperSubscription } from './supabase-client.js';

export class AuthService {
  constructor() {
    const isExplicitlyLoggedOut = localStorage.getItem('edupeak_is_logged_out') === 'true';
    let initialUser = null;

    if (!isExplicitlyLoggedOut) {
      try {
        const stored = localStorage.getItem('edupeak_cached_user');
        if (stored) {
          initialUser = JSON.parse(stored);
        }
      } catch (_) {}
    }

    this.currentUser = initialUser;
    this.listeners = [];
    this.loading = !initialUser;

    this.initialAuthReady = new Promise((resolve) => {
      this.resolveInitialAuth = resolve;
    });

    // Fast-path: if cached user is already present, unlock UI immediately without waiting for network
    if (this.currentUser) {
      setTimeout(() => {
        if (this.resolveInitialAuth) {
          this.resolveInitialAuth();
          this.resolveInitialAuth = null;
        }
      }, 0);
    } else {
      // Safety fallback: if no cached user, never block longer than 2000ms
      setTimeout(() => {
        if (this.resolveInitialAuth) {
          console.warn('[Auth] Safety timeout reached for initialAuthReady. Unblocking...');
          this.loading = false;
          this.resolveInitialAuth();
          this.resolveInitialAuth = null;
        }
      }, 2000);
    }

    // Handle SSO token callback or restore existing Supabase session in background
    this.initSession();
  }

  async initSession() {
    try {
      // 1. Detect tokens from SSO hash redirect (e.g., #access_token=...&refresh_token=...)
      const hash = window.location.hash || '';
      let ssoTokens = null;

      if (hash.includes('access_token=') || hash.includes('refresh_token=')) {
        const params = new URLSearchParams(hash.replace(/^#/, ''));
        const accessToken = params.get('access_token');
        const refreshToken = params.get('refresh_token');

        if (accessToken) {
          ssoTokens = { accessToken, refreshToken };
          // Clean hash from browser address bar smoothly
          try {
            const cleanUrl = window.location.pathname + window.location.search;
            window.history.replaceState(null, document.title, cleanUrl);
          } catch (_) {}
        }
      }

      // If tokens were received from edupeak.lk SSO redirect, set session in Supabase
      if (ssoTokens) {
        console.log('[Auth] Detected EduPeak SSO tokens in URL. Establishing Supabase session...');
        const { data: sessionData, error: sessionErr } = await supabase.auth.setSession({
          access_token: ssoTokens.accessToken,
          refresh_token: ssoTokens.refreshToken || ''
        });

        if (sessionErr) {
          console.error('[Auth] Failed to set Supabase session from tokens:', sessionErr);
        } else if (sessionData?.user) {
          localStorage.removeItem('edupeak_is_logged_out');
          await this.syncProfileFromAuthUser(sessionData.user);
          return;
        }
      }

      // 2. Check for active Supabase session in storage
      const { data: { session }, error: getSessionErr } = await supabase.auth.getSession();
      if (!getSessionErr && session?.user && localStorage.getItem('edupeak_is_logged_out') !== 'true') {
        await this.syncProfileFromAuthUser(session.user);
      } else if (this.currentUser && localStorage.getItem('edupeak_is_logged_out') !== 'true') {
        // Re-verify cached user against Supabase to ensure fresh subscription and profile state
        await this.refreshSubscription();
      } else {
        if (localStorage.getItem('edupeak_is_logged_out') === 'true') {
          this.currentUser = null;
        }
      }
    } catch (err) {
      console.error('[Auth] initSession error:', err);
    } finally {
      this.loading = false;
      if (this.resolveInitialAuth) {
        this.resolveInitialAuth();
        this.resolveInitialAuth = null;
      }
      this.notify();
    }

    // 3. Listen to ongoing Supabase auth state changes
    supabase.auth.onAuthStateChange(async (event, session) => {
      console.log('[Auth] Supabase auth state change:', event);
      if (event === 'SIGNED_OUT') {
        this.currentUser = null;
        localStorage.removeItem('edupeak_cached_user');
        this.notify();
      } else if (session?.user && event === 'SIGNED_IN') {
        localStorage.removeItem('edupeak_is_logged_out');
        await this.syncProfileFromAuthUser(session.user);
      }
    });
  }

  async syncProfileFromAuthUser(authUser) {
    if (!authUser) return null;
    const email = authUser.email;

    try {
      // Fetch authoritative student profile from Supabase profiles table
      const profile = await getStudentProfile(email || authUser.id);

      if (!profile) {
        console.warn('[Auth] No profile row found in Supabase for:', email);
        // Student is registered in Supabase Auth but lacks a profile in public.profiles
        this.currentUser = {
          id: authUser.id,
          uid: authUser.id,
          name: authUser.user_metadata?.full_name || authUser.user_metadata?.name || 'EduPeak Student',
          email: authUser.email,
          phone: authUser.phone || '',
          role: authUser.app_metadata?.role || 'student',
          exam_year: '2027 A/L',
          isSubscribed: false,
          subscriptionDetails: {
            isSubscribed: false,
            message: 'Your profile has not been assigned a class yet. Please contact EduPeak support.'
          }
        };
      } else {
        // Profile found in Supabase!
        const role = profile.role || (authUser.app_metadata?.role) || 'student';
        
        let subscription = { isSubscribed: true };
        if (role === 'student') {
          // Check monthly course subscription for Super Paper Class
          subscription = await checkSuperPaperSubscription(
            profile.id,
            profile.exam_year,
            profile.email,
            profile.phone,
            profile,
            authUser
          );
        }

        this.currentUser = {
          ...profile,
          uid: profile.id, // For backward compatibility with existing views
          studentId: profile.studentId || profile.student_id || profile.id,
          role,
          isSubscribed: subscription.isSubscribed,
          subscriptionDetails: subscription
        };
      }

      localStorage.setItem('edupeak_cached_user', JSON.stringify(this.currentUser));
      localStorage.removeItem('edupeak_is_logged_out');

      if (this.currentUser && (!this.currentUser.role || this.currentUser.role === 'student')) {
        this.recordDessertAppLogin(this.currentUser).catch((e) => {
          console.warn('[Auth] Background recordDessertAppLogin error:', e);
        });
      }

      this.notify();
      return this.currentUser;
    } catch (err) {
      console.error('[Auth] syncProfileFromAuthUser error:', err);
      return null;
    }
  }

  waitForInitialAuth() {
    return this.initialAuthReady;
  }

  onAuthStateChanged(callback) {
    this.listeners.push(callback);
    callback(this.currentUser);
    return () => {
      this.listeners = this.listeners.filter((listener) => listener !== callback);
    };
  }

  notify() {
    this.listeners.forEach((listener) => listener(this.currentUser));
  }

  /**
   * Redirect to edupeak.lk single sign-on page
   */
  redirectToEduPeakLogin() {
    const returnUrl = window.location.origin + window.location.pathname;
    const ssoUrl = `https://edupeak.lk/app-auth.html?redirect_uri=${encodeURIComponent(returnUrl)}`;
    window.location.href = ssoUrl;
  }

  /**
   * Log out of Supabase and clear local state
   */
  async logout() {
    localStorage.setItem('edupeak_is_logged_out', 'true');
    localStorage.removeItem('edupeak_cached_user');
    this.currentUser = null;

    try {
      await supabase.auth.signOut();
    } catch (err) {
      console.warn('[Auth] Signout warning:', err);
    }

    this.notify();
  }

  async updateProfile(updates = {}) {
    if (!this.currentUser) return null;

    // 1. Immediately apply updates to memory and local storage
    this.currentUser = { ...this.currentUser, ...updates };
    try {
      localStorage.setItem('edupeak_cached_user', JSON.stringify(this.currentUser));
    } catch (_) {}

    // 2. Persist to Firestore users collection
    try {
      const { db, doc, setDoc } = await import('./firebase-config.js');
      const uIds = Array.from(new Set([
        this.currentUser.id,
        this.currentUser.uid,
        this.currentUser.studentId,
        this.currentUser.phone
      ].filter(Boolean)));

      for (const uId of uIds) {
        try {
          await setDoc(doc(db, 'users', String(uId)), {
            ...updates,
            updatedAt: new Date()
          }, { merge: true });
        } catch (_) {}
      }
    } catch (e) {
      console.warn('[Auth] Firestore profile update note:', e);
    }

    // 3. Try syncing to Supabase profiles / logins table safely
    try {
      if (this.currentUser.id) {
        await supabase
          .from('profiles')
          .upsert({
            id: this.currentUser.id,
            ...updates,
            updated_at: new Date().toISOString()
          }, { onConflict: 'id' }).catch(() => {});
      }
    } catch (e) {
      console.warn('[Auth] Supabase profiles update note:', e);
    }

    this.notify();
    return this.currentUser;
  }

  // Refresh subscription status on demand
  async refreshSubscription() {
    if (!this.currentUser) return { isSubscribed: false };
    if (this.currentUser.role && this.currentUser.role !== 'student') {
      return { isSubscribed: true };
    }

    try {
      const identifier = this.currentUser.email || this.currentUser.id || this.currentUser.phone;
      const liveProfile = await getStudentProfile(identifier);
      const activeData = liveProfile || this.currentUser;

      const sub = await checkSuperPaperSubscription(
        activeData.id || this.currentUser.id,
        activeData.exam_year || this.currentUser.exam_year || '2027 A/L',
        activeData.email || this.currentUser.email,
        activeData.phone || this.currentUser.phone,
        activeData,
        this.currentUser
      );

      this.currentUser = {
        ...this.currentUser,
        ...(liveProfile || {}),
        isSubscribed: sub.isSubscribed,
        subscriptionDetails: sub
      };

      localStorage.setItem('edupeak_cached_user', JSON.stringify(this.currentUser));
      if (!this.currentUser.role || this.currentUser.role === 'student') {
        this.recordDessertAppLogin(this.currentUser).catch(() => {});
      }
      this.notify();
      return sub;
    } catch (err) {
      console.error('[Auth] refreshSubscription error:', err);
      return { isSubscribed: false, error: err };
    }
  }

  /**
   * Record this student's login / presence in Dessert App in Supabase
   */
  async recordDessertAppLogin(user) {
    if (!user) return;
    const role = (user.role || '').toLowerCase();
    if (role && role !== 'student') return;

    const studentId = user.studentId || user.id || user.uid;
    if (!studentId) return;

    try {
      const { error } = await supabase.rpc('record_dessert_app_login', {
        p_student_id: String(studentId),
        p_name: String(user.name || ''),
        p_phone: String(user.phone || ''),
        p_email: String(user.email || ''),
        p_exam_year: String(user.exam_year || user.examYear || '')
      });
      if (error) {
        console.warn('[Auth] record_dessert_app_login RPC warning:', error);
      } else {
        console.log('[Auth] Logged student dessert app presence:', studentId);
      }
    } catch (e) {
      console.warn('[Auth] recordDessertAppLogin invocation error:', e);
    }
  }
}

export const authService = new AuthService();
