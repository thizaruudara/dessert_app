const { normalizePhone } = require('./http');

function isConfiguredAdminPhone(phoneDigits) {
  const configured = [
    process.env.FIREBASE_ADMIN_PHONES,
    process.env.FIREBASE_ADMIN_PHONE_ADDITIONS,
  ].filter(Boolean).join(',')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  return configured.some((phone) => {
    try { return normalizePhone(phone) === phoneDigits; }
    catch (_) { return false; }
  });
}

module.exports = { isConfiguredAdminPhone };
