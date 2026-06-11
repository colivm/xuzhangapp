import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";
import fs from "node:fs";

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: resolve(__dirname, "..", ".env") });

export const config = {
  port: Number(process.env.PORT || 8790),
  jwtSecret: process.env.JWT_SECRET || "dev-secret-change-me",
  allowOrigin: process.env.ALLOW_ORIGIN || "*",
  aiProxyBaseUrl: process.env.AI_PROXY_BASE_URL || "http://localhost:8787",
  aiProxyToken: process.env.AI_PROXY_TOKEN || "",
  smsProvider: process.env.SMS_PROVIDER || "",
  devAllowSmsCode: process.env.DEV_ALLOW_SMS_CODE || (process.env.NODE_ENV === "production" ? "" : "123456"),
  aliyunSmsAccessKeyId: process.env.ALIYUN_SMS_ACCESS_KEY_ID || "",
  aliyunSmsAccessKeySecret: process.env.ALIYUN_SMS_ACCESS_KEY_SECRET || "",
  aliyunSmsSignName: process.env.ALIYUN_SMS_SIGN_NAME || "",
  aliyunSmsTemplateCode: process.env.ALIYUN_SMS_TEMPLATE_CODE || "",
  aliyunSmsEndpoint: process.env.ALIYUN_SMS_ENDPOINT || "dysmsapi.aliyuncs.com",
  databaseUrl: process.env.DATABASE_URL || "",
  appleIssuerId: process.env.APPLE_ISSUER_ID || "",
  appleKeyId: process.env.APPLE_KEY_ID || "",
  appleBundleId: process.env.APPLE_BUNDLE_ID || "",
  applePrivateKeyPath: process.env.APPLE_PRIVATE_KEY_PATH || "",
  applePrivateKey: process.env.APPLE_PRIVATE_KEY || "",
  appleAppStoreApiBaseUrl: process.env.APPLE_APP_STORE_API_BASE_URL || "https://api.storekit.itunes.apple.com",
  iapProductIds: {
    monthly: process.env.IAP_MONTHLY_PRODUCT_ID || "",
    yearly: process.env.IAP_YEARLY_PRODUCT_ID || "",
    lifetime: process.env.IAP_LIFETIME_PRODUCT_ID || "",
  },
};

export function loadApplePrivateKey() {
  if (config.applePrivateKey) {
    return config.applePrivateKey.replace(/\\n/g, "\n");
  }
  if (!config.applePrivateKeyPath) return "";
  return fs.readFileSync(config.applePrivateKeyPath, "utf8");
}
