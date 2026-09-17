import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { config, normalizeNodeEnv } from "./config.js";

const TOKEN_TTL_SECONDS = 24 * 60 * 60;
const ATTEMPT_WINDOW_MS = 10 * 60 * 1000;
const MAX_ATTEMPTS = 10;
const ATTEMPT_SCRIPT = `
local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end
return {count, redis.call('PTTL', KEYS[1])}
`;

// Invalid enabled configuration stops startup; disabled configuration has no effect.
export function createReviewLoginPolicy(settings, jwtSecret, now = Date.now) {
  const flag = String(settings.enabled ?? "false").trim();
  if (flag !== "true" && flag !== "false") {
    throw new Error("REVIEW_LOGIN_ENABLED must be true or false.");
  }
  const enabled = flag === "true";
  const phone = String(settings.phone || "").trim();
  const digest = String(settings.codeSha256 || "").trim().toLowerCase();
  const expiry = String(settings.expiresAt || "").trim();
  const expiresAt = Date.parse(expiry);
  if (enabled && (
    !/^1\d{10}$/.test(phone) || !/^[a-f0-9]{64}$/.test(digest) ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(expiry) ||
    !Number.isFinite(expiresAt) || typeof jwtSecret !== "string" || jwtSecret.length < 32 ||
    jwtSecret === "dev-secret-change-me"
  )) {
    throw new Error("Review login requires a valid dedicated phone, SHA256 credential digest, timezone-qualified expiry and strong JWT_SECRET.");
  }
  // JWT payloads are public: use a keyed fingerprint, never expose the code digest.
  const grant = enabled ? createHmac("sha256", jwtSecret)
    .update(JSON.stringify([phone, digest, expiresAt])).digest("hex") : "";
  const isActive = () => enabled && Math.floor(expiresAt / 1000) > Math.floor(now() / 1000);
  const handlesPhone = (value) => enabled && value === phone;

  return Object.freeze({
    handlesPhone,
    isActive,
    verify(value, code) {
      if (!handlesPhone(value) || !isActive() || !/^\d{8,12}$/.test(code)) return false;
      return timingSafeEqual(createHash("sha256").update(code).digest(), Buffer.from(digest, "hex"));
    },
    tokenClaims(value) {
      if (!handlesPhone(value) || !isActive()) throw new Error("Review login is unavailable.");
      return {
        reviewGrant: grant,
        exp: Math.min(Math.floor(expiresAt / 1000), Math.floor(now() / 1000) + TOKEN_TTL_SECONDS),
      };
    },
    acceptsToken(payload) {
      return isActive() && payload.phone === phone && payload.reviewGrant === grant;
    },
  });
}

// One budget per account, shared across IPs/workers when Redis is configured.
// Reserve BEFORE verification, including successful attempts; never reset on success.
export function createReviewAttemptLimiter({ getRedis = () => null, prefix = "xuzhang", now = Date.now, allowMemory = true } = {}) {
  let memoryBucket = null;
  return async function consumeAttempt(phone) {
    const redis = getRedis();
    let count;
    let ttl;
    if (redis) {
      const key = `${prefix}:review-login:attempts:${createHash("sha256").update(phone).digest("hex")}`;
      [count, ttl] = await redis.eval(ATTEMPT_SCRIPT, {
        keys: [key], arguments: [String(ATTEMPT_WINDOW_MS)],
      });
      if (!Number.isInteger(count) || count < 1 || !Number.isInteger(ttl) || ttl < 0) {
        throw new Error("Review login attempt budget is unavailable.");
      }
    } else {
      if (!allowMemory) throw new Error("Review login requires the shared Redis attempt budget.");
      const timestamp = now();
      if (!memoryBucket || memoryBucket.phone !== phone || memoryBucket.expiresAt <= timestamp) {
        memoryBucket = { phone, count: 0, expiresAt: timestamp + ATTEMPT_WINDOW_MS };
      }
      count = ++memoryBucket.count;
      ttl = memoryBucket.expiresAt - timestamp;
    }
    if (Number(count) > MAX_ATTEMPTS) {
      return { ok: false, error: "SMS_VERIFY_RATE_LIMIT", retryAfterSec: Math.max(1, Math.ceil(Number(ttl) / 1000)) };
    }
    return { ok: true };
  };
}

export function validateReviewLoginRuntime(runtimeConfig = config, nodeEnv = process.env.NODE_ENV) {
  if (String(runtimeConfig.reviewLogin.enabled).trim() === "true" &&
      ["staging", "production"].includes(normalizeNodeEnv(nodeEnv)) && !runtimeConfig.redisUrl) {
    throw new Error("Enabled review login requires REDIS_URL in staging and production.");
  }
}

validateReviewLoginRuntime();
export const reviewLoginPolicy = createReviewLoginPolicy(config.reviewLogin, config.jwtSecret);
