import assert from "node:assert/strict";
import {
  APPLE_PRODUCTION_API_BASE_URL,
  APPLE_SANDBOX_API_BASE_URL,
  normalizeNodeEnv,
  validateIAPEnvironmentConfig,
} from "../src/config.js";
import { shouldFallbackToSandbox } from "../src/iapService.js";

const shared = {
  appleIssuerId: "issuer",
  appleKeyId: "key",
  appleBundleId: "com.xuzhang.app",
  appleAppAppleId: "1234567890",
  applePrivateKeyPath: "/opt/xuzhang/secrets/AuthKey_key.p8",
  applePrivateKey: "",
  iapProductIds: { monthly: "monthly", yearly: "yearly", lifetime: "lifetime" },
};

assert.deepEqual(
  validateIAPEnvironmentConfig("production", {
    ...shared,
    appleAppStoreApiBaseUrl: APPLE_PRODUCTION_API_BASE_URL,
  }),
  [],
  "production accepts only the production endpoint"
);

assert.equal(normalizeNodeEnv("  Production "), "production", "NODE_ENV is normalized before branching");
assert.equal(normalizeNodeEnv("PRODUCTION"), "production", "NODE_ENV normalization is case-insensitive");
assert.equal(
  shouldFallbackToSandbox({ endpointEnvironment: "Production", error: { appleTransactionNotFound: true } }),
  true,
  "production falls back only after Apple transaction-not-found"
);
assert.equal(
  shouldFallbackToSandbox({ endpointEnvironment: "Production", error: { appleTransactionNotFound: false } }),
  false,
  "production does not fall back after auth or server failures"
);
assert.equal(
  shouldFallbackToSandbox({ endpointEnvironment: "Sandbox", error: { appleTransactionNotFound: true } }),
  false,
  "staging remains Sandbox-only"
);

for (const variant of [
  `${APPLE_PRODUCTION_API_BASE_URL}/?query=1`,
  `${APPLE_PRODUCTION_API_BASE_URL}/#fragment`,
  "https://api.storekit.itunes.apple.com:8443",
  "https://user:pass@api.storekit.itunes.apple.com",
]) {
  assert.ok(
    validateIAPEnvironmentConfig("production", { ...shared, appleAppStoreApiBaseUrl: variant }).some((issue) => issue.includes("production must use")),
    `production rejects endpoint variant: ${variant}`
  );
}

assert.ok(
  validateIAPEnvironmentConfig("staging", {
    ...shared,
    appleAppStoreApiBaseUrl: APPLE_SANDBOX_API_BASE_URL,
    appleIssuerId: "<shared-app-store-server-api-issuer-id>",
  }).some((issue) => issue.includes("placeholder")),
  "staging rejects copied placeholder credentials"
);
assert.ok(
  validateIAPEnvironmentConfig("production", {
    ...shared,
    appleAppStoreApiBaseUrl: APPLE_PRODUCTION_API_BASE_URL,
    appleBundleId: "com.example.NativeDemoApp",
  }).some((issue) => issue.includes("placeholder")),
  "production rejects example bundle identifiers"
);
assert.ok(
  validateIAPEnvironmentConfig("production", {
    ...shared,
    appleAppStoreApiBaseUrl: APPLE_SANDBOX_API_BASE_URL,
  }).some((issue) => issue.includes("production must use")),
  "production rejects the Sandbox endpoint"
);
assert.deepEqual(
  validateIAPEnvironmentConfig("staging", {
    ...shared,
    appleAppStoreApiBaseUrl: APPLE_SANDBOX_API_BASE_URL,
  }),
  [],
  "staging accepts the Sandbox endpoint"
);
assert.ok(
  validateIAPEnvironmentConfig("staging", {
    ...shared,
    appleAppStoreApiBaseUrl: APPLE_PRODUCTION_API_BASE_URL,
  }).some((issue) => issue.includes("staging must use")),
  "staging rejects the production endpoint"
);

console.log("IAP environment gate verified.");
