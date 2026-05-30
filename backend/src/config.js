import dotenv from "dotenv";

dotenv.config();

export const config = {
  port: Number(process.env.PORT || 8790),
  jwtSecret: process.env.JWT_SECRET || "dev-secret-change-me",
  allowOrigin: process.env.ALLOW_ORIGIN || "*",
  aiProxyBaseUrl: process.env.AI_PROXY_BASE_URL || "http://localhost:8787",
  aiProxyToken: process.env.AI_PROXY_TOKEN || "",
  devAllowSmsCode: process.env.DEV_ALLOW_SMS_CODE || "123456",
  databaseUrl: process.env.DATABASE_URL || "",
};
