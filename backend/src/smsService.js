import crypto from "node:crypto";
import https from "node:https";
import { config } from "./config.js";

const SMS_CODE_TTL_MS = 5 * 60 * 1000;

export class SmsProviderError extends Error {
  constructor(code, message) {
    super(message || code);
    this.name = "SmsProviderError";
    this.code = code;
  }
}

export function getSmsProviderMode() {
  return String(config.smsProvider || "").trim().toLowerCase();
}

export function isSmsConfigured() {
  const provider = getSmsProviderMode();
  if (!provider || provider === "dev") return Boolean(config.devAllowSmsCode);
  if (provider === "aliyun") {
    return Boolean(
      config.aliyunSmsAccessKeyId &&
        config.aliyunSmsAccessKeySecret &&
        config.aliyunSmsSignName &&
        config.aliyunSmsTemplateCode
    );
  }
  return false;
}

export async function sendLoginSmsCode(phone) {
  const provider = getSmsProviderMode();
  if (!provider || provider === "dev") {
    if (!config.devAllowSmsCode) {
      throw new SmsProviderError("SMS_NOT_CONFIGURED", "SMS provider is not configured.");
    }
    return {
      code: config.devAllowSmsCode,
      expireAt: Date.now() + SMS_CODE_TTL_MS,
      provider: "dev",
    };
  }
  if (provider === "aliyun") {
    const code = generateSmsCode();
    await sendAliyunSms({
      phone,
      code,
      signName: config.aliyunSmsSignName,
      templateCode: config.aliyunSmsTemplateCode,
    });
    return {
      code,
      expireAt: Date.now() + SMS_CODE_TTL_MS,
      provider: "aliyun",
    };
  }
  throw new SmsProviderError("SMS_PROVIDER_UNSUPPORTED", "Unsupported SMS provider.");
}

function generateSmsCode() {
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");
}

async function sendAliyunSms({ phone, code, signName, templateCode }) {
  if (!isSmsConfigured()) {
    throw new SmsProviderError("SMS_NOT_CONFIGURED", "Aliyun SMS provider is not configured.");
  }
  const request = buildAliyunSendSmsRequest({
    phone,
    signName,
    templateCode,
    templateParam: JSON.stringify({ code }),
  });
  const response = await requestAliyun(request);
  if (response.Code !== "OK") {
    throw new SmsProviderError(response.Code || "ALIYUN_SMS_FAILED", response.Message || "Aliyun SMS send failed.");
  }
}

function buildAliyunSendSmsRequest({ phone, signName, templateCode, templateParam }) {
  const endpoint = config.aliyunSmsEndpoint || "dysmsapi.aliyuncs.com";
  const params = {
    PhoneNumbers: phone,
    SignName: signName,
    TemplateCode: templateCode,
    TemplateParam: templateParam,
  };
  const query = canonicalQuery(params);
  const payloadHash = sha256Hex("");
  const headers = {
    host: endpoint,
    "x-acs-action": "SendSms",
    "x-acs-content-sha256": payloadHash,
    "x-acs-date": new Date().toISOString().replace(/\.\d{3}Z$/, "Z"),
    "x-acs-signature-nonce": crypto.randomUUID().replace(/-/g, ""),
    "x-acs-version": "2017-05-25",
  };
  const signedHeaders = Object.keys(headers).sort().join(";");
  const canonicalHeaders = Object.keys(headers)
    .sort()
    .map((key) => `${key}:${String(headers[key]).trim()}\n`)
    .join("");
  const canonicalRequest = ["POST", "/", query, canonicalHeaders, signedHeaders, payloadHash].join("\n");
  const stringToSign = `ACS3-HMAC-SHA256\n${sha256Hex(canonicalRequest)}`;
  const signature = crypto
    .createHmac("sha256", config.aliyunSmsAccessKeySecret)
    .update(stringToSign)
    .digest("hex");
  return {
    endpoint,
    query,
    headers: {
      ...headers,
      Authorization: `ACS3-HMAC-SHA256 Credential=${config.aliyunSmsAccessKeyId},SignedHeaders=${signedHeaders},Signature=${signature}`,
    },
  };
}

function canonicalQuery(params) {
  return Object.keys(params)
    .sort()
    .map((key) => `${percentEncode(key)}=${percentEncode(params[key])}`)
    .join("&");
}

function requestAliyun({ endpoint, query, headers }) {
  return new Promise((resolve, reject) => {
    const request = https.request(
      {
        protocol: "https:",
        hostname: endpoint,
        path: `/?${query}`,
        method: "POST",
        headers,
        timeout: 8000,
      },
      (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          const body = Buffer.concat(chunks).toString("utf8");
          const parsed = safeJSONParse(body);
          if (!parsed) {
            reject(new SmsProviderError("ALIYUN_SMS_BAD_RESPONSE", "Aliyun SMS returned invalid JSON."));
            return;
          }
          resolve(parsed);
        });
      }
    );
    request.on("timeout", () => {
      request.destroy(new SmsProviderError("ALIYUN_SMS_TIMEOUT", "Aliyun SMS request timed out."));
    });
    request.on("error", reject);
    request.end();
  });
}

function percentEncode(value) {
  return encodeURIComponent(String(value))
    .replace(/\+/g, "%20")
    .replace(/\*/g, "%2A")
    .replace(/%7E/g, "~");
}

function sha256Hex(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function safeJSONParse(text) {
  try {
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
}
