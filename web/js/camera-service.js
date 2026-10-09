// EduPeak iOS & Mobile Camera Service
// Provides live document scanning (rear camera), high-res photo capture, multi-page bundling,
// and front-camera live proctoring for online exam sessions.

export class CameraService {
  constructor() {
    this.stream = null;
    this.videoElement = null;
    this.currentFacingMode = 'environment'; // 'environment' for scanner, 'user' for proctoring
    this.isTorchOn = false;
    this.scannedPages = []; // Array of base64 data URLs
  }

  // Check if WebRTC camera is supported
  isCameraSupported() {
    return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
  }

  // Start video stream with iOS-optimized constraints
  async startCamera(videoElement, facingMode = 'environment') {
    this.videoElement = videoElement;
    this.currentFacingMode = facingMode;

    if (!this.isCameraSupported()) {
      throw new Error('Camera access is not supported by your current browser.');
    }

    // Stop any existing stream
    this.stopCamera();

    const constraints = {
      audio: false,
      video: {
        facingMode: { ideal: facingMode },
        width: { ideal: facingMode === 'environment' ? 1920 : 1280 },
        height: { ideal: facingMode === 'environment' ? 1080 : 720 }
      }
    };

    try {
      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      this.videoElement.srcObject = this.stream;
      
      // Crucial for iOS Safari inline video playback
      this.videoElement.setAttribute('playsinline', 'true');
      this.videoElement.setAttribute('webkit-playsinline', 'true');
      this.videoElement.muted = true;

      await this.videoElement.play();
      return this.stream;
    } catch (err) {
      console.error('[Camera] getUserMedia failed:', err);
      // Fallback with basic constraints
      try {
        this.stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
        this.videoElement.srcObject = this.stream;
        this.videoElement.setAttribute('playsinline', 'true');
        this.videoElement.muted = true;
        await this.videoElement.play();
        return this.stream;
      } catch (fallbackErr) {
        throw new Error('Please grant camera permissions in your iOS Settings to continue.');
      }
    }
  }

  // Stop video stream
  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
    if (this.videoElement) {
      this.videoElement.srcObject = null;
    }
    this.isTorchOn = false;
  }

  // Toggle Torch/Flash on supported iOS/Android hardware
  async toggleTorch() {
    if (!this.stream) return false;
    const track = this.stream.getVideoTracks()[0];
    if (!track) return false;

    const capabilities = track.getCapabilities ? track.getCapabilities() : {};
    if (capabilities.torch) {
      try {
        this.isTorchOn = !this.isTorchOn;
        await track.applyConstraints({
          advanced: [{ torch: this.isTorchOn }]
        });
        return this.isTorchOn;
      } catch (e) {
        console.warn('[Camera] Torch toggle not supported:', e);
      }
    }
    return false;
  }

  // Compress and resize image dataUrl to keep payload size lightweight (<100KB)
  compressImage(dataUrl, maxDim = 1200, quality = 0.72) {
    return new Promise((resolve) => {
      if (!dataUrl || typeof dataUrl !== 'string') return resolve(dataUrl);
      const img = new Image();
      img.onload = () => {
        let w = img.width;
        let h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) {
            h = Math.round((h * maxDim) / w);
            w = maxDim;
          } else {
            w = Math.round((w * maxDim) / h);
            h = maxDim;
          }
        }
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, w, h);
        resolve(canvas.toDataURL('image/jpeg', quality));
      };
      img.onerror = () => resolve(dataUrl);
      img.src = dataUrl;
    });
  }

  // Capture high-resolution photo from the live video feed
  capturePhoto(applyFilter = 'none') {
    if (!this.videoElement || !this.stream) {
      throw new Error('Camera is not active. Please grant camera permission or select images from Gallery.');
    }

    const video = this.videoElement;
    let width = video.videoWidth || 1280;
    let height = video.videoHeight || 720;
    if (width === 0 || height === 0) {
      width = 1280;
      height = 720;
    }

    // Downscale if dimension exceeds 1200 to prevent oversized payloads
    const maxDim = 1200;
    let targetW = width;
    let targetH = height;
    if (targetW > maxDim || targetH > maxDim) {
      if (targetW > targetH) {
        targetH = Math.round((targetH * maxDim) / targetW);
        targetW = maxDim;
      } else {
        targetW = Math.round((targetW * maxDim) / targetH);
        targetH = maxDim;
      }
    }

    const canvas = document.createElement('canvas');
    canvas.width = targetW;
    canvas.height = targetH;
    const ctx = canvas.getContext('2d');

    // If front camera, flip horizontally for natural mirror feel
    if (this.currentFacingMode === 'user') {
      ctx.translate(targetW, 0);
      ctx.scale(-1, 1);
    }

    try {
      ctx.drawImage(video, 0, 0, targetW, targetH);
    } catch (err) {
      console.warn('[Camera] drawImage fallback error:', err);
    }

    // Apply document contrast or B&W filter if requested
    if (applyFilter === 'bw' || applyFilter === 'document') {
      this.applyDocumentFilter(ctx, targetW, targetH, applyFilter);
    }

    const dataUrl = canvas.toDataURL('image/jpeg', 0.75);
    this.scannedPages.push(dataUrl);

    // Trigger haptic vibration if supported
    if ('vibrate' in navigator) {
      navigator.vibrate(60);
    }

    return dataUrl;
  }

  // Image processing filter for homework documents
  applyDocumentFilter(ctx, width, height, mode) {
    const imgData = ctx.getImageData(0, 0, width, height);
    const d = imgData.data;

    for (let i = 0; i < d.length; i += 4) {
      const r = d[i];
      const g = d[i + 1];
      const b = d[i + 2];
      // Luminance
      let v = 0.299 * r + 0.587 * g + 0.114 * b;

      if (mode === 'document') {
        // High contrast document enhancement
        v = (v - 128) * 1.45 + 128;
        v = Math.min(255, Math.max(0, v));
        d[i] = v;
        d[i + 1] = v;
        d[i + 2] = v;
      } else if (mode === 'bw') {
        // Pure crisp black and white threshold
        const threshold = 135;
        const bw = v > threshold ? 255 : 20;
        d[i] = bw;
        d[i + 1] = bw;
        d[i + 2] = bw;
      }
    }
    ctx.putImageData(imgData, 0, 0);
  }

  // Add an image from file input (fallback)
  addPageFromDataUrl(dataUrl) {
    this.scannedPages.push(dataUrl);
  }

  // Remove a scanned page by index
  removePage(index) {
    if (index >= 0 && index < this.scannedPages.length) {
      this.scannedPages.splice(index, 1);
    }
  }

  // Clear all scanned pages
  clearPages() {
    this.scannedPages = [];
  }

  getPages() {
    return this.scannedPages;
  }
}

export const cameraService = new CameraService();
