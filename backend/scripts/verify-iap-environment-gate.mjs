import assert from "node:assert/strict";
import {
  APPLE_PRODUCTION_API_BASE_URL,
  APPLE_SANDBOX_API_BASE_URL,
  validateIAPEnvironmentConfig,
} from "../src/config.js";

const shared = {
  appleIssuerId: "issuer",
  appleKeyId: "key",
  appleBundleId: "com.xuzhang.app",
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
