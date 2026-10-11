// EduPeak PWA Gatekeeper & Home Screen Installer
// Enforces Add to Home Screen (A2HS) / PWA installation on mobile and desktop
// Accurately detects OS & Browser and provides tailored bilingual (Sinhala & English) instructions.

export class PwaGatekeeper {
  constructor(options = {}) {
    this.onUnlocked = options.onUnlocked || (() => {});
    this.container = null;
    this.isUnlocked = false;
    this.lang = localStorage.getItem('edupeak_gatekeeper_lang') || 'si'; // 'si' (Sinhala) or 'en' (English)
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
      browserName = 'In-App Webview (Facebook / WhatsApp / Social)';
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
    const isSi = this.lang === 'si';
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
      badge = isSi ? '⚠️ බාහිර Browser එකක් අවශ්‍යයි' : '⚠️ External Browser Required';
      title = isSi ? 'Chrome හෝ Safari මගින් විවෘත කරන්න' : 'Open in Chrome or Safari';
      subtitle = isSi
        ? 'ඔබ මෙම පිටුව විවෘත කර ඇත්තේ සමාජ මාධ්‍ය App එකක් (Facebook/WhatsApp) තුළිනි. Add to Home Screen කිරීම සඳහා කරුණාකර ප්‍රධාන Browser එකෙන් විවෘත කරන්න.'
        : 'You are viewing EduPeak inside an in-app social browser. To add EduPeak to your Home Screen, please open it in Chrome or Safari.';
      showCopyLink = true;

      steps = [
        {
          num: '1',
          title: isSi ? 'මෙනු බොත්තම ඔබන්න' : 'Tap the Menu Button',
          desc: isSi ? 'ඉහළ හෝ පහළ කෙළවරේ ඇති තිත් 3 (⋮ හෝ ⋯) හෝ Share අයිකනය ඔබන්න.' : 'Tap the 3 dots (⋮ or ⋯) or Share icon in your current app.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="19" r="1.5"/></svg>`
        },
        {
          num: '2',
          title: isSi ? '"Open in Chrome" හෝ "Open in Safari" තෝරන්න' : 'Select "Open in Chrome" or "Open in Safari"',
          desc: isSi ? 'මෙනුවෙන් "Open in external browser" / "Open in Chrome / Safari" තෝරන්න.' : 'Choose "Open in external browser" or "Open in Safari / Chrome" from the options.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>`
        },
        {
          num: '3',
          title: isSi ? 'Home Screen එකට එක් කරන්න' : 'Add to Home Screen',
          desc: isSi ? 'විවෘත වන Browser එකෙන් පහත උපදෙස් අනුව Add to Home Screen කරන්න.' : 'Follow the prompt in your main browser to install EduPeak on your Home Screen.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        }
      ];
    }
    // 2. Apple iOS - Safari
    else if (os === 'ios' && (browser === 'safari' || browser === 'other')) {
      badge = isSi ? '🍎 iOS Home Screen ස්ථාපනය අවශ්‍යයි' : '🍎 iOS Home Screen Required';
      title = isSi ? 'EduPeak යෙදුම Home Screen එකට එක් කරන්න' : 'Install EduPeak on Your Home Screen';
      subtitle = isSi
        ? 'විභාග සඳහා <strong>කැමරා Proctored පද්ධතිය</strong>, <strong>සජීවී Push Alerts</strong> සහ <strong>Fullscreen අත්දැකීම</strong> ලබාගැනීමට EduPeak Home Screen එකෙන් ක්‍රියාත්මක විය යුතුය.'
        : 'To enable <strong>Live Exam Proctoring</strong>, <strong>Real-Time Push Alerts</strong>, and distraction-free fullscreen, Apple requires EduPeak to be launched from your Home Screen.';
      showSafariArrow = true;

      steps = [
        {
          num: '1',
          title: isSi ? 'Safari Share බොත්තම (⎋) ඔබන්න' : 'Tap Safari Share Button (⎋)',
          desc: isSi ? 'Safari හි පහළ ඇති Share බොත්තම (කොටුවක් තුළ උඩට ඊතලයක් ඇති අයිකනය) ඔබන්න.' : 'Tap the Share icon in the Safari bottom navigation bar.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/></svg>`
        },
        {
          num: '2',
          title: isSi ? '"Add to Home Screen" තෝරන්න' : 'Select "Add to Home Screen"',
          desc: isSi ? 'Share මෙනුවේ පහළට ගොස් <strong>"Add to Home Screen"</strong> (➕ අයිකනය) ඔබන්න.' : 'Scroll down the share sheet and tap <strong>"Add to Home Screen"</strong> (➕ icon).',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        },
        {
          num: '3',
          title: isSi ? '"Add" ඔබා Home Screen එකෙන් Launch කරන්න' : 'Tap "Add" & Launch from Home Screen',
          desc: isSi ? 'ඉහළ දකුණේ ඇති <strong>"Add"</strong> ඔබන්න. ඉන්පසු ඔබේ Home Screen හි ඇති <strong>EduPeak</strong> අයිකනයෙන් පිවිසෙන්න!' : 'Tap <strong>"Add"</strong> in the top-right corner. Then launch <strong>EduPeak</strong> from your Home Screen!',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>`
        }
      ];
    }
    // 3. Apple iOS - Non-Safari (Chrome, Edge, Firefox on iPhone)
    else if (os === 'ios') {
      badge = isSi ? '🍎 Safari Browser භාවිතා කරන්න' : '🍎 Use Apple Safari';
      title = isSi ? 'Safari මගින් Home Screen එකට එක් කරන්න' : 'Please Open in Apple Safari';
      subtitle = isSi
        ? 'Apple iOS මෙහෙයුම් පද්ධතියේ Web Push Notifications සහ Home Screen App පහසුකම් ලබාදෙන්නේ <strong>Apple Safari Browser</strong> එකෙන් පමණි.'
        : 'Apple iOS only supports full PWA installation and Push Notifications when launched via the <strong>Apple Safari</strong> browser.';
      showCopyLink = true;

      steps = [
        {
          num: '1',
          title: isSi ? 'ලින්ක් එක Copy කරගන්න' : 'Copy the Website Link',
          desc: isSi ? 'පහත ඇති "Copy Link" බොත්තම ඔබා EduPeak වෙබ් ලිපිනය Copy කරගන්න.' : 'Tap "Copy Link" below to copy the EduPeak web address to your clipboard.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>`
        },
        {
          num: '2',
          title: isSi ? 'Apple Safari විවෘත කරන්න' : 'Open Apple Safari',
          desc: isSi ? 'ඔබේ iPhone හි ඇති Safari Browser එක විවෘත කර ලිපිනය Paste කරන්න.' : 'Open Safari on your iPhone, paste the copied link, and open it.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="10"/><polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/></svg>`
        },
        {
          num: '3',
          title: isSi ? 'Share බොත්තමෙන් Add to Home Screen කරන්න' : 'Add to Home Screen via Safari',
          desc: isSi ? 'Safari හි පහළ ඇති Share බොත්තම (⎋) ඔබා "Add to Home Screen" තෝරන්න.' : 'Tap the Safari Share button (⎋) and select "Add to Home Screen".',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        }
      ];
    }
    // 4. Android - Google Chrome
    else if (os === 'android' && browser === 'chrome') {
      badge = isSi ? '🤖 Android Home Screen ස්ථාපනය අවශ්‍යයි' : '🤖 Android Installation Required';
      title = isSi ? 'EduPeak යෙදුම Phone එකට Install කරන්න' : 'Install EduPeak on Your Phone';
      subtitle = isSi
        ? 'විභාග වලදී වෙනත් Tab වලට මාරුවීම වැළැක්වීමට සහ <strong>සජීවී විභාග Push Alerts</strong> ලබාගැනීමට EduPeak Home Screen App එකක් ලෙස භාවිත කරන්න.'
        : 'To prevent accidental tab switching during live exams and receive <strong>Real-Time Paper Alerts</strong>, install EduPeak as a standalone app.';
      allowNativeInstall = true;

      steps = [
        {
          num: '1',
          title: isSi ? 'Chrome මෙනුව (⋮) ඔබන්න' : 'Tap the Chrome Menu (⋮)',
          desc: isSi ? 'Chrome Browser හි ඉහළ දකුණු කෙළවරේ ඇති තිත් 3 (⋮) අයිකනය ඔබන්න.' : 'Tap the three-dot menu (⋮) in the top-right corner of Chrome.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="19" r="1.5"/></svg>`
        },
        {
          num: '2',
          title: isSi ? '"Install app" හෝ "Add to Home screen" තෝරන්න' : 'Select "Install app" or "Add to Home screen"',
          desc: isSi ? 'මෙනුවෙන් <strong>"Install app"</strong> හෝ <strong>"Add to Home screen"</strong> තෝරන්න.' : 'Tap <strong>"Install app"</strong> or <strong>"Add to Home screen"</strong> from the dropdown menu.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>`
        },
        {
          num: '3',
          title: isSi ? '"Install" ඔබා Home Screen එකෙන් Launch කරන්න' : 'Tap "Install" & Open from Home Screen',
          desc: isSi ? 'පෙන්වන Dialog එකේ <strong>"Install"</strong> ඔබන්න. ඉන්පසු Home Screen හි ඇති <strong>EduPeak</strong> අයිකනයෙන් විවෘත කරන්න!' : 'Confirm by tapping <strong>"Install"</strong>. Then launch EduPeak directly from your phone screen!',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>`
        }
      ];
    }
    // 5. Android - Samsung Internet / Other Browser
    else if (os === 'android') {
      badge = isSi ? '📱 Home Screen ස්ථාපනය අවශ්‍යයි' : '📱 Home Screen Installation Required';
      title = isSi ? 'EduPeak යෙදුම Home Screen එකට එක් කරන්න' : 'Add EduPeak to Your Home Screen';
      subtitle = isSi
        ? 'විභාග සහ Push පහසුකම් සම්පූර්ණයෙන්ම ලබාගැනීමට EduPeak යෙදුම ඔබගේ දුරකථනයේ Home Screen එකට එක් කරගන්න.'
        : 'Install EduPeak on your home screen for full access to exams, push alerts, and camera submissions.';
      allowNativeInstall = true;

      steps = [
        {
          num: '1',
          title: isSi ? 'Browser මෙනුව (☰ හෝ ⋮) ඔබන්න' : 'Tap Browser Menu (☰ or ⋮)',
          desc: isSi ? 'පහළ හෝ ඉහළ කෙළවරේ ඇති Browser මෙනු බොත්තම ඔබන්න.' : 'Tap the browser menu button at the top or bottom of your screen.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></svg>`
        },
        {
          num: '2',
          title: isSi ? '"+ Add page to" -> "Home screen" තෝරන්න' : 'Select "+ Add page to" -> "Home screen"',
          desc: isSi ? 'මෙනුවෙන් <strong>"+ Add page to"</strong> තෝරා <strong>"Home screen"</strong> ඔබන්න.' : 'Tap <strong>"+ Add page to"</strong> then select <strong>"Home screen"</strong>.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><rect x="3" y="3" width="18" height="18" rx="4"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        },
        {
          num: '3',
          title: isSi ? '"Add" තහවුරු කරන්න' : 'Tap "Add" & Open App',
          desc: isSi ? '"Add" ඔබා තහවුරු කර Home Screen අයිකනයෙන් ඇතුළු වන්න.' : 'Confirm by tapping "Add". Then open EduPeak from your Home Screen.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>`
        }
      ];
    }
    // 6. Desktop (Windows, Mac, Linux)
    else {
      badge = isSi ? '💻 Desktop App ස්ථාපනය' : '💻 Desktop App Installation';
      title = isSi ? 'EduPeak යෙදුම පරිගණකයට Install කරන්න' : 'Install EduPeak as a Desktop App';
      subtitle = isSi
        ? 'වඩාත් වේගවත් ක්‍රියාකාරීත්වයක් සහ තනි කවුළුවක Fullscreen විභාග අත්දැකීමක් සඳහා EduPeak යෙදුම ඔබේ පරිගණකයට Install කරගන්න.'
        : 'For enhanced speed, fullscreen proctoring, and a dedicated desktop window, install EduPeak on your PC or Mac.';
      allowNativeInstall = true;

      steps = [
        {
          num: '1',
          title: isSi ? 'ලිපින තීරුවේ (Address Bar) ඇති Install අයිකනය (⊕) ක්ලික් කරන්න' : 'Click the Install Icon (⊕) in Address Bar',
          desc: isSi ? 'Browser එකේ ඉහළ ලිපින තීරුවේ (URL bar) දකුණු පස ඇති Install / App අයිකනය ඔබන්න.' : 'Look for the Install icon (⊕ / computer icon) at the right end of the URL address bar.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
        },
        {
          num: '2',
          title: isSi ? 'හෝ Browser Menu (⋮) -> "Install EduPeak" තෝරන්න' : 'Or Browser Menu (⋮) -> "Install EduPeak"',
          desc: isSi ? 'Browser මෙනුවේ (⋮) <strong>"Save and share"</strong> හෝ <strong>"Install EduPeak"</strong> ක්ලික් කරන්න.' : 'Click the browser menu (⋮) and select <strong>"Save and share"</strong> or <strong>"Install EduPeak"</strong>.',
          icon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="19" r="1.5"/></svg>`
        },
        {
          num: '3',
          title: isSi ? '"Install" ක්ලික් කර App එකෙන් විවෘත කරන්න' : 'Click "Install" & Launch',
          desc: isSi ? 'තහවුරු කිරීමේ Dialog එකේ <strong>"Install"</strong> ඔබා Desktop App එක ලෙස ඍජුවම භාවිතා කරන්න.' : 'Click <strong>"Install"</strong> to launch EduPeak in a clean desktop application window.',
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
    const existing = document.getElementById('pwa-gatekeeper-overlay');
    if (existing) existing.remove();

    const platform = this.detectPlatform();
    const info = this.getInstructions(platform);
    const isSi = this.lang === 'si';

    const overlay = document.createElement('div');
    overlay.id = 'pwa-gatekeeper-overlay';
    overlay.className = 'gatekeeper-overlay';
    overlay.innerHTML = `
      <div class="gatekeeper-ambient-glow glow-1"></div>
      <div class="gatekeeper-ambient-glow glow-2"></div>

      <div class="gatekeeper-card">
        <!-- Top App Emblem & Language Selector -->
        <div class="gatekeeper-top-bar" style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
          <div class="gatekeeper-lang-toggle" style="display:inline-flex; background:rgba(255,255,255,0.08); padding:3px; border-radius:20px; border:1px solid rgba(255,255,255,0.12);">
            <button type="button" id="btn-lang-si" class="lang-pill ${isSi ? 'active' : ''}" style="border:none; background:${isSi ? '#2563EB' : 'transparent'}; color:${isSi ? '#fff' : '#94A3B8'}; font-size:11.5px; font-weight:800; padding:4px 12px; border-radius:16px; cursor:pointer; transition:all 0.2s;">
              සිංහල
            </button>
            <button type="button" id="btn-lang-en" class="lang-pill ${!isSi ? 'active' : ''}" style="border:none; background:${!isSi ? '#2563EB' : 'transparent'}; color:${!isSi ? '#fff' : '#94A3B8'}; font-size:11.5px; font-weight:800; padding:4px 12px; border-radius:16px; cursor:pointer; transition:all 0.2s;">
              English
            </button>
          </div>

          <div class="gatekeeper-device-chip" style="font-size:11px; font-weight:700; color:#38BDF8; background:rgba(56,189,248,0.1); border:1px solid rgba(56,189,248,0.25); padding:4px 10px; border-radius:14px; max-width:210px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;" title="${info.deviceLabel}">
            ${platform.isIOS ? '🍏 iOS' : platform.isAndroid ? '🤖 Android' : '💻 PC'} • ${platform.browserName.split(' ')[0]}
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

        <!-- One-Tap Native Install Button (if available via beforeinstallprompt) -->
        <div id="native-install-wrapper" style="margin-bottom:14px; ${this.deferredPrompt ? 'display:block;' : 'display:none;'}">
          <button id="btn-native-install" style="width:100%; display:flex; align-items:center; justify-content:center; gap:8px; background:linear-gradient(135deg, #2563EB 0%, #06B6D4 100%); color:#FFFFFF; border:none; padding:13px 18px; border-radius:16px; font-size:14.5px; font-weight:800; box-shadow:0 8px 24px rgba(37,99,235,0.45); cursor:pointer; transition:transform 0.15s ease;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            <span>${isSi ? 'යෙදුම දැන්ම Install කරන්න 📲' : 'Install EduPeak App Now 📲'}</span>
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
            <button id="btn-copy-web-link" style="width:100%; display:flex; align-items:center; justify-content:center; gap:8px; background:rgba(255,255,255,0.06); border:1px solid rgba(255,255,255,0.18); color:#F8FAFC; padding:10px 14px; border-radius:14px; font-size:12.5px; font-weight:700; cursor:pointer;">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
              <span>${isSi ? 'වෙබ් ලිපිනය (Link) Copy කරගන්න' : 'Copy Website Link to Clipboard'}</span>
            </button>
          </div>
        ` : ''}

        <!-- Live Status Bar & Recheck Verification -->
        <div class="gatekeeper-status-box">
          <div class="status-pulse-dot"></div>
          <span class="status-text">${isSi ? 'ස්ථාපනය කර Home Screen එකෙන් විවෘත කරන්න...' : 'Waiting for launch from Home Screen...'}</span>
          <button id="btn-recheck-standalone" class="btn-recheck" style="white-space:nowrap;">
            ${isSi ? 'නැවත පරීක්ෂා කරන්න ↻' : 'Re-check ↻'}
          </button>
        </div>

        <!-- Testing / Temporary Bypass Footer -->
        <div class="gatekeeper-dev-footer">
          <button id="btn-browser-bypass" class="btn-dev-preview" style="background:transparent; color:#94A3B8; border:1px dashed rgba(255,255,255,0.2); font-size:11.5px; padding:8px 12px; border-radius:10px; cursor:pointer;">
            ${isSi ? 'Browser එකෙන් ඉදිරියට යන්න (විභාග පහසුකම් සීමා විය හැක) →' : 'Continue in Browser (Exams may be restricted) →'}
          </button>
        </div>
      </div>

      <!-- Animated Pointer for iOS Safari Bottom Bar -->
      <div class="safari-arrow-indicator ${info.showSafariArrow ? 'active' : ''}">
        <span class="arrow-text">${isSi ? 'පහළ ඇති Share බොත්තම ඔබන්න' : 'Tap Share below'}</span>
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
    const wrapper = document.getElementById('native-install-wrapper');
    if (wrapper && this.deferredPrompt) {
      wrapper.style.display = 'block';
    }
  }

  attachEventListeners() {
    // Language Toggle: Sinhala
    const btnSi = document.getElementById('btn-lang-si');
    if (btnSi) {
      btnSi.addEventListener('click', () => {
        this.lang = 'si';
        localStorage.setItem('edupeak_gatekeeper_lang', 'si');
        this.renderGatekeeper();
        this.attachEventListeners();
      });
    }

    // Language Toggle: English
    const btnEn = document.getElementById('btn-lang-en');
    if (btnEn) {
      btnEn.addEventListener('click', () => {
        this.lang = 'en';
        localStorage.setItem('edupeak_gatekeeper_lang', 'en');
        this.renderGatekeeper();
        this.attachEventListeners();
      });
    }

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
          btnCopy.innerHTML = `<span>✅ ${this.lang === 'si' ? 'Link එක Copy විය!' : 'Link Copied!'}</span>`;
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
          recheckBtn.textContent = this.lang === 'si' ? '✅ සාර්ථකයි!' : '✅ Standalone Active!';
          setTimeout(() => {
            this.unlockApp();
          }, 300);
        } else {
          recheckBtn.textContent = this.lang === 'si' ? '❌ තවමත් Browser එකේ' : '❌ Still in Browser';
          setTimeout(() => {
            recheckBtn.textContent = this.lang === 'si' ? 'නැවත පරීක්ෂා කරන්න ↻' : 'Re-check ↻';
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
