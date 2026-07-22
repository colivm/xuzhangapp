import assert from "node:assert/strict";
import {
  defaultPolicyForEnvironment,
  normalizePolicy,
} from "../src/nudgePolicy.js";

const local = defaultPolicyForEnvironment("development");
assert.equal(local.mode, "debug");
assert.equal(local.debugCooldownMs, 90 * 1000);

const staging = normalizePolicy({ mode: "debug", debugCooldownMs: 1_000 }, "staging");
assert.equal(staging.mode, "debug");
assert.equal(staging.debugCooldownMs, 1_000);

const production = defaultPolicyForEnvironment("production");
assert.equal(production.mode, "prod");
assert.equal(production.prodDailyLimit, 1);
assert.equal(production.prodSceneCooldownDays, 7);

const attemptedProductionBypass = normalizePolicy(
  { mode: "debug", debugCooldownMs: 1_000 },
  "production"
);
assert.equal(attemptedProductionBypass.mode, "prod");

console.log("Production nudge policy verified: prod mode, daily limit 1, scene cooldown 7 days.");
