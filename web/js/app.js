// EduPeak App Main Controller
// Orchestrates PWA Gatekeeper, Firebase Sync, Camera Document Scanner, Web Push, and Exam Hall
import { authService } from './auth-service.js';
import { dbService } from './db-service.js';
import { notificationService } from './notification-service.js';
import { cameraService } from './camera-service.js';
import { PwaGatekeeper } from './pwa-gatekeeper.js';

class AppController {
  constructor() {
    this.currentTab = 'home';
    this.theme = localStorage.getItem('edupeak_theme') || 'dark';
    this.currentUser = null;
    this.currentDesserts = [];
    this.activeExamTimer = null;
    this.activeSprintTimer = null;
    this.antiCheatViolations = 0;
  }

  init() {
    document.documentElement.setAttribute('data-theme', this.theme);

    // 1. Initialize PWA Gatekeeper (Enforces iOS Home Screen Standalone installation)
    const gatekeeper = new PwaGatekeeper({
      onUnlocked: () => {
        console.log('[App] PWA Unlocked via Standalone Mode / Dev Bypass');
        this.startApplication();
      }
    });

    gatekeeper.init();
  }

  startApplication() {
    // 2. Listen to Auth State
    authService.onAuthStateChanged((user) => {
      this.currentUser = user;
      if (!user) {
        this.renderAuthModal();
      } else {
        this.closeAuthModal();
        this.renderAppShell();
        this.switchTab('home');

        // Initialize Push Notifications once user is active
        notificationService.init(user);
      }
    });

    // 3. Register Service Worker for PWA & Web Push
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('./sw.js').then((reg) => {
        console.log('[App] Service Worker Registered:', reg.scope);
      }).catch((err) => {
        console.warn('[App] SW registration notice:', err);
      });
    }

    // 4. Global Anti-Cheat Listener when in Live Exam Room
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden' && this.isInsideLiveExam) {
        this.handleExamTabSwitch();
      }
    });
  }

  // ── Tab Navigation ────────────────────────────────────────────────────────
  switchTab(tabName) {
    this.currentTab = tabName;
    const container = document.getElementById('main-viewport');
    if (!container) return;

    // Update bottom nav active indicators
    document.querySelectorAll('.nav-item').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });

    switch (tabName) {
      case 'home':
        this.renderHomeScreen(container);
        break;
      case 'papers':
        this.renderPapersScreen(container);
        break;
      case 'sprint':
        this.renderSprintScreen(container);
        break;
      case 'leaderboard':
        this.renderLeaderboardScreen(container);
        break;
      case 'profile':
        this.renderProfileScreen(container);
        break;
      case 'admin':
        this.renderAdminScreen(container);
        break;
      default:
        this.renderHomeScreen(container);
    }

    // Scroll to top
    container.scrollTo({ top: 0, behavior: 'smooth' });
  }

  // ── Render Master App Shell ───────────────────────────────────────────────
  renderAppShell() {
    const root = document.getElementById('app-root');
    if (!root) return;

    const user = this.currentUser || {};
    const displayName = user.name || 'Scholar';
    const avatarInitial = displayName.charAt(0).toUpperCase();

    root.innerHTML = `
      <!-- Ambient Lighting -->
      <div class="bg-ambient-layer">
        <div class="ambient-orb orb-1"></div>
        <div class="ambient-orb orb-2"></div>
      </div>

      <!-- Top Sticky App Bar -->
      <header class="top-app-bar">
        <div class="top-profile-col" id="btn-header-profile">
          <div class="top-avatar">
            ${user.avatarUrl ? `<img src="${user.avatarUrl}" alt="${displayName}"/>` : `<div class="top-avatar-fallback">${avatarInitial}</div>`}
          </div>
          <div class="top-user-info">
            <span class="top-greeting">${this.getGreeting()}</span>
            <span class="top-username">${displayName}</span>
          </div>
        </div>

        <div class="top-actions-col">
          <div class="streak-pill">
            <span class="flame-icon">🔥</span>
            <span>14d</span>
          </div>
          <button class="btn-notif-bell" id="btn-open-notifs" title="Notification Center">
            🔔
            <span class="notif-badge-dot"></span>
          </button>
        </div>
      </header>

      <!-- Main Scrollable Screen Viewport -->
      <main class="main-content" id="main-viewport"></main>

      <!-- Bottom iOS Navigation Bar -->
      <nav class="bottom-nav-bar">
        <button class="nav-item active" data-tab="home">
          <span class="nav-icon">🏠</span>
          <span class="nav-label">Cockpit</span>
          <span class="nav-active-dot"></span>
        </button>
        <button class="nav-item" data-tab="papers">
          <span class="nav-icon">🏛️</span>
          <span class="nav-label">Exam Hall</span>
          <span class="nav-active-dot"></span>
        </button>
        <button class="nav-item" data-tab="sprint">
          <span class="nav-icon">⚡</span>
          <span class="nav-label">Sprint</span>
          <span class="nav-active-dot"></span>
        </button>
        <button class="nav-item" data-tab="leaderboard">
          <span class="nav-icon">🏆</span>
          <span class="nav-label">Ranks</span>
          <span class="nav-active-dot"></span>
        </button>
        <button class="nav-item" data-tab="profile">
          <span class="nav-icon">👤</span>
          <span class="nav-label">Profile</span>
          <span class="nav-active-dot"></span>
        </button>
      </nav>
    `;

    // Attach Nav Click Listeners
    document.querySelectorAll('.nav-item').forEach(btn => {
      btn.addEventListener('click', () => {
        this.switchTab(btn.dataset.tab);
      });
    });

    document.getElementById('btn-header-profile')?.addEventListener('click', () => {
      this.switchTab('profile');
    });

    document.getElementById('btn-open-notifs')?.addEventListener('click', () => {
      this.openNotificationCenter();
    });
  }

  // ── 1. Student Cockpit Screen (Home) ──────────────────────────────────────
  async renderHomeScreen(container) {
    const user = this.currentUser || {};
    const insight = dbService.getDailyInsight();

    container.innerHTML = `
      <!-- Daily Physics Insight Card -->
      <section class="insight-card">
        <div class="insight-header">
          <span class="insight-badge">⚛️ Daily Physics Insight</span>
          <span style="font-size: 11px; color: var(--text-muted); font-weight:700;">#A/L CONCEPT</span>
        </div>
        <h2 class="insight-title">${insight.concept}</h2>
        <div class="formula-box">${insight.formula}</div>
        <p class="insight-desc">${insight.summary}</p>
        <div class="insight-exam-tip">
          <strong>💡 Exam Strategy:</strong> ${insight.examTip}
        </div>
      </section>

      <!-- Exam Countdown Banner -->
      <section class="countdown-banner">
        <div class="countdown-info">
          <span class="countdown-exam-title">2026 A/L Physics Exam</span>
          <span class="countdown-exam-sub">National Examination Countdown</span>
        </div>
        <div class="countdown-digits-row" id="home-countdown-digits">
          <div class="timer-digit-box">
            <span class="digit-val" id="cd-days">42</span>
            <span class="digit-label">Days</span>
          </div>
          <div class="timer-digit-box">
            <span class="digit-val" id="cd-hours">14</span>
            <span class="digit-label">Hours</span>
          </div>
          <div class="timer-digit-box">
            <span class="digit-val" id="cd-mins">28</span>
            <span class="digit-label">Mins</span>
          </div>
        </div>
      </section>

      <!-- Quick Action Hub -->
      <section class="quick-action-grid">
        <div class="action-card" id="btn-action-camera">
          <div class="action-icon-circle camera">📷</div>
          <span class="action-label">Submit Dessert</span>
        </div>
        <div class="action-card" id="btn-action-exam">
          <div class="action-icon-circle exam">🏛️</div>
          <span class="action-label">Exam Hall</span>
        </div>
        <div class="action-card" id="btn-action-sprint">
          <div class="action-icon-circle sprint">⚡</div>
          <span class="action-label">MCQ Sprint</span>
        </div>
        <div class="action-card" id="btn-action-leaderboard">
          <div class="action-icon-circle trophy">🏆</div>
          <span class="action-label">Leaderboard</span>
        </div>
      </section>

      <!-- Live Scheduled Exam Banner -->
      <section class="live-exam-banner">
        <div class="live-badge-row">
          <div class="live-pill">
            <span class="live-dot"></span>
            <span>LIVE EXAM SESSION</span>
          </div>
          <span style="font-size: 11px; color: #60A5FA; font-weight:700;">120 MINS • 100 MARKS</span>
        </div>
        <div class="live-banner-title">2026 Island-Wide Physics Model Paper 04</div>
        <div class="live-banner-sub">Mechanics, Thermal Physics, Light & Oscillations</div>
        <button class="btn-enter-exam" id="btn-join-live-exam">
          <span>📹 Enter Proctor Exam Hall</span>
          <span>→</span>
        </button>
      </section>

      <!-- Homework Submissions Section -->
      <section>
        <div class="section-header">
          <span class="section-title">
            <span>📝</span> Recent Desserts
          </span>
          <span class="section-count" id="dessert-count-label">Loading...</span>
        </div>

        <div class="dessert-cards-list" id="home-dessert-list" style="margin-top: 10px;">
          <div style="text-align:center; padding: 20px; color: var(--text-muted); font-size:13px;">
            Loading your homework submissions...
          </div>
        </div>
      </section>
    `;

    // Start Live Clock Countdown
    this.startCountdownTimer();

    // Attach Quick Action Listeners
    document.getElementById('btn-action-camera')?.addEventListener('click', () => {
      this.openDocumentScanner();
    });

    document.getElementById('btn-action-exam')?.addEventListener('click', () => {
      this.switchTab('papers');
    });

    document.getElementById('btn-action-sprint')?.addEventListener('click', () => {
      this.switchTab('sprint');
    });

    document.getElementById('btn-action-leaderboard')?.addEventListener('click', () => {
      this.switchTab('leaderboard');
    });

    document.getElementById('btn-join-live-exam')?.addEventListener('click', () => {
      this.openLiveExamRoom('paper_001');
    });

    // Listen to Real-time Desserts
    dbService.listenToStudentDesserts(user.uid, user.phone, (desserts) => {
      this.currentDesserts = desserts;
      this.renderDessertCards(desserts);
    });
  }

  renderDessertCards(desserts) {
    const listEl = document.getElementById('home-dessert-list');
    const countEl = document.getElementById('dessert-count-label');
    if (!listEl) return;

    if (countEl) countEl.textContent = `${desserts.length} Submissions`;

    if (!desserts || desserts.length === 0) {
      listEl.innerHTML = `
        <div style="text-align:center; padding: 30px 20px; background: var(--bg-card); border-radius: 18px; border: 1px dashed var(--border-main);">
          <div style="font-size: 32px; margin-bottom: 8px;">📚</div>
          <div style="font-size: 14px; font-weight:700; color: var(--text-main);">No Homework Submitted Yet</div>
          <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px; margin-bottom: 14px;">
            Tap 'Submit Dessert' to scan your homework pages with the rear camera!
          </div>
          <button class="btn-primary" style="max-width: 200px; margin: 0 auto; padding: 10px;" id="btn-empty-scan">
            📷 Scan Now
          </button>
        </div>
      `;
      document.getElementById('btn-empty-scan')?.addEventListener('click', () => this.openDocumentScanner());
      return;
    }

    listEl.innerHTML = desserts.map(d => {
      const isApproved = d.status === 'approved';
      const isPending = d.status === 'pending';
      const statusClass = isApproved ? 'status-approved' : isPending ? 'status-pending' : 'status-rejected';
      const statusLabel = isApproved ? 'Approved' : isPending ? 'In Review' : 'Needs Redo';
      const thumb = d.mediaUrls && d.mediaUrls[0] ? `<img src="${d.mediaUrls[0]}" alt="Scan"/>` : '📄';

      return `
        <div class="dessert-card" data-id="${d.id}">
          <div class="dessert-thumb">${thumb}</div>
          <div class="dessert-info">
            <div class="dessert-subject">${d.subject || 'Physics Homework'}</div>
            <div class="dessert-date">${new Date(d.submittedAt).toLocaleDateString()} • ${d.creditsAwarded || 0} Credits</div>
          </div>
          <div class="dessert-status-pill ${statusClass}">${statusLabel}</div>
        </div>
      `;
    }).join('');

    // Attach click to open detail modal
    listEl.querySelectorAll('.dessert-card').forEach(card => {
      card.addEventListener('click', () => {
        const item = desserts.find(x => x.id === card.dataset.id);
        if (item) this.openDessertDetailModal(item);
      });
    });
  }

  // ── 2. Exam Hall Screen (Papers) ──────────────────────────────────────────
  async renderPapersScreen(container) {
    const papers = await dbService.getPaperSessions();

    container.innerHTML = `
      <div class="section-header" style="margin-bottom: 12px;">
        <span class="section-title">🏛️ Physics Paper Sessions</span>
        <span class="section-count">${papers.length} Available</span>
      </div>

      <div style="display:flex; flex-direction:column; gap: 14px;">
        ${papers.map(p => `
          <div class="dessert-card" style="flex-direction:column; align-items:flex-start; gap: 12px; padding: 18px;" data-paper-id="${p.id}">
            <div style="display:flex; align-items:center; justify-content:space-between; width: 100%;">
              <span class="live-pill" style="font-size:10px;">${p.isLive ? '🔴 LIVE NOW' : 'SCHEDULED'}</span>
              <span style="font-size:12px; font-weight:700; color: #38BDF8;">⏱️ ${p.durationMinutes} Mins</span>
            </div>
            <div>
              <div style="font-size:16px; font-weight:800; color: var(--text-main); margin-bottom: 4px;">${p.title}</div>
              <div style="font-size:12.5px; color: var(--text-sub);">${p.subject}</div>
            </div>
            <div style="width: 100%; display: flex; align-items:center; justify-content:space-between; border-top: 1px solid var(--border-main); padding-top: 12px; margin-top: 4px;">
              <span style="font-size:11.5px; color: var(--text-muted);">Max Score: ${p.totalMarks} Marks</span>
              <button class="btn-primary" style="width: auto; padding: 8px 18px; font-size:12px;" data-launch-id="${p.id}">
                ${p.isLive ? '📹 Join Live Room' : 'View Exam Rules'}
              </button>
            </div>
          </div>
        `).join('')}
      </div>
    `;

    container.querySelectorAll('[data-launch-id]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.openLiveExamRoom(btn.dataset.launchId);
      });
    });
  }

  // ── 3. Daily MCQ Sprint Screen ────────────────────────────────────────────
  renderSprintScreen(container) {
    const sprint = dbService.getDailySprint();
    let currentIdx = 0;
    let selectedOption = null;
    let correctCount = 0;
    let timerVal = 60;
    let isAnswerChecked = false;

    const renderQuestion = () => {
      const q = sprint.questions[currentIdx];
      const isLast = currentIdx === sprint.questions.length - 1;

      container.innerHTML = `
        <div class="sprint-container">
          <div style="display:flex; align-items:center; justify-content:space-between;">
            <span style="font-size: 14px; font-weight:800; color: var(--text-main);">⚡ Daily MCQ Sprint</span>
            <span style="font-size: 12px; font-weight:700; color: #F59E0B;">Question ${currentIdx + 1} of ${sprint.questions.length}</span>
          </div>

          <!-- Timer Bar -->
          <div class="sprint-timer-bar">
            <div class="sprint-timer-fill" id="sprint-timer-fill" style="width: ${(timerVal / 60) * 100}%"></div>
          </div>

          <div class="question-card">
            <div class="q-badge-row">
              <span class="q-number-pill">Q${currentIdx + 1}</span>
              <span class="q-points-pill">+15 Credits</span>
            </div>
            <div class="q-text">${q.text}</div>

            <div class="q-options-list">
              ${q.options.map((opt, i) => {
                const letters = ['A', 'B', 'C', 'D', 'E'];
                let extraClass = '';
                if (isAnswerChecked) {
                  if (i === q.correctIndex) extraClass = 'selected' + ' style="border-color:#10B981; background:rgba(16,185,129,0.2);"';
                  else if (i === selectedOption) extraClass = 'style="border-color:#EF4444; background:rgba(239,68,68,0.2);"';
                } else if (i === selectedOption) {
                  extraClass = 'selected';
                }

                return `
                  <div class="q-option-item ${extraClass}" data-opt-idx="${i}">
                    <span class="q-option-letter">${letters[i]}</span>
                    <span class="q-option-text">${opt}</span>
                  </div>
                `;
              }).join('')}
            </div>

            ${isAnswerChecked ? `
              <div class="sprint-explanation-box">
                <div class="sprint-exp-title">🔬 Physics Explanation</div>
                <div class="sprint-exp-text">${q.explanation}</div>
              </div>
            ` : ''}
          </div>

          <div>
            ${!isAnswerChecked ? `
              <button class="btn-primary" id="btn-sprint-check" ${selectedOption === null ? 'disabled style="opacity:0.4;"' : ''}>
                Check Answer
              </button>
            ` : `
              <button class="btn-primary" id="btn-sprint-next">
                ${isLast ? 'Complete Sprint 🎉' : 'Next Question →'}
              </button>
            `}
          </div>
        </div>
      `;

      // Option click
      if (!isAnswerChecked) {
        container.querySelectorAll('.q-option-item').forEach(el => {
          el.addEventListener('click', () => {
            selectedOption = Number(el.dataset.optIdx);
            renderQuestion();
          });
        });

        document.getElementById('btn-sprint-check')?.addEventListener('click', () => {
          if (selectedOption === null) return;
          isAnswerChecked = true;
          if (selectedOption === q.correctIndex) {
            correctCount++;
            notificationService.showInAppBanner('Correct Answer! 🎉', '+15 Credits added to your account.', 'success');
          } else {
            notificationService.showInAppBanner('Incorrect', 'Review the concept explanation below.', 'warning');
          }
          renderQuestion();
        });
      } else {
        document.getElementById('btn-sprint-next')?.addEventListener('click', () => {
          if (isLast) {
            this.showSprintSummary(correctCount, sprint.questions.length);
          } else {
            currentIdx++;
            selectedOption = null;
            isAnswerChecked = false;
            timerVal = 60;
            renderQuestion();
          }
        });
      }
    };

    renderQuestion();
  }

  showSprintSummary(correct, total) {
    const container = document.getElementById('main-viewport');
    const xp = correct * 15;
    container.innerHTML = `
      <div style="text-align:center; padding: 40px 20px; background: var(--bg-card); border-radius: 24px; border: 1px solid var(--border-main);">
        <div style="font-size: 54px; margin-bottom: 12px;">🏆</div>
        <h2 style="font-size: 22px; font-weight:800; color: var(--text-main); margin-bottom: 6px;">Sprint Completed!</h2>
        <p style="font-size: 14px; color: var(--text-sub); margin-bottom: 24px;">
          You scored <strong>${correct}</strong> out of <strong>${total}</strong> questions correctly.
        </p>
        <div style="display:inline-block; background: rgba(37,99,235,0.15); border:1px solid #38BDF8; padding: 10px 20px; border-radius: 14px; color: #38BDF8; font-weight:800; font-size: 16px; margin-bottom: 24px;">
          +${xp} Scholar Credits Awarded
        </div>
        <button class="btn-primary" id="btn-sprint-done">Back to Cockpit</button>
      </div>
    `;

    document.getElementById('btn-sprint-done')?.addEventListener('click', () => {
      this.switchTab('home');
    });
  }

  // ── 4. Leaderboard Screen (Ranks) ─────────────────────────────────────────
  async renderLeaderboardScreen(container) {
    container.innerHTML = `
      <div class="section-header" style="margin-bottom: 14px;">
        <span class="section-title">🏆 Physics Island Ranks</span>
        <span class="section-count">Live Sync</span>
      </div>
      <div style="text-align:center; padding: 20px; color: var(--text-muted);">Loading Rankings...</div>
    `;

    const leaders = await dbService.getLeaderboard();
    const top3 = leaders.slice(0, 3);
    const rest = leaders.slice(3);

    container.innerHTML = `
      <div class="section-header" style="margin-bottom: 14px;">
        <span class="section-title">🏆 Physics Island Ranks</span>
        <span class="section-count">Top Performers</span>
      </div>

      <!-- Top 3 Podium Cards -->
      <div style="display:grid; grid-template-columns: 1fr 1.15fr 1fr; gap: 8px; align-items:flex-end; margin-bottom: 20px;">
        <!-- Rank 2 -->
        ${top3[1] ? `
          <div style="background:var(--bg-card); border:1px solid rgba(148,163,184,0.3); border-radius:18px; padding:14px 8px; text-align:center;">
            <div style="font-size:20px; margin-bottom:4px;">🥈</div>
            <div style="font-size:12px; font-weight:800; color:var(--text-main); white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${top3[1].name.split(' ')[0]}</div>
            <div style="font-size:11px; color:#38BDF8; font-weight:700;">${top3[1].credits} pts</div>
          </div>
        ` : ''}

        <!-- Rank 1 (Gold, Center, Tallest) -->
        ${top3[0] ? `
          <div style="background:linear-gradient(135deg, rgba(245,158,11,0.15), rgba(217,119,6,0.25)); border:2px solid #F59E0B; border-radius:20px; padding:18px 8px; text-align:center; box-shadow:0 8px 24px rgba(245,158,11,0.2);">
            <div style="font-size:26px; margin-bottom:4px;">👑</div>
            <div style="font-size:13px; font-weight:800; color:#FFFFFF; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${top3[0].name.split(' ')[0]}</div>
            <div style="font-size:12px; color:#FBBF24; font-weight:800;">${top3[0].credits} pts</div>
          </div>
        ` : ''}

        <!-- Rank 3 -->
        ${top3[2] ? `
          <div style="background:var(--bg-card); border:1px solid rgba(180,83,9,0.3); border-radius:18px; padding:12px 8px; text-align:center;">
            <div style="font-size:18px; margin-bottom:4px;">🥉</div>
            <div style="font-size:12px; font-weight:800; color:var(--text-main); white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${top3[2].name.split(' ')[0]}</div>
            <div style="font-size:11px; color:#38BDF8; font-weight:700;">${top3[2].credits} pts</div>
          </div>
        ` : ''}
      </div>

      <!-- Rest of ranks -->
      <div style="display:flex; flex-direction:column; gap: 8px;">
        ${rest.map(r => `
          <div class="dessert-card" style="padding: 12px 16px;">
            <div style="font-size:14px; font-weight:800; color:var(--text-muted); width:24px;">#${r.rank}</div>
            <div style="flex:1;">
              <div style="font-size:13.5px; font-weight:700; color:var(--text-main);">${r.name}</div>
              <div style="font-size:11px; color:var(--text-sub);">${r.examYear}</div>
            </div>
            <div style="font-size:13px; font-weight:800; color:#38BDF8;">${r.credits} pts</div>
          </div>
        `).join('')}
      </div>
    `;
  }

  // ── 5. Student Profile Screen ─────────────────────────────────────────────
  renderProfileScreen(container) {
    const user = this.currentUser || {};
    const isStandalone = window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches;

    container.innerHTML = `
      <div class="section-header" style="margin-bottom: 14px;">
        <span class="section-title">👤 Student Profile & Settings</span>
      </div>

      <div class="dessert-card" style="flex-direction:column; align-items:center; text-align:center; padding: 24px;">
        <div class="top-avatar" style="width: 72px; height: 72px; font-size: 26px; margin-bottom: 12px;">
          ${user.avatarUrl ? `<img src="${user.avatarUrl}"/>` : `<div class="top-avatar-fallback">${user.name ? user.name[0] : 'S'}</div>`}
        </div>
        <h2 style="font-size: 18px; font-weight:800; color:var(--text-main);">${user.name || 'Scholar'}</h2>
        <p style="font-size: 13px; color:var(--text-sub); margin-bottom: 14px;">
          ${user.studentId || 'EP-1001'} • ${user.examYear || '2026 A/L'}
        </p>

        <!-- PWA Status Badge -->
        <div style="background: ${isStandalone ? 'rgba(16,185,129,0.15)' : 'rgba(245,158,11,0.15)'}; border: 1px solid ${isStandalone ? '#10B981' : '#F59E0B'}; color: ${isStandalone ? '#34D399' : '#FBBF24'}; font-size: 12px; font-weight:800; padding: 6px 14px; border-radius: 20px; margin-bottom: 18px;">
          ${isStandalone ? '🟢 Running as Installed Home Screen App' : '⚠️ Browser Preview Mode'}
        </div>

        <div style="display:grid; grid-template-columns: 1fr 1fr; gap: 10px; width:100%; border-top:1px solid var(--border-main); padding-top: 14px;">
          <div>
            <div style="font-size:11px; color:var(--text-muted); font-weight:700;">TOTAL CREDITS</div>
            <div style="font-size:20px; font-weight:800; color:#38BDF8;">${user.credits || 340}</div>
          </div>
          <div>
            <div style="font-size:11px; color:var(--text-muted); font-weight:700;">ROLE</div>
            <div style="font-size:20px; font-weight:800; color:#10B981; text-transform:capitalize;">${user.role || 'student'}</div>
          </div>
        </div>
      </div>

      <!-- Quick Actions List -->
      <div style="display:flex; flex-direction:column; gap: 10px; margin-top: 14px;">
        <button class="dessert-card" style="width:100%; justify-content:space-between; cursor:pointer;" id="btn-test-notifs">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:18px;">🔔</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:700; color:var(--text-main);">Push Notifications Manager</div>
              <div style="font-size:11.5px; color:var(--text-sub);">Test iOS 16.4+ Web Push & In-App Alerts</div>
            </div>
          </div>
          <span style="color:var(--text-muted);">→</span>
        </button>

        <button class="dessert-card" style="width:100%; justify-content:space-between; cursor:pointer;" id="btn-test-camera">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:18px;">📷</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:700; color:var(--text-main);">Camera Document Scanner</div>
              <div style="font-size:11.5px; color:var(--text-sub);">Launch live camera scanner & photo filters</div>
            </div>
          </div>
          <span style="color:var(--text-muted);">→</span>
        </button>

        <button class="dessert-card" style="width:100%; justify-content:space-between; cursor:pointer;" id="btn-toggle-theme">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:18px;">🌓</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:700; color:var(--text-main);">Toggle Theme Mode</div>
              <div style="font-size:11.5px; color:var(--text-sub);">Switch between Sleek Dark & Clean Light</div>
            </div>
          </div>
          <span style="font-weight:700; font-size:12px; color:#38BDF8; text-transform:uppercase;">${this.theme}</span>
        </button>

        <button class="dessert-card" style="width:100%; justify-content:space-between; cursor:pointer;" id="btn-admin-switch">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:18px;">🛠️</span>
            <div style="text-align:left;">
              <div style="font-size:13.5px; font-weight:700; color:var(--text-main);">Admin & Teacher Cockpit</div>
              <div style="font-size:11.5px; color:var(--text-sub);">Review Homework & Monitor Proctoring</div>
            </div>
          </div>
          <span style="color:var(--text-muted);">→</span>
        </button>

        <button class="btn-primary" style="background:#EF4444; margin-top: 10px;" id="btn-logout">
          Log Out
        </button>
      </div>
    `;

    document.getElementById('btn-test-notifs')?.addEventListener('click', () => {
      this.openNotificationCenter();
    });

    document.getElementById('btn-test-camera')?.addEventListener('click', () => {
      this.openDocumentScanner();
    });

    document.getElementById('btn-toggle-theme')?.addEventListener('click', () => {
      this.theme = this.theme === 'dark' ? 'light' : 'dark';
      localStorage.setItem('edupeak_theme', this.theme);
      document.documentElement.setAttribute('data-theme', this.theme);
      this.renderProfileScreen(container);
    });

    document.getElementById('btn-admin-switch')?.addEventListener('click', () => {
      this.switchTab('admin');
    });

    document.getElementById('btn-logout')?.addEventListener('click', () => {
      authService.logout();
    });
  }

  // ── 6. Admin / Teacher Review Cockpit ─────────────────────────────────────
  renderAdminScreen(container) {
    container.innerHTML = `
      <div class="section-header" style="margin-bottom: 14px;">
        <span class="section-title">🛠️ Admin & Review Cockpit</span>
        <button class="btn-primary" style="width:auto; padding:6px 12px; font-size:11px;" id="btn-back-student">
          Student View
        </button>
      </div>

      <div style="background:var(--bg-card); border-radius:20px; border:1px solid var(--border-main); padding: 18px; margin-bottom: 16px;">
        <h3 style="font-size:15px; font-weight:800; color:var(--text-main); margin-bottom:6px;">Homework Review Queue</h3>
        <p style="font-size:12.5px; color:var(--text-sub); margin-bottom: 14px;">
          Review pending homework submissions, award scholar credits, and give personalized feedback.
        </p>
        <div id="admin-pending-list" style="display:flex; flex-direction:column; gap:10px;">
          ${this.currentDesserts.map(d => `
            <div class="dessert-card" style="padding:12px;">
              <div style="flex:1;">
                <div style="font-size:13px; font-weight:700; color:var(--text-main);">${d.studentName} - ${d.subject}</div>
                <div style="font-size:11px; color:var(--text-muted);">${d.caption || 'No note'}</div>
              </div>
              <button class="btn-primary" style="width:auto; padding:6px 12px; font-size:11px;" data-review-id="${d.id}">
                Grade
              </button>
            </div>
          `).join('')}
        </div>
      </div>
    `;

    document.getElementById('btn-back-student')?.addEventListener('click', () => {
      this.switchTab('home');
    });

    container.querySelectorAll('[data-review-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        const item = this.currentDesserts.find(x => x.id === btn.dataset.reviewId);
        if (item) this.openAdminGradeModal(item);
      });
    });
  }

  // ── Camera Document Scanner Flow (Full iOS & Mobile Feature Match) ────────
  openDocumentScanner() {
    cameraService.clearPages();

    const modal = document.createElement('div');
    modal.className = 'scanner-modal';
    modal.id = 'camera-scanner-modal';

    modal.innerHTML = `
      <!-- Top Bar -->
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

      <!-- Live Video Viewfinder -->
      <div class="scanner-viewfinder-container">
        <video class="scanner-video" id="scanner-live-video" autoplay playsinline muted></video>
        <div class="scanner-frame-overlay">
          <div class="scanner-laser"></div>
          <span class="scanner-hint-text">Align document within the frame</span>
        </div>
        <div class="scanner-flash-overlay" id="scanner-flash"></div>
      </div>

      <!-- Document Image Processing Filter Bar -->
      <div class="scanner-filter-bar">
        <button class="filter-pill active" data-filter="none">Natural</button>
        <button class="filter-pill" data-filter="document">Enhance</button>
        <button class="filter-pill" data-filter="bw">B&W</button>
      </div>

      <!-- Bottom Bar with Shutter & Thumbnails Strip -->
      <div class="scanner-bottom-bar">
        <!-- Thumbnail strip -->
        <div class="scanner-thumbnails-strip" id="scanner-thumb-strip"></div>

        <!-- Shutter Row -->
        <div class="scanner-shutter-row">
          <!-- iOS File Picker Camera Fallback -->
          <label class="btn-upload-file-fallback" for="input-file-camera">
            <span>📁 Gallery</span>
            <input type="file" id="input-file-camera" accept="image/*" capture="environment" style="display:none;" multiple />
          </label>

          <!-- Central Shutter Trigger -->
          <div class="shutter-btn-wrap">
            <div class="shutter-outer-ring"></div>
            <button class="btn-shutter" id="btn-trigger-shutter"></button>
          </div>

          <!-- Done Button -->
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

    // Start rear camera
    cameraService.startCamera(videoEl, 'environment').catch(err => {
      alert('Camera Notice: ' + err.message);
    });

    // Torch toggle
    document.getElementById('btn-toggle-torch')?.addEventListener('click', async () => {
      const active = await cameraService.toggleTorch();
      document.getElementById('btn-toggle-torch')?.classList.toggle('active', active);
    });

    // Filter selector
    modal.querySelectorAll('.filter-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        modal.querySelectorAll('.filter-pill').forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        currentFilter = pill.dataset.filter;
      });
    });

    // Shutter Trigger
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
        // Flash animation
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

    // Gallery File Fallback
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

    // Close Scanner
    const closeScanner = () => {
      cameraService.stopCamera();
      modal.remove();
    };

    document.getElementById('btn-close-scanner')?.addEventListener('click', closeScanner);

    // Done scanning -> Open submit details dialog
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

        <div style="margin-bottom: 14px;">
          <div style="font-size: 13px; font-weight:700; color:var(--text-sub); margin-bottom: 8px;">
            Captured Pages (${pages.length})
          </div>
          <div style="display:flex; gap: 8px; overflow-x:auto; padding: 4px 0;">
            ${pages.map((img, i) => `
              <img src="${img}" style="width: 50px; height: 68px; object-fit: cover; border-radius: 8px; border: 1px solid #2563EB;" />
            `).join('')}
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">Subject / Chapter Topic</label>
          <select class="form-select" id="submit-subject-select">
            <option value="Physics Mechanics: Circular & Gravitation">Physics Mechanics: Circular & Gravitation</option>
            <option value="Thermal Physics: Thermodynamics & Gas Laws">Thermal Physics: Thermodynamics & Gas Laws</option>
            <option value="Wave Optics & Interference">Wave Optics & Interference</option>
            <option value="Current Electricity & Kirchhoff's Laws">Current Electricity & Kirchhoff's Laws</option>
            <option value="Electronics & Logic Gates">Electronics & Logic Gates</option>
          </select>
        </div>

        <div class="form-group">
          <label class="form-label">Student Note / Question</label>
          <textarea class="form-textarea" id="submit-caption-input" rows="3" placeholder="Add any comments or questions for the teacher..."></textarea>
        </div>

        <button class="btn-primary" id="btn-confirm-dessert-upload">
          🚀 Submit Homework Now
        </button>
      </div>
    `;

    document.body.appendChild(modal);

    document.getElementById('btn-close-submit-dialog')?.addEventListener('click', () => modal.remove());

    document.getElementById('btn-confirm-dessert-upload')?.addEventListener('click', async () => {
      const btn = document.getElementById('btn-confirm-dessert-upload');
      const subject = document.getElementById('submit-subject-select')?.value;
      const caption = document.getElementById('submit-caption-input')?.value;
      const user = this.currentUser || {};

      btn.disabled = true;
      btn.textContent = 'Uploading to Firebase... ⏳';

      try {
        const result = await dbService.submitDessert({
          studentId: user.uid,
          studentName: user.name,
          studentPhone: user.phone,
          subject,
          caption,
          mediaUrls: pages
        });

        modal.remove();
        notificationService.showInAppBanner('Homework Submitted! 🎉', 'Your teacher will review your submission and award marks.', 'success');
        this.switchTab('home');
      } catch (err) {
        alert('Upload Error: ' + err.message);
        btn.disabled = false;
        btn.textContent = '🚀 Submit Homework Now';
      }
    });
  }

  // ── Live Exam Room with Front-Camera Proctoring & Anti-Cheat ──────────────
  openLiveExamRoom(paperId) {
    this.isInsideLiveExam = true;
    this.antiCheatViolations = 0;

    const modal = document.createElement('div');
    modal.className = 'exam-hall-container';
    modal.id = 'exam-hall-room';

    let examMinutesLeft = 120;
    let currentQ = 0;
    const questions = [
      {
        id: 'ex_1',
        text: 'A simple pendulum has period T at the Earth\'s surface. If it is placed in an elevator moving downwards with acceleration g/4, its new period is:',
        options: ['T / 2', '2T / √3', 'T * √3 / 2', '2T', 'T / √2'],
        correctIndex: 1
      },
      {
        id: 'ex_2',
        text: 'A radioactive isotope has half-life 6 hours. After 24 hours, the fraction of initial undecayed nuclei remaining is:',
        options: ['1 / 4', '1 / 8', '1 / 16', '1 / 32', '1 / 64'],
        correctIndex: 2
      },
      {
        id: 'ex_3',
        text: 'Which of the following is true for an ideal gas undergoing a reversible adiabatic process?',
        options: ['Temperature remains constant', 'Entropy change is zero', 'No work is done', 'Pressure is proportional to volume', 'Internal energy is unchanged'],
        correctIndex: 1
      }
    ];

    const answers = {};

    modal.innerHTML = `
      <!-- Exam Header -->
      <header class="exam-header">
        <div class="exam-info-col">
          <span class="exam-title">2026 A/L Physics Model Paper</span>
          <span class="exam-status-indicator">
            <span class="live-dot"></span>
            Proctored Session Active
          </span>
        </div>

        <div class="exam-timer-box" id="exam-timer-display">
          <span>⏱️</span>
          <span id="exam-time-str">01:59:59</span>
        </div>

        <button class="btn-scanner-icon" id="btn-exit-exam" title="Exit Exam">✕</button>
      </header>

      <!-- Floating Live Proctor Video Feed (Front Camera) -->
      <div class="proctor-live-box">
        <video class="proctor-video" id="proctor-live-video" autoplay playsinline muted></video>
        <div class="proctor-badge">
          <span class="proctor-pulse"></span>
          <span>LIVE</span>
        </div>
      </div>

      <!-- Exam Body -->
      <div class="exam-body" id="exam-body-content"></div>

      <!-- Exam Bottom Navigation -->
      <footer class="exam-footer">
        <button class="btn-nav-q" id="btn-prev-q">← Prev</button>
        <span style="font-size:12px; font-weight:700; color:var(--text-sub);" id="exam-q-counter">Q1 / 3</span>
        <button class="btn-nav-q" id="btn-next-q">Next →</button>
        <button class="btn-finish-exam" id="btn-submit-exam">Submit Paper</button>
      </footer>
    `;

    document.body.appendChild(modal);

    // Start Front Camera for Proctoring
    const proctorVideo = document.getElementById('proctor-live-video');
    cameraService.startCamera(proctorVideo, 'user').catch(err => {
      console.warn('[Proctor] Front camera warning:', err);
    });

    // Render Question
    const renderExamQuestion = () => {
      const q = questions[currentQ];
      const body = document.getElementById('exam-body-content');
      const counter = document.getElementById('exam-q-counter');
      const prevBtn = document.getElementById('btn-prev-q');
      const nextBtn = document.getElementById('btn-next-q');

      if (counter) counter.textContent = `Q${currentQ + 1} / ${questions.length}`;
      if (prevBtn) prevBtn.disabled = currentQ === 0;
      if (nextBtn) nextBtn.disabled = currentQ === questions.length - 1;

      if (body) {
        body.innerHTML = `
          <div class="question-card">
            <div class="q-badge-row">
              <span class="q-number-pill">Question ${currentQ + 1}</span>
              <span class="q-points-pill">1.0 Mark</span>
            </div>
            <div class="q-text">${q.text}</div>
            <div class="q-options-list">
              ${q.options.map((opt, i) => {
                const letters = ['A', 'B', 'C', 'D', 'E'];
                const isSelected = answers[currentQ] === i;
                return `
                  <div class="q-option-item ${isSelected ? 'selected' : ''}" data-opt="${i}">
                    <span class="q-option-letter">${letters[i]}</span>
                    <span class="q-option-text">${opt}</span>
                  </div>
                `;
              }).join('')}
            </div>
          </div>

          <!-- Question jump grid -->
          <div style="margin-top: 10px;">
            <div style="font-size:12px; font-weight:700; color:var(--text-muted); margin-bottom: 8px;">Question Navigator</div>
            <div class="q-nav-grid">
              ${questions.map((_, idx) => `
                <button class="q-grid-btn ${answers[idx] !== undefined ? 'answered' : ''} ${idx === currentQ ? 'current' : ''}" data-jump="${idx}">
                  ${idx + 1}
                </button>
              `).join('')}
            </div>
          </div>
        `;

        body.querySelectorAll('.q-option-item').forEach(el => {
          el.addEventListener('click', () => {
            answers[currentQ] = Number(el.dataset.opt);
            renderExamQuestion();
          });
        });

        body.querySelectorAll('.q-grid-btn').forEach(btn => {
          btn.addEventListener('click', () => {
            currentQ = Number(btn.dataset.jump);
            renderExamQuestion();
          });
        });
      }
    };

    renderExamQuestion();

    document.getElementById('btn-prev-q')?.addEventListener('click', () => {
      if (currentQ > 0) { currentQ--; renderExamQuestion(); }
    });

    document.getElementById('btn-next-q')?.addEventListener('click', () => {
      if (currentQ < questions.length - 1) { currentQ++; renderExamQuestion(); }
    });

    // Close Exam Room
    const exitExam = () => {
      this.isInsideLiveExam = false;
      cameraService.stopCamera();
      modal.remove();
    };

    document.getElementById('btn-exit-exam')?.addEventListener('click', () => {
      if (confirm('Are you sure you want to leave the exam room? Your answers will be submitted.')) {
        exitExam();
      }
    });

    document.getElementById('btn-submit-exam')?.addEventListener('click', () => {
      alert('Exam submitted successfully! Your responses have been recorded.');
      exitExam();
    });
  }

  // Anti-Cheat: Detect Tab switching during exam
  handleExamTabSwitch() {
    this.antiCheatViolations++;
    const modal = document.createElement('div');
    modal.className = 'anti-cheat-modal';
    modal.innerHTML = `
      <div class="anti-cheat-card">
        <div class="anti-cheat-icon">⚠️</div>
        <h3 class="anti-cheat-title">Anti-Cheat Alert</h3>
        <p class="anti-cheat-msg">
          Switching tabs or minimizing the app during the exam is strictly prohibited! This incident has been logged for teacher review.
        </p>
        <button class="btn-anti-cheat-dismiss" id="btn-anti-cheat-ack">Return to Exam (Violation ${this.antiCheatViolations}/3)</button>
      </div>
    `;

    document.body.appendChild(modal);

    document.getElementById('btn-anti-cheat-ack')?.addEventListener('click', () => {
      modal.remove();
    });
  }

  // ── Dessert Detail Modal ──────────────────────────────────────────────────
  openDessertDetailModal(dessert) {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    const isApproved = dessert.status === 'approved';

    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title">${dessert.subject || 'Homework Detail'}</h3>
          <button class="modal-close-btn" id="btn-close-dessert-modal">✕</button>
        </div>

        <div style="margin-bottom: 14px;">
          <div style="font-size:12px; color:var(--text-muted);">STATUS</div>
          <div style="display:inline-block; font-size:12px; font-weight:800; padding: 4px 10px; border-radius: 12px; margin-top: 4px;" class="${isApproved ? 'status-approved' : 'status-pending'}">
            ${dessert.status.toUpperCase()} • ${dessert.creditsAwarded || 0} Credits
          </div>
        </div>

        ${dessert.adminFeedback ? `
          <div style="background: rgba(16,185,129,0.12); border-left: 3px solid #10B981; padding: 12px; border-radius: 8px; margin-bottom: 14px;">
            <div style="font-size:11px; font-weight:800; color:#34D399; margin-bottom:4px;">TEACHER REVIEW FEEDBACK</div>
            <div style="font-size:13px; color:#F1F5F9; line-height: 1.4;">${dessert.adminFeedback}</div>
            <div style="font-size:10.5px; color:var(--text-muted); margin-top: 6px;">Reviewed by ${dessert.reviewedBy || 'Teacher'}</div>
          </div>
        ` : `
          <div style="background: rgba(245,158,11,0.12); border-left: 3px solid #F59E0B; padding: 10px; border-radius: 8px; margin-bottom: 14px; font-size:12px; color:#FDE68A;">
            ⏳ Awaiting review from your physics teacher.
          </div>
        `}

        <div style="margin-bottom: 14px;">
          <div style="font-size:12px; font-weight:700; color:var(--text-sub); margin-bottom:6px;">Your Submission Note:</div>
          <div style="font-size:13px; color:var(--text-main);">${dessert.caption || 'None'}</div>
        </div>

        ${dessert.mediaUrls && dessert.mediaUrls.length > 0 ? `
          <div>
            <div style="font-size:12px; font-weight:700; color:var(--text-sub); margin-bottom:8px;">Scanned Pages:</div>
            <div style="display:flex; flex-direction:column; gap:10px;">
              ${dessert.mediaUrls.map(url => `
                <img src="${url}" style="width:100%; border-radius:12px; border:1px solid var(--border-main);" />
              `).join('')}
            </div>
          </div>
        ` : ''}
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('btn-close-dessert-modal')?.addEventListener('click', () => modal.remove());
  }

  // ── Notification Center Modal ─────────────────────────────────────────────
  openNotificationCenter() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';

    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title">Push Notification Center</h3>
          <button class="modal-close-btn" id="btn-close-notif-modal">✕</button>
        </div>

        <p style="font-size: 13px; color: var(--text-sub); margin-bottom: 16px; line-height: 1.5;">
          On iOS 16.4+, Apple requires EduPeak to be launched from your <strong>Home Screen</strong> to receive system push notifications for homework marking and exams.
        </p>

        <div style="background:var(--bg-card-subtle); border:1px solid var(--border-main); border-radius:14px; padding:14px; margin-bottom:16px;">
          <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:8px;">
            <span style="font-size:13px; font-weight:700; color:var(--text-main);">Push Permission Status</span>
            <span style="font-size:11px; font-weight:800; color:#38BDF8;" id="notif-perm-status">${Notification.permission || 'default'}</span>
          </div>
          <button class="btn-primary" id="btn-enable-push" style="padding: 10px; font-size:13px;">
            🔔 Enable Push Notifications
          </button>
        </div>

        <button class="btn-primary" id="btn-test-push-chime" style="background:linear-gradient(135deg, #10B981, #059669); margin-bottom:10px;">
          ⚡ Send Test Push Notification
        </button>
      </div>
    `;

    document.body.appendChild(modal);

    document.getElementById('btn-close-notif-modal')?.addEventListener('click', () => modal.remove());

    document.getElementById('btn-enable-push')?.addEventListener('click', async () => {
      const granted = await notificationService.requestPermission(this.currentUser);
      document.getElementById('notif-perm-status').textContent = granted ? 'granted' : 'denied';
    });

    document.getElementById('btn-test-push-chime')?.addEventListener('click', () => {
      notificationService.showLocalNotification('EduPeak Exam Alert 🏛️', {
        body: 'Model Paper 04 is now live! Tap to join the proctored exam hall.',
        tag: 'test-alert'
      });
      notificationService.showInAppBanner('Exam Alert Sent', 'Look for the system banner and audio chime.', 'info');
    });
  }

  // ── Auth Modal & Onboarding ───────────────────────────────────────────────
  renderAuthModal() {
    let modal = document.getElementById('auth-modal');
    if (!modal) {
      modal = document.createElement('div');
      modal.className = 'app-modal';
      modal.id = 'auth-modal';
      document.body.appendChild(modal);
    }

    let isRegisterMode = false;

    const renderAuthForm = () => {
      modal.innerHTML = `
        <div class="modal-sheet" style="border-radius: 28px; text-align:center;">
          <div class="gatekeeper-icon-wrap" style="width:68px; height:68px; margin: 0 auto 12px;">
            <img src="./icons/icon-192.png" alt="EduPeak" style="width:68px; height:68px; border-radius:18px;" onerror="this.src='./icons/icon.svg'" />
          </div>
          <h2 style="font-size:20px; font-weight:800; color:var(--text-main); margin-bottom:4px;">
            ${isRegisterMode ? 'Student Registration' : 'Welcome to EduPeak'}
          </h2>
          <p style="font-size:12.5px; color:var(--text-sub); margin-bottom:18px;">
            ${isRegisterMode ? 'Create your physics scholar account' : 'Sign in to access your cockpit and exam sessions'}
          </p>

          ${isRegisterMode ? `
            <div class="form-group">
              <label class="form-label">Full Name</label>
              <input type="text" class="form-input" id="auth-name" placeholder="Kasun Perera" />
            </div>
            <div class="form-group">
              <label class="form-label">Target Exam Year</label>
              <select class="form-select" id="auth-year">
                <option value="2026 A/L">2026 A/L</option>
                <option value="2027 A/L">2027 A/L</option>
                <option value="2028 A/L">2028 A/L</option>
              </select>
            </div>
          ` : ''}

          <div class="form-group">
            <label class="form-label">Phone Number</label>
            <input type="tel" class="form-input" id="auth-phone" placeholder="0712345678" />
          </div>

          <div class="form-group">
            <label class="form-label">Password</label>
            <input type="password" class="form-input" id="auth-pass" placeholder="••••••••" />
          </div>

          <button class="btn-primary" id="btn-submit-auth">
            ${isRegisterMode ? 'Register Account' : 'Sign In'}
          </button>

          <div style="margin: 14px 0 10px; font-size:12px; color:var(--text-muted);">
            ${isRegisterMode ? 'Already registered?' : 'Don\'t have an account?'}
            <button id="btn-toggle-auth-mode" style="background:none; border:none; color:#38BDF8; font-weight:700; cursor:pointer;">
              ${isRegisterMode ? 'Sign In' : 'Register Here'}
            </button>
          </div>

          <!-- Instant Demo Logins -->
          <div style="border-top:1px solid var(--border-main); padding-top:14px; margin-top:14px;">
            <div style="font-size:11px; font-weight:700; color:var(--text-muted); margin-bottom:8px;">INSTANT DEMO PREVIEW</div>
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:8px;">
              <button class="btn-dev-preview" id="btn-demo-student">Student Demo 👨‍🎓</button>
              <button class="btn-dev-preview" id="btn-demo-admin">Admin / Teacher 👨‍🏫</button>
            </div>
          </div>
        </div>
      `;

      document.getElementById('btn-toggle-auth-mode')?.addEventListener('click', () => {
        isRegisterMode = !isRegisterMode;
        renderAuthForm();
      });

      document.getElementById('btn-demo-student')?.addEventListener('click', () => {
        authService.loginDemo('student');
      });

      document.getElementById('btn-demo-admin')?.addEventListener('click', () => {
        authService.loginDemo('admin');
      });

      document.getElementById('btn-submit-auth')?.addEventListener('click', async () => {
        const phone = document.getElementById('auth-phone')?.value;
        const pass = document.getElementById('auth-pass')?.value;
        const name = document.getElementById('auth-name')?.value;
        const year = document.getElementById('auth-year')?.value;

        try {
          if (isRegisterMode) {
            await authService.register({ name, phone, password: pass, examYear: year });
          } else {
            await authService.login({ phone, password: pass });
          }
        } catch (err) {
          alert(err.message);
        }
      });
    };

    renderAuthForm();
  }

  closeAuthModal() {
    document.getElementById('auth-modal')?.remove();
  }

  getGreeting() {
    const hr = new Date().getHours();
    if (hr < 12) return 'Good Morning';
    if (hr < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  startCountdownTimer() {
    if (this.activeExamTimer) clearInterval(this.activeExamTimer);

    // Target exam date: 42 days, 14 hours ahead
    const target = new Date(Date.now() + (42 * 86400000) + (14 * 3600000));

    const update = () => {
      const diff = target - new Date();
      if (diff <= 0) return;

      const days = Math.floor(diff / 86400000);
      const hours = Math.floor((diff % 86400000) / 3600000);
      const mins = Math.floor((diff % 3600000) / 60000);

      const dEl = document.getElementById('cd-days');
      const hEl = document.getElementById('cd-hours');
      const mEl = document.getElementById('cd-mins');

      if (dEl) dEl.textContent = days;
      if (hEl) hEl.textContent = hours;
      if (mEl) mEl.textContent = mins;
    };

    this.activeExamTimer = setInterval(update, 30000);
    update();
  }
}

// Instantiate and start app on window load
window.addEventListener('DOMContentLoaded', () => {
  const app = new AppController();
  app.init();
});
