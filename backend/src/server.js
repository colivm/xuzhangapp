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
  getSmsCode,
  initStore,
  setSessionByUserId,
  setSmsCode,
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
  const limit = checkSmsSendRateLimit(phone, clientIP(req));
  if (!limit.ok) {
    return res.status(429).json({ ok: false, error: limit.error, retryAfterSec: limit.retryAfterSec });
  }
  const code = config.devAllowSmsCode;
  await setSmsCode(phone, code, Date.now() + 5 * 60 * 1000);
  return res.json({ ok: true, cooldownSec: 60 });
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
    });

    const existing = await getIAPTransactionByOriginalId(verified.originalTransactionId);
    if (existing && existing.userId !== req.user.userId) {
      return res.status(409).json({ ok: false, error: "TRANSACTION_ALREADY_BOUND" });
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
  try {
    const response = await fetch(upstream, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(config.aiProxyToken ? { "x-proxy-token": config.aiProxyToken } : {}),
      },
      body: JSON.stringify(req.body || {}),
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

app.get("/v1/member/nudge/policy", requireAuth, (req, res) => {
  res.json({ ok: true, policy: getNudgePolicy(req.user.userId), state: getNudgeState(req.user.userId) });
});

app.post("/v1/member/nudge/policy", requireAuth, (req, res) => {
  const next = setNudgePolicy(req.user.userId, req.body || {});
  res.json({ ok: true, policy: next });
});

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
