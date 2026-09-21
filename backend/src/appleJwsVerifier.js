import fs from "node:fs";
import { Environment, SignedDataVerifier } from "@apple/app-store-server-library";
import { config } from "./config.js";

const MAX_JWS_BYTES = 128 * 1024;
const MAX_CERT_BYTES = 16 * 1024;
const BASE64URL = /^[A-Za-z0-9_-]+$/;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;
const verifiers = new Map();

export class AppleJwsVerificationError extends Error {
  constructor(message) {
    super(message);
    this.code = "APPLE_JWS_INVALID";
  }
}

function decodeJsonPart(value, label) {
  if (!BASE64URL.test(value)) throw new AppleJwsVerificationError(`Invalid ${label} encoding.`);
  try {
    return JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
  } catch {
    throw new AppleJwsVerificationError(`Invalid ${label} JSON.`);
  }
}

function inspectProtectedHeader(signedTransactionInfo) {
  if (typeof signedTransactionInfo !== "string" || Buffer.byteLength(signedTransactionInfo, "utf8") > MAX_JWS_BYTES) {
    throw new AppleJwsVerificationError("Signed transaction JWS is too large.");
  }
  const parts = signedTransactionInfo.split(".");
  if (parts.length !== 3 || parts.some((part) => !BASE64URL.test(part))) {
    throw new AppleJwsVerificationError("Signed transaction JWS must have three compact parts.");
  }
  const header = decodeJsonPart(parts[0], "JWS header");
  if (!header || Array.isArray(header) || header.alg !== "ES256") {
    throw new AppleJwsVerificationError("Signed transaction JWS must use ES256.");
  }
  if (!Array.isArray(header.x5c) || header.x5c.length !== 3 || header.x5c.some((cert) => (
    typeof cert !== "string" || cert.length === 0 || cert.length > MAX_CERT_BYTES || !BASE64.test(cert)
  ))) {
    throw new AppleJwsVerificationError("Signed transaction JWS must contain a three-certificate x5c chain.");
  }
}

function rootCertificates() {
  const paths = String(config.appleRootCaPaths || "").split(",").map((path) => path.trim()).filter(Boolean);
  if (paths.length === 0 || paths.length > 4) throw new AppleJwsVerificationError("Apple root certificates are not configured.");
  try {
    return paths.map((path) => fs.readFileSync(path));
  } catch {
    throw new AppleJwsVerificationError("Apple root certificates are unavailable.");
  }
}

function verifierFor(expectedEnvironment) {
  const environment = expectedEnvironment === "Sandbox" ? Environment.SANDBOX : Environment.PRODUCTION;
  const key = `${environment}:${config.appleBundleId}:${config.appleAppAppleId || ""}:${config.appleJwsOnlineChecks}:${config.appleRootCaPaths}`;
  if (!verifiers.has(key)) {
    let appAppleId;
    if (environment === Environment.PRODUCTION) {
      const parsed = Number(config.appleAppAppleId);
      if (!Number.isSafeInteger(parsed) || parsed <= 0) {
        throw new AppleJwsVerificationError("APPLE_APPLE_ID is required for production JWS verification.");
      }
      appAppleId = parsed;
    }
    verifiers.set(key, new SignedDataVerifier(
      rootCertificates(),
      config.appleJwsOnlineChecks,
      environment,
      config.appleBundleId,
      appAppleId,
    ));
  }
  return verifiers.get(key);
}

export async function verifyAppleSignedTransaction(signedTransactionInfo, expectedEnvironment) {
  inspectProtectedHeader(signedTransactionInfo);
  try {
    return await verifierFor(expectedEnvironment).verifyAndDecodeTransaction(signedTransactionInfo);
  } catch (error) {
    if (error instanceof AppleJwsVerificationError) throw error;
    throw new AppleJwsVerificationError("Apple signed transaction verification failed.");
  }
}
