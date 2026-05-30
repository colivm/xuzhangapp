import express from "express";
import cors from "cors";
import { config } from "./config.js";
import {
  deleteLedger,
  deleteSmsCode,
  getLedgersByUserId,
  getOrCreateUserByPhone,
  getSessionByUserId,
  getSmsCode,
  initStore,
  setSessionByUserId,
  setSmsCode,
  upsertLedger,
} from "./store.js";
import { requireAuth, signAccessToken } from "./auth.js";
import { trackEvent, listEvents, summarizeEvents } from "./analytics.js";
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

const app = express();
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
  const code = config.devAllowSmsCode;
  await setSmsCode(phone, code, Date.now() + 5 * 60 * 1000);
  return res.json({ ok: true, cooldownSec: 60 });
});

app.post("/v1/auth/sms/verify", async (req, res) => {
  const phone = String(req.body?.phone || "").trim();
  const code = String(req.body?.code || "").trim();
  const snapshot = await getSmsCode(phone);
  if (!snapshot || snapshot.expireAt < Date.now() || snapshot.code !== code) {
    return res.status(400).json({ ok: false, error: "INVALID_CODE" });
  }
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

app.get("/v1/ledger", requireAuth, async (req, res) => {
  const rows = await getLedgersByUserId(req.user.userId);
  res.json({ ok: true, items: rows });
});

app.post("/v1/ledger", requireAuth, async (req, res) => {
  const item = req.body || {};
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

app.post("/v1/iap/verify", requireAuth, (_req, res) => {
  // v0 stub: replace with App Store Server API verification.
  res.status(501).json({
    ok: false,
    error: "IAP_VERIFY_NOT_IMPLEMENTED",
    message: "请接入 App Store Server API 后启用真实验单。",
  });
});

app.post("/v1/ai/insight/daily", requireAuth, async (req, res) => {
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
