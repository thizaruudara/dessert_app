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
    this.currentUser = authService.currentUser || null;
    this.countdownTimer = null;
    this.papersInterval = null;
    this.isInsideLiveExam = false;
    this.antiCheatViolations = 0;
    this.papersTab = 0; // 0: Live Sessions, 1: Upcoming Papers & Hints
    this.showAllBatches = false;
  }

  init() {
    // 0. Theme Initialization
    const savedTheme = localStorage.getItem('edupeak_theme') || 'light';
    document.documentElement.setAttribute('data-theme', savedTheme);

    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('admin') === 'true') {
      this.currentMode = 'admin';
    }

    // 1. Initialize PWA Gatekeeper for iOS Add to Home Screen enforcement
    const gatekeeper = new PwaGatekeeper({
      onUnlocked: () => {
        console.log('[App] PWA Standalone Mode active.');
        if (!this.currentUser) {
          this.renderAuthScreen();
        } else if (this.currentMode === 'admin' || this.currentUser?.role === 'admin') {
          this.renderAdminApp();
        } else {
          this.renderApp();
        }
      }
    });

    gatekeeper.init();

    // 2. Global Anti-Cheat Listener
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden' && this.isInsideLiveExam) {
        this.handleExamTabSwitch();
      }
    });
  }

  // ── 0. Dedicated Login & Register Screen (1:1 login_screen.dart replica) ──
  renderAuthScreen(initialTab = 0) {
    const root = document.getElementById('app-root');
    if (!root) return;

    this.authTab = initialTab; // 0 = Login, 1 = Register

    root.innerHTML = `
      <div class="auth-screen-container">
        <!-- Status Bar -->
        <div class="ios-status-bar" style="background:transparent; color:#FFFFFF;">
          <span class="status-time" id="status-clock">8:15</span>
          <div class="status-icons">
            <span>●●●</span>
            <span>📶</span>
            <span>🔋</span>
          </div>
        </div>

        <div class="auth-header">
          <div class="auth-brand-logo">🍰</div>
          <div class="auth-title">EduPeak Learning Platform</div>
          <div class="auth-subtitle">A/L Physics Examination & Proctoring Suite</div>
        </div>

        <!-- Auth Tabs (Login vs Register) -->
        <div class="auth-tabs-bar">
          <button class="auth-tab-btn ${this.authTab === 0 ? 'active' : ''}" id="tab-auth-login">
            🔑 Login with Password
          </button>
          <button class="auth-tab-btn ${this.authTab === 1 ? 'active' : ''}" id="tab-auth-register">
            📝 Register
          </button>
        </div>

        <!-- Form Card -->
        <div class="auth-form-card" id="auth-form-card">
          ${this.authTab === 0 ? `
            <!-- Login Form -->
            <form id="form-login" style="display:flex; flex-direction:column; gap:14px;">
              <div class="auth-field-group">
                <label class="auth-field-label">Phone Number (දුරකථන අංකය)</label>
                <div class="auth-input-wrapper">
                  <span class="auth-phone-prefix">+94</span>
                  <input type="tel" class="auth-input has-prefix" id="input-login-phone" placeholder="77 055 7769" value="0770557769" required />
                </div>
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label">Password (මුරපදය)</label>
                <div class="auth-input-wrapper">
                  <input type="password" class="auth-input" id="input-login-password" placeholder="••••••••" value="demo1234" required />
                  <button type="button" class="auth-pw-toggle" id="btn-toggle-login-pw">👁️</button>
                </div>
              </div>

              <div id="auth-error-msg" style="display:none; background:#FEE2E2; border:1px solid #FECACA; color:#DC2626; border-radius:10px; padding:10px 12px; font-size:12px; font-weight:600;"></div>

              <button type="submit" class="auth-btn-submit" id="btn-submit-login">
                Sign In (ඇතුල් වන්න) ➔
              </button>
            </form>
          ` : `
            <!-- Register Form -->
            <form id="form-register" style="display:flex; flex-direction:column; gap:14px;">
              <div class="auth-field-group">
                <label class="auth-field-label">Full Name (සම්පූර්ණ නම)</label>
                <input type="text" class="auth-input" id="input-reg-name" placeholder="Ex: ThiZaru Perera" required />
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label">Phone Number (දුරකථන අංකය)</label>
                <div class="auth-input-wrapper">
                  <span class="auth-phone-prefix">+94</span>
                  <input type="tel" class="auth-input has-prefix" id="input-reg-phone" placeholder="77 123 4567" required />
                </div>
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label">Target A/L Examination Batch</label>
                <select class="auth-input" id="input-reg-batch" style="background:#0F172A; color:#FFFFFF;">
                  <option value="2027 A/L" selected>2027 A/L</option>
                  <option value="2028 A/L">2028 A/L</option>
                  <option value="2029 A/L">2029 A/L</option>
                  <option value="2026 A/L">2026 A/L</option>
                </select>
              </div>

              <div class="auth-field-group">
                <label class="auth-field-label">Password (මුරපදය)</label>
                <div class="auth-input-wrapper">
                  <input type="password" class="auth-input" id="input-reg-password" placeholder="Create password" required />
                  <button type="button" class="auth-pw-toggle" id="btn-toggle-reg-pw">👁️</button>
                </div>
              </div>

              <div id="auth-error-msg" style="display:none; background:#FEE2E2; border:1px solid #FECACA; color:#DC2626; border-radius:10px; padding:10px 12px; font-size:12px; font-weight:600;"></div>

              <button type="submit" class="auth-btn-submit" id="btn-submit-reg">
                Create Account & Claim +50 Bonus XP ➔
              </button>
            </form>
          `}
        </div>

        <!-- Quick 1-Tap Demo Switcher -->
        <div class="auth-quick-demo-section">
          <div style="font-size:11.5px; font-weight:700; color:#64748B; text-align:center;">
            ⚡ Quick 1-Tap Login for Testing & Evaluation:
          </div>
          <button class="auth-quick-btn" id="btn-quick-student">
            <span>👨‍🎓 Student Demo (ThiZaru • 2027 A/L)</span>
            <span style="color:#818CF8; font-weight:800;">Log In ➔</span>
          </button>
          <button class="auth-quick-btn" id="btn-quick-admin">
            <span>👑 Teacher / Admin Demo (Prof. Senanayake)</span>
            <span style="color:#F59E0B; font-weight:800;">Log In ➔</span>
          </button>
        </div>
      </div>
    `;

    this.updateClock();

    // Tab Listeners
    document.getElementById('tab-auth-login')?.addEventListener('click', () => this.renderAuthScreen(0));
    document.getElementById('tab-auth-register')?.addEventListener('click', () => this.renderAuthScreen(1));

    // Show/Hide Password toggles
    document.getElementById('btn-toggle-login-pw')?.addEventListener('click', () => {
      const inp = document.getElementById('input-login-password');
      if (inp) inp.type = inp.type === 'password' ? 'text' : 'password';
    });
    document.getElementById('btn-toggle-reg-pw')?.addEventListener('click', () => {
      const inp = document.getElementById('input-reg-password');
      if (inp) inp.type = inp.type === 'password' ? 'text' : 'password';
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
        if (user.role === 'admin' || authService.isPhoneAdmin(user.phone)) {
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
      const errEl = document.getElementById('auth-error-msg');
      try {
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

    // Quick Demo Logins
    document.getElementById('btn-quick-student')?.addEventListener('click', () => {
      const user = authService.loginDemo('student');
      user.name = 'ThiZaru';
      user.examYear = '2027 A/L Candidate';
      user.phone = '0770557769';
      user.credits = 155;
      authService.saveSession(user);
      this.currentUser = user;
      this.renderApp();
    });

    document.getElementById('btn-quick-admin')?.addEventListener('click', () => {
      const user = authService.loginDemo('admin');
      authService.saveSession(user);
      this.currentUser = user;
      this.renderAdminApp();
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
      <!-- iOS Status Bar (8:15 battery/wifi) -->
      <div class="ios-status-bar">
        <span class="status-time" id="status-clock">8:15</span>
        <div class="status-icons">
          <span>●●●</span>
          <span>📶</span>
          <span>🔋</span>
        </div>
      </div>

      <!-- Main Scrollable Viewport -->
      <div class="main-viewport" id="main-viewport"></div>

      <!-- Bottom Navigation Bar (Matching student_shell.dart & real_dashboard_light_v4.html) -->
      <nav class="bottom-nav-bar">
        <button class="nav-tab-btn active" data-tab="home">
          <div class="nav-pill-icon">🏠</div>
          <span>Home</span>
        </button>
        <button class="nav-tab-btn" data-tab="papers">
          <div class="nav-pill-icon">📋</div>
          <span>Papers</span>
        </button>
        <button class="nav-tab-btn" data-tab="ranks">
          <div class="nav-pill-icon">🏆</div>
          <span>Ranks</span>
        </button>
        <button class="nav-tab-btn" data-tab="desserts">
          <div class="nav-pill-icon">📁</div>
          <span>Desserts</span>
        </button>
        <button class="nav-tab-btn" data-tab="profile">
          <div class="nav-pill-icon">👤</div>
          <span>Profile</span>
        </button>
      </nav>
    `;

    // Clock
    this.updateClock();
    setInterval(() => this.updateClock(), 30000);

    // Nav Listeners
    document.querySelectorAll('.nav-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.switchTab(btn.dataset.tab);
      });
    });

    this.switchTab('home');

    // Init notification service
    notificationService.init(this.currentUser);
  }

  updateClock() {
    const el = document.getElementById('status-clock');
    if (el) {
      const now = new Date();
      let hrs = now.getHours();
      let mins = now.getMinutes();
      el.textContent = `${hrs}:${mins < 10 ? '0' : ''}${mins}`;
    }
  }

  switchTab(tabName) {
    this.currentTab = tabName;
    const container = document.getElementById('main-viewport');
    if (!container) return;

    document.querySelectorAll('.nav-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });

    switch (tabName) {
      case 'home':
        this.renderHomeScreen(container);
        break;
      case 'papers':
        this.renderPapersScreen(container);
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
  renderHomeScreen(container) {
    const user = this.currentUser || {};
    const studentName = user.name || 'ThiZaru';
    const initial = studentName.charAt(0).toUpperCase();

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
              <span class="verified-icon">✓</span>
            </div>
            <span class="candidate-tag">2027 A/L Candidate</span>
          </div>
        </div>
        <div class="streak-pill">
          <span>🔥</span>
          <span>3 Days</span>
        </div>
      </div>

      <!-- 2. Hero Level Card (Level 2 Cadet, 155 / 200 XP, 3 Mission Checkboxes) -->
      <div class="hero-card">
        <div class="hero-top">
          <div class="hero-title">
            <span>⚡ Level 2 Cadet</span>
          </div>
          <span class="hero-pts">155 / 200 XP</span>
        </div>
        <div class="progress-bar-bg">
          <div class="progress-bar-fill"></div>
        </div>
        <div class="mission-checkboxes-row">
          <div class="mission-check-pill completed">
            <span class="mission-check-title">☑ Daily MCQ</span>
            <span class="mission-check-xp">+50 XP</span>
          </div>
          <div class="mission-check-pill">
            <span class="mission-check-title">☐ Review Tip</span>
            <span class="mission-check-xp">+20 XP</span>
          </div>
          <div class="mission-check-pill">
            <span class="mission-check-title">☐ Homework</span>
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
          <span class="quote-mark">“</span>
        </div>
        <div class="inspiration-quote" id="inspiration-quote-text">
          “Success is the sum of small efforts repeated day in and day out.”
        </div>
      </div>

      <!-- 4. Original 4-Digit Box Countdown (Days, Hours, Mins, Secs) -->
      <div class="cd-card">
        <div class="cd-top">
          <div class="cd-target-pill">⏳ A/L TARGET</div>
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
          <div class="action-icon-badge icon-mcq">⚡</div>
          <span class="action-card-name">Daily MCQ</span>
          <span class="action-card-sub">5 Sprints 🔥</span>
        </div>
        <div class="action-card-item action-box-tutor" id="act-ai-tutor">
          <div class="action-icon-badge icon-tutor">💬</div>
          <span class="action-card-name">AI Tutor</span>
          <span class="action-card-sub">Instant 💬</span>
        </div>
        <div class="action-card-item action-box-hw" id="act-submit-hw">
          <div class="action-icon-badge icon-hw">📷</div>
          <span class="action-card-name">Submit HW</span>
          <span class="action-card-sub">Earn XP 🚀</span>
        </div>
        <div class="action-card-item action-box-ranks" id="act-ranks">
          <div class="action-icon-badge icon-ranks">👑</div>
          <span class="action-card-name">Ranks</span>
          <span class="action-card-sub">Podium 👑</span>
        </div>
      </div>

      <!-- 6. Daily MCQ Sprint Spotlight Card -->
      <div class="sprint-box">
        <div class="sprint-header">
          <div class="sprint-pill-tag">🔥 TODAY'S SPRINT</div>
          <span class="sprint-subtext">5 Quick MCQs</span>
        </div>
        <div class="sprint-topic">Dynamics & Newton's Laws</div>
        <div class="sprint-desc">
          Solve 5 questions daily to maintain your streak and earn +50 XP towards your island rank.
        </div>
        <div class="sprint-start-btn" id="btn-start-sprint-action">
          <span>Start Sprint (+50 XP) ➔</span>
        </div>
      </div>

      <!-- 7. Weekly Study Quests (Gamified Challenge Hub) -->
      <div class="quests-card">
        <div class="quests-top">
          <div class="quests-title">
            <span>🎯</span>
            <span>Weekly Study Quests</span>
          </div>
          <span class="quests-badge">2 / 3 Completed 🏆</span>
        </div>

        <!-- Mission 1 -->
        <div class="quest-item">
          <div class="quest-circle quest-circle-mcq">⚡</div>
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
          <div class="quest-circle quest-circle-hw">📝</div>
          <div class="quest-info">
            <div class="quest-name">Submit Weekly Homework</div>
            <div class="quest-sub">1 submission in review</div>
            <div class="quest-bar">
              <div class="quest-bar-fill" style="width: 100%; background: #2563EB;"></div>
            </div>
          </div>
          <span class="quest-status-badge quest-badge-blue">In Review ⏳</span>
        </div>

        <!-- Mission 3 -->
        <div class="quest-item">
          <div class="quest-circle quest-circle-streak">🔥</div>
          <div class="quest-info">
            <div class="quest-name">Keep 3-Day Study Streak</div>
            <div class="quest-sub">Streak goal achieved!</div>
            <div class="quest-bar">
              <div class="quest-bar-fill" style="width: 100%; background: #059669;"></div>
            </div>
          </div>
          <span class="quest-status-badge quest-badge-green">Claimed! 🌟</span>
        </div>

        <div class="quests-footer-note">
          <span>⭐</span>
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
          <span class="evaluation-proctor-label">Live Proctoring 🎥</span>
        </div>
        <div class="evaluation-title">2027 A/L Physics Term Paper 01</div>
        <div class="evaluation-sub">Full Examination Syllabus • Real-time AI Proctoring & Timed Slots</div>
        <div class="evaluation-pills-row">
          <div class="eval-pill">⏱️ 2h 30m Duration</div>
          <div class="eval-pill">📝 MCQ + Essays</div>
          <div class="eval-pill">🏆 Island Rank</div>
        </div>
        <button class="btn-view-exam-room" id="btn-enter-eval-room">
          <span>View Exam Room & Select Slot</span>
          <span>➔</span>
        </button>
      </div>

      <!-- 9. High-Yield Physics Concept & Formula Vault (Bilingual) -->
      <div class="insight-vault-card">
        <div class="vault-top">
          <div class="vault-pill">
            <span>⚛️</span>
            <span>PHYSICS MICRO-INSIGHT</span>
          </div>
          <div style="display:flex; align-items:center; gap:6px;">
            <span class="vault-tag-pill">අද දවසේ සූත්‍රය • Daily</span>
            <button class="btn-vault-refresh" id="btn-shuffle-insight" title="Shuffle">🔄</button>
          </div>
        </div>
        <div class="vault-topic-meta">යාන්ත්‍ර විද්‍යාව • Mechanics</div>
        <div class="vault-concept-name">
          කාර්යය-ශක්ති ප්‍රමේයය <span style="font-size: 12.5px; font-weight:600; color:#64748B;">(Work-Energy Theorem & Friction Losses)</span>
        </div>
        <div class="vault-formula-box">
          W_net  =  ΔK  =  ½ m v²  -  ½ m u²
        </div>
        <div class="vault-exam-tip-box">
          <div class="tip-header">
            <span>💡</span>
            <span>විභාග උපදෙස (Exam Tip):</span>
          </div>
          <div class="tip-sinhala">
            ආනත තලයක චලිතයේදී ඝර්ෂණයට එරෙහි කාර්යය (W_f = -f · s) යාන්ත්‍රික ශක්ති සමීකරණයට පෙර වෙන්ව සලකා බලන්න.
          </div>
          <div class="tip-english">
            En: Always compute work done against friction W_f = -f · s separately before equating mechanical energy at the base of an incline.
          </div>
        </div>
        <div class="btn-ask-ai-tutor" id="btn-ask-tutor-insight">
          <span>💬</span>
          <span>මේ ගැන AI Tutor ගෙන් අසන්න (Ask AI Tutor)</span>
        </div>
      </div>

      <!-- 10. AI Tutor Quick Inquiries List -->
      <div class="ai-inquiries-card">
        <div class="inquiries-top-title">
          <span>🧠</span>
          <span>AI Tutor Quick Inquiries</span>
        </div>
        <div class="inquiries-desc">
          ඔබට අපැහැදිලි ඕනෑම A/L භෞතික විද්‍යා සංකල්පයක් පිළිබඳව AI Tutor ගෙන් ක්ෂණික පැහැදිලි කිරීමක් ලබාගන්න:
        </div>
        <div class="inquiry-item-btn" data-topic="Lenz's Law">
          <span class="inquiry-text">⚡ ලෙන්ස්ගේ නියමය සහ ප්‍රේරණය (Lenz's Law)</span>
          <span class="inquiry-arrow">➔</span>
        </div>
        <div class="inquiry-item-btn" data-topic="Banking of Roads">
          <span class="inquiry-text">🎯 වක්‍ර මාර්ගවල බැංකු නැංවීම (Banking of Roads)</span>
          <span class="inquiry-arrow">➔</span>
        </div>
        <div class="inquiry-item-btn" data-topic="Doppler Shifts">
          <span class="inquiry-text">💡 ඩොප්ලර් ආචරණය (Doppler Frequency Shifts)</span>
          <span class="inquiry-arrow">➔</span>
        </div>
        <div class="inquiry-item-btn" data-topic="Photoelectric Effect">
          <span class="inquiry-text">⚛️ ප්‍රකාශ විද්‍යුත් ආචරණය (Photoelectric Effect)</span>
          <span class="inquiry-arrow">➔</span>
        </div>
      </div>
    `;

    // Start Live Clock Countdown & Quote Rotator
    this.startCountdownTimer();
    this.startInspirationRotator();

    // Event Listeners
    document.getElementById('act-daily-mcq')?.addEventListener('click', () => this.switchTab('home'));
    document.getElementById('btn-start-sprint-action')?.addEventListener('click', () => this.openSprintDialog());
    document.getElementById('act-ai-tutor')?.addEventListener('click', () => this.openAiTutorDialog());
    document.getElementById('btn-ask-tutor-insight')?.addEventListener('click', () => this.openAiTutorDialog('Work-Energy Theorem'));
    document.getElementById('act-submit-hw')?.addEventListener('click', () => this.openDocumentScanner());
    document.getElementById('act-ranks')?.addEventListener('click', () => this.switchTab('ranks'));
    document.getElementById('btn-enter-eval-room')?.addEventListener('click', () => this.openLiveExamRoom('paper_001'));
    document.getElementById('btn-header-avatar')?.addEventListener('click', () => this.switchTab('profile'));

    container.querySelectorAll('.inquiry-item-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.openAiTutorDialog(btn.dataset.topic);
      });
    });
  }

  // ── 2. Papers Tab (Exam Sessions & Upcoming Hints - 1:1 Android Parity) ──
  async renderPapersScreen(container) {
    if (this.papersInterval) {
      clearInterval(this.papersInterval);
      this.papersInterval = null;
    }

    const user = this.currentUser || { name: 'Scholar', phone: '', examYear: '2027 A/L' };
    const currentYear = user.examYear || '2027 A/L';
    const activeTargetYear = this.showAllBatches ? null : currentYear;

    const [sessions, upcomingList] = await Promise.all([
      dbService.getPaperSessions(activeTargetYear),
      dbService.getUpcomingPapers(activeTargetYear)
    ]);

    const formatHeaderSubtitle = () => {
      if (this.showAllBatches) {
        return 'සියලු Batches • සජීවී විභාග සහ අධීක්ෂණ සැසි';
      }
      return `${currentYear} • සජීවී විභාග සහ අධීක්ෂණ සැසි`;
    };

    container.innerHTML = `
      <!-- App Bar (1:1 with paper_sessions_screen.dart lines 102-153) -->
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:rgba(99,102,241,0.1); color:#6366F1;">
            📋
          </div>
          <div>
            <div class="appbar-title">Paper Writing Sessions</div>
            <div class="appbar-subtitle" id="papers-batch-subtitle">${formatHeaderSubtitle()}</div>
          </div>
        </div>
        <div style="display:flex; align-items:center; gap:8px;">
          <button class="appbar-badge-toggle" id="btn-toggle-papers-batch" title="Toggle Batch Filter">
            <span>${this.showAllBatches ? '🌐 All' : '🎓 Batch'}</span>
          </button>
          <button class="btn-vault-refresh" id="btn-refresh-papers" title="Refresh Sessions">
            🔄
          </button>
        </div>
      </div>

      <!-- View Switcher Tabs (1:1 with lines 156-185 of paper_sessions_screen.dart) -->
      <div class="sub-tabs-container" style="margin: 6px 16px 14px;">
        <button class="sub-tab-btn ${this.papersTab === 0 ? 'active' : ''}" id="tab-papers-live">
          <span>📝 Live Exam Sessions</span>
          <span class="tab-sub">Active & Scheduled</span>
        </button>
        <button class="sub-tab-btn ${this.papersTab === 1 ? 'active' : ''}" id="tab-papers-upcoming">
          <span>🔮 Upcoming Papers & Hints</span>
          <span class="tab-sub">Scope, Tips & Hints</span>
        </button>
      </div>

      <!-- Tab 0: Live Exam Sessions View -->
      <div id="papers-tab-live-content" style="${this.papersTab === 0 ? 'display:flex; flex-direction:column; gap:16px;' : 'display:none;'}">
        ${sessions.length === 0 ? `
          <div style="padding:40px 24px; text-align:center; color:#64748B;">
            <div style="font-size:44px; margin-bottom:12px;">📖</div>
            <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:6px;">නව Paper Sessions සූදානම් වෙමින් පවතී</div>
            <div style="font-size:13px; line-height:1.5;">${this.showAllBatches ? 'දැනට කිසිදු Paper Session එකක් සැලසුම් කර නොමැත.' : `ඔබගේ කණ්ඩායම (${currentYear}) සඳහා ඉදිරි විභාග සැසි මෙහි දිස්වනු ඇත.`}</div>
            <button class="btn-primary" id="btn-empty-toggle-batch" style="margin-top:16px; width:auto; padding:10px 20px; font-size:12.5px;">
              ${this.showAllBatches ? 'මගේ Batch එක පමණක් බලන්න' : 'සියලු Batches වල Sessions බලන්න'}
            </button>
          </div>
        ` : sessions.map(session => {
          const reg = dbService.getStudentRegistration(session.id, user.phone || 'demo_user');
          const isSubmitted = reg?.status === 'submitted' || reg?.isSubmitted === true;
          const selectedSlotId = reg?.selectedSlot || 'slot1';
          const targetSlot = (selectedSlotId === 'slot2' && session.slot2) ? session.slot2 : session.slot1;

          const isEnded = session.status === 'ended' || session.currentPhase === 'ended';
          const isWaiting = session.currentPhase === 'waiting' && !isEnded;
          const isPackageOpening = session.currentPhase === 'package_opening' && !isEnded;
          const isWriting = session.currentPhase === 'writing' && !isEnded;
          const isTimeUp = session.currentPhase === 'time_up' && !isEnded;
          const isLive = !isEnded && !isWaiting && (session.status === 'active' || isPackageOpening || isWriting || isTimeUp);

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
                    ${session.subject}
                  </span>
                  <span style="background:#FFFFFF; color:#475569; border:1px solid #E2E8F0; padding:3px 10px; border-radius:20px; font-size:11px; font-weight:600;">
                    ${session.examYear}
                  </span>
                </div>
                ${isSubmitted ? `
                  <span style="background:rgba(34,197,94,0.12); color:#15803D; border:1px solid rgba(34,197,94,0.4); padding:3px 10px; border-radius:20px; font-size:10px; font-weight:800; display:inline-flex; align-items:center; gap:4px;">
                    <span>✓</span> <span>SUBMITTED</span>
                  </span>
                ` : isLive ? `
                  <span style="background:rgba(34,197,94,0.12); color:#15803D; border:1px solid rgba(34,197,94,0.4); padding:3px 10px; border-radius:20px; font-size:10px; font-weight:800; display:inline-flex; align-items:center; gap:5px;">
                    <span style="width:7px; height:7px; border-radius:50%; background:#22C55E; display:inline-block;"></span>
                    <span>LIVE NOW</span>
                  </span>
                ` : ''}
              </div>

              <!-- Title & Meta -->
              <div class="paper-title" style="margin-top:2px;">${session.title}</div>
              <div class="paper-meta-row">
                <div class="meta-chip">📅 ${new Date(session.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', weekday: 'short' })}</div>
                <div class="meta-chip">⏱️ ${session.durationMinutes} Minutes</div>
                <div class="meta-chip">🎥 Camera Monitored</div>
              </div>

              <!-- Slot Selector (1:1 with _buildSlotCard) -->
              <div style="font-size:11.5px; font-weight:700; color:#475569; margin-top:4px;">
                ${session.slot2 ? 'කරුණාකර ඔබගේ විභාග සැසිය (Slot) තෝරන්න:' : 'විභාග සැසිය (Exam Session):'}
              </div>
              <div class="slots-container">
                <div class="slot-selection-box ${selectedSlotId === 'slot1' ? 'selected' : ''}" data-paper-id="${session.id}" data-slot-id="slot1">
                  <div class="slot-name">
                    <span>☀️ Slot 1 (Morning)</span>
                    <span style="color:#6366F1; font-weight:800;">${selectedSlotId === 'slot1' ? '✓' : '○'}</span>
                  </div>
                  <div style="font-size:11px; color:#475569; font-weight:600;">
                    ${new Date(session.slot1.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} - ${new Date(session.slot1.endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </div>
                  <div class="slot-seats">🪑 ${session.slot1.registeredCount} / ${session.slot1.maxCapacity} Seats</div>
                </div>

                ${session.slot2 ? `
                  <div class="slot-selection-box ${selectedSlotId === 'slot2' ? 'selected' : ''}" data-paper-id="${session.id}" data-slot-id="slot2">
                    <div class="slot-name">
                      <span>🌙 Slot 2 (Evening)</span>
                      <span style="color:#6366F1; font-weight:800;">${selectedSlotId === 'slot2' ? '✓' : '○'}</span>
                    </div>
                    <div style="font-size:11px; color:#475569; font-weight:600;">
                      ${new Date(session.slot2.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} - ${new Date(session.slot2.endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </div>
                    <div class="slot-seats">🪑 ${session.slot2.registeredCount} / ${session.slot2.maxCapacity} Seats</div>
                  </div>
                ` : ''}
              </div>

              <!-- Real-Time Phase Status Banner Box -->
              ${isSubmitted ? `
                <div class="phase-status-banner-box submitted">
                  <span style="font-size:24px;">🎉</span>
                  <div>
                    <div style="font-size:12px; font-weight:800; color:#15803D;">පිළිතුරු පත්‍ර භාරදී ඇත (Answers Submitted)</div>
                    <div style="font-size:11px; color:#475569; margin-top:2px;">
                      ඔබ විසින් පිටු ${reg?.submissionPhotos?.length || 4} ක පිළිතුරු පත්‍රයක් සාර්ථකව භාරදෙන ලදී.
                    </div>
                  </div>
                </div>
              ` : isPackageOpening ? `
                <div class="phase-status-banner-box pkg-opening">
                  <span style="font-size:24px;">📦</span>
                  <div>
                    <div style="font-size:11.5px; font-weight:800; color:#B45309;">පැකේජය විවෘත කිරීමේ කාලය (Package Opening)</div>
                    <div style="font-size:12px; font-weight:800; color:#D97706; margin-top:2px;">
                      කැමරාව ඉදිරියේ පාර්සලය විවෘත කරන්න (<span class="timer-pkg-span" data-start="${session.packageOpeningStartedAt}">${pkgMin}:${pkgSec}</span>)
                    </div>
                  </div>
                </div>
              ` : isWriting ? `
                <div class="phase-status-banner-box writing">
                  <span style="font-size:24px;">✍️</span>
                  <div>
                    <div style="font-size:11.5px; font-weight:800; color:#15803D;">විභාගය ක්‍රියාත්මකයි (Exam Writing in Progress)</div>
                    <div style="font-size:12px; font-weight:800; color:#059669; margin-top:2px;">දැන් පිළිතුරු ලිවීම ආරම්භ කරන්න (Exam Live)</div>
                  </div>
                </div>
              ` : isTimeUp ? `
                <div class="phase-status-banner-box time-up">
                  <span style="font-size:24px;">⏰</span>
                  <div>
                    <div style="font-size:11.5px; font-weight:800; color:#DC2626;">වේලාව අවසන් (Time Up - Scan Answers)</div>
                    <div style="font-size:12px; font-weight:800; color:#B91C1C; margin-top:2px;">පිළිතුරු පත්‍ර Scan කර දැන්ම Submit කරන්න</div>
                  </div>
                </div>
              ` : isWaiting ? `
                <div class="phase-status-banner-box waiting">
                  <span style="font-size:24px;">⏳</span>
                  <div>
                    <div style="font-size:11.5px; font-weight:800; color:#4338CA;">විභාග පොරොත්තු ශාලාව විවෘතයි (Waiting Room Open)</div>
                    <div style="font-size:12px; font-weight:800; color:#6366F1; margin-top:2px;">පොරොත්තු ශාලාවට පිවිසෙන්න (Self-Check)</div>
                  </div>
                </div>
              ` : isEnded ? `
                <div class="phase-status-banner-box ended">
                  <span style="font-size:24px;">🛑</span>
                  <div>
                    <div style="font-size:11.5px; font-weight:800; color:#64748B;">සැසිය අවසන් (Session Completed)</div>
                    <div style="font-size:12px; color:#94A3B8; margin-top:2px;">ස්තුතියි, මෙම විභාග සැසිය අවසන් කර ඇත.</div>
                  </div>
                </div>
              ` : `
                <div class="phase-status-banner-box waiting">
                  <span style="font-size:24px;">⏱️</span>
                  <div>
                    <div style="font-size:11px; font-weight:700; color:#475569;">${targetSlot.name} ආරම්භ වීමට:</div>
                    <div style="font-size:15px; font-weight:800; color:#2563EB; letter-spacing:1px; margin-top:2px;" class="timer-upcoming-span" data-target="${targetSlot.startTime}">
                      01 : 45 : 30
                    </div>
                  </div>
                </div>
              `}

              <!-- Action Buttons (1:1 with lines 1373-1498) -->
              ${isSubmitted ? `
                <button class="btn-primary" style="background:#1E293B; border:1.5px solid #22C55E; color:#4ADE80; padding:12px;" data-view-sub="${session.id}">
                  ✅ Submitted (${reg?.submissionPhotos?.length || 4} Pages) • විස්තර බලන්න
                </button>
              ` : isPackageOpening ? `
                <button class="btn-primary" style="background:#D97706; padding:12px;" data-enter-exam="${session.id}">
                  📦 Open Package in Camera Room (පාර්සලය විවෘත කරන්න)
                </button>
              ` : isWriting ? `
                <button class="btn-primary" style="background:#16A34A; padding:12px;" data-enter-exam="${session.id}">
                  🎥 Enter Live Exam Room (කැමරාව ON කරන්න)
                </button>
              ` : isTimeUp ? `
                <button class="btn-primary" style="background:#DC2626; padding:12px;" data-scan-answers="${session.id}">
                  📄 Scan Answers (පිළිතුරු පත්‍ර Scan කරන්න)
                </button>
              ` : isWaiting ? `
                <button class="btn-primary" style="background:#6366F1; padding:12px;" data-enter-exam="${session.id}">
                  🚪 Enter Waiting Room (පොරොත්තු ශාලාව)
                </button>
              ` : isEnded ? `
                <button class="btn-primary" style="background:#F1F5F9; color:#94A3B8; border:1px solid #CBD5E1; cursor:not-allowed; padding:12px;" onclick="alert('🛑 මෙම විභාග සැසිය නිල වශයෙන් අවසන් කර ඇත (Session Ended).')">
                  🛑 විභාග සැසිය අවසන් විය (Ended)
                </button>
              ` : `
                <button class="btn-primary" style="background:#6366F1; padding:12px;" data-enter-exam="${session.id}">
                  🚪 Enter Waiting Room (පොරොත්තු ශාලාව)
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
            <div style="font-size:44px; margin-bottom:12px;">🔮</div>
            <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:6px;">No Upcoming Papers Scheduled Yet</div>
            <div style="font-size:13px; line-height:1.5;">${this.showAllBatches ? 'Check back soon for new exam papers, scopes, and preparation hints.' : `Upcoming papers and hints for ${currentYear} will be announced here.`}</div>
            <button class="btn-primary" id="btn-empty-toggle-batch-2" style="margin-top:16px; width:auto; padding:10px 20px; font-size:12.5px;">
              ${this.showAllBatches ? 'Show My Batch Only' : 'Show All Batches'}
            </button>
          </div>
        ` : upcomingList.map(paper => {
          const schedDate = new Date(paper.scheduledDate);
          const durationHours = (paper.durationMinutes / 60).toFixed(1);
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
                    ${paper.subject}
                  </span>
                  <span style="background:#FFFFFF; color:#475569; border:1px solid #CBD5E1; padding:3px 10px; border-radius:8px; font-size:11px; font-weight:600;">
                    ${paper.examYear}
                  </span>
                </div>
                <div class="upcoming-countdown-badge">
                  <span>⏱️</span>
                  <span>${diffMs > 0 ? countdownText : 'Paper Active'}</span>
                </div>
              </div>

              <!-- Card Body -->
              <div style="padding:16px; display:flex; flex-direction:column; gap:12px;">
                <div class="paper-title" style="font-size:16.5px;">${paper.title}</div>

                <!-- Date & Duration -->
                <div style="display:flex; flex-direction:column; gap:6px;">
                  <div style="display:flex; align-items:center; gap:6px; font-size:12px; color:#475569;">
                    <span>📅</span>
                    <span>${schedDate.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })} at ${schedDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                  </div>
                  <div style="display:flex; align-items:center; gap:6px; font-size:12px; color:#475569;">
                    <span>⏳</span>
                    <span>${paper.durationMinutes} Minutes (${durationHours} Hours) • ${paper.paperStructure}</span>
                  </div>
                </div>

                <!-- Syllabus Topics Chips (1:1 with lines 543-575) -->
                ${paper.syllabusTopics && paper.syllabusTopics.length > 0 ? `
                  <div style="margin-top:2px;">
                    <div style="font-size:11px; font-weight:700; color:#475569; margin-bottom:4px;">Syllabus & Tested Topics:</div>
                    <div class="upcoming-topics-wrap">
                      ${paper.syllabusTopics.map(topic => `
                        <div class="upcoming-topic-chip">
                          <span style="color:#10B981; font-weight:800;">✓</span>
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
                      <span style="font-size:16px;">💡</span>
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
                    <span>ℹ️</span>
                    <span>${paper.instructions}</span>
                  </div>
                ` : ''}

                <!-- Action Button -->
                <button class="btn-primary" style="background:#6366F1; padding:12px; font-size:13px; font-weight:700; display:flex; align-items:center; justify-content:center; gap:6px; box-shadow:0 4px 14px rgba(99,102,241,0.3);" data-paper-scope="${paper.id}">
                  <span>👁️</span>
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
          studentId: user.phone || 'demo_user',
          studentName: user.name || 'Scholar',
          studentPhone: user.phone || '0770557769',
          slotId: sId
        });
        notificationService.showLocalToast(`✅ ${sId === 'slot1' ? 'Slot 1 (Morning)' : 'Slot 2 (Evening)'} සාර්ථකව වෙන්කර ගන්නා ලදී!`);
        this.renderPapersScreen(container);
      });
    });

    // View Submission Details
    container.querySelectorAll('[data-view-sub]').forEach(btn => {
      btn.addEventListener('click', () => {
        const pId = btn.dataset.viewSub;
        const sess = sessions.find(s => s.id === pId);
        const reg = dbService.getStudentRegistration(pId, user.phone || 'demo_user');
        if (sess) this.showSubmissionDetailsDialog(sess, reg);
      });
    });

    // Enter Exam / Waiting Room
    container.querySelectorAll('[data-enter-exam]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.openLiveExamRoom(btn.dataset.enterExam);
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
              <span style="font-size:20px;">📅</span>
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
              <span style="font-size:20px;">⏱️</span>
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
                    <span style="color:#10B981; font-weight:800;">✓</span>
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
                <span>💡</span>
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
          <span style="font-size:26px; color:#22C55E;">✅</span>
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
    this.ranksBoardType = this.ranksBoardType ?? 0; // 0: Dessert, 1: Paper
    this.selectedLeague = this.selectedLeague ?? 'All Scholars';
    this.selectedRanksBatch = this.selectedRanksBatch ?? 'All Batches';
    this.expandedPaperBoards = this.expandedPaperBoards ?? new Set(['paper_001']);

    const leaders = await dbService.getLeaderboard();
    const leagues = [
      { name: 'All Scholars', emoji: '🌐' },
      { name: 'Diamond', emoji: '💎' },
      { name: 'Gold', emoji: '🥇' },
      { name: 'Silver', emoji: '🥈' },
      { name: 'Bronze', emoji: '🥉' }
    ];

    const filtered = leaders.filter(s => {
      if (this.selectedRanksBatch !== 'All Batches' && s.examYear !== this.selectedRanksBatch) return false;
      if (this.selectedLeague === 'Diamond') return s.credits >= 500;
      if (this.selectedLeague === 'Gold') return s.credits >= 250 && s.credits < 500;
      if (this.selectedLeague === 'Silver') return s.credits >= 100 && s.credits < 250;
      if (this.selectedLeague === 'Bronze') return s.credits < 100;
      return true;
    });

    const top3 = filtered.slice(0, 3);
    const rest = filtered.slice(3);

    container.innerHTML = `
      <!-- Screen Top Bar -->
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#FEF3C7; color:#B45309;">🏆</div>
          <div>
            <div class="appbar-title">${this.ranksBoardType === 0 ? 'Dessert Leaderboard 🧁' : 'Paper Leaderboard 📝'}</div>
            <div class="appbar-subtitle">${this.ranksBoardType === 0 ? 'XP Credits & Activity Leagues' : 'Exam Marks & Island Rankings'}</div>
          </div>
        </div>
      </div>

      <!-- Segmented Switcher: Dessert vs Paper -->
      <div class="sub-tabs-container">
        <button class="sub-tab-btn ${this.ranksBoardType === 0 ? 'active' : ''}" id="btn-ranks-dessert-mode">
          <span>🧁 Dessert Leaderboard</span>
          <span class="tab-sub">XP & Activity Leagues</span>
        </button>
        <button class="sub-tab-btn ${this.ranksBoardType === 1 ? 'active' : ''}" id="btn-ranks-paper-mode">
          <span>📝 Paper Leaderboard</span>
          <span class="tab-sub">Exam Marks & Ranks</span>
        </button>
      </div>

      ${this.ranksBoardType === 0 ? `
        <!-- League Horizontal Filter Scroll -->
        <div class="leagues-scroll-row">
          ${leagues.map(l => `
            <button class="league-chip ${this.selectedLeague === l.name ? 'active' : ''}" data-league="${l.name}">
              <span>${l.emoji}</span>
              <span>${l.name}</span>
            </button>
          `).join('')}
        </div>

        <!-- Batch Filter Row -->
        <div class="batch-filter-row">
          <span>Batch Selection:</span>
          <select class="batch-select" id="select-ranks-batch">
            <option value="All Batches" ${this.selectedRanksBatch === 'All Batches' ? 'selected' : ''}>All Batches</option>
            <option value="2026 A/L" ${this.selectedRanksBatch === '2026 A/L' ? 'selected' : ''}>2026 A/L</option>
            <option value="2027 A/L" ${this.selectedRanksBatch === '2027 A/L' ? 'selected' : ''}>2027 A/L</option>
            <option value="2028 A/L" ${this.selectedRanksBatch === '2028 A/L' ? 'selected' : ''}>2028 A/L</option>
          </select>
        </div>

        <!-- Top 3 Podium (Rank 2 Silver on left, Rank 1 Gold in center, Rank 3 Bronze on right) -->
        <div class="podium-container">
          <!-- Rank 2 -->
          ${top3[1] ? `
            <div class="podium-card">
              <div class="podium-medal">🥈</div>
              <div class="podium-name">${top3[1].name.split(' ')[0]}</div>
              <div class="podium-xp">${top3[1].credits} XP</div>
              <span style="font-size:10px; color:#64748B;">#2 Rank</span>
            </div>
          ` : '<div></div>'}

          <!-- Rank 1 Gold (Elevated) -->
          ${top3[0] ? `
            <div class="podium-card podium-card-gold">
              <div class="podium-medal-gold">👑</div>
              <div class="podium-name">${top3[0].name.split(' ')[0]}</div>
              <div class="podium-xp">${top3[0].credits} XP</div>
              <span style="font-size:11px; font-weight:800; color:#B45309;">#1 Island Rank</span>
            </div>
          ` : '<div></div>'}

          <!-- Rank 3 -->
          ${top3[2] ? `
            <div class="podium-card">
              <div class="podium-medal">🥉</div>
              <div class="podium-name">${top3[2].name.split(' ')[0]}</div>
              <div class="podium-xp">${top3[2].credits} XP</div>
              <span style="font-size:10px; color:#64748B;">#3 Rank</span>
            </div>
          ` : '<div></div>'}
        </div>

        <!-- Full List from Rank #4 onwards -->
        <div style="display:flex; flex-direction:column; gap:4px;">
          ${rest.map(r => `
            <div class="rank-list-item">
              <div class="rank-item-left">
                <span class="rank-index">#${r.rank}</span>
                <div class="rank-avatar">${r.name.charAt(0)}</div>
                <div class="rank-name-box">
                  <div class="rank-student-name">
                    <span>${r.name}</span>
                    <span style="color:#2563EB; font-size:11px;">✓</span>
                  </div>
                  <div class="rank-batch-tag">${r.examYear} Candidate</div>
                </div>
              </div>
              <div style="display:flex; align-items:center; gap:8px;">
                <span style="font-size:11.5px;">🔥 3d</span>
                <span class="rank-xp-pill">${r.credits} XP</span>
              </div>
            </div>
          `).join('')}
        </div>

        <!-- Sticky Bottom Bar for Current Student's Rank -->
        <div class="my-rank-sticky-bar">
          <div class="my-rank-info">
            <span class="my-rank-num">#3</span>
            <div>
              <div style="font-size:12.5px; font-weight:800;">Kasun Perera (You)</div>
              <div style="font-size:10.5px; color:#94A3B8;">Next Rank: +45 XP needed</div>
            </div>
          </div>
          <span style="font-size:13px; font-weight:900; color:#38BDF8;">155 XP</span>
        </div>
      ` : `
        <!-- Paper Leaderboard View -->
        <div style="display:flex; flex-direction:column; gap:12px;">
          <div class="paper-board-card">
            <div class="paper-board-header" id="btn-toggle-pb1">
              <div>
                <div style="font-size:14.5px; font-weight:800; color:#0F172A;">2027 A/L Physics Term Paper 01</div>
                <div class="paper-board-stats">
                  <span>📅 Sept 2026</span>
                  <span>📊 Avg: 68.4</span>
                  <span>🏆 Highest: 98</span>
                  <span>👥 142 Students</span>
                </div>
              </div>
              <span style="font-size:18px; color:#2563EB;">▼</span>
            </div>

            <div class="paper-scores-table" id="pb1-table">
              <div style="display:flex; justify-content:space-between; align-items:center; padding:8px 6px; border-bottom:1px solid #E2E8F0; font-size:12px; font-weight:800; background:#ECFDF5; border-radius:8px;">
                <div style="display:flex; align-items:center; gap:8px;">
                  <span style="color:#047857;">#14 (You)</span>
                  <span>Kasun Perera</span>
                </div>
                <div style="display:flex; align-items:center; gap:8px;">
                  <span class="grade-badge grade-A">A Grade</span>
                  <span style="font-size:13px; font-weight:900; color:#047857;">78 / 100</span>
                </div>
              </div>

              ${[
                { rank: 1, name: 'Danushka Wickramasinghe', marks: 98, grade: 'A', time: '2h 10m' },
                { rank: 2, name: 'Minoli Senarath', marks: 94, grade: 'A', time: '2h 18m' },
                { rank: 3, name: 'Sachintha Fernando', marks: 91, grade: 'A', time: '2h 25m' },
                { rank: 4, name: 'Dinuka Rajapaksha', marks: 88, grade: 'A', time: '2h 28m' },
                { rank: 5, name: 'Kavindu Jayawardena', marks: 84, grade: 'A', time: '2h 30m' }
              ].map(s => `
                <div style="display:flex; justify-content:space-between; align-items:center; padding:8px 6px; font-size:12px; border-bottom:1px solid #F1F5F9;">
                  <div style="display:flex; align-items:center; gap:8px;">
                    <span style="font-weight:800; color:#64748B; width:22px;">#${s.rank}</span>
                    <span style="font-weight:700; color:#1E293B;">${s.name}</span>
                  </div>
                  <div style="display:flex; align-items:center; gap:8px;">
                    <span style="font-size:10.5px; color:#64748B;">⏱️ ${s.time}</span>
                    <span class="grade-badge grade-${s.grade}">${s.grade}</span>
                    <span style="font-weight:800; color:#2563EB;">${s.marks}</span>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>
        </div>
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
      this.renderRanksScreen(container);
    });

    document.getElementById('btn-toggle-pb1')?.addEventListener('click', () => {
      const tbl = document.getElementById('pb1-table');
      if (tbl) tbl.style.display = tbl.style.display === 'none' ? 'flex' : 'none';
    });
  }

  // ── 4. Desserts Tab (Submit Homework & Submissions History - 1:1 Android) ──
  async renderDessertsScreen(container) {
    this.dessertsTab = this.dessertsTab ?? 0; // 0: Submit Homework, 1: History
    this.selectedTopic = this.selectedTopic ?? 'Mechanics';
    this.capturedHomeworkPhotos = this.capturedHomeworkPhotos ?? [];
    this.dessertHistoryFilter = this.dessertHistoryFilter ?? 'All';

    const user = this.currentUser || {};
    const desserts = await dbService.getStudentDesserts(user.uid, user.phone);

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
          <div class="appbar-icon-box" style="background:#EFF6FF; color:#2563EB;">📁</div>
          <div>
            <div class="appbar-title">Dessert Homework System</div>
            <div class="appbar-subtitle">A/L Physics Daily Problem Sets & Submissions</div>
          </div>
        </div>
      </div>

      <!-- Sub-Tabs: Submit Homework vs Submissions History -->
      <div class="sub-tabs-container">
        <button class="sub-tab-btn ${this.dessertsTab === 0 ? 'active' : ''}" id="tab-dessert-submit">
          <span>📤 Submit Homework</span>
          <span class="tab-sub">Scan & Upload Pages</span>
        </button>
        <button class="sub-tab-btn ${this.dessertsTab === 1 ? 'active' : ''}" id="tab-dessert-history">
          <span>📁 Submission History</span>
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
                <span style="font-size:24px;">📷</span>
                <span>In-App Camera</span>
              </button>
              <label class="capture-btn" for="input-hw-gallery" style="margin-bottom:0;">
                <span style="font-size:24px;">🖼️</span>
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
                    <button class="photo-delete-btn" data-del-photo="${i}">✕</button>
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
              <div style="font-size:12.5px; font-weight:800;">🤖 Submit via Telegram AI Bot</div>
              <div style="font-size:10.5px; opacity:0.9; margin-top:2px;">Prefer Telegram? Forward images directly to @edupeakbot</div>
            </div>
            <a href="https://t.me/edupeakbot" target="_blank" style="background:#FFFFFF; color:#0369A1; padding:6px 12px; border-radius:20px; font-size:11.5px; font-weight:800; text-decoration:none;">
              Open Bot
            </a>
          </div>

          <!-- Submit Button -->
          <button class="btn-primary" id="btn-submit-dessert-final" style="padding:14px; font-size:15px; margin-top:4px;">
            🚀 Submit Homework (+100 XP)
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
                    <div style="font-size:32px; margin-bottom:8px;">📁</div>
                    <div style="font-weight:700; font-size:14px; color:#0F172A;">No Submissions Found</div>
                    <div style="font-size:11.5px; margin-top:4px;">No ${this.dessertHistoryFilter} submissions yet. Submit your homework in Tab 1 to earn XP!</div>
                  </div>
                `;
              }
              return filtered.map(d => {
                const isApp = d.status === 'approved';
                const isPend = d.status === 'pending';
                const badgeClass = isApp ? 'quest-badge-green' : isPend ? 'quest-badge-orange' : 'quest-badge-blue';
                const label = isApp ? 'Approved ✓' : isPend ? 'In Review ⏳' : 'Needs Redo ⚠️';

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
                        <strong>👨‍🏫 Teacher Feedback:</strong> ${d.adminFeedback}
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
        btn.textContent = 'Uploading to Teacher... ⏳';
      }

      await dbService.submitDessert({
        studentId: user.uid,
        studentName: user.name,
        studentPhone: user.phone,
        subject: `Physics: ${this.selectedTopic}`,
        caption: caption || `Homework submission on ${this.selectedTopic}`,
        mediaUrls: this.capturedHomeworkPhotos.length > 0 ? this.capturedHomeworkPhotos : ['./icons/exam_3d_countdown.jpg']
      });

      this.capturedHomeworkPhotos = [];
      notificationService.showInAppBanner('Homework Submitted! 🍰', '+100 XP awarded to your profile.', 'success');
      this.dessertsTab = 1;
      this.renderDessertsScreen(container);
    });

    container.querySelectorAll('[data-view-dessert]').forEach(card => {
      card.addEventListener('click', () => {
        this.openDessertDetailModal(card.dataset.viewDessert);
      });
    });
  }

  // ── 5. Profile Tab (Trophy Room, Dark Mode, Admin Switcher - 1:1 Android) ──
  renderProfileScreen(container) {
    const user = this.currentUser || {};
    const isStandalone = window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches;
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';

    container.innerHTML = `
      <!-- Screen Top Bar -->
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#EFF6FF; color:#2563EB;">👤</div>
          <div>
            <div class="appbar-title">Student Profile</div>
            <div class="appbar-subtitle">Account Details, Trophy Room & Preferences</div>
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
          <button class="profile-cam-btn" id="btn-change-avatar" title="Change Photo">📷</button>
        </div>

        <div style="display:flex; align-items:center; gap:6px; margin-top:4px;">
          <span style="font-size:19px; font-weight:800; color:#0F172A;">${user.name || 'Kasun Perera'}</span>
          <button id="btn-edit-student-name" style="background:none; border:none; color:#64748B; cursor:pointer; font-size:14px;">✏️</button>
        </div>

        <div style="font-size:12px; color:#64748B; margin-top:2px;">
          ${user.phone || '+94 77 123 4567'} • <span style="color:#059669; font-weight:700;">Verified Student ✓</span>
        </div>

        <div style="margin-top:10px; padding:5px 12px; border-radius:20px; font-size:11px; font-weight:800; background: ${isStandalone ? '#ECFDF5' : '#FEF3C7'}; color: ${isStandalone ? '#047857' : '#B45309'}; border: 1px solid ${isStandalone ? '#A7F3D0' : '#FDE68A'};">
          ${isStandalone ? '🟢 iPhone Home Screen (PWA Standalone Mode)' : '⚠️ Safari Browser Tab'}
        </div>
      </div>

      <!-- 3-Item Stats Card (Credits, Approved, Pending) -->
      <div class="stats-trio-card">
        <div>
          <div class="stat-number" style="color:#F59E0B;">⭐ 155</div>
          <div class="stat-label">Credits (XP)</div>
        </div>
        <div class="stat-divider"></div>
        <div>
          <div class="stat-number" style="color:#10B981;">✅ 4</div>
          <div class="stat-label">Approved</div>
        </div>
        <div class="stat-divider"></div>
        <div>
          <div class="stat-number" style="color:#EA580C;">⏳ 1</div>
          <div class="stat-label">Pending</div>
        </div>
      </div>

      <!-- Account Details Card -->
      <div class="hero-card" style="padding:14px 18px; margin-top:14px;">
        <div style="display:flex; align-items:center; justify-content:space-between; padding:8px 0; border-bottom:1px solid #E2E8F0;">
          <div style="display:flex; align-items:center; gap:8px; font-size:12.5px; font-weight:700; color:#334155;">
            <span>🎓 Role:</span>
          </div>
          <span style="font-size:12px; font-weight:800; color:#2563EB;">Student (A/L Physics)</span>
        </div>
        <div style="display:flex; align-items:center; justify-content:space-between; padding:8px 0; border-bottom:1px solid #E2E8F0;">
          <div style="display:flex; align-items:center; gap:8px; font-size:12.5px; font-weight:700; color:#334155;">
            <span>📅 Member Since:</span>
          </div>
          <span style="font-size:12px; font-weight:600; color:#64748B;">September 2026</span>
        </div>
        <div style="display:flex; align-items:center; justify-content:space-between; padding:8px 0;">
          <div style="display:flex; align-items:center; gap:8px; font-size:12.5px; font-weight:700; color:#334155;">
            <span>📁 Total Submissions:</span>
          </div>
          <span style="font-size:12px; font-weight:800; color:#0F172A;">5 Problem Sets</span>
        </div>
      </div>

      <!-- Features & Preferences -->
      <div style="display:flex; flex-direction:column; gap:10px; margin-top:14px;">
        <!-- Trophy Room -->
        <button class="hero-card" style="padding:14px; flex-direction:row; align-items:center; justify-content:space-between; cursor:pointer;" id="btn-open-trophy-room">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:24px;">🏆</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:800; color:#0F172A;">Trophy Room & Flex Zone</div>
              <div style="font-size:11px; color:#64748B;">View 8 Unlockable Badges & Achievements</div>
            </div>
          </div>
          <span style="color:#2563EB; font-weight:800;">➔</span>
        </button>

        <!-- Dark Mode Toggle -->
        <div class="hero-card" style="padding:14px; flex-direction:row; align-items:center; justify-content:space-between;">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:22px;">🌙</span>
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
            <span style="font-size:22px;">🔔</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:800; color:#0F172A;">Web Push Notifications</div>
              <div style="font-size:11px; color:#64748B;">Test Alert Banners & Audio Chime</div>
            </div>
          </div>
          <span style="color:#2563EB; font-weight:800;">➔</span>
        </button>

        <!-- Teacher / Admin Console (Always accessible in Demo Mode) -->
        <button class="hero-card" style="padding:14px; flex-direction:row; align-items:center; justify-content:space-between; cursor:pointer; background:linear-gradient(135deg, #EFF6FF, #DBEAFE); border-color:#93C5FD;" id="btn-profile-admin">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:22px;">👑</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:800; color:#1E3A8A;">Teacher / Admin Console</div>
              <div style="font-size:11px; color:#2563EB;">Grade Submissions & Manage Exam Papers</div>
            </div>
          </div>
          <span style="color:#2563EB; font-weight:800;">➔</span>
        </button>

        <!-- Sign Out Button -->
        <button class="btn-primary" style="background:#EF4444; margin-top:6px;" id="btn-profile-logout">
          🚪 Sign Out
        </button>
      </div>
    `;

    // Event Listeners for Profile Tab
    document.getElementById('btn-open-trophy-room')?.addEventListener('click', () => {
      this.openTrophyRoomModal();
    });

    document.getElementById('btn-edit-student-name')?.addEventListener('click', () => {
      this.openEditNameDialog();
    });

    document.getElementById('btn-change-avatar')?.addEventListener('click', () => {
      const url = prompt('Enter image URL or photo link for your profile picture:', user.avatarUrl || '');
      if (url) {
        user.avatarUrl = url;
        authService.currentUser.avatarUrl = url;
        this.renderProfileScreen(container);
      }
    });

    document.getElementById('chk-dark-mode')?.addEventListener('change', (e) => {
      const dark = e.target.checked;
      document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
      localStorage.setItem('edupeak_theme', dark ? 'dark' : 'light');
    });

    document.getElementById('btn-profile-notifs')?.addEventListener('click', () => {
      this.openNotificationCenter();
    });

    document.getElementById('btn-profile-admin')?.addEventListener('click', () => {
      this.currentMode = 'admin';
      this.renderAdminApp();
    });

    document.getElementById('btn-profile-logout')?.addEventListener('click', () => {
      this.confirmLogout();
    });
  }

  // ── Trophy Room Modal (Matching badge_model.dart & trophy_room_sheet.dart) ─
  openTrophyRoomModal() {
    const badges = [
      { id: 'streak_3', emoji: '🔥', title: '3-Day Fire Streak', desc: 'Stay active and learn for 3 consecutive days.', unlocked: true, progress: 100, label: '3 / 3 Days' },
      { id: 'first_masterpiece', emoji: '🍰', title: 'First Masterpiece', desc: 'Get your very first homework approved by teacher.', unlocked: true, progress: 100, label: '1 / 1 Approved' },
      { id: 'century_club', emoji: '⚡', title: 'Century Scholar', desc: 'Earn 100 or more XP credits across all homework.', unlocked: true, progress: 100, label: '155 / 100 XP' },
      { id: 'speed_demon', emoji: '🚀', title: 'Speed Demon', desc: 'Submit 5 homework solutions with high precision.', unlocked: false, progress: 80, label: '4 / 5 Done' },
      { id: 'night_owl', emoji: '🦉', title: 'Night Owl Scholar', desc: 'Dedication at night! Submit homework after 9:00 PM.', unlocked: true, progress: 100, label: '2 / 2 Night Subs' },
      { id: 'podium_king', emoji: '👑', title: 'Podium King', desc: 'Reach the Top 3 on the Institute Leaderboard.', unlocked: false, progress: 77, label: '155 / 200 XP' },
      { id: 'grandmaster', emoji: '🏆', title: 'Dessert Grandmaster', desc: 'Accumulate 500 XP and achieve ultimate mastery.', unlocked: false, progress: 31, label: '155 / 500 XP' },
      { id: 'physics_guru', emoji: '⚛️', title: 'Physics Prodigy', desc: 'Solve 3 Daily MCQ Sprints with 100% correct score.', unlocked: true, progress: 100, label: '3 / 3 Completed' }
    ];

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <div style="display:flex; align-items:center; gap:8px;">
            <span style="font-size:22px;">🏆</span>
            <div>
              <h3 class="modal-title">Trophy Room & Flex Zone</h3>
              <div style="font-size:11px; color:#64748B;">Unlock badges by submitting homework & earning XP</div>
            </div>
          </div>
          <button class="modal-close-btn" id="btn-close-trophy">✕</button>
        </div>

        <div class="badges-grid">
          ${badges.map(b => `
            <div class="badge-card ${b.unlocked ? 'unlocked' : ''}">
              <div class="badge-top">
                <span class="badge-emoji">${b.emoji}</span>
                <span class="badge-status-tag ${b.unlocked ? 'badge-unlocked-tag' : 'badge-locked-tag'}">
                  ${b.unlocked ? 'UNLOCKED' : 'LOCKED'}
                </span>
              </div>
              <div class="badge-title">${b.title}</div>
              <div class="badge-desc">${b.desc}</div>
              <div class="badge-progress-bg">
                <div class="badge-progress-fill" style="width:${b.progress}%; background:${b.unlocked ? '#10B981' : '#2563EB'};"></div>
              </div>
              <div style="font-size:9.5px; font-weight:800; color:#64748B; margin-top:2px;">${b.label}</div>
            </div>
          `).join('')}
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-trophy')?.addEventListener('click', () => modal.remove());
  }

  // ── Edit Name Dialog ──────────────────────────────────────────────────────
  openEditNameDialog() {
    const currentName = this.currentUser?.name || 'Kasun Perera';
    const newName = prompt('Enter your full name:', currentName);
    if (newName && newName.trim().length > 0) {
      this.currentUser.name = newName.trim();
      authService.currentUser.name = newName.trim();
      this.renderScreen(this.activeTab);
    }
  }

  // ── Dessert Detail Modal ──────────────────────────────────────────────────
  async openDessertDetailModal(dessertId) {
    const user = this.currentUser || {};
    const desserts = await dbService.getStudentDesserts(user.uid, user.phone);
    const d = desserts.find(x => x.id === dessertId) || desserts[0];
    if (!d) return;

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title">📁 Submission Details</h3>
          <button class="modal-close-btn" id="btn-close-detail">✕</button>
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
  openAdminReviewModal() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title">👑 Teacher / Admin Console</h3>
          <button class="modal-close-btn" id="btn-close-admin">✕</button>
        </div>
        <div style="font-size:13px; color:#475569; line-height:1.5; margin-bottom:14px;">
          Welcome to the Teacher portal. Here you can grade submitted physics problem sets, set exam timers, and schedule new paper sessions.
        </div>
        <div style="display:flex; flex-direction:column; gap:8px;">
          <button class="btn-primary" style="background:#059669;" onclick="alert('Grading sheet loaded. 5 pending submissions marked as Approved (+100 XP).'); modal.remove();">
            ✅ Approve All Pending Submissions (+100 XP)
          </button>
          <button class="btn-primary" style="background:#2563EB;" onclick="alert('New exam paper created for 2027 A/L batch.'); modal.remove();">
            📝 Schedule New Model Paper
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
          <h3 class="modal-title">💬 AI Physics Tutor</h3>
          <button class="modal-close-btn" id="btn-close-tutor-sheet">✕</button>
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

        <button class="btn-primary" id="btn-send-tutor">
          ⚡ Ask Instant Explanation
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
  openSprintDialog() {
    const sprint = dbService.getDailySprint();
    const questions = sprint.questions;
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
              <span style="font-size:22px;">🔥</span>
              <div>
                <h3 class="modal-title">Daily MCQ Sprint</h3>
                <div style="font-size:11px; color:#64748B;">A/L Physics • දවසේ MCQ 5</div>
              </div>
            </div>
            <button class="modal-close-btn" id="btn-close-sprint">✕</button>
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
              <span>⏱️</span>
              <span id="sprint-timer-val">${Math.floor(elapsedSeconds / 60).toString().padStart(2, '0')}:${(elapsedSeconds % 60).toString().padStart(2, '0')}</span>
            </div>
          </div>

          <!-- Question Text -->
          <div style="font-size:14px; font-weight:800; color:#0F172A; line-height:1.5; margin-bottom:14px; background:#F8FAFC; padding:14px; border-radius:14px; border:1px solid #E2E8F0;">
            ${q.text}
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
              <strong>💡 විවරණය (Explanation):</strong><br>
              ${q.explanation}
            </div>
          ` : ''}

          <!-- Navigation Buttons -->
          <div style="display:flex; gap:8px;">
            ${currentIdx > 0 ? `
              <button class="btn-primary" style="background:#F1F5F9; color:#475569; width:auto; padding:12px 18px;" id="btn-sprint-prev">
                ◀ Prev
              </button>
            ` : ''}

            <button class="btn-primary" style="flex:1;" id="btn-sprint-next">
              ${currentIdx === questions.length - 1 ? 'Finish Sprint & Claim +50 XP 🚀' : 'Next Question ▶'}
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

      document.getElementById('btn-sprint-next')?.addEventListener('click', () => {
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

          notificationService.showInAppBanner('Sprint Complete! 🔥', `You scored ${correct}/5. +50 XP awarded!`, 'success');

          modal.innerHTML = `
            <div class="modal-sheet" style="text-align:center; padding:30px 20px;">
              <div style="font-size:54px;">🏆</div>
              <h2 style="font-size:20px; font-weight:900; color:#0F172A; margin-top:8px;">Sprint Completed!</h2>
              <div style="font-size:13.5px; color:#64748B; margin-top:4px;">
                You scored <strong style="color:#059669;">${correct} / 5</strong> in ${Math.floor(elapsedSeconds / 60)}m ${elapsedSeconds % 60}s.
              </div>
              <div style="margin:16px auto; padding:10px 20px; background:#FEF3C7; color:#B45309; border-radius:20px; font-size:14px; font-weight:900; width:fit-content;">
                ⭐ +50 XP Added to Your Rank!
              </div>
              <button class="btn-primary" id="btn-finish-sprint-sheet" style="margin-top:10px;">
                Back to Dashboard
              </button>
            </div>
          `;

          document.getElementById('btn-finish-sprint-sheet')?.addEventListener('click', () => {
            modal.remove();
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
          <span>📷 Scan Homework</span>
          <span class="scanner-page-counter" id="scanner-page-count">0 Pages</span>
        </div>
        <div class="scanner-top-actions">
          <button class="btn-scanner-icon" id="btn-toggle-torch" title="Flashlight">⚡</button>
          <button class="btn-scanner-icon" id="btn-close-scanner" title="Close">✕</button>
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
            <span>📁 Gallery</span>
            <input type="file" id="input-file-camera" accept="image/*" capture="environment" style="display:none;" multiple />
          </label>

          <div class="shutter-btn-wrap">
            <div class="shutter-outer-ring"></div>
            <button class="btn-shutter" id="btn-trigger-shutter"></button>
          </div>

          <button class="btn-done-scanning" id="btn-finish-scan" disabled>
            <span>Done</span>
            <span>✓</span>
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
            <button class="thumb-del-btn" data-del-idx="${idx}">✕</button>
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
          <button class="modal-close-btn" id="btn-close-submit-dialog">✕</button>
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

        <button class="btn-primary" id="btn-confirm-upload">
          🚀 Submit Homework Now (+50 XP)
        </button>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-submit-dialog')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-confirm-upload')?.addEventListener('click', async () => {
      const btn = document.getElementById('btn-confirm-upload');
      btn.disabled = true;
      btn.textContent = 'Uploading... ⏳';

      await dbService.submitDessert({
        studentId: this.currentUser.studentId || 'EP-2027',
        studentName: this.currentUser.name || 'ThiZaru',
        studentPhone: this.currentUser.phone || '0770557769',
        subject: document.getElementById('submit-topic-input')?.value,
        caption: document.getElementById('submit-note-input')?.value,
        mediaUrls: pages
      });

      modal.remove();
      notificationService.showInAppBanner('Homework Submitted! 🎉', 'Your teacher will review your submission and award marks.', 'success');
      this.switchTab('desserts');
    });
  }

  // ── Live Exam Room with Front-Camera Proctoring ───────────────────────────
  openLiveExamRoom(paperId) {
    this.isInsideLiveExam = true;
    this.antiCheatViolations = 0;

    const modal = document.createElement('div');
    modal.className = 'exam-hall-container';
    modal.id = 'exam-hall-room';

    modal.innerHTML = `
      <header class="exam-header">
        <div class="exam-info-col">
          <span class="exam-title">2027 A/L Physics Term Paper 01</span>
          <span class="exam-status-indicator">
            <span class="live-dot"></span>
            Proctored Session Active
          </span>
        </div>
        <div class="exam-timer-box">
          <span>⏱️</span>
          <span>02:29:59</span>
        </div>
        <button class="btn-scanner-icon" id="btn-exit-exam">✕</button>
      </header>

      <div class="proctor-live-box">
        <video class="proctor-video" id="proctor-live-video" autoplay playsinline muted></video>
        <div class="proctor-badge">
          <span class="proctor-pulse"></span>
          <span>LIVE</span>
        </div>
      </div>

      <div class="exam-body">
        <div class="question-card">
          <div class="q-badge-row">
            <span class="q-number-pill">Question 1</span>
            <span class="q-points-pill">1.0 Mark</span>
          </div>
          <div class="q-text">
            A simple pendulum has period T at the Earth's surface. If it is placed in an elevator moving downwards with acceleration g/4, its new period is:
          </div>
          <div class="q-options-list">
            <div class="q-option-item"><span class="q-option-letter">A</span><span class="q-option-text">T / 2</span></div>
            <div class="q-option-item selected"><span class="q-option-letter">B</span><span class="q-option-text">2T / √3</span></div>
            <div class="q-option-item"><span class="q-option-letter">C</span><span class="q-option-text">T * √3 / 2</span></div>
            <div class="q-option-item"><span class="q-option-letter">D</span><span class="q-option-text">2T</span></div>
            <div class="q-option-item"><span class="q-option-letter">E</span><span class="q-option-text">T / √2</span></div>
          </div>
        </div>
      </div>

      <footer class="exam-footer">
        <button class="btn-nav-q" disabled>← Prev</button>
        <span style="font-size:12px; font-weight:700; color:var(--text-sub);">Q1 / 50</span>
        <button class="btn-nav-q">Next →</button>
        <button class="btn-finish-exam" id="btn-submit-exam-paper">Submit Paper</button>
      </footer>
    `;

    document.body.appendChild(modal);

    const proctorVideo = document.getElementById('proctor-live-video');
    cameraService.startCamera(proctorVideo, 'user').catch(err => {
      console.warn('[Proctor] Notice:', err.message);
    });

    const exit = () => {
      this.isInsideLiveExam = false;
      cameraService.stopCamera();
      modal.remove();
    };

    document.getElementById('btn-exit-exam')?.addEventListener('click', () => {
      if (confirm('Leave the proctored exam hall?')) exit();
    });

    document.getElementById('btn-submit-exam-paper')?.addEventListener('click', () => {
      alert('Paper successfully submitted! Score recorded.');
      exit();
    });
  }

  handleExamTabSwitch() {
    this.antiCheatViolations++;
    const modal = document.createElement('div');
    modal.className = 'anti-cheat-modal';
    modal.innerHTML = `
      <div class="anti-cheat-card">
        <div class="anti-cheat-icon">⚠️</div>
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
          <h3 class="modal-title">🔔 Notification Center</h3>
          <button class="modal-close-btn" id="btn-close-notif-sheet">✕</button>
        </div>

        <div style="font-size:13px; color:#475569; line-height:1.5; margin-bottom:14px;">
          iOS 16.4+ Web Push sends real-time alerts directly to your iPhone lock screen when new papers are scheduled or homework is marked.
        </div>

        <button class="btn-primary" id="btn-req-push-perm" style="margin-bottom:10px;">
          Enable System Push Notifications
        </button>

        <button class="btn-primary" id="btn-send-test-push" style="background:#059669;">
          ⚡ Send Test Push Notification
        </button>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-notif-sheet')?.addEventListener('click', () => modal.remove());

    document.getElementById('btn-req-push-perm')?.addEventListener('click', async () => {
      await notificationService.requestPermission(this.currentUser);
    });

    document.getElementById('btn-send-test-push')?.addEventListener('click', () => {
      notificationService.showLocalNotification('EduPeak Exam Alert 🏛️', {
        body: '2027 A/L Physics Term Paper 01 is now active! Tap to join.',
        tag: 'exam-alert'
      });
      notificationService.showInAppBanner('Exam Alert Sent', 'Look for the system banner and audio chime.', 'info');
    });
  }

  // Live 4-box Countdown
  startCountdownTimer() {
    if (this.countdownTimer) clearInterval(this.countdownTimer);

    // 318 days, 12 hours, 17 mins, 57 secs
    const target = new Date(Date.now() + (318 * 86400000) + (12 * 3600000) + (17 * 60000) + (57 * 1000));

    const update = () => {
      const diff = target - new Date();
      if (diff <= 0) return;

      const days = Math.floor(diff / 86400000);
      const hours = Math.floor((diff % 86400000) / 3600000);
      const mins = Math.floor((diff % 3600000) / 60000);
      const secs = Math.floor((diff % 60000) / 1000);

      const d = document.getElementById('cd-days');
      const h = document.getElementById('cd-hours');
      const m = document.getElementById('cd-mins');
      const s = document.getElementById('cd-secs');

      if (d) d.textContent = days;
      if (h) h.textContent = hours;
      if (m) m.textContent = mins;
      if (s) s.textContent = secs;
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
      <!-- iOS Status Bar -->
      <div class="ios-status-bar">
        <span class="status-time" id="status-clock">10:26</span>
        <div class="status-icons">
          <span>●●●</span>
          <span>📶</span>
          <span>🔋</span>
        </div>
      </div>

      <!-- Main Scrollable Viewport -->
      <div class="main-viewport" id="admin-main-viewport" style="background:#F8FAFC; padding-bottom:80px;"></div>

      <!-- Admin Bottom Navigation Bar (1:1 with admin_shell.dart NavigationBar) -->
      <nav class="bottom-nav-bar" id="admin-bottom-nav" style="background:#FFFFFF; border-top:1px solid #E2E8F0;">
        <button class="nav-tab-btn ${this.adminTab === 'dashboard' ? 'active' : ''}" data-admin-tab="dashboard">
          <div class="nav-pill-icon">⊞</div>
          <span>Dashboard</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'papers' ? 'active' : ''}" data-admin-tab="papers">
          <div class="nav-pill-icon">📋</div>
          <span>Papers</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'sprints' ? 'active' : ''}" data-admin-tab="sprints">
          <div class="nav-pill-icon">⚡</div>
          <span>MCQ Sprints</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'students' ? 'active' : ''}" data-admin-tab="students">
          <div class="nav-pill-icon">👥</div>
          <span>Students</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'broadcasts' ? 'active' : ''}" data-admin-tab="broadcasts">
          <div class="nav-pill-icon">✈️</div>
          <span>Broadcasts</span>
        </button>
      </nav>
    `;

    this.updateClock();

    document.querySelectorAll('#admin-bottom-nav .nav-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.switchAdminTab(btn.dataset.adminTab);
      });
    });

    this.switchAdminTab(this.adminTab);
  }

  switchAdminTab(tabName) {
    this.adminTab = tabName;
    const viewport = document.getElementById('admin-main-viewport');
    if (!viewport) return;

    document.querySelectorAll('#admin-bottom-nav .nav-tab-btn').forEach(b => {
      b.classList.toggle('active', b.dataset.adminTab === tabName);
    });

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
            <div class="apk-admin-portal-badge">
              <span class="apk-pulsing-dot"></span>
              <span>Admin Portal • ${adminName}</span>
            </div>
            <div class="apk-admin-exec-actions">
              <button class="apk-btn-student-view" id="btn-admin-student-view">
                <span>🎓</span>
                <span>Student View</span>
              </button>
              <button class="apk-btn-logout-icon" id="btn-admin-logout" title="Sign Out">
                <span>🚪</span>
              </button>
            </div>
          </div>

          <!-- Greeting Row -->
          <div class="apk-admin-greeting-row">
            <div class="apk-admin-avatar">${initial}</div>
            <div class="apk-admin-greeting-text">
              <h2>Welcome back, ${adminName} 👋</h2>
              <p>${pending.length > 0 ? `${pending.length} dessert submission(s) need your review today` : 'All reviews up to date! System is running smoothly'}</p>
            </div>
          </div>
        </div>

        <!-- ── 2. Real-Time Overview Metrics Row (lines 347-394) ── -->
        <div class="apk-metrics-row">
          <div class="apk-metric-card ${this.adminFilterTab === 'pending' ? 'active-pending' : ''}" data-metric-tab="pending">
            <div class="apk-metric-icon-circle" style="background:rgba(245, 158, 11, 0.12); color:#F59E0B;">⏳</div>
            <div class="apk-metric-num" style="color:#F59E0B;">${pending.length}</div>
            <div class="apk-metric-lbl">Pending Review</div>
          </div>

          <div class="apk-metric-card ${this.adminFilterTab === 'approved' ? 'active-approved' : ''}" data-metric-tab="approved">
            <div class="apk-metric-icon-circle" style="background:rgba(16, 185, 129, 0.12); color:#10B981;">✓</div>
            <div class="apk-metric-num" style="color:#10B981;">${approved.length}</div>
            <div class="apk-metric-lbl">Approved</div>
          </div>

          <div class="apk-metric-card ${this.adminFilterTab === 'rejected' ? 'active-rejected' : ''}" data-metric-tab="rejected">
            <div class="apk-metric-icon-circle" style="background:rgba(239, 68, 68, 0.12); color:#EF4444;">⊘</div>
            <div class="apk-metric-num" style="color:#EF4444;">${rejected.length}</div>
            <div class="apk-metric-lbl">Rejected</div>
          </div>
        </div>

        <!-- ── 3. Quick Action Command Hub (lines 492-575) ── -->
        <div class="apk-command-center-box">
          <div class="apk-command-center-title">
            <span style="color:#2563EB;">⚡</span>
            <span>Admin Command Center</span>
          </div>
          <div class="apk-command-grid">
            <button class="apk-command-btn purple" id="btn-cmd-countdowns">
              <div class="apk-command-icon-box" style="background:rgba(139, 92, 246, 0.12); color:#8B5CF6;">⏱️</div>
              <div class="apk-command-info">
                <div class="title">Exam Dates ⌛</div>
                <div class="subtitle">Target count down</div>
              </div>
            </button>

            <button class="apk-command-btn blue" id="btn-cmd-papers">
              <div class="apk-command-icon-box" style="background:rgba(37, 99, 235, 0.12); color:#2563EB;">📋</div>
              <div class="apk-command-info">
                <div class="title">Paper Sessions 📝</div>
                <div class="subtitle">Live proctoring</div>
              </div>
            </button>

            <button class="apk-command-btn amber" id="btn-cmd-sprints">
              <div class="apk-command-icon-box" style="background:rgba(245, 158, 11, 0.12); color:#F59E0B;">⚡</div>
              <div class="apk-command-info">
                <div class="title">MCQ Sprints ⚡</div>
                <div class="subtitle">Rapid quiz sets</div>
              </div>
            </button>

            <button class="apk-command-btn cyan" id="btn-cmd-broadcasts">
              <div class="apk-command-icon-box" style="background:rgba(6, 182, 212, 0.12); color:#06B6D4;">✈️</div>
              <div class="apk-command-info">
                <div class="title">Broadcasts 📢</div>
                <div class="subtitle">Send telegram</div>
              </div>
            </button>
          </div>
        </div>

        <!-- ── 4. Dessert Submissions Queue Section (lines 99-178) ── -->
        <div class="apk-queue-section">
          <div class="apk-queue-header-row">
            <div class="apk-queue-title">
              <span style="color:#2563EB; font-size:18px;">☑️</span>
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
            <span class="apk-search-icon">🔍</span>
          </div>

          <!-- Submissions List or Empty State -->
          ${currentList.length === 0 ? `
            <div class="apk-empty-card">
              <div class="apk-empty-icon-circle">✓</div>
              <div class="apk-empty-title">All Caught Up! 🎉</div>
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
                      ${d.status === 'approved' ? 'Approved ✓' : d.status === 'rejected' ? 'Needs Redo ⚠️' : 'Pending Review ⏳'}
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
                    <button class="apk-btn-primary" data-review-id="${d.id}" style="padding:6px 14px; font-size:11.5px;">Review & Grade ➔</button>
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
          <button class="modal-close-btn" id="btn-close-review">✕</button>
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
            <button class="history-filter-chip" data-preset="Great work! Free-body diagram is crystal clear. ✅">
              🌟 Great Work
            </button>
            <button class="history-filter-chip" data-preset="Calculation is correct, but add units to the final answer. ⚠️">
              📏 Missing Units
            </button>
            <button class="history-filter-chip" data-preset="Sign error in force components on line 3. Please revise. ❌">
              📐 Sign Error
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
          <button class="btn-primary" id="btn-admin-reject-sub" style="background:#EF4444; flex:1; padding:12px;">
            ❌ Request Redo
          </button>
          <button class="btn-primary" id="btn-admin-approve-sub" style="background:#10B981; flex:1.3; padding:12px;">
            ✅ Approve (+${credits} XP)
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
        if (approveBtn) approveBtn.textContent = `✅ Approve (+${credits} XP)`;
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
      const fb = document.getElementById('admin-feedback-text')?.value || 'Great work! ✅';
      await dbService.reviewDessert(sub.id, {
        status: 'approved',
        adminFeedback: fb,
        creditsAwarded: credits,
        reviewedBy: 'Lead Physics Faculty'
      });
      notificationService.showInAppBanner('Submission Approved! ✅', `Awarded +${credits} XP to ${sub.studentName}.`, 'success');
      modal.remove();
      const vp = document.getElementById('admin-main-viewport');
      if (vp) this.renderAdminDashboardScreen(vp);
    });

    document.getElementById('btn-admin-reject-sub')?.addEventListener('click', async () => {
      const fb = document.getElementById('admin-feedback-text')?.value || 'Needs improvement. Please try again. ❌';
      await dbService.reviewDessert(sub.id, {
        status: 'rejected',
        adminFeedback: fb,
        creditsAwarded: 10,
        reviewedBy: 'Lead Physics Faculty'
      });
      notificationService.showInAppBanner('Revision Requested ⚠️', `Sent correction notes to ${sub.studentName}.`, 'warning');
      modal.remove();
      const vp = document.getElementById('admin-main-viewport');
      if (vp) this.renderAdminDashboardScreen(vp);
    });
  }

  // 2. Admin Papers Screen (admin_paper_sessions_screen.dart)
  async renderAdminPapersScreen(container) {
    this.adminPaperTab = this.adminPaperTab ?? 0; // 0: Live Sessions, 1: Upcoming Papers, 2: Leaderboard
    const papers = await dbService.getPaperSessions();

    const subtitle = this.adminPaperTab === 0
      ? 'සජීවී විභාග සැසි සහ කැමරා අධීක්ෂණය'
      : (this.adminPaperTab === 1 ? 'ඉදිරි විභාග සහ Hints කළමනාකරණය' : 'Paper ප්‍රතිඵල සහ Leaderboard නිර්මාණය');

    container.innerHTML = `
      <!-- Screen AppBar -->
      <div class="apk-screen-appbar">
        <div class="apk-appbar-left">
          <div class="apk-appbar-icon-box">
            <span style="font-size:18px;">☑️</span>
          </div>
          <div>
            <div class="apk-appbar-title">Paper Examination Hub</div>
            <div class="apk-appbar-subtitle">${subtitle}</div>
          </div>
        </div>
        <div class="apk-appbar-actions">
          <button class="apk-icon-action-btn" id="btn-admin-countdowns" title="A/L Exam Target Dates & Countdowns">⏱️</button>
          <button class="apk-icon-action-btn" id="btn-admin-add-paper-head" title="Create" style="font-size:22px; color:#2563EB;">⊕</button>
        </div>
      </div>

      <!-- Segmented 3-Tab Selector -->
      <div style="padding:12px 16px 8px;">
        <div style="background:#FFFFFF; border-radius:16px; padding:4px; border:1px solid #E2E8F0; display:flex; box-shadow:0 2px 8px rgba(15,23,42,0.04);">
          <button class="apk-segmented-tab-btn ${this.adminPaperTab === 0 ? 'active' : ''}" data-paper-tab="0" style="${this.adminPaperTab === 0 ? 'background:#2563EB; color:#FFFFFF;' : ''}">
            🔴 Live Sessions
          </button>
          <button class="apk-segmented-tab-btn ${this.adminPaperTab === 1 ? 'active' : ''}" data-paper-tab="1" style="${this.adminPaperTab === 1 ? 'background:#2563EB; color:#FFFFFF;' : ''}">
            🔮 Upcoming Papers
          </button>
          <button class="apk-segmented-tab-btn ${this.adminPaperTab === 2 ? 'active' : ''}" data-paper-tab="2" style="${this.adminPaperTab === 2 ? 'background:#2563EB; color:#FFFFFF;' : ''}">
            🏆 Leaderboard
          </button>
        </div>
      </div>

      <!-- Tab Viewport -->
      <div id="admin-papers-content" style="padding:0 16px 90px;">
        ${this.adminPaperTab === 0 ? this._buildAdminLiveSessionsHTML(papers) : ''}
        ${this.adminPaperTab === 1 ? this._buildAdminUpcomingPapersHTML() : ''}
        ${this.adminPaperTab === 2 ? this._buildAdminPaperLeaderboardHTML() : ''}
      </div>

      <!-- FAB (Floating Action Button) -->
      <button class="apk-fab-button" id="btn-fab-admin-paper">
        <span style="font-size:18px;">+</span> ${this.adminPaperTab === 0 ? 'Add Live Session' : (this.adminPaperTab === 1 ? 'Add Upcoming Paper' : 'Create Leaderboard')}
      </button>
    `;

    // Tab switcher events
    container.querySelectorAll('[data-paper-tab]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.adminPaperTab = Number(btn.dataset.paperTab);
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

    // Interactive paper action handlers
    container.querySelectorAll('[data-toggle-paper]').forEach(btn => {
      btn.addEventListener('click', () => {
        const p = papers.find(x => x.id === btn.dataset.togglePaper);
        if (p) {
          p.isLive = !p.isLive;
          notificationService.showInAppBanner('Paper Status Updated', `${p.title} is now ${p.isLive ? 'LIVE' : 'ENDED'}.`, 'info');
          this.renderAdminPapersScreen(container);
        }
      });
    });

    container.querySelectorAll('[data-view-proctor]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.openExamRoom(btn.dataset.viewProctor);
      });
    });
  }

  _buildAdminLiveSessionsHTML(papers) {
    if (!papers || papers.length === 0) {
      return `
        <div style="padding:60px 20px 20px; text-align:center; display:flex; flex-direction:column; align-items:center;">
          <div style="width:76px; height:76px; border-radius:50%; background:#F8FAFC; border:1px solid #E2E8F0; display:flex; align-items:center; justify-content:center; color:#2563EB; font-size:36px; margin-bottom:18px;">
            📄⁺
          </div>
          <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:8px;">
            තවම Paper Sessions නිර්මාණය කර නොමැත
          </div>
          <div style="font-size:13px; color:#64748B; max-width:320px; line-height:1.45; margin-bottom:24px;">
            නව විභාග සැසියක් නිර්මාණය කර Slot 1 සහ Slot 2 වේලාවන් සකසන්න.
          </div>
          <button class="apk-btn-primary" id="btn-empty-create-paper" style="display:inline-flex; align-items:center; gap:8px; padding:12px 22px; border-radius:12px;">
            <span style="font-size:16px;">+</span> Create First Paper Session
          </button>
        </div>
      `;
    }

    return `
      <div style="display:flex; flex-direction:column; gap:12px; margin-top:12px;">
        ${papers.map(p => `
          <div class="hero-card" style="padding:16px;">
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <span class="phase-pill ${p.isLive ? 'phase-live' : 'phase-upcoming'}">
                ${p.isLive ? '🔴 Writing in Progress' : '⏰ Scheduled'}
              </span>
              <span style="font-size:12px; font-weight:800; color:#2563EB;">⏱️ ${p.durationMinutes} Mins</span>
            </div>

            <div style="font-size:15px; font-weight:800; color:#0F172A; margin-top:8px;">${p.title}</div>
            <div style="font-size:12px; color:#64748B; margin-top:2px;">${p.subject}</div>

            <div style="display:flex; gap:8px; margin-top:14px;">
              <button class="apk-btn-primary" style="flex:1; background:${p.isLive ? '#EF4444' : '#10B981'}; padding:10px; font-size:12px;" data-toggle-paper="${p.id}">
                ${p.isLive ? '⏹ End Live Session' : '▶ Start Live Writing'}
              </button>
              <button class="apk-btn-primary" style="background:#F1F5F9; color:#334155; width:auto; padding:10px 14px; font-size:12px; box-shadow:none;" data-view-proctor="${p.id}">
                🎥 Proctor Hall
              </button>
            </div>
          </div>
        `).join('')}
      </div>
    `;
  }

  _buildAdminUpcomingPapersHTML() {
    return `
      <div style="padding:60px 20px; text-align:center; display:flex; flex-direction:column; align-items:center;">
        <div style="font-size:44px; margin-bottom:12px;">🔮</div>
        <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:6px;">No Upcoming Papers Scheduled</div>
        <div style="font-size:13px; color:#64748B; max-width:300px; line-height:1.4;">Add future exam dates with study hints so students can prepare ahead.</div>
      </div>
    `;
  }

  _buildAdminPaperLeaderboardHTML() {
    return `
      <div style="padding:60px 20px; text-align:center; display:flex; flex-direction:column; align-items:center;">
        <div style="font-size:44px; margin-bottom:12px;">🏆</div>
        <div style="font-size:16px; font-weight:800; color:#0F172A; margin-bottom:6px;">No Published Leaderboards Yet</div>
        <div style="font-size:13px; color:#64748B; max-width:300px; line-height:1.4;">Publish marks and ranks after paper corrections are completed.</div>
      </div>
    `;
  }

  // 3. Admin Sprints Screen (admin_mcq_sprint_screen.dart)
  renderAdminSprintsScreen(container) {
    this.adminSprintTab = this.adminSprintTab ?? 0; // 0: Sprint Sets, 1: Live Leaderboard
    this.adminSprintDate = this.adminSprintDate || new Date().toISOString().split('T')[0];
    this.customSprints = this.customSprints || [];

    const dateStr = this.adminSprintDate;

    container.innerHTML = `
      <!-- Screen AppBar -->
      <div class="apk-screen-appbar">
        <div class="apk-appbar-left">
          <div style="font-size:16px; font-weight:800; color:#0F172A; display:flex; align-items:center; gap:6px;">
            <span>🔥</span> Daily MCQ Sprints
          </div>
        </div>
        <div class="apk-appbar-actions">
          <button class="apk-icon-action-btn" id="btn-pick-sprint-date" title="Pick Date">📅</button>
        </div>
      </div>

      <!-- Underline Tabs -->
      <div class="apk-tabbar-underline">
        <button class="apk-tabbar-tab ${this.adminSprintTab === 0 ? 'active' : ''}" data-sprint-tab="0">
          <span>❓</span> Sprint Sets (දවසේ 5)
        </button>
        <button class="apk-tabbar-tab ${this.adminSprintTab === 1 ? 'active' : ''}" data-sprint-tab="1">
          <span>📊</span> Live Leaderboard
        </button>
      </div>

      <!-- Tab Content Area -->
      <div id="admin-sprint-content" style="padding-bottom:90px;">
        ${this.adminSprintTab === 0 ? this._buildAdminSprintsTabHTML(dateStr) : this._buildAdminSprintLeaderboardHTML(dateStr)}
      </div>

      <!-- FAB -->
      <button class="apk-fab-button" id="btn-fab-create-sprint">
        <span style="font-size:18px;">+</span> Create 5-MCQ Sprint
      </button>
    `;

    // Tab Switcher
    container.querySelectorAll('[data-sprint-tab]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.adminSprintTab = Number(btn.dataset.sprintTab);
        this.renderAdminSprintsScreen(container);
      });
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

    // Load Demo Sprint
    document.getElementById('btn-load-demo-sprint')?.addEventListener('click', () => {
      this.customSprints.push({
        id: 'sprint_demo_' + Date.now(),
        title: 'A/L Mechanics High-Yield Sprint',
        subject: 'Physics',
        targetDate: this.adminSprintDate,
        examYear: '2026 A/L',
        questionsCount: 5
      });
      notificationService.showInAppBanner('Demo Sprint Loaded! ⚡', 'Physics Mechanics 5-MCQ Set is ready.', 'success');
      this.renderAdminSprintsScreen(container);
    });

    // Create Sprint FAB
    document.getElementById('btn-fab-create-sprint')?.addEventListener('click', () => {
      this.openCreateSprintSheet();
    });
  }

  _buildAdminSprintsTabHTML(dateStr) {
    const sprintsForDate = this.customSprints.filter(s => s.targetDate === dateStr);

    return `
      <!-- Date Filter Bar -->
      <div style="margin:16px 16px 14px; padding:12px 16px; background:#FFFFFF; border-radius:14px; border:1px solid #E2E8F0; display:flex; justify-content:space-between; align-items:center; box-shadow:0 1px 3px rgba(0,0,0,0.03);">
        <div style="display:flex; align-items:center; gap:8px;">
          <span style="font-size:16px; color:#2563EB;">📅</span>
          <span style="font-size:13.5px; font-weight:700; color:#0F172A;">Viewing: ${dateStr}</span>
        </div>
        <button id="btn-change-sprint-date" style="background:none; border:none; color:#2563EB; font-weight:700; font-size:12.5px; cursor:pointer; display:flex; align-items:center; gap:4px;">
          <span>📅</span> Change
        </button>
      </div>

      <!-- Sprints Content -->
      ${sprintsForDate.length === 0 ? `
        <!-- Empty State matching Screenshot 3 -->
        <div style="margin:0 16px; padding:28px 20px; background:#FFFFFF; border-radius:16px; border:1px solid #E2E8F0; text-align:center; display:flex; flex-direction:column; align-items:center; gap:10px; box-shadow:0 1px 3px rgba(0,0,0,0.02);">
          <div style="font-size:44px;">📝</div>
          <div style="font-size:15.5px; font-weight:800; color:#0F172A;">No Custom MCQ Sprints Created Yet</div>
          <div style="font-size:12.5px; color:#64748B; max-width:320px; line-height:1.45;">
            Telegram bot is currently using the high-yield A/L Mechanics fallback set. Create custom daily 5-MCQ sets below!
          </div>
          <button class="apk-btn-primary" id="btn-load-demo-sprint" style="margin-top:8px; display:inline-flex; align-items:center; gap:6px;">
            <span>⚡</span> Load Demo A/L Physics Sprint Set
          </button>
        </div>
      ` : `
        <div style="display:flex; flex-direction:column; gap:12px; padding:0 16px;">
          ${sprintsForDate.map(s => `
            <div class="hero-card" style="padding:16px; border: 1.5px solid #2563EB; background: rgba(37,99,235,0.04);">
              <div style="display:flex; justify-content:space-between; align-items:center;">
                <span style="font-size:12px; font-weight:800; color:#2563EB;">🔥 ${s.examYear}</span>
                <span style="font-size:11px; background:#DCFCE7; color:#166534; padding:2px 8px; border-radius:10px; font-weight:800;">5 Questions Ready</span>
              </div>
              <div style="font-size:15px; font-weight:800; color:#0F172A; margin-top:6px;">${s.title}</div>
              <div style="font-size:12px; color:#64748B; margin-top:2px;">Target: ${s.targetDate} • ${s.subject}</div>
            </div>
          `).join('')}
        </div>
      `}
    `;
  }

  _buildAdminSprintLeaderboardHTML(dateStr) {
    return `
      <!-- Empty Leaderboard matching Screenshot 4 -->
      <div style="padding:80px 20px; text-align:center; display:flex; flex-direction:column; align-items:center; gap:10px;">
        <div style="font-size:44px;">🏆</div>
        <div style="font-size:16px; font-weight:800; color:#0F172A;">No completions for ${dateStr} yet</div>
        <div style="font-size:13px; color:#64748B; max-width:320px; line-height:1.45;">
          Students who complete the Sprint on Telegram will appear here live!
        </div>
      </div>
    `;
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
          <div style="font-size:16px; font-weight:800; color:#0F172A;">
            Registered Students 👥
          </div>
        </div>
      </div>

      <!-- Summary Stats & Search Header matching Screenshot 5 -->
      <div style="background:#FFFFFF; padding:12px 16px 14px; border-bottom:1px solid #E2E8F0;">
        <!-- Stats Row -->
        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-bottom:12px;">
          <div style="background:#F1F5F9; border-radius:12px; padding:10px 14px; display:flex; align-items:center; gap:10px;">
            <span style="font-size:18px; color:#2563EB;">👥</span>
            <div>
              <div style="font-size:10.5px; color:#64748B; font-weight:600;">Total Students</div>
              <div style="font-size:16px; font-weight:800; color:#0F172A;">${allStudents.length}</div>
            </div>
          </div>
          <div style="background:#F1F5F9; border-radius:12px; padding:10px 14px; display:flex; align-items:center; gap:10px;">
            <span style="font-size:18px; color:#6366F1;">⚡</span>
            <div>
              <div style="font-size:10.5px; color:#64748B; font-weight:600;">Showing</div>
              <div style="font-size:16px; font-weight:800; color:#0F172A;">${filtered.length}</div>
            </div>
          </div>
        </div>

        <!-- Search Field -->
        <div class="apk-search-bar" style="margin-bottom:10px;">
          <span class="apk-search-icon">🔍</span>
          <input type="text" id="input-admin-student-search" placeholder="Search by name, phone or ID..." value="${this.adminStudentSearchQuery}">
        </div>

        <!-- Batch Filter Chips -->
        <div class="apk-chips-scroll-row">
          ${batches.map(b => {
            const isSel = this.adminStudentBatchFilter === b;
            return `
              <button class="apk-filter-chip ${isSel ? 'active' : ''}" data-batch="${b}">
                ${isSel ? '✓ ' : ''}${b}
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
            <div style="font-size:44px;">🔍</div>
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
                    ✉️
                  </button>
                  <button class="apk-icon-action-btn" title="Delete Account" data-delete-student="${st.id}" style="color:#EF4444; font-size:16px;">
                    🗑️
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
            <span>📢</span> Push Broadcaster & Telegram
          </div>
        </div>
      </div>

      <div style="padding:16px 16px 90px;">
        <div class="hero-card" style="padding:16px;">
          <div class="form-label">Announcement Title:</div>
          <input type="text" id="bc-title" class="form-textarea" style="height:40px; margin-bottom:10px;" placeholder="e.g. 🔴 Paper 04 Live Exam Started!" />

          <div class="form-label">Notification Message Body:</div>
          <textarea id="bc-body" class="form-textarea" rows="3" style="margin-bottom:10px;" placeholder="Enter message to broadcast to all student home screens & Telegram..."></textarea>

          <div class="form-label">Target Audience:</div>
          <select id="bc-audience" class="form-textarea" style="height:40px; margin-bottom:14px; padding:6px 10px;">
            <option value="All Batches">All Enrolled Batches</option>
            <option value="2026 A/L">2026 A/L Batch Only</option>
            <option value="2027 A/L">2027 A/L Batch Only</option>
          </select>

          <button class="apk-btn-primary" id="btn-send-broadcast" style="width:100%; padding:14px; font-size:14px;">
            🚀 Send Instant Broadcast
          </button>
        </div>

        <div style="font-size:13.5px; font-weight:800; color:#0F172A; margin:18px 0 10px;">
          📜 Recent Broadcasts Sent:
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

      alert('🚀 Broadcast successfully dispatched to all student devices via Web Push and Telegram!');
      this.renderAdminBroadcastsScreen(container);
    });
  }

  // ── Helper Modal Dialogs ───────────────────────────────────────────────
  openExamCountdownsModal() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    modal.innerHTML = `
      <div class="modal-sheet" style="max-height:85vh; overflow-y:auto;">
        <div class="modal-header">
          <div style="display:flex; align-items:center; gap:8px;">
            <span style="font-size:20px;">⏱️</span>
            <div>
              <div style="font-size:15px; font-weight:800; color:#0F172A;">A/L Exam Target Dates</div>
              <div style="font-size:11px; color:#64748B;">Official countdowns to national examination</div>
            </div>
          </div>
          <button class="modal-close-btn" id="btn-close-countdown">✕</button>
        </div>

        <div style="display:flex; flex-direction:column; gap:12px; margin-top:12px;">
          <div class="hero-card" style="padding:16px; border:1px solid #DBEAFE; background:#EFF6FF;">
            <div style="font-size:12px; font-weight:800; color:#2563EB;">2026 G.C.E. A/L EXAMINATION</div>
            <div style="font-size:18px; font-weight:900; color:#1E3A8A; margin-top:4px;">November 2026</div>
            <div style="font-size:12px; color:#3B82F6; margin-top:2px;">Target date countdown active for all registered 2026 students.</div>
          </div>

          <div class="hero-card" style="padding:16px; border:1px solid #E0E7FF; background:#EEF2FF;">
            <div style="font-size:12px; font-weight:800; color:#4F46E5;">2027 G.C.E. A/L EXAMINATION</div>
            <div style="font-size:18px; font-weight:900; color:#312E81; margin-top:4px;">November 2027</div>
            <div style="font-size:12px; color:#6366F1; margin-top:2px;">Target date countdown active for 2027 batch.</div>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-countdown')?.addEventListener('click', () => modal.remove());
  }

  openAdminCreatePaperModal() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    modal.innerHTML = `
      <div class="modal-sheet" style="max-height:88vh; overflow-y:auto;">
        <div class="modal-header">
          <div style="font-size:16px; font-weight:800; color:#0F172A;">Create Paper Session</div>
          <button class="modal-close-btn" id="btn-close-new-paper">✕</button>
        </div>

        <div style="display:flex; flex-direction:column; gap:12px; margin-top:8px;">
          <div>
            <div class="form-label">Paper Title:</div>
            <input type="text" id="new-paper-title" class="form-textarea" style="height:40px;" placeholder="e.g. 2026 A/L Physics Model Paper 04" />
          </div>

          <div>
            <div class="form-label">Units / Syllabus Covered:</div>
            <input type="text" id="new-paper-units" class="form-textarea" style="height:40px;" placeholder="e.g. Mechanics, Oscillations & Waves" />
          </div>

          <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px;">
            <div>
              <div class="form-label">Duration (Mins):</div>
              <input type="number" id="new-paper-duration" class="form-textarea" style="height:40px;" value="120" />
            </div>
            <div>
              <div class="form-label">Total Marks:</div>
              <input type="number" id="new-paper-marks" class="form-textarea" style="height:40px;" value="100" />
            </div>
          </div>

          <div>
            <div class="form-label">Exam Slots (Slot 1 & Slot 2):</div>
            <div style="background:#F8FAFC; border:1px solid #E2E8F0; border-radius:10px; padding:10px; font-size:12px; color:#475569;">
              <div>• <strong>Slot 1:</strong> 08:30 AM - 10:30 AM (50 Seats)</div>
              <div style="margin-top:4px;">• <strong>Slot 2:</strong> 04:00 PM - 06:00 PM (50 Seats)</div>
            </div>
          </div>

          <button class="apk-btn-primary" id="btn-save-new-paper" style="margin-top:10px; padding:14px; font-size:14px;">
            🚀 Publish Paper Session to Students
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-new-paper')?.addEventListener('click', () => modal.remove());

    document.getElementById('btn-save-new-paper')?.addEventListener('click', async () => {
      const title = document.getElementById('new-paper-title')?.value;
      const subject = document.getElementById('new-paper-units')?.value;
      const duration = Number(document.getElementById('new-paper-duration')?.value) || 120;
      const marks = Number(document.getElementById('new-paper-marks')?.value) || 100;

      if (!title) {
        alert('Please enter a paper title.');
        return;
      }

      await dbService.savePaperSession({
        title,
        subject: subject || 'A/L Physics',
        durationMinutes: duration,
        totalMarks: marks,
        isLive: true,
        proctoringRequired: true,
        slots: [
          { id: 'slot_1', name: 'Morning (08:30 AM)', seatsLeft: 50 },
          { id: 'slot_2', name: 'Evening (04:00 PM)', seatsLeft: 50 }
        ]
      });

      notificationService.showInAppBanner('Paper Created! 📋', `${title} published to student portal.`, 'success');
      modal.remove();
      const vp = document.getElementById('admin-main-viewport');
      if (vp) this.renderAdminPapersScreen(vp);
    });
  }

  openCreateSprintSheet() {
    const title = prompt('Enter Sprint Title:', 'Daily 5-MCQ Sprint (A/L Physics)');
    if (!title) return;

    this.customSprints.push({
      id: 'sprint_' + Date.now(),
      title,
      subject: 'Physics',
      targetDate: this.adminSprintDate,
      examYear: '2026 A/L',
      questionsCount: 5
    });

    notificationService.showInAppBanner('Sprint Created! ⚡', `${title} scheduled for ${this.adminSprintDate}.`, 'success');
    const vp = document.getElementById('admin-main-viewport');
    if (vp) this.renderAdminSprintsScreen(vp);
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
          <button class="modal-close-btn" id="btn-close-msg-dialog">✕</button>
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

          <button class="apk-btn-primary" id="btn-send-cust-msg" style="padding:12px;">
            📨 Send to Student via Telegram
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

      notificationService.showInAppBanner('Message Delivered! 📨', `Delivered to ${student.name} on Telegram.`, 'success');
      modal.remove();
    });
  }

  confirmDeleteStudent(student) {
    if (!confirm(`Are you sure you want to permanently delete the account of ${student.name} (${student.phone})? This will purge all associated submissions and records.`)) {
      return;
    }

    dbService.deleteStudent(student.id);
    notificationService.showInAppBanner('Account Purged 🗑️', `All data for ${student.name} removed.`, 'warning');
    const vp = document.getElementById('admin-main-viewport');
    if (vp) this.renderAdminStudentsScreen(vp);
  }
}

window.addEventListener('DOMContentLoaded', () => {
  const app = new AppController();
  window.app = app;
  app.init();
});
