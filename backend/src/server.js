import express from "express";
import cors from "cors";
import { config } from "./config.js";
import {
  deleteAccountByUserId,
  deleteLedger,
  deleteLedgersByUserId,
  deleteSmsCode,
  getLedgersByUserId,
  getIAPTransactionByOriginalId,
  getOrCreateUserByPhone,
  getSessionByUserId,
  getUserById,
  getSmsCode,
  initStore,
  setSessionByUserId,
  setSmsCode,
  updateUserCloudSyncEnabled,
  updateUserDisplayName,
  upsertIAPTransaction,
  upsertLedger,
} from "./store.js";
import { requireAuth, signAccessToken } from "./auth.js";
import { deleteEventsByUserId, trackEvent, listEvents, summarizeEvents } from "./analytics.js";
import {
  checkSmsSendRateLimit,
  checkSmsVerifyRateLimit,
  clearSmsVerifyFailures,
  markSmsVerifyFailed,
} from "./rateLimit.js";
import { getSmsProviderMode, isSmsConfigured, sendLoginSmsCode, SmsProviderError } from "./smsService.js";
import {
  canShowNudge,
  getPolicy as getNudgePolicy,
  getState as getNudgeState,
  markNudgeDismissed,
  markNudgeShown,
  setPolicy as setNudgePolicy,
} from "./nudgePolicy.js";
import { getMemberCtaCopy } from "./memberFlow.js";
import { buildTodayPlayback } from "./playback.js";
import { IAPVerifyError, verifyAppStoreTransaction } from "./iapService.js";
import {
  redactForLog,
  sanitizeLedgerItem,
  validateAIOutputText,
  validateAIRequestBody,
} from "./contentSafety.js";

const app = express();
const isProduction = process.env.NODE_ENV === "production";
validateProductionConfig();
app.use(cors({ origin: config.allowOrigin === "*" ? true : config.allowOrigin }));
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "qingzhang-backend", now: new Date().toISOString() });
});

app.post("/v1/auth/sms/send", async (req, res) => {
  const phone = String(req.body?.phone || "").trim();
  if (!/^1\d{10}$/.test(phone)) {
    return res.status(400).json({ ok: false, error: "INVALID_PHONE" });
  }
  if (!isSmsConfigured()) {
    return res.status(503).json({ ok: false, error: "SMS_NOT_CONFIGURED" });
  }
  const limit = checkSmsSendRateLimit(phone, clientIP(req));
  if (!limit.ok) {
    return res.status(429).json({ ok: false, error: limit.error, retryAfterSec: limit.retryAfterSec });
  }
  try {
    const result = await sendLoginSmsCode(phone);
    await setSmsCode(phone, result.code, result.expireAt);
    return res.json({ ok: true, cooldownSec: 60 });
  } catch (error) {
    if (error instanceof SmsProviderError) {
      return res.status(502).json({ ok: false, error: error.code, message: "短信验证码发送失败，请稍后再试。" });
    }
    return res.status(502).json({ ok: false, error: "SMS_SEND_FAILED", message: "短信验证码发送失败，请稍后再试。" });
  }
});

app.post("/v1/auth/sms/verify", async (req, res) => {
  const phone = String(req.body?.phone || "").trim();
  const code = String(req.body?.code || "").trim();
  const limit = checkSmsVerifyRateLimit(phone, clientIP(req));
  if (!limit.ok) {
    return res.status(429).json({ ok: false, error: limit.error, retryAfterSec: limit.retryAfterSec });
  }
  const snapshot = await getSmsCode(phone);
  if (!snapshot || snapshot.expireAt < Date.now() || snapshot.code !== code) {
    markSmsVerifyFailed(phone, clientIP(req));
    return res.status(400).json({ ok: false, error: "INVALID_CODE" });
  }
  clearSmsVerifyFailures(phone, clientIP(req));
  await deleteSmsCode(phone);
  const user = await getOrCreateUserByPhone(phone);
  const accessToken = signAccessToken(user);
  const session = await getSessionByUserId(user.userId);
  return res.json({
    ok: true,
    user: {
      userId: user.userId,
      displayName: user.displayName,
      memberTier: session?.memberTier || "free",
      memberExpiresAt: session?.memberExpiresAt || null,
      cloudSyncEnabled: Boolean(user.cloudSyncEnabled),
    },
    accessToken,
  });
});

app.post("/v1/auth/wechat/login", (_req, res) => {
  return res.status(501).json({
    ok: false,
    error: "WECHAT_NOT_IMPLEMENTED",
    message: "请在接入微信开放平台参数后实现 code 换取登录态。",
  });
});

app.get("/v1/member/me", requireAuth, async (req, res) => {
  const session = await getSessionByUserId(req.user.userId);
  res.json({ ok: true, ...session });
});

app.get("/v1/account/me", requireAuth, async (req, res) => {
  const user = await getUserById(req.user.userId);
  if (!user) return res.status(404).json({ ok: false, error: "USER_NOT_FOUND" });
  const session = await getSessionByUserId(req.user.userId);
  res.json({
    ok: true,
    user: {
      userId: user.userId,
      displayName: user.displayName,
      memberTier: session?.memberTier || "free",
      memberExpiresAt: session?.memberExpiresAt || null,
      cloudSyncEnabled: Boolean(user.cloudSyncEnabled),
    },
  });
});

app.patch("/v1/account/me", requireAuth, async (req, res) => {
  const hasDisplayName = Object.prototype.hasOwnProperty.call(req.body || {}, "displayName");
  const hasCloudSyncEnabled = Object.prototype.hasOwnProperty.call(req.body || {}, "cloudSyncEnabled");
  let user = await getUserById(req.user.userId);
  if (!user) return res.status(404).json({ ok: false, error: "USER_NOT_FOUND" });
  if (hasDisplayName) {
    const displayName = String(req.body?.displayName || "").trim();
    if (displayName.length < 1 || displayName.length > 12) {
      return res.status(400).json({ ok: false, error: "INVALID_DISPLAY_NAME" });
    }
    user = await updateUserDisplayName(req.user.userId, displayName);
    if (!user) return res.status(404).json({ ok: false, error: "USER_NOT_FOUND" });
  }
  if (hasCloudSyncEnabled) {
    if (typeof req.body.cloudSyncEnabled !== "boolean") {
      return res.status(400).json({ ok: false, error: "INVALID_CLOUD_SYNC_ENABLED" });
    }
    user = await updateUserCloudSyncEnabled(req.user.userId, req.body.cloudSyncEnabled);
    if (!user) return res.status(404).json({ ok: false, error: "USER_NOT_FOUND" });
  }
  const session = await getSessionByUserId(req.user.userId);
  res.json({
    ok: true,
    user: {
      userId: user.userId,
      displayName: user.displayName,
      memberTier: session?.memberTier || "free",
      memberExpiresAt: session?.memberExpiresAt || null,
      cloudSyncEnabled: Boolean(user.cloudSyncEnabled),
    },
  });
});

if (!isProduction) {
  app.post("/v1/member/dev/set-tier", requireAuth, async (req, res) => {
    const tier = String(req.body?.tier || "free");
    const allow = new Set(["free", "monthly", "yearly", "lifetime"]);
    if (!allow.has(tier)) return res.status(400).json({ ok: false, error: "INVALID_TIER" });
    const next = {
      memberTier: tier,
      memberExpiresAt: tier === "lifetime" || tier === "free" ? null : new Date(Date.now() + 30 * 86400000).toISOString(),
    };
    await setSessionByUserId(req.user.userId, next);
    res.json({ ok: true, ...next });
  });
}

app.get("/v1/ledger", requireAuth, async (req, res) => {
  const rows = await getLedgersByUserId(req.user.userId);
  res.json({ ok: true, items: rows });
});

app.post("/v1/ledger", requireAuth, async (req, res) => {
  const validated = sanitizeLedgerItem(req.body || {});
  if (!validated.ok) {
    return res.status(400).json({
      ok: false,
      error: validated.error,
      message: validated.message,
      reason: validated.reason,
    });
  }
  const item = validated.item;
  if (!item.id || !item.createdAt) {
    return res.status(400).json({ ok: false, error: "INVALID_LEDGER_ITEM" });
  }
  await upsertLedger(req.user.userId, item);
  res.json({ ok: true });
});

app.delete("/v1/ledger/:id", requireAuth, async (req, res) => {
  await deleteLedger(req.user.userId, req.params.id);
  res.json({ ok: true });
});

app.delete("/v1/ledger", requireAuth, async (req, res) => {
  await deleteLedgersByUserId(req.user.userId);
  res.json({ ok: true });
});

app.delete("/v1/account", requireAuth, async (req, res) => {
  await deleteAccountByUserId(req.user.userId);
  deleteEventsByUserId(req.user.userId);
  res.json({ ok: true });
});

app.post("/v1/iap/verify", requireAuth, async (req, res) => {
  const productId = String(req.body?.productId || "").trim();
  const transactionId = String(req.body?.transactionId || "").trim();
  if (!productId || !transactionId) {
    return res.status(400).json({ ok: false, error: "INVALID_IAP_REQUEST" });
  }

  try {
    const verified = await verifyAppStoreTransaction({
      productId,
      transactionId,
      signedTransactionInfo: req.body?.signedTransactionInfo,
      expectedAppAccountToken: req.user.userId,
    });

    const existing = await getIAPTransactionByOriginalId(verified.originalTransactionId);
    if (existing && existing.userId !== req.user.userId) {
      return res.status(409).json({ ok: false, error: "TRANSACTION_ALREADY_BOUND" });
    }
    if (!verified.hasAppAccountToken && !existing) {
      return res.status(409).json({
        ok: false,
        error: "APP_ACCOUNT_TOKEN_MISSING",
        message: "Transaction is not bound to the current xLife account.",
      });
    }

    await upsertIAPTransaction({
      originalTransactionId: verified.originalTransactionId,
      userId: req.user.userId,
      transactionId: verified.transactionId,
      productId: verified.productId,
      memberTier: verified.memberTier,
      memberExpiresAt: verified.memberExpiresAt,
      environment: verified.environment,
      verifiedAt: new Date().toISOString(),
    });

    const current = await getSessionByUserId(req.user.userId);
    const next = mergeMemberSession(current, {
      memberTier: verified.memberTier,
      memberExpiresAt: verified.memberExpiresAt,
    });
    await setSessionByUserId(req.user.userId, next);
    res.json({
      ok: true,
      productId: verified.productId,
      transactionId: verified.transactionId,
      originalTransactionId: verified.originalTransactionId,
      environment: verified.environment,
      ...next,
    });
  } catch (error) {
    if (error instanceof IAPVerifyError) {
      return res.status(error.status).json({ ok: false, error: error.code, message: error.message });
    }
    res.status(500).json({ ok: false, error: "IAP_VERIFY_FAILED", message: String(error?.message || error) });
  }
});

app.post("/v1/ai/insight/daily", requireAuth, async (req, res) => {
  const safety = validateAIRequestBody(req.body || {});
  if (!safety.ok) {
    console.warn("[content-safety]", JSON.stringify({
      event: "ai_input_rejected",
      userId: req.user.userId,
      reason: safety.reason,
      sample: redactForLog(JSON.stringify(req.body || {})),
      ts: new Date().toISOString(),
    }));
    return res.status(400).json({ ok: false, error: safety.error, message: safety.message, reason: safety.reason });
  }
  const upstream = `${config.aiProxyBaseUrl}/v1/insight/daily`;
  const isCoverDirectorRequest = req.body?.feature === "cover_director";
  const abortController = isCoverDirectorRequest ? new AbortController() : null;
  const coverDirectorTimeout = abortController
    ? setTimeout(() => abortController.abort(), 9_000)
    : null;
  try {
    const response = await fetch(upstream, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(config.aiProxyToken ? { "x-proxy-token": config.aiProxyToken } : {}),
      },
      body: JSON.stringify(req.body || {}),
      ...(abortController ? { signal: abortController.signal } : {}),
    });
    const text = await response.text();
    const outputSafety = validateAIOutputText(text);
    if (!outputSafety.ok) {
      console.warn("[content-safety]", JSON.stringify({
        event: "ai_output_rejected",
        userId: req.user.userId,
        reason: outputSafety.reason,
        sample: redactForLog(text),
        ts: new Date().toISOString(),
      }));
      return res.status(502).json({
        ok: false,
        error: outputSafety.error,
        message: "AI 输出未通过内容安全检查",
        reason: outputSafety.reason,
      });
    }
    res.status(response.status).type("application/json").send(text);
  } catch (error) {
    res.status(502).json({ ok: false, error: "UPSTREAM_ERROR", message: String(error?.message || error) });
  } finally {
    if (coverDirectorTimeout) clearTimeout(coverDirectorTimeout);
  }
});

app.post("/v1/analytics/events", requireAuth, (req, res) => {
  const event = String(req.body?.event || "").trim();
  if (!event) return res.status(400).json({ ok: false, error: "INVALID_EVENT" });
  const payload = trackEvent(req.user.userId, event, req.body?.props || {});
  res.json({ ok: true, item: payload });
});

app.get("/v1/analytics/events", requireAuth, (req, res) => {
  const limit = Number(req.query?.limit || 200);
  res.json({ ok: true, items: listEvents(req.user.userId, { limit }) });
});

app.get("/v1/analytics/summary", requireAuth, (req, res) => {
  const days = Number(req.query?.days || 7);
  res.json({ ok: true, ...summarizeEvents(req.user.userId, { days }) });
});

app.get("/v1/member/cta-copy", requireAuth, (req, res) => {
  const scene = String(req.query?.scene || "default");
  res.json({ ok: true, scene, ...getMemberCtaCopy(scene) });
});

if (!isProduction) {
  app.get("/v1/member/nudge/policy", requireAuth, (req, res) => {
    res.json({ ok: true, policy: getNudgePolicy(req.user.userId), state: getNudgeState(req.user.userId) });
  });

  app.post("/v1/member/nudge/policy", requireAuth, (req, res) => {
    const next = setNudgePolicy(req.user.userId, req.body || {});
    res.json({ ok: true, policy: next });
  });
}

app.post("/v1/member/nudge/evaluate", requireAuth, (req, res) => {
  const scene = String(req.body?.scene || "default");
  const shouldShow = canShowNudge(req.user.userId, scene);
  if (shouldShow) markNudgeShown(req.user.userId, scene);
  const copy = getMemberCtaCopy(scene);
  res.json({
    ok: true,
    scene,
    shouldShow,
    copy,
    policy: getNudgePolicy(req.user.userId),
    state: getNudgeState(req.user.userId),
  });
});

app.post("/v1/member/nudge/dismiss", requireAuth, (req, res) => {
  const scene = String(req.body?.scene || "default");
  const nextState = markNudgeDismissed(req.user.userId, scene);
  res.json({ ok: true, scene, state: nextState });
});

app.get("/v1/playback/today", requireAuth, async (req, res) => {
  const rows = await getLedgersByUserId(req.user.userId);
  const playback = buildTodayPlayback(rows);
  res.json({ ok: true, ...playback });
});

function mergeMemberSession(current, incoming) {
  const currentTier = current?.memberTier || "free";
  const incomingTier = incoming?.memberTier || "free";
  if (currentTier === "lifetime" || incomingTier === "free") {
    return current || { memberTier: "free", memberExpiresAt: null };
  }
  if (incomingTier === "lifetime") {
    return { memberTier: "lifetime", memberExpiresAt: null };
  }

  const currentExpiry = Date.parse(current?.memberExpiresAt || "");
  const incomingExpiry = Date.parse(incoming?.memberExpiresAt || "");
  const currentActive = Number.isFinite(currentExpiry) && currentExpiry > Date.now();
  const incomingActive = Number.isFinite(incomingExpiry) && incomingExpiry > Date.now();
  if (currentActive && (!incomingActive || currentExpiry >= incomingExpiry)) {
    return current;
  }
  return incoming;
}

function clientIP(req) {
  return String(req.headers["x-forwarded-for"] || req.socket.remoteAddress || "").split(",")[0].trim();
}

function validateProductionConfig() {
  if (!isProduction) return;
  const issues = [];
  if (!config.jwtSecret || config.jwtSecret === "dev-secret-change-me" || config.jwtSecret.length < 32) {
    issues.push("JWT_SECRET must be set to a strong production value.");
  }
  if (!config.databaseUrl) {
    issues.push("DATABASE_URL is required in production; memory store must not be used.");
  }
  if (!config.redisUrl) {
    issues.push("REDIS_URL is required in production; SMS codes must not use memory storage.");
  }
  if (config.allowOrigin === "*") {
    issues.push("ALLOW_ORIGIN must not be '*' in production.");
  }
  if (!config.aiProxyToken || config.aiProxyToken.length < 16) {
    issues.push("AI_PROXY_TOKEN must be configured in production.");
  }
  if (config.devAllowSmsCode) {
    issues.push("DEV_ALLOW_SMS_CODE must be disabled before production.");
  }
  if (getSmsProviderMode() !== "aliyun" || !isSmsConfigured()) {
    issues.push("SMS_PROVIDER=aliyun and Aliyun SMS credentials are required in production.");
  }
  if (issues.length) {
    throw new Error(`Unsafe production backend config:\n- ${issues.join("\n- ")}`);
  }
}

initStore()
  .then(({ mode }) => {
    app.listen(config.port, () => {
      console.log(`[backend] listening on http://localhost:${config.port} (store=${mode})`);
    });
  })
  .catch((error) => {
    console.error("[backend] failed to initialize store", error);
    process.exit(1);
  });
