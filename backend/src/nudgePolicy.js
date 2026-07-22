const POLICY_LIMITS = Object.freeze({
  debugCooldownMs: 90 * 1000,
  prodDailyLimit: 1,
  prodSceneCooldownDays: 7,
});

const policyByUser = new Map();
const stateByUser = new Map();

export function defaultPolicyForEnvironment(nodeEnv = process.env.NODE_ENV) {
  const mode = String(nodeEnv || "").trim().toLowerCase() === "production" ? "prod" : "debug";
  return {
    mode,
    ...POLICY_LIMITS,
  };
}

export function normalizePolicy(input = {}, nodeEnv = process.env.NODE_ENV) {
  const defaults = defaultPolicyForEnvironment(nodeEnv);
  const mode = defaults.mode === "prod" || input.mode === "prod" ? "prod" : "debug";
  return {
    mode,
    debugCooldownMs: Math.max(1000, Number(input.debugCooldownMs || defaults.debugCooldownMs)),
    prodDailyLimit: Math.max(1, Number(input.prodDailyLimit || defaults.prodDailyLimit)),
    prodSceneCooldownDays: Math.max(1, Number(input.prodSceneCooldownDays || defaults.prodSceneCooldownDays)),
  };
}

function ensureState(userId) {
  const current = stateByUser.get(userId) || {
    lastShownAt: 0,
    dailyDayKey: "",
    dailyCount: 0,
    sceneCooldownUntil: {},
  };
  stateByUser.set(userId, current);
  return current;
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

export function getPolicy(userId) {
  const stored = policyByUser.get(userId);
  return stored ? normalizePolicy(stored) : defaultPolicyForEnvironment();
}

export function setPolicy(userId, input = {}) {
  const next = normalizePolicy({ ...getPolicy(userId), ...input });
  policyByUser.set(userId, next);
  return next;
}

export function getState(userId) {
  return ensureState(userId);
}

export function canShowNudge(userId, scene = "default") {
  const policy = getPolicy(userId);
  const state = ensureState(userId);
  const now = Date.now();
  if (policy.mode === "debug") {
    return now - Number(state.lastShownAt || 0) >= Number(policy.debugCooldownMs || POLICY_LIMITS.debugCooldownMs);
  }
  if (state.dailyDayKey === todayKey() && state.dailyCount >= policy.prodDailyLimit) return false;
  const until = Number(state.sceneCooldownUntil?.[scene] || 0);
  if (until > now) return false;
  return true;
}

export function markNudgeShown(userId, scene = "default") {
  const policy = getPolicy(userId);
  const state = ensureState(userId);
  state.lastShownAt = Date.now();
  if (policy.mode === "prod") {
    const key = todayKey();
    if (state.dailyDayKey !== key) {
      state.dailyDayKey = key;
      state.dailyCount = 1;
    } else {
      state.dailyCount += 1;
    }
  }
  stateByUser.set(userId, state);
  return state;
}

export function markNudgeDismissed(userId, scene = "default") {
  const policy = getPolicy(userId);
  if (policy.mode !== "prod") return ensureState(userId);
  const state = ensureState(userId);
  const cooldownMs = policy.prodSceneCooldownDays * 24 * 60 * 60 * 1000;
  state.sceneCooldownUntil = {
    ...state.sceneCooldownUntil,
    [scene]: Date.now() + cooldownMs,
  };
  stateByUser.set(userId, state);
  return state;
}

