const { normalizePhone } = require('./http');

function isConfiguredAdminPhone(phoneDigits) {
  const configured = String(process.env.FIREBASE_ADMIN_PHONES || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  return configured.some((phone) => {
    try { return normalizePhone(phone) === phoneDigits; }
    catch (_) { return false; }
  });
}

module.exports = { isConfiguredAdminPhone };
