import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import net from "node:net";
import jwt from "jsonwebtoken";
import { appleJwsFixtureRootPath, signedAppleTransaction } from "./support/appleJwsFixture.mjs";

// Set every config input before importing application modules. dotenv cannot
// replace these values with developer credentials, DB/Redis URLs or SMS settings.
const configSource = readFileSync(new URL("../src/config.js", import.meta.url), "utf8");
for (const [, name] of configSource.matchAll(/process\.env\.([A-Z0-9_]+)/g)) process.env[name] = "";
const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const account = "00000000-0000-4000-8000-000000000001";
const otherAccount = "00000000-0000-4000-8000-000000000002";
const transactionId = "2000000123456789";
const bundleId = "com.routing.test";
const products = { monthly: "routing.monthly", yearly: "routing.yearly", lifetime: "routing.lifetime" };
const expiresDate = Date.now() + 3600_000;
Object.assign(process.env, {
  NODE_ENV: "test", PORT: "0", JWT_SECRET: "isolated-iap-routing-test-secret-32-characters",
  SMS_PROVIDER: "dev", DEV_ALLOW_SMS_CODE: "654321", REVIEW_LOGIN_ENABLED: "false",
  IAP_DIAGNOSTICS_ENABLED: "false", APPLE_ISSUER_ID: "routing-test-issuer", APPLE_KEY_ID: "ROUTE12345",
  APPLE_BUNDLE_ID: bundleId, APPLE_APPLE_ID: "1234567890",
  APPLE_ROOT_CA_PATHS: fileURLToPath(appleJwsFixtureRootPath),
  APPLE_PRIVATE_KEY: privateKey.export({ type: "pkcs8", format: "pem" }),
  APPLE_APP_STORE_API_BASE_URL: "https://api.storekit.itunes.apple.com",
  IAP_MONTHLY_PRODUCT_ID: products.monthly, IAP_YEARLY_PRODUCT_ID: products.yearly,
  IAP_LIFETIME_PRODUCT_ID: products.lifetime,
});
const realFetch = globalThis.fetch;
globalThis.fetch = () => { throw new Error("External network disabled in IAP routing tests"); };
const { config, APPLE_PRODUCTION_API_BASE_URL, APPLE_SANDBOX_API_BASE_URL, validateIAPEnvironmentConfig } = await import("../src/config.js");
const { verifyAppStoreTransaction } = await import("../src/iapService.js");
assert.equal(config.databaseUrl, "");
assert.equal(config.redisUrl, "");
assert.equal(config.applePrivateKeyPath, "");
assert.equal(config.iapDiagnostics.enabled, "false");
assert.deepEqual(validateIAPEnvironmentConfig("production"), []);

const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
// Intentionally forged: client JWS is only a routing hint. Mock Apple responses
// exercise the existing server-response decoder, not Apple certificate validation.
const jws = (payload, header = { alg: "ES256" }) => `${encode(header)}.${encode(payload)}.forged-signature`;
const hintPayload = (patch = {}) => ({ environment: "Sandbox", transactionId, productId: products.monthly, bundleId, ...patch });
const matchingHint = jws(hintPayload());
const applePayload = (environment, patch = {}) => ({
  environment, transactionId, originalTransactionId: transactionId, productId: products.monthly,
  bundleId, appAccountToken: account, expiresDate, signedDate: Date.now(), ...patch,
});
let scenarios = 0;

function mockApple(plan) {
  const remaining = [...plan], calls = [];
  globalThis.fetch = async (url, options) => {
    const address = String(url);
    assert.match(address, /^https:\/\/api\.storekit(?:-sandbox)?\.itunes\.apple\.com\/inApps\/v1\/transactions\/\d+$/,
      "Only fixed Apple transaction URLs may reach the mocked fetch");
    const next = remaining.shift();
    assert.ok(next, `Unexpected extra Apple lookup: ${address}`);
    const base = next.environment === "Sandbox" ? APPLE_SANDBOX_API_BASE_URL : APPLE_PRODUCTION_API_BASE_URL;
    assert.equal(address, `${base}/inApps/v1/transactions/${next.transactionId || transactionId}`);
    assert.equal(options.method, "GET");
    assert.equal(options.headers.Accept, "application/json");
    const bearer = options.headers.Authorization;
    assert.ok(bearer.startsWith("Bearer "));
    assert.equal(jwt.verify(bearer.slice(7), publicKey, {
      algorithms: ["ES256"], audience: "appstoreconnect-v1", issuer: "routing-test-issuer",
    }).bid, bundleId);
    calls.push(address);
    const status = next.status || 200;
    const body = next.body !== undefined ? next.body : status === 200
      ? JSON.stringify({ signedTransactionInfo: signedAppleTransaction(applePayload(next.environment, next.payload)) }) : "";
    return new Response(body, { status, headers: { "content-type": "application/json" } });
  };
  return {
    calls,
    complete(label) {
      assert.equal(remaining.length, 0, `${label}: all expected Apple lookups occurred`);
      assert.equal(calls.length, plan.length, `${label}: exact Apple lookup count`);
    },
  };
}

async function verifyCase(label, { hint, plan, error, request = {}, expected = {} }) {
  const mock = mockApple(plan);
  const invoke = () => verifyAppStoreTransaction({
    productId: products.monthly, transactionId, expectedAppAccountToken: account,
    signedTransactionInfo: hint, ...request,
  });
  if (error) {
    await assert.rejects(invoke, (failure) => {
      assert.equal(failure.code, error, label);
      if (expected.status) assert.equal(failure.status, expected.status, label);
      if (expected.appleStatus) assert.equal(failure.appleHttpStatus, expected.appleStatus, label);
      if (expected.environment) assert.equal(failure.appleEndpointEnvironment, expected.environment, label);
      return true;
    });
  } else {
    const result = await invoke();
    const requestedProduct = request.productId || products.monthly;
    const requestedTier = Object.keys(products).find((tier) => products[tier] === requestedProduct);
    assert.equal(result.environment, plan.at(-1).environment, label);
    assert.equal(result.memberTier, requestedTier, label);
    assert.equal(result.productId, requestedProduct, label);
    assert.equal(result.memberExpiresAt, requestedTier === "lifetime" ? null : new Date(expiresDate).toISOString(), label);
    for (const [key, value] of Object.entries(expected)) assert.equal(result[key], value, label);
  }
  mock.complete(label);
  scenarios++;
}

let listener;
const originalListen = net.Server.prototype.listen;
try {
  await verifyCase("ordinary Production success", { plan: [{ environment: "Production" }] });
  for (const status of [401, 500]) {
    await verifyCase(`ordinary Production ${status} has no fallback`, {
      plan: [{ environment: "Production", status }], error: "APPLE_LOOKUP_FAILED",
      expected: { appleStatus: status, environment: "Production" },
    });
  }
  for (const failure of [{ status: 404 }, { status: 400, body: "Transaction not found" }]) {
    await verifyCase("original not-found fallback", {
      plan: [{ environment: "Production", ...failure }, { environment: "Sandbox" }],
    });
  }
  await verifyCase("matching Sandbox hint bypasses Production", {
    hint: matchingHint, plan: [{ environment: "Sandbox" }], expected: { appAccountToken: account },
  });
  for (const tier of ["yearly", "lifetime"]) {
    await verifyCase(`${tier} Sandbox hint retains its original tier and expiry rules`, {
      hint: jws(hintPayload({ productId: products[tier] })),
      request: { productId: products[tier] },
      plan: [{ environment: "Sandbox", payload: {
        productId: products[tier], expiresDate: tier === "lifetime" ? undefined : expiresDate,
      } }],
    });
  }
  await verifyCase("client entitlement fields cannot override Apple", {
    hint: jws(hintPayload({ appAccountToken: otherAccount, expiresDate: 1, revocationDate: 1, memberTier: "lifetime" })),
    plan: [{ environment: "Sandbox" }], expected: { appAccountToken: account },
  });
  const prefix = `${encode({ alg: "ES256" })}.${encode(hintPayload())}.`;
  const atLimit = prefix + "A".repeat(32 * 1024 - Buffer.byteLength(prefix));
  assert.equal(Buffer.byteLength(atLimit), 32 * 1024);
  await verifyCase("32 KiB hint accepted", { hint: atLimit, plan: [{ environment: "Sandbox" }] });

  const invalidHints = [
    ["missing", undefined], ["null", null], ["empty", ""], ["number", 42], ["object", {}], ["array", []],
    ["no segments", "malformed"], ["two segments", matchingHint.split(".").slice(0, 2).join(".")],
    ["four segments", `${matchingHint}.extra`], ["empty header", `.${encode(hintPayload())}.signature`],
    ["empty payload", `${encode({ alg: "ES256" })}..signature`],
    ["empty signature", `${encode({ alg: "ES256" })}.${encode(hintPayload())}.`],
    ["non-base64url header", `!${matchingHint}`], ["non-base64url payload", `${encode({ alg: "ES256" })}.!.signature`],
    ["non-base64url signature", `${prefix}bad/signature`], ["padded base64", `${matchingHint}=`],
    ["whitespace", ` ${matchingHint}`], ["newline", `${matchingHint}\n`], ["unicode", `${matchingHint}界`],
    ["header JSON invalid", `e2JhZA.${encode(hintPayload())}.signature`],
    ["payload JSON invalid", `${encode({ alg: "ES256" })}.e2JhZA.signature`],
    ["null header", jws(hintPayload(), null)], ["array header", jws(hintPayload(), [])],
    ["missing algorithm", jws(hintPayload(), {})], ["wrong algorithm", jws(hintPayload(), { alg: "HS256" })],
    ["none algorithm", jws(hintPayload(), { alg: "none" })],
    ["null payload", jws(null)], ["array payload", jws([])], ["string payload", jws("Sandbox")],
    ["Production hint", jws(hintPayload({ environment: "Production" }))],
    ["lowercase Sandbox", jws(hintPayload({ environment: "sandbox" }))],
    ["padded Sandbox", jws(hintPayload({ environment: " Sandbox " }))],
    ["transaction mismatch", jws(hintPayload({ transactionId: "2000000999999999" }))],
    ["numeric transaction", jws(hintPayload({ transactionId: Number(transactionId) }))],
    ["product mismatch", jws(hintPayload({ productId: products.yearly }))],
    ["bundle mismatch", jws(hintPayload({ bundleId: "com.other.test" }))],
    ["over 32 KiB", `${atLimit}A`],
    ["hint endpoint cannot redirect", jws(hintPayload({ environment: "https://attacker.invalid" }))],
  ];
  for (const field of ["environment", "transactionId", "productId", "bundleId"]) {
    const payload = hintPayload();
    delete payload[field];
    invalidHints.push([`missing ${field}`, jws(payload)]);
    invalidHints.push([`null ${field}`, jws(hintPayload({ [field]: null }))]);
    invalidHints.push([`object ${field}`, jws(hintPayload({ [field]: {} }))]);
  }
  for (const [label, hint] of invalidHints) {
    await verifyCase(`${label}: original primary success`, { hint, plan: [{ environment: "Production" }] });
    await verifyCase(`${label}: original not-found fallback`, {
      hint, plan: [{ environment: "Production", status: 404 }, { environment: "Sandbox" }],
    });
  }
  for (const status of [401, 404, 500, 503]) {
    await verifyCase(`direct Sandbox ${status} never reverse-falls back`, {
      hint: matchingHint, plan: [{ environment: "Sandbox", status }],
      error: status === 404 ? "APPLE_TRANSACTION_NOT_FOUND" : "APPLE_LOOKUP_FAILED",
      expected: { appleStatus: status, environment: "Sandbox" },
    });
  }
  await verifyCase("Apple success without a transaction cannot use client payload", {
    hint: matchingHint, plan: [{ environment: "Sandbox", body: "{}" }], error: "APPLE_BAD_RESPONSE",
  });
  const rejectedPayloads = [
    ["PRODUCT_MISMATCH", { productId: products.yearly }],
    ["TRANSACTION_MISMATCH", { transactionId: "2000000999999999" }],
    ["APPLE_BAD_RESPONSE", { bundleId: "com.other.test" }],
    ["APPLE_BAD_RESPONSE", { environment: "Production" }],
    ["APPLE_BAD_RESPONSE", { environment: undefined }],
    ["APP_ACCOUNT_MISMATCH", { appAccountToken: otherAccount }],
    ["TRANSACTION_EXPIRED", { expiresDate: Date.now() - 60_000 }],
    ["TRANSACTION_EXPIRED", { expiresDate: undefined }],
    ["TRANSACTION_REVOKED", { revocationDate: Date.now() - 60_000 }],
  ];
  for (const [error, payload] of rejectedPayloads) {
    await verifyCase(`Apple result still enforces ${error}`, {
      hint: matchingHint, plan: [{ environment: "Sandbox", payload }], error,
    });
  }
  await verifyCase("unknown products reject before Apple lookup", {
    hint: matchingHint, plan: [], request: { productId: "unknown-product" }, error: "UNKNOWN_PRODUCT",
  });
  await verifyCase("current account still required", {
    hint: matchingHint, plan: [{ environment: "Sandbox" }], request: { expectedAppAccountToken: "" },
    error: "APP_ACCOUNT_TOKEN_REQUIRED",
  });

  config.appleAppStoreApiBaseUrl = APPLE_SANDBOX_API_BASE_URL;
  process.env.NODE_ENV = "staging";
  assert.deepEqual(validateIAPEnvironmentConfig(), []);
  for (const hint of [undefined, matchingHint, jws(hintPayload({ environment: "Production" }))]) {
    await verifyCase("configured staging always queries Sandbox", { hint, plan: [{ environment: "Sandbox" }] });
    await verifyCase("staging failure cannot fall back to Production", {
      hint, plan: [{ environment: "Sandbox", status: 404 }], error: "APPLE_TRANSACTION_NOT_FOUND",
    });
  }
  process.env.NODE_ENV = "test";
  config.appleAppStoreApiBaseUrl = APPLE_PRODUCTION_API_BASE_URL;

  // Exercise real authenticated HTTP handlers with only a loopback listener and
  // the application's memory store. No server exports or existing tests change.
  let resolveListening;
  const listening = new Promise((resolve) => { resolveListening = resolve; });
  net.Server.prototype.listen = function (port, callback) {
    listener = this;
    this.once("listening", () => resolveListening(this.address().port));
    return originalListen.call(this, { port: Number(port), host: "127.0.0.1" }, callback);
  };
  await import("../src/server.js");
  const port = await Promise.race([listening, new Promise((_, reject) => {
    const timer = setTimeout(() => reject(new Error("HTTP startup timeout")), 5000);
    timer.unref();
  })]);
  net.Server.prototype.listen = originalListen;
  const store = await import("../src/store.js");
  async function request(route, body, token) {
    const result = await realFetch(`http://127.0.0.1:${port}${route}`, {
      method: body === undefined ? "GET" : "POST", signal: AbortSignal.timeout(2000),
      headers: { "content-type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: result.status, body: await result.json() };
  }
  async function login(phone) {
    assert.equal((await request("/v1/auth/sms/send", { phone })).status, 200);
    const result = await request("/v1/auth/sms/verify", { phone, code: "654321" });
    assert.equal(result.status, 200);
    return { id: result.body.user.userId, token: result.body.accessToken };
  }
  const noLookup = mockApple([]);
  assert.equal((await request("/v1/iap/verify", {})).status, 401);
  noLookup.complete("unauthenticated verification");
  const owner = await login("13900000001");
  const challenger = await login("13900000002");
  const boundId = "2000000123456790";
  const freshId = "2000000123456791";
  const purchase = (id, extraHint = {}) => ({
    productId: products.monthly, transactionId: id,
    signedTransactionInfo: jws(hintPayload({ transactionId: id, ...extraHint })),
  });
  const snapshots = async () => ({
    owner: await request("/v1/member/me", undefined, owner.token),
    challenger: await request("/v1/member/me", undefined, challenger.token),
    bound: structuredClone(await store.getIAPTransactionByOriginalId(boundId)),
    fresh: structuredClone(await store.getIAPTransactionByOriginalId(freshId)),
  });
  const seed = mockApple([{ environment: "Sandbox", transactionId: boundId,
    payload: { transactionId: boundId, originalTransactionId: boundId, appAccountToken: owner.id } }]);
  const granted = await request("/v1/iap/verify", purchase(boundId), owner.token);
  assert.equal(granted.status, 200);
  assert.equal(granted.body.environment, "Sandbox");
  assert.equal(granted.body.memberTier, "monthly");
  assert.equal((await store.getIAPTransactionByOriginalId(boundId)).userId, owner.id);
  seed.complete("same-account Sandbox purchase grants membership");
  scenarios++;

  async function rejectHTTP(label, { id = freshId, status = 409, error, payload = {}, appleStatus, appleBody }) {
    const before = await snapshots();
    const mock = mockApple([{ environment: "Sandbox", transactionId: id, status: appleStatus, body: appleBody,
      payload: { transactionId: id, originalTransactionId: id, appAccountToken: challenger.id, ...payload } }]);
    // Client claims this account and a future expiry even when Apple disagrees.
    const result = await request("/v1/iap/verify", purchase(id, {
      appAccountToken: challenger.id, expiresDate: Date.now() + 365 * 86400_000, memberTier: "lifetime",
    }), challenger.token);
    assert.equal(result.status, status, label);
    assert.equal(result.body.error, error, label);
    assert.deepEqual(await snapshots(), before, `${label}: both memberships and original bindings remain unchanged`);
    mock.complete(label);
    scenarios++;
  }
  await rejectHTTP("Apple account mismatch with existing binding", {
    id: boundId, error: "APP_ACCOUNT_MISMATCH", payload: { appAccountToken: owner.id },
  });
  await rejectHTTP("Apple account mismatch on first bind", {
    error: "APP_ACCOUNT_MISMATCH", payload: { appAccountToken: owner.id },
  });
  await rejectHTTP("missing Apple account token cannot first-bind", {
    error: "APP_ACCOUNT_TOKEN_MISSING", payload: { appAccountToken: undefined },
  });
  for (const appAccountToken of [challenger.id, undefined]) {
    await rejectHTTP("another account cannot take an existing original transaction", {
      id: boundId, error: "TRANSACTION_ALREADY_BOUND", payload: { appAccountToken },
    });
  }
  for (const [error, payload] of rejectedPayloads.filter(([code]) => code !== "APP_ACCOUNT_MISMATCH")) {
    await rejectHTTP(`HTTP Apple response enforces ${error}`, {
      error, payload, status: error === "APPLE_BAD_RESPONSE" ? 502 : 400,
    });
  }
  for (const appleStatus of [401, 404, 500]) {
    await rejectHTTP(`forged client payload cannot grant after Sandbox ${appleStatus}`, {
      appleStatus, status: 502, error: appleStatus === 404 ? "APPLE_TRANSACTION_NOT_FOUND" : "APPLE_LOOKUP_FAILED",
    });
  }
  await rejectHTTP("client cannot substitute for absent Apple transaction", {
    appleBody: "{}", status: 502, error: "APPLE_BAD_RESPONSE",
  });
  const signedForTamper = signedAppleTransaction(applePayload("Sandbox"));
  const tamperParts = signedForTamper.split(".");
  const tamperedAppleJws = `${tamperParts[0]}.${tamperParts[1]}.${tamperParts[2].startsWith("A") ? "B" : "A"}${tamperParts[2].slice(1)}`;
  await rejectHTTP("tampered Apple signed transaction cannot grant", {
    appleBody: { signedTransactionInfo: tamperedAppleJws }, status: 502, error: "APPLE_BAD_RESPONSE",
  });

  // Simulate a lost local entitlement; restoring the bound account remains valid,
  // including Apple's existing allowance for a tokenless already-owned purchase.
  for (const appAccountToken of [owner.id, undefined]) {
    await store.setSessionByUserId(owner.id, { memberTier: "free", memberExpiresAt: null });
    const beforeBinding = structuredClone(await store.getIAPTransactionByOriginalId(boundId));
    const restoredMock = mockApple([{ environment: "Sandbox", transactionId: boundId,
      payload: { transactionId: boundId, originalTransactionId: boundId, appAccountToken } }]);
    const restored = await request("/v1/iap/verify", purchase(boundId), owner.token);
    assert.equal(restored.status, 200);
    assert.equal(restored.body.memberTier, "monthly");
    assert.equal(restored.body.environment, "Sandbox");
    assert.equal((await request("/v1/member/me", undefined, owner.token)).body.memberTier, "monthly");
    assert.equal((await request("/v1/member/me", undefined, challenger.token)).body.memberTier, "free");
    const afterBinding = await store.getIAPTransactionByOriginalId(boundId);
    assert.deepEqual({ ...afterBinding, verifiedAt: beforeBinding.verifiedAt }, beforeBinding);
    restoredMock.complete("same-account restore");
    scenarios++;
  }
  assert.equal(await store.getIAPTransactionByOriginalId(freshId), null);
} finally {
  process.env.NODE_ENV = "test";
  config.appleAppStoreApiBaseUrl = APPLE_PRODUCTION_API_BASE_URL;
  net.Server.prototype.listen = originalListen;
  globalThis.fetch = realFetch;
  if (listener) {
    listener.closeAllConnections();
    await new Promise((resolve) => listener.close(resolve));
  }
}
console.log(`IAP Sandbox routing verified: ${scenarios} scenarios; exact endpoint/call counts, bounded untrusted hints, unchanged Apple validation, HTTP account/binding rejection without writes, and same-account purchase/restore.`);
