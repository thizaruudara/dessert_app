const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { parseEnv } = require('node:util');

const root = __dirname;
const localEnvFile = path.join(root, '.env.local');
if (fs.existsSync(localEnvFile)) {
  for (const [name, value] of Object.entries(parseEnv(fs.readFileSync(localEnvFile, 'utf8')))) {
    if (process.env[name] === undefined) process.env[name] = value;
  }
}

const apiHandlers = new Map([
  ['/api/auth/upgrade-legacy', require('./api/auth/upgrade-legacy')],
  ['/api/auth/ensure-admin', require('./api/auth/ensure-admin')],
  ['/api/auth/ensure-profile', require('./api/auth/ensure-profile')],
  ['/api/papers/register-slot', require('./api/papers/register-slot')],
  ['/api/sprints/submit-attempt', require('./api/sprints/submit-attempt')],
]);

const esbuild = path.join(root, 'node_modules', 'esbuild', 'bin', 'esbuild');
execFileSync(process.execPath, [esbuild, 'js/app.js', '--bundle', '--platform=browser', '--format=esm', '--outfile=js/app.bundle.js'], {
  cwd: root,
  stdio: 'inherit',
});

const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.webmanifest': 'application/manifest+json',
};

http.createServer(async (req, res) => {
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch (_) {
    res.writeHead(400).end('Bad request');
    return;
  }

  const relative = pathname.replace(/^\/+/, '');
  if (relative.split('/').some((part) => part.startsWith('.')) || relative === 'api' || relative.startsWith('api/')) {
    const pathnameOnly = new URL(req.url, 'http://localhost').pathname;
    const handler = apiHandlers.get(pathnameOnly);
    if (!handler) {
      res.writeHead(404, { 'Content-Type': 'application/json; charset=utf-8' })
        .end(JSON.stringify({ error: { code: 'not-found', message: 'API route not found.' } }));
      return;
    }

    let body = {};
    if (req.method === 'POST') {
      try {
        const chunks = [];
        let size = 0;
        for await (const chunk of req) {
          size += chunk.length;
          if (size > 10 * 1024 * 1024) throw Object.assign(new Error('Request is too large.'), { status: 413, code: 'payload-too-large' });
          chunks.push(chunk);
        }
        if (size) body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      } catch (error) {
        res.writeHead(error.status || 400, { 'Content-Type': 'application/json; charset=utf-8' })
          .end(JSON.stringify({ error: { code: error.code || 'invalid-json', message: error.message === 'Request is too large.' ? error.message : 'Invalid JSON request.' } }));
        return;
      }
    }

    let statusCode = 200;
    let ended = false;
    const apiRes = {
      status(code) { statusCode = code; return apiRes; },
      setHeader(name, value) { res.setHeader(name, value); return apiRes; },
      json(payload) {
        if (ended) return apiRes;
        ended = true;
        res.statusCode = statusCode;
        res.setHeader('Content-Type', 'application/json; charset=utf-8');
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.end(JSON.stringify(payload));
        return apiRes;
      },
    };
    try {
      await handler({ method: req.method, headers: req.headers, socket: req.socket, body }, apiRes);
      if (!ended) apiRes.status(500).json({ error: { code: 'internal', message: 'The local API handler did not return a response.' } });
    } catch (error) {
      console.error('[local-api]', error?.code || 'internal', error?.message || 'Unknown error');
      if (!ended) apiRes.status(500).json({ error: { code: 'internal', message: 'The local API could not complete the request.' } });
    }
    return;
  }

  let filename = path.resolve(root, relative || 'index.html');
  if (!filename.startsWith(`${root}${path.sep}`) && filename !== path.join(root, 'index.html')) {
    res.writeHead(404).end('Not found');
    return;
  }

  if (!fs.existsSync(filename) || !fs.statSync(filename).isFile()) filename = path.join(root, 'index.html');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Type', contentTypes[path.extname(filename)] || 'application/octet-stream');
  fs.createReadStream(filename).pipe(res);
}).listen(Number(process.env.PORT) || 3000, '127.0.0.1', () => {
  console.log(`EduPeak local files ready on http://localhost:${Number(process.env.PORT) || 3000}`);
});
