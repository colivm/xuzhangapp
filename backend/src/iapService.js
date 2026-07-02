import jwt from "jsonwebtoken";
import { config, loadApplePrivateKey } from "./config.js";

export class IAPVerifyError extends Error {
  constructor(code, message, status = 400) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export function tierForProductId(productId) {
  return Object.entries(config.iapProductIds).find(([, id]) => id && id === productId)?.[0] || "";
}

export async function verifyAppStoreTransaction({ productId, transactionId, signedTransactionInfo, expectedAppAccountToken }) {
  ensureAppleConfig();
  if (!tierForProductId(productId)) {
    throw new IAPVerifyError("UNKNOWN_PRODUCT", "Unknown IAP productId.", 400);
  }

  const transactionInfo = await resolveTransactionInfo({ transactionId, signedTransactionInfo });
  const payload = decodeJWSPayload(transactionInfo.signedTransactionInfo);
  validateTransactionPayload(payload, { productId, transactionId });
  const appAccountToken = validateAppAccountToken(payload, expectedAppAccountToken);

  const tier = tierForProductId(payload.productId);
  const memberExpiresAt = tier === "lifetime" ? null : expiresAtFromPayload(payload);
  if (tier !== "lifetime" && (!memberExpiresAt || Date.parse(memberExpiresAt) <= Date.now())) {
    throw new IAPVerifyError("TRANSACTION_EXPIRED", "The App Store transaction is expired.", 400);
  }

  return {
    productId: payload.productId,
    transactionId: String(payload.transactionId || transactionId),
    originalTransactionId: String(payload.originalTransactionId || payload.transactionId || transactionId),
    memberTier: tier,
    memberExpiresAt,
    environment: payload.environment || transactionInfo.environment || null,
    signedTransactionInfo: transactionInfo.signedTransactionInfo,
    appAccountToken,
    hasAppAccountToken: Boolean(appAccountToken),
  };
}

function ensureAppleConfig() {
  const missing = [];
  if (!config.appleIssuerId) missing.push("APPLE_ISSUER_ID");
  if (!config.appleKeyId) missing.push("APPLE_KEY_ID");
  if (!config.appleBundleId) missing.push("APPLE_BUNDLE_ID");
  if (!config.applePrivateKey && !config.applePrivateKeyPath) missing.push("APPLE_PRIVATE_KEY_PATH");
  if (!config.iapProductIds.monthly) missing.push("IAP_MONTHLY_PRODUCT_ID");
  if (!config.iapProductIds.yearly) missing.push("IAP_YEARLY_PRODUCT_ID");
  if (!config.iapProductIds.lifetime) missing.push("IAP_LIFETIME_PRODUCT_ID");
  if (missing.length) {
    throw new IAPVerifyError("IAP_NOT_CONFIGURED", `Missing env: ${missing.join(", ")}`, 503);
  }
}

async function fetchTransactionInfo(transactionId) {
  const token = makeAppStoreServerToken();
  const base = config.appleAppStoreApiBaseUrl.replace(/\/$/, "");
  const url = `${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`;
  const response = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });
  const text = await response.text();
  if (!response.ok) {
    throw new IAPVerifyError("APPLE_LOOKUP_FAILED", text || `Apple lookup failed (${response.status})`, 502);
  }
  const json = JSON.parse(text || "{}");
  if (!json.signedTransactionInfo) {
    throw new IAPVerifyError("APPLE_BAD_RESPONSE", "Apple response missing signedTransactionInfo.", 502);
  }
  return json;
}

async function resolveTransactionInfo({ transactionId, signedTransactionInfo }) {
  void signedTransactionInfo;
  return fetchTransactionInfo(transactionId);
}

function makeAppStoreServerToken() {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: config.appleIssuerId,
      iat: now,
      exp: now + 300,
      aud: "appstoreconnect-v1",
      bid: config.appleBundleId,
    },
    loadApplePrivateKey(),
    {
      algorithm: "ES256",
      keyid: config.appleKeyId,
    }
  );
}

function validateTransactionPayload(payload, { productId, transactionId }) {
  if (String(payload.productId || "") !== productId) {
    throw new IAPVerifyError("PRODUCT_MISMATCH", "Transaction productId does not match request.", 400);
  }
  if (payload.transactionId && String(payload.transactionId) !== String(transactionId)) {
    throw new IAPVerifyError("TRANSACTION_MISMATCH", "Transaction id does not match request.", 400);
  }
  if (payload.bundleId && payload.bundleId !== config.appleBundleId) {
    throw new IAPVerifyError("BUNDLE_MISMATCH", "Transaction bundleId does not match server config.", 400);
  }
  if (payload.revocationDate) {
    throw new IAPVerifyError("TRANSACTION_REVOKED", "Transaction has been revoked.", 400);
  }
}

function validateAppAccountToken(payload, expectedAppAccountToken) {
  const expected = normalizeAppAccountToken(expectedAppAccountToken);
  const actual = normalizeAppAccountToken(payload.appAccountToken);
  if (!expected) {
    throw new IAPVerifyError("APP_ACCOUNT_TOKEN_REQUIRED", "Current account is required to verify App Store membership.", 400);
  }
  if (!actual) {
    return null;
  }
  if (actual !== expected) {
    throw new IAPVerifyError("APP_ACCOUNT_MISMATCH", "Transaction belongs to another xLife account.", 409);
  }
  return actual;
}

function normalizeAppAccountToken(value) {
  return String(value || "").trim().toLowerCase();
}

function expiresAtFromPayload(payload) {
  if (!payload.expiresDate) return null;
  const millis = Number(payload.expiresDate);
  if (Number.isFinite(millis) && millis > 0) {
    return new Date(millis).toISOString();
  }
  const parsed = Date.parse(String(payload.expiresDate));
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : null;
}

function decodeJWSPayload(jws) {
  const parts = String(jws || "").split(".");
  if (parts.length < 2) {
    throw new IAPVerifyError("INVALID_SIGNED_TRANSACTION", "Invalid signedTransactionInfo.", 400);
  }
  const json = Buffer.from(parts[1], "base64url").toString("utf8");
  return JSON.parse(json);
}
