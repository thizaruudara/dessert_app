// EduPeak PWA Gatekeeper & Home Screen Installer
// Enforces Add to Home Screen (A2HS) / PWA installation on mobile and desktop
// Accurately detects OS & Browser and provides smart natural Sinhala + English mixed instructions.
// Matches EduPeak Light Master Design System.

export class PwaGatekeeper {
  constructor(options = {}) {
    this.onUnlocked = options.onUnlocked || (() => {});
    this.container = null;
    this.isUnlocked = false;
    this.deferredPrompt = window.__edupeakInstallPrompt || null;

    // Listen for beforeinstallprompt globally
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      this.deferredPrompt = e;
      window.__edupeakInstallPrompt = e;
      this.updateInstallButtonVisibility();
    });
  }

  isStandaloneMode() {
    // 1. iOS Safari standalone property
    if (window.navigator.standalone === true) return true;

    // 2. Standard CSS media query for installed PWAs
    if (window.matchMedia) {
      if (window.matchMedia('(display-mode: standalone)').matches) return true;
      if (window.matchMedia('(display-mode: fullscreen)').matches) return true;
      if (window.matchMedia('(display-mode: minimal-ui)').matches) return true;
    }

    // 3. Android Trusted Web Activity / referrer check
    if (document.referrer && document.referrer.includes('android-app://')) return true;

    // 4. Developer / Admin test bypass flag
    const urlParams = new URLSearchParams(window.location.search);
    if (
      urlParams.get('dev') === 'true' ||
      urlParams.get('preview') === 'true' ||
      urlParams.get('bypass') === 'true' ||
      sessionStorage.getItem('edupeak_dev_bypass') === 'true'
    ) {
      return true;
    }

    return false;
  }

  detectPlatform() {
    const ua = navigator.userAgent || '';
    const platform = navigator.platform || '';

    const isIOS = /iPad|iPhone|iPod/.test(ua) || (platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const isAndroid = /Android/i.test(ua);
    const isWindows = /Windows/i.test(ua);
    const isMac = /Macintosh/i.test(ua) && !isIOS;
    const isLinux = /Linux/i.test(ua) && !isAndroid;

    // In-app browsers: Facebook, Instagram, WhatsApp, Messenger, Telegram, TikTok, WeChat, etc.
    const isInApp = /FBAN|FBAV|Instagram|WhatsApp|Line|Snapchat|TikTok|MicroMessenger|Telegram/i.test(ua) ||
                    (isAndroid && /Version\/[0-9.]+/i.test(ua) && !/Chrome\/[0-9.]+/i.test(ua));

    let browser = 'other';
    let browserName = 'Browser';

    if (isInApp) {
      browser = 'inapp';
      browserName = 'In-App Webview';
    } else if (/Edg\/|EdgiOS|EdgA/i.test(ua)) {
      browser = 'edge';
      browserName = 'Microsoft Edge';
    } else if (/SamsungBrowser/i.test(ua)) {
      browser = 'samsung';
      browserName = 'Samsung Internet';
    } else if (/CriOS/i.test(ua) || (/Chrome/i.test(ua) && !/Edge|Edg|OPR/i.test(ua))) {
      browser = 'chrome';
      browserName = 'Google Chrome';
    } else if (/Safari/i.test(ua) && !/Chrome|CriOS|Android/i.test(ua)) {
      browser = 'safari';
      browserName = 'Apple Safari';
    } else if (/Firefox|FxiOS/i.test(ua)) {
      browser = 'firefox';
      browserName = 'Mozilla Firefox';
    }

    let os = 'other';
    let osName = 'Device';
    if (isIOS) {
      os = 'ios';
      osName = 'Apple iOS (iPhone / iPad)';
    } else if (isAndroid) {
      os = 'android';
      osName = 'Android Mobile';
    } else if (isWindows) {
      os = 'windows';
      osName = 'Windows PC';
    } else if (isMac) {
      os = 'mac';
      osName = 'macOS';
    } else if (isLinux) {
      os = 'linux';
      osName = 'Linux';
    }

    return {
      os,
      osName,
      browser,
      browserName,
      isIOS,
      isAndroid,
      isMobile: isIOS || isAndroid,
      isInApp
    };
  }

  getInstructions(platform) {
    const { os, browser, isInApp, osName, browserName } = platform;

    let title = '';
    let subtitle = '';
    let badge = '';
    let steps = [];
    let showSafariArrow = false;
    let allowNativeInstall = Boolean(this.deferredPrompt);
    let showCopyLink = false;

    // 1. In-App Browser Warning (Critical: cannot add to home screen inside facebook/whatsapp webview)
    if (isInApp) {
      badge = '⚠️ External Browser එකක් අවශ්‍යයි';
      title = 'Chrome හෝ Safari මගින් Open කරගන්න';
      subtitle = 'ඔබ මෙම පිටුව විවෘත කර ඇත්තේ Social Media App එකක් (WhatsApp/FB) තුළිනි. Add to Home Screen කිරීම සඳහා කරුණාකර ප්‍රධාන Browser එකෙන් Open කරන්න.';
      showCopyLink = true;

      steps = [
        {
          num: '1',
          title: 'Menu (⋮ හෝ ⋯) හෝ Share Icon එක Tap කරන්න',
          desc: 'ඉහළ හෝ පහළ කෙළවරේ ඇති 3-dots Menu එක (⋮ හෝ ⋯) හෝ Share අයිකනය Tap කරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="19" r="1.5"/></svg>`
        },
        {
          num: '2',
          title: '"Open in Chrome" හෝ "Open in Safari" තෝරන්න',
          desc: 'මෙනුවෙන් <strong>"Open in external browser"</strong> / <strong>"Open in Chrome / Safari"</strong> තෝරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>`
        },
        {
          num: '3',
          title: 'Home Screen එකට Add කරගන්න',
          desc: 'විවෘත වන Browser එකෙන් Add to Home Screen කර EduPeak App එකෙන් පිවිසෙන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        }
      ];
    }
    // 2. Apple iOS - Safari
    else if (os === 'ios' && (browser === 'safari' || browser === 'other')) {
      badge = '🍎 iOS Home Screen Required';
      title = 'EduPeak App එක Home Screen එකට Add කරගන්න';
      subtitle = 'විභාග සඳහා <strong>Live Camera Proctoring</strong>, <strong>Real-Time Push Alerts</strong> සහ <strong>Fullscreen Exam Mode</strong> පහසුකම් සඳහා EduPeak App එක Home Screen එකෙන් Open කිරීම අනිවාර්ය වේ.';
      showSafariArrow = true;

      steps = [
        {
          num: '1',
          title: 'Safari පහළ ඇති Share Icon (⎋) එක Tap කරන්න',
          desc: 'Safari හි පහළ navigation bar එකේ ඇති Share බොත්තම (කොටුව තුළ උඩ ඊතලය) Tap කරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/></svg>`
        },
        {
          num: '2',
          title: 'Share sheet එකෙන් "Add to Home Screen" (+) තෝරන්න',
          desc: 'මෙනුවේ පහළට Scroll කර ➕ <strong>"Add to Home Screen"</strong> option එක තෝරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        },
        {
          num: '3',
          title: 'ඉහළ ඇති "Add" Click කර App එකෙන් Open කරන්න',
          desc: 'ඉහළ දකුණු කෙළවරේ ඇති <strong>"Add"</strong> ඔබා, Home Screen එකේ හැදුනු <strong>EduPeak App</strong> icon එකෙන් පිවිසෙන්න!',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>`
        }
      ];
    }
    // 3. Apple iOS - Non-Safari (Chrome, Edge, Firefox on iPhone)
    else if (os === 'ios') {
      badge = '🍎 Apple Safari Browser Required';
      title = 'EduPeak Link එක Safari මගින් Open කරන්න';
      subtitle = 'Apple iOS වල Web Push Notifications සහ Home Screen App පහසුකම් ලබාදෙන්නේ <strong>Apple Safari Browser</strong> හරහා පමණි.';
      showCopyLink = true;

      steps = [
        {
          num: '1',
          title: 'EduPeak Link එක Copy කරගන්න',
          desc: 'පහත ඇති "Copy Link" බොත්තම ඔබා EduPeak web address එක Copy කරගන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>`
        },
        {
          num: '2',
          title: 'Apple Safari Browser එක Open කරන්න',
          desc: 'ඔබේ iPhone හි ඇති Safari Browser එක Open කර Copy කරගත් Link එක Paste කර පිවිසෙන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="10"/><polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/></svg>`
        },
        {
          num: '3',
          title: 'Share (⎋) මගින් Add to Home Screen කරන්න',
          desc: 'Safari පහළ ඇති Share icon එක (⎋) ඔබා "Add to Home Screen" තෝරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        }
      ];
    }
    // 4. Android - Google Chrome
    else if (os === 'android' && browser === 'chrome') {
      badge = '🤖 Android Home Screen App';
      title = 'EduPeak App එක Phone එකට Install කරගන්න';
      subtitle = 'විභාග අතරතුර accidental tab switches වැළැක්වීමට සහ <strong>Real-Time Paper Push Alerts</strong> ලබාගැනීමට EduPeak Home Screen App එකක් ලෙස Use කරන්න.';
      allowNativeInstall = true;

      steps = [
        {
          num: '1',
          title: 'Chrome Menu හි තිත් 3 (⋮) Tap කරන්න',
          desc: 'Chrome browser හි ඉහළ දකුණු කෙළවරේ ඇති 3-dots Menu (⋮) icon එක Tap කරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="19" r="1.5"/></svg>`
        },
        {
          num: '2',
          title: '"Install app" හෝ "Add to Home screen" තෝරන්න',
          desc: 'Menu එකෙන් <strong>"Install app"</strong> හෝ <strong>"Add to Home screen"</strong> option එක තෝරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>`
        },
        {
          num: '3',
          title: '"Install" Confirm කර App එකෙන් Open කරන්න',
          desc: 'පෙන්වන dialog එකේ <strong>"Install"</strong> ඔබා Home Screen එකේ හැදෙන <strong>EduPeak App</strong> icon එකෙන් පිවිසෙන්න!',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>`
        }
      ];
    }
    // 5. Android - Samsung Internet / Other Browser
    else if (os === 'android') {
      badge = '📱 Android Home Screen Installation';
      title = 'EduPeak App එක Home Screen එකට Add කරගන්න';
      subtitle = 'විභාග සහ Push Alerts පහසුකම් ලබාගැනීමට EduPeak යෙදුම ඔබගේ Phone එකේ Home Screen එකට Add කරගන්න.';
      allowNativeInstall = true;

      steps = [
        {
          num: '1',
          title: 'Browser Menu (☰ හෝ ⋮) එක Tap කරන්න',
          desc: 'පහළ හෝ ඉහළ කෙළවරේ ඇති Menu බොත්තම Tap කරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></svg>`
        },
        {
          num: '2',
          title: '"+ Add page to" ➔ "Home screen" තෝරන්න',
          desc: 'මෙනුවෙන් <strong>"+ Add page to"</strong> තෝරා <strong>"Home screen"</strong> option එක Click කරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        },
        {
          num: '3',
          title: '"Add" Confirm කර App එකෙන් Open කරන්න',
          desc: '"Add" ඔබා Confirm කර Home Screen එකේ හැදෙන EduPeak App එකෙන් පිවිසෙන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>`
        }
      ];
    }
    // 6. Desktop (Windows, Mac, Linux)
    else {
      badge = '💻 Desktop App Installation';
      title = 'EduPeak App එක පරිගණකයට Install කරගන්න';
      subtitle = 'වේගවත් performance, dedicated window සහ fullscreen exam mode අත්දැකීමක් සඳහා EduPeak App එක PC / Laptop එකට Install කරගන්න.';
      allowNativeInstall = true;

      steps = [
        {
          num: '1',
          title: 'Address Bar එකේ ඇති Install Icon (⊕) එක Click කරන්න',
          desc: 'Browser එකේ ඉහළ URL Address Bar එකේ දකුණු පස ඇති Install / App icon එක Click කරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        },
        {
          num: '2',
          title: 'නැතහොත් Chrome Menu (⋮) ➔ "Install EduPeak" තෝරන්න',
          desc: 'Browser Menu (⋮) එකෙන් <strong>"Save and share"</strong> හෝ <strong>"Install EduPeak"</strong> Click කරන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="19" r="1.5"/></svg>`
        },
        {
          num: '3',
          title: '"Install" Click කර Desktop App එකෙන් පිවිසෙන්න',
          desc: 'Confirm dialog එකේ <strong>"Install"</strong> ඔබා Desktop App එකක් ලෙස standalone විවෘත කරගන්න.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>`
        }
      ];
    }

    return {
      title,
      subtitle,
      badge,
      steps,
      showSafariArrow,
      allowNativeInstall,
      showCopyLink,
      deviceLabel: `${osName} • ${browserName}`
    };
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
      }, 300);
    }
    const appEl = document.getElementById('app-root');
    if (appEl) {
      appEl.classList.remove('app-locked');
      appEl.classList.add('app-unlocked');
    }
    this.onUnlocked();
  }

  renderGatekeeper() {
    const existing = document.getElementById('pwa-gatekeeper-overlay');
    if (existing) existing.remove();

    const platform = this.detectPlatform();
    const info = this.getInstructions(platform);

    const overlay = document.createElement('div');
    overlay.id = 'pwa-gatekeeper-overlay';
    overlay.className = 'gatekeeper-overlay';
    overlay.innerHTML = `
      <div class="gatekeeper-ambient-glow glow-1"></div>
      <div class="gatekeeper-ambient-glow glow-2"></div>

      <div class="gatekeeper-card">
        <!-- Top bar with detected device chip -->
        <div class="gatekeeper-top-bar" style="display:flex; justify-content:center; align-items:center; margin-bottom:12px;">
          <div class="gatekeeper-device-chip" title="${info.deviceLabel}">
            <span>${platform.isIOS ? '🍏 iOS' : platform.isAndroid ? '🤖 Android' : '💻 PC'}</span>
            <span>•</span>
            <span>${platform.browserName}</span>
          </div>
        </div>

        <div class="gatekeeper-header">
          <div class="gatekeeper-icon-wrap">
            <img src="./icons/edupeak_logo.png" alt="EduPeak" class="gatekeeper-icon" onerror="this.src='./icons/icon-192.png'" />
            <div class="icon-ring-pulse"></div>
          </div>
          <span class="gatekeeper-badge">${info.badge}</span>
          <h1 class="gatekeeper-title">${info.title}</h1>
          <p class="gatekeeper-subtitle">${info.subtitle}</p>
        </div>

        <!-- One-Tap Native Install Button (Android / Chromium only via beforeinstallprompt) -->
        <div id="native-install-wrapper" style="margin-bottom:14px; ${(!platform.isIOS && this.deferredPrompt) ? 'display:block;' : 'display:none;'}">
          <button id="btn-native-install" class="btn-native-install">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            <span>EduPeak App එක දැන්ම Install කරගන්න 📲</span>
          </button>
        </div>

        <!-- Visual Step-by-Step Instructions -->
        <div class="gatekeeper-steps">
          ${info.steps.map(s => `
            <div class="step-card">
              <div class="step-num">${s.num}</div>
              <div class="step-content">
                <div class="step-title">${s.title}</div>
                <div class="step-desc">${s.desc}</div>
              </div>
              <div class="step-icon-box">
                ${s.icon}
              </div>
            </div>
          `).join('')}
        </div>

        ${info.showCopyLink ? `
          <div style="margin-bottom:14px;">
            <button id="btn-copy-web-link" class="btn-copy-web-link">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
              <span>EduPeak Link එක Copy කරගන්න (Copy Link)</span>
            </button>
          </div>
        ` : ''}

        <!-- Live Status Bar & Recheck Verification -->
        <div class="gatekeeper-status-box">
          <div class="status-pulse-dot"></div>
          <span class="status-text">Home Screen එකෙන් Open කරන තෙක් රැඳී සිටින්න...</span>
          <button id="btn-recheck-standalone" class="btn-recheck" style="white-space:nowrap;">
            නැවත Check කරන්න ↻
          </button>
        </div>

        <!-- Testing / Temporary Bypass Footer -->
        <div class="gatekeeper-dev-footer">
          <button id="btn-browser-bypass" class="btn-dev-preview">
            Browser එකෙන් Continue කරන්න (විභාග පහසුකම් සීමා විය හැක) →
          </button>
        </div>
      </div>

      <!-- Animated Pointer for iOS Safari Bottom Bar -->
      <div class="safari-arrow-indicator ${info.showSafariArrow ? 'active' : ''}">
        <span class="arrow-text">පහළ ඇති Share බොත්තම ඔබන්න</span>
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

  updateInstallButtonVisibility() {
    const platform = this.detectPlatform();
    const wrapper = document.getElementById('native-install-wrapper');
    if (wrapper && !platform.isIOS && this.deferredPrompt) {
      wrapper.style.display = 'block';
    }
  }

  attachEventListeners() {
    // Native Install Button
    const btnNative = document.getElementById('btn-native-install');
    if (btnNative && this.deferredPrompt) {
      btnNative.addEventListener('click', async () => {
        try {
          this.deferredPrompt.prompt();
          const { outcome } = await this.deferredPrompt.userChoice;
          console.log('[PwaGatekeeper] User install prompt choice:', outcome);
          if (outcome === 'accepted') {
            this.deferredPrompt = null;
            setTimeout(() => {
              if (this.isStandaloneMode()) this.unlockApp();
            }, 1000);
          }
        } catch (err) {
          console.warn('[PwaGatekeeper] Native prompt error:', err);
        }
      });
    }

    // Copy Link Button
    const btnCopy = document.getElementById('btn-copy-web-link');
    if (btnCopy) {
      btnCopy.addEventListener('click', () => {
        const link = window.location.origin + window.location.pathname;
        navigator.clipboard.writeText(link).then(() => {
          const orig = btnCopy.innerHTML;
          btnCopy.innerHTML = `<span>✅ Link එක Copy විය! (Copied)</span>`;
          setTimeout(() => {
            btnCopy.innerHTML = orig;
          }, 2000);
        }).catch(() => {
          prompt('EduPeak App URL:', window.location.href);
        });
      });
    }

    // Re-check button
    const recheckBtn = document.getElementById('btn-recheck-standalone');
    if (recheckBtn) {
      recheckBtn.addEventListener('click', () => {
        if (this.isStandaloneMode()) {
          recheckBtn.textContent = '✅ සාර්ථකයි! (Unlocked)';
          setTimeout(() => {
            this.unlockApp();
          }, 300);
        } else {
          recheckBtn.textContent = '❌ තවමත් Browser එකේ';
          setTimeout(() => {
            recheckBtn.textContent = 'නැවත Check කරන්න ↻';
          }, 1800);
        }
      });
    }

    // Continue in browser bypass button
    const bypassBtn = document.getElementById('btn-browser-bypass');
    if (bypassBtn) {
      bypassBtn.addEventListener('click', () => {
        sessionStorage.setItem('edupeak_dev_bypass', 'true');
        this.unlockApp();
      });
    }

    // Auto-detect when display mode changes to standalone
    if (window.matchMedia) {
      window.matchMedia('(display-mode: standalone)').addEventListener('change', (e) => {
        if (e.matches) this.unlockApp();
      });
    }

    // Auto-detect when app switches from background to foreground
    window.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible' && this.isStandaloneMode()) {
        this.unlockApp();
      }
    });
  }
}
