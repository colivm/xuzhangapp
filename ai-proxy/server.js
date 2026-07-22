const https = require("https");
const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
require("dotenv").config({ path: require("path").resolve(__dirname, ".env") });
const { redactForLog, validateAIOutputText, validateAIRequestBody } = require("./contentSafety");
const { normalizeInsightPayload } = require("./legacyInsightContract");
const { normalizedSupportedFeature } = require("./aiFeaturePolicy");
const { allowsDevelopmentRoutes, isProductionEnvironment } = require("./runtimeEnvironmentPolicy");
const {
  buildNarrativeRewriteMessages,
  normalizeNarrativeRewriteBatch,
  validateNarrativeFactPacks,
} = require("./narrativeRewriteContract");

const app = express();
app.use(cors());
app.use(express.json({ limit: "512kb" }));

const PORT = Number(process.env.PORT || 8787);
const AI_UPSTREAM_URL =
  process.env.AI_UPSTREAM_URL || process.env.ZHIPU_API_URL || "https://open.bigmodel.cn/api/paas/v4/chat/completions";
const AI_UPSTREAM_API_KEY = process.env.AI_UPSTREAM_API_KEY || process.env.ZHIPU_API_KEY || "";
const AI_UPSTREAM_MODEL = process.env.AI_UPSTREAM_MODEL || "";
const APP_PROXY_TOKEN = process.env.APP_PROXY_TOKEN || "";
const MONTHLY_REQUEST_LIMIT = Number(process.env.MONTHLY_REQUEST_LIMIT || 5000);
const JWT_SECRET = process.env.JWT_SECRET || "";
const REQUIRE_JWT = String(process.env.REQUIRE_JWT || "0") === "1";
const USER_RATE_LIMIT_PER_MINUTE = Number(process.env.USER_RATE_LIMIT_PER_MINUTE || 20);
const PREMIUM_RATE_LIMIT_PER_MINUTE = Number(process.env.PREMIUM_RATE_LIMIT_PER_MINUTE || 8);
const GLOBAL_WINDOW_SECONDS = Number(process.env.GLOBAL_WINDOW_SECONDS || 60);
const RISK_LOG_ENABLED = String(process.env.RISK_LOG_ENABLED || "1") === "1";
const AI_UPSTREAM_TIMEOUT_MS = Number(process.env.AI_UPSTREAM_TIMEOUT_MS || 30000);
const AI_UPSTREAM_TIMEOUT_MS_MONTHLY = Number(process.env.AI_UPSTREAM_TIMEOUT_MS_MONTHLY || 45000);
const PREMIUM_FEATURES = new Set(["quarterly", "yearly"]);
const IS_PRODUCTION = isProductionEnvironment(process.env.NODE_ENV);
const DEVELOPMENT_ROUTES_ENABLED = allowsDevelopmentRoutes(process.env.NODE_ENV);

validateProductionConfig();

const rateBuckets = new Map();
let usage = {
  monthKey: monthIdentifier(),
  count: 0,
};

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "ai-proxy",
    month: usage.monthKey,
    count: usage.count,
    limit: MONTHLY_REQUEST_LIMIT,
    jwtEnabled: Boolean(JWT_SECRET),
    requireJwt: REQUIRE_JWT,
  });
});

if (DEVELOPMENT_ROUTES_ENABLED) {
  app.post("/v1/auth/dev-token", (req, res) => {
    if (!JWT_SECRET) {
      return res.status(400).json({ code: "CONFIG_ERROR", message: "missing JWT_SECRET" });
    }
    if (APP_PROXY_TOKEN) {
      const incomingToken = (req.headers["x-proxy-token"] || "").toString();
      if (!incomingToken || incomingToken !== APP_PROXY_TOKEN) {
        return res.status(401).json({ code: "UNAUTHORIZED", message: "invalid proxy token" });
      }
    }
    const userId = String(req.body?.userId || "demo-user");
    const isMember = Boolean(req.body?.isMember);
    const expiresIn = String(req.body?.expiresIn || "12h");
    const token = jwt.sign({ sub: userId, userId, isMember, role: isMember ? "member" : "free" }, JWT_SECRET, {
      expiresIn,
    });
    return res.json({ token, userId, isMember, expiresIn });
  });
}

app.post("/v1/insight/daily", async (req, res) => {
  try {
    if (!AI_UPSTREAM_API_KEY) {
      return res.status(500).json({ code: "CONFIG_ERROR", message: "missing AI_UPSTREAM_API_KEY" });
    }
    if (APP_PROXY_TOKEN) {
      const incomingToken = (req.headers["x-proxy-token"] || "").toString();
      if (!incomingToken || incomingToken !== APP_PROXY_TOKEN) {
        return res.status(401).json({ code: "UNAUTHORIZED", message: "invalid proxy token" });
      }
    }

    const auth = authenticateRequest(req);
    if (!auth.ok) {
      return res.status(auth.status).json({ code: auth.code, message: auth.message });
    }
    const user = auth.user;
    const feature = normalizedSupportedFeature(req.body?.feature);
    if (!feature) {
      return res.status(400).json({
        code: "UNSUPPORTED_FEATURE",
        message: "unsupported AI feature",
      });
    }
    const safety = validateAIRequestBody(req.body || {});
    if (!safety.ok) {
      auditRisk("ai_input_rejected", req, user, {
        feature,
        reason: safety.reason,
        sample: redactForLog(JSON.stringify(req.body || {})),
      });
      return res.status(400).json({ code: safety.error, message: safety.message, reason: safety.reason });
    }
    if (feature === "narrative_rewrite_batch") {
      const contract = validateNarrativeFactPacks(req.body?.factPacks);
      if (!contract.ok) {
        auditRisk("narrative_contract_rejected", req, user, { feature, reason: contract.reason });
        return res.status(400).json({
          code: contract.error,
          message: "narrative fact pack contract rejected",
          reason: contract.reason,
        });
      }
    }

    if (PREMIUM_FEATURES.has(feature) && !user.isMember) {
      auditRisk("premium_bypass", req, user, { feature });
      return res.status(403).json({ code: "FORBIDDEN", message: "member feature required" });
    }
    if (isUserRateLimited(user, feature)) {
      auditRisk("rate_limited", req, user, { feature });
      return res.status(429).json({ code: "RATE_LIMIT", message: "too many requests, please retry later" });
    }

    resetMonthlyUsageIfNeeded();
    if (usage.count >= MONTHLY_REQUEST_LIMIT) {
      auditRisk("monthly_limit_reached", req, user, { feature });
      return res.status(429).json({ code: "RATE_LIMIT", message: "monthly proxy limit reached" });
    }

    const model = (AI_UPSTREAM_MODEL || "glm-4-flash").toString();
    const messages = feature === "narrative_rewrite_batch"
      ? buildNarrativeRewriteMessages(req.body?.factPacks, req.body?.tone)
      : req.body?.messages;
    const temperature = feature === "narrative_rewrite_batch"
      ? 0.25
      : Number(req.body?.temperature ?? 0.6);
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ code: "INVALID_ARGUMENT", message: "messages is required" });
    }

    const upstreamBody = JSON.stringify({ model, messages, temperature });
    const upstream = await postJSON(
      AI_UPSTREAM_URL,
      upstreamBody,
      {
        "Content-Type": "application/json",
        Authorization: `Bearer ${AI_UPSTREAM_API_KEY}`,
      },
      getUpstreamTimeoutMs(feature)
    );

    if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
      auditRisk("upstream_error", req, user, { feature, upstreamStatus: upstream.statusCode });
      return res.status(502).json({
        code: "UPSTREAM_ERROR",
        message: "upstream request failed",
        upstreamStatus: upstream.statusCode,
        upstreamBody: String(upstream.body || "").slice(0, 400),
      });
    }

    const parsed = safeJSONParse(upstream.body);
    const content = parsed?.choices?.[0]?.message?.content;
    const outputSafety = validateAIOutputText(content || upstream.body);
    if (!outputSafety.ok) {
      auditRisk("ai_output_rejected", req, user, {
        feature,
        reason: outputSafety.reason,
        sample: redactForLog(content || upstream.body),
      });
      return res.status(502).json({ code: outputSafety.error, message: "AI 输出未通过内容安全检查", reason: outputSafety.reason });
    }
    const payload = feature === "narrative_rewrite_batch"
      ? normalizeNarrativeRewriteBatch(content, req.body?.factPacks)
      : normalizeInsightPayload(content);
    if (!payload) {
      auditRisk("parse_error", req, user, { feature });
      return res.status(502).json({ code: "PARSE_ERROR", message: "invalid model output" });
    }

    usage.count += 1;
    return res.json(payload);
  } catch (error) {
    return res.status(500).json({
      code: "INTERNAL_ERROR",
      message: "proxy failed",
      detail: error instanceof Error ? error.message : "unknown",
    });
  }
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`ai-proxy running on http://localhost:${PORT}`);
  });
}

function authenticateRequest(req) {
  if (APP_PROXY_TOKEN) {
    const incomingToken = (req.headers["x-proxy-token"] || "").toString();
    if (incomingToken && incomingToken === APP_PROXY_TOKEN) {
      return { ok: true, user: { id: "proxy-token-client", isMember: true } };
    }
  }

  if (!JWT_SECRET) {
    if (REQUIRE_JWT) {
      return { ok: false, status: 401, code: "UNAUTHORIZED", message: "jwt disabled" };
    }
    return { ok: true, user: guestUser() };
  }
  const authHeader = String(req.headers.authorization || "");
  const matched = authHeader.match(/^Bearer\s+(.+)$/i);
  const token = matched?.[1];
  if (!token) {
    if (REQUIRE_JWT) {
      return { ok: false, status: 401, code: "UNAUTHORIZED", message: "missing bearer token" };
    }
    return { ok: true, user: guestUser() };
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const userId = String(payload?.sub || payload?.userId || "guest");
    const isMember = Boolean(payload?.isMember || payload?.member || payload?.role === "member");
    return { ok: true, user: { id: userId, isMember } };
  } catch (_error) {
    return { ok: false, status: 401, code: "UNAUTHORIZED", message: "invalid token" };
  }
}

function guestUser() {
  return { id: "guest", isMember: false };
}

function isUserRateLimited(user, feature) {
  const now = Date.now();
  const windowMs = GLOBAL_WINDOW_SECONDS * 1000;
  const limit = PREMIUM_FEATURES.has(feature) ? PREMIUM_RATE_LIMIT_PER_MINUTE : USER_RATE_LIMIT_PER_MINUTE;
  const key = `${user.id}:${feature}`;
  const bucket = rateBuckets.get(key);
  if (!bucket || now - bucket.windowStart > windowMs) {
    rateBuckets.set(key, { windowStart: now, count: 1 });
    return false;
  }
  bucket.count += 1;
  return bucket.count > limit;
}

function auditRisk(event, req, user, extra = {}) {
  if (!RISK_LOG_ENABLED) return;
  const payload = {
    event,
    userId: user?.id || "unknown",
    member: Boolean(user?.isMember),
    ip: req.headers["x-forwarded-for"] || req.socket.remoteAddress || "",
    ua: req.headers["user-agent"] || "",
    ts: new Date().toISOString(),
    ...extra,
  };
  console.warn("[risk]", JSON.stringify(payload));
}

function validateProductionConfig() {
  if (!IS_PRODUCTION) return;
  const issues = [];
  if (!AI_UPSTREAM_API_KEY) {
    issues.push("AI_UPSTREAM_API_KEY must be configured in production.");
  }
  if (!APP_PROXY_TOKEN || APP_PROXY_TOKEN.length < 16) {
    issues.push("APP_PROXY_TOKEN must be configured in production.");
  }
  if (!JWT_SECRET || JWT_SECRET.length < 32) {
    issues.push("JWT_SECRET must be set to a strong production value.");
  }
  if (!REQUIRE_JWT) {
    issues.push("REQUIRE_JWT must be 1 in production.");
  }
  if (issues.length) {
    throw new Error(`Unsafe production ai-proxy config:\n- ${issues.join("\n- ")}`);
  }
}

function postJSON(urlString, body, headers, timeoutMs = AI_UPSTREAM_TIMEOUT_MS) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlString);
    const request = https.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        path: url.pathname + url.search,
        method: "POST",
        headers: {
          ...headers,
          "Content-Length": Buffer.byteLength(body),
        },
        timeout: timeoutMs,
      },
      (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          resolve({
            statusCode: response.statusCode || 500,
            body: Buffer.concat(chunks).toString("utf8"),
          });
        });
      }
    );

    request.on("timeout", () => {
      request.destroy(new Error("request timeout"));
    });
    request.on("error", reject);
    request.write(body);
    request.end();
  });
}

function getUpstreamTimeoutMs(feature) {
  if (feature === "monthly") {
    return AI_UPSTREAM_TIMEOUT_MS_MONTHLY;
  }
  return AI_UPSTREAM_TIMEOUT_MS;
}

function safeJSONParse(text) {
  try {
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
}

function monthIdentifier() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

function resetMonthlyUsageIfNeeded() {
  const currentMonth = monthIdentifier();
  if (usage.monthKey !== currentMonth) {
    usage = { monthKey: currentMonth, count: 0 };
  }
}

module.exports = {
  app,
};
