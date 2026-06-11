const smsSendBuckets = new Map();
const smsVerifyBuckets = new Map();

const SMS_SEND_COOLDOWN_MS = 60 * 1000;
const SMS_SEND_WINDOW_MS = 60 * 60 * 1000;
const SMS_SEND_MAX_PER_WINDOW = 5;
const SMS_VERIFY_WINDOW_MS = 10 * 60 * 1000;
const SMS_VERIFY_MAX_PER_WINDOW = 10;

export function checkSmsSendRateLimit(phone, ip = "") {
  const now = Date.now();
  const key = `${phone}:${ip}`;
  const bucket = pruneBucket(smsSendBuckets.get(key), now, SMS_SEND_WINDOW_MS);
  const last = bucket.timestamps[bucket.timestamps.length - 1] || 0;
  if (now - last < SMS_SEND_COOLDOWN_MS) {
    smsSendBuckets.set(key, bucket);
    return { ok: false, error: "SMS_COOLDOWN", retryAfterSec: Math.ceil((SMS_SEND_COOLDOWN_MS - (now - last)) / 1000) };
  }
  if (bucket.timestamps.length >= SMS_SEND_MAX_PER_WINDOW) {
    smsSendBuckets.set(key, bucket);
    return { ok: false, error: "SMS_RATE_LIMIT", retryAfterSec: Math.ceil((bucket.timestamps[0] + SMS_SEND_WINDOW_MS - now) / 1000) };
  }
  bucket.timestamps.push(now);
  smsSendBuckets.set(key, bucket);
  return { ok: true };
}

export function checkSmsVerifyRateLimit(phone, ip = "") {
  const now = Date.now();
  const key = `${phone}:${ip}`;
  const bucket = pruneBucket(smsVerifyBuckets.get(key), now, SMS_VERIFY_WINDOW_MS);
  if (bucket.timestamps.length >= SMS_VERIFY_MAX_PER_WINDOW) {
    smsVerifyBuckets.set(key, bucket);
    return { ok: false, error: "SMS_VERIFY_RATE_LIMIT", retryAfterSec: Math.ceil((bucket.timestamps[0] + SMS_VERIFY_WINDOW_MS - now) / 1000) };
  }
  return { ok: true };
}

export function markSmsVerifyFailed(phone, ip = "") {
  const now = Date.now();
  const key = `${phone}:${ip}`;
  const bucket = pruneBucket(smsVerifyBuckets.get(key), now, SMS_VERIFY_WINDOW_MS);
  bucket.timestamps.push(now);
  smsVerifyBuckets.set(key, bucket);
}

export function clearSmsVerifyFailures(phone, ip = "") {
  smsVerifyBuckets.delete(`${phone}:${ip}`);
}

function pruneBucket(bucket, now, windowMs) {
  const timestamps = Array.isArray(bucket?.timestamps) ? bucket.timestamps : [];
  return { timestamps: timestamps.filter((ts) => now - ts < windowMs) };
}
