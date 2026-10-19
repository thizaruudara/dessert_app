/**
 * EduPeak Cloudflare R2 Upload & CDN Worker
 * 
 * Free Tier Benefits:
 * - 10 GB Storage FREE every month
 * - $0 Bandwidth / Egress fees FOREVER
 * - 100,000 Free Write Requests / month
 * - 10,000,000 Free Read Requests / month
 * 
 * How to Deploy:
 * 1. Log in to Cloudflare Dashboard -> Workers & Pages -> Create Worker.
 * 2. Paste this code into the Worker editor.
 * 3. Go to Worker Settings -> Variables -> R2 Bucket Bindings:
 *    - Variable name: BUCKET
 *    - R2 Bucket: your-bucket-name (e.g. "edupeak-desserts")
 * 4. Save and Deploy!
 * 5. Copy the Worker URL (e.g. https://r2-upload.yourname.workers.dev) and set it in your app:
 *    window.EDUPEAK_R2_URL = 'https://r2-upload.yourname.workers.dev';
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS Headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // 1. Upload Route (POST)
    if (request.method === 'POST') {
      try {
        const formData = await request.formData();
        const file = formData.get('file');
        const key = formData.get('key') || `dessert_${Date.now()}.webp`;

        if (!file) {
          return new Response(JSON.stringify({ error: 'No file provided' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // Put object into R2
        await env.BUCKET.put(key, file.stream(), {
          httpMetadata: {
            contentType: file.type || 'image/webp',
            cacheControl: 'public, max-age=31536000, immutable'
          }
        });

        // Construct public URL
        const publicUrl = `${url.origin}/${key}`;

        return new Response(JSON.stringify({ success: true, key, url: publicUrl }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    // 2. Serve Route (GET /:key)
    if (request.method === 'GET') {
      const key = url.pathname.slice(1);
      if (!key) {
        return new Response('EduPeak R2 Storage Worker Active', { headers: corsHeaders });
      }

      const object = await env.BUCKET.get(key);
      if (!object) {
        return new Response('File not found', { status: 404, headers: corsHeaders });
      }

      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set('etag', object.httpEtag);
      headers.set('Access-Control-Allow-Origin', '*');
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');

      return new Response(object.body, { headers });
    }

    return new Response('Method not allowed', { status: 405, headers: corsHeaders });
  }
};
