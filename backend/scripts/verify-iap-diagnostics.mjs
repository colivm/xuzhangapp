import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import net from "node:net";
import jwt from "jsonwebtoken";
import { signedAppleTransaction, appleJwsFixtureRootPath } from "./support/appleJwsFixture.mjs";

// Isolate all settings before import: no developer .env, real Apple, SMS, Redis or DB.
const source = readFileSync(new URL("../src/config.js", import.meta.url), "utf8");
for (const [, name] of source.matchAll(/process\.env\.([A-Z0-9_]+)/g)) process.env[name] = "";
const phone = "13900000000";
const account = "00000000-0000-4000-8000-000000000001";
const transactionId = "2000000123456789";
const start = Date.now();
const settings = { enabled: "true", phone, expiresAt: new Date(start + 3600_000).toISOString() };
const products = { monthly: "diag.monthly", yearly: "diag.yearly", lifetime: "diag.lifetime" };
const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
Object.assign(process.env, {
  NODE_ENV: "test", PORT: "0", JWT_SECRET: "isolated-iap-diagnostic-test-secret-32-characters",
  SMS_PROVIDER: "dev", DEV_ALLOW_SMS_CODE: "654321", REVIEW_LOGIN_ENABLED: "false",
  IAP_DIAGNOSTICS_ENABLED: "true", IAP_DIAGNOSTICS_PHONE: phone, IAP_DIAGNOSTICS_EXPIRES_AT: settings.expiresAt,
  APPLE_ISSUER_ID: "diagnostic-test-issuer", APPLE_KEY_ID: "DIAG123456", APPLE_BUNDLE_ID: "com.diag.test", APPLE_APPLE_ID: "1234567890",
  APPLE_ROOT_CA_PATHS: fileURLToPath(appleJwsFixtureRootPath),
  APPLE_PRIVATE_KEY: privateKey.export({ type: "pkcs8", format: "pem" }),
  APPLE_APP_STORE_API_BASE_URL: "https://api.storekit.itunes.apple.com",
  IAP_MONTHLY_PRODUCT_ID: products.monthly, IAP_YEARLY_PRODUCT_ID: products.yearly, IAP_LIFETIME_PRODUCT_ID: products.lifetime,
});
const realFetch = globalThis.fetch;
globalThis.fetch = () => { throw new Error("External network disabled in diagnostics tests"); };
const { createIAPFailureDiagnostics, iapDiagnosticStatus } = await import("../src/iapDiagnostics.js");
const { config } = await import("../src/config.js");
const jws = (payload) => `e30.${Buffer.from(JSON.stringify(payload)).toString("base64url")}.test-signature`;
const payloadFor = (environment, accountToken = account) => ({
  environment, appAccountToken: accountToken, transactionId, originalTransactionId: transactionId,
  bundleId: "com.diag.test", productId: products.monthly, expiresDate: start + 3600_000, signedDate: start,
});
const raw = {
  phone, accountToken: account, productId: products.monthly, transactionId,
  signedTransactionInfo: jws({ environment: "Sandbox", secret: "DO_NOT_LOG_JWS" }),
  failureCode: "APPLE_LOOKUP_FAILED", failedLookupStatus: 401, failedLookupEnvironment: "Production",
};
const response = (status, json) => new Response(JSON.stringify(json), {
  status, headers: { "content-type": "application/json", date: new Date(start).toUTCString() },
});
const nextTick = () => new Promise((resolve) => setImmediate(resolve));
async function until(predicate) {
  const deadline = Date.now() + 2500;
  while (!predicate()) {
    assert.ok(Date.now() < deadline, "Diagnostic test timed out");
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
}
function harness(overrides = {}) {
  const entries = [], calls = [], queued = [];
  let now = start;
  const diagnostics = createIAPFailureDiagnostics({
    settings: { ...settings }, bundleId: "com.diag.test", productIds: products,
    tokenProvider: () => "DO_NOT_LOG_BEARER", clock: () => now,
    emit: (entry) => entries.push(entry), defer: (run) => queued.push(run),
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return url.includes("sandbox") ? response(200, { signedTransactionInfo: signedAppleTransaction(payloadFor("Sandbox")) })
        : response(401, { errorMessage: "DO_NOT_LOG_APPLE_ERROR", signedTransactionInfo: "DO_NOT_LOG_APPLE_BODY" });
    }, ...overrides,
  });
  return { diagnostics, entries, calls, queued, advance(ms) { now += ms; },
    async run() { queued.shift()?.(); await until(() => entries.length > 0); await nextTick(); } };
}

assert.equal(iapDiagnosticStatus(settings, start).active, true);
for (const patch of [
  { enabled: "false" }, { enabled: "TRUE" }, { phone: "" }, { phone: ` ${phone}` },
  { expiresAt: "" }, { expiresAt: "2026-09-18T12:00:00" }, { expiresAt: "invalid" },
  { expiresAt: new Date(start - 1).toISOString() }, { expiresAt: new Date(start + 25 * 3600_000).toISOString() },
]) {
  const h = harness({ settings: { ...settings, ...patch } });
  assert.equal(h.diagnostics.schedule(raw), false);
  assert.equal(h.calls.length + h.queued.length + h.entries.length, 0);
}
for (const patch of [
  { phone: "13800000000" }, { failureCode: "APP_ACCOUNT_MISMATCH" }, { failureCode: "TRANSACTION_EXPIRED" },
  { failureCode: "IAP_NOT_CONFIGURED" }, { productId: "not-a-product" }, { transactionId: "0" },
  { transactionId: "../private" }, { transactionId: "1".repeat(31) }, { accountToken: "" },
]) assert.equal(harness().diagnostics.schedule({ ...raw, ...patch }), false);

const normal = harness();
assert.equal(normal.diagnostics.schedule(raw), true);
assert.equal(normal.calls.length, 0, "The failure handler must not synchronously query Apple");
assert.equal(normal.diagnostics.schedule(raw), false, "One in flight per process");
assert.equal(normal.diagnostics.schedule(null), false);
assert.equal(normal.diagnostics.schedule(raw), false, "Malformed calls cannot unlock an in-flight task");
await normal.run();
assert.equal(normal.calls.length, 2);
assert.ok(normal.calls.every(({ url, options }) => /^https:\/\/api\.storekit(?:-sandbox)?\.itunes\.apple\.com\/inApps\/v1\/transactions\/\d+$/.test(url)
  && options.method === "GET" && options.redirect === "error" && options.signal));
const [prod, sandbox] = normal.entries[0].checks;
assert.equal(prod.httpStatus, 401);
assert.equal(sandbox.httpStatus, 200);
for (const key of ["hasTransactionPayload", "productMatches", "transactionMatches", "bundleMatches", "accountMatches"]) {
  assert.equal(sandbox[key], true, key);
}
assert.equal(sandbox.signatureVerified, false);
assert.equal(normal.entries[0].clientEnvironmentHint, "Sandbox");
assert.equal(normal.entries[0].clientHintVerified, false);
assert.equal(normal.entries[0].grantsMembership, false);
assert.equal(normal.entries[0].failedLookupEnvironment, "Production");
assert.equal(normal.entries[0].failedLookupStatus, 401);
const log = JSON.stringify(normal.entries);
for (const secret of [phone, account, transactionId, products.monthly, raw.signedTransactionInfo, "DO_NOT_LOG", "Bearer"]) {
  assert.ok(!log.includes(secret), `Leaked diagnostic fixture: ${secret}`);
}
assert.equal(normal.diagnostics.schedule(raw), false, "Cooldown survives completion");
for (let n = 1; n < 5; n++) {
  normal.advance(60_000);
  assert.equal(normal.diagnostics.schedule(raw), true);
  normal.queued.shift()();
  await until(() => normal.entries.length === n + 1);
  await nextTick();
}
normal.advance(60_000);
assert.equal(normal.diagnostics.schedule(raw), false, "At most five runs per process");

const expiredQueued = harness();
assert.equal(expiredQueued.diagnostics.schedule(raw), true);
expiredQueued.advance(3600_000);
expiredQueued.queued.shift()();
assert.equal(expiredQueued.calls.length, 0, "Expiry is rechecked before deferred work");
const future = harness({ settings: { ...settings, expiresAt: new Date(start + 25 * 3600_000).toISOString() } });
future.advance(2 * 3600_000);
assert.equal(future.diagnostics.schedule(raw), false, "Invalid startup settings do not activate later");

const timeout = harness({ timeoutMs: 15, fetchImpl: () => new Promise(() => {}) });
timeout.diagnostics.schedule(raw);
await timeout.run();
assert.ok(timeout.entries[0].checks.every((check) => check.outcome === "timeout"));
const oversized = harness({ fetchImpl: async () => new Response("SENSITIVE".repeat(20000), { status: 200 }) });
oversized.diagnostics.schedule(raw);
await oversized.run();
assert.ok(oversized.entries[0].checks.every((check) => check.outcome === "body_limit"));
const thrown = harness({ tokenProvider: () => { throw new Error("DO_NOT_LOG_PRIVATE_KEY_PATH"); } });
thrown.diagnostics.schedule(raw);
await thrown.run();
assert.ok(thrown.entries[0].checks.every((check) => check.outcome === "probe_failed"));
assert.ok(!JSON.stringify(thrown.entries).includes("DO_NOT_LOG"));
const badPayload = harness({ fetchImpl: async () => response(200, { signedTransactionInfo: "malformed.secret.jws" }) });
badPayload.diagnostics.schedule({ ...raw, signedTransactionInfo: jws({ environment: "LOG_INJECTION_SECRET" }) });
await badPayload.run();
assert.equal(badPayload.entries[0].clientEnvironmentHint, "Unknown");
assert.ok(badPayload.entries[0].checks.every((check) => check.hasTransactionPayload === false));
const mismatch = harness({ fetchImpl: async () => response(200, { signedTransactionInfo: signedAppleTransaction({
  ...payloadFor("Sandbox"), transactionId: "9999999999999999", productId: "SENSITIVE_PRODUCT",
  bundleId: "SENSITIVE_BUNDLE", appAccountToken: "SENSITIVE_ACCOUNT", revocationDate: start - 1000, expiresDate: start - 1000,
}) }) });
mismatch.diagnostics.schedule(raw);
await mismatch.run();
for (const check of mismatch.entries[0].checks) {
  for (const key of ["productMatches", "transactionMatches", "bundleMatches", "accountMatches"]) assert.equal(check[key], false);
  assert.equal(check.expired, true);
  assert.equal(check.revoked, true);
}
assert.ok(!JSON.stringify(mismatch.entries).includes("SENSITIVE"));
const logFailure = harness({ emit: () => { throw new Error("logger unavailable"); } });
assert.equal(logFailure.diagnostics.schedule(raw), true);
logFailure.queued.shift()();
await until(() => logFailure.calls.length === 2);
for (let n = 0; n < 8; n++) await nextTick();
logFailure.advance(60_000);
assert.equal(logFailure.diagnostics.schedule(raw), true, "Logger failure releases in-flight state");
assert.equal(harness({ defer: () => { throw new Error("scheduler unavailable"); } }).diagnostics.schedule(raw), false);

// Real HTTP entry point, loopback only, with Apple mocked. A Sandbox diagnostic
// success must not convert the original Production failure into a paid account.
let listener, resolveListening;
const listening = new Promise((resolve) => { resolveListening = resolve; });
const originalListen = net.Server.prototype.listen;
net.Server.prototype.listen = function (port, callback) {
  listener = this;
  this.once("listening", () => resolveListening(this.address().port));
  return originalListen.call(this, { port: Number(port), host: "127.0.0.1" }, callback);
};
const originalInfo = console.info;
const httpLogs = [], appleCalls = [];
console.info = (...args) => { if (args[0] === "[iap-diagnostic]") httpLogs.push(JSON.parse(args[1])); };
let apiAccount = account, successfulPrimary = false, releaseSandbox;
const sandboxGate = new Promise((resolve) => { releaseSandbox = resolve; });
globalThis.fetch = async (url, options) => {
  assert.match(String(url), /^https:\/\/api\.storekit(?:-sandbox)?\.itunes\.apple\.com\/inApps\/v1\/transactions\/\d+$/);
  appleCalls.push(String(url));
  const token = options.headers.Authorization.slice("Bearer ".length);
  assert.equal(jwt.verify(token, publicKey, { algorithms: ["ES256"], audience: "appstoreconnect-v1", issuer: "diagnostic-test-issuer" }).bid, "com.diag.test");
  if (String(url).includes("sandbox")) {
    await sandboxGate;
    return response(200, { signedTransactionInfo: signedAppleTransaction(payloadFor("Sandbox", apiAccount)) });
  }
  return successfulPrimary ? response(200, { signedTransactionInfo: signedAppleTransaction(payloadFor("Production", apiAccount)) })
    : new Response("", { status: 401 });
};
try {
  await import("../src/server.js");
  const port = await Promise.race([listening, new Promise((_, reject) => {
    const timer = setTimeout(() => reject(new Error("HTTP startup timeout")), 5000); timer.unref();
  })]);
  async function request(route, body, token) {
    const result = await realFetch(`http://127.0.0.1:${port}${route}`, {
      method: body === undefined ? "GET" : "POST", signal: AbortSignal.timeout(2000),
      headers: { "content-type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: result.status, body: await result.json() };
  }
  assert.equal((await request("/v1/iap/verify", {})).status, 401);
  assert.equal(appleCalls.length, 0);
  assert.equal((await request("/v1/auth/sms/send", { phone })).status, 200);
  const login = await request("/v1/auth/sms/verify", { phone, code: "654321" });
  assert.equal(login.status, 200);
  apiAccount = login.body.user.userId;
  const token = login.body.accessToken;
  const purchase = { productId: products.monthly, transactionId, signedTransactionInfo: raw.signedTransactionInfo };
  const failed = await request("/v1/iap/verify", purchase, token);
  assert.deepEqual(failed, { status: 502, body: { ok: false, error: "APPLE_LOOKUP_FAILED", message: "Apple lookup failed (401)" } });
  assert.equal(httpLogs.length, 0, "Original response does not await the blocked diagnostic");
  assert.equal((await request("/v1/member/me", undefined, token)).body.memberTier, "free");
  releaseSandbox();
  await until(() => httpLogs.length === 1);
  assert.deepEqual(httpLogs[0].checks.map((check) => check.httpStatus), [401, 200]);
  assert.equal((await request("/v1/member/me", undefined, token)).body.memberTier, "free");
  const { getIAPTransactionByOriginalId } = await import("../src/store.js");
  assert.equal(await getIAPTransactionByOriginalId(transactionId), null);
  const count = appleCalls.length;
  successfulPrimary = true;
  assert.equal((await request("/v1/iap/verify", purchase, token)).status, 200);
  assert.equal(appleCalls.length, count + 1, "Successful purchases do not run diagnostics");
  assert.equal(httpLogs.length, 1);
  assert.equal((await request("/v1/member/me", undefined, token)).body.memberTier, "monthly");
  // Disabling has no effect on the original request, even with a new process scope.
  config.iapDiagnostics.enabled = "false";
  successfulPrimary = false;
  const beforeDisabled = appleCalls.length;
  assert.equal((await request("/v1/iap/verify", purchase, token)).status, 502);
  await nextTick();
  assert.equal(appleCalls.length, beforeDisabled + 1);
} finally {
  releaseSandbox();
  net.Server.prototype.listen = originalListen;
  console.info = originalInfo;
  globalThis.fetch = realFetch;
  if (listener) {
    listener.closeAllConnections();
    await new Promise((resolve) => listener.close(resolve));
  }
}
// Preserve exact original fallback and retain metadata for the FINAL failed lookup.
const { verifyAppStoreTransaction } = await import("../src/iapService.js");
const attempts = [];
try {
  globalThis.fetch = async (url) => {
    attempts.push(String(url));
    return new Response("", { status: String(url).includes("sandbox") ? 401 : 404 });
  };
  await assert.rejects(verifyAppStoreTransaction({ productId: products.monthly, transactionId, expectedAppAccountToken: account }), (error) => {
    assert.equal(error.code, "APPLE_LOOKUP_FAILED");
    assert.equal(error.appleEndpointEnvironment, "Sandbox");
    assert.equal(error.appleHttpStatus, 401);
    return true;
  });
  assert.equal(attempts.length, 2);
  globalThis.fetch = async () => response(200, {});
  await assert.rejects(verifyAppStoreTransaction({ productId: products.monthly, transactionId, expectedAppAccountToken: account }), (error) => {
    assert.equal(error.code, "APPLE_BAD_RESPONSE");
    assert.equal(error.appleEndpointEnvironment, "Production");
    assert.equal(error.appleHttpStatus, 200);
    return true;
  });
} finally { globalThis.fetch = realFetch; }
console.log("IAP diagnostics verified: scoped/expired/off, bounded read-only probes, redaction, HTTP failure unchanged and no membership grant.");
