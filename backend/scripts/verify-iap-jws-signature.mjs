import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const configSource = readFileSync(new URL("../src/config.js", import.meta.url), "utf8");
for (const [, name] of configSource.matchAll(/process\.env\.([A-Z0-9_]+)/g)) process.env[name] = "";
const fixtureRoot = new URL("./fixtures/apple-jws-test/root.pem", import.meta.url);
const fixtureRootPath = fileURLToPath(fixtureRoot);
const { signedAppleTransaction } = await import("./support/appleJwsFixture.mjs");
Object.assign(process.env, {
  NODE_ENV: "test",
  APPLE_BUNDLE_ID: "com.jws.test",
  APPLE_APPLE_ID: "1234567890",
  APPLE_ROOT_CA_PATHS: fixtureRootPath,
  APPLE_JWS_ONLINE_CHECKS: "false",
});
const { AppleJwsVerificationError, verifyAppleSignedTransaction } = await import("../src/appleJwsVerifier.js");
const { config } = await import("../src/config.js");

const basePayload = (environment = "Production") => ({
  environment,
  bundleId: config.appleBundleId,
  productId: "com.jws.test.monthly",
  transactionId: "2000000123456789",
  originalTransactionId: "2000000123456789",
  signedDate: Date.now(),
  expiresDate: Date.now() + 3_600_000,
});
const valid = (environment = "Production", patch = {}, header = {}) => {
  const signed = signedAppleTransaction({ ...basePayload(environment), ...patch }, {});
  if (Object.keys(header).length === 0) return signed;
  const parts = signed.split(".");
  return `${Buffer.from(JSON.stringify({ alg: "ES256", ...header })).toString("base64url")}.${parts[1]}.${parts[2]}`;
};
const expectInvalid = async (label, jws, environment = "Production") => {
  await assert.rejects(
    () => verifyAppleSignedTransaction(jws, environment),
    (error) => error instanceof AppleJwsVerificationError,
    label,
  );
};

await verifyAppleSignedTransaction(valid(), "Production");
await verifyAppleSignedTransaction(valid("Sandbox"), "Sandbox");

const parts = valid().split(".");
const signatureTampered = `${parts[0]}.${parts[1]}.${parts[2].startsWith("A") ? "B" : "A"}${parts[2].slice(1)}`;
await expectInvalid("signature tampering is rejected", signatureTampered);
const payloadTampered = `${parts[0]}.${Buffer.from(JSON.stringify({ ...basePayload(), productId: "other" })).toString("base64url")}.${parts[2]}`;
await expectInvalid("payload tampering is rejected", payloadTampered);
await expectInvalid("missing x5c is rejected", valid("Production", {}, { x5c: undefined }));
await expectInvalid("wrong algorithm is rejected", valid("Production", {}, { alg: "HS256" }));
await expectInvalid("two-certificate chain is rejected", valid("Production", {}, { x5c: ["AA", "BB"] }));
await expectInvalid("four-certificate chain is rejected", valid("Production", {}, { x5c: ["AA", "BB", "CC", "DD"] }));
await expectInvalid("two-part JWS is rejected", `${parts[0]}.${parts[1]}`);
await expectInvalid("oversized JWS is rejected", `${parts[0]}.${parts[1]}.${parts[2]}${"A".repeat(128 * 1024)}`);

config.appleRootCaPaths = fileURLToPath(new URL("../../certs/apple-root-ca-g3.cer", import.meta.url));
await expectInvalid("untrusted root is rejected", valid());

console.log("IAP Apple JWS signature verification verified: valid production/sandbox chains, tampering, algorithm, chain shape, size, and untrusted-root rejection.");
