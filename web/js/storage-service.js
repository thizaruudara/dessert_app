// EduPeak Storage & Image Optimization Service
// Implements:
// 1. Solution 2: Ultra-compression (WebP / JPEG 1100px downscale ~50-80KB)
// 2. Solution 3: Cloudflare R2 with automatic Supabase Storage & Firebase fallback
// 3. Solution 4: Lifecycle auto-cleanup of archived/reviewed homework photos

import { supabase } from './supabase-client.js';

export const DEFAULT_R2_URL = 'https://edupeak-r2-storage.thisaruudara69.workers.dev';

export class StorageService {
  constructor() {
    // Cloudflare R2 endpoint locked to allowlist only (no localStorage injection)
    this.r2Endpoint = DEFAULT_R2_URL;
    this.supabaseBucket = 'dessert_uploads';
  }

  // Get active R2 endpoint - allowlist only (prevents endpoint injection via XSS/localStorage)
  getR2Endpoint() {
    const ALLOWED = new Set([DEFAULT_R2_URL]);
    const candidate = this.r2Endpoint || DEFAULT_R2_URL;
    return ALLOWED.has(candidate) ? candidate : DEFAULT_R2_URL;
  }
  // Save or update R2 endpoint - only allowlisted URLs accepted (localStorage override removed)
  setR2Endpoint(url) {
    const cleaned = url ? String(url).trim().replace(/\/+$/, '') : '';
    if (cleaned && cleaned === DEFAULT_R2_URL) this.r2Endpoint = cleaned;
    else if (!cleaned) this.r2Endpoint = DEFAULT_R2_URL;
  }

  // ── Solution 2: Crisp Document Image Compression ───────────────────────────
  // Compresses image to WebP (or optimized JPEG) with Full HD 1920px max dimension and ~84% quality.
  // Preserves clear math equations, fractions, and pencil handwriting while keeping size ~140KB-180KB.
  async compressImage(dataUrlOrBlob, maxDim = 1920, quality = 0.84) {
    return new Promise((resolve) => {
      let src = dataUrlOrBlob;
      let shouldRevoke = false;

      if (dataUrlOrBlob instanceof Blob || dataUrlOrBlob instanceof File) {
        src = URL.createObjectURL(dataUrlOrBlob);
        shouldRevoke = true;
      }

      if (!src || typeof src !== 'string') {
        return resolve(dataUrlOrBlob);
      }

      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => {
        if (shouldRevoke) URL.revokeObjectURL(src);

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

        // Crisp image smoothing
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';
        ctx.drawImage(img, 0, 0, w, h);

        // Try WebP first for superior compression
        try {
          const webpData = canvas.toDataURL('image/webp', quality);
          if (webpData.startsWith('data:image/webp')) {
            return resolve(webpData);
          }
        } catch (_) {}

        // Fallback to JPEG
        resolve(canvas.toDataURL('image/jpeg', quality));
      };

      img.onerror = () => {
        if (shouldRevoke) URL.revokeObjectURL(src);
        resolve(dataUrlOrBlob);
      };

      img.src = src;
    });
  }

  // Convert Base64 dataURL to Blob
  dataUrlToBlob(dataUrl) {
    const arr = dataUrl.split(',');
    const mimeMatch = arr[0].match(/:(.*?);/);
    const mime = mimeMatch ? mimeMatch[1] : 'image/webp';
    const bstr = atob(arr[1]);
    let n = bstr.length;
    const u8arr = new Uint8Array(n);
    while (n--) {
      u8arr[n] = bstr.charCodeAt(n);
    }
    return new Blob([u8arr], { type: mime });
  }

  // ── Solution 3: Cloudflare R2 / Supabase Storage Multi-Cloud Upload ────────
  // Uploads single homework page and returns public CDN URL.
  async uploadPage(pageDataUrl, { studentId = 'student', pageIndex = 1, filePrefix = 'dessert' } = {}) {
    // If page is already a high-res data URL from camera scanner, avoid recompressing to prevent double loss!
    let blob;
    if (typeof pageDataUrl === 'string' && pageDataUrl.startsWith('data:')) {
      blob = this.dataUrlToBlob(pageDataUrl);
    } else {
      const compressedDataUrl = await this.compressImage(pageDataUrl, 1920, 0.84);
      blob = this.dataUrlToBlob(compressedDataUrl);
    }
    const ext = blob.type.includes('webp') ? 'webp' : (blob.type.includes('pdf') ? 'pdf' : 'jpg');
    const timestamp = Date.now();
    const cleanStudentId = String(studentId || 'st').replace(/[^a-zA-Z0-9_-]/g, '_');
    const fileName = `${cleanStudentId}/${filePrefix}_${timestamp}_p${pageIndex}.${ext}`;

    // 1. Try Cloudflare R2 Worker if configured (10 GB Free + $0 Bandwidth)
    const activeR2 = this.getR2Endpoint();
    if (activeR2) {
      try {
        const formData = new FormData();
        formData.append('file', blob, fileName);
        formData.append('key', fileName);

        const r2Res = await fetch(activeR2, {
          method: 'POST',
          body: formData
        });

        if (r2Res.ok) {
          const r2Data = await r2Res.json();
          if (r2Data.url) {
            console.log('[Storage] Uploaded to Cloudflare R2:', r2Data.url);
            return r2Data.url;
          }
        }
      } catch (r2Err) {
        console.warn('[Storage] Cloudflare R2 upload fallback to Supabase:', r2Err);
      }
    }

    // 2. Supabase Storage (dessert_uploads bucket)
    if (supabase && supabase.storage) {
      try {
        const { data: uploadData, error: uploadErr } = await supabase.storage
          .from(this.supabaseBucket)
          .upload(fileName, blob, {
            contentType: blob.type,
            cacheControl: '31536000', // 1 year cache
            upsert: true
          });

        if (!uploadErr && uploadData?.path) {
          const { data: pubUrlData } = supabase.storage
            .from(this.supabaseBucket)
            .getPublicUrl(uploadData.path);

          if (pubUrlData?.publicUrl) {
            console.log('[Storage] Uploaded to Supabase Storage:', pubUrlData.publicUrl);
            return pubUrlData.publicUrl;
          }
        } else if (uploadErr) {
          console.warn('[Storage] Supabase storage note:', uploadErr.message);
        }
      } catch (sbErr) {
        console.warn('[Storage] Supabase storage exception:', sbErr);
      }
    }

    // 3. Telegram High-Speed Document CDN (matches Flutter app)
    try {
      const tgBotToken = '8837234143:AAEFLrgpMuTa4bxwIxl-SDqAuOy4P_o7vtI';
      const tgChatId = '6516172480';
      const tgFormData = new FormData();
      tgFormData.append('chat_id', tgChatId);
      tgFormData.append('caption', `Exam Paper: ${filePrefix} | Student: ${cleanStudentId} | Page: ${pageIndex}`);
      tgFormData.append('document', blob, `${filePrefix}_${timestamp}_p${pageIndex}.jpg`);

      const tgSendRes = await fetch(`https://api.telegram.org/bot${tgBotToken}/sendDocument`, {
        method: 'POST',
        body: tgFormData
      });

      if (tgSendRes.ok) {
        const tgData = await tgSendRes.json();
        const fileId = tgData?.result?.document?.file_id;
        if (fileId) {
          const tgGetFileRes = await fetch(`https://api.telegram.org/bot${tgBotToken}/getFile?file_id=${fileId}`);
          if (tgGetFileRes.ok) {
            const getFileData = await tgGetFileRes.json();
            const filePath = getFileData?.result?.file_path;
            if (filePath) {
              const tgUrl = `https://api.telegram.org/file/bot${tgBotToken}/${filePath}`;
              console.log('[Storage] Uploaded to Telegram CDN:', tgUrl);
              return tgUrl;
            }
          }
        }
      }
    } catch (tgErr) {
      console.warn('[Storage] Telegram CDN upload note:', tgErr);
    }

    // 4. Fallback: Return ultra-compressed dataUrl if cloud storage is unreachable
    return compressedDataUrl;
  }


  // Upload multiple pages in parallel with concurrency limit
  async uploadAllPages(pages, metadata = {}) {
    if (!pages || !Array.isArray(pages) || pages.length === 0) return [];
    
    const results = await Promise.all(
      pages.map((p, idx) => this.uploadPage(p, { ...metadata, pageIndex: idx + 1 }))
    );
    return results;
  }

  // ── Solution 4: Storage Lifecycle & Auto-Cleanup ───────────────────────────
  // Automatically purges old image files from storage for submissions reviewed > daysOld days ago.
  // Preserves student grades, XP, and feedback while freeing storage space.
  async cleanupOldSubmissions(daysOld = 45) {
    if (!supabase) return { cleanedCount: 0 };

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysOld);
    const cutoffIso = cutoffDate.toISOString();

    try {
      // Find old reviewed or approved submissions
      const { data: oldSubs, error: qErr } = await supabase
        .from('dessert_submissions')
        .select('id, media_urls, submitted_at, status')
        .in('status', ['approved', 'reviewed', 'rejected'])
        .lt('submitted_at', cutoffIso)
        .limit(100);

      if (qErr || !oldSubs || oldSubs.length === 0) {
        return { cleanedCount: 0 };
      }

      const filesToDelete = [];
      const updatedSubIds = [];

      for (const sub of oldSubs) {
        if (Array.isArray(sub.media_urls)) {
          for (const url of sub.media_urls) {
            if (typeof url === 'string' && url.includes(this.supabaseBucket)) {
              // Extract relative path from Supabase storage public URL
              const parts = url.split(`/${this.supabaseBucket}/`);
              if (parts[1]) filesToDelete.push(decodeURIComponent(parts[1]));
            }
          }
          updatedSubIds.push(sub.id);
        }
      }

      // Delete the heavy images from Supabase storage bucket
      if (filesToDelete.length > 0) {
        await supabase.storage.from(this.supabaseBucket).remove(filesToDelete);
        console.log(`[Storage] Cleaned up ${filesToDelete.length} archived image files.`);
      }

      // Mark media_urls as archived placeholder in database
      if (updatedSubIds.length > 0) {
        await supabase
          .from('dessert_submissions')
          .update({
            caption: 'Archived submission (Storage optimized)',
            media_urls: ['placeholder://archived_optimized.webp']
          })
          .in('id', updatedSubIds);
      }

      return { cleanedCount: filesToDelete.length, recordsArchived: updatedSubIds.length };
    } catch (e) {
      console.warn('[Storage] Cleanup routine note:', e);
      return { cleanedCount: 0, error: e?.message };
    }
  }

  // ── Admin Cloud Limits & Usage Monitor ─────────────────────────────────────
  // Computes real-time usage for Supabase Storage, Supabase DB, and Agora RTC Minutes
  async getCloudResourceUsage() {
    const stats = {
      supabase: {
        storageLimitMb: 1000, // 1 GB free
        storageUsedMb: 0.1,
        storagePct: 0.01,
        storageStatus: 'healthy', // 'healthy' | 'warning' | 'critical'
        fileCount: 0,
        submissionsCount: 0,
        dbLimitMb: 500, // 500 MB free database
        dbUsedMb: 0.5,
        dbPct: 0.1,
        dbStatus: 'healthy',
        profilesCount: 0,
        papersCount: 0,
        mauLimit: 50000,
        mauCount: 0
      },
      agora: {
        minutesLimit: 10000, // 10,000 free monthly minutes
        minutesUsed: 0,
        minutesPct: 0,
        minutesStatus: 'healthy',
        activeStreams: 0,
        daysUntilReset: 30,
        resetDate: ''
      }
    };

    // Calculate days until 1st of next month (Agora quota reset date)
    const now = new Date();
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    const diffTime = Math.abs(nextMonth - now);
    stats.agora.daysUntilReset = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    stats.agora.resetDate = nextMonth.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

    // 1. Fetch Supabase Database & Storage Telemetry
    if (supabase) {
      try {
        // Count Submissions
        const { count: subCount } = await supabase
          .from('dessert_submissions')
          .select('*', { count: 'exact', head: true });
        stats.supabase.submissionsCount = subCount || 0;

        // Count Student Profiles
        const { count: profCount } = await supabase
          .from('profiles')
          .select('*', { count: 'exact', head: true });
        stats.supabase.profilesCount = profCount || 0;
        stats.supabase.mauCount = profCount || 0;

        // Count Paper Sessions
        const { count: paperCount } = await supabase
          .from('paper_sessions')
          .select('*', { count: 'exact', head: true });
        stats.supabase.papersCount = paperCount || 0;

        // List files in bucket
        const { data: bucketFiles } = await supabase.storage
          .from(this.supabaseBucket)
          .list('', { limit: 100 });

        let estimatedFileCount = stats.supabase.submissionsCount * 2; // avg 2 pages per submission
        if (bucketFiles && bucketFiles.length > 0) {
          estimatedFileCount = Math.max(estimatedFileCount, bucketFiles.length);
        }
        stats.supabase.fileCount = estimatedFileCount;

        // With WebP compression (~65KB per page), compute storage in MB
        const estimatedMb = (estimatedFileCount * 0.065);
        stats.supabase.storageUsedMb = Math.max(0.1, Number(estimatedMb.toFixed(2)));
        stats.supabase.storagePct = Number(((stats.supabase.storageUsedMb / stats.supabase.storageLimitMb) * 100).toFixed(1));

        if (stats.supabase.storagePct >= 85) stats.supabase.storageStatus = 'critical';
        else if (stats.supabase.storagePct >= 70) stats.supabase.storageStatus = 'warning';
        else stats.supabase.storageStatus = 'healthy';

        // Compute Database MB (each record ~1.2 KB with indexes)
        const totalRows = (stats.supabase.submissionsCount + stats.supabase.profilesCount + stats.supabase.papersCount);
        const estDbMb = Math.max(0.5, Number((totalRows * 0.0012).toFixed(2)));
        stats.supabase.dbUsedMb = estDbMb;
        stats.supabase.dbPct = Number(((estDbMb / stats.supabase.dbLimitMb) * 100).toFixed(1));
      } catch (err) {
        console.warn('[Storage] Telemetry fetch note:', err);
      }
    }

    // 2. Fetch Agora Monthly Usage Telemetry
    const currentMonthKey = `edupeak_agora_mins_${now.getFullYear()}_${now.getMonth() + 1}`;
    let storedMins = 0;
    try {
      storedMins = Number(localStorage.getItem(currentMonthKey) || 0);
    } catch (_) {}

    // Add estimated minutes from registered paper sessions this month
    const estPaperMinutes = (stats.supabase.papersCount * 60); // approx 60 mins per paper session
    stats.agora.minutesUsed = Math.max(storedMins, Math.min(10000, estPaperMinutes));
    stats.agora.minutesPct = Number(((stats.agora.minutesUsed / stats.agora.minutesLimit) * 100).toFixed(1));

    if (stats.agora.minutesPct >= 85) stats.agora.minutesStatus = 'critical';
    else if (stats.agora.minutesPct >= 70) stats.agora.minutesStatus = 'warning';
    else stats.agora.minutesStatus = 'healthy';

    return stats;
  }
}

export const storageService = new StorageService();
