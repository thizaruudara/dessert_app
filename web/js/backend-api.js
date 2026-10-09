import { auth } from './firebase-config.js';

function getApiBase() {
  if (typeof window !== 'undefined') {
    return '/api';
  }
  return 'https://edupeak-web.vercel.app/api';
}

const API_BASE = getApiBase();

export async function callBackend(endpoint, payload, { authenticated = true } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (authenticated) {
    const user = auth.currentUser;
    if (!user) throw new Error('Sign in first.');
    headers.Authorization = `Bearer ${await user.getIdToken()}`;
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 4000);
  try {
    const response = await fetch(`${API_BASE}/${endpoint}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload || {}),
      signal: controller.signal
    });
    clearTimeout(timer);
    let data = {};
    try { data = await response.json(); } catch (_) {}
    if (!response.ok) {
      const error = new Error(data?.error?.message || 'The request could not be completed.');
      error.code = data?.error?.code || 'internal';
      throw error;
    }
    return data.result;
  } catch (err) {
    clearTimeout(timer);
    if (err.name === 'AbortError') {
      const timeoutError = new Error('Backend request timed out. Continuing with offline/local fallback.');
      timeoutError.code = 'timeout';
      throw timeoutError;
    }
    throw err;
  }
}

