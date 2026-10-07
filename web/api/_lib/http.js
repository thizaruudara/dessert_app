function sendError(res, error) {
  const status = Number(error?.status) || statusFromCode(error?.code) || 500;
  const message = status >= 500
    ? (status === 503 ? error.message : 'The request could not be completed. Please try again later.')
    : error.message;
  if (status >= 500) {
    const trace = String(error?.stack || '').split('\n').slice(1, 6).join('\n');
    console.error('[api]', error?.code || 'internal', error?.message || 'Unknown server error', trace);
  }
  return res.status(status).json({ error: { code: error?.code || 'internal', message } });
}

function statusFromCode(code) {
  return ({
    'invalid-argument': 400,
    'unauthenticated': 401,
    'permission-denied': 403,
    'not-found': 404,
    'already-exists': 409,
    'resource-exhausted': 429,
    'failed-precondition': 412,
  })[code] || 0;
}

function methodNotAllowed(res, allowed = 'POST') {
  res.setHeader('Allow', allowed);
  return res.status(405).json({ error: { code: 'method-not-allowed', message: 'Method not allowed.' } });
}

function handleCors(req, res) {
  const origin = String(req.headers.origin || '');
  if (origin === 'https://dessert-institute.web.app') {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Max-Age', '86400');
  }
  if (req.method === 'OPTIONS') {
    res.setHeader('Allow', 'POST, OPTIONS');
    res.status(204).end();
    return true;
  }
  return false;
}

function getBody(req) {
  if (req.body && typeof req.body === 'object' && !Array.isArray(req.body)) return req.body;
  if (typeof req.body === 'string') {
    try {
      const parsed = JSON.parse(req.body);
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
    } catch (_) { return {}; }
  }
  return {};
}

function normalizePhone(value) {
  let digits = String(value || '').replace(/\D/g, '');
  if (digits.startsWith('0')) digits = `94${digits.slice(1)}`;
  else if (digits.length === 9) digits = `94${digits}`;
  if (!digits || digits.length < 10 || digits.length > 15) {
    const error = new Error('Enter a valid phone number.');
    error.status = 400;
    error.code = 'invalid-argument';
    throw error;
  }
  return digits;
}

function authEmail(phoneDigits) {
  return `p${phoneDigits}@users.edupeak.app`;
}

async function requireUser(req, admin) {
  const authorization = String(req.headers.authorization || '');
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    const error = new Error('Sign in first.');
    error.status = 401;
    error.code = 'unauthenticated';
    throw error;
  }
  try {
    return await admin.auth().verifyIdToken(match[1], true);
  } catch (_) {
    const error = new Error('Your session has expired. Sign in again.');
    error.status = 401;
    error.code = 'unauthenticated';
    throw error;
  }
}

module.exports = { sendError, methodNotAllowed, handleCors, getBody, normalizePhone, authEmail, requireUser };
