import { auth } from './firebase-config.js';

export async function callBackend(endpoint, payload, { authenticated = true } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (authenticated) {
    const user = auth.currentUser;
    if (!user) throw new Error('Sign in first.');
    headers.Authorization = `Bearer ${await user.getIdToken()}`;
  }
  const response = await fetch(`/api/${endpoint}`, {
    method: 'POST', headers, body: JSON.stringify(payload || {}),
  });
  let data = {};
  try { data = await response.json(); } catch (_) {}
  if (!response.ok) {
    const error = new Error(data?.error?.message || 'The request could not be completed.');
    error.code = data?.error?.code || 'internal';
    throw error;
  }
  return data.result;
}
