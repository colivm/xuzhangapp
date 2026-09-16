import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";
import fs from "node:fs";

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: resolve(__dirname, "..", ".env") });

export const APPLE_PRODUCTION_API_BASE_URL = "https://api.storekit.itunes.apple.com";
export const APPLE_SANDBOX_API_BASE_URL = "https://api.storekit-sandbox.itunes.apple.com";

export const config = {
  port: Number(process.env.PORT || 8790),
  jwtSecret: process.env.JWT_SECRET || "dev-secret-change-me",
  allowOrigin: process.env.ALLOW_ORIGIN || "*",
  aiProxyBaseUrl: process.env.AI_PROXY_BASE_URL || "http://localhost:8787",
  aiProxyToken: process.env.AI_PROXY_TOKEN || "",
  redisUrl: process.env.REDIS_URL || "",
  redisKeyPrefix: process.env.REDIS_KEY_PREFIX || "xuzhang",
  smsProvider: process.env.SMS_PROVIDER || "",
  devAllowSmsCode: process.env.DEV_ALLOW_SMS_CODE || "",
  aliyunSmsAccessKeyId: process.env.ALIYUN_SMS_ACCESS_KEY_ID || "",
  aliyunSmsAccessKeySecret: process.env.ALIYUN_SMS_ACCESS_KEY_SECRET || "",
  aliyunSmsSchemeName: process.env.ALIYUN_SMS_SCHEME_NAME || "",
  aliyunSmsCountryCode: process.env.ALIYUN_SMS_COUNTRY_CODE || "86",
  aliyunSmsSignName: process.env.ALIYUN_SMS_SIGN_NAME || "",
  aliyunSmsTemplateCode: process.env.ALIYUN_SMS_TEMPLATE_CODE || "",
  aliyunSmsTemplateMin: process.env.ALIYUN_SMS_TEMPLATE_MIN || "5",
  aliyunSmsEndpoint: process.env.ALIYUN_SMS_ENDPOINT || "dypnsapi.aliyuncs.com",
  databaseUrl: process.env.DATABASE_URL || "",
  appleIssuerId: process.env.APPLE_ISSUER_ID || "",
  appleKeyId: process.env.APPLE_KEY_ID || "",
  appleBundleId: process.env.APPLE_BUNDLE_ID || "",
  applePrivateKeyPath: process.env.APPLE_PRIVATE_KEY_PATH || "",
  applePrivateKey: process.env.APPLE_PRIVATE_KEY || "",
  appleAppStoreApiBaseUrl: process.env.APPLE_APP_STORE_API_BASE_URL || APPLE_PRODUCTION_API_BASE_URL,
  iapProductIds: {
    monthly: process.env.IAP_MONTHLY_PRODUCT_ID || "",
    yearly: process.env.IAP_YEARLY_PRODUCT_ID || "",
    lifetime: process.env.IAP_LIFETIME_PRODUCT_ID || "",
  },
};

/**
 * Production and staging must use separate Apple environments. Keeping this
 * check at process start prevents a copied staging .env from silently turning
 * production verification into Sandbox verification.
 */
export function validateIAPEnvironmentConfig(nodeEnv = process.env.NODE_ENV, runtimeConfig = config) {
  const mode = String(nodeEnv || "").trim().toLowerCase();
  if (mode !== "production" && mode !== "staging") return [];

  const expectedBase = mode === "production"
    ? APPLE_PRODUCTION_API_BASE_URL
    : APPLE_SANDBOX_API_BASE_URL;
  const issues = [];
  let actual;
  try {
    actual = new URL(runtimeConfig.appleAppStoreApiBaseUrl);
  } catch {
    issues.push("APPLE_APP_STORE_API_BASE_URL must be a valid HTTPS URL.");
    return issues;
  }
  const expected = new URL(expectedBase);
  if (actual.protocol !== "https:" || actual.hostname !== expected.hostname || actual.pathname !== "/") {
    issues.push(`${mode} must use ${expectedBase} for App Store transaction verification.`);
  }
  const required = [
    ["APPLE_ISSUER_ID", runtimeConfig.appleIssuerId],
    ["APPLE_KEY_ID", runtimeConfig.appleKeyId],
    ["APPLE_BUNDLE_ID", runtimeConfig.appleBundleId],
    ["APPLE_PRIVATE_KEY_PATH or APPLE_PRIVATE_KEY", runtimeConfig.applePrivateKeyPath || runtimeConfig.applePrivateKey],
    ["IAP_MONTHLY_PRODUCT_ID", runtimeConfig.iapProductIds.monthly],
    ["IAP_YEARLY_PRODUCT_ID", runtimeConfig.iapProductIds.yearly],
    ["IAP_LIFETIME_PRODUCT_ID", runtimeConfig.iapProductIds.lifetime],
  ];
  for (const [name, value] of required) {
    if (!String(value || "").trim()) issues.push(`${name} is required for ${mode} IAP verification.`);
  }
  return issues;
}

export function loadApplePrivateKey() {
  if (config.applePrivateKey) {
    return config.applePrivateKey.replace(/\\n/g, "\n");
  }
  if (!config.applePrivateKeyPath) return "";
  return fs.readFileSync(config.applePrivateKeyPath, "utf8");
}
