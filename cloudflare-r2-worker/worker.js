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
    const origin = request.headers.get('Origin') || '*';

    const corsHeaders = {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, X-EduPeak-Token',
      'Access-Control-Max-Age': '86400',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // ── 1. POST /upload - Store file in R2 ───────────────────────────────
      if (request.method === 'POST') {
        const contentType = request.headers.get('Content-Type') || '';
        let fileBody = null;
        let fileName = null;
        let mimeType = 'application/octet-stream';

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

        // Clean filename / path
        const key = String(fileName).replace(/^\/+/, '');

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
        headers.set('Access-Control-Allow-Origin', origin);
        headers.set('Cache-Control', 'public, max-age=31536000, immutable');

        return new Response(object.body, { headers });
      }

      // ── 3. DELETE /:key - Delete file from R2 ────────────────────────────
      if (request.method === 'DELETE') {
        const key = decodeURIComponent(url.pathname.slice(1));
        if (!key) {
          return new Response(JSON.stringify({ error: 'Missing key' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
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
