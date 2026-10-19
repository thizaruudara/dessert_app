/**
 * EduPeak Cloudflare R2 High-Speed Storage Worker
 * 
 * Provides:
 * - 10 GB FREE storage every month on Cloudflare
 * - ZERO egress/bandwidth fees for uploads and downloads
 * - Fast CDN streaming for student exam answers, images, and compiled PDFs
 * - Automatic CORS handling for web and mobile PWAs
 */

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin') || '';
    const allowedOrigins = ['https://app.edupeak.lk','https://edupeak.lk','https://dessert-institute.web.app','https://edupeak-web.vercel.app'];
    // Restrict *.vercel.app to *your* Vercel project previews only — any other *.vercel.app is an attacker
    function isAllowedOriginFn(o) {
      if (allowedOrigins.includes(o)) return true;
      if (o.startsWith('http://localhost:') || o.startsWith('http://127.0.0.1:')) return true;
  try {
        const u = new URL(o);
        if (u.protocol !== 'https:') return false;
        const host = u.hostname.toLowerCase();
        // Allow preview deployments of THIS project only (e.g. edupeak-web-xyz.vercel.app, dessert-*.vercel.app)
        if (host === 'vercel.app' || host.endsWith('.vercel.app')) {
          return host.endsWith('.vercel.app') && (
            host.includes('edupeak') || host.includes('dessert') // project-specific substring
          );
        }
      } catch (_) { return false; }
      return false;
    }
    const isAllowedOrigin = isAllowedOriginFn(origin);
    const corsOrigin = isAllowedOrigin ? origin : null;

    const corsHeaders = {
      ...(corsOrigin ? { 'Access-Control-Allow-Origin': corsOrigin } : {}),
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, X-EduPeak-Token',
      'Access-Control-Max-Age': '86400',
      'Vary': 'Origin',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

  function isValidR2Key(k){ if(!k||typeof k!=='string')return false; if(k.length>512)return false; if(k.includes('..')||k.includes('\\')||k.startsWith('/'))return false; if(/[\x00-\x1f\x7f]/.test(k))return false; if(!/^[a-zA-Z0-9_\-.\/]+$/.test(k))return false; const dotIdx=k.lastIndexOf('.'); if(dotIdx===-1)return false; const ext=k.slice(dotIdx).toLowerCase(); const ALLOWED=['.jpg','.jpeg','.png','.webp','.pdf']; return ALLOWED.includes(ext); }
    try {
      // ── 1. POST /upload - Store file in R2 (requires auth) ──────────────
      if (request.method === 'POST') {
        const authHeader = request.headers.get('Authorization') || request.headers.get('X-EduPeak-Token') || '';
        const expectedToken = env.UPLOAD_TOKEN || env.R2_UPLOAD_TOKEN || '';
        if (!expectedToken) {
          return new Response(JSON.stringify({ error: 'Upload service not configured' }), { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        if (authHeader !== `Bearer ${expectedToken}` && authHeader !== expectedToken) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        // Validate file size header if present
        const contentLength = parseInt(request.headers.get('Content-Length') || '0', 10);
        if (contentLength > 15 * 1024 * 1024) {
          return new Response(JSON.stringify({ error: 'File too large (max 15MB)' }), { status: 413, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        // Parse body first, then validate key and MIME after real values are known
        const contentType = request.headers.get('Content-Type') || '';
        let fileBody = null;
        let fileName = null;
        let mimeType = 'application/octet-stream';
        const ALLOWED_MIMES = new Set(['image/jpeg','image/png','image/webp','application/pdf','image/jpg']);
        const ALLOWED_EXTS = new Set(['.jpg','.jpeg','.png','.webp','.pdf']);
        function isValidR2Key(k) {
          if (!k || typeof k !== 'string') return false;
          if (k.length > 512) return false;
          if (k.includes('..') || k.includes('\\') || k.startsWith('/')) return false;
          if (/[\x00-\x1f\x7f]/.test(k)) return false;
          // allow a-zA-Z0-9 _ - . / only
          if (!/^[a-zA-Z0-9_\-.\/]+$/.test(k)) return false;
          const dotIdx = k.lastIndexOf('.');
          if (dotIdx === -1) return false;
          const ext = k.slice(dotIdx).toLowerCase();
          if (!ALLOWED_EXTS.has(ext)) return false;
          return true;
        }

        if (contentType.includes('multipart/form-data')) {
          const formData = await request.formData();
          const file = formData.get('file');
          const keyParam = formData.get('key');

          if (!file) {
            return new Response(JSON.stringify({ error: 'No file provided in form data' }), {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
          }

          fileBody = file.stream ? file.stream() : await file.arrayBuffer();
          mimeType = file.type || 'image/jpeg';
          fileName = keyParam || file.name || `upload_${Date.now()}`;
        } else {
          // Direct raw body stream
          fileName = url.searchParams.get('key') || `upload_${Date.now()}`;
          mimeType = contentType || 'image/jpeg';
          fileBody = request.body;
        }

        // Clean filename / path and validate key + MIME
        let key = String(fileName).replace(/^\/+/, '');
        // Ensure extension matches expected upload pattern
        if (!isValidR2Key(key)) {
          return new Response(JSON.stringify({ error: 'Invalid key or file extension. Allowed: .jpg .jpeg .png .webp .pdf' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const normalizedMime = mimeType.split(';')[0].trim().toLowerCase();
        if (!ALLOWED_MIMES.has(normalizedMime)) {
          return new Response(JSON.stringify({ error: `MIME not allowed: ${normalizedMime}` }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        mimeType = normalizedMime;

        // Put object into R2 bucket
        await env.R2_BUCKET.put(key, fileBody, {
          httpMetadata: {
            contentType: mimeType,
            cacheControl: 'public, max-age=31536000, immutable'
          }
        });

        // Determine public access URL
        // If custom domain or r2.dev domain is provided in env.PUBLIC_URL, use it; otherwise route via this worker
        const publicBaseUrl = env.PUBLIC_URL ? env.PUBLIC_URL.replace(/\/+$/, '') : `${url.origin}`;
        const fileUrl = `${publicBaseUrl}/${encodeURIComponent(key).replace(/%2F/g, '/')}`;

        return new Response(JSON.stringify({
          success: true,
          key: key,
          url: fileUrl,
          contentType: mimeType,
          uploadedAt: new Date().toISOString()
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // ── 2. GET /:key - Deliver file with CDN caching ─────────────────────
      if (request.method === 'GET') {
        const key = decodeURIComponent(url.pathname.slice(1));
        if (!key || key === 'health') {
          return new Response(JSON.stringify({ status: 'ok', service: 'EduPeak Cloudflare R2 Worker' }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // R2 GET validation
        if (!isValidR2Key(key)) {
          return new Response(JSON.stringify({ error: 'Invalid key' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const object = await env.R2_BUCKET.get(key);
        if (!object) {
          return new Response('File not found in storage', {
            status: 404,
            headers: corsHeaders
          });
        }

        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set('etag', object.httpEtag);
        if (corsOrigin) headers.set('Access-Control-Allow-Origin', corsOrigin);
        headers.set('Vary', 'Origin');
        headers.set('Cache-Control', 'public, max-age=31536000, immutable');
        headers.set('X-Content-Type-Options', 'nosniff');

        return new Response(object.body, { headers });
      }

      // ── 3. DELETE /:key - Delete file from R2 (requires auth) ───────────
      if (request.method === 'DELETE') {
        const authHeader = request.headers.get('Authorization') || request.headers.get('X-EduPeak-Token') || '';
        const expectedToken = env.UPLOAD_TOKEN || env.R2_UPLOAD_TOKEN || '';
        if (!expectedToken) {
          return new Response(JSON.stringify({ error: 'Upload service not configured' }), { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        if (authHeader !== `Bearer ${expectedToken}` && authHeader !== expectedToken) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const key = decodeURIComponent(url.pathname.slice(1));
        if (!key) {
          return new Response(JSON.stringify({ error: 'Missing key' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // R2 DELETE validation
        if (!isValidR2Key(key)) {
          return new Response(JSON.stringify({ error: 'Invalid key or file extension. Allowed: .jpg .jpeg .png .webp .pdf' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        await env.R2_BUCKET.delete(key);
        return new Response(JSON.stringify({ success: true, deleted: key }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      return new Response('Method not allowed', { status: 405, headers: corsHeaders });

    } catch (err) {
      return new Response(JSON.stringify({ error: err.message || 'R2 Storage Worker Error' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  }
};
