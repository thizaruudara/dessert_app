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
    this.currentUser = authService.currentUser || {
      name: 'ThiZaru',
      phone: '0770557769',
      examYear: '2027 A/L Candidate',
      credits: 155,
      studentId: 'EP-2027'
    };
    this.countdownTimer = null;
    this.isInsideLiveExam = false;
    this.antiCheatViolations = 0;
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
        if (this.currentMode === 'admin') {
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
    this.papersTab = this.papersTab ?? 0;
    this.papersBatch = this.papersBatch ?? '2027 A/L';
    this.selectedSlots = this.selectedSlots ?? { 'paper_001': 'slot_1', 'paper_002': 'slot_sprint' };

    const papers = await dbService.getPaperSessions();
    const isAll = this.papersBatch === 'All Batches';

    container.innerHTML = `
      <!-- Screen Top Bar with Batch Filter and Refresh -->
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box">📋</div>
          <div>
            <div class="appbar-title">Paper Writing Sessions</div>
            <div class="appbar-subtitle">${isAll ? 'සියලු Batches • සජීවී විභාග සහ අධීක්ෂණ සැසි' : this.papersBatch + ' • සජීවී විභාග සහ අධීක්ෂණ සැසි'}</div>
          </div>
        </div>
        <button class="appbar-badge-toggle" id="btn-toggle-papers-batch">
          <span>🔄</span>
          <span>${this.papersBatch}</span>
        </button>
      </div>

      <!-- Dual Sub-Tabs (Live Sessions vs Upcoming Papers & Hints) -->
      <div class="sub-tabs-container">
        <button class="sub-tab-btn ${this.papersTab === 0 ? 'active' : ''}" id="tab-papers-live">
          <span>🔴 Live Sessions</span>
          <span class="tab-sub">සජීවී විභාග සැසි</span>
        </button>
        <button class="sub-tab-btn ${this.papersTab === 1 ? 'active' : ''}" id="tab-papers-upcoming">
          <span>📚 Upcoming & Hints</span>
          <span class="tab-sub">ඉදිරි විභාග සහ මාර්ගෝපදේශ</span>
        </button>
      </div>

      <!-- Tab 0: Live Sessions -->
      <div id="papers-tab-live-content" style="${this.papersTab === 0 ? 'display:flex; flex-direction:column; gap:14px;' : 'display:none;'}">
        ${papers.map(p => {
          const isLive = p.isLive;
          const selectedSlot = this.selectedSlots[p.id] || (p.slots && p.slots[0]?.id) || 'slot_1';

          return `
            <div class="paper-session-card">
              <div class="paper-card-header">
                <span class="phase-pill ${isLive ? 'phase-live' : 'phase-upcoming'}">
                  ${isLive ? '🔴 සක්‍රීයයි (Writing in Progress)' : '⏰ ආරම්භ වීමට නියමිතයි (Upcoming)'}
                </span>
                <span style="font-size:12px; font-weight:700; color:#2563EB;">⏱️ ${p.durationMinutes} Mins</span>
              </div>

              <div class="paper-title">${p.title}</div>

              <div class="paper-meta-row">
                <div class="meta-chip">📚 ${p.subject}</div>
                <div class="meta-chip">📝 100 Marks</div>
                <div class="meta-chip">🎥 Live Proctoring</div>
              </div>

              <!-- Slot Selection Cards -->
              <div style="font-size:11.5px; font-weight:800; color:#475569; margin-top:2px;">
                තෝරාගත් විභාග කාල සැසිය (Selected Exam Slot):
              </div>
              <div class="slots-container">
                ${(p.slots || [
                  { id: 'slot_1', name: 'Morning (08:30 AM)', seatsLeft: 42 },
                  { id: 'slot_2', name: 'Evening (04:00 PM)', seatsLeft: 78 }
                ]).map(slot => `
                  <div class="slot-selection-box ${selectedSlot === slot.id ? 'selected' : ''}" data-paper-id="${p.id}" data-slot-id="${slot.id}">
                    <div class="slot-name">
                      <span>${slot.name}</span>
                      <span>${selectedSlot === slot.id ? '✓' : '○'}</span>
                    </div>
                    <div class="slot-seats">🪑 ${slot.seatsLeft || 50} Seats Remaining</div>
                  </div>
                `).join('')}
              </div>

              <!-- Action Buttons -->
              <div class="paper-actions-row">
                <button class="btn-exam-hall" data-paper-join="${p.id}">
                  <span>🎥</span>
                  <span>Enter Exam Hall (විභාග ශාලාවට)</span>
                </button>
                <button class="btn-paper-script" data-paper-scan="${p.id}" title="Scan & Upload Script">
                  <span>📄</span>
                  <span>Upload Script</span>
                </button>
              </div>
            </div>
          `;
        }).join('')}
      </div>

      <!-- Tab 1: Upcoming Papers & Hints -->
      <div id="papers-tab-upcoming-content" style="${this.papersTab === 1 ? 'display:flex; flex-direction:column; gap:14px;' : 'display:none;'}">
        <div class="upcoming-hint-card">
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <span class="phase-pill phase-upcoming">🎯 Upcoming Term Paper 02</span>
            <span style="font-size:11px; font-weight:800; color:#2563EB;">2027 A/L Target</span>
          </div>

          <div class="paper-title">2027 A/L Full Syllabus Consolidation Paper</div>
          <div style="font-size:12px; color:#64748B;">Scheduled: October 14, 2026 • 08:30 AM</div>

          <div class="syllabus-breakdown">
            <div style="font-size:11px; font-weight:800; color:#0F172A; margin-bottom:4px;">විභාග විෂය නිර්දේශ ප්‍රතිශත (Syllabus Coverage):</div>
            <div>
              <div class="syllabus-row"><span>1. Mechanics & Newton's Laws</span><span>40%</span></div>
              <div class="syllabus-bar-bg"><div class="syllabus-bar-fill" style="width:40%;"></div></div>
            </div>
            <div>
              <div class="syllabus-row"><span>2. Waves & Oscillations</span><span>30%</span></div>
              <div class="syllabus-bar-bg"><div class="syllabus-bar-fill" style="width:30%; background:#0284C7;"></div></div>
            </div>
            <div>
              <div class="syllabus-row"><span>3. Electricity & Magnetism</span><span>20%</span></div>
              <div class="syllabus-bar-bg"><div class="syllabus-bar-fill" style="width:20%; background:#7C3AED;"></div></div>
            </div>
            <div>
              <div class="syllabus-row"><span>4. Thermal Physics</span><span>10%</span></div>
              <div class="syllabus-bar-bg"><div class="syllabus-bar-fill" style="width:10%; background:#EA580C;"></div></div>
            </div>
          </div>

          <div class="teacher-tip-box">
            <strong>💡 ගුරු උපදෙස (Teacher Hint):</strong><br>
            "ආනත තලයක චලිතයේදී ඝර්ෂණ බලය සහ ගම්‍යතා සංස්ථිති මූලධර්මය පිළිබඳ විශේෂ අවධානය යොමු කරන්න. රූප සටහන් පැහැදිලිව ඇඳීමෙන් ලකුණු පහසුවෙන් තහවුරු කරගත හැක."
          </div>

          <button class="btn-primary" style="background:#0F172A; padding:10px; font-size:12px;" onclick="alert('Pre-Exam Revision Guide PDF will download once published.')">
            📥 Download Revision Hints PDF
          </button>
        </div>
      </div>
    `;

    // Event Listeners
    document.getElementById('tab-papers-live')?.addEventListener('click', () => {
      this.papersTab = 0;
      this.renderPapersScreen(container);
    });

    document.getElementById('tab-papers-upcoming')?.addEventListener('click', () => {
      this.papersTab = 1;
      this.renderPapersScreen(container);
    });

    document.getElementById('btn-toggle-papers-batch')?.addEventListener('click', () => {
      this.papersBatch = this.papersBatch === '2027 A/L' ? 'All Batches' : '2027 A/L';
      this.renderPapersScreen(container);
    });

    container.querySelectorAll('.slot-selection-box').forEach(slotEl => {
      slotEl.addEventListener('click', () => {
        const pId = slotEl.dataset.paperId;
        const sId = slotEl.dataset.slotId;
        this.selectedSlots[pId] = sId;
        this.renderPapersScreen(container);
      });
    });

    container.querySelectorAll('[data-paper-join]').forEach(b => {
      b.addEventListener('click', () => {
        this.openLiveExamRoom(b.dataset.paperJoin);
      });
    });

    container.querySelectorAll('[data-paper-scan]').forEach(b => {
      b.addEventListener('click', () => {
        this.openDocumentScanner();
      });
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
      if (confirm('Are you sure you want to log out of your student account?')) {
        authService.logout();
        location.reload();
      }
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
        <span class="status-time" id="status-clock">8:15</span>
        <div class="status-icons">
          <span>●●●</span>
          <span>📶</span>
          <span>🔋</span>
        </div>
      </div>

      <!-- Sticky Executive Header across all Admin Screens -->
      <div style="padding: 44px 14px 6px; background: #0F172A; flex-shrink: 0; box-shadow: 0 4px 16px rgba(0,0,0,0.15);">
        <div class="admin-executive-header" style="margin-bottom:0; padding:10px 12px; border-radius:14px; background:transparent; box-shadow:none;">
          <div>
            <div style="font-size:14.5px; font-weight:900; letter-spacing:-0.02em; color:#FFFFFF;">EduPeak Admin Shell</div>
            <div style="display:flex; align-items:center; gap:6px; margin-top:2px;">
              <span class="admin-badge-faculty">🛡️ Physics Faculty</span>
              <span style="font-size:10.5px; opacity:0.8; color:#CBD5E1;">A/L Lead Proctor</span>
            </div>
          </div>
          <button class="btn-switch-to-student" id="btn-global-exit-admin">
            <span>🎓</span>
            <span>Student App</span>
          </button>
        </div>
      </div>

      <!-- Main Scrollable Viewport -->
      <div class="main-viewport" id="admin-main-viewport"></div>

      <!-- Admin Bottom Navigation Bar (1:1 with admin_shell.dart) -->
      <nav class="bottom-nav-bar" id="admin-bottom-nav">
        <button class="nav-tab-btn ${this.adminTab === 'dashboard' ? 'active' : ''}" data-admin-tab="dashboard">
          <div class="nav-pill-icon">📊</div>
          <span>Dashboard</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'papers' ? 'active' : ''}" data-admin-tab="papers">
          <div class="nav-pill-icon">📋</div>
          <span>Papers</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'sprints' ? 'active' : ''}" data-admin-tab="sprints">
          <div class="nav-pill-icon">⚡</div>
          <span>Sprints</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'students' ? 'active' : ''}" data-admin-tab="students">
          <div class="nav-pill-icon">👥</div>
          <span>Students</span>
        </button>
        <button class="nav-tab-btn ${this.adminTab === 'broadcasts' ? 'active' : ''}" data-admin-tab="broadcasts">
          <div class="nav-pill-icon">📢</div>
          <span>Broadcasts</span>
        </button>
      </nav>
    `;

    this.updateClock();

    document.getElementById('btn-global-exit-admin')?.addEventListener('click', () => {
      this.currentMode = 'student';
      this.renderApp();
    });

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

  // 1. Admin Dashboard (Submissions Review Workspace - admin_home_screen.dart)
  async renderAdminDashboardScreen(container) {
    this.adminFilterTab = this.adminFilterTab ?? 'pending';
    this.adminSearchQuery = this.adminSearchQuery ?? '';

    const allDesserts = await dbService.getAllDessertsForAdmin();
    const students = await dbService.getAllStudents();

    const pending = allDesserts.filter(d => (d.status || '').toLowerCase() === 'pending');
    const approved = allDesserts.filter(d => (d.status || '').toLowerCase() === 'approved');
    const rejected = allDesserts.filter(d => (d.status || '').toLowerCase() === 'rejected');

    let currentList = this.adminFilterTab === 'pending' ? pending :
                      this.adminFilterTab === 'approved' ? approved :
                      this.adminFilterTab === 'rejected' ? rejected : allDesserts;

    if (this.adminSearchQuery.trim()) {
      const q = this.adminSearchQuery.toLowerCase();
      currentList = currentList.filter(d => 
        (d.studentName || '').toLowerCase().includes(q) ||
        (d.subject || '').toLowerCase().includes(q) ||
        (d.studentPhone || '').includes(q)
      );
    }

    container.innerHTML = `
      <!-- Real-Time Overview Metrics Grid -->
      <div class="admin-metrics-grid">
        <div class="admin-metric-card" style="border-left:4px solid #F59E0B;">
          <div class="metric-top">
            <span class="metric-lbl">Pending Submissions</span>
            <div class="metric-icon" style="background:#FEF3C7; color:#D97706;">⏳</div>
          </div>
          <div class="metric-val" style="color:#D97706;">${pending.length}</div>
        </div>

        <div class="admin-metric-card" style="border-left:4px solid #10B981;">
          <div class="metric-top">
            <span class="metric-lbl">Approved Submissions</span>
            <div class="metric-icon" style="background:#DCFCE7; color:#059669;">✅</div>
          </div>
          <div class="metric-val" style="color:#059669;">${approved.length}</div>
        </div>

        <div class="admin-metric-card" style="border-left:4px solid #EF4444;">
          <div class="metric-top">
            <span class="metric-lbl">Revisions Needed</span>
            <div class="metric-icon" style="background:#FEE2E2; color:#DC2626;">❌</div>
          </div>
          <div class="metric-val" style="color:#DC2626;">${rejected.length}</div>
        </div>

        <div class="admin-metric-card" style="border-left:4px solid #6366F1;">
          <div class="metric-top">
            <span class="metric-lbl">Enrolled Scholars</span>
            <div class="metric-icon" style="background:#EEF2FF; color:#4F46E5;">👥</div>
          </div>
          <div class="metric-val" style="color:#4F46E5;">${students.length}</div>
        </div>
      </div>

      <!-- Submissions Review Workspace -->
      <div style="font-size:14px; font-weight:800; color:#0F172A; margin:6px 0 10px; display:flex; justify-content:space-between; align-items:center;">
        <span>📝 Homework Submissions Workspace</span>
        <span style="font-size:11px; color:#64748B;">Live Sync</span>
      </div>

      <!-- Filter Tabs -->
      <div class="admin-tab-nav">
        <button class="admin-tab-btn ${this.adminFilterTab === 'pending' ? 'active' : ''}" data-af-tab="pending">
          Pending (${pending.length})
        </button>
        <button class="admin-tab-btn ${this.adminFilterTab === 'approved' ? 'active' : ''}" data-af-tab="approved">
          Approved (${approved.length})
        </button>
        <button class="admin-tab-btn ${this.adminFilterTab === 'rejected' ? 'active' : ''}" data-af-tab="rejected">
          Rejected (${rejected.length})
        </button>
        <button class="admin-tab-btn ${this.adminFilterTab === 'all' ? 'active' : ''}" data-af-tab="all">
          All (${allDesserts.length})
        </button>
      </div>

      <!-- Search Box -->
      <div style="position:relative; margin-bottom:12px;">
        <input type="text" id="input-admin-search" placeholder="Search by student name or phone..." value="${this.adminSearchQuery}"
          style="width:100%; box-sizing:border-box; padding:10px 12px 10px 34px; border-radius:12px; border:1px solid #CBD5E1; font-size:12.5px; font-family:inherit;" />
        <span style="position:absolute; left:10px; top:50%; transform:translateY(-50%); font-size:14px; color:#94A3B8;">🔍</span>
      </div>

      <!-- Submissions List -->
      <div style="display:flex; flex-direction:column; gap:10px;">
        ${currentList.length === 0 ? `
          <div style="text-align:center; padding:32px 16px; background:#FFFFFF; border-radius:16px; border:1px dashed #CBD5E1; color:#64748B;">
            <div style="font-size:28px; margin-bottom:6px;">🎉</div>
            <div style="font-weight:700; font-size:13.5px; color:#0F172A;">All Clear!</div>
            <div style="font-size:11.5px; margin-top:2px;">No submissions found in this tab.</div>
          </div>
        ` : currentList.map(d => {
          const isPending = (d.status || '').toLowerCase() === 'pending';
          const isApp = (d.status || '').toLowerCase() === 'approved';
          const badgeClass = isApp ? 'quest-badge-green' : isPending ? 'quest-badge-orange' : 'quest-badge-blue';
          const label = isApp ? 'Approved ✓' : isPending ? 'Pending Review ⏳' : 'Needs Redo ⚠️';

          return `
            <div class="admin-submission-item">
              <div class="admin-sub-row-top">
                <div class="admin-sub-student">
                  <div class="admin-sub-avatar">${(d.studentName || 'S').charAt(0).toUpperCase()}</div>
                  <div>
                    <div style="font-size:13.5px; font-weight:800; color:#0F172A;">${d.studentName || 'Anonymous Scholar'}</div>
                    <div style="font-size:10.5px; color:#64748B;">${d.studentPhone || 'No Phone'}</div>
                  </div>
                </div>
                <span class="quest-status-badge ${badgeClass}">${label}</span>
              </div>

              <div>
                <div style="font-size:13px; font-weight:700; color:#1E293B;">${d.subject}</div>
                <div style="font-size:11.5px; color:#64748B; margin-top:2px;">${d.caption || 'Daily problem set submission'}</div>
              </div>

              ${d.mediaUrls && d.mediaUrls.length > 0 ? `
                <div style="display:flex; gap:6px; overflow-x:auto;">
                  ${d.mediaUrls.map(u => `
                    <img src="${u}" style="width:44px; height:44px; border-radius:8px; object-fit:cover; border:1px solid #CBD5E1;" />
                  `).join('')}
                </div>
              ` : ''}

              ${d.adminFeedback ? `
                <div style="background:#F8FAFC; border-left:3px solid #6366F1; border-radius:6px; padding:8px 10px; font-size:11px; color:#334155;">
                  <strong>Feedback:</strong> ${d.adminFeedback}
                </div>
              ` : ''}

              <div style="display:flex; justify-content:space-between; align-items:center; margin-top:4px; padding-top:8px; border-top:1px solid #F1F5F9;">
                <span style="font-size:11px; font-weight:800; color:#2563EB;">Award: +${d.creditsAwarded || 100} XP</span>
                <button class="admin-btn-grade" data-review-id="${d.id}">
                  <span>Review & Grade</span>
                  <span>➔</span>
                </button>
              </div>
            </div>
          `;
        }).join('')}
      </div>
    `;

    // Listeners
    document.getElementById('btn-exit-admin')?.addEventListener('click', () => {
      this.currentMode = 'student';
      this.renderApp();
    });

    container.querySelectorAll('[data-af-tab]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.adminFilterTab = btn.dataset.afTab;
        this.renderAdminDashboardScreen(container);
      });
    });

    document.getElementById('input-admin-search')?.addEventListener('input', (e) => {
      this.adminSearchQuery = e.target.value;
      this.renderAdminDashboardScreen(container);
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
    const papers = await dbService.getPaperSessions();

    container.innerHTML = `
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#EEF2FF; color:#4F46E5;">📋</div>
          <div>
            <div class="appbar-title">Manage Exam Papers</div>
            <div class="appbar-subtitle">Create sessions, schedule slots & proctor exams</div>
          </div>
        </div>
        <button class="btn-primary" id="btn-create-paper-dialog" style="width:auto; padding:8px 12px; font-size:12px;">
          + New Paper
        </button>
      </div>

      <div style="display:flex; flex-direction:column; gap:12px; margin-top:12px;">
        ${papers.map(p => `
          <div class="hero-card" style="padding:16px;">
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <span class="phase-pill ${p.isLive ? 'phase-live' : 'phase-upcoming'}">
                ${p.isLive ? '🔴 Writing in Progress' : '⏰ Scheduled'}
              </span>
              <span style="font-size:12px; font-weight:800; color:#2563EB;">⏱️ ${p.durationMinutes} Mins</span>
            </div>

            <div style="font-size:14.5px; font-weight:800; color:#0F172A; margin-top:8px;">${p.title}</div>
            <div style="font-size:11.5px; color:#64748B; margin-top:2px;">${p.subject}</div>

            <div style="display:flex; gap:8px; margin-top:12px;">
              <button class="btn-primary" style="flex:1; background:${p.isLive ? '#EF4444' : '#10B981'}; padding:10px; font-size:12px;" data-toggle-paper="${p.id}">
                ${p.isLive ? '⏹ End Live Session' : '▶ Start Live Writing'}
              </button>
              <button class="btn-primary" style="background:#F1F5F9; color:#334155; width:auto; padding:10px 14px; font-size:12px;" data-view-proctor="${p.id}">
                🎥 Proctor Hall
              </button>
            </div>
          </div>
        `).join('')}
      </div>
    `;

    document.getElementById('btn-create-paper-dialog')?.addEventListener('click', () => {
      this.openAdminCreatePaperModal();
    });

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

  // Create New Paper Dialog
  openAdminCreatePaperModal() {
    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.style.display = 'flex';

    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <div style="font-size:15px; font-weight:800; color:#0F172A;">Create Paper Session</div>
          <button class="modal-close-btn" id="btn-close-new-paper">✕</button>
        </div>

        <div style="display:flex; flex-direction:column; gap:10px;">
          <div>
            <div class="form-label">Paper Title:</div>
            <input type="text" id="new-paper-title" class="form-textarea" style="height:40px;" placeholder="e.g. 2027 A/L Physics Term Paper 02" />
          </div>

          <div>
            <div class="form-label">Units / Syllabus:</div>
            <input type="text" id="new-paper-units" class="form-textarea" style="height:40px;" placeholder="e.g. Mechanics, Waves & Oscillations" />
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

          <button class="btn-primary" id="btn-save-new-paper" style="margin-top:10px; padding:12px;">
            🚀 Publish Paper to Students
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

  // 3. Admin Sprints Screen (admin_mcq_sprint_screen.dart)
  renderAdminSprintsScreen(container) {
    const sprint = dbService.getDailySprint('today');

    container.innerHTML = `
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#FFF7ED; color:#EA580C;">⚡</div>
          <div>
            <div class="appbar-title">Daily MCQ Sprints</div>
            <div class="appbar-subtitle">5 Rapid Questions • Maintain Student Streaks</div>
          </div>
        </div>
      </div>

      <div style="display:flex; flex-direction:column; gap:12px; margin-top:12px;">
        <div class="hero-card" style="padding:16px;">
          <div style="font-size:12px; font-weight:800; color:#EA580C;">CURRENT ACTIVE SPRINT</div>
          <div style="font-size:15px; font-weight:800; color:#0F172A; margin-top:4px;">${sprint.title}</div>
          <div style="font-size:11.5px; color:#64748B;">Date: Today • Reward: +${sprint.xpBonus} XP</div>
        </div>

        <div style="font-size:13px; font-weight:800; color:#0F172A; margin-top:6px;">Questions Bank (5 Items):</div>

        ${sprint.questions.map((q, i) => `
          <div class="hero-card" style="padding:14px;">
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <span style="font-size:12px; font-weight:800; color:#2563EB;">Question 0${i + 1}</span>
              <span style="font-size:11px; background:#DCFCE7; color:#166534; padding:2px 8px; border-radius:10px; font-weight:800;">Correct: Option ${String.fromCharCode(65 + q.correctIndex)}</span>
            </div>
            <div style="font-size:12.5px; font-weight:700; color:#1E293B; margin-top:6px; line-height:1.4;">${q.text}</div>
            <div style="margin-top:8px; padding:8px; background:#EFF6FF; border-left:3px solid #3B82F6; border-radius:6px; font-size:11px; color:#1E40AF;">
              <strong>Explanation:</strong> ${q.explanation}
            </div>
          </div>
        `).join('')}
      </div>
    `;
  }

  // 4. Admin Students Screen (admin_students_screen.dart)
  async renderAdminStudentsScreen(container) {
    this.studentBatchFilter = this.studentBatchFilter || 'All Batches';
    this.studentSearchQuery = this.studentSearchQuery || '';

    const allStudents = await dbService.getAllStudents();

    let filtered = allStudents;
    if (this.studentBatchFilter !== 'All Batches') {
      filtered = filtered.filter(s => s.examYear === this.studentBatchFilter);
    }
    if (this.studentSearchQuery.trim()) {
      const q = this.studentSearchQuery.toLowerCase();
      filtered = filtered.filter(s => s.name.toLowerCase().includes(q) || s.phone.includes(q));
    }

    container.innerHTML = `
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#EFF6FF; color:#2563EB;">👥</div>
          <div>
            <div class="appbar-title">Student Directory</div>
            <div class="appbar-subtitle">${filtered.length} Enrolled Scholars</div>
          </div>
        </div>
      </div>

      <!-- Batch Filter & Search -->
      <div style="display:flex; gap:8px; margin:12px 0 10px;">
        <select id="select-admin-student-batch" class="form-textarea" style="height:38px; width:130px; padding:6px 8px; font-size:12px;">
          ${['All Batches', '2026 A/L', '2027 A/L', '2028 A/L'].map(b => `
            <option value="${b}" ${this.studentBatchFilter === b ? 'selected' : ''}>${b}</option>
          `).join('')}
        </select>
        <input type="text" id="input-admin-student-search" placeholder="Search student..." value="${this.studentSearchQuery}"
          style="flex:1; padding:8px 12px; border-radius:10px; border:1px solid #CBD5E1; font-size:12px;" />
      </div>

      <!-- Student Cards List -->
      <div style="display:flex; flex-direction:column; gap:8px;">
        ${filtered.map(st => `
          <div class="admin-student-card">
            <div style="display:flex; align-items:center; gap:10px;">
              <div class="admin-sub-avatar">${st.name.charAt(0).toUpperCase()}</div>
              <div>
                <div style="font-size:13.5px; font-weight:800; color:#0F172A;">${st.name}</div>
                <div style="font-size:11px; color:#64748B;">${st.phone} • <span style="color:#2563EB; font-weight:700;">${st.examYear}</span></div>
              </div>
            </div>

            <div style="display:flex; align-items:center; gap:10px;">
              <span style="font-size:12px; font-weight:900; color:#F59E0B;">${st.credits} XP</span>
              <button class="admin-verify-badge ${st.isVerified ? 'verified' : 'unverified'}" data-verify-id="${st.id}">
                ${st.isVerified ? 'Verified ✓' : 'Verify'}
              </button>
            </div>
          </div>
        `).join('')}
      </div>
    `;

    document.getElementById('select-admin-student-batch')?.addEventListener('change', (e) => {
      this.studentBatchFilter = e.target.value;
      this.renderAdminStudentsScreen(container);
    });

    document.getElementById('input-admin-student-search')?.addEventListener('input', (e) => {
      this.studentSearchQuery = e.target.value;
      this.renderAdminStudentsScreen(container);
    });

    container.querySelectorAll('[data-verify-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        const st = allStudents.find(x => x.id === btn.dataset.verifyId);
        if (st) {
          st.isVerified = !st.isVerified;
          notificationService.showInAppBanner('Verification Updated', `${st.name} is now ${st.isVerified ? 'Verified' : 'Unverified'}.`, 'info');
          this.renderAdminStudentsScreen(container);
        }
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
      <div class="screen-appbar">
        <div class="appbar-left">
          <div class="appbar-icon-box" style="background:#F0FDF4; color:#16A34A;">📢</div>
          <div>
            <div class="appbar-title">Push Broadcaster</div>
            <div class="appbar-subtitle">Send Instant Alerts to iOS & Android Devices</div>
          </div>
        </div>
      </div>

      <div class="hero-card" style="padding:16px; margin-top:12px;">
        <div class="form-label">Announcement Title:</div>
        <input type="text" id="bc-title" class="form-textarea" style="height:40px; margin-bottom:10px;" placeholder="e.g. 🔴 Paper 04 Live Exam Started!" />

        <div class="form-label">Notification Message Body:</div>
        <textarea id="bc-body" class="form-textarea" rows="3" style="margin-bottom:10px;" placeholder="Enter message to broadcast to all student home screens..."></textarea>

        <div class="form-label">Target Audience:</div>
        <select id="bc-audience" class="form-textarea" style="height:40px; margin-bottom:14px; padding:6px 10px;">
          <option value="All Batches">All Enrolled Batches</option>
          <option value="2026 A/L">2026 A/L Batch Only</option>
          <option value="2027 A/L">2027 A/L Batch Only</option>
        </select>

        <button class="btn-primary" id="btn-send-broadcast" style="padding:14px;">
          🚀 Send Broadcast with Chime Audio
        </button>
      </div>

      <div style="font-size:13px; font-weight:800; color:#0F172A; margin:16px 0 8px;">
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

      alert('🚀 Broadcast successfully dispatched to all student devices via Web Push!');
      this.renderAdminBroadcastsScreen(container);
    });
  }
}

window.addEventListener('DOMContentLoaded', () => {
  const app = new AppController();
  app.init();
});
