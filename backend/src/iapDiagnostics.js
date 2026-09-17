import { randomUUID } from "node:crypto";
import { config, APPLE_PRODUCTION_API_BASE_URL, APPLE_SANDBOX_API_BASE_URL } from "./config.js";
import { makeAppStoreServerToken } from "./iapService.js";

const MAX_WINDOW_MS = 24 * 60 * 60 * 1000;
const COOLDOWN_MS = 60_000;
const MAX_RUNS = 5; // Per process; no new Redis/database dependency.
const TIMEOUT_MS = 8000;
const MAX_BODY_BYTES = 128 * 1024;
const FAILURE_CODES = new Set(["APPLE_LOOKUP_FAILED", "APPLE_TRANSACTION_NOT_FOUND", "APPLE_BAD_RESPONSE"]);
const ENDPOINTS = [["Production", APPLE_PRODUCTION_API_BASE_URL], ["Sandbox", APPLE_SANDBOX_API_BASE_URL]];

function environment(value) {
  return value === "Production" || value === "Sandbox" ? value : "Unknown";
}

export function iapDiagnosticStatus(settings = config.iapDiagnostics, now = Date.now()) {
  if (settings?.enabled !== "true") return { active: false, reason: "disabled" };
  if (!/^1\d{10}$/.test(settings.phone || "")) return { active: false, reason: "invalid_phone" };
  const expiry = settings.expiresAt || "";
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(expiry)) {
    return { active: false, reason: "invalid_expiry" };
  }
  const remaining = Date.parse(expiry) - now;
  if (!Number.isFinite(remaining)) return { active: false, reason: "invalid_expiry" };
  if (remaining <= 0) return { active: false, reason: "expired" };
  if (remaining > MAX_WINDOW_MS) return { active: false, reason: "expiry_too_far" };
  return { active: true, expiresAt: expiry };
}

// Decoding here is ONLY for diagnostic hints/comparisons, never authorization.
function diagnosticPayload(jws) {
  if (typeof jws !== "string" || jws.length > MAX_BODY_BYTES) return null;
  const parts = jws.split(".");
  if (parts.length !== 3 || !/^[A-Za-z0-9_-]+$/.test(parts[1])) return null;
  try {
    const value = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    return value && typeof value === "object" && !Array.isArray(value) ? value : null;
  } catch { return null; }
}

async function limitedJSON(response) {
  const reader = response.body?.getReader();
  if (!reader) return {};
  const chunks = [];
  let size = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BODY_BYTES) {
        void reader.cancel().catch(() => {});
        throw new Error("diagnostic_body_limit");
      }
      chunks.push(Buffer.from(value));
    }
  } finally { reader.releaseLock(); }
  try { return JSON.parse(Buffer.concat(chunks).toString("utf8")); }
  catch { return {}; }
}

function responseSummary(response, json, input, bundleId, clock) {
  const appleDate = Date.parse(response.headers.get("date") || "");
  const result = {
    httpStatus: response.status,
    appleErrorCode: Number.isInteger(json?.errorCode) && json.errorCode >= 0 && json.errorCode < 100_000_000
      ? json.errorCode : null,
    clockDifferenceSeconds: Number.isFinite(appleDate) ? Math.round((appleDate - clock()) / 1000) : null,
  };
  // Never log errorMessage, response text, JWS, IDs, product names or headers.
  if (response.status === 200) {
    const payload = diagnosticPayload(json?.signedTransactionInfo);
    result.hasTransactionPayload = payload !== null;
    if (payload) {
      result.responseEnvironment = environment(payload.environment);
      result.productMatches = payload.productId === input.productId;
      result.transactionMatches = String(payload.transactionId || "") === input.transactionId;
      result.bundleMatches = payload.bundleId === bundleId;
      result.accountMatches = typeof payload.appAccountToken === "string"
        && payload.appAccountToken.toLowerCase() === input.accountToken.toLowerCase();
      result.revoked = Boolean(payload.revocationDate);
      const expires = Number(payload.expiresDate);
      result.expired = Number.isFinite(expires) && expires > 0 ? expires <= clock() : null;
      result.signatureVerified = false; // Existing JWS verification gap is not hidden by this probe.
    }
  }
  return result;
}

/** A failure-only, bounded observer; deliberately has no store or entitlement dependencies. */
export function createIAPFailureDiagnostics({
  settings,
  bundleId,
  productIds,
  tokenProvider,
  fetchImpl = (...args) => fetch(...args),
  clock = () => Date.now(),
  emit = (entry) => console.info("[iap-diagnostic]", JSON.stringify(entry)),
  defer = (run) => setImmediate(run),
  timeoutMs = TIMEOUT_MS,
}) {
  let running = false;
  let lastStarted = -Infinity;
  let runs = 0;
  // Invalid/far-future settings must not silently become active days later.
  const validAtStart = iapDiagnosticStatus(settings, clock()).active;
  const budgetMs = Math.max(1, Math.min(TIMEOUT_MS, Number(timeoutMs) || TIMEOUT_MS));

  function write(entry) {
    try { emit(entry); } catch { /* Logging failure cannot affect the payment response. */ }
  }

  async function probe([targetEnvironment, baseUrl], input) {
    const controller = new AbortController();
    let timer;
    const job = (async () => {
      const token = tokenProvider();
      const response = await fetchImpl(`${baseUrl}/inApps/v1/transactions/${encodeURIComponent(input.transactionId)}`, {
        method: "GET",
        headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
        signal: controller.signal,
        redirect: "error",
      });
      return responseSummary(response, await limitedJSON(response), input, bundleId, clock);
    })();
    try {
      const result = await Promise.race([job, new Promise((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(new Error("diagnostic_timeout"));
        }, budgetMs);
      })]);
      return { environment: targetEnvironment, ...result };
    } catch (error) {
      controller.abort();
      return {
        environment: targetEnvironment,
        outcome: error?.message === "diagnostic_body_limit" ? "body_limit"
          : (controller.signal.aborted && error?.name === "AbortError") || error?.message === "diagnostic_timeout"
            ? "timeout" : "probe_failed",
      };
    } finally { clearTimeout(timer); }
  }

  function schedule(raw) {
    let reserved = false;
    try {
      if (!validAtStart || !iapDiagnosticStatus(settings, clock()).active || running || runs >= MAX_RUNS
          || raw?.phone !== settings.phone || !FAILURE_CODES.has(raw.failureCode)
          || clock() - lastStarted < COOLDOWN_MS) return false;
      const tier = Object.entries(productIds).find(([, id]) => id && id === raw.productId)?.[0];
      if (!["monthly", "yearly", "lifetime"].includes(tier)
          || typeof raw.transactionId !== "string" || !/^[1-9]\d{5,29}$/.test(raw.transactionId)
          || typeof raw.accountToken !== "string" || !raw.accountToken) return false;
      const input = { transactionId: raw.transactionId, productId: raw.productId, accountToken: raw.accountToken };
      const entry = {
        event: "iap_failure_diagnostic",
        diagnosticId: randomUUID(),
        tier,
        failureCode: raw.failureCode,
        failedLookupEnvironment: environment(raw.failedLookupEnvironment),
        failedLookupStatus: Number.isInteger(raw.failedLookupStatus) && raw.failedLookupStatus >= 100 && raw.failedLookupStatus <= 599
          ? raw.failedLookupStatus : null,
        clientEnvironmentHint: environment(diagnosticPayload(raw.signedTransactionInfo)?.environment),
        clientHintVerified: false,
        grantsMembership: false,
      };
      running = true;
      reserved = true;
      lastStarted = clock();
      runs += 1;
      defer(() => {
        // Recheck expiry if scheduling was delayed. Do not retain the incoming JWS/phone.
        if (!iapDiagnosticStatus(settings, clock()).active) { running = false; return; }
        void Promise.all(ENDPOINTS.map((target) => probe(target, input)))
          .then((checks) => write({ ...entry, checks }))
          .catch(() => write({ ...entry, outcome: "diagnostic_failed" }))
          .finally(() => { running = false; });
      });
      return true;
    } catch {
      if (reserved) running = false;
      return false;
    }
  }

  return { schedule };
}

export const iapFailureDiagnostics = createIAPFailureDiagnostics({
  settings: config.iapDiagnostics,
  bundleId: config.appleBundleId,
  productIds: config.iapProductIds,
  tokenProvider: makeAppStoreServerToken,
});
