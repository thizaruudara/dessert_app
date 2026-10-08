// EduPeak Exact 1:1 Android App Replica Controller
// Matches current_real_dashboard.png, screen_cockpit_full.png & real_dashboard_light_v4.html
import { authService } from './auth-service.js';
import { dbService } from './db-service.js';
import { notificationService } from './notification-service.js';
import { cameraService } from './camera-service.js';
import { PwaGatekeeper } from './pwa-gatekeeper.js';

class AppController {
  constructor() {
    this.currentTab = 'home';
    this.renderToken = 0;
    this.currentUser = authService.currentUser || null;
    this.countdownTimer = null;
    this.papersInterval = null;
    this.isInsideLiveExam = false;
    this.antiCheatViolations = 0;
    this.papersTab = 0; // 0: Live Sessions, 1: Upcoming Papers & Hints
    this.showAllBatches = false;
  }

  init() {
    authService.onAuthStateChanged((user) => {
      this.currentUser = user;
      const appIsUnlocked = document.getElementById('app-root') && !document.getElementById('pwa-gatekeeper-overlay');
      if (appIsUnlocked && !user && !authService.loading) {
        this.renderAuthScreen();
      } else if (user && appIsUnlocked) {
        if (user.role === 'admin') this.renderAdminApp();
        else this.renderApp();
      }
    });
    window.addEventListener('popstate', () => {
      if (this.currentUser?.role === 'admin') {
        if (this.currentMode !== 'student') return;
        const params = new URLSearchParams(window.location.search);
        if (params.get('view') !== 'student') {
          this.returnToAdminDashboard();
          return;
        }
        const requestedTab = params.get('tab');
        const allowedTabs = ['home', 'papers', 'ranks', 'desserts', 'profile'];
        this.switchTab(allowedTabs.includes(requestedTab) ? requestedTab : 'home', { historyMode: 'none' });
        return;
      }
      if (!document.getElementById('main-viewport')) return;
      const requestedTab = new URLSearchParams(window.location.search).get('tab');
      const allowedTabs = ['home', 'papers', 'ranks', 'desserts', 'profile'];
      this.switchTab(allowedTabs.includes(requestedTab) ? requestedTab : 'home', { historyMode: 'none' });
    });

    // 0. Theme Initialization
    const savedTheme = localStorage.getItem('edupeak_theme') || 'light';
    document.documentElement.setAttribute('data-theme', savedTheme);

    // Privileged mode is determined only by the protected server profile.

    // 1. Mount 1:1 Opening Loading Screen (splash_screen.dart replica)
    this.renderSplashScreen();

    // 2. Initialize PWA Gatekeeper for iOS Add to Home Screen enforcement
    const gatekeeper = new PwaGatekeeper({
      onUnlocked: async () => {
        console.log('[App] PWA Standalone Mode active.');
        await authService.waitForInitialAuth();
        if (!this.currentUser) {
          this.renderAuthScreen();
        } else if (this.currentUser?.role === 'admin') {
          this.renderAdminApp();
        } else {
          this.renderApp();
        }
      }
    });

    gatekeeper.init();

    // 3. Global Anti-Cheat Listener
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden' && this.isInsideLiveExam) {
        this.handleExamTabSwitch();
      }
    });
  }

  // ── 00. 1:1 Opening Loading Screen (Exact splash_screen.dart Replica) ──
  renderSplashScreen() {
    if (document.getElementById('app-splash-screen')) return;

    const splash = document.createElement('div');
    splash.className = 'splash-screen-overlay';
    splash.id = 'app-splash-screen';
    splash.innerHTML = `
      <div style="height: 20px;"></div>

      <!-- Center Content: Logo + Badge (100% Dead Centered) -->
      <div class="splash-center-content">
        <div class="splash-logo-wrap">
          <img src="./icons/edupeak_logo.png" alt="EduPeak" class="splash-logo-img" onerror="this.src='./icons/icon-192.png'" />
        </div>
        <div class="splash-badge-wrap">
          <div class="splash-badge">
            <div class="splash-badge-dot"></div>
            <span class="splash-badge-text">AI & Advanced Level Institute</span>
          </div>
        </div>
      </div>

      <!-- Bottom Loader (100% Dead Centered) -->
      <div class="splash-bottom-loader">
        <div class="splash-progress-track">
          <div class="splash-progress-bar"></div>
        </div>
        <div class="splash-loading-text">Connecting to Campus...</div>
      </div>
    `;

    document.body.appendChild(splash);

    // Keep the splash in place until Firebase has resolved the persisted
    // session, while preserving its minimum display time and exit animation.
    const splashStartedAt = performance.now();
    authService.waitForInitialAuth().then(() => {
      const remaining = Math.max(0, 1900 - (performance.now() - splashStartedAt));
      setTimeout(() => {
        splash.classList.add('swap-up-exit');
        setTimeout(() => splash.remove(), 550);
      }, remaining);
    });  }

  // ── 0. Dedicated Login & Register Screen (1:1 login_screen.dart replica) ──
  renderAuthScreen(initialTab = 0) {
    const root = document.getElementById('app-root');
    if (!root) return;

    this.authTab = initialTab; // 0 = Login, 1 = Register

    root.innerHTML = `
      <div class="auth-screen-container ${this.authTab === 1 ? 'is-registering' : ''}">
        <div class="auth-scroll-content">
        <div class="auth-header">
          <div class="auth-brand-logo-wrap">
            <img src="./icons/edupeak_logo.png" alt="EduPeak" class="auth-brand-logo-img" onerror="this.src='./icons/icon-192.png'" />
          </div>
          <div class="auth-title">EduPeak</div>
          <div class="auth-brand-tag" style="display:inline-flex; align-items:center; justify-content:center; gap:4px;">
            <span>A/L Pastry &amp; Dessert Institute 🍰</span>
          </div>
        </div>

        <!-- Auth Tabs (Login vs Register) -->
        <div class="auth-tabs-bar">
          <button class="auth-tab-btn ${this.authTab === 0 ? 'active' : ''}" id="tab-auth-login" style="display:inline-flex; align-items:center; justify-content:center; gap:6px;">
            <span>Sign In</span>
          </button>
          <button class="auth-tab-btn ${this.authTab === 1 ? 'active' : ''}" id="tab-auth-register" style="display:inline-flex; align-items:center; justify-content:center; gap:6px;">
            <span>Register</span>
          </button>
        </div>

        <!-- Form Card -->
        <div class="auth-form-card" id="auth-form-card">
          ${this.authTab === 0 ? `
            <!-- Login Form -->
            <form id="form-login" style="display:flex; flex-direction:column; gap:14px;">
              <div class="auth-form-heading">
                <h2>Sign In</h2>
                <p>Enter your phone number and password to access your portal</p>
              </div>
              <div class="auth-field-group">
                <label class="auth-field-label" for="input-login-phone">Phone Number</label>
                <div class="auth-phone-row">
                  <span class="auth-phone-country">
                    <svg class="auth-country-flag" viewBox="0 0 28 18" role="img" aria-label="Sri Lanka">
                      <rect x=".5" y=".5" width="27" height="17" rx="2.5" fill="#FFBE29" />
                      <rect x="2" y="3" width="4" height="12" fill="#00534E" />
                      <rect x="6.5" y="3" width="4" height="12" fill="#EB7400" />
                      <rect x="11" y="3" width="15" height="12" rx="1" fill="#8D153A" />
                      <path d="M17 6.2c1.4-.9 3.3-.4 3.5 1.1.1 1.2-1 1.4-1.7 2.1-.4.4-.3 1.1.1 1.5m-2.7-4.7-.7-.8m4.9.4.7-.7M18.7 11v1.1m-2.3-.2-.8.8m4.7-.8.8.8" fill="none" stroke="#FFBE29" stroke-width=".8" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                    <strong>+94</strong>
                  </span>
                  <div class="auth-input-wrapper auth-phone-input-wrap">
                    <span class="material-symbols-rounded auth-input-prefix">call</span>
                    <input type="tel" class="auth-input has-prefix" id="input-login-phone" placeholder="7XXXXXXXX" autocomplete="tel-national" inputmode="numeric" maxlength="10" required />
                  </div>
                </div>
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label" for="input-login-password">Password</label>
                <div class="auth-input-wrapper">
                  <span class="material-symbols-rounded auth-input-prefix">lock_outline</span>
                  <input type="password" class="auth-input has-prefix has-suffix" id="input-login-password" placeholder="Enter your password" autocomplete="current-password" required />
                  <button type="button" class="auth-pw-toggle" id="btn-toggle-login-pw">
                    <span class="material-symbols-rounded" style="font-size:18px;">visibility_off</span>
                  </button>
                </div>
              </div>

              <div id="auth-error-msg" style="display:none; background:#FEE2E2; border:1px solid #FECACA; color:#DC2626; border-radius:10px; padding:10px 12px; font-size:12px; font-weight:600;"></div>

              <button type="submit" class="auth-btn-submit" id="btn-submit-login" style="display:flex; align-items:center; justify-content:center; gap:8px;">
                <span>Sign In 🚀</span>
              </button>
            </form>
          ` : `
            <!-- Register Form -->
            <form id="form-register" style="display:flex; flex-direction:column; gap:14px;">
              <div class="auth-form-heading">
                <h2>New Student Registration</h2>
                <p>Create your password to instantly access your portal</p>
              </div>
              <div class="auth-field-group">
                <label class="auth-field-label" for="input-reg-name">Full Name</label>
                <div class="auth-input-wrapper">
                  <span class="material-symbols-rounded auth-input-prefix">person_outline</span>
                  <input type="text" class="auth-input has-prefix" id="input-reg-name" placeholder="e.g. Thisaru Udara" autocomplete="name" required />
                </div>
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label" for="input-reg-phone">Phone Number</label>
                <div class="auth-phone-row">
                  <span class="auth-phone-country">
                    <svg class="auth-country-flag" viewBox="0 0 28 18" role="img" aria-label="Sri Lanka">
                      <rect x=".5" y=".5" width="27" height="17" rx="2.5" fill="#FFBE29" />
                      <rect x="2" y="3" width="4" height="12" fill="#00534E" />
                      <rect x="6.5" y="3" width="4" height="12" fill="#EB7400" />
                      <rect x="11" y="3" width="15" height="12" rx="1" fill="#8D153A" />
                      <path d="M17 6.2c1.4-.9 3.3-.4 3.5 1.1.1 1.2-1 1.4-1.7 2.1-.4.4-.3 1.1.1 1.5m-2.7-4.7-.7-.8m4.9.4.7-.7M18.7 11v1.1m-2.3-.2-.8.8m4.7-.8.8.8" fill="none" stroke="#FFBE29" stroke-width=".8" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                    <strong>+94</strong>
                  </span>
                  <div class="auth-input-wrapper auth-phone-input-wrap">
                    <span class="material-symbols-rounded auth-input-prefix">call</span>
                    <input type="tel" class="auth-input has-prefix" id="input-reg-phone" placeholder="7XXXXXXXX" autocomplete="tel-national" inputmode="numeric" maxlength="10" required />
                  </div>
                </div>
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label" for="input-reg-batch">A/L Examination Year</label>
                <div class="auth-input-wrapper">
                  <span class="material-symbols-rounded auth-input-prefix">school</span>
                  <select class="auth-input has-prefix" id="input-reg-batch">
                  <option value="2027 A/L" selected>2027 A/L</option>
                  <option value="2028 A/L">2028 A/L</option>
                  <option value="2029 A/L">2029 A/L</option>
                  </select>
                </div>
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label" for="input-reg-password">Create Password (8+ Digits)</label>
                <div class="auth-input-wrapper">
                  <span class="material-symbols-rounded auth-input-prefix">lock_outline</span>
                  <input type="password" class="auth-input has-prefix has-suffix" id="input-reg-password" placeholder="Minimum 8 characters" minlength="8" autocomplete="new-password" required />
                  <button type="button" class="auth-pw-toggle" id="btn-toggle-reg-pw">
                    <span class="material-symbols-rounded" style="font-size:18px;">visibility_off</span>
                  </button>
                </div>
                <small class="auth-helper-text">Must be at least 8 characters long</small>
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label" for="input-reg-confirm-password">Confirm 8-Digit Password</label>
                <div class="auth-input-wrapper">
                  <span class="material-symbols-rounded auth-input-prefix">lock_outline</span>
                  <input type="password" class="auth-input has-prefix has-suffix" id="input-reg-confirm-password" placeholder="Re-enter your 8-digit password" autocomplete="new-password" required />
                  <button type="button" class="auth-pw-toggle" id="btn-toggle-reg-confirm-pw">
                    <span class="material-symbols-rounded" style="font-size:18px;">visibility_off</span>
                  </button>
                </div>
              </div>

              <div id="auth-error-msg" style="display:none; background:#FEE2E2; border:1px solid #FECACA; color:#DC2626; border-radius:10px; padding:10px 12px; font-size:12px; font-weight:600;"></div>

            </form>
          `}
        </div>
        <div class="auth-secure-note">
          <span class="material-symbols-rounded">lock_outline</span>
          <span>Secure authentication for EduPeak Students</span>
        </div>
        </div>
        ${this.authTab === 1 ? `
          <div class="auth-sticky-action">
            <button type="submit" form="form-register" class="auth-btn-submit" id="btn-submit-reg">
              <span>Create Account (Instant Sign-in) 🚀</span>
            </button>
          </div>
        ` : ''}

      </div>
    `;

    // Tab Listeners
    document.getElementById('tab-auth-login')?.addEventListener('click', () => this.renderAuthScreen(0));
    document.getElementById('tab-auth-register')?.addEventListener('click', () => this.renderAuthScreen(1));

    // Show/Hide Password toggles
    document.getElementById('btn-toggle-login-pw')?.addEventListener('click', () => {
      const inp = document.getElementById('input-login-password');
      if (inp) {
        inp.type = inp.type === 'password' ? 'text' : 'password';
        const icon = document.querySelector('#btn-toggle-login-pw .material-symbols-rounded');
        if (icon) icon.textContent = inp.type === 'password' ? 'visibility_off' : 'visibility';
      }
    });
    document.getElementById('btn-toggle-reg-pw')?.addEventListener('click', () => {
      const inp = document.getElementById('input-reg-password');
      if (inp) {
        inp.type = inp.type === 'password' ? 'text' : 'password';
        const icon = document.querySelector('#btn-toggle-reg-pw .material-symbols-rounded');
        if (icon) icon.textContent = inp.type === 'password' ? 'visibility_off' : 'visibility';
      }
    });
    document.getElementById('btn-toggle-reg-confirm-pw')?.addEventListener('click', () => {
      const inp = document.getElementById('input-reg-confirm-password');
      if (inp) {
        inp.type = inp.type === 'password' ? 'text' : 'password';
        const icon = document.querySelector('#btn-toggle-reg-confirm-pw .material-symbols-rounded');
        if (icon) icon.textContent = inp.type === 'password' ? 'visibility_off' : 'visibility';
      }
    });

    // Form Submissions
    document.getElementById('form-login')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const phone = document.getElementById('input-login-phone')?.value || '';
      const password = document.getElementById('input-login-password')?.value || '';
      const errEl = document.getElementById('auth-error-msg');
      try {
        const user = await authService.login({ phone, password });
        this.currentUser = user;
        if (user.role === 'admin') {
          this.renderAdminApp();
        } else {
          this.renderApp();
        }
      } catch (err) {
        if (errEl) {
          errEl.style.display = 'block';
          errEl.textContent = err.message || 'Invalid login credentials.';
        }
      }
    });

    document.getElementById('form-register')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const name = document.getElementById('input-reg-name')?.value || '';
      const phone = document.getElementById('input-reg-phone')?.value || '';
      const examYear = document.getElementById('input-reg-batch')?.value || '2027 A/L';
      const password = document.getElementById('input-reg-password')?.value || '';
      const confirmPassword = document.getElementById('input-reg-confirm-password')?.value || '';
      const errEl = document.getElementById('auth-error-msg');
      try {
        if (password !== confirmPassword) throw new Error('Passwords do not match.');
        const user = await authService.register({ name, phone, password, examYear });
        this.currentUser = user;
        this.renderApp();
      } catch (err) {
        if (errEl) {
          errEl.style.display = 'block';
          errEl.textContent = err.message || 'Registration failed.';
        }
      }
    });

  }

  // ── Logout In-App Confirmation Dialog (1:1 student_profile_screen.dart replica) ─
  confirmLogout() {
    const existing = document.getElementById('app-logout-dialog');
    if (existing) existing.remove();

    const overlay = document.createElement('div');
    overlay.className = 'app-dialog-overlay';
    overlay.id = 'app-logout-dialog';
    overlay.innerHTML = `
      <div class="app-dialog-box">
        <div class="app-dialog-title">Log Out</div>
        <div class="app-dialog-content">
          Are you sure you want to log out of your account?
        </div>
        <div class="app-dialog-actions">
          <button class="app-dialog-btn-cancel" id="btn-cancel-logout">Cancel</button>
          <button class="app-dialog-btn-danger" id="btn-confirm-logout">Log Out</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    overlay.querySelector('#btn-cancel-logout')?.addEventListener('click', () => {
      overlay.remove();
    });

    overlay.querySelector('#btn-confirm-logout')?.addEventListener('click', () => {
      overlay.remove();
      authService.logout();
      this.currentUser = null;
      if (this.countdownTimer) clearInterval(this.countdownTimer);
      if (this.papersInterval) clearInterval(this.papersInterval);
      this.renderAuthScreen(0);
    });
  }

  renderApp() {
    const root = document.getElementById('app-root');
    if (!root) return;

    root.innerHTML = `
      <!-- Main Scrollable Viewport -->
      <div class="main-viewport" id="main-viewport"></div>

      <!-- Bottom Navigation Bar (Matching student_shell.dart & real_dashboard_light_v4.html) -->
      <nav class="bottom-nav-bar">
        <button class="nav-tab-btn active" data-tab="home">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">home</span></div>
          <span>Home</span>
        </button>
        <button class="nav-tab-btn" data-tab="papers">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">assignment</span></div>
          <span>Papers</span>
        </button>
        <button class="nav-tab-btn" data-tab="ranks">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">emoji_events</span></div>
          <span>Ranks</span>
        </button>
        <button class="nav-tab-btn" data-tab="desserts">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">folder_special</span></div>
          <span>Desserts</span>
        </button>
        <button class="nav-tab-btn" data-tab="profile">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">person</span></div>
          <span>Profile</span>
        </button>
      </nav>
    `;

    // Nav Listeners
    document.querySelectorAll('.nav-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.switchTab(btn.dataset.tab);
      });
    });

    const requestedTab = new URLSearchParams(window.location.search).get('tab');
    const allowedTabs = ['home', 'papers', 'ranks', 'desserts', 'profile'];
    this.currentTab = null;
    this.switchTab(allowedTabs.includes(requestedTab) ? requestedTab : 'home', { historyMode: 'replace' });

    // Init notification service
    notificationService.init(this.currentUser);
  }

  switchTab(tabName, { historyMode = 'push' } = {}) {
    const allowedTabs = ['home', 'papers', 'ranks', 'desserts', 'profile'];
    if (!allowedTabs.includes(tabName)) tabName = 'home';
    const previousTab = this.currentTab;
    this.currentTab = tabName;
    const container = document.getElementById('main-viewport');
    if (!container) return;

    if (historyMode !== 'none' && (historyMode === 'replace' || previousTab !== tabName)) {
      const url = new URL(window.location.href);
      if (tabName === 'home') url.searchParams.delete('tab');
      else url.searchParams.set('tab', tabName);
      window.history[historyMode === 'replace' ? 'replaceState' : 'pushState'](
        { ...(window.history.state || {}), edupeakTab: tabName }, '', url,
      );
    }
    this.renderToken++;

    // Show a stable loading state while an async screen loads. A render token
    // below prevents a slow page request from replacing a newer tab.
    container.innerHTML = `
      <div style="display:flex; flex-direction:column; align-items:center; justify-content:center; min-height:55vh; gap:14px;">
        <div style="width:38px; height:38px; border:3px solid #DBEAFE; border-top-color:#2563EB; border-radius:50%; animation:spin 0.75s linear infinite;"></div>
        <div style="font-size:12px; font-weight:700; color:#64748B;">Loading your page…</div>
      </div>
    `;

    document.querySelectorAll('.nav-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });

    // Smooth page entrance transition matching Flutter 1:1
    container.classList.remove('tab-page-transition');
    void container.offsetWidth; // Force DOM reflow to re-trigger CSS keyframes
    container.classList.add('tab-page-transition');

    switch (tabName) {
      case 'home':
        this.renderHomeScreen(container);
        break;
      case 'papers':
        container.innerHTML = `
          <div style="display:flex; flex-direction:column; align-items:center; justify-content:center; min-height:55vh; gap:16px;">
            <div style="width:42px; height:42px; border:3.5px solid #E2E8F0; border-top-color:#6366F1; border-radius:50%; animation:spin 0.75s linear infinite;"></div>
            <div style="font-size:13.5px; font-weight:700; color:#475569;">විභාග සැසි සූදානම් කරමින්...</div>
          </div>
        `;
        this.renderPapersScreen(container).catch(err => {
          if (this.currentTab !== 'papers' || !container.isConnected) return;
          console.error('[Papers] Error rendering papers tab:', err);
          container.innerHTML = `
            <div style="padding:40px 20px; text-align:center; color:#DC2626;">
              <span class="material-symbols-rounded filled" style="font-size:42px; color:#DC2626; margin-bottom:8px;">warning</span>
              <div style="font-weight:700; font-size:15px; margin-bottom:4px;">Paper Sessions ලෝඩ් කිරීමේ දෝෂයක් සිදුවිය</div>
              <div style="font-size:12px; color:#64748B; margin-bottom:16px;">${err.message || 'Unknown error'}</div>
              <button class="btn-primary" onclick="window.app ? window.app.switchTab('papers') : location.reload()" style="width:auto; padding:8px 18px; margin:0 auto;">නැවත උත්සාහ කරන්න</button>
            </div>
          `;
        });
        break;
      case 'ranks':
        this.renderRanksScreen(container);
        break;
      case 'desserts':
        this.renderDessertsScreen(container);
        break;
      case 'profile':
        this.renderProfileScreen(container);
        break;
      default:
        this.renderHomeScreen(container);
    }

    container.scrollTo({ top: 0, behavior: 'smooth' });
  }

  // ── 1. The Exact Student Cockpit (Home) ──────────────────────────────────
  async renderHomeScreen(container) {
    const renderToken = ++this.renderToken;
    const user = this.currentUser || {};
    const studentName = user.name || 'ThiZaru';
    const initial = studentName.charAt(0).toUpperCase();

    const insight = await dbService.getDailyInsight();
    if (renderToken !== this.renderToken || !container.isConnected) return;

    container.innerHTML = `
      <!-- 1. Header (Avatar, Name, Verified Badge, 2027 Tag, 3 Days Streak) -->
      <div class="header-row">
        <div class="header-left">
          <div class="avatar-wrapper" id="btn-header-avatar">
            <div class="avatar-ring">
              <div class="avatar-img">${initial}</div>
            </div>
            <div class="avatar-badge-dot"></div>
          </div>
          <div class="header-info">
            <span class="greeting-text">Good Evening</span>
            <div class="student-name-row">
              <span class="student-name">${studentName}</span>
              <span class="material-symbols-rounded filled" style="font-size:16px; color:#2563EB;">verified</span>
            </div>
            <span class="candidate-tag">2027 A/L Candidate</span>
          </div>
        </div>
        <div class="streak-pill" style="display:inline-flex; align-items:center; gap:4px;">
          <span class="material-symbols-rounded filled" style="font-size:16px; color:#EA580C;">local_fire_department</span>
          <span>3 Days</span>
        </div>
      </div>

      <!-- 2. Hero Level Card (Level 2 Cadet, 155 / 200 XP, 3 Mission Checkboxes) -->
      <div class="hero-card">
        <div class="hero-top">
          <div class="hero-title" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded filled" style="font-size:16px; color:#F59E0B;">bolt</span>
            <span>Level 2 Cadet</span>
          </div>
          <span class="hero-pts">155 / 200 XP</span>
        </div>
        <div class="progress-bar-bg">
          <div class="progress-bar-fill"></div>
        </div>
        <div class="mission-checkboxes-row">
          <div class="mission-check-pill completed" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded filled" style="font-size:14px; color:#10B981;">check_circle</span>
            <span class="mission-check-title">Daily MCQ</span>
            <span class="mission-check-xp">+50 XP</span>
          </div>
          <div class="mission-check-pill" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded" style="font-size:14px; color:#94A3B8;">radio_button_unchecked</span>
            <span class="mission-check-title">Review Tip</span>
            <span class="mission-check-xp">+20 XP</span>
          </div>
          <div class="mission-check-pill" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded" style="font-size:14px; color:#94A3B8;">radio_button_unchecked</span>
            <span class="mission-check-title">Homework</span>
            <span class="mission-check-xp">+100 XP</span>
          </div>
        </div>
      </div>

      <!-- 3. Daily Inspiration Banner (Exact Blue Gradient) -->
      <div class="inspiration-banner">
        <div class="banner-ambient-circle"></div>
        <div class="inspiration-top">
          <div class="inspiration-badge">
            <div class="inspiration-dot"></div>
            <span class="inspiration-badge-text">DAILY INSPIRATION</span>
          </div>
          <span class="material-symbols-rounded" style="font-size:22px; color:rgba(255,255,255,0.7);">format_quote</span>
        </div>
        <div class="inspiration-quote" id="inspiration-quote-text">
          “Success is the sum of small efforts repeated day in and day out.”
        </div>
      </div>

      <!-- 4. Original 4-Digit Box Countdown (Days, Hours, Mins, Secs) -->
      <div class="cd-card">
        <div class="cd-top">
          <div class="cd-target-pill" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded" style="font-size:13px;">timer</span>
            <span>A/L TARGET</span>
          </div>
          <span class="cd-exam-name">2027 A/L Physics Final Exam</span>
          <div class="pulse-dot"></div>
        </div>
        <div class="cd-grid">
          <div class="cd-box cd-box-days">
            <span class="cd-num cd-num-days" id="cd-days">318</span>
            <span class="cd-label">DAYS</span>
          </div>
          <span class="cd-colon">:</span>
          <div class="cd-box cd-box-hours">
            <span class="cd-num cd-num-hours" id="cd-hours">12</span>
            <span class="cd-label">HOURS</span>
          </div>
          <span class="cd-colon">:</span>
          <div class="cd-box cd-box-mins">
            <span class="cd-num cd-num-mins" id="cd-mins">17</span>
            <span class="cd-label">MINS</span>
          </div>
          <span class="cd-colon">:</span>
          <div class="cd-box cd-box-secs">
            <span class="cd-num cd-num-secs" id="cd-secs">57</span>
            <span class="cd-label">SECS</span>
          </div>
        </div>
      </div>

      <!-- 5. Quick Actions (4 Columns with Colorful Squares) -->
      <div class="actions-grid">
        <div class="action-card-item action-box-mcq" id="act-daily-mcq">
          <div class="action-icon-badge icon-mcq">
            <span class="material-symbols-rounded" style="font-size:22px;">bolt</span>
          </div>
          <span class="action-card-name">Daily MCQ</span>
          <span class="action-card-sub">5 Sprints</span>
        </div>
        <div class="action-card-item action-box-tutor" id="act-ai-tutor">
          <div class="action-icon-badge icon-tutor">
            <span class="material-symbols-rounded" style="font-size:22px;">forum</span>
          </div>
          <span class="action-card-name">AI Tutor</span>
          <span class="action-card-sub">Instant</span>
        </div>
        <div class="action-card-item action-box-hw" id="act-submit-hw">
          <div class="action-icon-badge icon-hw">
            <span class="material-symbols-rounded" style="font-size:22px;">camera_alt</span>
          </div>
          <span class="action-card-name">Submit HW</span>
          <span class="action-card-sub">Earn XP</span>
        </div>
        <div class="action-card-item action-box-ranks" id="act-ranks">
          <div class="action-icon-badge icon-ranks">
            <span class="material-symbols-rounded" style="font-size:22px;">emoji_events</span>
          </div>
          <span class="action-card-name">Ranks</span>
          <span class="action-card-sub">Podium</span>
        </div>
      </div>

      <!-- 6. Daily MCQ Sprint Spotlight Card -->
      <div class="sprint-box">
        <div class="sprint-header">
          <div class="sprint-pill-tag" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded filled" style="font-size:13px;">local_fire_department</span>
            <span>TODAY'S SPRINT</span>
          </div>
          <span class="sprint-subtext">5 Quick MCQs</span>
        </div>
        <div class="sprint-topic">Dynamics & Newton's Laws</div>
        <div class="sprint-desc">
          Solve 5 questions daily to maintain your streak and earn +50 XP towards your island rank.
        </div>
        <div class="sprint-start-btn" id="btn-start-sprint-action" style="display:flex; align-items:center; justify-content:center; gap:6px;">
          <span>Start Sprint (+50 XP)</span>
          <span class="material-symbols-rounded" style="font-size:18px;">arrow_forward</span>
        </div>
      </div>

      <!-- 7. Weekly Study Quests (Gamified Challenge Hub) -->
      <div class="quests-card">
        <div class="quests-top">
          <div class="quests-title" style="display:inline-flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded" style="font-size:18px; color:#2563EB;">track_changes</span>
            <span>Weekly Study Quests</span>
          </div>
          <span class="quests-badge" style="display:inline-flex; align-items:center; gap:4px;">
            <span>2 / 3 Completed</span>
            <span class="material-symbols-rounded filled" style="font-size:13px; color:#F59E0B;">emoji_events</span>
          </span>
        </div>

        <!-- Mission 1 -->
        <div class="quest-item">
          <div class="quest-circle quest-circle-mcq">
            <span class="material-symbols-rounded" style="font-size:18px;">bolt</span>
          </div>
          <div class="quest-info">
            <div class="quest-name">Complete 5 Daily MCQs</div>
            <div class="quest-sub">3 of 5 sprints solved (60%)</div>
            <div class="quest-bar">
              <div class="quest-bar-fill" style="width: 60%; background: #EA580C;"></div>
            </div>
          </div>
          <span class="quest-status-badge quest-badge-orange">+50 XP</span>
        </div>

        <!-- Mission 2 -->
        <div class="quest-item">
          <div class="quest-circle quest-circle-hw">
            <span class="material-symbols-rounded" style="font-size:18px;">description</span>
          </div>
          <div class="quest-info">
            <div class="quest-name">Submit Weekly Homework</div>
            <div class="quest-sub">1 submission in review</div>
            <div class="quest-bar">
              <div class="quest-bar-fill" style="width: 100%; background: #2563EB;"></div>
            </div>
          </div>
          <span class="quest-status-badge quest-badge-blue" style="display:inline-flex; align-items:center; gap:3px;">
            <span>In Review</span>
            <span class="material-symbols-rounded" style="font-size:13px;">schedule</span>
          </span>
        </div>

        <!-- Mission 3 -->
        <div class="quest-item">
          <div class="quest-circle quest-circle-streak">
            <span class="material-symbols-rounded filled" style="font-size:18px;">local_fire_department</span>
          </div>
          <div class="quest-info">
            <div class="quest-name">Keep 3-Day Study Streak</div>
            <div class="quest-sub">Streak goal achieved!</div>
            <div class="quest-bar">
              <div class="quest-bar-fill" style="width: 100%; background: #059669;"></div>
            </div>
          </div>
          <span class="quest-status-badge quest-badge-green" style="display:inline-flex; align-items:center; gap:3px;">
            <span>Claimed!</span>
            <span class="material-symbols-rounded filled" style="font-size:12px;">star</span>
          </span>
        </div>

        <div class="quests-footer-note" style="display:flex; align-items:center; gap:4px;">
          <span class="material-symbols-rounded filled" style="font-size:15px; color:#F59E0B;">star</span>
          <span>Complete all 3 missions to unlock +100 Bonus XP on Sunday!</span>
        </div>
      </div>

      <!-- 8. Upcoming Live Exam Room & Paper Session Showcase -->
      <div class="evaluation-card">
        <div class="evaluation-top">
          <div class="evaluation-badge">
            <div class="eval-dot"></div>
            <span class="eval-badge-text">UPCOMING EVALUATION</span>
          </div>
          <span class="evaluation-proctor-label" style="display:inline-flex; align-items:center; gap:4px;">
            <span>Live Proctoring</span>
            <span class="material-symbols-rounded filled" style="font-size:14px;">videocam</span>
          </span>
        </div>
        <div class="evaluation-title">2027 A/L Physics Term Paper 01</div>
        <div class="evaluation-sub">Full Examination Syllabus • Real-time AI Proctoring & Timed Slots</div>
        <div class="evaluation-pills-row">
          <div class="eval-pill" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded" style="font-size:14px;">timer</span>
            <span>2h 30m Duration</span>
          </div>
          <div class="eval-pill" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded" style="font-size:14px;">assignment</span>
            <span>MCQ + Essays</span>
          </div>
          <div class="eval-pill" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded" style="font-size:14px;">emoji_events</span>
            <span>Island Rank</span>
          </div>
        </div>
        <button class="btn-view-exam-room" id="btn-enter-eval-room" style="display:flex; align-items:center; justify-content:center; gap:6px;">
          <span>View Exam Room & Select Slot</span>
          <span class="material-symbols-rounded" style="font-size:16px;">arrow_forward</span>
        </button>
      </div>

      <!-- 9. High-Yield Physics Concept & Formula Vault (Bilingual) -->
      <div class="insight-vault-card">
        <div class="vault-top">
          <div class="vault-pill" style="display:inline-flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded" style="font-size:14px;">science</span>
            <span>PHYSICS MICRO-INSIGHT</span>
          </div>
          <div style="display:flex; align-items:center; gap:6px;">
            <span class="vault-tag-pill">අද දවසේ සූත්‍රය • Daily</span>
            <button class="btn-vault-refresh" id="btn-shuffle-insight" title="Shuffle">
              <span class="material-symbols-rounded" style="font-size:16px;">refresh</span>
            </button>
          </div>
        </div>
        <div class="vault-topic-meta" id="home-vault-meta">${insight.unitSinhala || 'යාන්ත්‍ර විද්‍යාව'} • ${insight.unitEnglish || 'Mechanics'}</div>
        <div class="vault-concept-name" id="home-vault-name">
          ${insight.titleSinhala || 'කාර්යය-ශක්ති ප්‍රමේයය'} <span style="font-size: 12.5px; font-weight:600; color:#64748B;" id="home-vault-en">(${insight.titleEnglish || 'Work-Energy Theorem & Friction Losses'})</span>
        </div>
        <div class="vault-formula-box" id="home-vault-formula">
          ${insight.formula || 'W_net  =  ΔK  =  ½ m v²  -  ½ m u²'}
        </div>
        <div class="vault-exam-tip-box">
          <div class="tip-header" style="display:flex; align-items:center; gap:4px;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#F59E0B;">lightbulb</span>
            <span>විභාග උපදෙස (Exam Tip):</span>
          </div>
          <div class="tip-sinhala" id="home-vault-tip-si">
            ${insight.tipSinhala || 'ආනත තලයක චලිතයේදී ඝර්ෂණයට එරෙහි කාර්යය (W_f = -f · s) යාන්ත්‍රික ශක්ති සමීකරණයට පෙර වෙන්ව සලකා බලන්න.'}
          </div>
          <div class="tip-english" id="home-vault-tip-en">
            En: ${insight.tipEnglish || 'Always compute work done against friction W_f = -f · s separately before equating mechanical energy at the base of an incline.'}
          </div>
        </div>
        <div class="btn-ask-ai-tutor" id="btn-ask-tutor-insight" style="display:flex; align-items:center; justify-content:center; gap:6px;">
          <span class="material-symbols-rounded" style="font-size:16px;">chat</span>
          <span>මේ ගැන AI Tutor ගෙන් අසන්න (Ask AI Tutor)</span>
        </div>
      </div>

      <!-- 10. AI Tutor Quick Inquiries List -->
      <div class="ai-inquiries-card">
        <div class="inquiries-top-title" style="display:inline-flex; align-items:center; gap:6px;">
          <span class="material-symbols-rounded" style="font-size:18px; color:#2563EB;">psychology</span>
          <span>AI Tutor Quick Inquiries</span>
        </div>
        <div class="inquiries-desc">
          ඔබට අපැහැදිලි ඕනෑම A/L භෞතික විද්‍යා සංකල්පයක් පිළිබඳව AI Tutor ගෙන් ක්ෂණික පැහැදිලි කිරීමක් ලබාගන්න:
        </div>
        <div class="inquiry-item-btn" data-topic="Lenz's Law">
          <span class="inquiry-text" style="display:inline-flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#F59E0B;">bolt</span>
            <span>ලෙන්ස්ගේ නියමය සහ ප්‍රේරණය (Lenz's Law)</span>
          </span>
          <span class="material-symbols-rounded" style="font-size:16px; color:#64748B;">arrow_forward</span>
        </div>
        <div class="inquiry-item-btn" data-topic="Banking of Roads">
          <span class="inquiry-text" style="display:inline-flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#2563EB;">track_changes</span>
            <span>වක්‍ර මාර්ගවල බැංකු නැංවීම (Banking of Roads)</span>
          </span>
          <span class="material-symbols-rounded" style="font-size:16px; color:#64748B;">arrow_forward</span>
        </div>
        <div class="inquiry-item-btn" data-topic="Doppler Shifts">
          <span class="inquiry-text" style="display:inline-flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#EAB308;">lightbulb</span>
            <span>ඩොප්ලර් ආචරණය (Doppler Frequency Shifts)</span>
          </span>
          <span class="material-symbols-rounded" style="font-size:16px; color:#64748B;">arrow_forward</span>
        </div>
        <div class="inquiry-item-btn" data-topic="Photoelectric Effect">
          <span class="inquiry-text" style="display:inline-flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#6366F1;">science</span>
            <span>ප්‍රකාශ විද්‍යුත් ආචරණය (Photoelectric Effect)</span>
          </span>
          <span class="material-symbols-rounded" style="font-size:16px; color:#64748B;">arrow_forward</span>
        </div>
      </div>
    `;

    // Start Live Clock Countdown & Quote Rotator
    this.startCountdownTimer();
    this.startInspirationRotator();

    // Shuffle Insight Handler across 10 official presets
    let shuffleIdx = 0;
    const presets = dbService.getPresetPhysicsInsights();
    document.getElementById('btn-shuffle-insight')?.addEventListener('click', () => {
      shuffleIdx = (shuffleIdx + 1) % presets.length;
      const p = presets[shuffleIdx];
      const meta = document.getElementById('home-vault-meta');
      if (meta) meta.innerText = `${p.unitSinhala} • ${p.unitEnglish}`;
      const name = document.getElementById('home-vault-name');
      if (name) name.innerHTML = `${p.titleSinhala} <span style="font-size:12.5px; font-weight:600; color:#64748B;">(${p.titleEnglish})</span>`;
      const form = document.getElementById('home-vault-formula');
      if (form) form.innerText = p.formula;
      const tipSi = document.getElementById('home-vault-tip-si');
      if (tipSi) tipSi.innerText = p.tipSinhala;
      const tipEn = document.getElementById('home-vault-tip-en');
      if (tipEn) tipEn.innerText = `En: ${p.tipEnglish}`;
      notificationService.showInAppToast('Shuffled Concept: ' + p.titleEnglish, 'info');
    });

    // Event Listeners
    document.getElementById('act-daily-mcq')?.addEventListener('click', () => this.switchTab('home'));
    document.getElementById('btn-start-sprint-action')?.addEventListener('click', () => this.openSprintDialog());
    document.getElementById('act-ai-tutor')?.addEventListener('click', () => this.openAiTutorDialog());
    document.getElementById('btn-ask-tutor-insight')?.addEventListener('click', () => this.openAiTutorDialog(insight.titleEnglish || 'Work-Energy Theorem'));
    document.getElementById('act-submit-hw')?.addEventListener('click', () => this.openSubmitGuideModal());
    document.getElementById('act-ranks')?.addEventListener('click', () => this.switchTab('ranks'));
    document.getElementById('btn-enter-eval-room')?.addEventListener('click', () => this.switchTab('papers'));
    document.getElementById('btn-header-avatar')?.addEventListener('click', () => this.switchTab('profile'));

    container.querySelectorAll('.inquiry-item-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.openAiTutorDialog(btn.dataset.topic);
      });
    });
  }

  // ── 2. Papers Tab (Exam Sessions & Upcoming Hints - 1:1 Android Parity) ──
  async renderPapersScreen(container) {
    const renderToken = ++this.renderToken;
    if (this.papersInterval) {
      clearInterval(this.papersInterval);
      this.papersInterval = null;
    }

    try {
      const user = this.currentUser || { name: 'Scholar', phone: '', examYear: '2027 A/L' };
      const currentYear = user.examYear || '2027 A/L';
      const activeTargetYear = this.showAllBatches ? null : currentYear;

      const [sessions, upcomingList] = await Promise.all([
        dbService.getPaperSessions(activeTargetYear),
        dbService.getUpcomingPapers(activeTargetYear)
      ]);
      const studentId = user.uid || user.id || 's_default';
      const registrations = new Map(await Promise.all(sessions.map(async session => [
        session.id,
        await dbService.getStudentRegistration(session.id, studentId)
      ])));
      if (renderToken !== this.renderToken || !container.isConnected) return;

      const formatHeaderSubtitle = () => {
        if (this.showAllBatches) {
          return 'සියලු Batches • සජීවී විභාග සහ අධීක්ෂණ සැසි';
        }
        return `${currentYear} • සජීවී විභාග සහ අධීක්ෂණ සැසි`;
      };

      const safeFormatTime = (isoString, fallback = '08:30 AM') => {
        if (!isoString) return fallback;
        try {
          const d = new Date(isoString);
          if (isNaN(d.getTime())) return fallback;
          return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } catch (_) {
          return fallback;
        }
      };

      const safeFormatDate = (dateVal, fallback = 'Today') => {
        if (!dateVal) return fallback;
        try {
          const d = new Date(dateVal);
          if (isNaN(d.getTime())) return fallback;
          return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', weekday: 'short' });
        } catch (_) {
          return fallback;
        }
      };

      container.innerHTML = `
        <!-- App Bar (1:1 with paper_sessions_screen.dart lines 102-153) -->
        <div class="screen-appbar">
          <div class="appbar-left">
            <div class="appbar-icon-box" style="background:rgba(99,102,241,0.1); color:#6366F1;">
              <span class="material-symbols-rounded">assignment</span>
            </div>
            <div>
              <div class="appbar-title">Paper Writing Sessions</div>
              <div class="appbar-subtitle" id="papers-batch-subtitle">${formatHeaderSubtitle()}</div>
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:8px;">
            <button class="appbar-badge-toggle" id="btn-toggle-papers-batch" title="Toggle Batch Filter">
              <span style="display:inline-flex; align-items:center; gap:4px;">
                <span class="material-symbols-rounded" style="font-size:14px;">${this.showAllBatches ? 'public' : 'school'}</span>
                <span>${this.showAllBatches ? 'All' : 'Batch'}</span>
              </span>
            </button>
            <button class="btn-vault-refresh" id="btn-refresh-papers" title="Refresh Sessions">
              <span class="material-symbols-rounded" style="font-size:18px;">refresh</span>
            </button>
          </div>
        </div>

        <!-- View Switcher Tabs (1:1 with lines 156-185 of paper_sessions_screen.dart) -->
        <div class="sub-tabs-container" style="margin: 6px 16px 14px;">
          <button class="sub-tab-btn ${this.papersTab === 0 ? 'active' : ''}" id="tab-papers-live">
            <span style="display:inline-flex; align-items:center; justify-content:center; gap:6px;">
              <span class="material-symbols-rounded" style="font-size:16px;">assignment</span>
              <span>Live Exam Sessions</span>
            </span>
            <span class="tab-sub">Active & Scheduled</span>
          </button>
          <button class="sub-tab-btn ${this.papersTab === 1 ? 'active' : ''}" id="tab-papers-upcoming">
            <span style="display:inline-flex; align-items:center; justify-content:center; gap:6px;">
              <span class="material-symbols-rounded" style="font-size:16px;">lightbulb</span>
              <span>Upcoming Papers & Hints</span>
            </span>
            <span class="tab-sub">Scope, Tips & Hints</span>
          </button>
        </div>

        <!-- Tab 0: Live Exam Sessions View -->
        <div id="papers-tab-live-content" style="${this.papersTab === 0 ? 'display:flex; flex-direction:column; gap:16px;' : 'display:none;'}">
          ${sessions.length === 0 ? `
            <div style="padding:40px 24px; text-align:center; color:#64748B;">
              <div style="margin-bottom:12px; display:flex; justify-content:center;">
                <span class="material-symbols-rounded" style="font-size:48px; color:#94A3B8;">menu_book</span>
              </div>
              <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:6px;">නව Paper Sessions සූදානම් වෙමින් පවතී</div>
              <div style="font-size:13px; line-height:1.5;">${this.showAllBatches ? 'දැනට කිසිදු Paper Session එකක් සැලසුම් කර නොමැත.' : `ඔබගේ කණ්ඩායම (${currentYear}) සඳහා ඉදිරි විභාග සැසි මෙහි දිස්වනු ඇත.`}</div>
              <button class="btn-primary" id="btn-empty-toggle-batch" style="margin-top:16px; width:auto; padding:10px 20px; font-size:12.5px;">
                ${this.showAllBatches ? 'මගේ Batch එක පමණක් බලන්න' : 'සියලු Batches වල Sessions බලන්න'}
              </button>
            </div>
          ` : sessions.map(session => {
            const reg = registrations.get(session.id);
            const isSubmitted = reg?.status === 'submitted' || reg?.isSubmitted === true;
            const selectedSlotId = reg?.selectedSlot || 'slot1';

            const slot1 = session.slot1 || {
              id: 'slot1',
              name: 'Slot 1 (Morning / උදෑසන සැසිය)',
              startTime: new Date().toISOString(),
              endTime: new Date(Date.now() + (session.durationMinutes || 120) * 60000).toISOString(),
              registeredCount: 0,
              maxCapacity: 100
            };
            const slot2 = session.slot2 || null;
            const targetSlot = (selectedSlotId === 'slot2' && slot2) ? slot2 : slot1;

            const statusInfo = dbService.computeSessionStatus(session);
            const isEnded = statusInfo.isEnded;
            const isPackageOpening = statusInfo.isPackageOpening;
            const isWriting = statusInfo.isWriting;
            const isTimeUp = statusInfo.isTimeUp;
            const isLive = statusInfo.isLive;
            const isWaiting = statusInfo.isWaiting;

            // Calculate initial Package Opening Remaining Seconds
            let packageRemainingSecs = 600;
            if (session.packageOpeningStartedAt) {
              const elapsed = Math.floor((Date.now() - new Date(session.packageOpeningStartedAt).getTime()) / 1000);
              if (elapsed >= 0 && elapsed <= 600) {
                packageRemainingSecs = 600 - elapsed;
              }
            }

            const pkgMin = Math.floor(packageRemainingSecs / 60).toString().padStart(2, '0');
            const pkgSec = (packageRemainingSecs % 60).toString().padStart(2, '0');

            return `
              <div class="paper-session-card" id="paper-card-${session.id}" style="${isSubmitted ? 'border-color:#22C55E; box-shadow:0 6px 20px rgba(34,197,94,0.15);' : (isLive ? 'border-color:#22C55E; box-shadow:0 6px 20px rgba(34,197,94,0.12);' : '')}">
                <!-- Header Row -->
                <div class="paper-card-header">
                  <div style="display:flex; align-items:center; gap:8px;">
                    <span style="background:rgba(99,102,241,0.1); color:#6366F1; border:1px solid rgba(99,102,241,0.3); padding:3px 10px; border-radius:20px; font-size:11px; font-weight:700;">
                      ${session.subject || 'A/L Physics'}
                    </span>
                    <span style="background:#FFFFFF; color:#475569; border:1px solid #E2E8F0; padding:3px 10px; border-radius:20px; font-size:11px; font-weight:600;">
                      ${session.examYear || '2027 A/L'}
                    </span>
                  </div>
                  ${isSubmitted ? `
                    <span style="background:rgba(34,197,94,0.12); color:#15803D; border:1px solid rgba(34,197,94,0.4); padding:3px 10px; border-radius:20px; font-size:10px; font-weight:800; display:inline-flex; align-items:center; gap:4px;">
                      <span class="material-symbols-rounded filled" style="font-size:13px;">check_circle</span> <span>SUBMITTED</span>
                    </span>
                  ` : isLive ? `
                    <span style="background:rgba(34,197,94,0.12); color:#15803D; border:1px solid rgba(34,197,94,0.4); padding:3px 10px; border-radius:20px; font-size:10px; font-weight:800; display:inline-flex; align-items:center; gap:5px;">
                      <span style="width:7px; height:7px; border-radius:50%; background:#22C55E; display:inline-block;"></span>
                      <span>LIVE NOW</span>
                    </span>
                  ` : ''}
                </div>

                <!-- Title & Meta -->
                <div class="paper-title" style="margin-top:2px;">${session.title || 'Physics Examination Paper'}</div>
                <div class="paper-meta-row">
                  <div class="meta-chip">
                    <span class="material-symbols-rounded" style="font-size:14px; color:#64748B;">calendar_today</span>
                    <span>${safeFormatDate(session.date)}</span>
                  </div>
                  <div class="meta-chip">
                    <span class="material-symbols-rounded" style="font-size:14px; color:#64748B;">timer</span>
                    <span>${session.durationMinutes || 120} Minutes</span>
                  </div>
                  <div class="meta-chip">
                    <span class="material-symbols-rounded" style="font-size:14px; color:#64748B;">videocam</span>
                    <span>Camera Monitored</span>
                  </div>
                </div>

                <!-- Slot Selector (1:1 with _buildSlotCard) -->
                <div style="font-size:11.5px; font-weight:700; color:#475569; margin-top:4px;">
                  ${slot2 ? 'කරුණාකර ඔබගේ විභාග සැසිය (Slot) තෝරන්න:' : 'විභාග සැසිය (Exam Session):'}
                </div>
                <div class="slots-container">
                  <div class="slot-selection-box ${selectedSlotId === 'slot1' ? 'selected' : ''}" data-paper-id="${session.id}" data-slot-id="slot1">
                    <div class="slot-name">
                      <span style="display:inline-flex; align-items:center; gap:5px;">
                        <span class="material-symbols-rounded" style="font-size:16px; color:#F59E0B;">wb_sunny</span>
                        <span>${slot1.name || 'Slot 1 (Morning)'}</span>
                      </span>
                      <span class="material-symbols-rounded ${selectedSlotId === 'slot1' ? 'filled' : ''}" style="font-size:18px; color:#6366F1;">
                        ${selectedSlotId === 'slot1' ? 'check_circle' : 'radio_button_unchecked'}
                      </span>
                    </div>
                    <div style="font-size:11px; color:#475569; font-weight:600;">
                      ${safeFormatTime(slot1.startTime, '08:30 AM')} - ${safeFormatTime(slot1.endTime, '10:30 AM')}
                    </div>
                    <div class="slot-seats" style="display:inline-flex; align-items:center; gap:4px;">
                      <span class="material-symbols-rounded" style="font-size:13px;">chair</span>
                      <span>${slot1.registeredCount} / ${slot1.maxCapacity} Seats</span>
                    </div>
                  </div>

                  ${slot2 ? `
                    <div class="slot-selection-box ${selectedSlotId === 'slot2' ? 'selected' : ''}" data-paper-id="${session.id}" data-slot-id="slot2">
                      <div class="slot-name">
                        <span style="display:inline-flex; align-items:center; gap:5px;">
                          <span class="material-symbols-rounded" style="font-size:16px; color:#2563EB;">bedtime</span>
                          <span>${slot2.name || 'Slot 2 (Evening)'}</span>
                        </span>
                        <span class="material-symbols-rounded ${selectedSlotId === 'slot2' ? 'filled' : ''}" style="font-size:18px; color:#6366F1;">
                          ${selectedSlotId === 'slot2' ? 'check_circle' : 'radio_button_unchecked'}
                        </span>
                      </div>
                      <div style="font-size:11px; color:#475569; font-weight:600;">
                        ${safeFormatTime(slot2.startTime, '04:00 PM')} - ${safeFormatTime(slot2.endTime, '06:00 PM')}
                      </div>
                      <div class="slot-seats" style="display:inline-flex; align-items:center; gap:4px;">
                        <span class="material-symbols-rounded" style="font-size:13px;">chair</span>
                        <span>${slot2.registeredCount} / ${slot2.maxCapacity} Seats</span>
                      </div>
                    </div>
                  ` : ''}
                </div>

                <!-- Real-Time Phase Status Banner Box -->
                ${isSubmitted ? `
                  <div class="phase-status-banner-box submitted">
                    <span class="material-symbols-rounded filled" style="font-size:26px; color:#15803D;">verified</span>
                    <div>
                      <div style="font-size:12px; font-weight:800; color:#15803D;">පිළිතුරු පත්‍ර භාරදී ඇත (Answers Submitted)</div>
                      <div style="font-size:11px; color:#475569; margin-top:2px;">
                        ඔබ විසින් පිටු ${reg?.submissionPhotos?.length || 4} ක පිළිතුරු පත්‍රයක් සාර්ථකව භාරදෙන ලදී.
                      </div>
                    </div>
                  </div>
                ` : isPackageOpening ? `
                  <div class="phase-status-banner-box pkg-opening">
                    <span class="material-symbols-rounded" style="font-size:26px; color:#D97706;">inventory_2</span>
                    <div>
                      <div style="font-size:11.5px; font-weight:800; color:#B45309;">පැකේජය විවෘත කිරීමේ කාලය (Package Opening)</div>
                      <div style="font-size:12px; font-weight:800; color:#D97706; margin-top:2px;">
                        කැමරාව ඉදිරියේ පාර්සලය විවෘත කරන්න (<span class="timer-pkg-span" data-start="${session.packageOpeningStartedAt || ''}">${pkgMin}:${pkgSec}</span>)
                      </div>
                    </div>
                  </div>
                ` : (isWriting || isLive) ? `
                  <div class="phase-status-banner-box writing">
                    <span class="material-symbols-rounded filled" style="font-size:26px; color:#15803D;">sensors</span>
                    <div>
                      <div style="font-size:11.5px; font-weight:800; color:#15803D;">විභාගය ක්‍රියාත්මකයි (Exam Writing in Progress)</div>
                      <div style="font-size:12px; font-weight:800; color:#059669; margin-top:2px;">දැන් පිළිතුරු ලිවීම ආරම්භ කරන්න (Exam Live)</div>
                    </div>
                  </div>
                ` : isTimeUp ? `
                  <div class="phase-status-banner-box time-up">
                    <span class="material-symbols-rounded" style="font-size:26px; color:#DC2626;">alarm</span>
                    <div>
                      <div style="font-size:11.5px; font-weight:800; color:#DC2626;">වේලාව අවසන් (Time Up - Scan Answers)</div>
                      <div style="font-size:12px; font-weight:800; color:#B91C1C; margin-top:2px;">පිළිතුරු පත්‍ර Scan කර දැන්ම Submit කරන්න</div>
                    </div>
                  </div>
                ` : isWaiting ? `
                  <div class="phase-status-banner-box waiting">
                    <span class="material-symbols-rounded" style="font-size:26px; color:#4338CA;">meeting_room</span>
                    <div>
                      <div style="font-size:11.5px; font-weight:800; color:#4338CA;">විභාග පොරොත්තු ශාලාව විවෘතයි (Waiting Room Open)</div>
                      <div style="font-size:12px; font-weight:800; color:#6366F1; margin-top:2px;">පොරොත්තු ශාලාවට පිවිසෙන්න (Self-Check)</div>
                    </div>
                  </div>
                ` : isEnded ? `
                  <div class="phase-status-banner-box ended">
                    <span class="material-symbols-rounded" style="font-size:26px; color:#64748B;">cancel</span>
                    <div>
                      <div style="font-size:11.5px; font-weight:800; color:#64748B;">සැසිය අවසන් (Session Completed)</div>
                      <div style="font-size:12px; color:#94A3B8; margin-top:2px;">ස්තුතියි, මෙම විභාග සැසිය අවසන් කර ඇත.</div>
                    </div>
                  </div>
                ` : `
                  <div class="phase-status-banner-box waiting">
                    <span class="material-symbols-rounded" style="font-size:26px; color:#2563EB;">schedule</span>
                    <div>
                      <div style="font-size:11px; font-weight:700; color:#475569;">${targetSlot.name || 'විභාග සැසිය'} ආරම්භ වීමට:</div>
                      <div style="font-size:15px; font-weight:800; color:#2563EB; letter-spacing:1px; margin-top:2px;" class="timer-upcoming-span" data-target="${targetSlot.startTime || new Date().toISOString()}">
                        01 : 45 : 30
                      </div>
                    </div>
                  </div>
                `}

                <!-- Action Buttons (1:1 with lines 1373-1498) -->
                ${isSubmitted ? `
                  <button class="btn-primary" style="background:#1E293B; border:1.5px solid #22C55E; color:#4ADE80; padding:12px; display:flex; align-items:center; justify-content:center; gap:8px;" data-view-sub="${session.id}">
                    <span class="material-symbols-rounded filled" style="font-size:18px; color:#22C55E;">check_circle</span>
                    <span>Submitted (${reg?.submissionPhotos?.length || 4} Pages) • විස්තර බලන්න</span>
                  </button>
                ` : isPackageOpening ? `
                  <button class="btn-primary" style="background:#D97706; padding:12px; display:flex; align-items:center; justify-content:center; gap:8px;" data-enter-exam="${session.id}">
                    <span class="material-symbols-rounded" style="font-size:18px;">inventory_2</span>
                    <span>Open Package in Camera Room (පාර්සලය විවෘත කරන්න)</span>
                  </button>
                ` : (isWriting || isLive) ? `
                  <button class="btn-primary" style="background:#16A34A; padding:12px; display:flex; align-items:center; justify-content:center; gap:8px;" data-enter-exam="${session.id}">
                    <span class="material-symbols-rounded filled" style="font-size:18px;">videocam</span>
                    <span>Enter Live Exam Room (කැමරාව ON කරන්න)</span>
                  </button>
                ` : isTimeUp ? `
                  <button class="btn-primary" style="background:#DC2626; padding:12px; display:flex; align-items:center; justify-content:center; gap:8px;" data-scan-answers="${session.id}">
                    <span class="material-symbols-rounded" style="font-size:18px;">document_scanner</span>
                    <span>Scan Answers (පිළිතුරු පත්‍ර Scan කරන්න)</span>
                  </button>
                ` : isWaiting ? `
                  <button class="btn-primary" style="background:#6366F1; padding:12px; display:flex; align-items:center; justify-content:center; gap:8px;" data-enter-exam="${session.id}">
                    <span class="material-symbols-rounded" style="font-size:18px;">meeting_room</span>
                    <span>Enter Waiting Room (පොරොත්තු ශාලාව)</span>
                  </button>
                ` : isEnded ? `
                  <button class="btn-primary" style="background:#F1F5F9; color:#94A3B8; border:1px solid #CBD5E1; cursor:not-allowed; padding:12px; display:flex; align-items:center; justify-content:center; gap:8px;" onclick="alert('මෙම විභාග සැසිය නිල වශයෙන් අවසන් කර ඇත (Session Ended).')">
                    <span class="material-symbols-rounded" style="font-size:18px;">cancel</span>
                    <span>විභාග සැසිය අවසන් විය (Ended)</span>
                  </button>
                ` : `
                  <button class="btn-primary" style="background:#6366F1; padding:12px; display:flex; align-items:center; justify-content:center; gap:8px;" data-enter-exam="${session.id}">
                    <span class="material-symbols-rounded" style="font-size:18px;">meeting_room</span>
                    <span>Enter Waiting Room (පොරොත්තු ශාලාව)</span>
                  </button>
                `}
              </div>
            `;
          }).join('')}
        </div>

        <!-- Tab 1: Upcoming Papers & Hints View (1:1 with _buildUpcomingPapersView lines 298-665) -->
        <div id="papers-tab-upcoming-content" style="${this.papersTab === 1 ? 'display:flex; flex-direction:column; gap:16px;' : 'display:none;'}">
          ${upcomingList.length === 0 ? `
            <div style="padding:40px 24px; text-align:center; color:#64748B;">
              <div style="margin-bottom:12px; display:flex; justify-content:center;">
                <span class="material-symbols-rounded" style="font-size:48px; color:#94A3B8;">lightbulb</span>
              </div>
              <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:6px;">No Upcoming Papers Scheduled Yet</div>
              <div style="font-size:13px; line-height:1.5;">${this.showAllBatches ? 'Check back soon for new exam papers, scopes, and preparation hints.' : `Upcoming papers and hints for ${currentYear} will be announced here.`}</div>
              <button class="btn-primary" id="btn-empty-toggle-batch-2" style="margin-top:16px; width:auto; padding:10px 20px; font-size:12.5px;">
                ${this.showAllBatches ? 'Show My Batch Only' : 'Show All Batches'}
              </button>
            </div>
          ` : upcomingList.map(paper => {
            const rawDate = paper.scheduledDate ? new Date(paper.scheduledDate) : new Date(Date.now() + 86400000 * 3);
            const schedDate = isNaN(rawDate.getTime()) ? new Date(Date.now() + 86400000 * 3) : rawDate;
            const durationMins = Number(paper.durationMinutes) || 180;
            const durationHours = (durationMins / 60).toFixed(1);
            const diffMs = schedDate.getTime() - Date.now();
            const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
            const hours = Math.floor((diffMs / (1000 * 60 * 60)) % 24);
            const minutes = Math.floor((diffMs / (1000 * 60)) % 60);
            const countdownText = days > 0 ? `${days}d ${hours}h ${minutes}m` : `${hours}h ${minutes}m`;

            return `
              <div class="upcoming-paper-card">
                <!-- Banner Header -->
                <div class="upcoming-paper-header-banner">
                  <div style="display:flex; align-items:center; gap:8px;">
                    <span style="background:rgba(99,102,241,0.1); color:#6366F1; border:1px solid rgba(99,102,241,0.3); padding:3px 10px; border-radius:8px; font-size:11px; font-weight:800;">
                      ${paper.subject || 'A/L Physics'}
                    </span>
                    <span style="background:#FFFFFF; color:#475569; border:1px solid #CBD5E1; padding:3px 10px; border-radius:8px; font-size:11px; font-weight:600;">
                      ${paper.examYear || '2027 A/L'}
                    </span>
                  </div>
                  <div class="upcoming-countdown-badge">
                    <span class="material-symbols-rounded" style="font-size:14px; margin-right:3px;">schedule</span>
                    <span>${diffMs > 0 ? countdownText : 'Paper Active'}</span>
                  </div>
                </div>

                <!-- Card Body -->
                <div style="padding:16px; display:flex; flex-direction:column; gap:12px;">
                  <div class="paper-title" style="font-size:16.5px;">${paper.title || 'Upcoming Model Paper'}</div>

                  <!-- Date & Duration -->
                  <div style="display:flex; flex-direction:column; gap:6px;">
                    <div style="display:flex; align-items:center; gap:6px; font-size:12px; color:#475569;">
                      <span class="material-symbols-rounded" style="font-size:15px; color:#64748B;">calendar_today</span>
                      <span>${schedDate.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })} at ${safeFormatTime(schedDate.toISOString(), '08:30 AM')}</span>
                    </div>
                    <div style="display:flex; align-items:center; gap:6px; font-size:12px; color:#475569;">
                      <span class="material-symbols-rounded" style="font-size:15px; color:#64748B;">timer</span>
                      <span>${durationMins} Minutes (${durationHours} Hours) • ${paper.paperStructure || 'Comprehensive Evaluation'}</span>
                    </div>
                  </div>

                  <!-- Syllabus Topics Chips (1:1 with lines 543-575) -->
                  ${paper.syllabusTopics && paper.syllabusTopics.length > 0 ? `
                    <div style="margin-top:2px;">
                      <div style="font-size:11px; font-weight:700; color:#475569; margin-bottom:4px;">Syllabus & Tested Topics:</div>
                      <div class="upcoming-topics-wrap">
                        ${paper.syllabusTopics.map(topic => `
                          <div class="upcoming-topic-chip">
                            <span class="material-symbols-rounded filled" style="font-size:14px; color:#10B981;">check_circle</span>
                            <span>${topic}</span>
                          </div>
                        `).join('')}
                      </div>
                    </div>
                  ` : ''}

                  <!-- EXCLUSIVE HINTS & TIPS (Highlight Box 1:1 with lines 578-617) -->
                  ${paper.hints ? `
                    <div class="upcoming-hints-highlight-box">
                      <div class="upcoming-hints-title">
                        <span class="material-symbols-rounded" style="font-size:18px; color:#D97706;">lightbulb</span>
                        <span>Special Paper Hints & Guidance</span>
                      </div>
                      <div class="upcoming-hints-text">
                        ${paper.hints}
                      </div>
                    </div>
                  ` : ''}

                  <!-- Instructions -->
                  ${paper.instructions ? `
                    <div style="display:flex; align-items:flex-start; gap:6px; font-size:11.5px; color:#64748B;">
                      <span class="material-symbols-rounded" style="font-size:16px; color:#64748B; flex-shrink:0;">info</span>
                      <span>${paper.instructions}</span>
                    </div>
                  ` : ''}

                  <!-- Action Button -->
                  <button class="btn-primary" style="background:#6366F1; padding:12px; font-size:13px; font-weight:700; display:flex; align-items:center; justify-content:center; gap:6px; box-shadow:0 4px 14px rgba(99,102,241,0.3);" data-paper-scope="${paper.id}">
                    <span class="material-symbols-rounded" style="font-size:18px;">visibility</span>
                    <span>View Full Scope & Hints</span>
                  </button>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `;

      // ── Live 1-Second Interval Ticker ──
      this.startPapersTimer(container, sessions);

      // ── Event Handlers ──
      document.getElementById('tab-papers-live')?.addEventListener('click', () => {
        this.papersTab = 0;
        this.renderPapersScreen(container);
      });

      document.getElementById('tab-papers-upcoming')?.addEventListener('click', () => {
        this.papersTab = 1;
        this.renderPapersScreen(container);
      });

      const toggleBatch = () => {
        this.showAllBatches = !this.showAllBatches;
        this.renderPapersScreen(container);
      };

      document.getElementById('btn-toggle-papers-batch')?.addEventListener('click', toggleBatch);
      document.getElementById('btn-refresh-papers')?.addEventListener('click', () => this.renderPapersScreen(container));
      document.getElementById('btn-empty-toggle-batch')?.addEventListener('click', toggleBatch);
      document.getElementById('btn-empty-toggle-batch-2')?.addEventListener('click', toggleBatch);

      // Slot Selection
      container.querySelectorAll('.slot-selection-box').forEach(box => {
        box.addEventListener('click', async () => {
          const pId = box.dataset.paperId;
          const sId = box.dataset.slotId;
          await dbService.registerStudentSlot({
            paperId: pId,
            studentId: user.uid || user.id || "s_default", studentName: user.name || "Scholar",
            studentPhone: user.phone || '0770557769',
            slotId: sId
          });
          notificationService.showLocalToast(`${sId === 'slot1' ? 'Slot 1 (Morning)' : 'Slot 2 (Evening)'} සාර්ථකව වෙන්කර ගන්නා ලදී!`);
          this.renderPapersScreen(container);
        });
      });

      // View Submission Details
      container.querySelectorAll('[data-view-sub]').forEach(btn => {
        btn.addEventListener('click', async () => {
          const pId = btn.dataset.viewSub;
          const sess = sessions.find(s => s.id === pId);
          const reg = registrations.get(pId);
          if (sess) this.showSubmissionDetailsDialog(sess, reg);
        });
      });

      // Enter Exam / Waiting Room
      container.querySelectorAll('[data-enter-exam]').forEach(btn => {
        btn.addEventListener('click', () => {
          const paperId = btn.dataset.enterExam;
          const reg = registrations.get(paperId);
          const selectedSlot = reg?.selectedSlot || 'slot1';
          this.openLiveExamRoom(paperId, selectedSlot);
        });
      });

      // Scan Answers
      container.querySelectorAll('[data-scan-answers]').forEach(btn => {
        btn.addEventListener('click', () => {
          this.openDocumentScanner();
        });
      });

      // View Full Scope & Hints Modal
      container.querySelectorAll('[data-paper-scope]').forEach(btn => {
        btn.addEventListener('click', () => {
          const pId = btn.dataset.paperScope;
          const paper = upcomingList.find(p => p.id === pId);
          if (paper) this.showUpcomingPaperDetailsModal(paper);
        });
      });
    } catch (renderError) {
      console.error('[PapersScreen] Critical render error caught:', renderError);
      container.innerHTML = `
        <div style="padding:40px 20px; text-align:center;">
          <span class="material-symbols-rounded filled" style="font-size:48px; color:#EF4444; margin-bottom:12px;">error</span>
          <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:6px;">Paper Sessions ලෝඩ් කිරීමේ ගැටළුවක්</div>
          <div style="font-size:12px; color:#64748B; margin-bottom:16px;">${renderError.message || 'Unknown error occurred'}</div>
          <button class="btn-primary" onclick="window.app ? window.app.renderPapersScreen(document.getElementById('main-viewport')) : location.reload()" style="width:auto; padding:10px 20px; margin:0 auto; display:inline-flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded" style="font-size:18px;">refresh</span>
            <span>නැවත උත්සාහ කරන්න (Retry)</span>
          </button>
        </div>
      `;
    }
  }

  // ── Live 1-Second Timer for Papers Screen ──
  startPapersTimer(container, sessions) {
    if (this.papersInterval) clearInterval(this.papersInterval);
    this.papersInterval = setInterval(() => {
      const now = Date.now();

      // Update package opening countdowns
      container.querySelectorAll('.timer-pkg-span').forEach(span => {
        const startIso = span.dataset.start;
        if (startIso) {
          const elapsed = Math.floor((now - new Date(startIso).getTime()) / 1000);
          const remaining = Math.max(0, 600 - elapsed);
          const m = Math.floor(remaining / 60).toString().padStart(2, '0');
          const s = (remaining % 60).toString().padStart(2, '0');
          span.textContent = `${m}:${s}`;
        }
      });

      // Update upcoming slot countdowns
      container.querySelectorAll('.timer-upcoming-span').forEach(span => {
        const targetIso = span.dataset.target;
        if (targetIso) {
          const diff = Math.max(0, new Date(targetIso).getTime() - now);
          const h = Math.floor(diff / (1000 * 3600)).toString().padStart(2, '0');
          const m = Math.floor((diff / (1000 * 60)) % 60).toString().padStart(2, '0');
          const s = Math.floor((diff / 1000) % 60).toString().padStart(2, '0');
          span.textContent = `${h} : ${m} : ${s}`;
        }
      });
    }, 1000);
  }

  // ── Show Full Scope & Hints Bottom Sheet (1:1 with _showUpcomingPaperDetailsModal lines 667-848) ──
  showUpcomingPaperDetailsModal(paper) {
    const existing = document.getElementById('upcoming-details-modal');
    if (existing) existing.remove();

    const schedDate = new Date(paper.scheduledDate);
    const durationHours = (paper.durationMinutes / 60).toFixed(1);

    const sheet = document.createElement('div');
    sheet.className = 'flutter-sheet-overlay';
    sheet.id = 'upcoming-details-modal';
    sheet.innerHTML = `
      <div class="flutter-sheet-container">
        <!-- Handle Bar (lines 688-698) -->
        <div class="flutter-sheet-handle"></div>

        <div class="flutter-sheet-body">
          <!-- Subject & Year Pills -->
          <div style="display:flex; align-items:center; gap:8px;">
            <span style="background:rgba(99,102,241,0.2); color:#818CF8; padding:4px 10px; border-radius:8px; font-size:12px; font-weight:800;">
              ${paper.subject}
            </span>
            <span style="background:rgba(255,255,255,0.1); color:#E2E8F0; padding:4px 10px; border-radius:8px; font-size:12px; font-weight:600;">
              ${paper.examYear}
            </span>
          </div>

          <!-- Paper Title -->
          <div style="font-size:19px; font-weight:800; color:#FFFFFF; line-height:1.35;">
            ${paper.title}
          </div>

          <!-- Date & Time Card (lines 739-760) -->
          <div style="background:#1E293B; border:1px solid #334155; border-radius:16px; padding:14px; display:flex; flex-direction:column; gap:10px;">
            <div style="display:flex; align-items:center; gap:10px;">
              <span class="material-symbols-rounded filled" style="font-size:22px; color:#818CF8;">calendar_today</span>
              <div>
                <div style="font-size:11px; color:#94A3B8;">Scheduled Date & Time</div>
                <div style="font-size:13px; font-weight:700; color:#F8FAFC;">
                  ${schedDate.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })}
                </div>
                <div style="font-size:12px; color:#818CF8; font-weight:600;">
                  Starting at ${schedDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </div>
              </div>
            </div>

            <div style="height:1px; background:#334155;"></div>

            <div style="display:flex; align-items:center; gap:10px;">
              <span class="material-symbols-rounded filled" style="font-size:22px; color:#F59E0B;">timer</span>
              <div>
                <div style="font-size:11px; color:#94A3B8;">Exam Duration & Structure</div>
                <div style="font-size:13px; font-weight:700; color:#F8FAFC;">
                  ${paper.durationMinutes} Minutes (${durationHours} Hours)
                </div>
                <div style="font-size:12px; color:#CBD5E1;">
                  ${paper.paperStructure}
                </div>
              </div>
            </div>
          </div>

          <!-- Full Syllabus Topics Scope (lines 770-800) -->
          ${paper.syllabusTopics && paper.syllabusTopics.length > 0 ? `
            <div>
              <div style="font-size:13.5px; font-weight:800; color:#FFFFFF; margin-bottom:8px;">
                Tested Syllabus Topics (විභාග විෂය පථය):
              </div>
              <div style="display:flex; flex-direction:column; gap:6px;">
                ${paper.syllabusTopics.map((topic, idx) => `
                  <div style="display:flex; align-items:center; gap:8px; background:#1E293B; padding:9px 12px; border-radius:10px; border:1px solid #334155; font-size:12px; color:#E2E8F0;">
                    <span class="material-symbols-rounded filled" style="color:#10B981; font-size:16px;">check_circle</span>
                    <span>${topic}</span>
                  </div>
                `).join('')}
              </div>
            </div>
          ` : ''}

          <!-- Special Paper Hints & Guidance (lines 801-813) -->
          ${paper.hints ? `
            <div>
              <div style="font-size:13.5px; font-weight:800; color:#F59E0B; margin-bottom:8px; display:flex; align-items:center; gap:6px;">
                <span class="material-symbols-rounded filled" style="font-size:20px; color:#F59E0B;">lightbulb</span>
                <span>Exclusive Teacher Guidance & Exam Hints</span>
              </div>
              <div style="background:rgba(245,158,11,0.12); border:1px solid rgba(245,158,11,0.4); border-radius:16px; padding:16px; color:#FEF3C7; font-size:12.5px; line-height:1.55;">
                ${paper.hints}
              </div>
            </div>
          ` : ''}

          <!-- Instructions & Rules (lines 815-827) -->
          ${paper.instructions ? `
            <div>
              <div style="font-size:13.5px; font-weight:800; color:#FFFFFF; margin-bottom:6px;">
                Instructions & Exam Chamber Rules
              </div>
              <div style="color:#94A3B8; font-size:12.5px; line-height:1.45;">
                ${paper.instructions}
              </div>
            </div>
          ` : ''}

          <!-- Close Button (lines 829-841) -->
          <button class="btn-primary" style="background:#6366F1; padding:14px; border-radius:14px; font-size:14px; font-weight:700; margin-top:8px;" id="btn-close-paper-scope">
            Close Scope & Hints (වසන්න)
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(sheet);

    sheet.querySelector('#btn-close-paper-scope')?.addEventListener('click', () => {
      sheet.remove();
    });

    sheet.addEventListener('click', (e) => {
      if (e.target === sheet) sheet.remove();
    });
  }

  // ── Show Submission Details Dialog (1:1 with _showSubmissionDetailsDialog lines 1538-1601) ──
  showSubmissionDetailsDialog(session, reg) {
    const existing = document.getElementById('submission-details-dialog');
    if (existing) existing.remove();

    const overlay = document.createElement('div');
    overlay.className = 'app-dialog-overlay';
    overlay.id = 'submission-details-dialog';
    overlay.innerHTML = `
      <div class="app-dialog-box" style="max-width:380px;">
        <div style="display:flex; align-items:center; gap:8px;">
          <span class="material-symbols-rounded filled" style="font-size:26px; color:#22C55E;">check_circle</span>
          <div class="app-dialog-title" style="font-size:16px;">Submission Confirmed</div>
        </div>

        <div style="display:flex; flex-direction:column; gap:8px; font-size:12.5px; color:#CBD5E1;">
          <div style="font-size:14px; font-weight:800; color:#A5B4FC;">${session.title}</div>
          <div>Subject: <strong style="color:#FFFFFF;">${session.subject} (${session.examYear})</strong></div>
          <div>Submitted Pages: <strong style="color:#4ADE80;">${reg?.submissionPhotos?.length || 4} Pages</strong></div>
          <div style="font-size:11px; color:#94A3B8;">
            Time: ${reg?.submittedAt ? new Date(reg.submittedAt).toLocaleString() : 'Today, Live Session Verified'}
          </div>
          <div style="background:rgba(30,41,59,0.8); border:1px solid #334155; border-radius:10px; padding:10px; font-size:11px; color:#94A3B8; line-height:1.45; margin-top:4px;">
            ඔබගේ පිළිතුරු පත්‍ර ගුරුභවතුන් වෙත සුරක්ෂිතව ලැබී ඇති බැවින් නැවත විභාග ශාලාවට පිවිසීමට අවශ්‍ය නොවේ.
          </div>
        </div>

        <div class="app-dialog-actions" style="margin-top:10px;">
          <button class="btn-primary" style="background:#22C55E; width:100%; padding:10px; border-radius:8px; font-weight:800; font-size:13px;" id="btn-close-sub-dialog">
            හරි (Done)
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    overlay.querySelector('#btn-close-sub-dialog')?.addEventListener('click', () => {
      overlay.remove();
    });

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) overlay.remove();
    });
  }

  // ── 3. Ranks Tab (Dessert XP Leagues & Paper Leaderboard - 1:1 Android) ───
  async renderRanksScreen(container) {
    const renderToken = ++this.renderToken;
    this.ranksBoardType = this.ranksBoardType ?? 0; // 0: Dessert, 1: Paper
    this.selectedLeague = this.selectedLeague ?? 'All Scholars';
    const currentUser = this.currentUser || {};
    const isAdmin = currentUser.role === 'admin';
    const studentBatch = String(currentUser.examYear || '').trim();
    this.selectedRanksBatch = isAdmin
      ? (this.selectedRanksBatch || 'All Batches')
      : studentBatch;
    this.expandedPaperBoards = this.expandedPaperBoards ?? new Set();
    this.paperBoardsInitialized = this.paperBoardsInitialized ?? false;

    let leaders = [];
    let paperBoards = [];
    let leaderboardLoadError = false;
    let paperLeaderboardLoadError = false;
    try {
      if (this.ranksBoardType === 0) {
        leaders = await dbService.getLeaderboard(isAdmin ? this.selectedRanksBatch : undefined);
      } else {
        paperBoards = await dbService.getPaperLeaderboards();
      }
    } catch (error) {
      console.warn('[Ranks] Board could not be loaded:', error?.code || 'unknown');
      if (this.ranksBoardType === 0) leaderboardLoadError = true;
      else paperLeaderboardLoadError = true;
    }
    if (renderToken !== this.renderToken || !container.isConnected) return;
    const leagues = [
      { name: 'All Scholars', icon: 'public' },
      { name: 'Diamond', icon: 'diamond' },
      { name: 'Gold', icon: 'military_tech' },
      { name: 'Silver', icon: 'military_tech' },
      { name: 'Bronze', icon: 'military_tech' }
    ];

    const normalizeBatch = (value) => String(value || '').replace(/\s+/g, '').toUpperCase();
    const escapeHTML = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[char]);
    const paperBatchFilter = isAdmin ? this.selectedRanksBatch : studentBatch;
    const normalizedPaperBatch = normalizeBatch(paperBatchFilter);
    const visiblePaperBoards = paperBoards.filter((board) => {
      const boardBatch = normalizeBatch(board.examYear);
      return !normalizedPaperBatch || normalizedPaperBatch === 'ALLBATCHES'
        || boardBatch === normalizedPaperBatch || boardBatch === 'ALLBATCHES' || boardBatch === 'ALL';
    });
    if (this.ranksBoardType === 1 && !this.paperBoardsInitialized && visiblePaperBoards[0]) {
      this.expandedPaperBoards.add(visiblePaperBoards[0].id);
      this.paperBoardsInitialized = true;
    }
    const filtered = leaders.filter(s => {
      if (s.role !== 'student') return false;
      if (isAdmin) {
        if (this.selectedRanksBatch !== 'All Batches' && normalizeBatch(s.examYear) !== normalizeBatch(this.selectedRanksBatch)) return false;
      } else if (!studentBatch || normalizeBatch(s.examYear) !== normalizeBatch(studentBatch)) {
        return false;
      }
      if (this.selectedLeague === 'Diamond') return s.credits >= 500;
      if (this.selectedLeague === 'Gold') return s.credits >= 250 && s.credits < 500;
      if (this.selectedLeague === 'Silver') return s.credits >= 100 && s.credits < 250;
      if (this.selectedLeague === 'Bronze') return s.credits < 100;
      return true;
    }).sort((a, b) => b.credits - a.credits);

    filtered.forEach((student, index) => { student.rank = index + 1; });
    const top3 = filtered.slice(0, 3);
    const showPodium = this.selectedLeague === 'All Scholars' && top3.length >= 2;
    const visibleRankRows = showPodium ? filtered.slice(3) : filtered;
    const currentUserId = currentUser.uid || currentUser.id;
    const currentUserRank = filtered.findIndex((student) => student.id === currentUserId) + 1;
    const currentUserEntry = currentUserRank > 0 ? filtered[currentUserRank - 1] : null;
    const nextRankEntry = currentUserRank > 1 ? filtered[currentUserRank - 2] : null;
    const emptyBatchLabel = isAdmin
      ? (this.selectedRanksBatch === 'All Batches' ? '' : this.selectedRanksBatch)
      : studentBatch;
    const xpToNextRank = nextRankEntry
      ? Math.max(1, nextRankEntry.credits - currentUserEntry.credits + 1)
      : 0;

    const rankingContent = leaderboardLoadError
      ? `<div class="leaderboard-state" role="status">
          <span class="material-symbols-rounded">cloud_off</span>
          <strong>Leaderboard unavailable</strong>
          <span>Check your connection and try again.</span>
          <button class="leaderboard-retry-btn" id="btn-ranks-retry" type="button">Retry</button>
        </div>`
      : filtered.length === 0
        ? `<div class="leaderboard-state" role="status">
            <span class="material-symbols-rounded">emoji_events</span>
            <strong>${!emptyBatchLabel ? 'No students ranked yet' : `No students ranked in ${escapeHTML(emptyBatchLabel)} yet`}</strong>
            <span>Rankings appear here when student XP records are available.</span>
          </div>`
        : `${showPodium ? `
            <div class="podium-container">
              <div class="podium-card">
                <div class="podium-medal"><span class="material-symbols-rounded filled" style="color:#94A3B8; font-size:24px;">military_tech</span></div>
                <div class="podium-name">${escapeHTML(top3[1].name.split(' ')[0])}</div>
                <div class="podium-xp">${top3[1].credits} XP</div>
                <span style="font-size:10px; color:#64748B;">#2 Rank</span>
              </div>
              <div class="podium-card podium-card-gold">
                <div class="podium-medal-gold"><span class="material-symbols-rounded filled" style="color:#B45309; font-size:28px;">emoji_events</span></div>
                <div class="podium-name">${escapeHTML(top3[0].name.split(' ')[0])}</div>
                <div class="podium-xp">${top3[0].credits} XP</div>
                <span style="font-size:11px; font-weight:800; color:#B45309;">#1 Rank</span>
              </div>
              <div class="podium-card">
                <div class="podium-medal"><span class="material-symbols-rounded filled" style="color:#B45309; font-size:24px;">military_tech</span></div>
                <div class="podium-name">${top3[2] ? escapeHTML(top3[2].name.split(' ')[0]) : '—'}</div>
                <div class="podium-xp">${top3[2] ? `${top3[2].credits} XP` : ''}</div>
                <span style="font-size:10px; color:#64748B;">#3 Rank</span>
              </div>
            </div>
          ` : ''}
          <div class="ranks-list">
            ${visibleRankRows.map((student) => `
              <div class="rank-list-item ${student.id === (currentUser.uid || currentUser.id) ? 'is-current-user' : ''}">
                <div class="rank-item-left">
                  <span class="rank-index">#${student.rank}</span>
                  <div class="rank-avatar">${escapeHTML(String(student.name || 'S').charAt(0).toUpperCase())}</div>
                  <div class="rank-name-box">
                    <div class="rank-student-name">
                      <span>${escapeHTML(student.name)}</span>
                      ${student.id === (currentUser.uid || currentUser.id) ? '<span class="rank-you-tag">You</span>' : ''}
                    </div>
                    <div class="rank-batch-tag">${escapeHTML(student.examYear || 'General Batch')}</div>
                  </div>
                </div>
                <span class="rank-xp-pill">${student.credits} XP</span>
              </div>
            `).join('')}
          </div>
          ${currentUserEntry ? `
            <div class="my-rank-sticky-bar">
              <div class="my-rank-info">
                <span class="my-rank-num">#${currentUserRank}</span>
                <div>
                  <div class="my-rank-name">${escapeHTML(currentUserEntry.name)} (You)</div>
                  <div class="my-rank-next">${nextRankEntry ? `Next rank: +${xpToNextRank} XP needed` : 'You are ranked #1!'}</div>
                </div>
              </div>
              <span class="my-rank-xp">${currentUserEntry.credits} XP</span>
            </div>
          ` : ''}`;

    const ownPhone = String(currentUser.phone || '').replace(/\D/g, '');
    const paperViewContent = paperLeaderboardLoadError
      ? `<div class="leaderboard-state" role="status">
          <span class="material-symbols-rounded">cloud_off</span>
          <strong>Paper results unavailable</strong>
          <span>Check your connection and try again.</span>
          <button class="leaderboard-retry-btn" id="btn-ranks-retry" type="button">Retry</button>
        </div>`
      : visiblePaperBoards.length === 0
        ? `<div class="leaderboard-state" role="status">
            <span class="material-symbols-rounded">military_tech</span>
            <strong>No Paper Leaderboards for ${escapeHTML(paperBatchFilter || 'your batch')}</strong>
            <span>Official rankings and marks will appear here after an evaluation is published.</span>
          </div>`
        : `<div class="paper-results-list">
            ${visiblePaperBoards.map((board, boardIndex) => {
              const entries = board.entries || [];
              const expanded = this.expandedPaperBoards.has(board.id);
              const myEntry = entries.find((entry) => {
                const entryPhone = String(entry.studentPhone || '').replace(/\D/g, '');
                return (entry.studentId && entry.studentId === (currentUser.uid || currentUser.id))
                  || (ownPhone && entryPhone && ownPhone === entryPhone)
                  || (currentUser.name && entry.studentName.trim().toLowerCase() === String(currentUser.name).trim().toLowerCase());
              });
              const publishedDate = board.publishedAt.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
              const topThree = entries.slice(0, 3);
              return `
                <article class="paper-board-card ${boardIndex === 0 ? 'is-latest' : ''}">
                  <button class="paper-board-header" type="button" data-paper-board="${escapeHTML(board.id)}" aria-expanded="${expanded}">
                    <span class="paper-board-heading-content">
                      <span class="paper-board-tag">${escapeHTML(board.subject)} · ${escapeHTML(board.examYear)}</span>
                      ${boardIndex === 0 ? '<span class="paper-latest-tag">LATEST</span>' : ''}
                      <span class="paper-board-date">${escapeHTML(publishedDate)}</span>
                      <strong class="paper-board-title">${escapeHTML(board.paperTitle)}</strong>
                      <span class="paper-board-stats">
                        <span>Max: ${board.totalMarks} marks</span>
                        <span>${entries.length} candidates</span>
                        ${myEntry ? `<span class="paper-my-result">You: #${myEntry.rank} · ${myEntry.marks}/${board.totalMarks}</span>` : ''}
                      </span>
                      ${!expanded && entries[0] ? `<span class="paper-winner-snippet">Rank 1: ${escapeHTML(entries[0].studentName)} (${entries[0].marks} marks · ${escapeHTML(entries[0].grade)})</span>` : ''}
                    </span>
                    <span class="material-symbols-rounded paper-expand-icon">${expanded ? 'expand_less' : 'expand_more'}</span>
                  </button>
                  ${expanded ? `
                    <div class="paper-results-content">
                      ${topThree.length >= 2 ? `
                        <div class="paper-results-podium">
                          ${topThree.slice(0, 3).map((entry, index) => `
                            <div class="paper-results-podium-item ${index === 0 ? 'first' : ''}">
                              <span class="material-symbols-rounded">${index === 0 ? 'emoji_events' : 'military_tech'}</span>
                              <strong>${escapeHTML(entry.studentName)}</strong>
                              <span>#${entry.rank} · ${entry.marks} marks</span>
                            </div>
                          `).join('')}
                        </div>
                      ` : ''}
                      <div class="paper-results-list-heading">Full Candidate Rankings <span>${entries.length} ranked</span></div>
                      ${entries.length ? entries.map((entry) => `
                        <div class="paper-result-row ${myEntry && entry.rank === myEntry.rank ? 'is-current-user' : ''}">
                          <span class="paper-result-rank">#${entry.rank}</span>
                          <span class="paper-result-name">${escapeHTML(entry.studentName)}${myEntry && entry.rank === myEntry.rank ? ' <b>You</b>' : ''}</span>
                          <span class="grade-badge grade-${escapeHTML(entry.grade)}">${escapeHTML(entry.grade)}</span>
                          <strong class="paper-result-marks">${entry.marks} / ${board.totalMarks}</strong>
                        </div>
                      `).join('') : '<div class="paper-results-empty">No candidate records published yet.</div>'}
                    </div>
                  ` : ''}
                </article>
              `;
            }).join('')}
          </div>`;

    container.innerHTML = `
      <!-- Screen Top Bar -->
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#FEF3C7; color:#B45309;">
            <span class="material-symbols-rounded filled">emoji_events</span>
          </div>
          <div>
            <div class="appbar-title">${this.ranksBoardType === 0 ? 'Dessert Leaderboard' : 'Paper Leaderboard'}</div>
            <div class="appbar-subtitle">${this.ranksBoardType === 0 ? 'XP Credits & Activity Leagues' : 'Exam Marks & Island Rankings'}</div>
          </div>
        </div>
      </div>

      <!-- Segmented Switcher: Dessert vs Paper -->
      <div class="sub-tabs-container">
        <button class="sub-tab-btn ${this.ranksBoardType === 0 ? 'active' : ''}" id="btn-ranks-dessert-mode">
          <span style="display:inline-flex; align-items:center; gap:6px;"><span class="material-symbols-rounded filled" style="font-size:16px;">emoji_events</span> Dessert Leaderboard</span>
          <span class="tab-sub">XP & Activity Leagues</span>
        </button>
        <button class="sub-tab-btn ${this.ranksBoardType === 1 ? 'active' : ''}" id="btn-ranks-paper-mode">
          <span style="display:inline-flex; align-items:center; gap:6px;"><span class="material-symbols-rounded" style="font-size:16px;">assignment</span> Paper Leaderboard</span>
          <span class="tab-sub">Exam Marks & Ranks</span>
        </button>
      </div>

      ${this.ranksBoardType === 0 ? `
        ${isAdmin ? `
          <div class="batch-filter-row">
            <span>Batch Selection:</span>
            <select class="batch-select" id="select-ranks-batch">
              <option value="All Batches" ${this.selectedRanksBatch === 'All Batches' ? 'selected' : ''}>All Batches</option>
              <option value="2024 A/L" ${this.selectedRanksBatch === '2024 A/L' ? 'selected' : ''}>2024 A/L</option>
              <option value="2025 A/L" ${this.selectedRanksBatch === '2025 A/L' ? 'selected' : ''}>2025 A/L</option>
              <option value="2026 A/L" ${this.selectedRanksBatch === '2026 A/L' ? 'selected' : ''}>2026 A/L</option>
              <option value="2027 A/L" ${this.selectedRanksBatch === '2027 A/L' ? 'selected' : ''}>2027 A/L</option>
              <option value="2028 A/L" ${this.selectedRanksBatch === '2028 A/L' ? 'selected' : ''}>2028 A/L</option>
              <option value="2029 A/L" ${this.selectedRanksBatch === '2029 A/L' ? 'selected' : ''}>2029 A/L</option>
            </select>
          </div>
        ` : `
          <div class="leaderboard-batch-banner">
            <strong>${escapeHTML(studentBatch || 'General Batch')} Standings</strong>
            <span>Showing rankings for your exam year</span>
          </div>
        `}

        <!-- League Horizontal Filter Scroll -->
        <div class="leagues-scroll-row">
          ${leagues.map(l => `
            <button class="league-chip ${this.selectedLeague === l.name ? 'active' : ''}" data-league="${l.name}">
              <span class="material-symbols-rounded filled" style="font-size:16px;">${l.icon}</span>
              <span>${l.name}</span>
            </button>
          `).join('')}
        </div>

      ${rankingContent}
      ` : `
        ${isAdmin ? `
          <div class="batch-filter-row paper-batch-filter">
            <span>Batch Selection:</span>
            <select class="batch-select" id="select-ranks-batch">
              <option value="All Batches" ${this.selectedRanksBatch === 'All Batches' ? 'selected' : ''}>All Batches</option>
              <option value="2024 A/L" ${this.selectedRanksBatch === '2024 A/L' ? 'selected' : ''}>2024 A/L</option>
              <option value="2025 A/L" ${this.selectedRanksBatch === '2025 A/L' ? 'selected' : ''}>2025 A/L</option>
              <option value="2026 A/L" ${this.selectedRanksBatch === '2026 A/L' ? 'selected' : ''}>2026 A/L</option>
              <option value="2027 A/L" ${this.selectedRanksBatch === '2027 A/L' ? 'selected' : ''}>2027 A/L</option>
              <option value="2028 A/L" ${this.selectedRanksBatch === '2028 A/L' ? 'selected' : ''}>2028 A/L</option>
              <option value="2029 A/L" ${this.selectedRanksBatch === '2029 A/L' ? 'selected' : ''}>2029 A/L</option>
            </select>
          </div>
        ` : `
          <div class="leaderboard-batch-banner paper-batch-banner">
            <strong>${escapeHTML(studentBatch || 'General Batch')} Paper Results</strong>
            <span>Official exam evaluations for your batch</span>
          </div>
        `}
        ${paperViewContent}
      `}
    `;

    // Event Listeners
    document.getElementById('btn-ranks-dessert-mode')?.addEventListener('click', () => {
      this.ranksBoardType = 0;
      this.renderRanksScreen(container);
    });

    document.getElementById('btn-ranks-paper-mode')?.addEventListener('click', () => {
      this.ranksBoardType = 1;
      this.renderRanksScreen(container);
    });

    container.querySelectorAll('.league-chip').forEach(btn => {
      btn.addEventListener('click', () => {
        this.selectedLeague = btn.dataset.league;
        this.renderRanksScreen(container);
      });
    });

    document.getElementById('select-ranks-batch')?.addEventListener('change', (e) => {
      this.selectedRanksBatch = e.target.value;
      this.expandedPaperBoards = new Set();
      this.paperBoardsInitialized = false;
      this.renderRanksScreen(container);
    });

    document.getElementById('btn-ranks-retry')?.addEventListener('click', () => {
      this.renderRanksScreen(container);
    });

    container.querySelectorAll('[data-paper-board]').forEach((button) => {
      button.addEventListener('click', () => {
        const boardId = button.dataset.paperBoard;
        if (this.expandedPaperBoards.has(boardId)) this.expandedPaperBoards.delete(boardId);
        else this.expandedPaperBoards.add(boardId);
        this.renderRanksScreen(container);
      });
    });
  }

  // ── 4. Desserts Tab (Submit Homework & Submissions History - 1:1 Android) ──
  async renderDessertsScreen(container) {
    const renderToken = ++this.renderToken;
    this.dessertsTab = this.dessertsTab ?? 0; // 0: Submit Homework, 1: History
    this.selectedTopic = this.selectedTopic ?? 'Mechanics';
    this.capturedHomeworkPhotos = this.capturedHomeworkPhotos ?? [];
    this.dessertHistoryFilter = this.dessertHistoryFilter ?? 'All';

    const user = this.currentUser || {};
    const desserts = await dbService.getStudentDesserts(user.uid || user.id, user.phone);
    if (renderToken !== this.renderToken || !container.isConnected) return;

    const topics = [
      'Mechanics',
      'Waves & Optics',
      'Thermal Physics',
      'Electricity & Mag',
      'Modern Physics',
      'Unit Test'
    ];

    container.innerHTML = `
      <!-- Screen Top Bar -->
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#EFF6FF; color:#2563EB;">
            <span class="material-symbols-rounded">folder_special</span>
          </div>
          <div>
            <div class="appbar-title">Dessert Homework System</div>
            <div class="appbar-subtitle">A/L Physics Daily Problem Sets & Submissions</div>
          </div>
        </div>
      </div>

      <!-- Sub-Tabs: Submit Homework vs Submissions History -->
      <div class="sub-tabs-container">
        <button class="sub-tab-btn ${this.dessertsTab === 0 ? 'active' : ''}" id="tab-dessert-submit">
          <span style="display:inline-flex; align-items:center; gap:6px;"><span class="material-symbols-rounded" style="font-size:16px;">upload_file</span> Submit Homework</span>
          <span class="tab-sub">Scan & Upload Pages</span>
        </button>
        <button class="sub-tab-btn ${this.dessertsTab === 1 ? 'active' : ''}" id="tab-dessert-history">
          <span style="display:inline-flex; align-items:center; gap:6px;"><span class="material-symbols-rounded" style="font-size:16px;">history</span> Submission History</span>
          <span class="tab-sub">Marks & Teacher Feedback</span>
        </button>
      </div>

      ${this.dessertsTab === 0 ? `
        <!-- Tab 0: Submit Homework Form -->
        <div style="display:flex; flex-direction:column; gap:12px;">
          <!-- Topic Tag Selector -->
          <div class="hero-card" style="padding:16px;">
            <div class="form-label" style="margin-bottom:4px;">1. තෝරාගත් ඒකකය (Select Topic Tag):</div>
            <div class="topic-chips-grid">
              ${topics.map(t => `
                <button class="topic-chip ${this.selectedTopic === t ? 'active' : ''}" data-topic="${t}">
                  ${t}
                </button>
              `).join('')}
            </div>
          </div>

          <!-- Document Capture Buttons -->
          <div class="hero-card" style="padding:16px;">
            <div class="form-label" style="margin-bottom:8px;">2. පිළිතුරු පත්‍ර ඡායාරූප (Capture Homework Pages):</div>
            <div class="capture-buttons-row">
              <button class="capture-btn" id="btn-dessert-open-cam">
                <span class="material-symbols-rounded" style="font-size:26px;">photo_camera</span>
                <span>In-App Camera</span>
              </button>
              <label class="capture-btn" for="input-hw-gallery" style="margin-bottom:0;">
                <span class="material-symbols-rounded" style="font-size:26px;">photo_library</span>
                <span>Gallery / Files</span>
                <input type="file" id="input-hw-gallery" accept="image/*" multiple style="display:none;" />
              </label>
            </div>

            <!-- Multi-Page Photo Strip -->
            ${this.capturedHomeworkPhotos.length > 0 ? `
              <div style="font-size:11px; font-weight:800; color:#2563EB; margin:8px 0 4px;">
                Attached Pages (${this.capturedHomeworkPhotos.length}):
              </div>
              <div class="photos-preview-strip">
                ${this.capturedHomeworkPhotos.map((url, i) => `
                  <div class="photo-thumb-card">
                    <img src="${url}" alt="Page ${i + 1}" />
                    <span class="photo-page-num">P${i + 1}</span>
                    <button class="photo-delete-btn" data-del-photo="${i}" style="display:inline-flex; align-items:center; justify-content:center;">
                      <span class="material-symbols-rounded" style="font-size:12px;">close</span>
                    </button>
                  </div>
                `).join('')}
              </div>
            ` : `
              <div style="text-align:center; padding:12px; background:#F8FAFC; border:1px dashed #CBD5E1; border-radius:12px; font-size:11.5px; color:#64748B;">
                No pages attached yet. Tap Camera or Gallery to add pages.
              </div>
            `}
          </div>

          <!-- Caption Textarea -->
          <div class="hero-card" style="padding:16px;">
            <div class="form-label" style="margin-bottom:6px;">3. සටහන / ප්‍රශ්න අංක (Student Remarks / Questions):</div>
            <textarea class="form-textarea" id="input-dessert-caption" rows="2" placeholder="උදා: Mechanics Past Paper 2024 Structured Essay Q1 & Q2..."></textarea>
          </div>

          <!-- Telegram Alternative Guide -->
          <div class="telegram-guide-card">
            <div>
              <div style="display:flex; align-items:center; gap:6px; font-size:12.5px; font-weight:800;">
                <span class="material-symbols-rounded" style="font-size:18px;">smart_toy</span>
                Submit via Telegram AI Bot
              </div>
              <div style="font-size:10.5px; opacity:0.9; margin-top:2px;">Prefer Telegram? Forward images directly to @edupeakbot</div>
            </div>
            <a href="https://t.me/edupeakbot" target="_blank" style="background:#FFFFFF; color:#0369A1; padding:6px 12px; border-radius:20px; font-size:11.5px; font-weight:800; text-decoration:none;">
              Open Bot
            </a>
          </div>

          <!-- Submit Button -->
          <button class="btn-primary" id="btn-submit-dessert-final" style="padding:14px; font-size:15px; margin-top:4px; display:inline-flex; align-items:center; justify-content:center; gap:8px;">
            <span class="material-symbols-rounded filled" style="font-size:18px;">send</span>
            <span>Submit Homework (+100 XP)</span>
          </button>
        </div>
      ` : `
        <!-- Tab 1: Submission History -->
        <div style="display:flex; flex-direction:column; gap:12px;">
          <!-- Filter Chips -->
          <div class="history-filter-chips">
            ${['All', 'Pending', 'Approved', 'Rejected'].map(f => `
              <button class="history-filter-chip ${this.dessertHistoryFilter === f ? 'active' : ''}" data-hist-filter="${f}">
                ${f}
              </button>
            `).join('')}
          </div>

          <!-- List of Submissions -->
          <div style="display:flex; flex-direction:column; gap:12px;">
            ${(() => {
              const filtered = desserts.filter(d => {
                if (this.dessertHistoryFilter === 'All') return true;
                return (d.status || '').toLowerCase() === this.dessertHistoryFilter.toLowerCase();
              });
              if (filtered.length === 0) {
                return `
                  <div style="text-align:center; padding:32px 16px; background:#FFFFFF; border-radius:16px; border:1px dashed #CBD5E1; color:#64748B;">
                    <div style="margin-bottom:8px;"><span class="material-symbols-rounded" style="font-size:40px; color:#94A3B8;">folder_open</span></div>
                    <div style="font-weight:700; font-size:14px; color:#0F172A;">No Submissions Found</div>
                    <div style="font-size:11.5px; margin-top:4px;">No ${this.dessertHistoryFilter} submissions yet. Submit your homework in Tab 1 to earn XP!</div>
                  </div>
                `;
              }
              return filtered.map(d => {
                const isApp = d.status === 'approved';
                const isPend = d.status === 'pending';
                const badgeClass = isApp ? 'quest-badge-green' : isPend ? 'quest-badge-orange' : 'quest-badge-blue';
                const label = isApp 
                  ? '<span class="material-symbols-rounded filled" style="font-size:13px; vertical-align:middle;">check_circle</span> Approved' 
                  : isPend 
                  ? '<span class="material-symbols-rounded filled" style="font-size:13px; vertical-align:middle;">hourglass_top</span> In Review' 
                  : '<span class="material-symbols-rounded filled" style="font-size:13px; vertical-align:middle;">warning</span> Needs Redo';

                return `
                  <div class="hero-card" style="padding:16px; cursor:pointer;" data-view-dessert="${d.id}">
                    <div style="display:flex; justify-content:space-between; align-items:center;">
                      <span class="quest-status-badge ${badgeClass}">${label}</span>
                      <span style="font-size:12px; font-weight:900; color:#2563EB;">+${d.creditsAwarded || 100} XP</span>
                    </div>

                    <div style="font-size:14.5px; font-weight:800; color:#0F172A; margin-top:8px;">${d.subject}</div>
                    <div style="font-size:11.5px; color:#64748B; margin-top:2px;">${d.caption || 'Daily Dessert Problem Set'}</div>

                    ${d.mediaUrls && d.mediaUrls.length > 0 ? `
                      <div style="display:flex; gap:6px; margin-top:8px; overflow-x:auto;">
                        ${d.mediaUrls.map(u => `
                          <img src="${u}" style="width:48px; height:48px; border-radius:8px; object-fit:cover; border:1px solid #E2E8F0;" />
                        `).join('')}
                      </div>
                    ` : ''}

                    ${d.adminFeedback ? `
                      <div style="margin-top:10px; padding:10px; background:#EFF6FF; border-left:3px solid #2563EB; border-radius:8px; font-size:11.5px; color:#1E3A8A; line-height:1.4;">
                        <strong style="display:inline-flex; align-items:center; gap:4px;"><span class="material-symbols-rounded" style="font-size:14px;">school</span> Teacher Feedback:</strong> ${d.adminFeedback}
                      </div>
                    ` : ''}
                  </div>
                `;
              }).join('');
            })()}
          </div>
        </div>
      `}
    `;

    // Event Listeners for Desserts Tab
    document.getElementById('tab-dessert-submit')?.addEventListener('click', () => {
      this.dessertsTab = 0;
      this.renderDessertsScreen(container);
    });

    document.getElementById('tab-dessert-history')?.addEventListener('click', () => {
      this.dessertsTab = 1;
      this.renderDessertsScreen(container);
    });

    container.querySelectorAll('.topic-chip').forEach(btn => {
      btn.addEventListener('click', () => {
        this.selectedTopic = btn.dataset.topic;
        this.renderDessertsScreen(container);
      });
    });

    container.querySelectorAll('.history-filter-chip').forEach(btn => {
      btn.addEventListener('click', () => {
        this.dessertHistoryFilter = btn.dataset.histFilter;
        this.renderDessertsScreen(container);
      });
    });

    document.getElementById('btn-dessert-open-cam')?.addEventListener('click', () => {
      this.openDocumentScanner();
    });

    const fileInput = document.getElementById('input-hw-gallery');
    fileInput?.addEventListener('change', (e) => {
      const files = Array.from(e.target.files);
      files.forEach(file => {
        const reader = new FileReader();
        reader.onload = (re) => {
          this.capturedHomeworkPhotos.push(re.target.result);
          this.renderDessertsScreen(container);
        };
        reader.readAsDataURL(file);
      });
    });

    container.querySelectorAll('[data-del-photo]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const idx = Number(btn.dataset.delPhoto);
        this.capturedHomeworkPhotos.splice(idx, 1);
        this.renderDessertsScreen(container);
      });
    });

    document.getElementById('btn-submit-dessert-final')?.addEventListener('click', async () => {
      const caption = document.getElementById('input-dessert-caption')?.value.trim();
      const btn = document.getElementById('btn-submit-dessert-final');
      if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<span class="material-symbols-rounded" style="font-size:16px; vertical-align:middle;">hourglass_top</span> Uploading to Teacher...';
      }

      await dbService.submitDessert({
        studentId: user.uid || user.id, studentName: user.name, studentPhone: user.phone,
        subject: `Physics: ${this.selectedTopic}`,
        caption: caption || `Homework submission on ${this.selectedTopic}`,
        mediaUrls: this.capturedHomeworkPhotos.length > 0 ? this.capturedHomeworkPhotos : ['./icons/exam_3d_countdown.jpg']
      });

      this.capturedHomeworkPhotos = [];
      notificationService.showInAppBanner('Homework Submitted!', 'Your submission was saved for review.', 'success');
      this.dessertsTab = 1;
      this.renderDessertsScreen(container);
    });

    container.querySelectorAll('[data-view-dessert]').forEach(card => {
      card.addEventListener('click', () => {
        this.openDessertDetailModal(card.dataset.viewDessert);
      });
    });
  }

  // ── 5. Profile Tab (Trophy Room, Dark Mode, Exam Batch & Avatar Picker - 1:1 Android) ──
  async renderProfileScreen(container) {
    const renderToken = ++this.renderToken;
    const user = this.currentUser || {};
    const isStandalone = window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches;
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const examBatches = ['2025 A/L', '2026 A/L', '2027 A/L', '2028 A/L', '2029 A/L'];
    const currentBatch = user.examYear || '2027 A/L';

    // Fetch student's real homework submissions from Firestore
    let desserts = [];
    try {
      desserts = await dbService.getStudentDesserts(user.uid || user.id, user.phone) || [];
    } catch (_) {
      desserts = [];
    }
    const approvedCount = desserts.filter(d => d.status === 'approved').length;
    const pendingCount = desserts.filter(d => !d.status || d.status === 'pending').length;
    if (renderToken !== this.renderToken || !container.isConnected) return;
    const totalCount = desserts.length;
    const creditsXP = user.credits ?? 155;

    // Format member since date
    let memberSinceStr = 'September 2026';
    if (user.createdAt) {
      try {
        const d = new Date(user.createdAt);
        memberSinceStr = d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
      } catch (_) {}
    }

    container.innerHTML = `
      <!-- Screen Top Bar -->
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#EFF6FF; color:#2563EB;">
            <span class="material-symbols-rounded">person</span>
          </div>
          <div>
            <div class="appbar-title">Student Profile</div>
            <div class="appbar-subtitle">Account Details, Batch & Preferences</div>
          </div>
        </div>
      </div>

      <!-- Large DP with Camera Badge -->
      <div class="hero-card" style="align-items:center; text-align:center; padding:22px;">
        <div class="profile-avatar-stack">
          ${user.avatarUrl ? `
            <img src="${user.avatarUrl}" class="profile-avatar-img" />
          ` : `
            <div class="profile-avatar-img">${user.name ? user.name.charAt(0).toUpperCase() : 'K'}</div>
          `}
          <button class="profile-cam-btn" id="btn-change-avatar" title="Change Profile Photo">
            <span class="material-symbols-rounded" style="font-size:16px;">photo_camera</span>
          </button>
        </div>

        <div style="display:flex; align-items:center; gap:6px; margin-top:8px;">
          <span style="font-size:20px; font-weight:800; color:#0F172A;" id="profile-display-name">${user.name || 'Kasun Perera'}</span>
          <button id="btn-edit-student-name" style="background:none; border:none; color:#64748B; cursor:pointer; font-size:15px; display:inline-flex; align-items:center;" title="Edit Name">
            <span class="material-symbols-rounded" style="font-size:18px;">edit</span>
          </button>
        </div>

        <div style="font-size:12.5px; color:#64748B; margin-top:2px;">
          ${user.phone || '+94 77 123 4567'} • <span style="color:#059669; font-weight:700;">Verified Student <span class="material-symbols-rounded filled" style="font-size:14px; vertical-align:middle; color:#059669;">verified</span></span>
        </div>

        <!-- Student ID Badge -->
        <div style="margin-top:6px; display:inline-flex; align-items:center; gap:6px; padding:3px 10px; background:#F1F5F9; border-radius:12px; font-size:11px; font-weight:700; color:#475569;">
          <span class="material-symbols-rounded" style="font-size:14px; color:#475569;">badge</span>
          <span>${user.studentId || ('EP-' + (user.phone ? user.phone.slice(-4) : '2026'))}</span>
        </div>

        <div style="margin-top:10px; padding:5px 12px; border-radius:20px; font-size:11px; font-weight:800; background: ${isStandalone ? '#ECFDF5' : '#FEF3C7'}; color: ${isStandalone ? '#047857' : '#B45309'}; border: 1px solid ${isStandalone ? '#A7F3D0' : '#FDE68A'};">
          ${isStandalone ? '<span class="material-symbols-rounded filled" style="font-size:14px; vertical-align:middle;">check_circle</span> iPhone Home Screen (PWA Standalone Mode)' : '<span class="material-symbols-rounded" style="font-size:14px; vertical-align:middle;">tab</span> Web Browser Mode'}
        </div>
      </div>

      <!-- 3-Item Stats Card (Credits, Approved, Pending) -->
      <div class="stats-trio-card">
        <div>
          <div class="stat-number" style="color:#F59E0B; display:flex; align-items:center; justify-content:center; gap:4px;">
            <span class="material-symbols-rounded filled" style="font-size:18px; color:#F59E0B;">star</span>
            <span>${creditsXP}</span>
          </div>
          <div class="stat-label">Credits (XP)</div>
        </div>
        <div class="stat-divider"></div>
        <div>
          <div class="stat-number" style="color:#10B981; display:flex; align-items:center; justify-content:center; gap:4px;">
            <span class="material-symbols-rounded filled" style="font-size:18px; color:#10B981;">check_circle</span>
            <span>${approvedCount}</span>
          </div>
          <div class="stat-label">Approved</div>
        </div>
        <div class="stat-divider"></div>
        <div>
          <div class="stat-number" style="color:#EA580C; display:flex; align-items:center; justify-content:center; gap:4px;">
            <span class="material-symbols-rounded filled" style="font-size:18px; color:#EA580C;">hourglass_top</span>
            <span>${pendingCount}</span>
          </div>
          <div class="stat-label">Pending</div>
        </div>
      </div>

      <!-- Target A/L Exam Batch Card (1:1 examYear parity) -->
      <div class="hero-card" style="padding:16px 18px; margin-top:14px;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="material-symbols-rounded" style="font-size:22px; color:#2563EB;">track_changes</span>
            <div>
              <div style="font-size:13.5px; font-weight:800; color:#0F172A;">Target Examination Batch</div>
              <div style="font-size:11px; color:#64748B;">Select your A/L year for countdown & papers</div>
            </div>
          </div>
          <span style="font-size:12px; font-weight:800; color:#2563EB; background:#EFF6FF; padding:4px 10px; border-radius:12px; border:1px solid #BFDBFE;" id="current-batch-badge">
            ${currentBatch}
          </span>
        </div>

        <div style="display:flex; gap:6px; flex-wrap:wrap;">
          ${examBatches.map(b => {
            const isSel = b === currentBatch;
            return `
              <button class="batch-select-chip ${isSel ? 'active' : ''}" data-target-batch="${b}" style="flex:1; min-width:64px; padding:8px 6px; border-radius:10px; border:1px solid ${isSel ? '#2563EB' : '#CBD5E1'}; background:${isSel ? '#2563EB' : '#F8FAFC'}; color:${isSel ? '#FFFFFF' : '#334155'}; font-size:11.5px; font-weight:700; cursor:pointer; transition:all 0.2s ease;">
                ${b}
              </button>
            `;
          }).join('')}
        </div>
      </div>

      <!-- Account Details Card -->
      <div class="hero-card" style="padding:14px 18px; margin-top:14px;">
        <div style="display:flex; align-items:center; justify-content:space-between; padding:8px 0; border-bottom:1px solid #E2E8F0;">
          <div style="display:flex; align-items:center; gap:8px; font-size:12.5px; font-weight:700; color:#334155;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#64748B;">school</span>
            <span>Role:</span>
          </div>
          <span style="font-size:12px; font-weight:800; color:#2563EB;">Student (A/L Physics & Dessert)</span>
        </div>
        <div style="display:flex; align-items:center; justify-content:space-between; padding:8px 0; border-bottom:1px solid #E2E8F0;">
          <div style="display:flex; align-items:center; gap:8px; font-size:12.5px; font-weight:700; color:#334155;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#64748B;">calendar_today</span>
            <span>Member Since:</span>
          </div>
          <span style="font-size:12px; font-weight:600; color:#64748B;">${memberSinceStr}</span>
        </div>
        <div style="display:flex; align-items:center; justify-content:space-between; padding:8px 0;">
          <div style="display:flex; align-items:center; gap:8px; font-size:12.5px; font-weight:700; color:#334155;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#64748B;">folder_special</span>
            <span>Total Submissions:</span>
          </div>
          <span style="font-size:12px; font-weight:800; color:#0F172A;">${totalCount} Problem Sets</span>
        </div>
      </div>

      <!-- Features & Preferences -->
      <div style="display:flex; flex-direction:column; gap:10px; margin-top:14px;">
        <!-- Trophy Room -->
        <button class="hero-card" style="padding:14px; flex-direction:row; align-items:center; justify-content:space-between; cursor:pointer;" id="btn-open-trophy-room">
          <div style="display:flex; align-items:center; gap:10px;">
            <span class="material-symbols-rounded filled" style="font-size:24px; color:#F59E0B;">emoji_events</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:800; color:#0F172A;">Trophy Room & Flex Zone</div>
              <div style="font-size:11px; color:#64748B;">View 8 Unlockable Badges & Achievements</div>
            </div>
          </div>
          <span class="material-symbols-rounded" style="color:#64748B; font-size:20px;">chevron_right</span>
        </button>

        <!-- Dark Mode Toggle -->
        <div class="hero-card" style="padding:14px; flex-direction:row; align-items:center; justify-content:space-between;">
          <div style="display:flex; align-items:center; gap:10px;">
            <span class="material-symbols-rounded" style="font-size:22px; color:#64748B;">dark_mode</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:800; color:#0F172A;">Cyber Midnight Dark Mode</div>
              <div style="font-size:11px; color:#64748B;">Switch between Frost White & Dark</div>
            </div>
          </div>
          <input type="checkbox" id="chk-dark-mode" ${isDark ? 'checked' : ''} style="width:20px; height:20px; accent-color:#2563EB; cursor:pointer;" />
        </div>

        <!-- Push Notifications Center -->
        <button class="hero-card" style="padding:14px; flex-direction:row; align-items:center; justify-content:space-between; cursor:pointer;" id="btn-profile-notifs">
          <div style="display:flex; align-items:center; gap:10px;">
            <span class="material-symbols-rounded" style="font-size:22px; color:#2563EB;">notifications</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:800; color:#0F172A;">Web Push Notifications</div>
              <div style="font-size:11px; color:#64748B;">Test Alert Banners & Audio Chime</div>
            </div>
          </div>
          <span class="material-symbols-rounded" style="color:#64748B; font-size:20px;">chevron_right</span>
        </button>


        ${this.currentUser?.role === 'admin' && this.currentMode === 'student' ? `
          <button class="btn-primary" style="margin-top:6px; display:inline-flex; align-items:center; justify-content:center; gap:8px;" id="btn-profile-admin-dashboard">
            <span class="material-symbols-rounded" style="font-size:18px;">admin_panel_settings</span>
            <span>Back to Admin Dashboard</span>
          </button>
        ` : ''}
        <!-- Sign Out Button -->
        <button class="btn-primary" style="background:#EF4444; margin-top:6px; display:inline-flex; align-items:center; justify-content:center; gap:8px;" id="btn-profile-logout">
          <span class="material-symbols-rounded" style="font-size:18px;">logout</span>
          <span>Sign Out</span>
        </button>
      </div>
    `;

    // Event Listeners for Profile Tab
    document.getElementById('btn-open-trophy-room')?.addEventListener('click', () => {
      this.openTrophyRoomModal();
    });

    document.getElementById('btn-edit-student-name')?.addEventListener('click', () => {
      this.openEditNameDialog(container);
    });

    document.getElementById('btn-change-avatar')?.addEventListener('click', () => {
      this.openAvatarPickerSheet(container);
    });

    // Target Batch Switchers
    container.querySelectorAll('[data-target-batch]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const newBatch = btn.dataset.targetBatch;
        if (newBatch === user.examYear) return;
        await authService.updateProfile({ examYear: newBatch });
        if (this.currentUser) this.currentUser.examYear = newBatch;
        notificationService.showInAppBanner('Exam Batch Updated', `Switched to ${newBatch} curriculum & countdown!`, 'success');
        this.renderProfileScreen(container);
      });
    });

    document.getElementById('chk-dark-mode')?.addEventListener('change', (e) => {
      const dark = e.target.checked;
      document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
      localStorage.setItem('edupeak_theme', dark ? 'dark' : 'light');
    });

    document.getElementById('btn-profile-notifs')?.addEventListener('click', () => {
      this.openNotificationCenter();
    });


    document.getElementById('btn-profile-admin-dashboard')?.addEventListener('click', () => {
      this.returnToAdminDashboard();
    });

    document.getElementById('btn-profile-logout')?.addEventListener('click', () => {
      this.confirmLogout();
    });
  }

  // ── Avatar Picker Bottom Sheet (1:1 student_profile_screen.dart parity) ────
  openAvatarPickerSheet(profileContainer) {
    const user = this.currentUser || {};
    const presets = [
      { name: 'Albert Einstein', role: 'Relativity', url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=240' },
      { name: 'Isaac Newton', role: 'Mechanics', url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=240' },
      { name: 'Nikola Tesla', role: 'Electricity', url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=240' },
      { name: 'Marie Curie', role: 'Nuclear', url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=240' },
      { name: 'Richard Feynman', role: 'Quantum', url: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=240' },
      { name: 'Pastry Prodigy', role: 'Dessert Master', url: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=240' }
    ];

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';
    modal.innerHTML = `
      <div class="modal-sheet" style="max-height:92vh; overflow-y:auto;">
        <!-- Drag pill -->
        <div style="width:36px; height:4px; background:#CBD5E1; border-radius:2px; margin:0 auto 12px auto;"></div>

        <div class="modal-header">
          <div>
            <h3 class="modal-title">Change Profile Photo</h3>
            <div style="font-size:11.5px; color:#64748B;">Upload your portrait or choose a Physics genius</div>
          </div>
          <button class="modal-close-btn" id="btn-close-avatar-sheet">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <!-- Action Row (Camera vs Gallery) -->
        <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:12px;">
          <!-- Camera Capture Button -->
          <button id="btn-snap-camera-avatar" style="display:flex; flex-direction:column; align-items:center; justify-content:center; gap:8px; padding:16px 12px; background:#EFF6FF; border:1px solid #BFDBFE; border-radius:14px; cursor:pointer;">
            <span class="material-symbols-rounded" style="font-size:26px; color:#1D4ED8;">photo_camera</span>
            <span style="font-size:12.5px; font-weight:800; color:#1D4ED8;">Take Photo (Camera)</span>
          </button>

          <!-- Gallery Upload Button -->
          <label for="input-gallery-avatar" style="display:flex; flex-direction:column; align-items:center; justify-content:center; gap:8px; padding:16px 12px; background:#F0FDF4; border:1px solid #BBF7D0; border-radius:14px; cursor:pointer;">
            <span class="material-symbols-rounded" style="font-size:26px; color:#15803D;">photo_library</span>
            <span style="font-size:12.5px; font-weight:800; color:#15803D;">Choose from Gallery</span>
            <input type="file" id="input-gallery-avatar" accept="image/*" style="display:none;" />
          </label>
        </div>

        <!-- Hidden Camera Stream Preview -->
        <div id="avatar-camera-container" style="display:none; flex-direction:column; align-items:center; margin-top:14px; background:#0F172A; border-radius:16px; padding:12px;">
          <video id="avatar-webcam-preview" autoplay playsinline style="width:200px; height:200px; border-radius:50%; object-fit:cover; border:3px solid #2563EB;"></video>
          <div style="display:flex; gap:10px; margin-top:12px;">
            <button id="btn-capture-snapshot" class="apk-btn-primary" style="padding:8px 18px; font-size:12px; display:inline-flex; align-items:center; gap:6px;">
              <span class="material-symbols-rounded" style="font-size:16px;">photo_camera</span>
              <span>Capture Snapshot</span>
            </button>
            <button id="btn-cancel-webcam" style="background:transparent; border:1px solid #475569; color:#CBD5E1; border-radius:8px; padding:8px 14px; font-size:12px; cursor:pointer;">
              Cancel
            </button>
          </div>
        </div>

        <!-- Presets Row -->
        <div style="margin-top:18px;">
          <div style="display:flex; align-items:center; gap:6px; font-size:12px; font-weight:800; color:#334155; margin-bottom:8px;">
            <span class="material-symbols-rounded" style="font-size:16px; color:#2563EB;">science</span>
            <span>Or Choose a Physics Scholar Avatar:</span>
          </div>
          <div style="display:grid; grid-template-columns: repeat(3, 1fr); gap:10px;">
            ${presets.map((p, idx) => `
              <div class="preset-avatar-card" data-preset-idx="${idx}" style="display:flex; flex-direction:column; align-items:center; text-align:center; padding:10px; background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; cursor:pointer; transition:all 0.2s ease;">
                <img src="${p.url}" style="width:52px; height:52px; border-radius:50%; object-fit:cover; border:2px solid #CBD5E1;" />
                <div style="font-size:11px; font-weight:800; color:#0F172A; margin-top:6px;">${p.name}</div>
                <div style="font-size:9.5px; color:#64748B;">${p.role}</div>
              </div>
            `).join('')}
          </div>
        </div>

        <!-- Direct URL Option -->
        <div style="margin-top:16px; padding-top:14px; border-top:1px solid #E2E8F0;">
          <div style="font-size:11.5px; font-weight:700; color:#475569; margin-bottom:6px;">Custom Image Web Link:</div>
          <div style="display:flex; gap:8px;">
            <input type="url" id="input-avatar-url" placeholder="https://..." value="${user.avatarUrl || ''}" class="form-textarea" style="height:38px; margin:0;" />
            <button id="btn-save-avatar-url" class="apk-btn-primary" style="width:auto; padding:0 16px; font-size:12px;">Save</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    let activeStream = null;

    const stopWebcam = () => {
      if (activeStream) {
        activeStream.getTracks().forEach(t => t.stop());
        activeStream = null;
      }
      const camCont = modal.querySelector('#avatar-camera-container');
      if (camCont) camCont.style.display = 'none';
    };

    const saveAndClose = async (newUrl) => {
      stopWebcam();
      await authService.updateProfile({ avatarUrl: newUrl });
      if (this.currentUser) this.currentUser.avatarUrl = newUrl;
      notificationService.showInAppBanner('Profile Photo Updated!', 'Your portrait is now updated across all portals.', 'success');
      modal.remove();
      if (profileContainer) this.renderProfileScreen(profileContainer);
    };

    modal.querySelector('#btn-close-avatar-sheet')?.addEventListener('click', () => {
      stopWebcam();
      modal.remove();
    });

    // Preset Selection
    modal.querySelectorAll('[data-preset-idx]').forEach(card => {
      card.addEventListener('click', () => {
        const p = presets[Number(card.dataset.presetIdx)];
        if (p) saveAndClose(p.url);
      });
    });

    // Gallery File Upload (Reads as Base64 Data URL)
    modal.querySelector('#input-gallery-avatar')?.addEventListener('change', (e) => {
      const file = e.target.files?.[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (re) => {
          saveAndClose(re.target.result);
        };
        reader.readAsDataURL(file);
      }
    });

    // Camera Capture
    modal.querySelector('#btn-snap-camera-avatar')?.addEventListener('click', async () => {
      try {
        const camCont = modal.querySelector('#avatar-camera-container');
        const videoEl = modal.querySelector('#avatar-webcam-preview');
        activeStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: false });
        if (videoEl && activeStream) {
          videoEl.srcObject = activeStream;
          videoEl.play().catch(() => {});
          camCont.style.display = 'flex';
        }
      } catch (err) {
        alert('Could not access camera: ' + err.message);
      }
    });

    modal.querySelector('#btn-cancel-webcam')?.addEventListener('click', () => {
      stopWebcam();
    });

    modal.querySelector('#btn-capture-snapshot')?.addEventListener('click', () => {
      const videoEl = modal.querySelector('#avatar-webcam-preview');
      if (!videoEl) return;
      const canvas = document.createElement('canvas');
      canvas.width = 400;
      canvas.height = 400;
      const ctx = canvas.getContext('2d');
      // Draw centered square crop
      const minDim = Math.min(videoEl.videoWidth || 400, videoEl.videoHeight || 400);
      const startX = ((videoEl.videoWidth || 400) - minDim) / 2;
      const startY = ((videoEl.videoHeight || 400) - minDim) / 2;
      ctx.drawImage(videoEl, startX, startY, minDim, minDim, 0, 0, 400, 400);
      const dataUrl = canvas.toDataURL('image/jpeg', 0.85);
      saveAndClose(dataUrl);
    });

    // Custom URL
    modal.querySelector('#btn-save-avatar-url')?.addEventListener('click', () => {
      const url = modal.querySelector('#input-avatar-url')?.value.trim();
      if (url) saveAndClose(url);
    });
  }

  // ── Edit Name Dialog (Matching _showEditNameDialog in Flutter) ────────────
  openEditNameDialog(profileContainer) {
    const currentName = this.currentUser?.name || 'Kasun Perera';

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';
    modal.innerHTML = `
      <div class="modal-sheet" style="max-width:380px;">
        <div class="modal-header">
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="material-symbols-rounded" style="font-size:20px; color:#2563EB;">edit</span>
            <div>
              <h3 class="modal-title">Edit Name</h3>
              <div style="font-size:11px; color:#64748B;">සම්පූර්ණ නම සංස්කරණය කරන්න</div>
            </div>
          </div>
          <button class="modal-close-btn" id="btn-close-name-modal">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="margin-top:14px;">
          <label style="font-size:11.5px; font-weight:700; color:#334155; display:block; margin-bottom:6px;">Full Name (ශිෂ්‍යයාගේ නම)</label>
          <input type="text" id="input-new-student-name" class="form-textarea" style="height:42px; font-size:14px; font-weight:600;" value="${currentName}" placeholder="Enter full name" />
        </div>

        <div style="display:flex; justify-content:flex-end; gap:8px; margin-top:16px;">
          <button id="btn-cancel-edit-name" style="background:transparent; border:none; color:#64748B; font-size:13px; font-weight:700; padding:8px 14px; cursor:pointer;">
            Cancel
          </button>
          <button id="btn-save-student-name" class="apk-btn-primary" style="width:auto; padding:8px 20px; font-size:13px;">
            Save Name
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modal.querySelector('#btn-close-name-modal')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#btn-cancel-edit-name')?.addEventListener('click', () => modal.remove());

    modal.querySelector('#btn-save-student-name')?.addEventListener('click', async () => {
      const newName = modal.querySelector('#input-new-student-name')?.value.trim();
      if (!newName) {
        alert('Please enter a valid name.');
        return;
      }

      await authService.updateProfile({ name: newName });
      if (this.currentUser) this.currentUser.name = newName;
      notificationService.showInAppBanner('Name Updated', `Profile name updated to ${newName}!`, 'success');
      modal.remove();
      if (profileContainer) this.renderProfileScreen(profileContainer);
    });
  }

  // ── Dessert Detail Modal ──────────────────────────────────────────────────
  async openDessertDetailModal(dessertId) {
    const user = this.currentUser || {};
    const desserts = await dbService.getStudentDesserts(user.uid || user.id, user.phone);
    const d = desserts.find(x => x.id === dessertId) || desserts[0];
    if (!d) return;

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title" style="display:flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded">folder_special</span>
            <span>Submission Details</span>
          </h3>
          <button class="modal-close-btn" id="btn-close-detail">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="font-size:15px; font-weight:800; color:#0F172A; margin-bottom:4px;">${d.subject}</div>
        <div style="font-size:12px; color:#64748B; margin-bottom:12px;">Submitted on ${new Date(d.submittedAt || Date.now()).toLocaleDateString()}</div>

        <div style="display:flex; gap:10px; overflow-x:auto; margin-bottom:14px; padding-bottom:4px;">
          ${(d.mediaUrls || ['./icons/exam_3d_countdown.jpg']).map(url => `
            <img src="${url}" style="width:140px; height:180px; object-fit:cover; border-radius:12px; border:1px solid #CBD5E1; box-shadow:0 4px 10px rgba(0,0,0,0.1);" />
          `).join('')}
        </div>

        <div style="background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; padding:12px; margin-bottom:12px;">
          <div style="font-size:11px; font-weight:800; color:#475569;">STUDENT REMARKS:</div>
          <div style="font-size:12.5px; color:#1E293B; margin-top:2px;">${d.caption || 'No extra note provided.'}</div>
        </div>

        ${d.adminFeedback ? `
          <div style="background:#EFF6FF; border:1px solid #BFDBFE; border-radius:12px; padding:12px; margin-bottom:12px;">
            <div style="font-size:11px; font-weight:800; color:#1D4ED8;">TEACHER EVALUATION & FEEDBACK:</div>
            <div style="font-size:12.5px; color:#1E3A8A; margin-top:2px; line-height:1.45;">${d.adminFeedback}</div>
          </div>
        ` : ''}

        <button class="btn-primary" id="btn-done-detail">Done</button>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-detail')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-done-detail')?.addEventListener('click', () => modal.remove());
  }

  // ── Admin Review Modal (Mock Teacher Console) ─────────────────────────────
  openMockTeacherConsoleModal() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title" style="display:flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded filled" style="color:#2563EB;">admin_panel_settings</span>
            <span>Teacher / Admin Console</span>
          </h3>
          <button class="modal-close-btn" id="btn-close-admin">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>
        <div style="font-size:13px; color:#475569; line-height:1.5; margin-bottom:14px;">
          Welcome to the Teacher portal. Here you can grade submitted physics problem sets, set exam timers, and schedule new paper sessions.
        </div>
        <div style="display:flex; flex-direction:column; gap:8px;">
          <button class="btn-primary" style="background:#059669; display:inline-flex; align-items:center; justify-content:center; gap:6px;" onclick="alert('Grading sheet loaded. 5 pending submissions marked as Approved (+100 XP).'); modal.remove();">
            <span class="material-symbols-rounded filled" style="font-size:16px;">check_circle</span>
            <span>Approve All Pending Submissions (+100 XP)</span>
          </button>
          <button class="btn-primary" style="background:#2563EB; display:inline-flex; align-items:center; justify-content:center; gap:6px;" onclick="alert('New exam paper created for 2027 A/L batch.'); modal.remove();">
            <span class="material-symbols-rounded" style="font-size:16px;">note_add</span>
            <span>Schedule New Model Paper</span>
          </button>
        </div>
      </div>
    `;
    document.body.appendChild(modal);
    document.getElementById('btn-close-admin')?.addEventListener('click', () => modal.remove());
  }

  // ── AI Tutor Inquiry Modal ───────────────────────────────────────────────
  openAiTutorDialog(initialTopic = 'Physics Doubt') {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title" style="display:flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded filled" style="color:#2563EB;">psychology</span>
            <span>AI Physics Tutor</span>
          </h3>
          <button class="modal-close-btn" id="btn-close-tutor-sheet">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="background:#EFF6FF; border:1px solid #DBEAFE; border-radius:14px; padding:12px; margin-bottom:14px;">
          <div style="font-size:12px; font-weight:800; color:#2563EB;">TOPIC: ${initialTopic}</div>
          <div style="font-size:12.5px; color:#1E3A8A; margin-top:4px; line-height:1.45;">
            "ආයුබෝවන්! මම ඔබගේ A/L භෞතික විද්‍යා AI උපදේශක. මෙම සංකල්පය පිළිබඳ ඔබේ ඕනෑම ගැටලුවක් මෙහි සටහන් කරන්න."
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">ඔබගේ ප්‍රශ්නය (Your Question)</label>
          <textarea class="form-textarea" rows="3" placeholder="උදා: රෝලරයක් තල්ලු කිරීමට වඩා ඇදීම පහසු ඇයි?"></textarea>
        </div>

        <button class="btn-primary" id="btn-send-tutor" style="display:inline-flex; align-items:center; justify-content:center; gap:6px;">
          <span class="material-symbols-rounded filled" style="font-size:16px;">bolt</span>
          <span>Ask Instant Explanation</span>
        </button>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-tutor-sheet')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-send-tutor')?.addEventListener('click', () => {
      alert('AI Tutor has analyzed your inquiry and sent the full structured derivation to your study dashboard!');
      modal.remove();
    });
  }

  // ── Daily MCQ Sprint Runner (Full 1:1 Android Parity) ─────────────────────
  async openSprintDialog() {
    let sprint;
    try {
      sprint = await dbService.getDailySprint(undefined, this.currentUser?.examYear);
    } catch (error) {
      console.error('[Sprint] Could not load the shared sprint:', error);
      alert('Could not load today’s sprint from the institute database. Please try again later.');
      return;
    }
    const questions = sprint?.questions || [];
    if (questions.length === 0) {
      alert('There is no sprint published for your batch today.');
      return;
    }
    let currentIdx = 0;
    let selectedAnswers = {};
    let elapsedSeconds = 0;
    let timer = null;

    const modal = document.createElement('div');
    modal.className = 'app-modal';

    const renderQuestion = () => {
      const q = questions[currentIdx];
      const selected = selectedAnswers[currentIdx];

      modal.innerHTML = `
        <div class="modal-sheet" style="max-height:92vh;">
          <div class="modal-header">
            <div style="display:flex; align-items:center; gap:8px;">
              <span class="material-symbols-rounded filled" style="font-size:22px; color:#EA580C;">local_fire_department</span>
              <div>
                <h3 class="modal-title">Daily MCQ Sprint</h3>
                <div style="font-size:11px; color:#64748B;">A/L Physics • දවසේ MCQ 5</div>
              </div>
            </div>
            <button class="modal-close-btn" id="btn-close-sprint">
              <span class="material-symbols-rounded">close</span>
            </button>
          </div>

          <!-- Stepper and Timer Bar -->
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
            <div style="display:flex; gap:6px;">
              ${questions.map((_, i) => `
                <div class="sprint-step-dot ${i === currentIdx ? 'active' : selectedAnswers[i] !== undefined ? 'done' : ''}">
                  ${i + 1}
                </div>
              `).join('')}
            </div>
            <div class="stopwatch-pill">
              <span class="material-symbols-rounded" style="font-size:15px;">timer</span>
              <span id="sprint-timer-val">${Math.floor(elapsedSeconds / 60).toString().padStart(2, '0')}:${(elapsedSeconds % 60).toString().padStart(2, '0')}</span>
            </div>
          </div>

          <!-- Question Text -->
          <div style="font-size:14px; font-weight:800; color:#0F172A; line-height:1.5; margin-bottom:14px; background:#F8FAFC; padding:14px; border-radius:14px; border:1px solid #E2E8F0;">
            ${q.question || q.text || ''}
          </div>

          <!-- Options -->
          <div style="display:flex; flex-direction:column; gap:8px; margin-bottom:14px;">
            ${q.options.map((opt, i) => `
              <div class="mcq-choice-btn ${selected === i ? 'selected' : ''}" data-opt-idx="${i}">
                <div class="mcq-choice-index">${String.fromCharCode(65 + i)}</div>
                <span>${opt}</span>
              </div>
            `).join('')}
          </div>

          <!-- Explanation Box if answered -->
          ${selected !== undefined ? `
            <div style="background:#EFF6FF; border-left:3px solid #2563EB; border-radius:10px; padding:12px; margin-bottom:14px; font-size:12px; color:#1E3A8A; line-height:1.45;">
              <strong style="display:inline-flex; align-items:center; gap:4px;"><span class="material-symbols-rounded" style="font-size:15px; color:#2563EB;">lightbulb</span> විවරණය (Explanation):</strong><br>
              ${q.explanation}
            </div>
          ` : ''}

          <!-- Navigation Buttons -->
          <div style="display:flex; gap:8px;">
            ${currentIdx > 0 ? `
              <button class="btn-primary" style="background:#F1F5F9; color:#475569; width:auto; padding:12px 18px; display:inline-flex; align-items:center; gap:4px;" id="btn-sprint-prev">
                <span class="material-symbols-rounded" style="font-size:16px;">arrow_back</span>
                <span>Prev</span>
              </button>
            ` : ''}

            <button class="btn-primary" style="flex:1; display:inline-flex; align-items:center; justify-content:center; gap:6px;" id="btn-sprint-next">
              <span>${currentIdx === questions.length - 1 ? 'Finish Sprint' : 'Next Question'}</span>
              <span class="material-symbols-rounded" style="font-size:16px;">${currentIdx === questions.length - 1 ? 'check' : 'arrow_forward'}</span>
            </button>
          </div>
        </div>
      `;

      // Option selection
      modal.querySelectorAll('.mcq-choice-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          selectedAnswers[currentIdx] = Number(btn.dataset.optIdx);
          renderQuestion();
        });
      });

      document.getElementById('btn-close-sprint')?.addEventListener('click', () => {
        clearInterval(timer);
        modal.remove();
      });

      document.getElementById('btn-sprint-prev')?.addEventListener('click', () => {
        currentIdx--;
        renderQuestion();
      });

      document.getElementById('btn-sprint-next')?.addEventListener('click', async () => {
        if (selectedAnswers[currentIdx] === undefined) {
          alert('Please select an option before continuing.');
          return;
        }

        if (currentIdx < questions.length - 1) {
          currentIdx++;
          renderQuestion();
        } else {
          // Finished!
          clearInterval(timer);
          let correct = 0;
          questions.forEach((qu, idx) => {
            if (selectedAnswers[idx] === qu.correctIndex) correct++;
          });

          let xpEarned = 0;
          const timeFormatted = `${Math.floor(elapsedSeconds / 60)}m ${elapsedSeconds % 60}s`;
          let isPerfect = correct === questions.length;

          // 1. Record Attempt in Firestore
          try {
            const result = await dbService.recordSprintAttempt({
              date: sprint.targetDate || new Date().toISOString().split('T')[0],
              timeTakenSeconds: elapsedSeconds,
              answers: selectedAnswers
            });
            correct = result.score;
            xpEarned = result.xpEarned;
            isPerfect = correct === questions.length;
          } catch (error) {
            console.error('[Sprint] Attempt could not be saved:', error);
            alert('Your sprint result could not be saved to the institute database. Please try again.');
            return;
          }

          notificationService.showInAppBanner(
            isPerfect ? 'PERFECT SCORE!' : 'Sprint Complete!',
            `You scored ${correct}/${questions.length}. +${xpEarned} XP earned.`,
            'success'
          );

          // 3. Render 1:1 Completed Review View matching _buildCompletedReviewView in Flutter
          modal.innerHTML = `
            <div class="modal-sheet" style="max-height:92vh; overflow-y:auto; padding:20px 16px;">
              <!-- Celebration Card -->
              <div style="background:${isPerfect ? 'linear-gradient(135deg, #065F46, #047857)' : 'linear-gradient(135deg, #1E3A8A, #2563EB)'}; border-radius:20px; padding:20px; text-align:center; color:#FFFFFF; box-shadow:0 10px 24px rgba(0,0,0,0.25);">
                <div style="font-size:14px; font-weight:800; letter-spacing:0.5px; opacity:0.9; display:flex; align-items:center; justify-content:center; gap:6px;">
                  ${isPerfect ? '<span class="material-symbols-rounded filled" style="font-size:20px; color:#FDE047;">emoji_events</span> PERFECT SCORE!' : '<span class="material-symbols-rounded filled" style="font-size:20px; color:#FDE047;">local_fire_department</span> SPRINT COMPLETED!'}
                </div>
                <div style="display:flex; align-items:baseline; justify-content:center; gap:4px; margin:8px 0 10px 0;">
                  <span style="font-size:48px; font-weight:900; line-height:1;">${correct}</span>
                  <span style="font-size:20px; font-weight:700; opacity:0.75;">/ ${questions.length}</span>
                </div>
                <div style="display:flex; flex-wrap:wrap; justify-content:center; gap:6px;">
                  <span style="background:rgba(255,255,255,0.18); padding:4px 10px; border-radius:12px; font-size:11px; font-weight:700; display:inline-flex; align-items:center; gap:4px;">
                    <span class="material-symbols-rounded" style="font-size:13px;">timer</span> Time: ${timeFormatted}
                  </span>
                  <span style="background:rgba(251,191,36,0.3); color:#FEF3C7; padding:4px 10px; border-radius:12px; font-size:11px; font-weight:800; display:inline-flex; align-items:center; gap:4px;">
                    <span class="material-symbols-rounded filled" style="font-size:13px; color:#F59E0B;">bolt</span> +${xpEarned} XP earned
                  </span>
                  <span style="background:rgba(255,255,255,0.18); padding:4px 10px; border-radius:12px; font-size:11px; font-weight:700; display:inline-flex; align-items:center; gap:4px;">
                    <span class="material-symbols-rounded" style="font-size:13px;">menu_book</span> Mechanics & Newton Laws
                  </span>
                </div>
              </div>

              <!-- Review Header -->
              <div style="display:flex; justify-content:space-between; align-items:center; margin:18px 0 10px 0;">
                <div style="font-size:14px; font-weight:800; color:#0F172A;">
                  Question Review & Explanations (විවරණ)
                </div>
                <button id="btn-sprint-view-ranks" style="background:none; border:none; color:#2563EB; font-size:12px; font-weight:700; cursor:pointer; display:inline-flex; align-items:center; gap:4px;">
                  <span>View Ranks</span>
                  <span class="material-symbols-rounded filled" style="font-size:14px; color:#2563EB;">emoji_events</span>
                </button>
              </div>

              <!-- Question by Question Review List -->
              <div style="display:flex; flex-direction:column; gap:12px; margin-bottom:16px;">
                ${questions.map((qu, qIdx) => {
                  const studentChoice = selectedAnswers[qIdx];
                  const isCorrect = studentChoice === qu.correctIndex;
                  return `
                    <div style="background:#FFFFFF; border:1.5px solid ${isCorrect ? '#22C55E' : '#EF4444'}; border-radius:14px; padding:14px;">
                      <div style="display:flex; align-items:center; gap:8px; margin-bottom:8px;">
                        <span style="background:${isCorrect ? '#DCFCE7' : '#FEE2E2'}; color:${isCorrect ? '#15803D' : '#B91C1C'}; padding:2px 8px; border-radius:6px; font-size:11px; font-weight:800;">
                          Q${qIdx + 1}
                        </span>
                        <span style="font-size:11.5px; font-weight:800; color:${isCorrect ? '#15803D' : '#B91C1C'}; display:inline-flex; align-items:center; gap:4px;">
                          <span class="material-symbols-rounded filled" style="font-size:14px;">${isCorrect ? 'check_circle' : 'cancel'}</span>
                          <span>${isCorrect ? 'Correct (+10 XP)' : 'Incorrect (0 XP)'}</span>
                        </span>
                      </div>

                      <div style="font-size:13px; font-weight:700; color:#0F172A; line-height:1.45; margin-bottom:10px;">
                        ${qu.text}
                      </div>

                      <!-- Options List -->
                      <div style="display:flex; flex-direction:column; gap:6px; margin-bottom:10px;">
                        ${qu.options.map((opt, optIdx) => {
                          const isAnswer = optIdx === qu.correctIndex;
                          const isPicked = optIdx === studentChoice;
                          let bg = '#F8FAFC';
                          let border = '#E2E8F0';
                          let color = '#475569';
                          if (isAnswer) {
                            bg = '#F0FDF4';
                            border = '#22C55E';
                            color = '#15803D';
                          } else if (isPicked && !isAnswer) {
                            bg = '#FEF2F2';
                            border = '#EF4444';
                            color = '#B91C1C';
                          }
                          return `
                            <div style="display:flex; align-items:center; justify-content:space-between; background:${bg}; border:1px solid ${border}; border-radius:8px; padding:7px 10px; font-size:12px; color:${color}; font-weight:${isAnswer ? '700' : '500'};">
                              <span>(${String.fromCharCode(65 + optIdx)}) ${opt}</span>
                              ${isAnswer ? '<span style="color:#22C55E; font-weight:800; display:inline-flex; align-items:center; gap:2px;"><span class="material-symbols-rounded filled" style="font-size:13px;">check_circle</span> Correct</span>' : (isPicked ? '<span style="color:#EF4444; font-weight:800; display:inline-flex; align-items:center; gap:2px;"><span class="material-symbols-rounded filled" style="font-size:13px;">cancel</span> Your Choice</span>' : '')}
                            </div>
                          `;
                        }).join('')}
                      </div>

                      <!-- Amber Explanation Box (විවරණය) -->
                      <div style="background:#FFFBEB; border-left:3px solid #F59E0B; border-radius:8px; padding:10px; font-size:11.5px; color:#92400E; line-height:1.45;">
                        <strong style="display:inline-flex; align-items:center; gap:4px;"><span class="material-symbols-rounded" style="font-size:14px; color:#F59E0B;">lightbulb</span> විවරණය (Explanation):</strong><br>
                        ${qu.explanation}
                      </div>
                    </div>
                  `;
                }).join('')}
              </div>

              <!-- Bottom Actions -->
              <div style="display:flex; gap:8px;">
                <button class="btn-primary" id="btn-finish-sprint-sheet" style="flex:1;">
                  Back to Dashboard
                </button>
              </div>
            </div>
          `;

          document.getElementById('btn-finish-sprint-sheet')?.addEventListener('click', () => {
            modal.remove();
          });

          document.getElementById('btn-sprint-view-ranks')?.addEventListener('click', () => {
            modal.remove();
            this.switchTab('ranks');
          });
        }
      });
    };

    timer = setInterval(() => {
      elapsedSeconds++;
      const tEl = document.getElementById('sprint-timer-val');
      if (tEl) {
        tEl.textContent = `${Math.floor(elapsedSeconds / 60).toString().padStart(2, '0')}:${(elapsedSeconds % 60).toString().padStart(2, '0')}`;
      }
    }, 1000);

    document.body.appendChild(modal);
    renderQuestion();
  }

  // ── Camera Document Scanner Flow (Full iOS Match) ─────────────────────────
  openDocumentScanner() {
    cameraService.clearPages();

    const modal = document.createElement('div');
    modal.className = 'scanner-modal';
    modal.id = 'camera-scanner-modal';

    modal.innerHTML = `
      <div class="scanner-top-bar">
        <div class="scanner-title">
          <span style="display:inline-flex; align-items:center; gap:6px;"><span class="material-symbols-rounded">document_scanner</span> Scan Homework</span>
          <span class="scanner-page-counter" id="scanner-page-count">0 Pages</span>
        </div>
        <div class="scanner-top-actions">
          <button class="btn-scanner-icon" id="btn-toggle-torch" title="Flashlight" style="display:inline-flex; align-items:center; justify-content:center;">
            <span class="material-symbols-rounded" style="font-size:18px;">flash_on</span>
          </button>
          <button class="btn-scanner-icon" id="btn-close-scanner" title="Close" style="display:inline-flex; align-items:center; justify-content:center;">
            <span class="material-symbols-rounded" style="font-size:20px;">close</span>
          </button>
        </div>
      </div>

      <div class="scanner-viewfinder-container">
        <video class="scanner-video" id="scanner-live-video" autoplay playsinline muted></video>
        <div class="scanner-frame-overlay">
          <div class="scanner-laser"></div>
          <span class="scanner-hint-text">Align document within the frame</span>
        </div>
        <div class="scanner-flash-overlay" id="scanner-flash"></div>
      </div>

      <div class="scanner-filter-bar">
        <button class="filter-pill active" data-filter="none">Natural</button>
        <button class="filter-pill" data-filter="document">Enhance</button>
        <button class="filter-pill" data-filter="bw">B&W</button>
      </div>

      <div class="scanner-bottom-bar">
        <div class="scanner-thumbnails-strip" id="scanner-thumb-strip"></div>
        <div class="scanner-shutter-row">
          <label class="btn-upload-file-fallback" for="input-file-camera">
            <span style="display:inline-flex; align-items:center; gap:4px;"><span class="material-symbols-rounded" style="font-size:18px;">photo_library</span> Gallery</span>
            <input type="file" id="input-file-camera" accept="image/*" capture="environment" style="display:none;" multiple />
          </label>

          <div class="shutter-btn-wrap">
            <div class="shutter-outer-ring"></div>
            <button class="btn-shutter" id="btn-trigger-shutter"></button>
          </div>

          <button class="btn-done-scanning" id="btn-finish-scan" disabled style="display:inline-flex; align-items:center; justify-content:center; gap:4px;">
            <span>Done</span>
            <span class="material-symbols-rounded" style="font-size:16px;">check</span>
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    const videoEl = document.getElementById('scanner-live-video');
    let currentFilter = 'none';

    cameraService.startCamera(videoEl, 'environment').catch(err => {
      console.warn('[Camera] Notice:', err.message);
    });

    document.getElementById('btn-toggle-torch')?.addEventListener('click', async () => {
      const active = await cameraService.toggleTorch();
      document.getElementById('btn-toggle-torch')?.classList.toggle('active', active);
    });

    modal.querySelectorAll('.filter-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        modal.querySelectorAll('.filter-pill').forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        currentFilter = pill.dataset.filter;
      });
    });

    const updateThumbnails = () => {
      const pages = cameraService.getPages();
      const countEl = document.getElementById('scanner-page-count');
      const stripEl = document.getElementById('scanner-thumb-strip');
      const doneBtn = document.getElementById('btn-finish-scan');

      if (countEl) countEl.textContent = `${pages.length} Pages`;
      if (doneBtn) doneBtn.disabled = pages.length === 0;

      if (stripEl) {
        stripEl.innerHTML = pages.map((dataUrl, idx) => `
          <div class="thumb-card">
            <img src="${dataUrl}"/>
            <button class="thumb-del-btn" data-del-idx="${idx}" style="display:inline-flex; align-items:center; justify-content:center;">
              <span class="material-symbols-rounded" style="font-size:12px;">close</span>
            </button>
            <span class="thumb-page-badge">P${idx + 1}</span>
          </div>
        `).join('');

        stripEl.querySelectorAll('.thumb-del-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            cameraService.removePage(Number(btn.dataset.delIdx));
            updateThumbnails();
          });
        });
      }
    };

    document.getElementById('btn-trigger-shutter')?.addEventListener('click', () => {
      try {
        const flash = document.getElementById('scanner-flash');
        if (flash) {
          flash.classList.add('flashing');
          setTimeout(() => flash.classList.remove('flashing'), 140);
        }
        cameraService.capturePhoto(currentFilter);
        updateThumbnails();
      } catch (e) {
        alert(e.message);
      }
    });

    document.getElementById('input-file-camera')?.addEventListener('change', (e) => {
      const files = e.target.files;
      if (!files) return;
      Array.from(files).forEach(file => {
        const reader = new FileReader();
        reader.onload = (evt) => {
          cameraService.addPageFromDataUrl(evt.target.result);
          updateThumbnails();
        };
        reader.readAsDataURL(file);
      });
    });

    const closeScanner = () => {
      cameraService.stopCamera();
      modal.remove();
    };

    document.getElementById('btn-close-scanner')?.addEventListener('click', closeScanner);

    document.getElementById('btn-finish-scan')?.addEventListener('click', () => {
      const pages = cameraService.getPages();
      if (pages.length === 0) return;
      closeScanner();
      this.openSubmitDessertDialog(pages);
    });
  }

  openSubmitDessertDialog(pages) {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title">Confirm Homework Submission</h3>
          <button class="modal-close-btn" id="btn-close-submit-dialog">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="font-size:12px; font-weight:700; color:#475569; margin-bottom:8px;">
          Scanned Pages (${pages.length}):
        </div>
        <div style="display:flex; gap:8px; overflow-x:auto; margin-bottom:14px;">
          ${pages.map(img => `<img src="${img}" style="width:48px; height:64px; object-fit:cover; border-radius:8px; border:1px solid #2563EB;" />`).join('')}
        </div>

        <div class="form-group">
          <label class="form-label">Topic / Unit</label>
          <input type="text" class="form-input" id="submit-topic-input" value="Mechanics: Circular & Gravitation" />
        </div>

        <div class="form-group">
          <label class="form-label">Note for Teacher</label>
          <textarea class="form-textarea" id="submit-note-input" rows="2" placeholder="Any questions or notes..."></textarea>
        </div>

        <button class="btn-primary" id="btn-confirm-upload" style="display:inline-flex; align-items:center; justify-content:center; gap:8px;">
          <span class="material-symbols-rounded filled" style="font-size:18px;">send</span>
          <span>Submit Homework Now (+50 XP)</span>
        </button>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-submit-dialog')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-confirm-upload')?.addEventListener('click', async () => {
      const btn = document.getElementById('btn-confirm-upload');
      btn.disabled = true;
      btn.innerHTML = '<span class="material-symbols-rounded filled" style="font-size:16px; vertical-align:middle; margin-right:4px;">hourglass_top</span>Uploading...';

      await dbService.submitDessert({
        studentId: this.currentUser.studentId || 'EP-2027',
        studentName: this.currentUser.name || 'ThiZaru',
        studentPhone: this.currentUser.phone || '0770557769',
        subject: document.getElementById('submit-topic-input')?.value,
        caption: document.getElementById('submit-note-input')?.value,
        mediaUrls: pages
      });

      modal.remove();
      notificationService.showInAppBanner('Homework Submitted!', 'Your teacher will review your submission and award marks.', 'success');
      this.switchTab('desserts');
    });
  }

  // ── Live Exam Room with Front-Camera Proctoring (1:1 Mobile Parity) ──
  openLiveExamRoom(paperId, slotId = 'slot1') {
    return this.openStudentLiveExamRoom(paperId, slotId);
  }

  handleExamTabSwitch() {
    this.antiCheatViolations++;
    const modal = document.createElement('div');
    modal.className = 'anti-cheat-modal';
    modal.innerHTML = `
      <div class="anti-cheat-card">
        <div class="anti-cheat-icon">
          <span class="material-symbols-rounded filled" style="font-size:36px; color:#EF4444;">warning</span>
        </div>
        <h3 class="anti-cheat-title">Anti-Cheat Alert</h3>
        <p class="anti-cheat-msg">
          Minimizing or switching away from the proctored exam is strictly prohibited! (Violation ${this.antiCheatViolations}/3)
        </p>
        <button class="btn-anti-cheat-dismiss" id="btn-anti-cheat-ack">Return to Exam</button>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-anti-cheat-ack')?.addEventListener('click', () => modal.remove());
  }

  // ── Push Notification Center Modal ────────────────────────────────────────
  openNotificationCenter() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title" style="display:flex; align-items:center; gap:8px;">
            <span class="material-symbols-rounded filled" style="font-size:22px; color:#6366F1;">notifications</span>
            <span>Notification Center</span>
          </h3>
          <button class="modal-close-btn" id="btn-close-notif-sheet">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="font-size:13px; color:#475569; line-height:1.5; margin-bottom:14px;">
          iOS 16.4+ Web Push sends real-time alerts directly to your iPhone lock screen when new papers are scheduled or homework is marked.
        </div>

        <button class="btn-primary" id="btn-req-push-perm" style="margin-bottom:10px;">
          Enable System Push Notifications
        </button>

        <button class="btn-primary" id="btn-send-test-push" style="background:#059669; display:inline-flex; align-items:center; justify-content:center; gap:6px;">
          <span class="material-symbols-rounded filled" style="font-size:16px;">flash_on</span>
          <span>Send Test Push Notification</span>
        </button>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-notif-sheet')?.addEventListener('click', () => modal.remove());

    document.getElementById('btn-req-push-perm')?.addEventListener('click', async () => {
      await notificationService.requestPermission(this.currentUser);
    });

    document.getElementById('btn-send-test-push')?.addEventListener('click', () => {
      notificationService.showLocalNotification('EduPeak Exam Alert', {
        body: '2027 A/L Physics Term Paper 01 is now active! Tap to join.',
        tag: 'exam-alert'
      });
      notificationService.showInAppBanner('Exam Alert Sent', 'Look for the system banner and audio chime.', 'info');
    });
  }

  // Live 4-box Countdown dynamically wired to student's batch and Firestore countdowns
  async startCountdownTimer() {
    if (this.countdownTimer) clearInterval(this.countdownTimer);

    const user = this.currentUser || {};
    const userBatch = user.examYear || '2027 A/L';
    let target = null;
    let title = `${userBatch} Physics Final Exam`;

    try {
      const countdowns = await dbService.getExamCountdowns();
      const match = countdowns.find(c => dbService.matchesYear(c.examYear, userBatch) && c.isEnabled !== false);
      if (match && match.targetDate) {
        target = new Date(match.targetDate);
        if (match.customTitle) title = match.customTitle;
      }
    } catch (_) {}

    if (!target || isNaN(target.getTime())) {
      const yearNum = parseInt((userBatch.match(/\d{4}/) || [2027])[0]);
      target = new Date(`${yearNum}-08-15T08:30:00+05:30`);
    }

    const titleEl = document.querySelector('.cd-exam-name');
    if (titleEl) titleEl.textContent = title;

    const update = () => {
      const diff = target - new Date();
      if (diff <= 0) {
        const d = document.getElementById('cd-days');
        const h = document.getElementById('cd-hours');
        const m = document.getElementById('cd-mins');
        const s = document.getElementById('cd-secs');
        if (d) d.textContent = '0';
        if (h) h.textContent = '00';
        if (m) m.textContent = '00';
        if (s) s.textContent = '00';
        return;
      }

      const days = Math.floor(diff / 86400000);
      const hours = Math.floor((diff % 86400000) / 3600000);
      const mins = Math.floor((diff % 3600000) / 60000);
      const secs = Math.floor((diff % 60000) / 1000);

      const d = document.getElementById('cd-days');
      const h = document.getElementById('cd-hours');
      const m = document.getElementById('cd-mins');
      const s = document.getElementById('cd-secs');

      if (d) d.textContent = days;
      if (h) h.textContent = hours.toString().padStart(2, '0');
      if (m) m.textContent = mins.toString().padStart(2, '0');
      if (s) s.textContent = secs.toString().padStart(2, '0');
    };

    this.countdownTimer = setInterval(update, 1000);
    update();
  }

  // Live Daily Inspiration Quote Rotator
  startInspirationRotator() {
    if (this.quoteRotator) clearInterval(this.quoteRotator);
    const quotes = [
      '“Success is the sum of small efforts repeated day in and day out.”',
      '“Discipline is choosing between what you want now and what you want most.”',
      '“Physics isn’t about memorizing formulas; it’s about understanding the universe.”',
      '“Small progress every single day adds up to big island ranks.”',
      '“Focus on the step in front of you, not the whole staircase.”'
    ];
    let index = 0;
    this.quoteRotator = setInterval(() => {
      const el = document.getElementById('inspiration-quote-text');
      if (!el) return;
      index = (index + 1) % quotes.length;
      el.style.opacity = '0';
      el.style.transform = 'translateY(4px)';
      setTimeout(() => {
        el.textContent = quotes[index];
        el.style.opacity = '1';
        el.style.transform = 'translateY(0)';
      }, 350);
    }, 5000);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ── ADMIN CONSOLE (1:1 FIDELITY WITH admin_shell.dart & FLUTTER ADMIN) ──
  // ═════════════════════════════════════════════════════════════════════════

  renderAdminApp() {
    const root = document.getElementById('app-root');
    if (!root) return;

    this.currentMode = 'admin';
    this.adminTab = this.adminTab || 'dashboard';

    root.innerHTML = `
      <!-- Main Scrollable Viewport -->
      <div class="main-viewport" id="admin-main-viewport" style="background:#F8FAFC; padding-bottom:80px;"></div>

      <!-- Contained Floating Action Button Slot (Strictly inside #app-root) -->
      <div id="admin-fab-slot"></div>

      <!-- Admin Bottom Navigation Bar (1:1 with admin_shell.dart NavigationBar) -->
      <nav class="bottom-nav-bar" id="admin-bottom-nav" style="background:#FFFFFF; border-top:1px solid #E2E8F0;">
        <button class="nav-tab-btn ${this.adminTab === 'dashboard' ? 'active' : ''}" data-admin-tab="dashboard">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">dashboard</span></div>
          <span>Dashboard</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'papers' ? 'active' : ''}" data-admin-tab="papers">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">assignment</span></div>
          <span>Papers</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'sprints' ? 'active' : ''}" data-admin-tab="sprints">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">flash_on</span></div>
          <span>MCQ Sprints</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'students' ? 'active' : ''}" data-admin-tab="students">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">people</span></div>
          <span>Students</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'broadcasts' ? 'active' : ''}" data-admin-tab="broadcasts">
          <div class="nav-pill-icon"><span class="material-symbols-rounded">send</span></div>
          <span>Broadcasts</span>
        </button>
      </nav>
    `;

    document.querySelectorAll('#admin-bottom-nav .nav-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.switchAdminTab(btn.dataset.adminTab);
      });
    });

    this.switchAdminTab(this.adminTab);
  }

  returnToAdminDashboard() {
    this.currentMode = 'admin';
    const url = new URL(window.location.href);
    url.searchParams.delete('view');
    url.searchParams.delete('tab');
    window.history.replaceState({ ...(window.history.state || {}), edupeakView: 'admin' }, '', url);
    this.renderAdminApp();
  }
  switchAdminTab(tabName) {
    this.adminTab = tabName;
    const viewport = document.getElementById('admin-main-viewport');
    if (!viewport) return;

    // Reset FAB slot on every tab switch so buttons never bleed across tabs
    const fabSlot = document.getElementById('admin-fab-slot');
    if (fabSlot) fabSlot.innerHTML = '';

    document.querySelectorAll('#admin-bottom-nav .nav-tab-btn').forEach(b => {
      b.classList.toggle('active', b.dataset.adminTab === tabName);
    });

    // Smooth page entrance transition matching Flutter 1:1
    viewport.classList.remove('tab-page-transition');
    void viewport.offsetWidth; // Force DOM reflow to re-trigger CSS keyframes
    viewport.classList.add('tab-page-transition');

    switch (tabName) {
      case 'dashboard':
        this.renderAdminDashboardScreen(viewport);
        break;
      case 'papers':
        this.renderAdminPapersScreen(viewport);
        break;
      case 'sprints':
        this.renderAdminSprintsScreen(viewport);
        break;
      case 'students':
        this.renderAdminStudentsScreen(viewport);
        break;
      case 'broadcasts':
        this.renderAdminBroadcastsScreen(viewport);
        break;
      default:
        this.renderAdminDashboardScreen(viewport);
    }

    viewport.scrollTo({ top: 0, behavior: 'smooth' });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ── 1. SCREEN 1: ADMIN HOME SCREEN (admin_home_screen.dart) ──────────────
  // ═════════════════════════════════════════════════════════════════════════
  async renderAdminDashboardScreen(container) {
    this.adminFilterTab = this.adminFilterTab ?? 'pending'; // 'pending', 'approved', 'rejected'
    this.adminSearchQuery = this.adminSearchQuery ?? '';

    const allDesserts = await dbService.getAllDessertsForAdmin();
    const pending = allDesserts.filter(d => (d.status || '').toLowerCase() === 'pending');
    const approved = allDesserts.filter(d => (d.status || '').toLowerCase() === 'approved');
    const rejected = allDesserts.filter(d => (d.status || '').toLowerCase() === 'rejected');

    let currentList = this.adminFilterTab === 'pending' ? pending :
                      this.adminFilterTab === 'approved' ? approved : rejected;

    if (this.adminSearchQuery.trim()) {
      const q = this.adminSearchQuery.toLowerCase();
      currentList = currentList.filter(d =>
        (d.studentName || '').toLowerCase().includes(q) ||
        (d.subject || '').toLowerCase().includes(q) ||
        (d.studentPhone || '').includes(q) ||
        (d.caption || '').toLowerCase().includes(q)
      );
    }

    const adminName = this.currentUser?.name || 'ThiZaru';
    const initial = adminName.charAt(0).toUpperCase();

    container.innerHTML = `
      <div class="apk-admin-screen-container">
        <!-- ── 1. Executive Top Header (lines 185-344) ── -->
        <div class="apk-admin-exec-card">
          <div class="apk-admin-exec-top-row">
            <div class="apk-admin-portal-badge" title="Admin Portal • ${adminName}">
              <span class="apk-pulsing-dot"></span>
              <span>Admin Portal</span>
            </div>
            <div class="apk-admin-exec-actions">
              <button class="apk-btn-student-view" id="btn-admin-student-view">
                <span class="material-symbols-rounded" style="font-size:16px;">school</span>
                <span>Student View</span>
              </button>
              <button class="apk-btn-logout-icon" id="btn-admin-logout" title="Sign Out">
                <span class="material-symbols-rounded" style="font-size:18px;">logout</span>
              </button>
            </div>
          </div>

          <!-- Greeting Row -->
          <div class="apk-admin-greeting-row">
            <div class="apk-admin-avatar">${initial}</div>
            <div class="apk-admin-greeting-text">
              <h2>Welcome back, ${adminName}</h2>
              <p>${pending.length > 0 ? `${pending.length} dessert submission(s) need your review today` : 'All reviews up to date! System is running smoothly'}</p>
            </div>
          </div>
        </div>

        <!-- ── 2. Real-Time Overview Metrics Row (lines 347-394) ── -->
        <div class="apk-metrics-row">
          <div class="apk-metric-card ${this.adminFilterTab === 'pending' ? 'active-pending' : ''}" data-metric-tab="pending">
            <div class="apk-metric-icon-circle" style="background:rgba(245, 158, 11, 0.12); color:#F59E0B;">
              <span class="material-symbols-rounded filled" style="font-size:18px; color:#F59E0B;">hourglass_top</span>
            </div>
            <div class="apk-metric-num" style="color:#F59E0B;">${pending.length}</div>
            <div class="apk-metric-lbl">Pending Review</div>
          </div>

          <div class="apk-metric-card ${this.adminFilterTab === 'approved' ? 'active-approved' : ''}" data-metric-tab="approved">
            <div class="apk-metric-icon-circle" style="background:rgba(16, 185, 129, 0.12); color:#10B981;">
              <span class="material-symbols-rounded filled" style="font-size:18px; color:#10B981;">check_circle</span>
            </div>
            <div class="apk-metric-num" style="color:#10B981;">${approved.length}</div>
            <div class="apk-metric-lbl">Approved</div>
          </div>

          <div class="apk-metric-card ${this.adminFilterTab === 'rejected' ? 'active-rejected' : ''}" data-metric-tab="rejected">
            <div class="apk-metric-icon-circle" style="background:rgba(239, 68, 68, 0.12); color:#EF4444;">
              <span class="material-symbols-rounded" style="font-size:18px; color:#EF4444;">cancel</span>
            </div>
            <div class="apk-metric-num" style="color:#EF4444;">${rejected.length}</div>
            <div class="apk-metric-lbl">Rejected</div>
          </div>
        </div>

        <!-- ── 3. Quick Action Command Hub (lines 492-575) ── -->
        <div class="apk-command-center-box">
          <div class="apk-command-center-title">
            <span class="material-symbols-rounded filled" style="color:#2563EB; font-size:20px;">flash_on</span>
            <span>Admin Command Center</span>
          </div>
          <div class="apk-command-grid">
            <button class="apk-command-btn purple" id="btn-cmd-countdowns">
              <div class="apk-command-icon-box" style="background:rgba(139, 92, 246, 0.12); color:#8B5CF6;">
                <span class="material-symbols-rounded" style="font-size:20px;">timer</span>
              </div>
              <div class="apk-command-info">
                <div class="title">Exam Dates</div>
                <div class="subtitle">Target count down</div>
              </div>
            </button>

            <button class="apk-command-btn blue" id="btn-cmd-papers">
              <div class="apk-command-icon-box" style="background:rgba(37, 99, 235, 0.12); color:#2563EB;">
                <span class="material-symbols-rounded" style="font-size:20px;">assignment</span>
              </div>
              <div class="apk-command-info">
                <div class="title">Paper Sessions</div>
                <div class="subtitle">Live proctoring</div>
              </div>
            </button>

            <button class="apk-command-btn amber" id="btn-cmd-sprints">
              <div class="apk-command-icon-box" style="background:rgba(245, 158, 11, 0.12); color:#F59E0B;">
                <span class="material-symbols-rounded filled" style="font-size:20px;">flash_on</span>
              </div>
              <div class="apk-command-info">
                <div class="title">MCQ Sprints</div>
                <div class="subtitle">Rapid quiz sets</div>
              </div>
            </button>

            <button class="apk-command-btn cyan" id="btn-cmd-broadcasts">
              <div class="apk-command-icon-box" style="background:rgba(6, 182, 212, 0.12); color:#06B6D4;">
                <span class="material-symbols-rounded" style="font-size:20px;">send</span>
              </div>
              <div class="apk-command-info">
                <div class="title">Broadcasts</div>
                <div class="subtitle">Send telegram</div>
              </div>
            </button>

            <button class="apk-command-btn emerald" id="btn-cmd-daily-insight" style="grid-column: span 2;">
              <div class="apk-command-icon-box" style="background:rgba(16, 185, 129, 0.12); color:#10B981;">
                <span class="material-symbols-rounded" style="font-size:20px;">science</span>
              </div>
              <div class="apk-command-info">
                <div class="title">Physics Micro-Insight</div>
                <div class="subtitle">Auto-rotate random or pin custom formula</div>
              </div>
            </button>
          </div>
        </div>

        <!-- ── 4. Dessert Submissions Queue Section (lines 99-178) ── -->
        <div class="apk-queue-section">
          <div class="apk-queue-header-row">
            <div class="apk-queue-title">
              <span class="material-symbols-rounded" style="color:#2563EB; font-size:20px;">assignment_turned_in</span>
              <span>Dessert Submissions Queue</span>
            </div>
            <span class="apk-queue-badge">Physics A/L</span>
          </div>

          <!-- Segmented Tab Switcher -->
          <div class="apk-segmented-tabs">
            <button class="apk-segmented-tab-btn ${this.adminFilterTab === 'pending' ? 'active' : ''}" data-queue-tab="pending">
              <span>Pending</span>
              <span class="apk-segmented-pill-badge ${this.adminFilterTab === 'pending' ? 'orange' : 'grey'}">${pending.length}</span>
            </button>
            <button class="apk-segmented-tab-btn ${this.adminFilterTab === 'approved' ? 'active' : ''}" data-queue-tab="approved">
              <span>Approved</span>
              <span class="apk-segmented-pill-badge ${this.adminFilterTab === 'approved' ? 'green' : 'grey'}">${approved.length}</span>
            </button>
            <button class="apk-segmented-tab-btn ${this.adminFilterTab === 'rejected' ? 'active' : ''}" data-queue-tab="rejected">
              <span>Rejected</span>
              <span class="apk-segmented-pill-badge ${this.adminFilterTab === 'rejected' ? 'red' : 'grey'}">${rejected.length}</span>
            </button>
          </div>

          <!-- Search Bar -->
          <div class="apk-search-bar">
            <input type="text" id="input-admin-search" placeholder="Search by student name, phone or notes..." value="${this.adminSearchQuery}" />
            <span class="material-symbols-rounded apk-search-icon" style="font-size:18px;">search</span>
          </div>

          <!-- Submissions List or Empty State -->
          ${currentList.length === 0 ? `
            <div class="apk-empty-card">
              <div class="apk-empty-icon-circle">
                <span class="material-symbols-rounded filled" style="font-size:24px; color:#10B981;">task_alt</span>
              </div>
              <div class="apk-empty-title">All Caught Up!</div>
              <div class="apk-empty-subtitle">There are no pending dessert submissions waiting for review.</div>
              <button class="apk-btn-primary" id="btn-queue-manage-papers">Manage Paper Sessions</button>
            </div>
          ` : `
            <div style="display:flex; flex-direction:column; gap:10px;">
              ${currentList.map(d => `
                <div class="admin-submission-item" style="background:#FFFFFF; border:1px solid #E2E8F0; border-radius:16px; padding:14px;">
                  <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
                    <div style="display:flex; align-items:center; gap:8px;">
                      <div class="apk-admin-avatar" style="width:34px; height:34px; font-size:14px;">${(d.studentName || 'S').charAt(0).toUpperCase()}</div>
                      <div>
                        <div style="font-size:13px; font-weight:800; color:#0F172A;">${d.studentName || 'Anonymous Student'}</div>
                        <div style="font-size:11px; color:#64748B;">${d.studentPhone || ''}</div>
                      </div>
                    </div>
                    <span class="quest-status-badge ${d.status === 'approved' ? 'quest-badge-green' : d.status === 'rejected' ? 'quest-badge-orange' : 'quest-badge-blue'}">
                      ${d.status === 'approved' ? '<span class="material-symbols-rounded filled" style="font-size:13px; vertical-align:middle;">check_circle</span> Approved' : d.status === 'rejected' ? '<span class="material-symbols-rounded filled" style="font-size:13px; vertical-align:middle;">cancel</span> Needs Redo' : '<span class="material-symbols-rounded filled" style="font-size:13px; vertical-align:middle;">hourglass_top</span> Pending Review'}
                    </span>
                  </div>
                  <div style="font-size:12.5px; font-weight:700; color:#1E293B;">${d.subject || 'Physics Problem Set'}</div>
                  <div style="font-size:11.5px; color:#64748B; margin-top:2px;">${d.caption || 'Daily problem set submission'}</div>
                  ${d.mediaUrls && d.mediaUrls.length > 0 ? `
                    <div style="display:flex; gap:6px; margin:8px 0; overflow-x:auto;">
                      ${d.mediaUrls.map(u => `<img src="${u}" style="width:48px; height:48px; border-radius:8px; object-fit:cover; border:1px solid #CBD5E1;" />`).join('')}
                    </div>
                  ` : ''}
                  <div style="display:flex; justify-content:space-between; align-items:center; margin-top:6px; padding-top:8px; border-top:1px solid #F1F5F9;">
                    <span style="font-size:11.5px; font-weight:800; color:#2563EB;">Award: +${d.creditsAwarded || 50} XP</span>
                    <button class="apk-btn-primary" data-review-id="${d.id}" style="padding:6px 14px; font-size:11.5px; display:inline-flex; align-items:center; gap:4px;">
                      <span>Review & Grade</span>
                      <span class="material-symbols-rounded" style="font-size:14px;">arrow_forward</span>
                    </button>
                  </div>
                </div>
              `).join('')}
            </div>
          `}
        </div>
      </div>
    `;

    // Listeners
    document.getElementById('btn-admin-student-view')?.addEventListener('click', () => {
      this.currentMode = 'student';
      const url = new URL(window.location.href);
      url.searchParams.delete('tab');
      url.searchParams.set('view', 'student');
      window.history.pushState({ ...(window.history.state || {}), edupeakView: 'student' }, '', url);
      this.renderApp();
    });

    document.getElementById('btn-admin-logout')?.addEventListener('click', () => {
      this.confirmLogout();
    });

    container.querySelectorAll('[data-metric-tab]').forEach(card => {
      card.addEventListener('click', () => {
        this.adminFilterTab = card.dataset.metricTab;
        this.renderAdminDashboardScreen(container);
      });
    });

    container.querySelectorAll('[data-queue-tab]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.adminFilterTab = btn.dataset.queueTab;
        this.renderAdminDashboardScreen(container);
      });
    });

    document.getElementById('input-admin-search')?.addEventListener('input', (e) => {
      this.adminSearchQuery = e.target.value;
      this.renderAdminDashboardScreen(container);
    });

    document.getElementById('btn-queue-manage-papers')?.addEventListener('click', () => {
      this.switchAdminTab('papers');
    });

    // Command Center Quick Jump Buttons
    document.getElementById('btn-cmd-countdowns')?.addEventListener('click', () => {
      this.openExamCountdownsModal();
    });
    document.getElementById('btn-cmd-papers')?.addEventListener('click', () => {
      this.switchAdminTab('papers');
    });
    document.getElementById('btn-cmd-sprints')?.addEventListener('click', () => {
      this.switchAdminTab('sprints');
    });
    document.getElementById('btn-cmd-broadcasts')?.addEventListener('click', () => {
      this.switchAdminTab('broadcasts');
    });
    document.getElementById('btn-cmd-daily-insight')?.addEventListener('click', () => {
      this.openAdminDailyInsightModal();
    });

    container.querySelectorAll('[data-review-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.reviewId;
        const sub = allDesserts.find(x => x.id === id);
        this.openAdminReviewModal(sub);
      });
    });
  }

  // Review & Grade Drawer Modal (admin_review_screen.dart)
  openAdminReviewModal(sub) {
    if (!sub) return;

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    let credits = sub.creditsAwarded || 50;

    modal.innerHTML = `
      <div class="modal-sheet" style="max-height:92vh; overflow-y:auto;">
        <div class="modal-header">
          <div>
            <div style="font-size:15px; font-weight:800; color:#0F172A;">Grade Homework: ${sub.studentName}</div>
            <div style="font-size:11.5px; color:#64748B;">${sub.subject}</div>
          </div>
          <button class="modal-close-btn" id="btn-close-review">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <!-- Media Image Viewer -->
        ${sub.mediaUrls && sub.mediaUrls.length > 0 ? `
          <div style="text-align:center; background:#0B0F19; border-radius:12px; padding:8px; margin-bottom:12px;">
            <img src="${sub.mediaUrls[0]}" style="max-height:220px; width:auto; border-radius:8px; object-fit:contain;" />
            <div style="color:#94A3B8; font-size:10px; margin-top:4px;">Attached Answer Sheet</div>
          </div>
        ` : ''}

        <!-- Student Remarks -->
        <div style="background:#F8FAFC; border:1px solid #E2E8F0; border-radius:10px; padding:10px; margin-bottom:12px; font-size:11.5px; color:#334155;">
          <strong>Student Remarks:</strong> ${sub.caption || 'None provided.'}
        </div>

        <!-- XP Credit Award Picker -->
        <div style="margin-bottom:14px;">
          <div style="font-size:12px; font-weight:800; color:#0F172A; margin-bottom:6px;">Award XP Credits:</div>
          <div style="display:flex; gap:6px;">
            ${[10, 25, 50, 100].map(amt => `
              <button class="topic-chip ${credits === amt ? 'active' : ''}" data-credit-val="${amt}" style="flex:1;">
                +${amt} XP
              </button>
            `).join('')}
          </div>
        </div>

        <!-- Teacher Feedback Presets -->
        <div style="margin-bottom:8px;">
          <div style="font-size:12px; font-weight:800; color:#0F172A; margin-bottom:6px;">Quick Feedback Presets:</div>
          <div style="display:flex; flex-wrap:wrap; gap:6px;">
            <button class="history-filter-chip" data-preset="Great work! Free-body diagram is crystal clear.">
              <span style="display:inline-flex; align-items:center; gap:4px;"><span class="material-symbols-rounded filled" style="font-size:14px; color:#F59E0B;">star</span> Great Work</span>
            </button>
            <button class="history-filter-chip" data-preset="Calculation is correct, but add units to the final answer.">
              <span style="display:inline-flex; align-items:center; gap:4px;"><span class="material-symbols-rounded" style="font-size:14px;">straighten</span> Missing Units</span>
            </button>
            <button class="history-filter-chip" data-preset="Sign error in force components on line 3. Please revise.">
              <span style="display:inline-flex; align-items:center; gap:4px;"><span class="material-symbols-rounded" style="font-size:14px;">calculate</span> Sign Error</span>
            </button>
          </div>
        </div>

        <!-- Teacher Feedback Custom Textarea -->
        <div style="margin-bottom:16px;">
          <div style="font-size:12px; font-weight:800; color:#0F172A; margin-bottom:4px;">Feedback / Correction Notes:</div>
          <textarea id="admin-feedback-text" class="form-textarea" rows="2" placeholder="Write personalized teacher feedback...">${sub.adminFeedback || ''}</textarea>
        </div>

        <!-- Approve vs Reject Actions -->
        <div style="display:flex; gap:10px;">
          <button class="btn-primary" id="btn-admin-reject-sub" style="background:#EF4444; flex:1; padding:12px; display:inline-flex; align-items:center; justify-content:center; gap:4px;">
            <span class="material-symbols-rounded filled" style="font-size:16px;">cancel</span>
            <span>Request Redo</span>
          </button>
          <button class="btn-primary" id="btn-admin-approve-sub" style="background:#10B981; flex:1.3; padding:12px; display:inline-flex; align-items:center; justify-content:center; gap:4px;">
            <span class="material-symbols-rounded filled" style="font-size:16px;">check_circle</span>
            <span>Approve (+${credits} XP)</span>
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelectorAll('[data-credit-val]').forEach(btn => {
      btn.addEventListener('click', () => {
        credits = Number(btn.dataset.creditVal);
        modal.querySelectorAll('[data-credit-val]').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const approveBtn = document.getElementById('btn-admin-approve-sub');
        if (approveBtn) approveBtn.innerHTML = `<span class="material-symbols-rounded filled" style="font-size:16px;">check_circle</span> <span>Approve (+${credits} XP)</span>`;
      });
    });

    modal.querySelectorAll('[data-preset]').forEach(btn => {
      btn.addEventListener('click', () => {
        const area = document.getElementById('admin-feedback-text');
        if (area) area.value = btn.dataset.preset;
      });
    });

    document.getElementById('btn-close-review')?.addEventListener('click', () => modal.remove());

    document.getElementById('btn-admin-approve-sub')?.addEventListener('click', async () => {
      const fb = document.getElementById('admin-feedback-text')?.value || 'Great work!';
      await dbService.reviewDessert(sub.id, {
        status: 'approved',
        adminFeedback: fb,
        creditsAwarded: credits,
        reviewedBy: 'Lead Physics Faculty'
      });
      notificationService.showInAppBanner('Submission Approved!', `Awarded +${credits} XP to ${sub.studentName}.`, 'success');
      modal.remove();
      const vp = document.getElementById('admin-main-viewport');
      if (vp) this.renderAdminDashboardScreen(vp);
    });

    document.getElementById('btn-admin-reject-sub')?.addEventListener('click', async () => {
      const fb = document.getElementById('admin-feedback-text')?.value || 'Needs improvement. Please try again.';
      await dbService.reviewDessert(sub.id, {
        status: 'rejected',
        adminFeedback: fb,
        creditsAwarded: 10,
        reviewedBy: 'Lead Physics Faculty'
      });
      notificationService.showInAppBanner('Revision Requested', `Sent correction notes to ${sub.studentName}.`, 'warning');
      modal.remove();
      const vp = document.getElementById('admin-main-viewport');
      if (vp) this.renderAdminDashboardScreen(vp);
    });
  }

  // 2. Admin Papers Screen (admin_paper_sessions_screen.dart)
  async renderAdminPapersScreen(container) {
    this.adminPaperTab = this.adminPaperTab ?? 0; // 0: Live Sessions, 1: Upcoming Papers, 2: Leaderboard
    this.adminSelectedPaperBatch = this.adminSelectedPaperBatch || 'All Batches';
    const papers = await dbService.getPaperSessions();
    let adminUpcomingPapers = [];
    let adminUpcomingPapersError = false;
    if (this.adminPaperTab === 1) {
      try {
        adminUpcomingPapers = await dbService.getUpcomingPapers('All Batches');
      } catch (error) {
        console.warn('[Admin papers] Upcoming papers could not be loaded:', error?.code || 'unknown');
        adminUpcomingPapersError = true;
      }
    }
    let adminPaperBoards = [];
    let adminPaperBoardsError = false;
    if (this.adminPaperTab === 2) {
      try {
        const allBoards = await dbService.getPaperLeaderboards();
        const selectedBatch = this.adminSelectedPaperBatch.replace(/\s+/g, '').toUpperCase();
        adminPaperBoards = allBoards.filter((board) => this.adminSelectedPaperBatch === 'All Batches'
          || board.examYear.replace(/\s+/g, '').toUpperCase() === selectedBatch
          || ['ALL', 'ALLBATCHES'].includes(board.examYear.replace(/\s+/g, '').toUpperCase()));
      } catch (error) {
        console.warn('[Admin papers] Paper results could not be loaded:', error?.code || 'unknown');
        adminPaperBoardsError = true;
      }
    }

    const subtitle = this.adminPaperTab === 0
      ? 'සජීවී විභාග සැසි සහ කැමරා අධීක්ෂණය'
      : (this.adminPaperTab === 1 ? 'ඉදිරි විභාග සහ Hints කළමනාකරණය' : 'Paper ප්‍රතිඵල සහ Leaderboard නිර්මාණය');

    container.innerHTML = `
      <!-- Screen AppBar -->
      <div class="apk-screen-appbar">
        <div class="apk-appbar-left">
          <div class="apk-appbar-icon-box">
            <span class="material-symbols-rounded" style="font-size:22px; color:#2563EB;">fact_check</span>
          </div>
          <div>
            <div class="apk-appbar-title">Paper Examination Hub</div>
            <div class="apk-appbar-subtitle">${subtitle}</div>
          </div>
        </div>
        <div class="apk-appbar-actions">
          <button class="apk-icon-action-btn" id="btn-admin-countdowns" title="A/L Exam Target Dates & Countdowns">
            <span class="material-symbols-rounded" style="font-size:20px; color:#64748B;">timer</span>
          </button>
          <button class="apk-icon-action-btn" id="btn-admin-add-paper-head" title="Create" style="color:#2563EB;">
            <span class="material-symbols-rounded" style="font-size:24px;">add_circle</span>
          </button>
        </div>
      </div>

      <!-- Segmented 3-Tab Selector -->
      <div style="padding:12px 16px 8px;">
        <div style="background:#FFFFFF; border-radius:16px; padding:4px; border:1px solid #E2E8F0; display:flex; box-shadow:0 2px 8px rgba(15,23,42,0.04);">
          <button class="apk-segmented-tab-btn ${this.adminPaperTab === 0 ? 'active' : ''}" data-paper-tab="0" style="${this.adminPaperTab === 0 ? 'background:#2563EB; color:#FFFFFF;' : ''}">
            <span class="material-symbols-rounded filled" style="font-size:16px; margin-right:4px;">sensors</span> Live Sessions
          </button>
          <button class="apk-segmented-tab-btn ${this.adminPaperTab === 1 ? 'active' : ''}" data-paper-tab="1" style="${this.adminPaperTab === 1 ? 'background:#2563EB; color:#FFFFFF;' : ''}">
            <span class="material-symbols-rounded" style="font-size:16px; margin-right:4px;">lightbulb</span> Upcoming Papers
          </button>
          <button class="apk-segmented-tab-btn ${this.adminPaperTab === 2 ? 'active' : ''}" data-paper-tab="2" style="${this.adminPaperTab === 2 ? 'background:#2563EB; color:#FFFFFF;' : ''}">
            <span class="material-symbols-rounded" style="font-size:16px; margin-right:4px;">emoji_events</span> Leaderboard
          </button>
        </div>
      </div>

      <!-- Tab Viewport -->
      <div id="admin-papers-content" style="padding:0 16px 90px;">
        ${this.adminPaperTab === 0 ? this._buildAdminLiveSessionsHTML(papers) : ''}
        ${this.adminPaperTab === 1 ? this._buildAdminUpcomingPapersHTML(adminUpcomingPapers, adminUpcomingPapersError) : ''}
        ${this.adminPaperTab === 2 ? this._buildAdminPaperLeaderboardHTML(adminPaperBoards, adminPaperBoardsError, this.adminSelectedPaperBatch) : ''}
      </div>
    `;

    // Render FAB strictly inside the contained admin-fab-slot
    const fabSlot = document.getElementById('admin-fab-slot');
    if (fabSlot) {
      fabSlot.innerHTML = `
        <button class="apk-fab-button" id="btn-fab-admin-paper" style="display:inline-flex; align-items:center; gap:6px;">
          <span class="material-symbols-rounded" style="font-size:20px;">add</span>
          <span>${this.adminPaperTab === 0 ? 'Add Live Session' : (this.adminPaperTab === 1 ? 'Add Upcoming Paper' : 'Create Leaderboard')}</span>
        </button>
      `;
    }

    // Tab switcher events
    container.querySelectorAll('[data-paper-tab]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.adminPaperTab = Number(btn.dataset.paperTab);
        this.renderAdminPapersScreen(container);
      });
    });

    document.getElementById('select-admin-paper-results-batch')?.addEventListener('change', (event) => {
      this.adminSelectedPaperBatch = event.target.value;
      this.adminExpandedPaperBoards = new Set();
      this.adminPaperBoardsInitialized = false;
      this.renderAdminPapersScreen(container);
    });
    document.getElementById('btn-admin-paper-results-retry')?.addEventListener('click', () => {
      this.renderAdminPapersScreen(container);
    });
    document.getElementById('btn-admin-upcoming-retry')?.addEventListener('click', () => {
      this.renderAdminPapersScreen(container);
    });
    container.querySelectorAll('[data-admin-paper-board]').forEach((button) => {
      button.addEventListener('click', () => {
        const boardId = button.dataset.adminPaperBoard;
        if (this.adminExpandedPaperBoards.has(boardId)) this.adminExpandedPaperBoards.delete(boardId);
        else this.adminExpandedPaperBoards.add(boardId);
        this.renderAdminPapersScreen(container);
      });
    });

    // Countdown button
    document.getElementById('btn-admin-countdowns')?.addEventListener('click', () => {
      this.openExamCountdownsModal();
    });

    // Add buttons
    const triggerAdd = () => {
      if (this.adminPaperTab === 0) this.openAdminCreatePaperModal();
      else if (this.adminPaperTab === 1) this.openAdminCreatePaperModal();
      else this.openAdminCreatePaperModal();
    };

    document.getElementById('btn-admin-add-paper-head')?.addEventListener('click', triggerAdd);
    document.getElementById('btn-fab-admin-paper')?.addEventListener('click', triggerAdd);
    document.getElementById('btn-empty-create-paper')?.addEventListener('click', triggerAdd);

    // Interactive paper action handlers matching Flutter 1:1
    container.querySelectorAll('[data-view-proctor]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.openAdminLiveProctorHall(btn.dataset.viewProctor);
      });
    });

    container.querySelectorAll('[data-student-exam]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.openStudentLiveExamRoom(btn.dataset.studentExam, 'slot1');
      });
    });

    container.querySelectorAll('[data-edit-times]').forEach(btn => {
      btn.addEventListener('click', () => {
        const p = papers.find(x => x.id === btn.dataset.editTimes);
        if (p) this._showEditTimesDialog(p, container);
      });
    });

    container.querySelectorAll('[data-delete-paper]').forEach(btn => {
      btn.addEventListener('click', () => {
        const p = papers.find(x => x.id === btn.dataset.deletePaper);
        if (p) this._showDeleteConfirmation(p, container);
      });
    });

    container.querySelectorAll('[data-end-session]').forEach(btn => {
      btn.addEventListener('click', () => {
        const p = papers.find(x => x.id === btn.dataset.endSession);
        if (p) this._showEndSessionConfirmation(p, container);
      });
    });

    container.querySelectorAll('[data-start-session]').forEach(btn => {
      btn.addEventListener('click', () => {
        const p = papers.find(x => x.id === btn.dataset.startSession);
        if (p) this._startSessionNow(p, container);
      });
    });

    container.querySelectorAll('[data-reopen-session]').forEach(btn => {
      btn.addEventListener('click', () => {
        const p = papers.find(x => x.id === btn.dataset.reopenSession);
        if (p) this._reopenSession(p, container);
      });
    });
  }

  _computePaperStatus(session) {
    return dbService.computeSessionStatus(session).statusText;
  }

  _formatSessionDate(dateStr) {
    try {
      const d = dateStr ? new Date(dateStr) : new Date();
      if (isNaN(d.getTime())) return dateStr || 'Today';
      const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      return `${d.getFullYear()} ${months[d.getMonth()]} ${String(d.getDate()).padStart(2, '0')} (${days[d.getDay()]})`;
    } catch (_) {
      return dateStr || 'Today';
    }
  }

  _formatSessionTime(timeVal, fallback = '08:30 AM') {
    if (!timeVal) return fallback;
    try {
      const d = new Date(timeVal);
      if (!isNaN(d.getTime())) {
        let h = d.getHours();
        const m = String(d.getMinutes()).padStart(2, '0');
        const ampm = h >= 12 ? 'PM' : 'AM';
        h = h % 12;
        if (h === 0) h = 12;
        return `${String(h).padStart(2, '0')}:${m} ${ampm}`;
      }
      return String(timeVal);
    } catch (_) {
      return fallback;
    }
  }

  _buildAdminLiveSessionsHTML(papers) {
    if (!papers || papers.length === 0) {
      return `
        <div style="padding:60px 20px 20px; text-align:center; display:flex; flex-direction:column; align-items:center;">
          <div style="width:76px; height:76px; border-radius:50%; background:#F8FAFC; border:1px solid #E2E8F0; display:flex; align-items:center; justify-content:center; color:#2563EB; margin-bottom:18px;">
            <span class="material-symbols-rounded" style="font-size:36px;">note_add</span>
          </div>
          <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:8px;">
            තවම Paper Sessions නිර්මාණය කර නොමැත
          </div>
          <div style="font-size:13px; color:#64748B; max-width:320px; line-height:1.45; margin-bottom:24px;">
            නව විභාග සැසියක් නිර්මාණය කර Slot 1 සහ Slot 2 වේලාවන් සකසන්න.
          </div>
          <button class="apk-btn-primary" id="btn-empty-create-paper" style="display:inline-flex; align-items:center; gap:8px; padding:12px 22px; border-radius:12px;">
            <span class="material-symbols-rounded" style="font-size:18px;">add</span> Create First Paper Session
          </button>
        </div>
      `;
    }

    return `
      <div style="display:flex; flex-direction:column; gap:16px; margin-top:12px;">
        ${papers.map(p => this._buildAdminPaperCard(p)).join('')}
      </div>
    `;
  }

  _buildAdminPaperCard(session) {
    const status = this._computePaperStatus(session);
    const isEnded = status === 'ended';
    const isLive = status === 'live';
    const isUpcoming = status === 'upcoming';

    let badgeText = 'Upcoming';
    let badgeIcon = 'schedule';
    let badgeBg = 'rgba(245, 158, 11, 0.12)';
    let badgeBorder = '#F59E0B';
    let badgeColor = '#D97706';

    if (isEnded) {
      badgeText = 'Ended';
      badgeIcon = 'cancel';
      badgeBg = 'rgba(239, 68, 68, 0.12)';
      badgeBorder = '#EF4444';
      badgeColor = '#DC2626';
    } else if (isLive) {
      badgeText = 'Live';
      badgeIcon = 'sensors';
      badgeBg = 'rgba(34, 197, 94, 0.12)';
      badgeBorder = '#22C55E';
      badgeColor = '#16A34A';
    }

    const dateFormatted = this._formatSessionDate(session.date);
    const hasSlot2 = !!(session.slot2 && session.slot2.startTime);
    
    const slot1Name = hasSlot2 ? 'Slot 1 (Morning)' : 'Exam Session Time';
    const slot1Start = this._formatSessionTime(session.slot1?.startTime, '08:30 AM');
    const slot1End = this._formatSessionTime(session.slot1?.endTime, '11:30 AM');
    const slot1Count = session.slot1?.registeredCount || 0;

    const slot2Name = 'Slot 2 (Evening)';
    const slot2Start = this._formatSessionTime(session.slot2?.startTime, '04:00 PM');
    const slot2End = this._formatSessionTime(session.slot2?.endTime, '07:00 PM');
    const slot2Count = session.slot2?.registeredCount || 0;

    return `
      <div class="admin-paper-card" style="background:#FFFFFF; border-radius:16px; border:1px solid #E2E8F0; box-shadow:0 3px 12px rgba(15,23,42,0.04); margin-bottom:4px; overflow:hidden;">
        <!-- Top Badges & Actions matching Flutter 1:1 -->
        <div style="padding:16px; background:#F8FAFC; border-bottom:1px solid #E2E8F0;">
          <div style="display:flex; align-items:center; gap:8px;">
            <span style="background:rgba(37,99,235,0.12); color:#2563EB; font-size:11px; font-weight:600; padding:4px 10px; border-radius:20px;">
              ${session.subject || 'Physics'}
            </span>
            <span style="background:#FFFFFF; border:1px solid #E2E8F0; color:#64748B; font-size:11px; padding:4px 10px; border-radius:20px;">
              ${session.examYear || '2027 A/L'}
            </span>
            <span style="background:${badgeBg}; border:1px solid ${badgeBorder}; color:${badgeColor}; font-size:10px; font-weight:700; padding:4px 8px; border-radius:20px; display:inline-flex; align-items:center; gap:4px;">
              <span class="material-symbols-rounded ${isLive ? 'filled' : ''}" style="font-size:13px;">${badgeIcon}</span>
              <span>${badgeText}</span>
            </span>
            <div style="margin-left:auto; display:flex; align-items:center; gap:4px;">
              <button class="apk-icon-action-btn" data-edit-times="${session.id}" title="Change Session Times (Slot 1 / Slot 2)" style="color:#2563EB; font-size:16px; width:32px; height:32px; display:inline-flex; align-items:center; justify-content:center; border:none; background:transparent; cursor:pointer;">
                <span class="material-symbols-rounded" style="font-size:18px;">edit_calendar</span>
              </button>
              <button class="apk-icon-action-btn" data-delete-paper="${session.id}" title="Delete Paper Session (සැසිය මකා දැමීම)" style="color:#EF4444; font-size:16px; width:32px; height:32px; display:inline-flex; align-items:center; justify-content:center; border:none; background:transparent; cursor:pointer;">
                <span class="material-symbols-rounded" style="font-size:18px;">delete</span>
              </button>
            </div>
          </div>

          <div style="font-size:16px; font-weight:700; color:#0F172A; margin-top:8px;">
            ${session.title}
          </div>

          <div style="display:flex; align-items:center; gap:14px; margin-top:4px; font-size:11px; color:#64748B;">
            <span style="display:inline-flex; align-items:center; gap:4px;">
              <span class="material-symbols-rounded" style="font-size:14px; color:#64748B;">calendar_today</span>
              <span>${dateFormatted}</span>
            </span>
            <span style="display:inline-flex; align-items:center; gap:4px;">
              <span class="material-symbols-rounded" style="font-size:14px; color:#64748B;">timer</span>
              <span>${session.durationMinutes || 180} Mins</span>
            </span>
          </div>
        </div>

        <!-- Slots & Action Buttons matching Flutter 1:1 -->
        <div style="padding:16px;">
          <!-- Slots Container -->
          <div style="display:grid; grid-template-columns: ${hasSlot2 ? '1fr 1fr' : '1fr'}; gap:12px;">
            <div style="background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; padding:12px;">
              <div style="display:flex; align-items:center; gap:6px; font-size:11px; font-weight:600; color:#0F172A;">
                <span class="material-symbols-rounded" style="font-size:15px; color:#F59E0B;">wb_sunny</span>
                <span>${slot1Name}</span>
              </div>
              <div style="font-size:11px; color:#64748B; margin-top:6px;">
                ${slot1Start} - ${slot1End}
              </div>
              <div style="font-size:11px; font-weight:700; color:#2563EB; margin-top:4px; display:inline-flex; align-items:center; gap:4px;">
                <span class="material-symbols-rounded" style="font-size:14px; color:#2563EB;">group</span>
                <span>${slot1Count} Registered</span>
              </div>
            </div>

            ${hasSlot2 ? `
            <div style="background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; padding:12px;">
              <div style="display:flex; align-items:center; gap:6px; font-size:11px; font-weight:600; color:#0F172A;">
                <span class="material-symbols-rounded" style="font-size:15px; color:#2563EB;">bedtime</span>
                <span>${slot2Name}</span>
              </div>
              <div style="font-size:11px; color:#64748B; margin-top:6px;">
                ${slot2Start} - ${slot2End}
              </div>
              <div style="font-size:11px; font-weight:700; color:#2563EB; margin-top:4px; display:inline-flex; align-items:center; gap:4px;">
                <span class="material-symbols-rounded" style="font-size:14px; color:#2563EB;">group</span>
                <span>${slot2Count} Registered</span>
              </div>
            </div>
            ` : ''}
          </div>

          <!-- Primary Full-Width Proctor Button matching Flutter 1:1 -->
          <button class="apk-btn-primary" data-view-proctor="${session.id}" style="width:100%; height:46px; border-radius:12px; font-size:12px; font-weight:600; display:flex; align-items:center; justify-content:center; gap:8px; margin-top:16px; background:#2563EB; color:#FFFFFF; box-shadow:0 4px 14px rgba(37,99,235,0.25);">
            <span class="material-symbols-rounded filled" style="font-size:18px;">videocam</span>
            <span>Live Camera Proctor Monitor (අධීක්ෂණ මධ්‍යස්ථානය)</span>
          </button>

          <!-- Secondary Row matching Flutter 1:1 -->
          <div style="display:flex; gap:8px; margin-top:10px; align-items:center;">
            ${!isEnded ? `
              <button data-end-session="${session.id}" style="flex:1; padding:10px; border-radius:10px; border:1px solid #EF4444; background:transparent; color:#EF4444; font-size:11px; font-weight:600; display:flex; align-items:center; justify-content:center; gap:6px; cursor:pointer;">
                <span class="material-symbols-rounded" style="font-size:16px;">stop_circle</span>
                <span>End Session (සැසිය අවසන් කරන්න)</span>
              </button>
              ${isUpcoming ? `
                <button data-start-session="${session.id}" style="padding:10px 14px; border-radius:10px; border:1px solid #22C55E; background:transparent; color:#22C55E; font-size:11px; font-weight:600; display:flex; align-items:center; justify-content:center; gap:6px; cursor:pointer; white-space:nowrap;">
                  <span class="material-symbols-rounded" style="font-size:16px;">play_arrow</span>
                  <span>Start Now</span>
                </button>
              ` : ''}
            ` : `
              <div style="flex:1; padding:8px; border-radius:8px; background:#F1F5F9; border:1px solid #E2E8F0; text-align:center; font-size:11px; color:#64748B; font-weight:500;">
                සැසිය අවසන් කර ඇත (Session Ended)
              </div>
              <button data-reopen-session="${session.id}" style="padding:8px 12px; border-radius:8px; border:none; background:transparent; color:#2563EB; font-size:11px; font-weight:600; display:flex; align-items:center; gap:5px; cursor:pointer;">
                <span class="material-symbols-rounded" style="font-size:16px;">replay</span>
                <span>Reopen</span>
              </button>
            `}
          </div>

          <!-- Student Preview link -->
          <div style="text-align:right; margin-top:10px;">
            <a href="javascript:void(0)" data-student-exam="${session.id}" style="font-size:11px; color:#64748B; text-decoration:none; display:inline-flex; align-items:center; gap:4px;">
              <span class="material-symbols-rounded" style="font-size:14px;">visibility</span>
              <span>Enter Student Exam Room (Preview)</span>
              <span class="material-symbols-rounded" style="font-size:13px;">open_in_new</span>
            </a>
          </div>
        </div>
      </div>
    `;
  }

  _showEditTimesDialog(session, container) {
    const s1Start = this._formatSessionTime(session.slot1?.startTime, '08:30 AM');
    const s1End = this._formatSessionTime(session.slot1?.endTime, '11:40 AM');
    const hasSlot2 = !!(session.slot2 && session.slot2.startTime);
    const s2Start = this._formatSessionTime(session.slot2?.startTime, '04:00 PM');
    const s2End = this._formatSessionTime(session.slot2?.endTime, '07:10 PM');

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';
    modal.innerHTML = `
      <div class="modal-sheet" style="max-height:85vh; overflow-y:auto;">
        <div class="modal-header">
          <div style="font-size:15px; font-weight:700; color:#0F172A;">Change Session Times (වේලාවන් වෙනස් කිරීම)</div>
          <button class="modal-close-btn" id="btn-close-edit-times">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>
        <div style="display:flex; flex-direction:column; gap:14px; margin-top:8px;">
          <div>
            <div style="font-size:12px; font-weight:600; color:#D97706; margin-bottom:6px;">
              ${hasSlot2 ? 'Slot 1 (Morning Session):' : 'Exam Session Times:'}
            </div>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px;">
              <div>
                <div class="form-label" style="font-size:11px;">Start Time:</div>
                <input type="text" id="edit-s1-start" class="form-textarea" style="height:38px;" value="${s1Start}" />
              </div>
              <div>
                <div class="form-label" style="font-size:11px;">End Time:</div>
                <input type="text" id="edit-s1-end" class="form-textarea" style="height:38px;" value="${s1End}" />
              </div>
            </div>
          </div>

          ${hasSlot2 ? `
          <div>
            <div style="font-size:12px; font-weight:600; color:#2563EB; margin-bottom:6px;">
              Slot 2 (Evening Session):
            </div>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px;">
              <div>
                <div class="form-label" style="font-size:11px;">Start Time:</div>
                <input type="text" id="edit-s2-start" class="form-textarea" style="height:38px;" value="${s2Start}" />
              </div>
              <div>
                <div class="form-label" style="font-size:11px;">End Time:</div>
                <input type="text" id="edit-s2-end" class="form-textarea" style="height:38px;" value="${s2End}" />
              </div>
            </div>
          </div>
          ` : ''}

          <div style="display:flex; gap:10px; margin-top:10px;">
            <button class="apk-btn-primary" id="btn-cancel-edit-times" style="flex:1; background:#F1F5F9; color:#475569; box-shadow:none;">
              Cancel
            </button>
            <button class="apk-btn-primary" id="btn-save-edit-times" style="flex:1.5; background:#22C55E;">
              Save Changes
            </button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-edit-times')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-cancel-edit-times')?.addEventListener('click', () => modal.remove());

    document.getElementById('btn-save-edit-times')?.addEventListener('click', async () => {
      const newS1Start = document.getElementById('edit-s1-start')?.value || s1Start;
      const newS1End = document.getElementById('edit-s1-end')?.value || s1End;
      
      const updatedSlot1 = {
        ...(session.slot1 || {}),
        startTime: newS1Start,
        endTime: newS1End
      };

      let updatedSlot2 = null;
      if (hasSlot2) {
        const newS2Start = document.getElementById('edit-s2-start')?.value || s2Start;
        const newS2End = document.getElementById('edit-s2-end')?.value || s2End;
        updatedSlot2 = {
          ...(session.slot2 || {}),
          startTime: newS2Start,
          endTime: newS2End
        };
      }

      await dbService.updateSlotTimes(session.id, { slot1: updatedSlot1, slot2: updatedSlot2 });
      notificationService.showInAppBanner('Times Updated', 'Session Times Updated Successfully!', 'success');
      modal.remove();
      this.renderAdminPapersScreen(container);
    });
  }

  _showDeleteConfirmation(session, container) {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';
    modal.innerHTML = `
      <div class="modal-sheet" style="max-width:360px;">
        <div style="display:flex; align-items:center; gap:10px; margin-bottom:12px;">
          <div style="background:rgba(239,68,68,0.15); color:#EF4444; width:36px; height:36px; border-radius:10px; display:flex; align-items:center; justify-content:center;">
            <span class="material-symbols-rounded" style="font-size:20px;">delete</span>
          </div>
          <div style="font-size:16px; font-weight:700; color:#0F172A;">Delete Session?</div>
        </div>
        <div style="font-size:12.5px; color:#475569; line-height:1.5;">
          Are you sure you want to delete this paper session?
        </div>
        <div style="margin-top:10px; padding:10px; background:#F8FAFC; border:1px solid #E2E8F0; border-radius:8px;">
          <div style="font-size:13px; font-weight:700; color:#0F172A;">${session.title}</div>
          <div style="font-size:11px; color:#64748B; margin-top:2px;">${session.subject || 'Physics'} • ${session.examYear || '2027 A/L'}</div>
        </div>
        <div style="display:flex; gap:10px; margin-top:16px;">
          <button class="apk-btn-primary" id="btn-cancel-delete" style="flex:1; background:#F1F5F9; color:#475569; box-shadow:none;">
            Cancel
          </button>
          <button class="apk-btn-primary" id="btn-confirm-delete" style="flex:1; background:#EF4444;">
            Delete
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-cancel-delete')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-confirm-delete')?.addEventListener('click', async () => {
      await dbService.deletePaperSession(session.id);
      notificationService.showInAppBanner('Session Deleted', 'Paper Session එක සාර්ථකව මකා දමන ලදී (Deleted).', 'warning');
      modal.remove();
      this.renderAdminPapersScreen(container);
    });
  }

  _showEndSessionConfirmation(session, container) {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';
    modal.innerHTML = `
      <div class="modal-sheet" style="max-width:380px;">
        <div style="display:flex; align-items:center; gap:10px; margin-bottom:12px;">
          <div style="background:rgba(239,68,68,0.15); color:#EF4444; width:36px; height:36px; border-radius:10px; display:flex; align-items:center; justify-content:center;">
            <span class="material-symbols-rounded" style="font-size:20px;">warning</span>
          </div>
          <div style="font-size:16px; font-weight:700; color:#0F172A;">End Paper Session?</div>
        </div>
        <div style="font-size:12px; color:#475569; line-height:1.5;">
          ඔබට මෙම Paper Session එක අවසන් කිරීමට අවශ්‍ය බව සහතිකද?<br><br>
          සැසිය අවසන් කළ පසු සිසුන්ට විභාග කාමරයට පිවිසීමට හෝ නව පිළිතුරු පත්‍ර Submit කිරීමට නොහැක.
        </div>
        <div style="display:flex; gap:10px; margin-top:16px;">
          <button class="apk-btn-primary" id="btn-cancel-end" style="flex:1; background:#F1F5F9; color:#475569; box-shadow:none;">
            Cancel
          </button>
          <button class="apk-btn-primary" id="btn-confirm-end" style="flex:1.4; background:#EF4444;">
            End Session (අවසන් කරන්න)
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-cancel-end')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-confirm-end')?.addEventListener('click', async () => {
      await dbService.endPaperSession(session.id);
      notificationService.showInAppBanner('Session Ended', 'Paper Session එක සාර්ථකව අවසන් කරන ලදී (Session Ended).', 'info');
      modal.remove();
      this.renderAdminPapersScreen(container);
    });
  }

  async _startSessionNow(session, container) {
    await dbService.startPaperSession(session.id);
    notificationService.showInAppBanner('Session Live', 'සැසිය සක්‍රීය කරන ලදී (Session is now Live)!', 'success');
    this.renderAdminPapersScreen(container);
  }

  async _reopenSession(session, container) {
    await dbService.reopenPaperSession(session.id);
    notificationService.showInAppBanner('Session Reopened', 'සැසිය නැවත සක්‍රීය කරන ලදී (Session Re-opened).', 'info');
    this.renderAdminPapersScreen(container);
  }

  _buildAdminUpcomingPapersHTML(papers, loadError = false) {
    if (loadError) return `<div class="leaderboard-state" role="status"><span class="material-symbols-rounded">cloud_off</span><strong>Upcoming papers unavailable</strong><span>Check the connection and try again.</span><button class="leaderboard-retry-btn" id="btn-admin-upcoming-retry" type="button">Retry</button></div>`;
    if (!papers.length) return `<div class="leaderboard-state" role="status"><span class="material-symbols-rounded">event_busy</span><strong>No upcoming papers published</strong><span>When an administrator publishes a paper, it will appear here.</span></div>`;
    const escapeHTML = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
    const formatDate = (value) => new Date(value).toLocaleString(undefined, { year: 'numeric', month: 'long', day: '2-digit', hour: '2-digit', minute: '2-digit' });
    return `<div class="admin-upcoming-papers-list">
      ${papers.map((paper) => `
        <article class="hero-card admin-upcoming-paper-card">
          <div class="admin-upcoming-paper-tags"><span>${escapeHTML(paper.subject)} · ${escapeHTML(paper.examYear)}</span><span>${escapeHTML(paper.status)}</span></div>
          <h3>${escapeHTML(paper.title)}</h3>
          <div class="admin-upcoming-paper-meta"><span class="material-symbols-rounded">calendar_today</span>${escapeHTML(formatDate(paper.scheduledDate))}<span>·</span><span>${Number(paper.durationMinutes) || 180} mins</span></div>
          ${paper.paperStructure ? `<p>${escapeHTML(paper.paperStructure)}</p>` : ''}
          ${paper.syllabusTopics?.length ? `<div class="admin-upcoming-topics">${paper.syllabusTopics.map((topic) => `<span>${escapeHTML(topic)}</span>`).join('')}</div>` : ''}
          ${paper.hints ? `<div class="admin-paper-hints"><strong><span class="material-symbols-rounded">lightbulb</span> Special Paper Hints &amp; Guidance</strong><p>${escapeHTML(paper.hints)}</p></div>` : ''}
          ${paper.instructions ? `<p class="admin-upcoming-instructions">${escapeHTML(paper.instructions)}</p>` : ''}
        </article>
      `).join('')}
    </div>`;
  }

  _buildAdminPaperLeaderboardHTML(boards, loadError, selectedBatch) {
    const escapeHTML = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[char]);
    if (loadError) return `
      <div class="leaderboard-state" role="status">
        <span class="material-symbols-rounded">cloud_off</span>
        <strong>Paper results unavailable</strong>
        <span>Check the connection and retry.</span>
        <button class="leaderboard-retry-btn" id="btn-admin-paper-results-retry" type="button">Retry</button>
      </div>`;
    if (!boards.length) return `
      <div class="leaderboard-state" role="status">
        <span class="material-symbols-rounded">military_tech</span>
        <strong>No published paper results for ${escapeHTML(selectedBatch)}</strong>
        <span>Published evaluations will appear here.</span>
      </div>`;
    this.adminExpandedPaperBoards ??= new Set();
    if (!this.adminPaperBoardsInitialized) {
      this.adminExpandedPaperBoards.add(boards[0].id);
      this.adminPaperBoardsInitialized = true;
    }

    return `<div class="paper-results-list admin-paper-results-list">
      ${boards.map((board, index) => {
        const entries = board.entries || [];
        const expanded = this.adminExpandedPaperBoards.has(board.id);
        const published = board.publishedAt.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
        return `<article class="paper-board-card ${index === 0 ? 'is-latest' : ''}">
          <button class="paper-board-header" type="button" data-admin-paper-board="${escapeHTML(board.id)}" aria-expanded="${expanded}">
            <span class="paper-board-heading-content">
              <span class="paper-board-tag">${escapeHTML(board.subject)} · ${escapeHTML(board.examYear)}</span>
              ${index === 0 ? '<span class="paper-latest-tag">LATEST</span>' : ''}
              <span class="paper-board-date">${escapeHTML(published)}</span>
              <strong class="paper-board-title">${escapeHTML(board.paperTitle)}</strong>
              <span class="paper-board-stats"><span>Max: ${board.totalMarks} marks</span><span>${entries.length} candidates</span></span>
              ${!expanded && entries[0] ? `<span class="paper-winner-snippet">Rank 1: ${escapeHTML(entries[0].studentName)} (${entries[0].marks} marks · ${escapeHTML(entries[0].grade)})</span>` : ''}
            </span>
            <span class="material-symbols-rounded paper-expand-icon">${expanded ? 'expand_less' : 'expand_more'}</span>
          </button>
          ${expanded ? `<div class="paper-results-content">
            <div class="paper-results-list-heading">Full Candidate Rankings <span>${entries.length} ranked</span></div>
            ${entries.length ? entries.map((entry) => `
              <div class="paper-result-row">
                <span class="paper-result-rank">#${entry.rank}</span>
                <span class="paper-result-name">${escapeHTML(entry.studentName)}</span>
                <span class="grade-badge grade-${escapeHTML(entry.grade)}">${escapeHTML(entry.grade)}</span>
                <strong class="paper-result-marks">${entry.marks} / ${board.totalMarks}</strong>
              </div>
            `).join('') : '<div class="paper-results-empty">No candidate records published yet.</div>'}
          </div>` : ''}
        </article>`;
      }).join('')}
    </div>`;
  }

  // 3. Admin Sprints Screen (admin_mcq_sprint_screen.dart)
  async renderAdminSprintsScreen(container) {
    this.adminSprintTab = this.adminSprintTab ?? 0; // 0: Sprint Sets, 1: Live Leaderboard
    this.adminSprintDate = this.adminSprintDate || new Date().toISOString().split('T')[0];

    const dateStr = this.adminSprintDate;
    let dailySprints = [];
    let dailySprintsError = false;
    if (this.adminSprintTab === 0) {
      try {
        dailySprints = await dbService.getDailySprints();
      } catch (error) {
        console.warn('[Admin sprints] Sprint sets could not be loaded:', error?.code || 'unknown');
        dailySprintsError = true;
      }
    }
    let sprintAttempts = [];
    let sprintAttemptsError = false;
    if (this.adminSprintTab === 1) {
      try {
        sprintAttempts = await dbService.getSprintAttempts(dateStr);
      } catch (error) {
        console.warn('[Admin sprints] Attempts could not be loaded:', error?.code || 'unknown');
        sprintAttemptsError = true;
      }
    }

    container.innerHTML = `
      <!-- Screen AppBar -->
      <div class="apk-screen-appbar">
        <div class="apk-appbar-left">
          <div style="font-size:16px; font-weight:800; color:#0F172A; display:flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded filled" style="font-size:20px; color:#EA580C;">local_fire_department</span> Daily MCQ Sprints
          </div>
        </div>
        <div class="apk-appbar-actions">
          <button class="apk-icon-action-btn" id="btn-pick-sprint-date" title="Pick Date">
            <span class="material-symbols-rounded" style="font-size:18px;">calendar_today</span>
          </button>
        </div>
      </div>

      <!-- Underline Tabs -->
      <div class="apk-tabbar-underline">
        <button class="apk-tabbar-tab ${this.adminSprintTab === 0 ? 'active' : ''}" data-sprint-tab="0">
          <span class="material-symbols-rounded" style="font-size:18px;">quiz</span> Sprint Sets (දවසේ 5)
        </button>
        <button class="apk-tabbar-tab ${this.adminSprintTab === 1 ? 'active' : ''}" data-sprint-tab="1">
          <span class="material-symbols-rounded" style="font-size:18px;">leaderboard</span> Live Leaderboard
        </button>
      </div>

      <!-- Tab Content Area -->
      <div id="admin-sprint-content" style="padding-bottom:90px;">
        ${this.adminSprintTab === 0 ? this._buildAdminSprintsTabHTML(dateStr, dailySprints, dailySprintsError) : this._buildAdminSprintLeaderboardHTML(dateStr, sprintAttempts, sprintAttemptsError)}
      </div>
    `;

    // Render FAB strictly inside the contained admin-fab-slot
    const fabSlot = document.getElementById('admin-fab-slot');
    if (fabSlot) {
      fabSlot.innerHTML = `
        <button class="apk-fab-button" id="btn-fab-create-sprint">
          <span class="material-symbols-rounded" style="font-size:18px;">add</span> Create 5-MCQ Sprint
        </button>
      `;
    }

    // Tab Switcher
    container.querySelectorAll('[data-sprint-tab]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.adminSprintTab = Number(btn.dataset.sprintTab);
        this.renderAdminSprintsScreen(container);
      });
    });
    document.getElementById('btn-admin-sprint-retry')?.addEventListener('click', () => {
      this.renderAdminSprintsScreen(container);
    });
    document.getElementById('btn-admin-sprints-retry')?.addEventListener('click', () => {
      this.renderAdminSprintsScreen(container);
    });

    // Date Picker action
    const pickDateAction = () => {
      const newDate = prompt('Enter viewing date (YYYY-MM-DD):', this.adminSprintDate);
      if (newDate && /^\d{4}-\d{2}-\d{2}$/.test(newDate)) {
        this.adminSprintDate = newDate;
        this.renderAdminSprintsScreen(container);
      }
    };
    document.getElementById('btn-pick-sprint-date')?.addEventListener('click', pickDateAction);
    document.getElementById('btn-change-sprint-date')?.addEventListener('click', pickDateAction);

    container.querySelectorAll('[data-delete-daily-sprint]').forEach((button) => {
      button.addEventListener('click', async () => {
        if (!confirm('Delete this published sprint? Students will no longer be able to open it.')) return;
        await dbService.deleteDailySprint(button.dataset.deleteDailySprint);
        this.renderAdminSprintsScreen(container);
      });
    });

    // Create Sprint FAB
    document.getElementById('btn-fab-create-sprint')?.addEventListener('click', () => {
      this.openCreateSprintSheet();
    });
  }

  _buildAdminSprintsTabHTML(dateStr, sprints, loadError = false) {
    if (loadError) return `
      <div class="leaderboard-state" role="status">
        <span class="material-symbols-rounded">cloud_off</span>
        <strong>Sprint sets unavailable</strong>
        <span>Check the connection and try again.</span>
        <button class="leaderboard-retry-btn" id="btn-admin-sprints-retry" type="button">Retry</button>
      </div>`;

    return `
      <!-- Date Filter Bar -->
      <div style="margin:16px 16px 14px; padding:12px 16px; background:#FFFFFF; border-radius:14px; border:1px solid #E2E8F0; display:flex; justify-content:space-between; align-items:center; box-shadow:0 1px 3px rgba(0,0,0,0.03);">
        <div style="display:flex; align-items:center; gap:8px;">
          <span class="material-symbols-rounded" style="font-size:18px; color:#2563EB;">calendar_today</span>
          <span style="font-size:13.5px; font-weight:700; color:#0F172A;">Viewing: ${dateStr}</span>
        </div>
        <button id="btn-change-sprint-date" style="background:none; border:none; color:#2563EB; font-weight:700; font-size:12.5px; cursor:pointer; display:flex; align-items:center; gap:4px;">
          <span class="material-symbols-rounded" style="font-size:16px;">calendar_today</span> Change
        </button>
      </div>

      <!-- Sprints Content -->
      ${sprints.length === 0 ? `
        <div style="margin:0 16px; padding:28px 20px; background:#FFFFFF; border-radius:16px; border:1px solid #E2E8F0; text-align:center; display:flex; flex-direction:column; align-items:center; gap:10px; box-shadow:0 1px 3px rgba(0,0,0,0.02);">
          <span class="material-symbols-rounded" style="font-size:44px; color:#94A3B8;">note_alt</span>
          <div style="font-size:15.5px; font-weight:800; color:#0F172A;">No MCQ Sprints Published Yet</div>
          <div style="font-size:12.5px; color:#64748B; max-width:320px; line-height:1.45;">
            Published five-question sprint sets for all batches will appear here.
          </div>
        </div>
      ` : `
        <div style="display:flex; flex-direction:column; gap:12px; padding:0 16px;">
          ${sprints.map(s => `
            <div class="hero-card" style="padding:16px; border: 1.5px solid #2563EB; background: rgba(37,99,235,0.04);">
              <div style="display:flex; justify-content:space-between; align-items:center;">
                <span style="font-size:12px; font-weight:800; color:#2563EB; display:inline-flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:14px; color:#EA580C;">local_fire_department</span> ${s.examYear}
                </span>
                <span style="font-size:11px; background:${s.targetDate === dateStr ? '#DCFCE7' : '#F1F5F9'}; color:${s.targetDate === dateStr ? '#166534' : '#475569'}; padding:2px 8px; border-radius:10px; font-weight:800;">${s.targetDate === dateStr ? 'TODAY' : s.targetDate}</span>
              </div>
              <div style="font-size:15px; font-weight:800; color:#0F172A; margin-top:6px;">${s.title}</div>
              <div style="font-size:12px; color:#64748B; margin-top:2px;">${s.targetDate} • ${s.subject || 'Physics'} (${s.unit || 'General'}) • ${(s.questions || []).length} Questions</div>
              <details style="margin-top:10px;">
                <summary style="cursor:pointer; color:#2563EB; font-size:12px; font-weight:700;">Review questions</summary>
                <div style="display:flex; flex-direction:column; gap:8px; margin-top:8px;">
                  ${(s.questions || []).map((question, index) => `
                    <div style="padding:10px; border-radius:10px; background:#F8FAFC; font-size:11px;">
                      <strong>Q${index + 1}: ${String(question.question || '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char])}</strong>
                      ${(question.options || []).map((option, optionIndex) => `<div style="margin-top:4px; color:${optionIndex === Number(question.correctIndex) ? '#047857' : '#475569'};">${optionIndex === Number(question.correctIndex) ? '✓ ' : ''}${String(option).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char])}</div>`).join('')}
                      ${question.explanation ? `<small style="display:block; margin-top:6px; color:#64748B;">${String(question.explanation).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char])}</small>` : ''}
                    </div>
                  `).join('')}
                </div>
              </details>
              <button class="apk-icon-action-btn" type="button" data-delete-daily-sprint="${s.id}" title="Delete sprint" style="margin-top:10px; color:#EF4444;"><span class="material-symbols-rounded">delete</span> Delete</button>
            </div>
          `).join('')}
        </div>
      `}
    `;
  }

  _buildAdminSprintLeaderboardHTML(dateStr, attempts, loadError = false) {
    if (loadError) return `
      <div class="leaderboard-state" role="status">
        <span class="material-symbols-rounded">cloud_off</span>
        <strong>Sprint results unavailable</strong>
        <span>Check your connection and try again.</span>
        <button class="leaderboard-retry-btn" id="btn-admin-sprint-retry" type="button">Retry</button>
      </div>`;
    if (!attempts.length) return `
      <div class="leaderboard-state" role="status">
        <span class="material-symbols-rounded">emoji_events</span>
        <strong>No completions for ${dateStr} yet</strong>
        <span>Students who complete this sprint will appear here.</span>
      </div>`;

    return `<div class="admin-sprint-rank-list">
      ${attempts.map((attempt, index) => {
        const rank = index + 1;
        const medal = rank === 1 ? 'emoji_events' : (rank <= 3 ? 'military_tech' : 'tag');
        return `<article class="admin-sprint-rank-row ${rank <= 3 ? 'is-top-rank' : ''}">
          <span class="admin-sprint-medal material-symbols-rounded ${rank <= 3 ? 'filled' : ''}">${medal}</span>
          <span class="admin-sprint-avatar">${String(attempt.studentName || 'S').charAt(0).toUpperCase()}</span>
          <span class="admin-sprint-student">
            <strong>${String(attempt.studentName || 'Student').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char])}</strong>
            <small>${String(attempt.phone || '').replace(/[&<>"']/g, '')} · ${String(attempt.timeTakenFormatted || `${Number(attempt.timeTakenSeconds) || 0}s`).replace(/[&<>"']/g, '')}</small>
          </span>
          <span class="admin-sprint-score"><strong>${Number(attempt.score) || 0} / ${Number(attempt.totalQuestions) || 0}</strong><small>+${Number(attempt.xpEarned) || 0} XP</small></span>
        </article>`;
      }).join('')}
    </div>`;
  }

  // 4. Admin Students Screen (admin_students_screen.dart)
  async renderAdminStudentsScreen(container) {
    this.adminStudentBatchFilter = this.adminStudentBatchFilter || 'All';
    this.adminStudentSearchQuery = this.adminStudentSearchQuery || '';

    const allStudents = await dbService.getAllStudents();

    let filtered = allStudents;
    if (this.adminStudentBatchFilter !== 'All') {
      filtered = filtered.filter(s => (s.examYear || '').trim().toLowerCase() === this.adminStudentBatchFilter.trim().toLowerCase());
    }
    if (this.adminStudentSearchQuery.trim()) {
      const q = this.adminStudentSearchQuery.toLowerCase();
      filtered = filtered.filter(s =>
        (s.name || '').toLowerCase().includes(q) ||
        (s.phone || '').includes(q) ||
        (s.studentId || '').toLowerCase().includes(q)
      );
    }

    const batches = ['All', '2024 A/L', '2025 A/L', '2026 A/L', '2027 A/L', '2028 A/L', '2029 A/L'];

    container.innerHTML = `
      <!-- Screen AppBar -->
      <div class="apk-screen-appbar">
        <div class="apk-appbar-left">
          <div style="font-size:16px; font-weight:800; color:#0F172A; display:flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded" style="font-size:20px; color:#2563EB;">group</span> Registered Students
          </div>
        </div>
      </div>

      <!-- Summary Stats & Search Header matching Screenshot 5 -->
      <div style="background:#FFFFFF; padding:12px 16px 14px; border-bottom:1px solid #E2E8F0;">
        <!-- Stats Row -->
        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-bottom:12px;">
          <div style="background:#F1F5F9; border-radius:12px; padding:10px 14px; display:flex; align-items:center; gap:10px;">
            <span class="material-symbols-rounded" style="font-size:20px; color:#2563EB;">group</span>
            <div>
              <div style="font-size:10.5px; color:#64748B; font-weight:600;">Total Students</div>
              <div style="font-size:16px; font-weight:800; color:#0F172A;">${allStudents.length}</div>
            </div>
          </div>
          <div style="background:#F1F5F9; border-radius:12px; padding:10px 14px; display:flex; align-items:center; gap:10px;">
            <span class="material-symbols-rounded filled" style="font-size:20px; color:#6366F1;">flash_on</span>
            <div>
              <div style="font-size:10.5px; color:#64748B; font-weight:600;">Showing</div>
              <div style="font-size:16px; font-weight:800; color:#0F172A;">${filtered.length}</div>
            </div>
          </div>
        </div>

        <!-- Search Field -->
        <div class="apk-search-bar" style="margin-bottom:10px;">
          <span class="material-symbols-rounded apk-search-icon" style="font-size:18px;">search</span>
          <input type="text" id="input-admin-student-search" placeholder="Search by name, phone or ID..." value="${this.adminStudentSearchQuery}">
        </div>

        <!-- Batch Filter Chips -->
        <div class="apk-chips-scroll-row">
          ${batches.map(b => {
            const isSel = this.adminStudentBatchFilter === b;
            return `
              <button class="apk-filter-chip ${isSel ? 'active' : ''}" data-batch="${b}">
                ${isSel ? '<span class="material-symbols-rounded" style="font-size:14px; vertical-align:middle;">check</span> ' : ''}${b}
              </button>
            `;
          }).join('')}
        </div>
      </div>

      <!-- Students List View -->
      <div id="admin-students-list" style="padding:16px; padding-bottom:90px;">
        ${filtered.length === 0 ? `
          <!-- Empty State matching Screenshot 5 -->
          <div style="padding:70px 20px; text-align:center; display:flex; flex-direction:column; align-items:center; gap:10px;">
            <span class="material-symbols-rounded" style="font-size:44px; color:#94A3B8;">search</span>
            <div style="font-size:16px; font-weight:800; color:#0F172A;">
              ${allStudents.length === 0 ? 'No students registered yet' : 'No students found matching filters'}
            </div>
            <div style="font-size:13px; color:#64748B; max-width:320px; line-height:1.45;">
              When students register with phone number, they appear here.
            </div>
          </div>
        ` : `
          <div style="display:flex; flex-direction:column; gap:10px;">
            ${filtered.map(st => `
              <div class="admin-student-card" style="padding:14px; background:#FFFFFF; border-radius:14px; border:1px solid #E2E8F0; display:flex; justify-content:space-between; align-items:center;">
                <div style="display:flex; align-items:center; gap:12px;">
                  <div class="admin-sub-avatar" style="width:40px; height:40px; font-size:16px;">${(st.name || 'S').charAt(0).toUpperCase()}</div>
                  <div>
                    <div style="font-size:14px; font-weight:800; color:#0F172A;">${st.name || 'Student'}</div>
                    <div style="font-size:11.5px; color:#64748B;">${st.phone || 'No phone'} • <span style="color:#2563EB; font-weight:700;">${st.examYear || '2026 A/L'}</span></div>
                  </div>
                </div>

                <div style="display:flex; align-items:center; gap:8px;">
                  <button class="apk-icon-action-btn" title="Send Custom Message" data-msg-student="${st.id}" style="color:#2563EB; font-size:16px;">
                    <span class="material-symbols-rounded filled" style="font-size:18px;">send</span>
                  </button>
                  <button class="apk-icon-action-btn" title="Delete Account" data-delete-student="${st.id}" style="color:#EF4444; font-size:16px;">
                    <span class="material-symbols-rounded" style="font-size:18px;">delete</span>
                  </button>
                </div>
              </div>
            `).join('')}
          </div>
        `}
      </div>
    `;

    // Search Input event
    document.getElementById('input-admin-student-search')?.addEventListener('input', (e) => {
      this.adminStudentSearchQuery = e.target.value;
      this.renderAdminStudentsScreen(container);
    });

    // Batch Chips events
    container.querySelectorAll('[data-batch]').forEach(chip => {
      chip.addEventListener('click', () => {
        this.adminStudentBatchFilter = chip.dataset.batch;
        this.renderAdminStudentsScreen(container);
      });
    });

    // Custom Message
    container.querySelectorAll('[data-msg-student]').forEach(btn => {
      btn.addEventListener('click', () => {
        const st = allStudents.find(x => x.id === btn.dataset.msgStudent);
        if (st) this.openSendCustomMessageModal(st);
      });
    });

    // Delete Student
    container.querySelectorAll('[data-delete-student]').forEach(btn => {
      btn.addEventListener('click', () => {
        const st = allStudents.find(x => x.id === btn.dataset.deleteStudent);
        if (st) this.confirmDeleteStudent(st);
      });
    });
  }

  // 5. Admin Broadcasts Screen (admin_announcements_screen.dart)
  renderAdminBroadcastsScreen(container) {
    this.broadcastLogs = this.broadcastLogs || [
      { id: 1, title: 'Exam Hall Open', message: 'Morning session for Model Paper 04 is now open for students.', time: '1 hour ago' },
      { id: 2, title: 'New Homework Feedback', message: 'Wave Optics submissions have been evaluated and XP awarded.', time: 'Yesterday' }
    ];

    container.innerHTML = `
      <div class="apk-screen-appbar">
        <div class="apk-appbar-left">
          <div style="font-size:16px; font-weight:800; color:#0F172A; display:flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded filled" style="font-size:20px; color:#0284C7;">campaign</span> Push Broadcaster & Telegram
          </div>
        </div>
      </div>

      <div style="padding:16px 16px 90px;">
        <div class="hero-card" style="padding:16px;">
          <div class="form-label">Announcement Title:</div>
          <input type="text" id="bc-title" class="form-textarea" style="height:40px; margin-bottom:10px;" placeholder="e.g. Paper 04 Live Exam Started!" />

          <div class="form-label">Notification Message Body:</div>
          <textarea id="bc-body" class="form-textarea" rows="3" style="margin-bottom:10px;" placeholder="Enter message to broadcast to all student home screens & Telegram..."></textarea>

          <div class="form-label">Target Audience:</div>
          <select id="bc-audience" class="form-textarea" style="height:40px; margin-bottom:14px; padding:6px 10px;">
            <option value="All Batches">All Enrolled Batches</option>
            <option value="2026 A/L">2026 A/L Batch Only</option>
            <option value="2027 A/L">2027 A/L Batch Only</option>
          </select>

          <button class="apk-btn-primary" id="btn-send-broadcast" style="width:100%; padding:14px; font-size:14px; display:inline-flex; align-items:center; justify-content:center; gap:8px;">
            <span class="material-symbols-rounded filled" style="font-size:18px;">send</span> Send Instant Broadcast
          </button>
        </div>

        <div style="font-size:13.5px; font-weight:800; color:#0F172A; margin:18px 0 10px; display:flex; align-items:center; gap:6px;">
          <span class="material-symbols-rounded" style="font-size:18px; color:#64748B;">history</span> Recent Broadcasts Sent:
        </div>

        <div style="display:flex; flex-direction:column; gap:8px;">
          ${this.broadcastLogs.map(b => `
            <div class="hero-card" style="padding:12px 14px;">
              <div style="display:flex; justify-content:space-between; align-items:center;">
                <span style="font-size:13px; font-weight:800; color:#0F172A;">${b.title}</span>
                <span style="font-size:10.5px; color:#64748B;">${b.time}</span>
              </div>
              <div style="font-size:11.5px; color:#475569; margin-top:4px;">${b.message}</div>
            </div>
          `).join('')}
        </div>
      </div>
    `;

    document.getElementById('btn-send-broadcast')?.addEventListener('click', () => {
      const title = document.getElementById('bc-title')?.value;
      const body = document.getElementById('bc-body')?.value;

      if (!title || !body) {
        alert('Please fill in both title and message body.');
        return;
      }

      this.broadcastLogs.unshift({
        id: Date.now(),
        title,
        message: body,
        time: 'Just now'
      });

      notificationService.playChime();
      notificationService.showInAppBanner(title, body, 'info');

      alert('Broadcast successfully dispatched to all student devices via Web Push and Telegram!');
      this.renderAdminBroadcastsScreen(container);
    });
  }

  // ── Helper Modal Dialogs ───────────────────────────────────────────────
  async openAdminDailyInsightModal() {
    const current = await dbService.getDailyInsight();
    const presets = dbService.getPresetPhysicsInsights();

    let isCustom = current.isCustom || false;
    let selectedPresetIdx = isCustom ? -1 : 0;

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    const renderModalContent = () => {
      modal.innerHTML = `
        <div class="modal-sheet" style="max-height:90vh; overflow-y:auto; padding:18px;">
          <div class="modal-header" style="border-bottom:1px solid #E2E8F0; padding-bottom:12px; margin-bottom:14px;">
            <div style="display:flex; align-items:center; gap:10px;">
              <div style="width:38px; height:38px; border-radius:12px; background:rgba(16, 185, 129, 0.12); display:flex; align-items:center; justify-content:center; color:#10B981;">
                <span class="material-symbols-rounded" style="font-size:22px;">science</span>
              </div>
              <div>
                <div style="font-size:16px; font-weight:800; color:#0F172A;">Daily Physics Insight Manager</div>
                <div style="font-size:11px; color:#64748B;">Control formula rotation & custom pinned concepts for students</div>
              </div>
            </div>
            <button class="modal-close-btn" id="btn-close-insight-modal">
              <span class="material-symbols-rounded">close</span>
            </button>
          </div>

          <!-- Mode Toggle Cards (1:1 with Flutter _isCustomMode) -->
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-bottom:16px;">
            <div id="btn-mode-random" style="border:2px solid ${!isCustom ? '#10B981' : '#E2E8F0'}; background:${!isCustom ? '#ECFDF5' : '#FFFFFF'}; padding:12px; border-radius:14px; cursor:pointer; transition:all 0.2s;">
              <div style="display:flex; align-items:center; gap:6px;">
                <span class="material-symbols-rounded" style="font-size:18px; color:${!isCustom ? '#065F46' : '#475569'};">sync</span>
                <span style="font-size:12.5px; font-weight:700; color:${!isCustom ? '#065F46' : '#475569'};">Random Mode</span>
              </div>
              <div style="font-size:10.5px; color:${!isCustom ? '#047857' : '#94A3B8'}; margin-top:4px; line-height:1.35;">Auto-rotates daily across 10 official A/L formula presets.</div>
            </div>

            <div id="btn-mode-custom" style="border:2px solid ${isCustom ? '#2563EB' : '#E2E8F0'}; background:${isCustom ? '#EFF6FF' : '#FFFFFF'}; padding:12px; border-radius:14px; cursor:pointer; transition:all 0.2s;">
              <div style="display:flex; align-items:center; gap:6px;">
                <span class="material-symbols-rounded" style="font-size:18px; color:${isCustom ? '#1E40AF' : '#475569'};">push_pin</span>
                <span style="font-size:12.5px; font-weight:700; color:${isCustom ? '#1E40AF' : '#475569'};">Custom Pinned</span>
              </div>
              <div style="font-size:10.5px; color:${isCustom ? '#1D4ED8' : '#94A3B8'}; margin-top:4px; line-height:1.35;">Pin a specific formula, concept, or exam tip for all students.</div>
            </div>
          </div>

          ${isCustom ? `
            <!-- Preset Selector (lines 89-102 of Flutter) -->
            <div style="background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; padding:12px; margin-bottom:14px;">
              <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
                <span style="font-size:11.5px; font-weight:700; color:#334155; display:inline-flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:16px; color:#F59E0B;">flash_on</span> Preload From Curated Presets:
                </span>
                <span style="font-size:10px; color:#64748B;">10 Official Presets</span>
              </div>
              <select id="preset-select" class="form-textarea" style="height:38px; padding:6px 10px; font-size:12px;">
                <option value="-1">-- Choose a concept preset to populate --</option>
                ${presets.map((p, idx) => `
                  <option value="${idx}" ${selectedPresetIdx === idx ? 'selected' : ''}>${p.unitSinhala} • ${p.titleSinhala} (${p.titleEnglish})</option>
                `).join('')}
              </select>
            </div>

            <!-- Form Fields -->
            <div style="display:flex; flex-direction:column; gap:10px; margin-bottom:16px;">
              <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px;">
                <div>
                  <div class="form-label">මාතෘකාව (Sinhala Title):</div>
                  <input type="text" id="ins-title-si" class="form-textarea" style="height:38px;" value="${current.titleSinhala || ''}" placeholder="උදා: කාර්යය-ශක්ති ප්‍රමේයය" />
                </div>
                <div>
                  <div class="form-label">Concept (English Title):</div>
                  <input type="text" id="ins-title-en" class="form-textarea" style="height:38px;" value="${current.titleEnglish || ''}" placeholder="e.g. Work-Energy Theorem" />
                </div>
              </div>

              <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px;">
                <div>
                  <div class="form-label">පාඩම (Sinhala Unit):</div>
                  <input type="text" id="ins-unit-si" class="form-textarea" style="height:38px;" value="${current.unitSinhala || 'යාන්ත්‍ර විද්‍යාව'}" />
                </div>
                <div>
                  <div class="form-label">Physics Unit (English):</div>
                  <input type="text" id="ins-unit-en" class="form-textarea" style="height:38px;" value="${current.unitEnglish || 'Mechanics'}" />
                </div>
              </div>

              <div>
                <div class="form-label">භෞතික විද්‍යා සූත්‍රය (Physics Formula):</div>
                <input type="text" id="ins-formula" class="form-textarea" style="height:42px; font-family:monospace; font-weight:700; color:#1E3A8A; background:#EFF6FF; border-color:#BFDBFE;" value="${current.formula || ''}" placeholder="e.g. W_net = ΔK = ½ m v² - ½ m u²" />
              </div>

              <div>
                <div class="form-label">විභාග උපදෙස (Sinhala Exam Tip):</div>
                <textarea id="ins-tip-si" class="form-textarea" style="height:55px; resize:none;" placeholder="සිසුන්ට මතක තබාගත යුතු ප්‍රධාන උපක්‍රමය හෝ ফাঁද...">${current.tipSinhala || ''}</textarea>
              </div>

              <div>
                <div class="form-label">Exam Tip (English Explanation):</div>
                <textarea id="ins-tip-en" class="form-textarea" style="height:55px; resize:none;" placeholder="Important exam nuance or common pitfall in English...">${current.tipEnglish || ''}</textarea>
              </div>
            </div>
          ` : `
            <div style="background:#F0FDF4; border:1px solid #BBF7D0; border-radius:12px; padding:14px; margin-bottom:14px; display:flex; align-items:flex-start; gap:10px;">
              <span class="material-symbols-rounded" style="font-size:22px; color:#166534;">sync</span>
              <div>
                <div style="font-size:13px; font-weight:700; color:#166534;">Daily Random Mode is Currently Active</div>
                <div style="font-size:11px; color:#15803D; margin-top:3px; line-height:1.4;">
                  The system automatically cycles through all 10 core A/L physics formula presets every day at midnight (Sri Lanka Time). Students see a fresh formula and exam tip every single day.
                </div>
              </div>
            </div>
          `}

          <!-- Live Preview Card (Matching Student Cockpit 1:1) -->
          <div style="margin-bottom:16px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
              <span style="font-size:11.5px; font-weight:700; color:#475569; display:inline-flex; align-items:center; gap:4px;">
                <span class="material-symbols-rounded" style="font-size:16px;">visibility</span> Live Student Cockpit Preview:
              </span>
              <span style="font-size:10px; color:#10B981; font-weight:700;">● Pixel-Perfect 1:1</span>
            </div>

            <div class="insight-vault-card" id="ins-preview-card" style="margin:0; box-shadow:0 4px 16px rgba(15,23,42,0.06);">
              <div class="vault-top">
                <div class="vault-pill">
                  <span class="material-symbols-rounded" style="font-size:14px;">science</span>
                  <span>PHYSICS MICRO-INSIGHT</span>
                </div>
                <span class="vault-tag-pill">${isCustom ? '<span class="material-symbols-rounded" style="font-size:12px; vertical-align:middle;">push_pin</span> Custom Pinned' : 'අද දවසේ සූත්‍රය • Daily'}</span>
              </div>
              <div class="vault-topic-meta" id="prev-unit">${current.unitSinhala || 'යාන්ත්‍ර විද්‍යාව'} • ${current.unitEnglish || 'Mechanics'}</div>
              <div class="vault-concept-name" id="prev-title">
                ${current.titleSinhala || 'කාර්යය-ශක්ති ප්‍රමේයය'} <span style="font-size: 12.5px; font-weight:600; color:#64748B;" id="prev-title-en">(${current.titleEnglish || 'Work-Energy Theorem'})</span>
              </div>
              <div class="vault-formula-box" id="prev-formula">
                ${current.formula || 'W_net  =  ΔK  =  ½ m v²  -  ½ m u²'}
              </div>
              <div class="vault-exam-tip-box">
                <div class="tip-header">
                  <span class="material-symbols-rounded filled" style="font-size:16px; color:#D97706;">lightbulb</span>
                  <span>විභාග උපදෙස (Exam Tip):</span>
                </div>
                <div class="tip-sinhala" id="prev-tip-si">
                  ${current.tipSinhala || 'ආනත තලයක චලිතයේදී ඝර්ෂණයට එරෙහි කාර්යය යාන්ත්‍රික ශක්ති සමීකරණයට පෙර වෙන්ව සලකා බලන්න.'}
                </div>
                <div class="tip-english" id="prev-tip-en">
                  En: ${current.tipEnglish || 'Always compute work done against friction separately.'}
                </div>
              </div>
            </div>
          </div>

          <!-- Action Buttons Row -->
          <div style="display:flex; gap:10px;">
            ${isCustom ? `
              <button class="apk-paper-btn-secondary" id="btn-revert-random" style="flex:1; border-color:#EF4444; color:#EF4444; height:44px; display:inline-flex; align-items:center; justify-content:center; gap:6px;">
                <span class="material-symbols-rounded" style="font-size:16px;">sync</span> Revert to Random
              </button>
              <button class="primary-btn" id="btn-save-custom-insight" style="flex:2; height:44px; margin-top:0; display:inline-flex; align-items:center; justify-content:center; gap:6px;">
                <span class="material-symbols-rounded" style="font-size:16px;">save</span> Save & Pin to Students
              </button>
            ` : `
              <button class="apk-paper-btn-secondary" id="btn-switch-custom-mode" style="flex:1; border-color:#2563EB; color:#2563EB; height:44px; display:inline-flex; align-items:center; justify-content:center; gap:6px;">
                <span class="material-symbols-rounded" style="font-size:16px;">edit</span> Switch to Custom Pinned Mode
              </button>
            `}
          </div>
        </div>
      `;

      // Attach Event Listeners
      document.getElementById('btn-close-insight-modal')?.addEventListener('click', () => modal.remove());

      document.getElementById('btn-mode-random')?.addEventListener('click', () => {
        if (isCustom) {
          isCustom = false;
          renderModalContent();
        }
      });

      document.getElementById('btn-mode-custom')?.addEventListener('click', () => {
        if (!isCustom) {
          isCustom = true;
          renderModalContent();
        }
      });

      document.getElementById('btn-switch-custom-mode')?.addEventListener('click', () => {
        isCustom = true;
        renderModalContent();
      });

      document.getElementById('preset-select')?.addEventListener('change', (e) => {
        const idx = parseInt(e.target.value);
        if (idx >= 0 && idx < presets.length) {
          selectedPresetIdx = idx;
          const p = presets[idx];
          current.titleSinhala = p.titleSinhala;
          current.titleEnglish = p.titleEnglish;
          current.unitSinhala = p.unitSinhala;
          current.unitEnglish = p.unitEnglish;
          current.formula = p.formula;
          current.tipSinhala = p.tipSinhala;
          current.tipEnglish = p.tipEnglish;
          current.topicCode = p.topicCode;
          renderModalContent();
        }
      });

      // Live typing updates for preview
      const updatePreview = () => {
        const titleSi = document.getElementById('ins-title-si')?.value || '';
        const titleEn = document.getElementById('ins-title-en')?.value || '';
        const unitSi = document.getElementById('ins-unit-si')?.value || '';
        const unitEn = document.getElementById('ins-unit-en')?.value || '';
        const formula = document.getElementById('ins-formula')?.value || '';
        const tipSi = document.getElementById('ins-tip-si')?.value || '';
        const tipEn = document.getElementById('ins-tip-en')?.value || '';

        const prevTitle = document.getElementById('prev-title');
        if (prevTitle) prevTitle.innerHTML = `${titleSi || 'Formula Title'} <span style="font-size:12.5px; font-weight:600; color:#64748B;">(${titleEn || 'English Concept'})</span>`;
        const prevUnit = document.getElementById('prev-unit');
        if (prevUnit) prevUnit.innerText = `${unitSi} • ${unitEn}`;
        const prevFormula = document.getElementById('prev-formula');
        if (prevFormula) prevFormula.innerText = formula;
        const prevTipSi = document.getElementById('prev-tip-si');
        if (prevTipSi) prevTipSi.innerText = tipSi;
        const prevTipEn = document.getElementById('prev-tip-en');
        if (prevTipEn) prevTipEn.innerText = `En: ${tipEn}`;
      };

      ['ins-title-si', 'ins-title-en', 'ins-unit-si', 'ins-unit-en', 'ins-formula', 'ins-tip-si', 'ins-tip-en'].forEach(id => {
        document.getElementById(id)?.addEventListener('input', updatePreview);
      });

      // Save custom
      document.getElementById('btn-save-custom-insight')?.addEventListener('click', async () => {
        const titleSi = document.getElementById('ins-title-si')?.value.trim();
        const formula = document.getElementById('ins-formula')?.value.trim();
        if (!titleSi || !formula) {
          notificationService.showInAppToast('කරුණාකර මාතෘකාව සහ සූත්‍රය ඇතුළත් කරන්න (Please fill title and formula)', 'warning');
          return;
        }

        const data = {
          titleSinhala: titleSi,
          titleEnglish: document.getElementById('ins-title-en')?.value.trim() || '',
          unitSinhala: document.getElementById('ins-unit-si')?.value.trim() || '',
          unitEnglish: document.getElementById('ins-unit-en')?.value.trim() || '',
          formula: formula,
          tipSinhala: document.getElementById('ins-tip-si')?.value.trim() || '',
          tipEnglish: document.getElementById('ins-tip-en')?.value.trim() || '',
          topicCode: current.topicCode || 'topic_custom'
        };

        const btn = document.getElementById('btn-save-custom-insight');
        btn.innerText = 'Saving to Cloud...';
        btn.disabled = true;

        try {
          await dbService.saveCustomPhysicsInsight(data, this.currentUser?.name || 'Admin');
          notificationService.showInAppToast('Daily Physics Insight successfully pinned to all students!', 'success');
          modal.remove();
        } catch (e) {
          notificationService.showInAppToast('Save error: ' + e.message, 'error');
          btn.innerHTML = '<span class="material-symbols-rounded" style="font-size:16px;">save</span> Save & Pin to Students';
          btn.disabled = false;
        }
      });

      // Revert to Random
      document.getElementById('btn-revert-random')?.addEventListener('click', async () => {
        try {
          await dbService.setRandomPhysicsInsightMode(this.currentUser?.name || 'Admin');
          notificationService.showInAppToast('Successfully reverted to Automatic Daily Random Mode', 'success');
          modal.remove();
        } catch (e) {
          notificationService.showInAppToast('Revert error: ' + e.message, 'error');
        }
      });
    };

    renderModalContent();
    document.body.appendChild(modal);
  }

  // ── Examination Countdowns Manager (1:1 with admin_exam_countdowns_screen.dart) ──
  async openExamCountdownsModal() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    let countdowns = await dbService.getExamCountdowns();
    let timerInterval = null;

    const computeTimeLeft = (targetStr) => {
      const diff = new Date(targetStr).getTime() - Date.now();
      if (diff <= 0) return { days: 0, hours: 0, mins: 0, secs: 0, expired: true };
      const days = Math.floor(diff / (1000 * 60 * 60 * 24));
      const hours = Math.floor((diff / (1000 * 60 * 60)) % 24);
      const mins = Math.floor((diff / 1000 / 60) % 60);
      const secs = Math.floor((diff / 1000) % 60);
      return { days, hours, mins, secs, expired: false };
    };

    const renderCountdownsList = () => {
      modal.innerHTML = `
        <div class="modal-sheet" style="max-height:88vh; overflow-y:auto; padding:18px;">
          <div class="modal-header" style="border-bottom:1px solid #E2E8F0; padding-bottom:12px; margin-bottom:14px;">
            <div style="display:flex; align-items:center; gap:10px;">
              <div style="width:38px; height:38px; border-radius:12px; background:rgba(139, 92, 246, 0.12); display:flex; align-items:center; justify-content:center; color:#8B5CF6;">
                <span class="material-symbols-rounded" style="font-size:20px;">timer</span>
              </div>
              <div>
                <div style="font-size:16px; font-weight:800; color:#0F172A;">G.C.E. A/L Examination Countdowns</div>
                <div style="font-size:11px; color:#64748B;">Target dates & dashboard countdown timer visibility</div>
              </div>
            </div>
            <button class="modal-close-btn" id="btn-close-countdown">
              <span class="material-symbols-rounded">close</span>
            </button>
          </div>

          <div style="display:flex; flex-direction:column; gap:12px;" id="countdowns-list-container">
            ${countdowns.map((c) => {
              const t = computeTimeLeft(c.targetDate);
              const dateFormatted = new Date(c.targetDate).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
              return `
                <div class="hero-card" style="padding:14px; border:1px solid ${c.isEnabled ? '#C7D2FE' : '#E2E8F0'}; background:${c.isEnabled ? '#FFFFFF' : '#F8FAFC'}; box-shadow:0 2px 8px rgba(15,23,42,0.04);" id="card-cd-${c.id}">
                  <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                    <div>
                      <div style="display:flex; align-items:center; gap:8px;">
                        <span style="font-size:13px; font-weight:800; color:#4338CA; background:#EEF2FF; padding:3px 10px; border-radius:8px; border:1px solid #C7D2FE;">${c.examYear}</span>
                        <span style="font-size:13px; font-weight:700; color:#1E293B;">${c.customTitle}</span>
                      </div>
                      <div style="font-size:11px; color:#64748B; margin-top:4px; display:flex; align-items:center; gap:4px;">
                        <span class="material-symbols-rounded" style="font-size:14px; color:#4338CA;">track_changes</span> Target: <strong>${dateFormatted}</strong>
                      </div>
                    </div>

                    <!-- Visibility Toggle (lines 60-70 of Flutter screen) -->
                    <label style="display:flex; align-items:center; gap:6px; cursor:pointer;" title="Toggle visibility for students">
                      <span style="font-size:10.5px; font-weight:600; color:${c.isEnabled ? '#10B981' : '#94A3B8'};">${c.isEnabled ? 'Visible' : 'Hidden'}</span>
                      <input type="checkbox" data-toggle-cd="${c.id}" ${c.isEnabled ? 'checked' : ''} style="width:18px; height:18px; accent-color:#10B981; cursor:pointer;" />
                    </label>
                  </div>

                  <!-- Live Counter Box (Days, Hours, Mins, Secs) -->
                  <div style="display:grid; grid-template-columns:repeat(4, 1fr); gap:8px; margin:12px 0; background:${c.isEnabled ? '#F5F3FF' : '#F1F5F9'}; padding:10px; border-radius:10px; text-align:center;">
                    <div>
                      <div style="font-size:18px; font-weight:900; color:#4F46E5;" id="cd-days-${c.id}">${t.days}</div>
                      <div style="font-size:9.5px; font-weight:700; color:#6366F1; text-transform:uppercase;">Days</div>
                    </div>
                    <div>
                      <div style="font-size:18px; font-weight:900; color:#4F46E5;" id="cd-hours-${c.id}">${t.hours}</div>
                      <div style="font-size:9.5px; font-weight:700; color:#6366F1; text-transform:uppercase;">Hours</div>
                    </div>
                    <div>
                      <div style="font-size:18px; font-weight:900; color:#4F46E5;" id="cd-mins-${c.id}">${t.mins}</div>
                      <div style="font-size:9.5px; font-weight:700; color:#6366F1; text-transform:uppercase;">Mins</div>
                    </div>
                    <div>
                      <div style="font-size:18px; font-weight:900; color:#4F46E5;" id="cd-secs-${c.id}">${t.secs}</div>
                      <div style="font-size:9.5px; font-weight:700; color:#6366F1; text-transform:uppercase;">Secs</div>
                    </div>
                  </div>

                  <!-- Action Bar -->
                  <div style="display:flex; justify-content:space-between; align-items:center; border-top:1px solid #F1F5F9; padding-top:8px;">
                    <div style="font-size:10.5px; color:#94A3B8;">${c.notes || 'Official countdown active for students'}</div>
                    <button class="apk-paper-btn-secondary" data-edit-date="${c.id}" style="padding:4px 10px; font-size:11px; height:30px; border-color:#8B5CF6; color:#8B5CF6; display:inline-flex; align-items:center; gap:4px;">
                      <span class="material-symbols-rounded" style="font-size:14px;">calendar_today</span> Edit Date & Time
                    </button>
                  </div>

                  <!-- Inline Date Picker Box -->
                  <div id="date-picker-box-${c.id}" style="display:none; margin-top:10px; padding:10px; background:#F8FAFC; border:1px solid #CBD5E1; border-radius:10px;">
                    <div style="font-size:11px; font-weight:700; color:#334155; margin-bottom:6px;">Select New Examination Date & Time:</div>
                    <div style="display:flex; gap:8px;">
                      <input type="datetime-local" id="input-dt-${c.id}" class="form-textarea" style="height:36px; font-size:11.5px; flex:1;" value="${new Date(c.targetDate).toISOString().slice(0, 16)}" />
                      <button class="primary-btn" data-save-dt="${c.id}" style="height:36px; padding:0 14px; margin-top:0; font-size:11.5px;">Save</button>
                    </div>
                  </div>
                </div>
              `;
            }).join('')}
          </div>

          <!-- Add New Countdown Button / Form -->
          <div style="margin-top:16px; border-top:1px solid #E2E8F0; padding-top:14px;">
            <button class="apk-paper-btn-secondary" id="btn-toggle-add-cd" style="width:100%; border-color:#8B5CF6; color:#8B5CF6; height:40px; font-weight:700; display:inline-flex; align-items:center; justify-content:center; gap:6px;">
              <span class="material-symbols-rounded" style="font-size:16px;">add</span> Add New Batch Examination Countdown
            </button>
            <div id="add-cd-box" style="display:none; margin-top:12px; background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; padding:12px;">
              <div style="font-size:12px; font-weight:700; color:#1E293B; margin-bottom:8px;">Create New Batch Target:</div>
              <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-bottom:8px;">
                <input type="text" id="new-cd-year" class="form-textarea" style="height:38px;" placeholder="e.g. 2030 A/L" />
                <input type="datetime-local" id="new-cd-date" class="form-textarea" style="height:38px;" />
              </div>
              <input type="text" id="new-cd-title" class="form-textarea" style="height:38px; margin-bottom:8px;" placeholder="e.g. 2030 G.C.E. Advanced Level Examination" />
              <button class="primary-btn" id="btn-submit-new-cd" style="height:38px; margin-top:0; width:100%;">Create & Sync Countdown</button>
            </div>
          </div>
        </div>
      `;

      // Handlers
      document.getElementById('btn-close-countdown')?.addEventListener('click', () => {
        if (timerInterval) clearInterval(timerInterval);
        modal.remove();
      });

      // Toggle edit box
      modal.querySelectorAll('[data-edit-date]').forEach(btn => {
        btn.addEventListener('click', () => {
          const id = btn.dataset.editDate;
          const box = document.getElementById(`date-picker-box-${id}`);
          if (box) box.style.display = box.style.display === 'none' ? 'block' : 'none';
        });
      });

      // Save date
      modal.querySelectorAll('[data-save-dt]').forEach(btn => {
        btn.addEventListener('click', async () => {
          const id = btn.dataset.saveDt;
          const val = document.getElementById(`input-dt-${id}`)?.value;
          if (!val) return;
          try {
            btn.innerText = 'Saving...';
            await dbService.updateExamCountdown(id, { targetDate: new Date(val).toISOString() }, this.currentUser?.name || 'Admin');
            notificationService.showInAppToast('Examination target date successfully updated!', 'success');
            countdowns = await dbService.getExamCountdowns();
            renderCountdownsList();
          } catch (e) {
            notificationService.showInAppToast('Update error: ' + e.message, 'error');
            btn.innerText = 'Save';
          }
        });
      });

      // Toggle visibility
      modal.querySelectorAll('[data-toggle-cd]').forEach(chk => {
        chk.addEventListener('change', async () => {
          const id = chk.dataset.toggleCd;
          try {
            await dbService.updateExamCountdown(id, { isEnabled: chk.checked }, this.currentUser?.name || 'Admin');
            notificationService.showInAppToast(`${chk.checked ? 'Enabled' : 'Hidden'} countdown on student dashboard!`, 'info');
            const target = countdowns.find(x => x.id === id);
            if (target) target.isEnabled = chk.checked;
          } catch (e) {
            notificationService.showInAppToast('Visibility error: ' + e.message, 'error');
          }
        });
      });

      // Toggle Add Form
      document.getElementById('btn-toggle-add-cd')?.addEventListener('click', () => {
        const box = document.getElementById('add-cd-box');
        if (box) box.style.display = box.style.display === 'none' ? 'block' : 'none';
      });

      // Submit new
      document.getElementById('btn-submit-new-cd')?.addEventListener('click', async () => {
        const year = document.getElementById('new-cd-year')?.value.trim();
        const dateVal = document.getElementById('new-cd-date')?.value;
        const title = document.getElementById('new-cd-title')?.value.trim();

        if (!year || !dateVal) {
          notificationService.showInAppToast('Please provide exam year and target date!', 'warning');
          return;
        }

        try {
          await dbService.addExamCountdown({
            examYear: year,
            customTitle: title || `${year} Examination`,
            targetDate: new Date(dateVal).toISOString(),
            isEnabled: true
          }, this.currentUser?.name || 'Admin');
          notificationService.showInAppToast('New examination countdown created!', 'success');
          countdowns = await dbService.getExamCountdowns();
          renderCountdownsList();
        } catch (e) {
          notificationService.showInAppToast('Add error: ' + e.message, 'error');
        }
      });
    };

    renderCountdownsList();
    document.body.appendChild(modal);

    // Live 1-second interval to tick countdown numbers
    timerInterval = setInterval(() => {
      countdowns.forEach(c => {
        const t = computeTimeLeft(c.targetDate);
        const daysEl = document.getElementById(`cd-days-${c.id}`);
        const hoursEl = document.getElementById(`cd-hours-${c.id}`);
        const minsEl = document.getElementById(`cd-mins-${c.id}`);
        const secsEl = document.getElementById(`cd-secs-${c.id}`);
        if (daysEl) daysEl.innerText = t.days;
        if (hoursEl) hoursEl.innerText = t.hours;
        if (minsEl) minsEl.innerText = t.mins;
        if (secsEl) secsEl.innerText = t.secs;
      });
    }, 1000);
  }

  // ── Student Homework Submission Guidelines Modal (1:1 with student_submit_guide_screen.dart) ──
  openSubmitGuideModal() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    modal.innerHTML = `
      <div class="modal-sheet" style="max-height:88vh; overflow-y:auto; padding:18px;">
        <div class="modal-header" style="border-bottom:1px solid #E2E8F0; padding-bottom:12px; margin-bottom:14px;">
          <div style="display:flex; align-items:center; gap:10px;">
            <div style="width:38px; height:38px; border-radius:12px; background:rgba(37,99,235,0.1); display:flex; align-items:center; justify-content:center; color:#2563EB;">
              <span class="material-symbols-rounded" style="font-size:20px;">menu_book</span>
            </div>
            <div>
              <div style="font-size:16px; font-weight:800; color:#0F172A;">Dessert Submission Guidelines</div>
              <div style="font-size:11px; color:#64748B;">How to submit homework & answer sheets for grading</div>
            </div>
          </div>
          <button class="modal-close-btn" id="btn-close-guide-modal">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="display:flex; flex-direction:column; gap:14px;">
          <!-- Key Requirements Banner -->
          <div style="background:#EFF6FF; border:1px solid #BFDBFE; border-radius:12px; padding:14px;">
            <div style="font-size:13px; font-weight:800; color:#1E40AF; margin-bottom:6px; display:flex; align-items:center; gap:6px;">
              <span class="material-symbols-rounded filled" style="font-size:16px;">assignment</span> අවශ්‍ය මූලික නීති (Essential Rules):
            </div>
            <ul style="font-size:11.5px; color:#1E3A8A; line-height:1.6; padding-left:18px; margin:0;">
              <li><strong>පැහැදිලි ඡායාරූප (Good Lighting):</strong> ප්‍රමාණවත් ආලෝකය ඇති ස්ථානයක පත්‍රිකාව තබා සෘජුව (Portrait) ඡායාරූප ගන්න.</li>
              <li><strong>පිටු අංක (Page Numbers):</strong> සෑම පිටුවකම ඉහළින් පැහැදිලිව පිටු අංකය (Page 1, 2, 3...) සටහන් කරන්න.</li>
              <li><strong>නම සහ ශිෂ්‍ය අංකය (Student ID):</strong> පළමු පිටුවේ ඔබගේ නම සහ ලියාපදිංචි ශිෂ්‍ය අංකය සටහන් කරන්න.</li>
              <li><strong>සෙවණැලි වළක්වන්න (Avoid Shadows):</strong> කැමරාවෙන් පත්‍රිකාව මත සෙවණැලි වැටීමෙන් වළකින්න.</li>
            </ul>
          </div>

          <!-- Quick Topic Tags -->
          <div>
            <div style="font-size:12px; font-weight:700; color:#334155; margin-bottom:8px; display:flex; align-items:center; gap:4px;">
              <span class="material-symbols-rounded" style="font-size:15px;">label</span> Popular Physics Submission Units:
            </div>
            <div style="display:flex; flex-wrap:wrap; gap:8px;">
              <span class="apk-filter-chip">Mechanics</span>
              <span class="apk-filter-chip">Waves & Optics</span>
              <span class="apk-filter-chip">Thermal Physics</span>
              <span class="apk-filter-chip">Electricity & Mag</span>
              <span class="apk-filter-chip">Modern Physics</span>
              <span class="apk-filter-chip">Unit Test</span>
            </div>
          </div>

          <!-- Telegram Bot Integration Card -->
          <div style="background:#F0FDF4; border:1px solid #BBF7D0; border-radius:12px; padding:14px;">
            <div style="display:flex; align-items:center; gap:8px; margin-bottom:6px;">
              <span class="material-symbols-rounded filled" style="font-size:18px; color:#166534;">smart_toy</span>
              <span style="font-size:13px; font-weight:800; color:#166534;">Official Telegram Grading Bot</span>
            </div>
            <div style="font-size:11.5px; color:#15803D; line-height:1.45;">
              You can also directly link with <strong>@edupeakbot</strong> on Telegram to receive instant teacher marks, corrections, and audio feedback notifications!
            </div>
          </div>

          <!-- Proceed Button -->
          <button class="primary-btn" id="btn-proceed-to-scanner" style="height:44px; margin-top:4px; display:inline-flex; align-items:center; justify-content:center; gap:6px;">
            <span class="material-symbols-rounded filled" style="font-size:18px;">document_scanner</span> Open Document Camera Scanner
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-guide-modal')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-proceed-to-scanner')?.addEventListener('click', () => {
      modal.remove();
      this.openDocumentScanner();
    });
  }

  openAdminCreatePaperModal() {
    const today = new Date().toISOString().split('T')[0];
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    modal.innerHTML = `
      <div class="modal-sheet" style="max-height:88vh; overflow-y:auto;">
        <div class="modal-header">
          <div style="font-size:16px; font-weight:800; color:#0F172A;">Create Paper Session</div>
          <button class="modal-close-btn" id="btn-close-new-paper">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="display:flex; flex-direction:column; gap:12px; margin-top:8px;">
          <div>
            <div class="form-label">Paper Title:</div>
            <input type="text" id="new-paper-title" class="form-textarea" style="height:40px;" placeholder="e.g. 2027 A/L Speed Paper 01 (Mechanics)" />
          </div>

          <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px;">
            <div>
              <div class="form-label">Subject:</div>
              <select id="new-paper-subject" class="form-textarea" style="height:40px; padding:8px;">
                <option value="Physics" selected>Physics</option>
              </select>
            </div>
            <div>
              <div class="form-label">Exam Year / Batch:</div>
              <select id="new-paper-year" class="form-textarea" style="height:40px; padding:8px;">
                <option value="2024 A/L">2024 A/L</option>
                <option value="2025 A/L">2025 A/L</option>
                <option value="2026 A/L">2026 A/L</option>
                <option value="2027 A/L" selected>2027 A/L</option>
                <option value="2028 A/L">2028 A/L</option>
                <option value="2029 A/L">2029 A/L</option>
                <option value="All Batches">All Batches</option>
              </select>
            </div>
          </div>

          <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px;">
            <div>
              <div class="form-label">Duration (Mins):</div>
              <input type="number" id="new-paper-duration" class="form-textarea" style="height:40px;" value="180" />
            </div>
            <div>
              <div class="form-label">Total Marks:</div>
              <input type="number" id="new-paper-marks" class="form-textarea" style="height:40px;" value="100" />
            </div>
          </div>

          <!-- Physical Paper Delivery Note matching Flutter -->
          <div style="background:rgba(37,99,235,0.08); border:1px solid rgba(37,99,235,0.2); border-radius:10px; padding:10px; display:flex; gap:8px;">
            <span class="material-symbols-rounded filled" style="font-size:20px; color:#2563EB;">inventory_2</span>
            <div style="font-size:10.5px; color:#1E3A8A; line-height:1.45;">
              <strong>Physical Paper Delivery:</strong> සිසුන්ගේ නිවෙස් වලට කුරියර් කර ඇති මුද්‍රිත ප්‍රශ්න පත්‍රය කැමරාව ඉදිරියේ විවෘත කිරීමට ප්‍රථම විනාඩි 10 ක කාලයක් ස්වයංක්‍රීයව හිමිවේ.
            </div>
          </div>

          <div>
            <div class="form-label" style="display:flex; align-items:center; gap:4px;">
              <span class="material-symbols-rounded" style="font-size:15px;">calendar_today</span> Examination Date:
            </div>
            <input type="date" id="new-paper-date" class="form-textarea" style="height:40px;" value="${today}" />
          </div>

          <div>
            <div class="form-label">Number of Session Slots:</div>
            <div style="display:flex; gap:10px; margin-top:4px;">
              <label style="flex:1; display:flex; align-items:center; gap:6px; background:#F8FAFC; border:1px solid #E2E8F0; padding:10px; border-radius:10px; font-size:12px; font-weight:600; cursor:pointer;">
                <input type="radio" name="slot-count" value="1" id="radio-slot-1">
                <span>1 Slot</span>
              </label>
              <label style="flex:1; display:flex; align-items:center; gap:6px; background:#F8FAFC; border:1px solid #E2E8F0; padding:10px; border-radius:10px; font-size:12px; font-weight:600; cursor:pointer;">
                <input type="radio" name="slot-count" value="2" id="radio-slot-2" checked>
                <span>2 Slots (Morning & Evening)</span>
              </label>
            </div>
          </div>

          <!-- Slot Times Container -->
          <div style="background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; padding:12px;">
            <div style="font-size:11.5px; font-weight:700; color:#D97706; margin-bottom:6px; display:flex; align-items:center; gap:4px;">
              <span class="material-symbols-rounded filled" style="font-size:15px; color:#D97706;">wb_sunny</span> Slot 1 (Morning Session):
            </div>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px;">
              <div>
                <span style="font-size:10.5px; color:#64748B;">Start:</span>
                <input type="text" id="new-s1-start" class="form-textarea" style="height:36px; font-size:11px;" value="08:30 AM" />
              </div>
              <div>
                <span style="font-size:10.5px; color:#64748B;">End:</span>
                <input type="text" id="new-s1-end" class="form-textarea" style="height:36px; font-size:11px;" value="11:40 AM" />
              </div>
            </div>

            <div id="new-slot2-box" style="margin-top:10px;">
              <div style="font-size:11.5px; font-weight:700; color:#2563EB; margin-bottom:6px; display:flex; align-items:center; gap:4px;">
                <span class="material-symbols-rounded filled" style="font-size:15px; color:#2563EB;">bedtime</span> Slot 2 (Evening Session):
              </div>
              <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px;">
                <div>
                  <span style="font-size:10.5px; color:#64748B;">Start:</span>
                  <input type="text" id="new-s2-start" class="form-textarea" style="height:36px; font-size:11px;" value="04:00 PM" />
                </div>
                <div>
                  <span style="font-size:10.5px; color:#64748B;">End:</span>
                  <input type="text" id="new-s2-end" class="form-textarea" style="height:36px; font-size:11px;" value="07:10 PM" />
                </div>
              </div>
            </div>
          </div>

          <!-- Manual Session End Note matching Flutter -->
          <div style="background:rgba(245,158,11,0.12); border:1px solid rgba(245,158,11,0.3); border-radius:10px; padding:10px; display:flex; gap:8px;">
            <span class="material-symbols-rounded filled" style="font-size:18px; color:#D97706;">cancel</span>
            <div style="font-size:10.5px; color:#92400E; line-height:1.45;">
              <strong>Manual Session End:</strong> විභාග සැසිය ස්වයංක්‍රීයව අවසන් නොවේ. විභාගය අවසන් වූ පසු Admin විසින් "End Session" බොත්තම ඔබා එය අවසන් කළ යුතුය.
            </div>
          </div>

          <div style="display:flex; gap:10px; margin-top:8px;">
            <button class="apk-btn-primary" id="btn-cancel-create-paper" style="flex:1; background:#F1F5F9; color:#475569; box-shadow:none;">
              Cancel
            </button>
            <button class="apk-btn-primary" id="btn-save-new-paper" style="flex:1.5; background:#2563EB; padding:13px; font-size:13px;">
              Create Paper (නිර්මාණය කරන්න)
            </button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-new-paper')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-cancel-create-paper')?.addEventListener('click', () => modal.remove());

    const slot2Box = document.getElementById('new-slot2-box');
    document.getElementById('radio-slot-1')?.addEventListener('change', () => {
      if (slot2Box) slot2Box.style.display = 'none';
    });
    document.getElementById('radio-slot-2')?.addEventListener('change', () => {
      if (slot2Box) slot2Box.style.display = 'block';
    });

    document.getElementById('btn-save-new-paper')?.addEventListener('click', async () => {
      const title = document.getElementById('new-paper-title')?.value?.trim();
      const subject = document.getElementById('new-paper-subject')?.value || 'Physics';
      const examYear = document.getElementById('new-paper-year')?.value || '2027 A/L';
      const duration = Number(document.getElementById('new-paper-duration')?.value) || 180;
      const marks = Number(document.getElementById('new-paper-marks')?.value) || 100;
      const examDate = document.getElementById('new-paper-date')?.value || today;
      const isTwoSlots = document.getElementById('radio-slot-2')?.checked;

      const s1Start = document.getElementById('new-s1-start')?.value || '08:30 AM';
      const s1End = document.getElementById('new-s1-end')?.value || '11:40 AM';
      const s2Start = document.getElementById('new-s2-start')?.value || '04:00 PM';
      const s2End = document.getElementById('new-s2-end')?.value || '07:10 PM';

      if (!title) {
        alert('කරුණාකර Paper Title එක ඇතුළත් කරන්න (Please enter Paper Title)');
        return;
      }

      // Convert date + time strings to ISO timestamps for slot1 and slot2
      const makeIsoTime = (dStr, timeStr) => {
        try {
          const parts = timeStr.trim().split(' ');
          const [hStr, mStr] = parts[0].split(':');
          let h = parseInt(hStr, 10);
          const m = parseInt(mStr, 10);
          const isPm = (parts[1] || '').toUpperCase() === 'PM';
          if (isPm && h < 12) h += 12;
          if (!isPm && h === 12) h = 0;
          const [yr, mo, da] = dStr.split('-').map(Number);
          return new Date(yr, mo - 1, da, h, m).toISOString();
        } catch (_) {
          return new Date().toISOString();
        }
      };

      const slot1StartIso = makeIsoTime(examDate, s1Start);
      const slot1EndIso = makeIsoTime(examDate, s1End);

      const slot1 = {
        id: 'slot1',
        name: isTwoSlots ? 'Morning Session (උදෑසන සැසිය)' : 'Exam Session Time',
        startTime: slot1StartIso,
        endTime: slot1EndIso,
        registeredCount: 0,
        maxCapacity: 200
      };

      let slot2 = null;
      if (isTwoSlots) {
        slot2 = {
          id: 'slot2',
          name: 'Evening Session (සවස සැසිය)',
          startTime: makeIsoTime(examDate, s2Start),
          endTime: makeIsoTime(examDate, s2End),
          registeredCount: 0,
          maxCapacity: 200
        };
      }

      // Sessions ALWAYS start in 'upcoming' status and 'waiting' phase!
      await dbService.savePaperSession({
        title,
        subject,
        examYear,
        date: examDate,
        durationMinutes: duration,
        totalMarks: marks,
        status: 'upcoming',
        currentPhase: 'waiting',
        isEnded: false,
        isLive: false,
        isTimeUp: false,
        slot1,
        slot2
      });

      notificationService.showInAppBanner('Paper Created!', 'Paper Session එක සාර්ථකව නිර්මාණය කරන ලදී (Upcoming Session).', 'success');
      modal.remove();
      const vp = document.getElementById('admin-main-viewport');
      if (vp) this.renderAdminPapersScreen(vp);
    });
  }

  openCreateSprintSheet() {
    document.getElementById('create-sprint-modal')?.remove();
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.id = 'create-sprint-modal';
    modal.innerHTML = `
      <form id="form-create-sprint" class="sprint-create-sheet">
        <header class="sprint-create-header">
          <div><h2>Create Daily 5-MCQ Sprint</h2><p>Publish questions to the shared student database.</p></div>
          <button type="button" class="modal-close-btn" id="btn-close-create-sprint" aria-label="Close"><span class="material-symbols-rounded">close</span></button>
        </header>
        <div class="sprint-create-scroll">
          <div class="sprint-create-meta">
            <label>Title<input name="title" required value="Daily MCQ 5"></label>
            <label>Unit / Lesson<input name="unit" required value="Mechanics"></label>
            <label>Batch<select name="examYear"><option>All Batches</option><option>2026 A/L</option><option>2027 A/L</option><option>2028 A/L</option></select></label>
            <label>Sprint Date<input name="targetDate" type="date" required value="${this.adminSprintDate}"></label>
          </div>
          ${Array.from({ length: 5 }, (_, index) => `
            <section class="sprint-question-card">
              <h3>Question ${index + 1}</h3>
              <label>Question<input name="question-${index}" required placeholder="Enter question text"></label>
              <div class="sprint-question-options">
                ${Array.from({ length: 5 }, (_, option) => `<label>Option ${option + 1}<input name="option-${index}-${option}" required placeholder="Option ${option + 1}"></label>`).join('')}
              </div>
              <label>Correct option<select name="correct-${index}">${Array.from({ length: 5 }, (_, option) => `<option value="${option}">Option ${option + 1}</option>`).join('')}</select></label>
              <label>Explanation<textarea name="explanation-${index}" rows="2" placeholder="Optional explanation"></textarea></label>
            </section>
          `).join('')}
          <div id="create-sprint-error" class="sprint-create-error" role="alert" hidden></div>
        </div>
        <footer class="sprint-create-footer"><button class="apk-btn-primary" id="btn-publish-sprint" type="submit">Publish 5-MCQ Sprint 🚀</button></footer>
      </form>`;
    document.body.appendChild(modal);
    document.getElementById('btn-close-create-sprint')?.addEventListener('click', () => modal.remove());
    modal.addEventListener('click', (event) => { if (event.target === modal) modal.remove(); });
    document.getElementById('form-create-sprint')?.addEventListener('submit', async (event) => {
      event.preventDefault();
      const form = event.currentTarget;
      if (!form.reportValidity()) return;
      const fields = new FormData(form);
      const questions = Array.from({ length: 5 }, (_, index) => ({
        question: fields.get(`question-${index}`),
        options: Array.from({ length: 5 }, (_, option) => fields.get(`option-${index}-${option}`)),
        correctIndex: Number(fields.get(`correct-${index}`)),
        explanation: fields.get(`explanation-${index}`),
      }));
      const publishButton = document.getElementById('btn-publish-sprint');
      const errorBox = document.getElementById('create-sprint-error');
      publishButton.disabled = true;
      publishButton.textContent = 'Publishing…';
      try {
        await dbService.publishDailySprint({
          title: fields.get('title'),
          unit: fields.get('unit'),
          examYear: fields.get('examYear'),
          targetDate: fields.get('targetDate'),
          subject: 'Physics',
          questions,
        });
        modal.remove();
        notificationService.showInAppBanner('Sprint Published', 'The five-question sprint is available to the selected batch.', 'success');
        const viewport = document.getElementById('admin-main-viewport');
        if (viewport) this.renderAdminSprintsScreen(viewport);
      } catch (error) {
        errorBox.hidden = false;
        errorBox.textContent = error?.message || 'The sprint could not be published. Try again.';
        publishButton.disabled = false;
        publishButton.textContent = 'Publish 5-MCQ Sprint 🚀';
      }
    });
  }

  openSendCustomMessageModal(student) {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <div>
            <div style="font-size:15px; font-weight:800; color:#0F172A;">Send Custom Message</div>
            <div style="font-size:11.5px; color:#64748B;">To: ${student.name} (${student.phone})</div>
          </div>
          <button class="modal-close-btn" id="btn-close-msg-dialog">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="display:flex; flex-direction:column; gap:12px; margin-top:10px;">
          <div>
            <div class="form-label">Message Title:</div>
            <input type="text" id="cust-msg-title" class="form-textarea" style="height:38px;" placeholder="Enter title..." />
          </div>

          <div>
            <div class="form-label">Message Content:</div>
            <textarea id="cust-msg-body" class="form-textarea" rows="3" placeholder="Type instructions or feedback here..."></textarea>
          </div>

          <button class="apk-btn-primary" id="btn-send-cust-msg" style="padding:12px; display:inline-flex; align-items:center; justify-content:center; gap:6px;">
            <span class="material-symbols-rounded filled" style="font-size:18px;">send</span> Send to Student via Telegram
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-msg-dialog')?.addEventListener('click', () => modal.remove());

    document.getElementById('btn-send-cust-msg')?.addEventListener('click', () => {
      const title = document.getElementById('cust-msg-title')?.value;
      const body = document.getElementById('cust-msg-body')?.value;

      if (!title || !body) {
        alert('Please enter title and content.');
        return;
      }

      notificationService.showInAppBanner('Message Delivered!', `Delivered to ${student.name} on Telegram.`, 'success');
      modal.remove();
    });
  }

  confirmDeleteStudent(student) {
    if (!confirm(`Are you sure you want to permanently delete the account of ${student.name} (${student.phone})? This will purge all associated submissions and records.`)) {
      return;
    }

    dbService.deleteStudent(student.id);
    notificationService.showInAppBanner('Account Purged', `All data for ${student.name} removed.`, 'warning');
    const vp = document.getElementById('admin-main-viewport');
    if (vp) this.renderAdminStudentsScreen(vp);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ── 5. LIVE EXAM PROCTOR HALL & STUDENT EXAM ROOM (1:1 Mobile Parity) ───
  // ═════════════════════════════════════════════════════════════════════════

  openExamRoom(paperId) {
    this.openAdminLiveProctorHall(paperId);
  }

  // ── A. Examiner Live Proctoring Center (admin_live_proctor_screen.dart 1:1) ──
  async openAdminLiveProctorHall(paperId) {
    let session = await dbService.getPaperSession(paperId);
    if (!session) {
      const papers = await dbService.getPaperSessions();
      session = papers.find(p => p.id === paperId) || {
        id: paperId,
        title: 'Exam Proctoring Center',
        currentPhase: 'writing',
        durationMinutes: 150
      };
    }

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';
    modal.style.justifyContent = 'center';
    modal.style.alignItems = 'center';
    modal.style.background = 'rgba(11, 15, 25, 0.9)';
    modal.style.backdropFilter = 'blur(12px)';
    modal.style.zIndex = '9999';

    let activeTab = 'slot1'; // 'slot1', 'slot2', 'answers'
    let allStudents = [];
    let unsubs = [];

    const formatTimer = (secs) => {
      const h = String(Math.floor(secs / 3600)).padStart(2, '0');
      const m = String(Math.floor((secs % 3600) / 60)).padStart(2, '0');
      const s = String(secs % 60).padStart(2, '0');
      return `${h}:${m}:${s}`;
    };

    const isRecentPing = (lastPing) => {
      if (!lastPing) return false;
      let date;
      if (typeof lastPing.toDate === 'function') date = lastPing.toDate();
      else if (lastPing.seconds) date = new Date(lastPing.seconds * 1000);
      else date = new Date(lastPing);
      const diff = Math.floor((Date.now() - date.getTime()) / 1000);
      return diff >= -5 && diff <= 35;
    };

    const render = () => {
      const slot1Students = allStudents.filter(s => (s.selectedSlot || 'slot1') === 'slot1');
      const slot2Students = allStudents.filter(s => s.selectedSlot === 'slot2');
      const submittedStudents = allStudents.filter(s => s.status === 'submitted' || (s.submissionPhotos && s.submissionPhotos.length > 0));

      const currentSlotStudents = activeTab === 'slot2' ? slot2Students : slot1Students;
      const liveCount = currentSlotStudents.filter(s => {
        if (s.status === 'submitted' || (s.submissionPhotos && s.submissionPhotos.length > 0)) return false;
        return s.isCameraActive && (isRecentPing(s.lastCameraPing) || s.cameraSnapshotUrl);
      }).length;
      const submittedSlotCount = currentSlotStudents.filter(s => s.status === 'submitted' || (s.submissionPhotos && s.submissionPhotos.length > 0)).length;
      const inactiveCount = Math.max(0, currentSlotStudents.length - liveCount - submittedSlotCount);

      const phase = session.currentPhase || 'waiting';
      let phaseColor = '#818CF8';
      let phaseLabel = '<span class="material-symbols-rounded filled" style="font-size:16px; vertical-align:middle; margin-right:4px;">hourglass_top</span>Waiting Room (Students Waiting)';

      switch (phase) {
        case 'package_opening':
          phaseColor = '#F59E0B';
          phaseLabel = '<span class="material-symbols-rounded filled" style="font-size:16px; vertical-align:middle; margin-right:4px;">inventory_2</span>Package Opening (10 Mins Active)';
          break;
        case 'writing':
          phaseColor = '#22C55E';
          phaseLabel = '<span class="material-symbols-rounded filled" style="font-size:16px; vertical-align:middle; margin-right:4px;">edit_note</span>Exam Writing In Progress';
          break;
        case 'time_up':
          phaseColor = '#EA580C';
          phaseLabel = '<span class="material-symbols-rounded filled" style="font-size:16px; vertical-align:middle; margin-right:4px;">alarm</span>Time is Up (Collecting Answers)';
          break;
        case 'ended':
          phaseColor = '#EF4444';
          phaseLabel = '<span class="material-symbols-rounded filled" style="font-size:16px; vertical-align:middle; margin-right:4px;">cancel</span>Session Ended';
          break;
        default:
          phaseColor = '#818CF8';
          phaseLabel = '<span class="material-symbols-rounded filled" style="font-size:16px; vertical-align:middle; margin-right:4px;">hourglass_top</span>Waiting Room (Students Waiting)';
          break;
      }

      const isEnded = session.isEnded || phase === 'ended';
      const isTimeUp = session.isTimeUp || phase === 'time_up';

      modal.innerHTML = `
        <div style="width:100%; max-width:440px; height:92vh; max-height:890px; border-radius:24px; border:1px solid #334155; display:flex; flex-direction:column; background:#0F172A; color:#F8FAFC; overflow:hidden; font-family:'Poppins','Plus Jakarta Sans',sans-serif; box-shadow:0 25px 60px rgba(0,0,0,0.7); position:relative;">
          
          <!-- ── AppBar (matching admin_live_proctor_screen.dart AppBar) ── -->
          <div style="background:#1E293B; border-bottom:1px solid #334155; padding:12px 14px 0 14px; flex-shrink:0;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <div style="display:flex; flex-direction:column; gap:2px;">
                <div style="display:flex; align-items:center; gap:8px;">
                  <span style="width:8px; height:8px; border-radius:50%; background:#22C55E; box-shadow:0 0 8px #22C55E; display:inline-block;"></span>
                  <span style="font-size:15px; font-weight:700; color:#FFFFFF;">Live Invigilator Monitor</span>
                </div>
                <div style="font-size:11px; color:#94A3B8; padding-left:16px;">${session.title || 'Exam Proctoring Center'}</div>
              </div>

              <!-- Top Actions: Time Up, End Session, Broadcast Alert, Close -->
              <div style="display:flex; align-items:center; gap:6px;">
                ${!isEnded ? `
                  <button id="btn-proctor-time-up" style="background:${isTimeUp ? '#EA580C' : '#F59E0B'}; color:#000000; border:none; padding:5px 8px; border-radius:8px; font-size:11px; font-weight:700; cursor:pointer; display:flex; align-items:center; gap:4px;">
                    <span class="material-symbols-rounded filled" style="font-size:14px;">alarm</span> ${isTimeUp ? 'Time Up (Sent)' : 'Time Up'}
                  </button>
                  <button id="btn-proctor-end-session" style="background:#EF4444; color:#FFFFFF; border:none; padding:5px 8px; border-radius:8px; font-size:11px; font-weight:700; cursor:pointer; display:flex; align-items:center; gap:4px;">
                    <span class="material-symbols-rounded filled" style="font-size:14px;">cancel</span> End Session
                  </button>
                ` : `
                  <div style="padding:4px 8px; border-radius:6px; background:rgba(239,68,68,0.2); border:1px solid #EF4444; color:#FCA5A5; font-size:11px; font-weight:700; display:flex; align-items:center; gap:4px;">
                    <span class="material-symbols-rounded" style="font-size:14px;">check</span> Ended
                  </div>
                `}
                <button id="btn-proctor-broadcast" title="Broadcast Announcement to All Students" style="background:transparent; border:none; color:#F59E0B; cursor:pointer; padding:4px; display:flex; align-items:center;">
                  <span class="material-symbols-rounded filled" style="font-size:20px; color:#F59E0B;">campaign</span>
                </button>
                <button id="btn-close-proctor-hall" title="Exit Hall" style="background:transparent; border:none; color:#94A3B8; cursor:pointer; padding:4px 6px; display:inline-flex; align-items:center; justify-content:center;">
                  <span class="material-symbols-rounded">close</span>
                </button>
              </div>
            </div>

            <!-- TabBar: Slot 1, Slot 2, Answers (Count) -->
            <div style="display:flex; border-bottom:1px solid #334155;">
              <button class="proctor-tab-btn" data-tab="slot1" style="flex:1; padding:10px 0; background:none; border:none; border-bottom:${activeTab === 'slot1' ? '3px solid #6366F1' : '3px solid transparent'}; color:${activeTab === 'slot1' ? '#FFFFFF' : '#94A3B8'}; font-size:12px; font-weight:700; cursor:pointer; display:flex; align-items:center; justify-content:center; gap:5px;">
                <span class="material-symbols-rounded filled" style="font-size:15px; color:#F59E0B;">wb_sunny</span> ${session.slot2 ? 'Slot 1' : 'Slot 1 (Live)'}
              </button>
              <button class="proctor-tab-btn" data-tab="slot2" style="flex:1; padding:10px 0; background:none; border:none; border-bottom:${activeTab === 'slot2' ? '3px solid #6366F1' : '3px solid transparent'}; color:${activeTab === 'slot2' ? '#FFFFFF' : '#94A3B8'}; font-size:12px; font-weight:700; cursor:pointer; display:flex; align-items:center; justify-content:center; gap:5px;">
                <span class="material-symbols-rounded filled" style="font-size:15px; color:#818CF8;">bedtime</span> ${session.slot2 ? 'Slot 2' : 'Slot 2 (None)'}
              </button>
              <button class="proctor-tab-btn" data-tab="answers" style="flex:1; padding:10px 0; background:none; border:none; border-bottom:${activeTab === 'answers' ? '3px solid #6366F1' : '3px solid transparent'}; color:${activeTab === 'answers' ? '#FFFFFF' : '#94A3B8'}; font-size:12px; font-weight:700; cursor:pointer; display:flex; align-items:center; justify-content:center; gap:5px;">
                <span class="material-symbols-rounded filled" style="font-size:15px; color:#4ADE80;">check_circle</span> Answers (${submittedStudents.length})
              </button>
            </div>
          </div>

          <!-- ── Phase Control Bar (_buildSessionPhaseControlBar) ── -->
          <div style="background:#1E293B; border-bottom:1px solid #334155; padding:8px 14px; flex-shrink:0;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
              <div style="padding:4px 8px; border-radius:8px; background:${phaseColor}25; border:1px solid ${phaseColor}; display:flex; align-items:center; gap:6px;">
                <span style="font-size:11px; font-weight:700; color:${phaseColor};">${phaseLabel}</span>
              </div>
              <div style="font-size:10px; font-weight:600; color:#64748B;">Manual Phase Controls</div>
            </div>

            <!-- Horizontal Action Buttons Matching Mobile Dart Screen -->
            <div style="display:flex; gap:6px; overflow-x:auto; padding-bottom:2px;">
              ${phase === 'waiting' ? `
                <button class="phase-action-btn" data-set-phase="package_opening" style="background:#F59E0B; color:#000000; border:none; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:700; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:14px;">inventory_2</span> Start Package Opening (10m)
                </button>
                <button class="phase-action-btn" data-set-phase="writing" style="background:transparent; border:1px solid #22C55E; color:#22C55E; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:600; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:14px;">play_arrow</span> Start Writing Direct
                </button>
              ` : phase === 'package_opening' ? `
                <button class="phase-action-btn" data-set-phase="writing" style="background:#22C55E; color:#FFFFFF; border:none; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:700; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:14px;">edit_note</span> Start Exam Writing (ලිවීම අරඹන්න)
                </button>
                <button class="phase-action-btn" data-restart-10m="true" style="background:#F59E0B; color:#000000; border:none; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:700; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded" style="font-size:14px;">sync</span> Restart 10m Timer
                </button>
                <button class="phase-action-btn" data-end-now="true" style="background:#EF4444; color:#FFFFFF; border:none; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:700; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:14px;">cancel</span> End Session
                </button>
              ` : phase === 'writing' ? `
                <button class="phase-action-btn" data-trigger-time-up="true" style="background:#F59E0B; color:#000000; border:none; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:700; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:14px;">alarm</span> Trigger Time Up (වේලාව අවසන්)
                </button>
                <button class="phase-action-btn" data-end-now="true" style="background:#EF4444; color:#FFFFFF; border:none; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:700; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:14px;">cancel</span> End Session
                </button>
              ` : phase === 'time_up' ? `
                <button class="phase-action-btn" data-end-now="true" style="background:#EF4444; color:#FFFFFF; border:none; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:700; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded filled" style="font-size:14px;">cancel</span> End Session (සැසිය අවසන් කරන්න)
                </button>
                <button class="phase-action-btn" data-set-phase="writing" style="background:transparent; border:1px solid #38BDF8; color:#38BDF8; padding:6px 10px; border-radius:8px; font-size:10.5px; font-weight:600; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded" style="font-size:14px;">sync</span> Resume Writing
                </button>
              ` : `
                <button class="phase-action-btn" data-set-phase="writing" style="background:#6366F1; color:#FFFFFF; border:none; padding:6px 12px; border-radius:8px; font-size:10.5px; font-weight:700; cursor:pointer; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span class="material-symbols-rounded" style="font-size:14px;">sync</span> Reopen Session (නැවත අරඹන්න)
                </button>
              `}
            </div>
          </div>

          <!-- ── Main Tab Content ── -->
          <div style="flex:1; overflow-y:auto; display:flex; flex-direction:column;">
            ${activeTab === 'answers' ? `
              <!-- Answers Section (_buildSubmittedAnswersSection) -->
              <div style="background:#1E293B; border-bottom:1px solid #334155; padding:12px 16px; display:flex; justify-content:space-between; align-items:center;">
                <div style="display:flex; align-items:center; gap:10px;">
                  <div style="padding:8px; background:rgba(34,197,94,0.2); border-radius:10px; color:#4ADE80; display:flex; align-items:center; justify-content:center;">
                    <span class="material-symbols-rounded filled" style="font-size:20px;">description</span>
                  </div>
                  <div>
                    <div style="font-size:12.5px; font-weight:700; color:#FFFFFF;">Submitted Answer Sheets (ලැබුණු පිළිතුරු පත්‍ර)</div>
                    <div style="font-size:11px; color:#94A3B8;">${submittedStudents.length} of ${allStudents.length} Students Submitted</div>
                  </div>
                </div>
                <div style="padding:4px 10px; border-radius:12px; background:rgba(34,197,94,0.15); border:1px solid #22C55E; color:#4ADE80; font-size:11px; font-weight:700;">
                  ${submittedStudents.length} Submitted
                </div>
              </div>

              <!-- List of Submitted Students or Empty State -->
              <div style="flex:1; padding:16px;">
                ${submittedStudents.length === 0 ? `
                  <div style="display:flex; flex-direction:column; align-items:center; justify-content:center; height:100%; min-height:260px; text-align:center; padding:32px;">
                    <div style="width:70px; height:70px; border-radius:50%; background:#1E293B; border:1px solid #334155; display:flex; align-items:center; justify-content:center; color:#64748B; margin-bottom:16px;">
                      <span class="material-symbols-rounded" style="font-size:32px;">folder_open</span>
                    </div>
                    <div style="font-size:15px; font-weight:700; color:#FFFFFF; margin-bottom:6px;">තවමත් පිළිතුරු පත්‍ර ලැබී නොමැත</div>
                    <div style="font-size:12px; color:#94A3B8; line-height:1.5;">සිසුන් පිළිතුරු පත්‍ර ඡායාරූප ගෙන Submit කළ පසු ඒවා ශිෂ්‍ය නාමය සමඟ මෙහි සජීවීව දිස්වනු ඇත.</div>
                  </div>
                ` : `
                  <div style="display:flex; flex-direction:column; gap:10px;">
                    ${submittedStudents.map((s, idx) => `
                      <div style="background:#1E293B; border:1px solid #334155; border-radius:14px; padding:12px 14px; display:flex; justify-content:space-between; align-items:center;">
                        <div style="display:flex; align-items:center; gap:10px;">
                          <div style="width:26px; height:26px; border-radius:50%; background:#334155; display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:700; color:#94A3B8;">
                            #${idx + 1}
                          </div>
                          <div>
                            <div style="font-size:13px; font-weight:700; color:#FFFFFF;">${s.studentName || 'Student'}</div>
                            <div style="font-size:11px; color:#94A3B8;">${s.studentPhone || ''} • ${s.submissionPhotos?.length || 1} Pages</div>
                          </div>
                        </div>
                        <button class="btn-view-answers" data-student-id="${s.studentId}" style="background:#22C55E; color:#FFFFFF; border:none; padding:6px 12px; border-radius:8px; font-size:11px; font-weight:700; cursor:pointer;">
                          View Answers
                        </button>
                      </div>
                    `).join('')}
                  </div>
                `}
              </div>
            ` : `
              <!-- Slot Proctored Grid (_buildSlotProctorGrid) -->
              <!-- Top Analytics Stats Bar -->
              <div style="padding:10px 16px; background:rgba(30,41,59,0.5); display:flex; justify-content:space-around; align-items:center; border-bottom:1px solid #1E293B; flex-shrink:0;">
                <div style="text-align:center;">
                  <div style="font-size:15px; font-weight:700; color:#818CF8;">${currentSlotStudents.length}</div>
                  <div style="font-size:10px; color:#94A3B8;">Registered</div>
                </div>
                <div style="text-align:center;">
                  <div style="font-size:15px; font-weight:700; color:#22C55E;">${liveCount}</div>
                  <div style="font-size:10px; color:#94A3B8; display:flex; align-items:center; justify-content:center; gap:3px;">
                    <span class="material-symbols-rounded filled" style="font-size:12px; color:#22C55E;">videocam</span> Live Cameras
                  </div>
                </div>
                <div style="text-align:center;">
                  <div style="font-size:15px; font-weight:700; color:#EF4444;">${inactiveCount}</div>
                  <div style="font-size:10px; color:#94A3B8; display:flex; align-items:center; justify-content:center; gap:3px;">
                    <span class="material-symbols-rounded" style="font-size:12px; color:#EF4444;">videocam_off</span> Inactive
                  </div>
                </div>
                <div style="text-align:center;">
                  <div style="font-size:15px; font-weight:700; color:#38BDF8;">${submittedSlotCount}</div>
                  <div style="font-size:10px; color:#94A3B8; display:flex; align-items:center; justify-content:center; gap:3px;">
                    <span class="material-symbols-rounded filled" style="font-size:12px; color:#38BDF8;">check_circle</span> Submitted
                  </div>
                </div>
              </div>

              <!-- Students Grid or Exact Empty State -->
              <div style="flex:1; padding:14px; overflow-y:auto;">
                ${currentSlotStudents.length === 0 ? `
                  <div style="display:flex; flex-direction:column; align-items:center; justify-content:center; height:100%; min-height:280px; text-align:center; padding:24px;">
                    <div style="font-size:13px; color:#94A3B8; line-height:1.6;">
                      ${activeTab === 'slot2' && !session.slot2
                        ? 'මෙම Paper එක සඳහා 2nd Slot එකක් සකසා නොමැත.<br><span style="font-size:11px; color:#64748B;">(Single Slot Session)</span>'
                        : 'මෙම සැසිය සඳහා තවම ශිෂ්‍යයින් ලියාපදිංචි වී නොමැත.'}
                    </div>
                  </div>
                ` : `
                  <div style="display:grid; grid-template-columns:repeat(2, 1fr); gap:12px;">
                    ${currentSlotStudents.map(student => {
                      const isSubmitted = student.status === 'submitted' || (student.submissionPhotos && student.submissionPhotos.length > 0);
                      const pingActive = isRecentPing(student.lastCameraPing);
                      const isCameraActive = !isSubmitted && !!(student.isCameraActive && (pingActive || student.cameraSnapshotUrl));
                      const isOnline = !isSubmitted && (isCameraActive || pingActive || student.isOnline);
                      const borderColor = isSubmitted ? '#38BDF8' : isCameraActive ? '#22C55E' : isOnline ? '#3B82F6' : '#EF4444';
                      const statusBadge = isSubmitted ? 'SUBMITTED' : isCameraActive ? 'LIVE' : isOnline ? 'ONLINE' : 'OFFLINE';

                      return `
                        <div style="background:#1E293B; border-radius:14px; border:1.5px solid ${borderColor}; display:flex; flex-direction:column; overflow:hidden;">
                          <!-- Camera Preview Box -->
                          <div class="student-camera-box" data-student-id="${student.studentId}" style="height:140px; background:#0F172A; position:relative; cursor:pointer; display:flex; align-items:center; justify-content:center; overflow:hidden;">
                            ${(student.cameraSnapshotUrl && (isCameraActive || isOnline)) ? `
                              <img src="${student.cameraSnapshotUrl}" style="width:100%; height:100%; object-fit:cover;" />
                            ` : `
                              <div style="display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px;">
                                <span class="material-symbols-rounded" style="font-size:26px; color:${borderColor};">${isCameraActive ? 'videocam' : 'videocam_off'}</span>
                                <span style="font-size:10px; font-weight:500; color:${isOnline ? '#4ADE80' : '#94A3B8'};">
                                  ${isSubmitted ? 'Paper Submitted' : isCameraActive ? 'Proctor Stream Active' : 'Camera Offline'}
                                </span>
                              </div>
                            `}
                            <!-- Status Pill Top Left -->
                            <div style="position:absolute; top:6px; left:6px; padding:2px 6px; border-radius:4px; background:${borderColor}; color:#FFFFFF; font-size:8.5px; font-weight:700; box-shadow:0 2px 4px rgba(0,0,0,0.4);">
                              ${statusBadge}
                            </div>
                            <!-- Fullscreen Icon Top Right -->
                            <div style="position:absolute; top:6px; right:6px; background:rgba(0,0,0,0.65); padding:3px 5px; border-radius:4px; font-size:10px; color:#FFFFFF; display:flex; align-items:center;">
                              <span class="material-symbols-rounded" style="font-size:14px;">zoom_in</span>
                            </div>
                          </div>

                          <!-- Details & Actions -->
                          <div style="padding:10px; display:flex; flex-direction:column; gap:6px;">
                            <div>
                              <div style="font-size:12px; font-weight:700; color:#FFFFFF; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
                                ${student.studentName || 'Student'}
                              </div>
                              <div style="font-size:10px; color:#94A3B8;">
                                ${student.studentPhone || `ID: ${(student.studentId || '').slice(0, 6)}`}
                              </div>
                            </div>

                            ${(student.submissionPhotos?.length || isSubmitted) ? `
                              <button class="btn-view-answers" data-student-id="${student.studentId}" style="width:100%; height:26px; background:#22C55E; color:#FFFFFF; border:none; border-radius:6px; font-size:10px; font-weight:700; cursor:pointer;">
                                View Answers (${student.submissionPhotos?.length || 1})
                              </button>
                            ` : ''}

                            <div style="display:flex; gap:6px;">
                              <button class="btn-full-view" data-student-id="${student.studentId}" style="flex:1; height:26px; background:transparent; border:1px solid #38BDF8; color:#38BDF8; border-radius:6px; font-size:10px; font-weight:600; cursor:pointer;">
                                Full View
                              </button>
                              <button class="btn-alert-student" data-student-id="${student.studentId}" style="flex:1; height:26px; background:#6366F1; color:#FFFFFF; border:none; border-radius:6px; font-size:10px; font-weight:600; cursor:pointer;">
                                Alert
                              </button>
                            </div>
                          </div>
                        </div>
                      `;
                    }).join('')}
                  </div>
                `}
              </div>
            `}
          </div>

          <!-- Bottom Status Footer -->
          <div style="padding:10px 14px; background:#111827; border-top:1px solid #1E293B; display:flex; justify-content:space-between; align-items:center; flex-shrink:0;">
            <div style="font-size:11px; color:#94A3B8;">
              Connected to Session Channel: edupeak_proctor_${session.id}
            </div>
            <button id="btn-hall-test-student" style="background:#10B981; color:#FFFFFF; border:none; border-radius:8px; padding:6px 12px; font-size:11px; font-weight:700; cursor:pointer; display:inline-flex; align-items:center; gap:6px;">
              <span class="material-symbols-rounded filled" style="font-size:15px;">description</span>
              <span>Test Student View</span>
              <span class="material-symbols-rounded" style="font-size:14px;">arrow_forward</span>
            </button>
          </div>
        </div>
      `;

      attachEventHandlers();
    };

    const attachEventHandlers = () => {
      // Close Hall
      document.getElementById('btn-close-proctor-hall')?.addEventListener('click', () => {
        unsubs.forEach(fn => { try { fn(); } catch (_) {} });
        modal.remove();
      });

      // Tab Buttons
      modal.querySelectorAll('.proctor-tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          activeTab = btn.dataset.tab;
          render();
        });
      });

      // Test Student View
      document.getElementById('btn-hall-test-student')?.addEventListener('click', () => {
        unsubs.forEach(fn => { try { fn(); } catch (_) {} });
        modal.remove();
        this.openStudentLiveExamRoom(session.id, 'slot1');
      });

      // Trigger Time Up Button in AppBar
      document.getElementById('btn-proctor-time-up')?.addEventListener('click', () => {
        this._confirmProctorAction({
          title: 'Trigger Time Up (වේලාව අවසන් කරන්නද?)',
          content: 'සියලුම සිසුන්ට ලිවීම නවත්වා, පිළිතුරු පත්‍රවල ඡායාරූප (Photos) ලබාගෙන App එක හරහා Submit කරන ලෙස Alert එකක් යැවීමට අවශ්‍ය බව සහතිකද?',
          confirmText: 'Trigger Time Up (දන්වන්න)',
          confirmColor: '#F59E0B',
          onConfirm: async () => {
            await dbService.triggerTimeUp(session.id);
            notificationService.showInAppBanner('⏰ Time Up Sent', 'Time up alert broadcasted to all students!', 'info');
          }
        });
      });

      // End Session Button in AppBar
      document.getElementById('btn-proctor-end-session')?.addEventListener('click', () => {
        this._confirmProctorAction({
          title: 'End Paper Session?',
          content: 'ඔබට මෙම Paper Session එක අවසන් කිරීමට අවශ්‍ය බව සහතිකද?\n\nසැසිය අවසන් කළ පසු සියලුම සිසුන්ගේ විභාග කාමරය වසා දැමෙන අතර නව submissions ලබාගත නොහැක.',
          confirmText: 'End Session (අවසන් කරන්න)',
          confirmColor: '#EF4444',
          onConfirm: async () => {
            await dbService.endPaperSession(session.id);
            notificationService.showInAppBanner('Session Ended', 'Exam session has been officially ended.', 'warning');
          }
        });
      });

      // Broadcast Alert Button
      document.getElementById('btn-proctor-broadcast')?.addEventListener('click', () => {
        this._showProctorBroadcastDialog(session.id);
      });

      // Phase Control Buttons
      modal.querySelectorAll('[data-set-phase]').forEach(btn => {
        btn.addEventListener('click', async () => {
          const targetPhase = btn.dataset.setPhase;
          await dbService.setSessionPhase(session.id, targetPhase);
          notificationService.showInAppBanner('Phase Updated', `Transitioned to: ${targetPhase.toUpperCase()}`, 'info');
        });
      });

      modal.querySelectorAll('[data-restart-10m]').forEach(btn => {
        btn.addEventListener('click', async () => {
          await dbService.setSessionPhase(session.id, 'package_opening', { forceResetTimer: true });
          notificationService.showInAppBanner('10m Timer Restarted', 'Package opening timer reset to 10:00', 'info');
        });
      });

      modal.querySelectorAll('[data-trigger-time-up]').forEach(btn => {
        btn.addEventListener('click', async () => {
          await dbService.triggerTimeUp(session.id);
          notificationService.showInAppBanner('Time Up Triggered', 'Time is Up alert sent!', 'info');
        });
      });

      modal.querySelectorAll('[data-end-now]').forEach(btn => {
        btn.addEventListener('click', async () => {
          await dbService.endPaperSession(session.id);
          notificationService.showInAppBanner('Session Ended', 'Session closed.', 'warning');
        });
      });

      // Student Item Actions
      modal.querySelectorAll('.btn-alert-student').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const student = allStudents.find(s => s.studentId === btn.dataset.studentId);
          if (student) this._showDirectAlertSheet(session.id, student);
        });
      });

      modal.querySelectorAll('.btn-view-answers').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const student = allStudents.find(s => s.studentId === btn.dataset.studentId);
          if (student) this._showSubmissionViewer(student);
        });
      });

      modal.querySelectorAll('.btn-full-view, .student-camera-box').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const student = allStudents.find(s => s.studentId === btn.dataset.studentId);
          if (student) this._showFullScreenStudentViewer(session.id, student);
        });
      });
    };

    // Real-Time Listeners (Matching Dart _sessionStream & _allRegistrationsStream)
    const unsubSession = dbService.streamPaperSession(session.id, (updatedSession) => {
      if (updatedSession) {
        session = { ...session, ...updatedSession };
        render();
      }
    });
    unsubs.push(unsubSession);

    const unsubRegs = dbService.streamSlotRegistrations(session.id, 'all', (regs) => {
      allStudents = regs || [];
      render();
      const fsModal = document.getElementById('proctor-fullscreen-modal');
      if (fsModal) {
        const currentFsStudent = allStudents.find(s => s.studentId === fsModal.dataset.studentId);
        if (currentFsStudent && currentFsStudent.cameraSnapshotUrl) {
          const img = fsModal.querySelector('#fs-student-stream');
          if (img) {
            img.src = currentFsStudent.cameraSnapshotUrl;
          } else {
            const feedContainer = fsModal.querySelector('#fs-feed-container');
            if (feedContainer) {
              feedContainer.innerHTML = `<img id="fs-student-stream" src="${currentFsStudent.cameraSnapshotUrl}" style="max-width:100%; max-height:100%; object-fit:contain;" />`;
            }
          }
        }
      }
    });
    unsubs.push(unsubRegs);

    render();
    document.body.appendChild(modal);
  }

  // Helper: Confirmation Dialog matching Flutter AlertDialog
  _confirmProctorAction({ title, content, confirmText, confirmColor = '#6366F1', onConfirm }) {
    const dialog = document.createElement('div');
    dialog.style.cssText = 'position:fixed; inset:0; background:rgba(0,0,0,0.7); display:flex; justify-content:center; align-items:center; z-index:10025;';
    dialog.innerHTML = `
      <div style="background:#1E293B; border-radius:16px; border:1px solid #334155; padding:20px; width:90%; max-width:380px; color:#FFFFFF; font-family:'Poppins',sans-serif; box-shadow:0 20px 40px rgba(0,0,0,0.5);">
        <div style="font-size:15px; font-weight:700; margin-bottom:10px;">${title}</div>
        <div style="font-size:12px; color:#CBD5E1; line-height:1.5; margin-bottom:18px; white-space:pre-line;">${content}</div>
        <div style="display:flex; justify-content:flex-end; gap:8px;">
          <button id="dialog-btn-cancel" style="background:transparent; border:none; color:#94A3B8; font-size:12px; font-weight:600; padding:6px 12px; cursor:pointer;">Cancel</button>
          <button id="dialog-btn-confirm" style="background:${confirmColor}; border:none; color:${confirmColor === '#F59E0B' ? '#000000' : '#FFFFFF'}; border-radius:8px; font-size:12px; font-weight:700; padding:6px 14px; cursor:pointer;">${confirmText}</button>
        </div>
      </div>
    `;
    dialog.querySelector('#dialog-btn-cancel').onclick = () => dialog.remove();
    dialog.querySelector('#dialog-btn-confirm').onclick = async () => {
      dialog.remove();
      if (onConfirm) await onConfirm();
    };
    document.body.appendChild(dialog);
  }

  // Helper: Broadcast Announcement Dialog (_showBroadcastDialog)
  _showProctorBroadcastDialog(paperId) {
    const dialog = document.createElement('div');
    dialog.style.cssText = 'position:fixed; inset:0; background:rgba(0,0,0,0.7); display:flex; justify-content:center; align-items:center; z-index:10025;';
    dialog.innerHTML = `
      <div style="background:#1E293B; border-radius:16px; border:1px solid #334155; padding:20px; width:90%; max-width:400px; color:#FFFFFF; font-family:'Poppins',sans-serif;">
        <div style="display:flex; align-items:center; gap:8px; margin-bottom:4px;">
          <span class="material-symbols-rounded filled" style="font-size:20px; color:#F59E0B;">campaign</span>
          <span style="font-size:14px; font-weight:700;">Broadcast Announcement</span>
        </div>
        <div style="font-size:11px; color:#94A3B8; margin-bottom:14px;">සියලුම සිසුන්ගේ තිරය මත ක්ෂණිකව දිස්වන නිවේදනයක් යවන්න.</div>
        <textarea id="broadcast-msg-input" rows="3" placeholder="පණිවිඩය මෙහි ටයිප් කරන්න..." style="width:100%; background:#0F172A; border:1px solid #334155; border-radius:10px; color:#FFFFFF; padding:10px; font-size:12px; resize:none; margin-bottom:14px; box-sizing:border-box;"></textarea>
        <div style="display:flex; justify-content:flex-end; gap:8px;">
          <button id="dialog-broadcast-cancel" style="background:transparent; border:none; color:#94A3B8; font-size:12px; cursor:pointer; padding:6px 12px;">Cancel</button>
          <button id="dialog-broadcast-send" style="background:#F59E0B; border:none; color:#000000; border-radius:8px; font-size:12px; font-weight:700; padding:6px 14px; cursor:pointer;">Broadcast Alert</button>
        </div>
      </div>
    `;
    dialog.querySelector('#dialog-broadcast-cancel').onclick = () => dialog.remove();
    dialog.querySelector('#dialog-broadcast-send').onclick = async () => {
      const msg = dialog.querySelector('#broadcast-msg-input').value.trim();
      if (!msg) return;
      dialog.remove();
      await dbService.broadcastProctorAlert({
        paperId,
        senderName: 'Admin / Examiner',
        message: msg,
        type: 'info'
      });
      notificationService.showInAppBanner('Broadcast Sent', 'Announcement sent to all students!', 'info');
    };
    document.body.appendChild(dialog);
  }

  // Helper: Direct Proctor Alert Sheet (_showDirectMessageSheet)
  _showDirectAlertSheet(paperId, student) {
    const sheet = document.createElement('div');
    sheet.style.cssText = 'position:fixed; inset:0; background:rgba(0,0,0,0.7); display:flex; justify-content:center; align-items:flex-end; z-index:10020;';
    const quickWarnings = [
      'කරුණාකර ඔබගේ මේසය සහ පිළිතුරු පත්‍රය පෙනෙන සේ කැමරාව සකසන්න. (Please adjust camera angle)',
      'ඔබගේ මුහුණ සහ පරිසරය පැහැදිලිව නොපෙනේ. (Please improve lighting/position)',
      'විභාග කාලය අවසන් වීමට විනාඩි 15 ක් ඉතිරිව ඇත. (15 Minutes Remaining)',
      'කරුණාකර අවධානයෙන් පිළිතුරු ලියන්න. වෙනත් කටයුතු වලින් වළකින්න.'
    ];

    sheet.innerHTML = `
      <div style="background:#1E293B; border-radius:20px 20px 0 0; border:1px solid #334155; padding:20px; width:100%; max-width:440px; color:#FFFFFF; font-family:'Poppins',sans-serif; box-sizing:border-box;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
          <div>
            <div style="font-size:14px; font-weight:700; color:#FFFFFF;">Direct Proctor Alert (ශිෂ්‍යයාට පණිවිඩයක්)</div>
            <div style="font-size:11px; color:#94A3B8;">To: ${student.studentName} (${student.studentPhone || ''})</div>
          </div>
          <button id="sheet-close-btn" style="background:transparent; border:none; color:#94A3B8; cursor:pointer; display:inline-flex; align-items:center; justify-content:center;">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="font-size:11px; font-weight:600; color:#CBD5E1; margin-bottom:8px;">ක්ෂණික අනතුරු ඇඟවීම් (Quick Warnings):</div>
        <div style="display:flex; flex-direction:column; gap:6px; margin-bottom:12px;">
          ${quickWarnings.map(w => `
            <button class="quick-warn-chip" data-msg="${w}" style="text-align:left; background:#0F172A; border:1px solid #334155; border-radius:8px; padding:6px 10px; font-size:10.5px; color:#E2E8F0; cursor:pointer;">
              ${w}
            </button>
          `).join('')}
        </div>

        <textarea id="direct-msg-input" rows="3" placeholder="පණිවිඩය මෙහි ටයිප් කරන්න..." style="width:100%; background:#0F172A; border:1px solid #334155; border-radius:10px; color:#FFFFFF; padding:10px; font-size:12px; resize:none; margin-bottom:12px; box-sizing:border-box;"></textarea>

        <button id="direct-send-btn" style="width:100%; height:40px; background:#6366F1; color:#FFFFFF; border:none; border-radius:10px; font-size:12px; font-weight:700; cursor:pointer;">
          Send Instant Alert to Student
        </button>
      </div>
    `;

    sheet.querySelector('#sheet-close-btn').onclick = () => sheet.remove();
    sheet.querySelectorAll('.quick-warn-chip').forEach(chip => {
      chip.onclick = () => {
        sheet.querySelector('#direct-msg-input').value = chip.dataset.msg;
      };
    });
    sheet.querySelector('#direct-send-btn').onclick = async () => {
      const msg = sheet.querySelector('#direct-msg-input').value.trim();
      if (!msg) return;
      sheet.remove();
      await dbService.sendProctorAlert({
        paperId,
        studentId: student.studentId,
        studentPhone: student.studentPhone,
        senderName: 'Admin / Examiner',
        message: msg,
        type: 'warning'
      });
      notificationService.showInAppBanner('Alert Sent', `Alert sent to ${student.studentName}!`, 'info');
    };
    document.body.appendChild(sheet);
  }

  // Helper: Submission Viewer (_showStudentSubmissionViewer)
  _showSubmissionViewer(student) {
    const modal = document.createElement('div');
    modal.style.cssText = 'position:fixed; inset:0; background:rgba(0,0,0,0.85); display:flex; justify-content:center; align-items:center; z-index:10020;';
    const photos = student.submissionPhotos || [];

    modal.innerHTML = `
      <div style="background:#1E293B; border-radius:20px; border:1px solid #334155; width:92%; max-width:440px; max-height:85vh; display:flex; flex-direction:column; overflow:hidden; font-family:'Poppins',sans-serif; color:#FFFFFF;">
        <div style="padding:14px 16px; border-bottom:1px solid #334155; display:flex; justify-content:space-between; align-items:center;">
          <div>
            <div style="font-size:14px; font-weight:700;">${student.studentName}</div>
            <div style="font-size:11px; color:#94A3B8;">${student.studentPhone || ''} • Submitted ${photos.length} Pages</div>
          </div>
          <button id="view-ans-close" style="background:transparent; border:none; color:#94A3B8; cursor:pointer; display:inline-flex; align-items:center; justify-content:center;">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>

        <div style="flex:1; overflow-y:auto; padding:14px; display:flex; flex-direction:column; gap:12px;">
          ${photos.length === 0 ? `
            <div style="text-align:center; padding:32px; color:#94A3B8; font-size:12px;">No answer sheet photos attached yet.</div>
          ` : photos.map((p, idx) => `
            <div style="background:#0F172A; border-radius:12px; border:1px solid #334155; overflow:hidden;">
              <div style="padding:8px 10px; background:#111827; font-size:11px; font-weight:700; color:#4ADE80;">Page ${idx + 1}</div>
              <img src="${p}" style="width:100%; max-height:350px; object-fit:contain; background:#000000;" />
            </div>
          `).join('')}
        </div>
      </div>
    `;

    modal.querySelector('#view-ans-close').onclick = () => modal.remove();
    document.body.appendChild(modal);
  }

  // Helper: Full Screen Student Viewer (_showFullScreenStudentViewer)
  _showFullScreenStudentViewer(paperId, student) {
    const modal = document.createElement('div');
    modal.id = 'proctor-fullscreen-modal';
    modal.dataset.studentId = student.studentId;
    modal.style.cssText = 'position:fixed; inset:0; background:#0F172A; display:flex; flex-direction:column; z-index:10002; font-family:Poppins,sans-serif;';
    modal.innerHTML = `
      <div style="background:#1E293B; padding:14px 16px; display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #334155;">
        <div>
          <div style="font-size:14px; font-weight:700; color:#FFFFFF;">${student.studentName}</div>
          <div style="font-size:11px; color:#94A3B8;">Surveillance Monitor • Slot: ${student.selectedSlot || 'slot1'}</div>
        </div>
        <button id="fs-close-btn" style="background:#334155; border:none; color:#FFFFFF; border-radius:8px; padding:6px 12px; font-size:12px; font-weight:600; cursor:pointer; display:inline-flex; align-items:center; gap:4px;">
          <span class="material-symbols-rounded" style="font-size:16px;">fullscreen_exit</span>
          <span>Exit Full View</span>
        </button>
      </div>

      <div style="flex:1; display:flex; align-items:center; justify-content:center; background:#000000; position:relative; overflow:hidden;" id="fs-feed-container">
        ${student.cameraSnapshotUrl ? `
          <img id="fs-student-stream" src="${student.cameraSnapshotUrl}" style="max-width:100%; max-height:100%; object-fit:contain;" />
        ` : `
          <div id="fs-student-stream-placeholder" style="text-align:center; color:#94A3B8;">
            <span class="material-symbols-rounded" style="font-size:48px; margin-bottom:12px; color:#64748B;">videocam</span>
            <div style="font-size:14px; font-weight:600;">Active Proctoring Feed</div>
            <div style="font-size:11px;">Audio & Video Active • Real-time Monitoring</div>
          </div>
        `}
      </div>

      <div style="background:#1E293B; padding:12px 16px; display:flex; justify-content:space-between; align-items:center; border-top:1px solid #334155;">
        <button id="fs-warn-btn" style="background:#EF4444; color:#FFFFFF; border:none; border-radius:8px; padding:8px 16px; font-size:12px; font-weight:700; cursor:pointer; display:inline-flex; align-items:center; gap:6px;">
          <span class="material-symbols-rounded filled" style="font-size:15px;">warning</span> Issue Direct Warning
        </button>
        ${(student.submissionPhotos?.length || student.status === 'submitted') ? `
          <button id="fs-answers-btn" style="background:#22C55E; color:#FFFFFF; border:none; border-radius:8px; padding:8px 16px; font-size:12px; font-weight:700; cursor:pointer;">
            View Submitted Answers
          </button>
        ` : ''}
      </div>
    `;

    modal.querySelector('#fs-close-btn').onclick = () => modal.remove();
    modal.querySelector('#fs-warn-btn').onclick = () => {
      this._showDirectAlertSheet(paperId, student);
    };
    modal.querySelector('#fs-answers-btn')?.addEventListener('click', () => {
      this._showSubmissionViewer(student);
    });

    document.body.appendChild(modal);
  }

  // ── B. Student Live Exam Writing Room (1:1 with live_exam_room_screen.dart & in_app_document_scanner_screen.dart) ──
  async openStudentLiveExamRoom(paperId, slotId = 'slot1') {
    const student = this.currentUser || { id: 's_default', name: 'Student', phone: '' };
    const studentId = student.uid || student.id || 's_default';
    const studentName = student.name || student.displayName || 'Student';
    const studentPhone = student.phone || student.phoneNumber || '';

    // 1. Check if student already submitted this paper (matching _checkIfAlreadySubmitted)
    const existingReg = await dbService.getStudentRegistration(paperId, studentId);
    if (existingReg && (existingReg.isSubmitted || existingReg.status === 'submitted')) {
      const alreadySubmittedModal = document.createElement('div');
      alreadySubmittedModal.className = 'app-modal';
      alreadySubmittedModal.style.cssText = 'display:flex; justify-content:center; align-items:center; background:rgba(15,23,42,0.85); z-index:99999;';
      alreadySubmittedModal.innerHTML = `
        <div style="background:#1E293B; border-radius:16px; border:1px solid #334155; padding:24px; max-width:440px; width:90%; color:#F8FAFC; box-shadow:0 20px 40px rgba(0,0,0,0.6); font-family:'Poppins',sans-serif;">
          <div style="display:flex; align-items:center; gap:10px; margin-bottom:14px;">
            <span class="material-symbols-rounded filled" style="color:#22C55E; font-size:28px;">check_circle</span>
            <h3 style="font-size:16px; font-weight:700; color:#FFFFFF; margin:0;">Paper Already Submitted</h3>
          </div>
          <p style="font-size:13px; color:#CBD5E1; line-height:1.5; margin:0 0 20px 0;">
            ඔබ මෙම විභාගයේ පිළිතුරු පත්‍ර දැනටමත් සාර්ථකව භාරදී ඇත. නැවත විභාග ශාලාවට පිවිසීමට අවශ්‍ය නොවේ.
          </p>
          <div style="display:flex; justify-content:flex-end;">
            <button id="btn-submitted-ok" style="background:#22C55E; color:#FFFFFF; border:none; padding:10px 20px; border-radius:8px; font-size:13px; font-weight:700; cursor:pointer;">
              හරි (OK)
            </button>
          </div>
        </div>
      `;
      document.body.appendChild(alreadySubmittedModal);
      alreadySubmittedModal.querySelector('#btn-submitted-ok')?.addEventListener('click', () => {
        alreadySubmittedModal.remove();
      });
      return;
    }

    // Auto-register student if not yet registered (matching _ensureStudentRegistered)
    await dbService.registerStudentSlot({
      paperId,
      studentId,
      studentName,
      studentPhone,
      slotId: slotId || 'slot1'
    });

    // 2. Fetch session from Firestore
    let session = await dbService.getPaperSession(paperId);
    if (!session) {
      session = {
        id: paperId,
        title: 'Physics Mock Exam',
        subject: 'Physics',
        durationMinutes: 150,
        currentPhase: 'waiting',
        status: 'live',
        slot1: { name: 'Slot 1 (08:30 AM)', startTime: '08:30' },
        slot2: { name: 'Slot 2 (04:00 PM)', startTime: '16:00' }
      };
    }

    // Fullscreen View Container matching Flutter Scaffold
    const roomContainer = document.createElement('div');
    roomContainer.id = 'live-exam-room-root';
    roomContainer.style.cssText = `
      position: fixed; inset: 0; background: #0F172A; z-index: 99999;
      display: flex; flex-direction: column; color: #F8FAFC;
      font-family: 'Poppins', sans-serif; overflow: hidden;
    `;

    // State Variables
    let cameraStream = null;
    let cameraActive = false;
    let heartbeatInterval = null;
    let syncInterval = null;
    let timerInterval = null;
    let isBigTimerMinimized = false;
    let facingMode = 'user'; // front / user camera
    let now = new Date();
    let shownAlertIds = new Set();

    // Time calculations matching Flutter
    const getSlot = () => (slotId === 'slot2' && session.slot2 ? session.slot2 : (session.slot1 || { name: 'Morning Slot 1', startTime: '08:30' }));
    
    let captureCanvas = null;
    const captureSnapshot = () => {
      if (!cameraActive || !cameraStream) return null;
      const videoEl = roomContainer.querySelector('.proctor-video-feed');
      if (!videoEl || videoEl.readyState < 2 || !videoEl.videoWidth) return null;
      try {
        if (!captureCanvas) {
          captureCanvas = document.createElement('canvas');
        }
        captureCanvas.width = 320;
        captureCanvas.height = Math.round(320 * (videoEl.videoHeight / videoEl.videoWidth)) || 240;
        const ctx = captureCanvas.getContext('2d');
        ctx.drawImage(videoEl, 0, 0, captureCanvas.width, captureCanvas.height);
        return captureCanvas.toDataURL('image/jpeg', 0.52);
      } catch (err) {
        return null;
      }
    };

    // Heartbeat function matching Flutter _sendHeartbeat
    const sendHeartbeat = async (isActive) => {
      try {
        const snap = isActive ? captureSnapshot() : null;
        await dbService.updateCameraHeartbeat({
          paperId,
          studentId,
          studentName,
          studentPhone,
          slotId: slotId || 'slot1',
          isCameraActive: isActive,
          cameraSnapshotUrl: snap,
          status: 'in_exam'
        });
      } catch (e) {
        console.warn('Heartbeat error:', e);
      }
    };

    // Camera Init using WebRTC getUserMedia
    const initCamera = async () => {
      const overlay = roomContainer.querySelector('#camera-loading-overlay');
      const loadText = roomContainer.querySelector('#camera-loading-text');
      const loadIcon = roomContainer.querySelector('#camera-loading-icon');
      const retryBtn = roomContainer.querySelector('#btn-retry-camera');
      if (overlay && !cameraActive) {
        overlay.style.display = 'flex';
        if (loadText) loadText.textContent = 'කැමරාව ආරම්භ වෙමින් පවතී...';
        if (loadIcon) loadIcon.textContent = 'videocam_off';
        if (retryBtn) { retryBtn.textContent = 'සම්බන්ධ වෙමින්...'; retryBtn.disabled = true; }
      }
      try {
        if (cameraStream) {
          cameraStream.getTracks().forEach(t => t.stop());
        }
        cameraStream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode, width: { ideal: 1280 }, height: { ideal: 720 } },
          audio: false
        });
        cameraActive = true;
        const videoEls = roomContainer.querySelectorAll('.proctor-video-feed');
        videoEls.forEach(v => {
          v.srcObject = cameraStream;
          v.play().catch(() => {});
        });
        if (overlay) overlay.style.display = 'none';
        updateCameraStatusBadges(true);
        setTimeout(() => sendHeartbeat(true), 800);
      } catch (err) {
        console.warn('Camera init error:', err);
        cameraActive = false;
        if (overlay) {
          overlay.style.display = 'flex';
          if (loadText) loadText.textContent = 'කැමරා ප්‍රවේශය අසාර්ථක විය (Camera Failed)';
          if (loadIcon) loadIcon.textContent = 'error';
          if (retryBtn) { retryBtn.textContent = 'නැවත උත්සාහ කරන්න (Retry)'; retryBtn.disabled = false; }
        }
        updateCameraStatusBadges(false);
        sendHeartbeat(false);
      } finally {
        if (retryBtn) retryBtn.disabled = false;
      }
    };

    const updateCameraStatusBadges = (online) => {
      const badges = roomContainer.querySelectorAll('.camera-status-pill');
      badges.forEach(b => {
        if (online) {
          b.style.background = 'rgba(34, 197, 94, 0.2)';
          b.style.border = '1px solid #22C55E';
          b.style.color = '#4ADE80';
          b.innerHTML = '<span class="material-symbols-rounded filled" style="font-size:11px; vertical-align:middle; margin-right:2px;">fiber_manual_record</span>Online';
        } else {
          b.style.background = 'rgba(239, 68, 68, 0.2)';
          b.style.border = '1px solid #EF4444';
          b.style.color = '#FCA5A5';
          b.innerHTML = '<span class="material-symbols-rounded filled" style="font-size:11px; vertical-align:middle; margin-right:2px;">fiber_manual_record</span>Offline';
        }
      });
    };

    // Calculate time metrics matching live_exam_room_screen.dart
    const calculateTimes = () => {
      const isEnded = session.status === 'completed' || session.currentPhase === 'ended';
      const isTimeUp = session.isTimeUp || session.currentPhase === 'time_up';
      const isWaiting = session.currentPhase === 'waiting' || session.status === 'scheduled';
      const isPackageOpening = session.currentPhase === 'package_opening';
      const isWriting = session.currentPhase === 'writing' || (!isWaiting && !isPackageOpening && !isTimeUp && !isEnded);

      // Package opening 10 mins countdown (600s)
      let pkgSecsLeft = 600;
      if (isPackageOpening) {
        let startTime = session.packageOpeningStartedAt ? new Date(session.packageOpeningStartedAt) : null;
        if (!startTime) {
          const cached = localStorage.getItem(`paper_pkg_start_${session.id}`);
          if (cached) startTime = new Date(cached);
          else {
            startTime = new Date();
            localStorage.setItem(`paper_pkg_start_${session.id}`, startTime.toISOString());
          }
        }
        const elapsed = Math.max(0, Math.floor((new Date() - startTime) / 1000));
        pkgSecsLeft = Math.max(0, 600 - elapsed);
      }

      // Exam Writing countdown
      const totalWritingSecs = (session.durationMinutes || 150) * 60;
      let writingSecsLeft = totalWritingSecs;
      let isOvertime = false;
      let overtimeSecs = 0;

      if (isWriting) {
        let startTime = session.writingStartedAt ? new Date(session.writingStartedAt) : null;
        if (!startTime) {
          const cached = localStorage.getItem(`paper_writing_start_${session.id}`);
          if (cached) startTime = new Date(cached);
          else {
            startTime = new Date();
            localStorage.setItem(`paper_writing_start_${session.id}`, startTime.toISOString());
          }
        }
        const elapsed = Math.max(0, Math.floor((new Date() - startTime) / 1000));
        if (elapsed > totalWritingSecs) {
          isOvertime = true;
          overtimeSecs = elapsed - totalWritingSecs;
          writingSecsLeft = 0;
        } else {
          writingSecsLeft = totalWritingSecs - elapsed;
        }
      }

      return { isEnded, isTimeUp, isWaiting, isPackageOpening, isWriting, isOvertime, pkgSecsLeft, writingSecsLeft, overtimeSecs };
    };

    // Render Room Function
    const renderRoom = () => {
      const times = calculateTimes();
      const slot = getSlot();

      // Top live timer pill text and colors matching Flutter
      let timerText = 'Waiting';
      let timerColor = '#818CF8';
      let timerIcon = 'hourglass_top';

      if (times.isEnded) {
        timerText = 'Ended';
        timerColor = '#EF4444';
        timerIcon = 'close';
      } else if (times.isTimeUp) {
        timerText = 'Time Up';
        timerColor = '#EF4444';
        timerIcon = 'alarm';
      } else if (times.isWaiting) {
        timerText = 'Waiting';
        timerColor = '#818CF8';
        timerIcon = 'hourglass_top';
      } else if (times.isPackageOpening) {
        const m = String(Math.floor(times.pkgSecsLeft / 60)).padStart(2, '0');
        const s = String(times.pkgSecsLeft % 60).padStart(2, '0');
        timerText = times.pkgSecsLeft <= 0 ? '00:00' : `Open: ${m}:${s}`;
        timerColor = '#F59E0B';
        timerIcon = 'inventory_2';
      } else if (times.isWriting) {
        if (!times.isOvertime) {
          const h = String(Math.floor(times.writingSecsLeft / 3600)).padStart(2, '0');
          const m = String(Math.floor((times.writingSecsLeft % 3600) / 60)).padStart(2, '0');
          const s = String(times.writingSecsLeft % 60).padStart(2, '0');
          timerText = Math.floor(times.writingSecsLeft / 3600) > 0 ? `${h}:${m}:${s}` : `${m}:${s}`;
          timerColor = times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E';
          timerIcon = 'edit_note';
        } else {
          const m = String(Math.floor(times.overtimeSecs / 60)).padStart(2, '0');
          const s = String(times.overtimeSecs % 60).padStart(2, '0');
          timerText = `Extra: +${m}:${s}`;
          timerColor = '#F59E0B';
          timerIcon = 'timer';
        }
      }

      // Subtitle matching Flutter
      let subtitleText = `${slot.name || 'Slot 1'} • සජීවී විභාගය`;
      if (times.isWaiting) subtitleText = 'පොරොත්තු ශාලාව (Waiting)';
      else if (times.isPackageOpening) subtitleText = 'පාර්සල් විවෘත කිරීම';

      // Build HTML
      roomContainer.innerHTML = `
        <!-- AppBar matching Flutter AppBar -->
        <div style="background:#1E293B; height:56px; padding:0 16px; display:flex; align-items:center; justify-content:space-between; border-bottom:1px solid #334155; flex-shrink:0;">
          <div style="display:flex; align-items:center; gap:12px;">
            <button id="btn-appbar-back" style="background:transparent; border:none; color:#FFFFFF; font-size:18px; cursor:pointer; display:flex; align-items:center; padding:4px;">
              <span class="material-symbols-rounded">arrow_back</span>
            </button>
            <div>
              <div style="font-size:14px; font-weight:600; color:#FFFFFF; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:240px;">
                ${session.title}
              </div>
              <div style="font-size:11px; color:#94A3B8;">
                ${subtitleText}
              </div>
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:8px;">
${!times.isWaiting ? `
              <button id="btn-appbar-flip" title="Flip Camera" style="background:transparent; border:none; color:#FFFFFF; font-size:18px; cursor:pointer; padding:6px; display:flex; align-items:center;">
                <span class="material-symbols-rounded">flip_camera_ios</span>
              </button>
            ` : ''}
            <!-- Upgraded Live Timer Pill -->
            <div id="live-timer-pill" style="background:${timerColor}38; border:1.8px solid ${timerColor}; box-shadow:0 0 10px ${timerColor}4D; border-radius:20px; padding:5px 12px; display:flex; align-items:center; gap:6px;">
              <span class="material-symbols-rounded filled timer-icon" style="font-size:16px; color:${timerColor};">${timerIcon}</span>
              <span class="timer-text" style="font-size:13.5px; font-weight:800; color:${timerColor}; letter-spacing:0.5px;">${timerText}</span>
            </div>
          </div>
        </div>

        <!-- Body matching live_exam_room_screen.dart -->
        <div style="flex:1; position:relative; overflow:hidden; display:flex; flex-direction:column;">
          ${times.isWaiting ? `
            <!-- ── A. WAITING ROOM VIEW (_buildWaitingRoomView) ── -->
            <div style="flex:1; overflow-y:auto; padding:16px; max-width:680px; width:100%; margin:0 auto;">
              <!-- 1. Top Waiting Notice Card -->
              <div style="padding:16px; border-radius:16px; background:linear-gradient(135deg, rgba(99,102,241,0.25), #0F172A); border:1px solid rgba(99,102,241,0.4); display:flex; gap:14px; align-items:flex-start;">
                <div style="width:44px; height:44px; border-radius:50%; background:rgba(99,102,241,0.3); display:flex; align-items:center; justify-content:center; color:#A5B4FC; flex-shrink:0;">
                  <span class="material-symbols-rounded filled" style="font-size:24px;">hourglass_top</span>
                </div>
                <div>
                  <div style="font-size:14px; font-weight:700; color:#FFFFFF; margin-bottom:4px;">
                    විභාග පොරොත්තු ශාලාව (Waiting Room)
                  </div>
                  <div style="font-size:12px; font-weight:600; color:#38BDF8; margin-bottom:6px;">
                    නියමිත වේලාව: ${slot.startTime || '08:30'} (${slot.name || 'Slot 1'})
                  </div>
                  <div style="font-size:11px; color:#CBD5E1; line-height:1.45;">
                    විභාගය නියමිත වේලාවට ස්වයංක්‍රීයව ආරම්භ නොවේ. විභාග පරීක්ෂක විසින් විභාගය ආරම්භ කරන තෙක් කරුණාකර මෙම තිරයේ රැඳී සිටින්න. ඔවුන් සැසිය ආරම්භ කළ වහාම තිරය සජීවී විභාගයට මාරු වේ.
                  </div>
                </div>
              </div>

              <!-- 2. Camera Self-Check Box -->
              <div style="margin-top:16px; background:#1E293B; border-radius:16px; border:1px solid #334155; overflow:hidden;">
                <div style="padding:10px 14px; display:flex; align-items:center; justify-content:space-between; border-bottom:1px solid #334155;">
                  <div style="display:flex; align-items:center; gap:8px;">
                    <span class="material-symbols-rounded" style="color:#22C55E; font-size:18px;">videocam</span>
                    <span style="font-size:12px; font-weight:600; color:#FFFFFF;">කැමරා පූර්ව පරීක්ෂාව (Self-Check)</span>
                  </div>
                  <div class="camera-status-pill" style="padding:3px 8px; border-radius:10px; font-size:10px; font-weight:700; ${cameraActive ? 'background:rgba(34,197,94,0.2); border:1px solid #22C55E; color:#4ADE80;' : 'background:rgba(239,68,68,0.2); border:1px solid #EF4444; color:#FCA5A5;'}">
                    ${cameraActive ? '<span class="material-symbols-rounded filled" style="font-size:11px; vertical-align:middle; margin-right:2px;">fiber_manual_record</span>Online' : '<span class="material-symbols-rounded filled" style="font-size:11px; vertical-align:middle; margin-right:2px;">fiber_manual_record</span>Offline'}
                  </div>
                </div>
                <div style="height:220px; width:100%; background:#000000; position:relative; display:flex; align-items:center; justify-content:center;">
                  <video class="proctor-video-feed" autoplay playsinline muted style="width:100%; height:100%; object-fit:cover;"></video>
                  <div id="camera-loading-overlay" style="position:absolute; display:${cameraActive ? 'none' : 'flex'}; flex-direction:column; align-items:center; gap:8px; color:#94A3B8; text-align:center; padding:16px; background:rgba(0,0,0,0.6); border-radius:12px; pointer-events:auto;">
                    <span id="camera-loading-icon" class="material-symbols-rounded" style="font-size:32px; color:#64748B;">videocam_off</span>
                    <div id="camera-loading-text" style="font-size:11px;">කැමරාව ආරම්භ වෙමින් පවතී...</div>
                    <button id="btn-retry-camera" style="background:#6366F1; color:#FFFFFF; border:none; padding:6px 12px; border-radius:6px; font-size:11px; font-weight:600; cursor:pointer;">නැවත උත්සාහ කරන්න (Retry)</button>
                  </div>
                </div>
                <div style="padding:12px; display:flex; align-items:center; justify-content:space-between;">
                  <div style="display:flex; align-items:center; gap:6px; font-size:10.5px; color:#94A3B8;">
                    <span class="material-symbols-rounded filled" style="color:#22C55E; font-size:16px;">check_circle</span>
                    <span>ඔබගේ මුහුණ සහ විභාග මේසය පැහැදිලිව පෙනෙන සේ තබන්න.</span>
                  </div>
                  <button id="btn-flip-self-check" style="background:transparent; border:none; color:#818CF8; font-size:11px; font-weight:600; cursor:pointer; display:flex; align-items:center; gap:4px;">
                    <span class="material-symbols-rounded" style="font-size:14px;">flip_camera_ios</span> Flip
                  </button>
                </div>
              </div>

              <!-- 3. Exam Preparations Checklist -->
              <div style="margin-top:16px; background:#1E293B; border-radius:16px; border:1px solid #334155; padding:16px;">
                <div style="display:flex; align-items:center; gap:10px; margin-bottom:14px;">
                  <span class="material-symbols-rounded filled" style="color:#F59E0B; font-size:20px;">assignment</span>
                  <span style="font-size:13px; font-weight:700; color:#FFFFFF;">විභාග උපදෙස් (Exam Checklist)</span>
                </div>
                <div style="display:flex; flex-direction:column; gap:12px;">
                  <div style="display:flex; gap:10px; align-items:flex-start;">
                    <div style="width:26px; height:26px; border-radius:50%; background:rgba(245,158,11,0.15); display:flex; align-items:center; justify-content:center; color:#F59E0B; flex-shrink:0;">
                      <span class="material-symbols-rounded filled" style="font-size:15px;">inventory_2</span>
                    </div>
                    <div>
                      <div style="font-size:11.5px; font-weight:600; color:#FFFFFF;">මුද්‍රා තැබූ ප්‍රශ්න පත්‍ර පාර්සලය මේසය මත තබාගන්න</div>
                      <div style="font-size:10px; color:#94A3B8;">පරීක්ෂක විසින් විධානය දෙන තුරු කිසිසේත්ම විවෘත නොකරන්න.</div>
                    </div>
                  </div>
                  <div style="display:flex; gap:10px; align-items:flex-start;">
                    <div style="width:26px; height:26px; border-radius:50%; background:rgba(56,189,248,0.15); display:flex; align-items:center; justify-content:center; color:#38BDF8; flex-shrink:0;">
                      <span class="material-symbols-rounded filled" style="font-size:15px;">content_cut</span>
                    </div>
                    <div>
                      <div style="font-size:11.5px; font-weight:600; color:#FFFFFF;">පාර්සලය විවෘත කිරීමට කතුරක්/බ්ලේඩයක් සූදානම් කරගන්න</div>
                      <div style="font-size:10px; color:#94A3B8;">කැමරාව ඉදිරියේ පළමු මිනිත්තු 10 තුළ විවෘත කළ යුතුය.</div>
                    </div>
                  </div>
                  <div style="display:flex; gap:10px; align-items:flex-start;">
                    <div style="width:26px; height:26px; border-radius:50%; background:rgba(34,197,94,0.15); display:flex; align-items:center; justify-content:center; color:#22C55E; flex-shrink:0;">
                      <span class="material-symbols-rounded filled" style="font-size:15px;">lightbulb</span>
                    </div>
                    <div>
                      <div style="font-size:11.5px; font-weight:600; color:#FFFFFF;">ප්‍රමාණවත් ආලෝකය සහ ස්ථාවර ආධාරකයක් භාවිතා කරන්න</div>
                      <div style="font-size:10px; color:#94A3B8;">දුරකථනය නොසෙල්වෙන සේ මේසය මත රඳවා තබන්න.</div>
                    </div>
                  </div>
                  <div style="display:flex; gap:10px; align-items:flex-start;">
                    <div style="width:26px; height:26px; border-radius:50%; background:rgba(165,180,252,0.15); display:flex; align-items:center; justify-content:center; color:#A5B4FC; flex-shrink:0;">
                      <span class="material-symbols-rounded filled" style="font-size:15px;">lock</span>
                    </div>
                    <div>
                      <div style="font-size:11.5px; font-weight:600; color:#FFFFFF;">මෙම තිරයෙන් ඉවත් නොවන්න</div>
                      <div style="font-size:10px; color:#94A3B8;">තිරය ස්වයංක්‍රීයව ක්‍රියා විරහිත නොවන පරිදි සකසා ඇත.</div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- 4. Pulse Status -->
              <div style="margin:20px 0; text-align:center;">
                <div style="display:inline-flex; align-items:center; gap:8px; padding:8px 16px; background:#0F172A; border:1px solid #334155; border-radius:20px; font-size:11px; color:#94A3B8;">
                  <span class="material-symbols-rounded" style="font-size:16px; color:#22C55E;">sensors</span>
                  <span>Examiner Connection: Active • Waiting to Start...</span>
                </div>
              </div>
            </div>
          ` : `
            <!-- ── B. LIVE SURVEILLANCE STACK (_buildFullScreenCameraView) ── -->
            <div style="position:absolute; inset:0; background:#000000; overflow:hidden;">
              <video class="proctor-video-feed" autoplay playsinline muted style="width:100%; height:100%; object-fit:cover;"></video>
              <!-- Candidate details pill -->
              <div style="position:absolute; top:16px; left:16px; background:rgba(15,23,42,0.85); backdrop-filter:blur(6px); border:1px solid #334155; border-radius:10px; padding:6px 12px; display:flex; align-items:center; gap:8px; z-index:10;">
                <span style="font-size:11.5px; font-weight:700; color:#38BDF8;">Candidate: ${student.name}</span>
                <span style="font-size:10px; background:#047857; color:#A7F3D0; padding:2px 6px; border-radius:6px; font-weight:800;">720p HD</span>
              </div>
            </div>

            <!-- Top Phase Notice Banner (_buildPhaseNoticeBanner) -->
            <div style="position:absolute; top:54px; left:16px; right:16px; z-index:20; max-width:680px; margin:0 auto;">
              ${times.isPackageOpening ? `
                <!-- 10-Minute Package Opening Banner -->
                <div style="background:rgba(15,23,42,0.95); border:2px solid ${times.pkgSecsLeft <= 0 ? '#EF4444' : '#F59E0B'}; border-radius:16px; padding:14px; box-shadow:0 8px 24px rgba(0,0,0,0.5);">
                  <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:10px;">
                    <div style="display:flex; align-items:center; gap:10px;">
                      <div style="width:36px; height:36px; border-radius:50%; background:${times.pkgSecsLeft <= 0 ? 'rgba(239,68,68,0.2)' : 'rgba(245,158,11,0.2)'}; display:flex; align-items:center; justify-content:center;">
                        <span class="material-symbols-rounded filled" style="font-size:20px; color:${times.pkgSecsLeft <= 0 ? '#EF4444' : '#F59E0B'};">inventory_2</span>
                      </div>
                      <div>
                        <div style="font-size:12px; font-weight:700; color:${times.pkgSecsLeft <= 0 ? '#EF4444' : '#F59E0B'};">
                          ${times.pkgSecsLeft <= 0 ? 'විනාඩි 10 අවසන් (Time Stopped)' : 'ප්‍රශ්න පත්‍ර පාර්සලය විවෘත කිරීම (10 Mins)'}
                        </div>
                        <div style="font-size:10px; color:#E2E8F0;">
                          ${times.pkgSecsLeft <= 0 ? 'පරීක්ෂකවරයා විභාගය ආරම්භ කරන තෙක් රැඳී සිටින්න' : 'කැමරාව ඉදිරියේ පමණක් පාර්සලය විවෘත කරන්න'}
                        </div>
                      </div>
                    </div>
                    <div id="pkg-timer-banner-pill" style="background:${times.pkgSecsLeft <= 0 ? '#EF4444' : '#F59E0B'}; color:${times.pkgSecsLeft <= 0 ? '#FFFFFF' : '#000000'}; padding:4px 8px; border-radius:8px; font-size:12px; font-weight:800;">
                      ${String(Math.floor(times.pkgSecsLeft / 60)).padStart(2, '0')}:${String(times.pkgSecsLeft % 60).padStart(2, '0')}
                    </div>
                  </div>
                  <div style="background:#1E293B; border-radius:8px; border:1px solid #334155; padding:8px 10px; font-size:10px; color:#FFFFFF; line-height:1.6;">
                    <div>1. <span class="material-symbols-rounded filled" style="font-size:14px; vertical-align:middle;">label</span> මුද්‍රා තැබූ පාර්සලය කැමරාවට පෙන්වන්න (Show sealed parcel)</div>
                    <div>2. <span class="material-symbols-rounded filled" style="font-size:14px; vertical-align:middle;">content_cut</span> කැමරාව ඉදිරියේම කපා විවෘත කරන්න (Cut open on camera)</div>
                    <div style="color:${times.pkgSecsLeft <= 0 ? '#FBBF24' : '#4ADE80'}; font-weight:${times.pkgSecsLeft <= 0 ? '700' : '400'};">
                      3. <span class="material-symbols-rounded filled" style="font-size:14px; vertical-align:middle;">description</span> පත්‍රය මේසය මත තබා ලිවීමට සූදානම් වන්න (Place on desk)
                    </div>
                  </div>
                </div>
              ` : times.isWriting ? `
                <!-- Giant High-Contrast Digital Digits HUD -->
                ${isBigTimerMinimized ? `
                  <div style="background:rgba(15,23,42,0.92); border:1.5px solid ${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}; border-radius:14px; padding:8px 14px; display:flex; align-items:center; justify-content:space-between; box-shadow:0 6px 20px rgba(0,0,0,0.5);">
                    <div style="display:flex; align-items:center; gap:8px;">
                      <span style="width:10px; height:10px; border-radius:50%; background:${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}; display:inline-block;"></span>
                      <span style="font-size:11.5px; font-weight:600; color:#FFFFFF; display:inline-flex; align-items:center;"><span class="material-symbols-rounded filled" style="font-size:15px; vertical-align:middle; margin-right:4px;">edit_note</span>ලිවීම සක්‍රීයයි • ඉතිරි කාලය:</span>
                    </div>
                    <div style="display:flex; align-items:center; gap:10px;">
                      <span id="hud-minimized-time" style="font-size:16px; font-weight:800; color:${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}; font-family:monospace;">
                        ${String(Math.floor(times.writingSecsLeft / 3600)).padStart(2, '0')}:${String(Math.floor((times.writingSecsLeft % 3600) / 60)).padStart(2, '0')}:${String(times.writingSecsLeft % 60).padStart(2, '0')}
                      </span>
                      <button id="btn-toggle-hud" style="background:rgba(255,255,255,0.12); border:none; color:#FFFFFF; border-radius:6px; padding:4px 8px; font-size:12px; cursor:pointer; display:flex; align-items:center;">
                        <span class="material-symbols-rounded" style="font-size:18px;">expand_more</span>
                      </button>
                    </div>
                  </div>
                ` : `
                  <div style="background:rgba(11,19,43,0.94); border:2px solid ${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}; border-radius:20px; padding:12px 16px; box-shadow:0 0 20px rgba(34,197,94,0.25); text-align:center;">
                    <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:10px;">
                      <div style="display:flex; align-items:center; gap:8px;">
                        <span style="width:10px; height:10px; border-radius:50%; background:${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}; box-shadow:0 0 6px ${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'};"></span>
                        <span style="font-size:11px; font-weight:700; color:#E2E8F0; letter-spacing:0.5px; display:inline-flex; align-items:center;"><span class="material-symbols-rounded filled" style="font-size:15px; vertical-align:middle; margin-right:4px;">edit_note</span>පිළිතුරු ලිවීම සක්‍රීයයි (WRITING ACTIVE)</span>
                      </div>
                      <button id="btn-toggle-hud" style="background:rgba(255,255,255,0.1); border:none; color:#94A3B8; border-radius:6px; padding:3px 8px; font-size:10px; cursor:pointer; display:flex; align-items:center; gap:4px;">
                        <span>සුළු කරන්න</span> <span class="material-symbols-rounded" style="font-size:16px;">expand_less</span>
                      </button>
                    </div>
                    <!-- Digit Tiles -->
                    <div style="display:flex; justify-content:center; align-items:center; gap:6px; margin:6px 0;">
                      <div style="display:flex; flex-direction:column; align-items:center;">
                        <div id="hud-tile-hours" style="background:#1E293B; border:1.5px solid ${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}80; border-radius:10px; padding:6px 10px; min-width:54px; font-size:26px; font-weight:900; color:${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}; font-family:monospace;">
                          ${String(Math.floor(times.writingSecsLeft / 3600)).padStart(2, '0')}
                        </div>
                        <span style="font-size:8.5px; font-weight:600; color:#64748B; margin-top:3px;">HOURS</span>
                      </div>
                      <span style="font-size:24px; font-weight:bold; color:${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'};">:</span>
                      <div style="display:flex; flex-direction:column; align-items:center;">
                        <div id="hud-tile-minutes" style="background:#1E293B; border:1.5px solid ${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}80; border-radius:10px; padding:6px 10px; min-width:54px; font-size:26px; font-weight:900; color:${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}; font-family:monospace;">
                          ${String(Math.floor((times.writingSecsLeft % 3600) / 60)).padStart(2, '0')}
                        </div>
                        <span style="font-size:8.5px; font-weight:600; color:#64748B; margin-top:3px;">MINUTES</span>
                      </div>
                      <span style="font-size:24px; font-weight:bold; color:${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'};">:</span>
                      <div style="display:flex; flex-direction:column; align-items:center;">
                        <div id="hud-tile-seconds" style="background:#1E293B; border:1.5px solid ${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}80; border-radius:10px; padding:6px 10px; min-width:54px; font-size:26px; font-weight:900; color:${times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E'}; font-family:monospace;">
                          ${String(times.writingSecsLeft % 60).padStart(2, '0')}
                        </div>
                        <span style="font-size:8.5px; font-weight:600; color:#64748B; margin-top:3px;">SECONDS</span>
                      </div>
                    </div>
                    <div style="font-size:10px; color:#94A3B8; margin-top:6px;">
                      කැමරාව ඉදිරියේ ඔබගේ ලිවීම් මේසය සහ පිළිතුරු පත්‍රය තබා ගන්න
                    </div>
                  </div>
                `}
              ` : times.isTimeUp ? `
                <!-- Urgent Time Up Banner -->
                <div style="background:rgba(239,68,68,0.95); border:1.5px solid rgba(255,255,255,0.4); border-radius:14px; padding:10px 14px; display:flex; align-items:center; justify-content:space-between; box-shadow:0 0 16px rgba(239,68,68,0.5);">
                  <div style="display:flex; align-items:center; gap:10px;">
                    <span class="material-symbols-rounded filled" style="font-size:24px; color:#FFFFFF;">alarm</span>
                    <div>
                      <div style="font-size:12px; font-weight:700; color:#FFFFFF;">වේලාව අවසන් විය! (TIME IS UP)</div>
                      <div style="font-size:10px; color:#FEE2E2;">ලිවීම නවතා පිළිතුරු පත්‍ර Scan කර දැන්ම Submit කරන්න.</div>
                    </div>
                  </div>
                  <button id="btn-phase-scan" style="background:#FFFFFF; color:#EF4444; border:none; padding:8px 12px; border-radius:8px; font-size:11px; font-weight:700; cursor:pointer;">
                    Scan & Submit
                  </button>
                </div>
              ` : times.isEnded ? `
                <div style="background:rgba(239,68,68,0.95); border-radius:14px; padding:12px; color:#FFFFFF; font-size:12px; font-weight:600; text-align:center;">
                  මෙම විභාග සැසිය ගුරුභවතුන් විසින් අවසන් කරන ලදී (Session ended by Admin).
                </div>
              ` : ''}
            </div>

            <!-- Bottom Exam Control Bar (_buildBottomExamControlBar) -->
            <div style="position:absolute; bottom:20px; left:16px; right:16px; z-index:20; max-width:680px; margin:0 auto;">
              <div style="background:rgba(30,41,59,0.92); border:1px solid ${times.isTimeUp ? '#EF4444' : '#334155'}; border-radius:16px; padding:12px 14px; display:flex; align-items:center; justify-content:space-between; box-shadow:0 8px 24px rgba(0,0,0,0.5);">
                <div style="display:flex; align-items:center; gap:10px;">
                  <div style="width:36px; height:36px; border-radius:50%; background:${times.isTimeUp ? 'rgba(239,68,68,0.2)' : 'rgba(34,197,94,0.2)'}; display:flex; align-items:center; justify-content:center; color:${times.isTimeUp ? '#EF4444' : '#4ADE80'}; font-size:18px;">
                    <span class="material-symbols-rounded filled" style="font-size:20px;">${times.isTimeUp ? 'alarm' : 'shield'}</span>
                  </div>
                  <div>
                    <div style="font-size:11px; font-weight:600; color:${times.isTimeUp ? '#FCA5A5' : '#FFFFFF'};">
                      ${times.isTimeUp ? 'වේලාව අවසන් කර ඇත' : 'කැමරා අධීක්ෂණය සක්‍රීයයි'}
                    </div>
                    <div style="font-size:10px; color:#94A3B8;">
                      ${times.isTimeUp ? 'පිළිතුරු පත්‍ර Submit කරන්න' : 'ගුරුභවතුන් සජීවීව පරීක්ෂා කරයි'}
                    </div>
                  </div>
                </div>
                <button id="btn-bottom-submit" style="background:${times.isEnded ? '#334155' : (times.isTimeUp ? '#22C55E' : '#6366F1')}; color:#FFFFFF; border:none; padding:10px 16px; border-radius:10px; font-size:12px; font-weight:600; cursor:pointer; display:flex; align-items:center; gap:6px;">
                  <span class="material-symbols-rounded filled" style="font-size:16px;">${times.isTimeUp ? 'description' : 'upload'}</span>
                  <span>${times.isTimeUp ? 'Scan & Submit' : 'Submit Paper'}</span>
                </button>
              </div>
            </div>
          `}
        </div>
      `;

      // Re-attach video stream
      if (cameraStream) {
        const videoEls = roomContainer.querySelectorAll('.proctor-video-feed');
        videoEls.forEach(v => {
          v.srcObject = cameraStream;
          v.play().catch(() => {});
        });
      }

      // Event Listeners
      roomContainer.querySelector('#btn-appbar-back')?.addEventListener('click', () => {
        showExitWarningDialog();
      });

      roomContainer.querySelector('#btn-appbar-flip')?.addEventListener('click', () => {
        facingMode = facingMode === 'user' ? 'environment' : 'user';
        initCamera();
      });

      roomContainer.querySelector('#btn-flip-self-check')?.addEventListener('click', () => {
        facingMode = facingMode === 'user' ? 'environment' : 'user';
        initCamera();
      });

      roomContainer.querySelector('#btn-retry-camera')?.addEventListener('click', async () => {
        const retryBtn = roomContainer.querySelector('#btn-retry-camera');
        if (retryBtn) { retryBtn.textContent = 'සම්බන්ධ වෙමින්...'; retryBtn.disabled = true; }
        await initCamera();
      });

      roomContainer.querySelector('#btn-toggle-hud')?.addEventListener('click', () => {
        isBigTimerMinimized = !isBigTimerMinimized;
        renderRoom();
      });

      roomContainer.querySelector('#btn-phase-scan')?.addEventListener('click', () => {
        openDocumentScanner();
      });

      roomContainer.querySelector('#btn-bottom-submit')?.addEventListener('click', () => {
        openDocumentScanner();
      });


    };

    // Exit Warning Dialog matching _showExitWarningDialog()
    const showExitWarningDialog = () => {
      const exitModal = document.createElement('div');
      exitModal.className = 'app-modal';
      exitModal.style.cssText = 'display:flex; justify-content:center; align-items:center; background:rgba(15,23,42,0.85); z-index:999999;';
      exitModal.innerHTML = `
        <div style="background:#1E293B; border-radius:16px; border:1px solid #334155; padding:22px; max-width:400px; width:90%; color:#F8FAFC; box-shadow:0 20px 40px rgba(0,0,0,0.6); font-family:'Poppins',sans-serif;">
          <h3 style="font-size:15px; font-weight:700; color:#FFFFFF; margin:0 0 10px 0; display:flex; align-items:center;">
            <span class="material-symbols-rounded filled" style="color:#EF4444; font-size:20px; vertical-align:middle; margin-right:6px;">warning</span>
            <span>විභාග ශාලාවෙන් පිටවීම?</span>
          </h3>
          <p style="font-size:12px; color:#CBD5E1; line-height:1.5; margin:0 0 20px 0;">
            විභාග සැසිය අතරතුර පිටවීම ගුරුභවතුන්ට සටහන් වේ. ඔබට පිටවීමට අවශ්‍යද?
          </p>
          <div style="display:flex; justify-content:flex-end; gap:10px;">
            <button id="btn-exit-cancel" style="background:transparent; border:none; color:#94A3B8; padding:8px 14px; font-size:12.5px; font-weight:600; cursor:pointer;">
              නැත (Stay)
            </button>
            <button id="btn-exit-confirm" style="background:#EF4444; border:none; color:#FFFFFF; padding:8px 16px; border-radius:8px; font-size:12.5px; font-weight:700; cursor:pointer;">
              පිටවෙන්න (Exit)
            </button>
          </div>
        </div>
      `;
      document.body.appendChild(exitModal);

      exitModal.querySelector('#btn-exit-cancel')?.addEventListener('click', () => exitModal.remove());
      exitModal.querySelector('#btn-exit-confirm')?.addEventListener('click', () => {
        exitModal.remove();
        cleanupAndExit();
      });
    };

    // Cleanup and Exit
    const cleanupAndExit = () => {
      if (heartbeatInterval) clearInterval(heartbeatInterval);
      if (syncInterval) clearInterval(syncInterval);
      if (timerInterval) clearInterval(timerInterval);
      if (cameraStream) {
        cameraStream.getTracks().forEach(t => t.stop());
      }
      sendHeartbeat(false);
      roomContainer.remove();
      this.renderApp();
    };

    // In-App Document Scanner (1:1 with in_app_document_scanner_screen.dart)
    const openDocumentScanner = () => {
      const scannerModal = document.createElement('div');
      scannerModal.id = 'scanner-modal-root';
      scannerModal.style.cssText = `
        position: fixed; inset: 0; background: #000000; z-index: 1000000;
        display: flex; flex-direction: column; color: #FFFFFF; font-family: 'Poppins', sans-serif;
      `;

      let scannedPages = [];
      let scannerStream = null;
      let driveLink = '';
      let isCapturing = false;

      // Start rear or user camera for document scanner
      const startScannerCamera = async () => {
        try {
          scannerStream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: 'environment', width: { ideal: 1920 }, height: { ideal: 1080 } },
            audio: false
          });
        } catch (_) {
          try {
            scannerStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
          } catch (e) {
            console.warn('Scanner camera error:', e);
          }
        }
        const sv = scannerModal.querySelector('#scanner-camera-view');
        if (sv && scannerStream) {
          sv.srcObject = scannerStream;
          sv.play().catch(() => {});
        }
      };

      const renderScanner = () => {
        scannerModal.innerHTML = `
          <!-- Top Control Bar (_buildTopControlBar) -->
          <div style="background:rgba(15,23,42,0.9); border-bottom:1px solid #334155; padding:12px 16px; display:flex; justify-content:space-between; align-items:center; z-index:20;">
            <div style="display:flex; align-items:center; gap:10px;">
              <button id="btn-close-scanner" style="background:transparent; border:none; color:#FFFFFF; font-size:20px; cursor:pointer; display:flex; align-items:center;">
                <span class="material-symbols-rounded">close</span>
              </button>
              <div>
                <div style="font-size:13.5px; font-weight:700; color:#FFFFFF;">In-App Document Scanner</div>
                <div style="font-size:10.5px; color:#94A3B8;">පිළිතුරු පත්‍ර ස්කෑන් කරන්න</div>
              </div>
            </div>
            <div style="display:flex; align-items:center; gap:8px;">
              <span id="scanner-pages-badge" style="background:#1E293B; border:1px solid #22C55E; color:#4ADE80; font-size:11px; font-weight:700; padding:4px 10px; border-radius:12px;">
                ${scannedPages.length} Pages
              </span>
            </div>
          </div>

          <!-- Camera Viewfinder & A4 Frame (_buildA4DocumentScannerFrame) -->
          <div style="flex:1; position:relative; overflow:hidden; background:#000000; display:flex; align-items:center; justify-content:center;">
            <video id="scanner-camera-view" autoplay playsinline muted style="width:100%; height:100%; object-fit:cover;"></video>
            <canvas id="scanner-capture-canvas" style="display:none;"></canvas>

            <!-- A4 Document Scanner Viewport Guide Frame -->
            <div style="position:absolute; width:82%; max-width:380px; height:68%; border:1.5px solid rgba(34,197,94,0.5); border-radius:12px; pointer-events:none;">
              <!-- Top Left Corner Bracket -->
              <div style="position:absolute; top:0; left:0; width:28px; height:28px; border-top:4px solid #22C55E; border-left:4px solid #22C55E;"></div>
              <!-- Top Right Corner Bracket -->
              <div style="position:absolute; top:0; right:0; width:28px; height:28px; border-top:4px solid #22C55E; border-right:4px solid #22C55E;"></div>
              <!-- Bottom Left Corner Bracket -->
              <div style="position:absolute; bottom:0; left:0; width:28px; height:28px; border-bottom:4px solid #22C55E; border-left:4px solid #22C55E;"></div>
              <!-- Bottom Right Corner Bracket -->
              <div style="position:absolute; bottom:0; right:0; width:28px; height:28px; border-bottom:4px solid #22C55E; border-right:4px solid #22C55E;"></div>

              <!-- Center Guidance Badge -->
              <div style="position:absolute; top:50%; left:50%; transform:translate(-50%, -50%); background:rgba(0,0,0,0.65); border:1px solid rgba(255,255,255,0.2); border-radius:20px; padding:6px 14px; display:flex; align-items:center; gap:6px; white-space:nowrap;">
                <span class="material-symbols-rounded filled" style="color:#4ADE80; font-size:16px;">description</span>
                <span style="font-size:10px; color:#FFFFFF; font-weight:500;">A4 කඩදාසිය රාමුවට ගැලපෙන සේ තබන්න</span>
              </div>
            </div>

            <!-- Shutter Flash Overlay -->
            <div id="scanner-flash-overlay" style="position:absolute; inset:0; background:#FFFFFF; opacity:0; pointer-events:none; transition:opacity 0.15s ease;"></div>
          </div>

          <!-- Bottom Thumbnail Tray & Controls (_buildBottomScannerControls) -->
          <div style="background:#0F172A; border-top:1px solid #334155; padding:14px 16px; display:flex; flex-direction:column; gap:12px; z-index:20;">
            <!-- Scanned Pages Thumbnail Tray -->
            <div id="scanner-thumbnail-tray" style="display:flex; gap:10px; overflow-x:auto; min-height:64px; align-items:center; padding:4px 0;">
              ${scannedPages.length === 0 ? `
                <div style="font-size:11px; color:#64748B; font-style:italic;">පිටු කිසිවක් ස්කෑන් කර නොමැත. කැමරා බොත්තම ඔබා ඡායාරූප ලබාගන්න.</div>
              ` : scannedPages.map((p, idx) => `
                <div style="position:relative; width:52px; height:68px; border-radius:8px; border:2px solid #22C55E; overflow:hidden; flex-shrink:0; cursor:pointer;" data-preview-idx="${idx}">
                  <img src="${p.dataUrl}" style="width:100%; height:100%; object-fit:cover;" />
                  <div style="position:absolute; bottom:0; left:0; right:0; background:rgba(15,23,42,0.85); font-size:9px; font-weight:800; text-align:center; color:#FFFFFF;">P.${idx + 1}</div>
                  <button class="btn-delete-page" data-del-idx="${idx}" style="position:absolute; top:2px; right:2px; width:16px; height:16px; border-radius:50%; background:#EF4444; border:none; color:#FFFFFF; font-size:9px; font-weight:bold; cursor:pointer; display:flex; align-items:center; justify-content:center;">
                    <span class="material-symbols-rounded" style="font-size:12px;">close</span>
                  </button>
                </div>
              `).join('')}
            </div>

            <!-- Optional Google Drive Link Input -->
            <div style="display:flex; align-items:center; background:#1E293B; border:1px solid #334155; border-radius:10px; padding:0 12px;">
              <span class="material-symbols-rounded filled" style="font-size:18px; color:#94A3B8; margin-right:8px;">folder</span>
              <input id="scanner-drive-input" type="text" placeholder="Google Drive Link (විකල්ප - Optional)" value="${driveLink}" style="flex:1; background:transparent; border:none; color:#FFFFFF; font-size:11.5px; padding:10px 0; outline:none;" />
            </div>

            <!-- Action Buttons: Shutter & Submit -->
            <div style="display:flex; gap:10px; align-items:center;">
              <button id="btn-shutter-snap" style="flex:1; background:#0F766E; border:none; color:#FFFFFF; padding:12px; border-radius:12px; font-size:12.5px; font-weight:700; cursor:pointer; display:flex; align-items:center; justify-content:center; gap:6px;">
                <span class="material-symbols-rounded filled" style="font-size:18px;">photo_camera</span> <span>Snap Page (${scannedPages.length + 1})</span>
              </button>
              <button id="btn-scanner-submit-all" style="flex:1.4; background:#22C55E; border:none; color:#FFFFFF; padding:12px; border-radius:12px; font-size:12.5px; font-weight:800; cursor:pointer; display:flex; align-items:center; justify-content:center; gap:6px;">
                <span class="material-symbols-rounded filled" style="font-size:18px;">send</span> <span>Submit All Answers</span>
              </button>
            </div>
          </div>
        `;

        // Re-attach video stream
        const sv = scannerModal.querySelector('#scanner-camera-view');
        if (sv && scannerStream) {
          sv.srcObject = scannerStream;
          sv.play().catch(() => {});
        }

        // Attach listeners
        scannerModal.querySelector('#btn-close-scanner')?.addEventListener('click', () => {
          if (scannerStream) scannerStream.getTracks().forEach(t => t.stop());
          scannerModal.remove();
        });

        // Snap Page action
        scannerModal.querySelector('#btn-shutter-snap')?.addEventListener('click', () => {
          if (isCapturing) return;
          isCapturing = true;

          // Flash animation
          const flash = scannerModal.querySelector('#scanner-flash-overlay');
          if (flash) {
            flash.style.opacity = '0.8';
            setTimeout(() => { flash.style.opacity = '0'; }, 140);
          }

          // Capture frame to canvas
          const video = scannerModal.querySelector('#scanner-camera-view');
          const canvas = scannerModal.querySelector('#scanner-capture-canvas');
          if (video && canvas) {
            canvas.width = video.videoWidth || 1280;
            canvas.height = video.videoHeight || 720;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
            const dataUrl = canvas.toDataURL('image/jpeg', 0.85);

            scannedPages.push({
              page: scannedPages.length + 1,
              dataUrl,
              timestamp: new Date().toISOString()
            });

            isCapturing = false;
            renderScanner();
          } else {
            isCapturing = false;
          }
        });

        // Delete Page
        scannerModal.querySelectorAll('.btn-delete-page').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = parseInt(btn.dataset.delIdx);
            scannedPages.splice(idx, 1);
            renderScanner();
          });
        });

        // Preview Page Dialog
        scannerModal.querySelectorAll('[data-preview-idx]').forEach(el => {
          el.addEventListener('click', () => {
            const idx = parseInt(el.dataset.previewIdx);
            const previewModal = document.createElement('div');
            previewModal.className = 'app-modal';
            previewModal.style.cssText = 'display:flex; justify-content:center; align-items:center; background:rgba(0,0,0,0.9); z-index:10000000;';
            previewModal.innerHTML = `
              <div style="background:#1E293B; border-radius:16px; border:1px solid #334155; padding:16px; max-width:500px; width:90%; color:#FFFFFF; font-family:'Poppins',sans-serif;">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
                  <span style="background:#6366F1; padding:3px 8px; border-radius:6px; font-size:11px; font-weight:700;">Page ${idx + 1} of ${scannedPages.length}</span>
                  <button id="btn-close-preview" style="background:transparent; border:none; color:#FFFFFF; font-size:18px; cursor:pointer; display:flex; align-items:center;">
                    <span class="material-symbols-rounded">close</span>
                  </button>
                </div>
                <div style="max-height:60vh; overflow:hidden; border-radius:8px; background:#000000;">
                  <img src="${scannedPages[idx].dataUrl}" style="width:100%; height:100%; object-fit:contain;" />
                </div>
              </div>
            `;
            document.body.appendChild(previewModal);
            previewModal.querySelector('#btn-close-preview')?.addEventListener('click', () => previewModal.remove());
          });
        });

        // Drive link change listener
        const driveInp = scannerModal.querySelector('#scanner-drive-input');
        if (driveInp) {
          driveInp.addEventListener('input', (e) => {
            driveLink = e.target.value.trim();
          });
        }

        // Final Submit All Answers matching _submitAllAnswers()
        scannerModal.querySelector('#btn-scanner-submit-all')?.addEventListener('click', async () => {
          if (scannedPages.length === 0 && !driveLink) {
            alert('කරුණාකර අවම වශයෙන් එක් පිළිතුරු පත්‍රයක්වත් Scan කරන්න හෝ Drive Link එකක් ඇතුලත් කරන්න.');
            return;
          }

          // Confirmation Dialog matching Flutter
          const confirmModal = document.createElement('div');
          confirmModal.className = 'app-modal';
          confirmModal.style.cssText = 'display:flex; justify-content:center; align-items:center; background:rgba(15,23,42,0.85); z-index:10000001;';
          confirmModal.innerHTML = `
            <div style="background:#1E293B; border-radius:16px; border:1px solid #334155; padding:22px; max-width:440px; width:90%; color:#F8FAFC; box-shadow:0 20px 40px rgba(0,0,0,0.6); font-family:'Poppins',sans-serif;">
              <div style="display:flex; align-items:center; gap:10px; margin-bottom:12px;">
                <span class="material-symbols-rounded filled" style="color:#22C55E; font-size:28px;">cloud_upload</span>
                <h3 style="font-size:16px; font-weight:700; color:#FFFFFF; margin:0;">Submit Answer Sheets?</h3>
              </div>
              <p style="font-size:13px; color:#E2E8F0; line-height:1.5; margin:0 0 14px 0;">
                ඔබ විසින් Scan කරන ලද පිටු ${scannedPages.length} ක් ගුරුභවතුන් වෙත භාරදීමට සූදානම්ද?
              </p>
              <div style="background:#0F172A; border:1px solid #334155; border-radius:8px; padding:10px; display:flex; align-items:center; gap:8px; margin-bottom:18px;">
                <span class="material-symbols-rounded filled" style="color:#22C55E; font-size:16px;">check_circle</span>
                <span style="font-size:11px; font-weight:600; color:#4ADE80;">${scannedPages.length} Pages Verified & Ready</span>
              </div>
              <div style="display:flex; justify-content:flex-end; gap:10px;">
                <button id="btn-confirm-cancel" style="background:transparent; border:none; color:#94A3B8; padding:8px 14px; font-size:12.5px; font-weight:600; cursor:pointer;">
                  Cancel
                </button>
                <button id="btn-confirm-yes" style="background:#22C55E; border:none; color:#FFFFFF; padding:8px 16px; border-radius:8px; font-size:12.5px; font-weight:700; cursor:pointer;">
                  Yes, Submit Now
                </button>
              </div>
            </div>
          `;
          document.body.appendChild(confirmModal);

          confirmModal.querySelector('#btn-confirm-cancel')?.addEventListener('click', () => confirmModal.remove());
          confirmModal.querySelector('#btn-confirm-yes')?.addEventListener('click', async () => {
            confirmModal.remove();

            // Show Submitting Progress Overlay
            const overlay = document.createElement('div');
            overlay.style.cssText = 'position:fixed; inset:0; background:rgba(0,0,0,0.85); display:flex; align-items:center; justify-content:center; z-index:10000002; font-family:"Poppins",sans-serif;';
            overlay.innerHTML = `
              <div style="background:#1E293B; border-radius:16px; border:1px solid rgba(34,197,94,0.5); padding:28px; text-align:center; color:#FFFFFF;">
                <div class="apk-spinner" style="margin:0 auto 16px auto; width:36px; height:36px; border-width:3px; border-color:#22C55E; border-top-color:transparent;"></div>
                <div style="font-size:14px; font-weight:700; margin-bottom:6px;">පිළිතුරු පත්‍ර Upload වෙමින් පවතී...</div>
                <div style="font-size:12px; color:#38BDF8;">Saving submission records to Cloud...</div>
              </div>
            `;
            document.body.appendChild(overlay);

            try {
              const photoUrls = scannedPages.map(p => p.dataUrl);
              if (driveLink) photoUrls.push(driveLink);

              // Update Firestore paper_registrations record
              await dbService.updateCameraHeartbeat({
                paperId,
                studentId: studentId, studentName: studentName, studentPhone: studentPhone,
                slotId: slotId || 'slot1',
                isCameraActive: false,
                status: 'submitted',
                submissionPhotos: photoUrls
              });

              overlay.remove();
              if (scannerStream) scannerStream.getTracks().forEach(t => t.stop());
              scannerModal.remove();

              // Show success message and exit
              alert(`පිළිතුරු පත්‍ර (${photoUrls.length} Pages) සාර්ථකව භාරදෙන ලදී!`);
              cleanupAndExit();
            } catch (err) {
              console.error('Submission save error:', err);
              overlay.remove();
              alert('Submission error: ' + err.message);
            }
          });
        });
      };

      document.body.appendChild(scannerModal);
      renderScanner();
      startScannerCamera();
    };

    // Realtime Proctor Alerts Listener
    const listenToProctorAlerts = () => {
      try {
        if (typeof dbService.streamStudentAlerts === 'function') {
          dbService.streamStudentAlerts(paperId, studentId, (alerts) => {
            alerts.forEach(alert => {
              if (!alert.isRead && !shownAlertIds.has(alert.id)) {
                shownAlertIds.add(alert.id);
                showProctorAlertDialog(alert);
              }
            });
          });
        }
      } catch (e) {
        console.warn('Alerts listener error:', e);
      }
    };

    // Show Proctor Alert Modal matching _showProctorAlertDialog()
    const showProctorAlertDialog = (alert) => {
      const alertModal = document.createElement('div');
      alertModal.className = 'app-modal';
      alertModal.style.cssText = 'display:flex; justify-content:center; align-items:center; background:rgba(15,23,42,0.85); z-index:999999;';
      alertModal.innerHTML = `
        <div style="background:#1E293B; border-radius:16px; border:1px solid #334155; padding:22px; max-width:440px; width:90%; color:#F8FAFC; box-shadow:0 20px 40px rgba(0,0,0,0.6); font-family:'Poppins',sans-serif;">
          <div style="display:flex; align-items:center; gap:10px; margin-bottom:12px;">
            <div style="background:rgba(245,158,11,0.2); padding:8px; border-radius:8px; display:flex; align-items:center; justify-content:center; color:#F59E0B;">
              <span class="material-symbols-rounded filled" style="font-size:22px;">warning</span>
            </div>
            <div>
              <div style="font-size:15px; font-weight:700; color:#FFFFFF;">විභාග පරීක්ෂක පණිවිඩය</div>
              <div style="font-size:11px; color:#94A3B8;">From: ${alert.senderName || 'Faculty Proctor'}</div>
            </div>
          </div>
          <div style="background:#0F172A; border-radius:10px; border:1px solid #F59E0B; padding:12px; font-size:13px; color:#E2E8F0; line-height:1.5; margin-bottom:18px;">
            ${alert.message}
          </div>
          <button id="btn-ack-alert" style="width:100%; background:#6366F1; color:#FFFFFF; border:none; padding:12px; border-radius:10px; font-size:13px; font-weight:700; cursor:pointer;">
            තේරුම් ගතිමි (Acknowledge)
          </button>
        </div>
      `;
      document.body.appendChild(alertModal);
      alertModal.querySelector('#btn-ack-alert')?.addEventListener('click', () => {
        alertModal.remove();
        if (typeof dbService.markAlertRead === 'function') {
          dbService.markAlertRead(alert.id);
        }
      });
    };

    // Initialize View
    document.body.appendChild(roomContainer);
    renderRoom();
    await initCamera();
    listenToProctorAlerts();

    // Periodic Heartbeat every 4 seconds (matching _heartbeatTimer)
    heartbeatInterval = setInterval(() => {
      sendHeartbeat(cameraActive);
    }, 4000);

    // Periodic Session Sync every 3 seconds (matching _sessionSyncTimer)
    syncInterval = setInterval(async () => {
      try {
        const s = await dbService.getPaperSession(paperId);
        if (s) {
          const changed = session.currentPhase !== s.currentPhase || session.status !== s.status || session.isTimeUp !== s.isTimeUp;
          session = s;
          if (changed) renderRoom();
        }
      } catch (e) {
        console.warn('Session sync error:', e);
      }
    }, 3000);

    // 1-second Countdown Ticker (matching _examCountdownTimer)
    timerInterval = setInterval(() => {
      now = new Date();
      // Only re-render header & HUD countdowns to preserve smooth 60fps video
      const times = calculateTimes();
      let timerText = 'Waiting';
      let timerColor = '#818CF8';
      let timerIcon = 'hourglass_top';

      if (times.isEnded) {
        timerText = 'Ended';
        timerColor = '#EF4444';
        timerIcon = 'close';
      } else if (times.isTimeUp) {
        timerText = 'Time Up';
        timerColor = '#EF4444';
        timerIcon = 'alarm';
      } else if (times.isWaiting) {
        timerText = 'Waiting';
        timerColor = '#818CF8';
        timerIcon = 'hourglass_top';
      } else if (times.isPackageOpening) {
        const m = String(Math.floor(times.pkgSecsLeft / 60)).padStart(2, '0');
        const s = String(times.pkgSecsLeft % 60).padStart(2, '0');
        timerText = times.pkgSecsLeft <= 0 ? '00:00' : `Open: ${m}:${s}`;
        timerColor = '#F59E0B';
        timerIcon = 'inventory_2';
      } else if (times.isWriting) {
        if (!times.isOvertime) {
          const h = String(Math.floor(times.writingSecsLeft / 3600)).padStart(2, '0');
          const m = String(Math.floor((times.writingSecsLeft % 3600) / 60)).padStart(2, '0');
          const s = String(times.writingSecsLeft % 60).padStart(2, '0');
          timerText = Math.floor(times.writingSecsLeft / 3600) > 0 ? `${h}:${m}:${s}` : `${m}:${s}`;
          timerColor = times.writingSecsLeft < 900 ? '#EF4444' : '#22C55E';
          timerIcon = 'edit_note';
        } else {
          const m = String(Math.floor(times.overtimeSecs / 60)).padStart(2, '0');
          const s = String(times.overtimeSecs % 60).padStart(2, '0');
          timerText = `Extra: +${m}:${s}`;
          timerColor = '#F59E0B';
          timerIcon = 'timer';
        }
      }

      // Update timer pill in AppBar
      const pill = roomContainer.querySelector('#live-timer-pill');
      if (pill) {
        const iconEl = pill.querySelector('.timer-icon');
        const textEl = pill.querySelector('.timer-text');
        if (iconEl && iconEl.textContent !== timerIcon) iconEl.textContent = timerIcon;
        if (textEl && textEl.textContent !== timerText) textEl.textContent = timerText;
        pill.style.background = `${timerColor}38`;
        pill.style.borderColor = timerColor;
        if (iconEl) iconEl.style.color = timerColor;
        if (textEl) textEl.style.color = timerColor;
      }

      // Update package opening 10-minute banner pill
      const pkgBannerPill = roomContainer.querySelector('#pkg-timer-banner-pill');
      if (pkgBannerPill && times.isPackageOpening) {
        const m = String(Math.floor(times.pkgSecsLeft / 60)).padStart(2, '0');
        const s = String(times.pkgSecsLeft % 60).padStart(2, '0');
        const timeStr = `${m}:${s}`;
        if (pkgBannerPill.textContent.trim() !== timeStr) {
          pkgBannerPill.textContent = timeStr;
          pkgBannerPill.style.background = times.pkgSecsLeft <= 0 ? '#EF4444' : '#F59E0B';
          pkgBannerPill.style.color = times.pkgSecsLeft <= 0 ? '#FFFFFF' : '#000000';
        }
      }

      // Update writing digital HUD clock
      if (times.isWriting) {
        let h, m, s;
        if (!times.isOvertime) {
          h = String(Math.floor(times.writingSecsLeft / 3600)).padStart(2, '0');
          m = String(Math.floor((times.writingSecsLeft % 3600) / 60)).padStart(2, '0');
          s = String(times.writingSecsLeft % 60).padStart(2, '0');
        } else {
          h = '00';
          m = String(Math.floor(times.overtimeSecs / 60)).padStart(2, '0');
          s = String(times.overtimeSecs % 60).padStart(2, '0');
        }
        const tileH = roomContainer.querySelector('#hud-tile-hours');
        const tileM = roomContainer.querySelector('#hud-tile-minutes');
        const tileS = roomContainer.querySelector('#hud-tile-seconds');
        const minTime = roomContainer.querySelector('#hud-minimized-time');
        if (tileH && tileH.textContent.trim() !== h) tileH.textContent = h;
        if (tileM && tileM.textContent.trim() !== m) tileM.textContent = m;
        if (tileS && tileS.textContent.trim() !== s) tileS.textContent = s;
        if (minTime) minTime.textContent = times.isOvertime ? `+${m}:${s}` : `${h}:${m}:${s}`;
      }
    }, 1000);
  }
}

window.addEventListener('DOMContentLoaded', () => {
  const app = new AppController();
  window.app = app;
  app.init();
});
