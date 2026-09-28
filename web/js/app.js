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
    // 1. Initialize PWA Gatekeeper for iOS Add to Home Screen enforcement
    const gatekeeper = new PwaGatekeeper({
      onUnlocked: () => {
        console.log('[App] PWA Standalone Mode active.');
        this.renderApp();
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

  // ── 2. Papers Tab (Exam Sessions) ─────────────────────────────────────────
  async renderPapersScreen(container) {
    const papers = await dbService.getPaperSessions();
    container.innerHTML = `
      <div style="font-size: 18px; font-weight:800; color: #0F172A; margin-bottom: 12px; display:flex; align-items:center; gap:8px;">
        <span>📋</span>
        <span>A/L Physics Paper Sessions</span>
      </div>

      <div style="display:flex; flex-direction:column; gap:14px;">
        ${papers.map(p => `
          <div class="hero-card" style="padding: 18px;">
            <div style="display:flex; align-items:center; justify-content:space-between;">
              <span class="quests-badge">${p.isLive ? '🔴 LIVE NOW' : 'SCHEDULED'}</span>
              <span style="font-size:12px; font-weight:700; color:#2563EB;">⏱️ ${p.durationMinutes} Mins</span>
            </div>
            <div style="font-size:16px; font-weight:800; color:#0F172A; margin-top:8px;">${p.title}</div>
            <div style="font-size:12px; color:#64748B;">${p.subject}</div>
            <div style="display:flex; justify-content:space-between; align-items:center; border-top:1px solid #E2E8F0; padding-top:12px; margin-top:8px;">
              <span style="font-size:11.5px; font-weight:600; color:#64748B;">Full Score: ${p.totalMarks} Marks</span>
              <button class="btn-primary" style="width:auto; padding:8px 16px; font-size:12px;" data-paper-join="${p.id}">
                📹 Enter Exam Room
              </button>
            </div>
          </div>
        `).join('')}
      </div>
    `;

    container.querySelectorAll('[data-paper-join]').forEach(b => {
      b.addEventListener('click', () => {
        this.openLiveExamRoom(b.dataset.paperJoin);
      });
    });
  }

  // ── 3. Ranks Tab (Podium & Leaderboard) ────────────────────────────────────
  async renderRanksScreen(container) {
    const leaders = await dbService.getLeaderboard();
    const top3 = leaders.slice(0, 3);
    const rest = leaders.slice(3);

    container.innerHTML = `
      <div style="font-size: 18px; font-weight:800; color: #0F172A; margin-bottom: 14px; display:flex; align-items:center; gap:8px;">
        <span>🏆</span>
        <span>Island-Wide Physics Leaderboard</span>
      </div>

      <!-- Top 3 Podium Cards -->
      <div style="display:grid; grid-template-columns: 1fr 1.15fr 1fr; gap: 8px; align-items:flex-end; margin-bottom: 16px;">
        <!-- Rank 2 -->
        ${top3[1] ? `
          <div style="background:#FFFFFF; border:1px solid #E2E8F0; border-radius:18px; padding:14px 6px; text-align:center; box-shadow:0 4px 12px rgba(0,0,0,0.03);">
            <div style="font-size:22px;">🥈</div>
            <div style="font-size:12px; font-weight:800; color:#0F172A; margin-top:4px;">${top3[1].name.split(' ')[0]}</div>
            <div style="font-size:11px; color:#2563EB; font-weight:800;">${top3[1].credits} XP</div>
          </div>
        ` : ''}

        <!-- Rank 1 (Gold) -->
        ${top3[0] ? `
          <div style="background:linear-gradient(135deg, #FEF3C7, #FDE68A); border:2px solid #F59E0B; border-radius:20px; padding:18px 8px; text-align:center; box-shadow:0 8px 20px rgba(245,158,11,0.25);">
            <div style="font-size:28px;">👑</div>
            <div style="font-size:13px; font-weight:800; color:#78350F; margin-top:4px;">${top3[0].name.split(' ')[0]}</div>
            <div style="font-size:12px; color:#B45309; font-weight:900;">${top3[0].credits} XP</div>
          </div>
        ` : ''}

        <!-- Rank 3 -->
        ${top3[2] ? `
          <div style="background:#FFFFFF; border:1px solid #E2E8F0; border-radius:18px; padding:12px 6px; text-align:center; box-shadow:0 4px 12px rgba(0,0,0,0.03);">
            <div style="font-size:20px;">🥉</div>
            <div style="font-size:12px; font-weight:800; color:#0F172A; margin-top:4px;">${top3[2].name.split(' ')[0]}</div>
            <div style="font-size:11px; color:#2563EB; font-weight:800;">${top3[2].credits} XP</div>
          </div>
        ` : ''}
      </div>

      <!-- Rest of list -->
      <div style="display:flex; flex-direction:column; gap:8px;">
        ${rest.map(r => `
          <div style="background:#FFFFFF; border:1px solid #E2E8F0; border-radius:14px; padding:12px 16px; display:flex; align-items:center; justify-content:space-between; box-shadow:0 2px 6px rgba(0,0,0,0.02);">
            <div style="display:flex; align-items:center; gap:12px;">
              <span style="font-size:13px; font-weight:800; color:#64748B; width:22px;">#${r.rank}</span>
              <div>
                <div style="font-size:13px; font-weight:700; color:#0F172A;">${r.name}</div>
                <div style="font-size:11px; color:#64748B;">${r.examYear}</div>
              </div>
            </div>
            <span style="font-size:13px; font-weight:800; color:#2563EB;">${r.credits} XP</span>
          </div>
        `).join('')}
      </div>
    `;
  }

  // ── 4. Desserts Tab (Homework Submissions & History) ───────────────────────
  async renderDessertsScreen(container) {
    const user = this.currentUser || {};
    const desserts = await dbService.getStudentDesserts(user.uid, user.phone);

    container.innerHTML = `
      <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:14px;">
        <span style="font-size: 18px; font-weight:800; color: #0F172A;">📁 Dessert Homework</span>
        <button class="btn-primary" style="width:auto; padding:8px 14px; font-size:12px;" id="btn-desserts-scan">
          📷 Scan & Submit
        </button>
      </div>

      <div style="display:flex; flex-direction:column; gap:12px;">
        ${desserts.map(d => {
          const isApproved = d.status === 'approved';
          const isPending = d.status === 'pending';
          const badgeClass = isApproved ? 'quest-badge-green' : isPending ? 'quest-badge-orange' : 'quest-badge-orange';
          const label = isApproved ? 'Approved ✓' : isPending ? 'In Review ⏳' : 'Needs Redo ⚠️';

          return `
            <div class="hero-card" style="padding:16px;" data-dessert-id="${d.id}">
              <div style="display:flex; align-items:center; justify-content:space-between;">
                <span class="quest-status-badge ${badgeClass}">${label}</span>
                <span style="font-size:11.5px; font-weight:700; color:#2563EB;">+${d.creditsAwarded || 0} XP</span>
              </div>
              <div style="font-size:14.5px; font-weight:800; color:#0F172A; margin-top:8px;">${d.subject}</div>
              <div style="font-size:12px; color:#64748B; margin-top:2px;">${d.caption || 'No note added'}</div>
              ${d.adminFeedback ? `
                <div style="margin-top:10px; padding:10px; background:#EFF6FF; border-left:3px solid #2563EB; border-radius:6px; font-size:11.5px; color:#1E3A8A;">
                  <strong>Teacher Feedback:</strong> ${d.adminFeedback}
                </div>
              ` : ''}
            </div>
          `;
        }).join('')}
      </div>
    `;

    document.getElementById('btn-desserts-scan')?.addEventListener('click', () => {
      this.openDocumentScanner();
    });
  }

  // ── 5. Profile Tab ────────────────────────────────────────────────────────
  renderProfileScreen(container) {
    const user = this.currentUser || {};
    const isStandalone = window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches;

    container.innerHTML = `
      <div style="font-size: 18px; font-weight:800; color: #0F172A; margin-bottom: 14px;">
        👤 Student Profile & Settings
      </div>

      <div class="hero-card" style="align-items:center; text-align:center; padding:24px;">
        <div class="avatar-ring" style="width:72px; height:72px; font-size:28px;">
          <div class="avatar-img">${user.name ? user.name.charAt(0).toUpperCase() : 'T'}</div>
        </div>
        <div style="font-size:18px; font-weight:800; color:#0F172A; margin-top:10px;">${user.name || 'ThiZaru'}</div>
        <div style="font-size:12.5px; color:#64748B;">${user.examYear || '2027 A/L Candidate'} • ID: ${user.studentId || 'EP-2027'}</div>

        <div style="margin-top:12px; padding:6px 14px; border-radius:20px; font-size:11.5px; font-weight:800; background: ${isStandalone ? '#ECFDF5' : '#FEF3C7'}; color: ${isStandalone ? '#047857' : '#B45309'}; border: 1px solid ${isStandalone ? '#A7F3D0' : '#FDE68A'};">
          ${isStandalone ? '🟢 Running on iPhone Home Screen (PWA Mode)' : '⚠️ Safari Browser Tab'}
        </div>
      </div>

      <div style="display:flex; flex-direction:column; gap:10px; margin-top:14px;">
        <button class="hero-card" style="padding:14px; flex-direction:row; align-items:center; justify-content:space-between; cursor:pointer;" id="btn-profile-notifs">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:20px;">🔔</span>
            <div style="text-align:left;">
              <div style="font-size:13px; font-weight:700; color:#0F172A;">Web Push Notifications</div>
              <div style="font-size:11px; color:#64748B;">Enable & Test iOS 16.4+ Alert Banners</div>
            </div>
          </div>
          <span style="color:#94A3B8;">➔</span>
        </button>

        <button class="hero-card" style="padding:14px; flex-direction:row; align-items:center; justify-content:space-between; cursor:pointer;" id="btn-profile-scanner">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:20px;">📷</span>
            <div style="text-align:left;">
              <div style="font-size:13px; font-weight:700; color:#0F172A;">Camera Scanner</div>
              <div style="font-size:11px; color:#64748B;">Test Rear Document Scanner & Filters</div>
            </div>
          </div>
          <span style="color:#94A3B8;">➔</span>
        </button>

        <button class="btn-primary" style="background:#EF4444; margin-top:10px;" id="btn-profile-logout">
          Sign Out
        </button>
      </div>
    `;

    document.getElementById('btn-profile-notifs')?.addEventListener('click', () => {
      this.openNotificationCenter();
    });

    document.getElementById('btn-profile-scanner')?.addEventListener('click', () => {
      this.openDocumentScanner();
    });

    document.getElementById('btn-profile-logout')?.addEventListener('click', () => {
      authService.logout();
      location.reload();
    });
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

  // ── Daily MCQ Sprint Modal ────────────────────────────────────────────────
  openSprintDialog() {
    const sprint = dbService.getDailySprint();
    const q = sprint.questions[0];

    const modal = document.createElement('div');
    modal.className = 'app-modal';
    modal.innerHTML = `
      <div class="modal-sheet">
        <div class="modal-header">
          <h3 class="modal-title">⚡ Dynamics & Newton's Laws</h3>
          <button class="modal-close-btn" id="btn-close-sprint-sheet">✕</button>
        </div>

        <div style="display:flex; justify-content:space-between; margin-bottom:12px; font-size:12px; font-weight:700;">
          <span style="color:#EA580C;">Question 1 of 5</span>
          <span style="color:#2563EB;">⏱️ 60s remaining</span>
        </div>

        <div style="font-size:14px; font-weight:700; color:#0F172A; line-height:1.5; margin-bottom:14px;">
          ${q.text}
        </div>

        <div style="display:flex; flex-direction:column; gap:8px; margin-bottom:16px;">
          ${q.options.map((opt, i) => `
            <div style="padding:10px 14px; background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; font-size:13px; font-weight:600; cursor:pointer;" class="sprint-opt-item" data-idx="${i}">
              ${String.fromCharCode(65 + i)}. ${opt}
            </div>
          `).join('')}
        </div>

        <button class="btn-primary" id="btn-submit-sprint-opt">
          Confirm Answer (+15 XP)
        </button>
      </div>
    `;

    document.body.appendChild(modal);
    let selected = null;

    modal.querySelectorAll('.sprint-opt-item').forEach(el => {
      el.addEventListener('click', () => {
        modal.querySelectorAll('.sprint-opt-item').forEach(x => {
          x.style.background = '#F8FAFC';
          x.style.borderColor = '#E2E8F0';
        });
        el.style.background = '#EFF6FF';
        el.style.borderColor = '#2563EB';
        selected = el.dataset.idx;
      });
    });

    document.getElementById('btn-close-sprint-sheet')?.addEventListener('click', () => modal.remove());
    document.getElementById('btn-submit-sprint-opt')?.addEventListener('click', () => {
      if (selected === null) return;
      alert('Answer recorded! +15 XP added to your island ranking.');
      modal.remove();
    });
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
}

window.addEventListener('DOMContentLoaded', () => {
  const app = new AppController();
  app.init();
});
