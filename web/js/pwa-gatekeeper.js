// EduPeak iOS PWA Gatekeeper
// Enforces that students on iOS / mobile MUST add the webapp to Home Screen (Standalone mode)
// before accessing the app, enabling iOS 16.4+ Web Push Notifications & Fullscreen App Experience.

export class PwaGatekeeper {
  constructor(options = {}) {
    this.onUnlocked = options.onUnlocked || (() => {});
    this.container = null;
    this.isUnlocked = false;
  }

  isStandaloneMode() {
    // 1. iOS Safari standalone property
    if (window.navigator.standalone === true) return true;

    // 2. Standard CSS media query for installed PWAs
    if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) return true;
    if (window.matchMedia && window.matchMedia('(display-mode: fullscreen)').matches) return true;
    if (window.matchMedia && window.matchMedia('(display-mode: minimal-ui)').matches) return true;

    // 3. Android Trusted Web Activity / referrer check
    if (document.referrer.includes('android-app://')) return true;

    // 4. Developer / Admin test bypass flag
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('dev') === 'true' || urlParams.get('preview') === 'true') return true;
    if (sessionStorage.getItem('edupeak_dev_bypass') === 'true') return true;

    return false;
  }

  isIOS() {
    return (
      /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
    );
  }

  init() {
    if (this.isStandaloneMode()) {
      this.unlockApp();
      return;
    }

    this.renderGatekeeper();
    this.attachEventListeners();
  }

  unlockApp() {
    this.isUnlocked = true;
    const gatekeeperEl = document.getElementById('pwa-gatekeeper-overlay');
    if (gatekeeperEl) {
      gatekeeperEl.classList.add('fade-out');
      setTimeout(() => {
        gatekeeperEl.remove();
      }, 350);
    }
    const appEl = document.getElementById('app-root');
    if (appEl) {
      appEl.classList.remove('app-locked');
      appEl.classList.add('app-unlocked');
    }
    this.onUnlocked();
  }

  renderGatekeeper() {
    const isIos = this.isIOS();
    const isMobile = window.innerWidth <= 768;

    const overlay = document.createElement('div');
    overlay.id = 'pwa-gatekeeper-overlay';
    overlay.className = 'gatekeeper-overlay';
    overlay.innerHTML = `
      <div class="gatekeeper-ambient-glow glow-1"></div>
      <div class="gatekeeper-ambient-glow glow-2"></div>

      <div class="gatekeeper-card">
        <!-- Top App Emblem -->
        <div class="gatekeeper-header">
          <div class="gatekeeper-icon-wrap">
            <img src="./icons/icon-192.png" alt="EduPeak" class="gatekeeper-icon" onerror="this.src='./icons/icon.svg'" />
            <div class="icon-ring-pulse"></div>
          </div>
          <span class="gatekeeper-badge">iOS Home Screen Required</span>
          <h1 class="gatekeeper-title">Install EduPeak on Your Home Screen</h1>
          <p class="gatekeeper-subtitle">
            To enable real-time <strong>Push Notifications</strong>, <strong>Camera Document Scanning</strong>, and <strong>Live Exam Proctoring</strong>, Apple requires EduPeak to run from your Home Screen.
          </p>
        </div>

        <!-- Visual Step-by-Step Instructions -->
        <div class="gatekeeper-steps">
          <div class="step-card">
            <div class="step-num">1</div>
            <div class="step-content">
              <div class="step-title">Tap Safari Share Button</div>
              <div class="step-desc">
                Tap the <strong>Share</strong> icon in your Safari bottom navigation bar.
              </div>
            </div>
            <div class="step-icon-box">
              <!-- iOS Share Icon -->
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/>
                <polyline points="16 6 12 2 8 6"/>
                <line x1="12" y1="2" x2="12" y2="15"/>
              </svg>
            </div>
          </div>

          <div class="step-card">
            <div class="step-num">2</div>
            <div class="step-content">
              <div class="step-title">Select "Add to Home Screen"</div>
              <div class="step-desc">
                Scroll down the share sheet and tap <strong>Add to Home Screen</strong>.
              </div>
            </div>
            <div class="step-icon-box">
              <!-- iOS Add to Home Icon -->
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="3" width="18" height="18" rx="4"/>
                <line x1="12" y1="8" x2="12" y2="16"/>
                <line x1="8" y1="12" x2="16" y2="12"/>
              </svg>
            </div>
          </div>

          <div class="step-card">
            <div class="step-num">3</div>
            <div class="step-content">
              <div class="step-title">Tap "Add" & Launch</div>
              <div class="step-desc">
                Confirm by tapping <strong>Add</strong> in the top-right corner, then open the <strong>EduPeak</strong> app from your Home Screen!
              </div>
            </div>
            <div class="step-icon-box">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="20 6 9 17 4 12"/>
              </svg>
            </div>
          </div>
        </div>

        <!-- Live Status Bar / Pulsing Verification -->
        <div class="gatekeeper-status-box">
          <div class="status-pulse-dot"></div>
          <span class="status-text">Waiting for launch from Home Screen...</span>
          <button id="btn-recheck-standalone" class="btn-recheck">Re-check</button>
        </div>

        <!-- Developer / Desktop Testing Bypass for Local Preview -->
        <div class="gatekeeper-dev-footer">
          <button id="btn-dev-preview" class="btn-dev-preview">
            🖥️ Desktop Testing Mode (Click to Preview App)
          </button>
          <div class="dev-hint">Students must launch via iPhone Home Screen for push notifications</div>
        </div>
      </div>

      <!-- Animated Pointer for iOS Safari Bottom Bar -->
      <div class="safari-arrow-indicator ${isIos ? 'active' : ''}">
        <span class="arrow-text">Tap Share below</span>
        <div class="bouncing-arrow">↓</div>
      </div>
    `;

    document.body.appendChild(overlay);

    // Lock main app
    const appEl = document.getElementById('app-root');
    if (appEl) {
      appEl.classList.add('app-locked');
    }
  }

  attachEventListeners() {
    // Re-check button
    const recheckBtn = document.getElementById('btn-recheck-standalone');
    if (recheckBtn) {
      recheckBtn.addEventListener('click', () => {
        if (this.isStandaloneMode()) {
          this.unlockApp();
        } else {
          recheckBtn.textContent = '❌ Still in Browser';
          setTimeout(() => {
            recheckBtn.textContent = 'Re-check';
          }, 1500);
        }
      });
    }

    // Dev preview bypass button for desktop testing
    const devBtn = document.getElementById('btn-dev-preview');
    if (devBtn) {
      devBtn.addEventListener('click', () => {
        sessionStorage.setItem('edupeak_dev_bypass', 'true');
        this.unlockApp();
      });
    }

    // Auto-detect when app switches from background to foreground or display mode changes
    window.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible' && this.isStandaloneMode()) {
        this.unlockApp();
      }
    });

    window.matchMedia('(display-mode: standalone)').addEventListener('change', (e) => {
      if (e.matches) {
        this.unlockApp();
      }
    });
  }
}
