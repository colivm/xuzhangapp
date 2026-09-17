import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import jwt from "jsonwebtoken";

// Override every config input before importing application modules. Never use a
// developer's .env credentials, database, Redis, SMS or Apple services in tests.
const configSource = readFileSync(new URL("../src/config.js", import.meta.url), "utf8");
const isolatedEnv = Object.fromEntries([...configSource.matchAll(/process\.env\.([A-Z0-9_]+)/g)]
  .map((match) => [match[1], ""]));
Object.assign(isolatedEnv, {
  NODE_ENV: "test",
  JWT_SECRET: "review-login-test-only-isolated-secret-32-bytes-minimum",
  PORT: "0",
  SMS_PROVIDER: "dev",
  DEV_ALLOW_SMS_CODE: "654321",
  REVIEW_LOGIN_ENABLED: "false",
  AI_PROXY_BASE_URL: "http://127.0.0.1:1",
  ALIYUN_SMS_ENDPOINT: "127.0.0.1",
  APPLE_APP_STORE_API_BASE_URL: "https://127.0.0.1:1",
});
Object.assign(process.env, isolatedEnv);

const { createReviewLoginPolicy, createReviewAttemptLimiter, validateReviewLoginRuntime } = await import("../src/reviewLogin.js");
const { signAccessToken, createRequireAuth, ACCESS_TOKEN_TTL_SECONDS } = await import("../src/auth.js");
const phone = "13800000881";
const otherPhone = "13800000882";
const code = "4826193750";
const digest = (value) => createHash("sha256").update(value).digest("hex");
const secret = isolatedEnv.JWT_SECRET;
let clock = Math.floor(Date.now() / 1000) * 1000;
const start = clock;
const settings = {
  enabled: "true", phone, codeSha256: digest(code),
  expiresAt: new Date(start + 48 * 60 * 60 * 1000).toISOString(),
};
const policyFor = (overrides = {}) => createReviewLoginPolicy({ ...settings, ...overrides }, secret, () => clock);
const active = policyFor();
const disabled = policyFor({ enabled: "false", phone: "invalid", codeSha256: "invalid", expiresAt: "invalid" });

assert.equal(disabled.handlesPhone(phone), false);
assert.equal(disabled.isActive(), false);
assert.equal(disabled.verify(phone, code), false);
assert.throws(() => disabled.tokenClaims(phone));
assert.equal(createReviewLoginPolicy({}, secret).isActive(), false);
for (const enabled of ["TRUE", "yes", "1", ""]) {
  assert.throws(() => policyFor({ enabled }), /REVIEW_LOGIN_ENABLED/);
}
for (const invalid of [
  { phone: "1380000088" }, { phone: "23800000881" }, { phone: "" },
  { codeSha256: "" }, { codeSha256: "x".repeat(64) }, { codeSha256: "a".repeat(63) },
  { expiresAt: "" }, { expiresAt: "not-a-date" }, { expiresAt: "2099-01-01T00:00:00" },
  { expiresAt: "2099-01-01T00:00:00+99:99" },
]) assert.throws(() => policyFor(invalid), /Review login requires/);
assert.throws(() => createReviewLoginPolicy(settings, ""), /Review login requires/);
assert.throws(() => createReviewLoginPolicy(settings, "dev-secret-change-me"), /Review login requires/);
for (const mode of ["staging", "production", " STAGING "]) {
  assert.throws(() => validateReviewLoginRuntime({ reviewLogin: settings, redisUrl: "" }, mode), /REDIS_URL/);
  assert.doesNotThrow(() => validateReviewLoginRuntime({ reviewLogin: settings, redisUrl: "redis://test.invalid" }, mode));
  assert.doesNotThrow(() => validateReviewLoginRuntime({ reviewLogin: { enabled: "false" }, redisUrl: "" }, mode));
}
assert.doesNotThrow(() => validateReviewLoginRuntime({ reviewLogin: settings, redisUrl: "" }, "test"));
assert.equal(active.handlesPhone(phone), true);
for (const value of [otherPhone, ` ${phone}`, `+86${phone}`, ""]) {
  assert.equal(active.handlesPhone(value), false);
  assert.equal(active.verify(value, code), false);
}
for (const invalid of ["", "123456", "1234567", "1234567890123", "4826193751", "abcdefghij", `${code} `]) {
  assert.equal(active.verify(phone, invalid), false);
}
for (const valid of ["01234567", code, "012345678901"]) {
  const boundary = policyFor({ codeSha256: digest(valid).toUpperCase() });
  assert.equal(boundary.verify(phone, valid), true);
  assert.equal(boundary.verify(phone, valid), true, "Review credentials must be reusable.");
}
const expired = policyFor({ expiresAt: new Date(start).toISOString() });
assert.equal(expired.handlesPhone(phone), true, "An expired review account must not fall through to SMS.");
assert.equal(expired.verify(phone, code), false);
assert.throws(() => expired.tokenClaims(phone));

const claims = active.tokenClaims(phone);
assert.equal(claims.exp, Math.floor(start / 1000) + 24 * 60 * 60);
assert.match(claims.reviewGrant, /^[a-f0-9]{64}$/);
assert.notEqual(claims.reviewGrant, settings.codeSha256, "JWT must not expose a crackable credential digest.");
assert.notEqual(claims.reviewGrant, createReviewLoginPolicy(settings, `${secret}-other`, () => clock).tokenClaims(phone).reviewGrant);
assert.equal(policyFor({ expiresAt: new Date(start + 60_000).toISOString() }).tokenClaims(phone).exp, start / 1000 + 60);
assert.equal(active.acceptsToken({ phone, ...claims }), true);
assert.equal(active.acceptsToken({ phone: otherPhone, ...claims }), false);
assert.equal(active.acceptsToken({ phone, ...claims, reviewGrant: "forged" }), false);
for (const changed of [disabled, expired, policyFor({ phone: otherPhone }),
  policyFor({ codeSha256: digest("9753186420") }),
  policyFor({ expiresAt: new Date(start + 72 * 60 * 60 * 1000).toISOString() })]) {
  assert.equal(changed.acceptsToken({ phone, ...claims }), false, "Config changes must revoke prior review grants.");
}
clock = Date.parse(settings.expiresAt);
assert.equal(active.isActive(), false);
assert.equal(active.acceptsToken({ phone, ...claims }), false);
clock = start;

const user = { userId: "review-test-user", displayName: "Current profile", phone };
const users = new Map([[user.userId, user]]);
let currentPolicy = active;
const middleware = createRequireAuth({
  getUserById: async (id) => users.get(id) || null,
  reviewPolicy: { acceptsToken: (payload) => currentPolicy.acceptsToken(payload) },
});
const reviewToken = signAccessToken({ ...user, displayName: "Stale profile" }, { reviewPolicy: active });
const normalToken = signAccessToken(user);
const reviewPayload = jwt.verify(reviewToken, secret);
const normalPayload = jwt.verify(normalToken, secret);
assert.ok(reviewPayload.exp - reviewPayload.iat <= 24 * 60 * 60);
assert.equal(normalPayload.exp - normalPayload.iat, 90 * 24 * 60 * 60);
assert.equal(ACCESS_TOKEN_TTL_SECONDS, 90 * 24 * 60 * 60);
assert.equal(Object.hasOwn(normalPayload, "reviewGrant"), false);
assert.equal((await invoke(middleware, reviewToken)).req.user.displayName, user.displayName);
for (const changed of [disabled, expired, policyFor({ phone: otherPhone }),
  policyFor({ codeSha256: digest("9753186420") }),
  policyFor({ expiresAt: new Date(start + 72 * 60 * 60 * 1000).toISOString() })]) {
  currentPolicy = changed;
  assert.equal((await invoke(middleware, reviewToken)).body.error, "INVALID_TOKEN");
  assert.equal((await invoke(middleware, normalToken)).nextCalled, true, "Normal auth must survive review disable/rotation.");
}
currentPolicy = active;
users.delete(user.userId);
assert.equal((await invoke(middleware, reviewToken)).body.error, "ACCOUNT_NOT_FOUND");
assert.equal((await invoke(middleware, normalToken)).body.error, "ACCOUNT_NOT_FOUND");
assert.equal((await invoke(middleware, `${reviewToken}invalid`)).body.error, "INVALID_TOKEN");
assert.equal((await invoke(middleware, "")).statusCode, 401);

let limitClock = start;
const memoryLimit = createReviewAttemptLimiter({ now: () => limitClock });
const burst = await Promise.all(Array.from({ length: 15 }, () => memoryLimit(phone)));
assert.equal(burst.filter((result) => result.ok).length, 10);
assert.deepEqual(burst[10], { ok: false, error: "SMS_VERIFY_RATE_LIMIT", retryAfterSec: 600 });
limitClock += 599_999;
assert.equal((await memoryLimit(phone)).retryAfterSec, 1);
limitClock += 1;
assert.equal((await memoryLimit(phone)).ok, true);

let redisCount = 0;
const redisCalls = [];
const fakeRedis = {
  async eval(script, options) {
    redisCalls.push({ script, options });
    return [++redisCount, 1234];
  },
};
const workerA = createReviewAttemptLimiter({ getRedis: () => fakeRedis, prefix: "review-test" });
const workerB = createReviewAttemptLimiter({ getRedis: () => fakeRedis, prefix: "review-test" });
const sharedBurst = await Promise.all(Array.from({ length: 12 }, (_, i) => (i % 2 ? workerA : workerB)(phone)));
assert.equal(sharedBurst.filter((result) => result.ok).length, 10, "Redis must share one account budget across workers.");
assert.equal(sharedBurst[10].retryAfterSec, 2);
for (const call of redisCalls) {
  assert.deepEqual(call.options, { keys: [`review-test:review-login:attempts:${digest(phone)}`], arguments: ["600000"] });
  assert.match(call.script, /redis\.call\('INCR'/);
  assert.match(call.script, /if count == 1 then redis\.call\('PEXPIRE'/);
  assert.match(call.script, /redis\.call\('PTTL'/);
  assert.equal(call.options.keys[0].includes(phone), false);
}
const redisFailure = new Error("isolated-redis-unavailable");
await assert.rejects(createReviewAttemptLimiter({ allowMemory: false })(phone), /Redis/);
for (const reply of [[0, 600000], [1, -1], [NaN, 1000], [1, NaN]]) {
  await assert.rejects(createReviewAttemptLimiter({ getRedis: () => ({ eval: async () => reply }) })(phone), /unavailable/);
}
await assert.rejects(createReviewAttemptLimiter({ getRedis: () => ({ eval: async () => { throw redisFailure; } }) })(phone),
  (error) => error === redisFailure, "Store failure must not fall back to an empty process-local budget.");
console.log("Review login policy, token revocation and account-wide limiter verified.");

await withServer({}, async (request) => {
  const send = await request("/v1/auth/sms/send", { phone });
  assert.deepEqual(send, { status: 200, body: { ok: true, cooldownSec: 60 } });
  assert.equal((await request("/v1/auth/sms/send", { phone })).status, 429, "Review send keeps the original cooldown.");
  assert.equal((await request("/v1/auth/sms/verify", { phone, code: isolatedEnv.DEV_ALLOW_SMS_CODE })).body.error, "INVALID_CODE");
  const first = await request("/v1/auth/sms/verify", { phone, code });
  const second = await request("/v1/auth/sms/verify", { phone, code });
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.deepEqual(Object.keys(first.body).sort(), ["accessToken", "ok", "user"]);
  assert.deepEqual(Object.keys(first.body.user).sort(), ["cloudSyncEnabled", "displayName", "memberExpiresAt", "memberTier", "userId"]);
  assert.equal(first.body.user.userId, second.body.user.userId);
  assert.equal(first.body.user.memberTier, "free");
  assert.equal(first.body.user.memberExpiresAt, null);
  assert.equal(first.body.user.cloudSyncEnabled, false);
  assert.ok(jwt.verify(first.body.accessToken, secret).reviewGrant);
  for (const route of ["/v1/account/me", "/v1/member/me"]) {
    const session = await request(route, undefined, { token: first.body.accessToken });
    assert.equal(session.status, 200);
    assert.equal((session.body.user || session.body).memberTier, "free", "Review login must not auto-grant membership.");
  }
  assert.equal((await request("/v1/auth/sms/send", { phone: otherPhone })).status, 200);
  assert.equal((await request("/v1/auth/sms/verify", { phone: otherPhone, code })).body.error, "INVALID_CODE");
  const ordinary = await request("/v1/auth/sms/verify", { phone: otherPhone, code: isolatedEnv.DEV_ALLOW_SMS_CODE });
  assert.equal(ordinary.status, 200);
  assert.equal(Object.hasOwn(jwt.verify(ordinary.body.accessToken, secret), "reviewGrant"), false);
  assert.equal((await request("/v1/auth/sms/verify", { phone: otherPhone, code: isolatedEnv.DEV_ALLOW_SMS_CODE })).body.error,
    "INVALID_CODE", "Ordinary SMS remains single-use.");

  const limitedPhone = "13800000883";
  for (let i = 0; i < 10; i++) {
    assert.equal((await request("/v1/auth/sms/verify", { phone: limitedPhone, code: "wrong" })).status, 400);
  }
  assert.equal((await request("/v1/auth/sms/verify", { phone: limitedPhone, code: "wrong" })).status, 429);
  assert.equal((await request("/v1/auth/sms/verify", { phone: limitedPhone, code: "wrong" }, { ip: "192.0.2.99" })).status, 400);

  assert.equal((await request("/v1/account", undefined, { method: "DELETE", token: first.body.accessToken })).status, 200);
  assert.equal((await request("/v1/account/me", undefined, { token: first.body.accessToken })).body.error, "ACCOUNT_NOT_FOUND");
  // One failed and two successful review attempts already consumed the budget.
  for (let i = 0; i < 7; i++) {
    assert.equal((await request("/v1/auth/sms/verify", { phone, code: "wrong" }, { ip: `192.0.2.${i + 1}` })).status, 400);
  }
  const exhausted = await request("/v1/auth/sms/verify", { phone, code }, { ip: "192.0.2.200" });
  assert.equal(exhausted.status, 429, "Changing IP or succeeding must not reset the review account budget.");
  assert.equal(exhausted.body.error, "SMS_VERIFY_RATE_LIMIT");
  assert.ok(exhausted.body.retryAfterSec > 0 && exhausted.body.retryAfterSec <= 600);
});
await withServer({ SMS_PROVIDER: "", DEV_ALLOW_SMS_CODE: "" }, async (request) => {
  assert.equal((await request("/v1/auth/sms/send", { phone: otherPhone })).status, 503);
  assert.equal((await request("/v1/auth/sms/send", { phone })).status, 200, "Review send must not require or call an SMS provider.");
  assert.equal((await request("/v1/auth/sms/verify", { phone, code })).status, 200);
});
await withServer({ REVIEW_LOGIN_ENABLED: "false" }, async (request) => {
  assert.equal((await request("/v1/auth/sms/verify", { phone, code })).status, 400);
  assert.equal((await request("/v1/auth/sms/send", { phone })).status, 200);
  assert.equal((await request("/v1/auth/sms/verify", { phone, code })).status, 400);
  const ordinary = await request("/v1/auth/sms/verify", { phone, code: isolatedEnv.DEV_ALLOW_SMS_CODE });
  assert.equal(ordinary.status, 200);
  assert.equal(Object.hasOwn(jwt.verify(ordinary.body.accessToken, secret), "reviewGrant"), false);
});
await withServer({ REVIEW_LOGIN_EXPIRES_AT: new Date(start - 1000).toISOString() }, async (request) => {
  assert.equal((await request("/v1/auth/sms/send", { phone })).status, 400);
  assert.equal((await request("/v1/auth/sms/verify", { phone, code })).status, 400);
  assert.equal((await request("/v1/auth/sms/verify", { phone, code: isolatedEnv.DEV_ALLOW_SMS_CODE })).status, 400);
});
console.log("Isolated HTTP review login, ordinary SMS, expiry, account deletion and rate limits verified.");

async function invoke(middlewareToInvoke, token) {
  const req = { headers: { authorization: token ? `Bearer ${token}` : "" } };
  const result = { req, statusCode: 200, body: null, nextCalled: false };
  const res = {
    status(statusCode) { result.statusCode = statusCode; return this; },
    json(body) { result.body = body; return this; },
  };
  await middlewareToInvoke(req, res, (error) => {
    if (error) throw error;
    result.nextCalled = true;
  });
  return result;
}

async function withServer(overrides, run) {
  // The production entry point stays unchanged. The test harness binds its
  // ephemeral listener to loopback and reports the OS-assigned port over IPC.
  const entry = new URL("../src/server.js", import.meta.url).href;
  const harness = `
    import net from 'node:net';
    const listen = net.Server.prototype.listen;
    net.Server.prototype.listen = function (port, callback) {
      this.once('listening', () => process.send({ port: this.address().port }));
      return listen.call(this, { port: Number(port), host: '127.0.0.1' }, callback);
    };
    await import(${JSON.stringify(entry)});
  `;
  const child = spawn(process.execPath, ["--input-type=module", "--eval", harness], {
    cwd: fileURLToPath(new URL("..", import.meta.url)),
    env: { ...process.env, ...isolatedEnv,
      REVIEW_LOGIN_ENABLED: "true", REVIEW_LOGIN_PHONE: phone,
      REVIEW_LOGIN_CODE_SHA256: settings.codeSha256,
      REVIEW_LOGIN_EXPIRES_AT: settings.expiresAt, ...overrides },
    stdio: ["ignore", "pipe", "pipe", "ipc"], windowsHide: true,
  });
  let output = "";
  child.stdout.on("data", (data) => { output += data; });
  child.stderr.on("data", (data) => { output += data; });
  const stopped = new Promise((resolve) => child.once("exit", resolve));
  try {
    const port = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Isolated backend startup timed out. ${output}`)), 10_000);
      child.once("message", (message) => { clearTimeout(timer); resolve(message.port); });
      child.once("error", (error) => { clearTimeout(timer); reject(error); });
      child.once("exit", (status) => { clearTimeout(timer); reject(new Error(`Isolated backend exited ${status}. ${output}`)); });
    });
    await run(async (route, body, { method = body === undefined ? "GET" : "POST", ip = "192.0.2.1", token } = {}) => {
      const response = await fetch(`http://127.0.0.1:${port}${route}`, {
        method,
        headers: { "content-type": "application/json", "x-forwarded-for": ip,
          ...(token ? { authorization: `Bearer ${token}` } : {}) },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(5000),
      });
      return { status: response.status, body: await response.json() };
    });
  } finally {
    if (child.exitCode === null && child.signalCode === null) child.kill();
    await stopped;
  }
}
