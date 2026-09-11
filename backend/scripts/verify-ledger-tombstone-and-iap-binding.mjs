import assert from "node:assert/strict";

process.env.JWT_SECRET = "ledger-tombstone-test-secret-32-bytes-minimum";
// dotenv does not override variables that already exist, so pre-setting these to
// empty strings forces memory mode even when backend/.env points at Postgres/Redis.
process.env.DATABASE_URL = "";
process.env.REDIS_URL = "";

const store = await import("../src/store.js");
const { resolveIAPBindingDecision } = await import("../src/iapService.js");
const { sanitizeLedgerItem } = await import("../src/contentSafety.js");

await store.initStore();

// --- Ledger tombstones ------------------------------------------------------

const userA = "user-a";
const early = "2026-09-01T10:00:00Z";
const later = "2026-09-02T10:00:00Z";
const latest = "2026-09-03T10:00:00Z";

await store.upsertLedger(userA, { id: "item-1", title: "午餐", amount: 35, createdAt: early, updatedAt: early });
await store.upsertLedger(userA, { id: "item-2", title: "咖啡", amount: 18, createdAt: early, updatedAt: early });

await store.deleteLedger(userA, "item-1", later);
let items = await store.getLedgersByUserId(userA);
let tombstones = await store.getLedgerTombstonesByUserId(userA);
assert.deepEqual(items.map((x) => x.id), ["item-2"], "Deleted item must disappear from the item list.");
assert.deepEqual(tombstones.map((x) => x.id), ["item-1"], "Deleted item must be reported as a tombstone.");
assert.equal(tombstones[0].deletedAt, later);

// An older re-upload (offline device that never saw the delete) must NOT resurrect the record.
await store.upsertLedger(userA, { id: "item-1", title: "午餐", amount: 35, createdAt: early, updatedAt: early });
items = await store.getLedgersByUserId(userA);
assert.deepEqual(items.map((x) => x.id), ["item-2"], "A stale upload must not resurrect a tombstoned record.");

// A genuinely newer edit made after the delete does win (user re-created / edited it on another device).
await store.upsertLedger(userA, { id: "item-1", title: "午餐（改）", amount: 36, createdAt: early, updatedAt: latest });
items = await store.getLedgersByUserId(userA);
tombstones = await store.getLedgerTombstonesByUserId(userA);
assert.deepEqual(items.map((x) => x.id).sort(), ["item-1", "item-2"], "A newer edit after the delete must restore the record.");
assert.equal(tombstones.length, 0, "Restoring a record must clear its tombstone.");

// A delete stamped older than the current record must be ignored.
await store.deleteLedger(userA, "item-1", later);
items = await store.getLedgersByUserId(userA);
assert.deepEqual(items.map((x) => x.id).sort(), ["item-1", "item-2"], "An older delete must not remove a newer record.");

// Tombstones expire after the retention window.
await store.deleteLedger(userA, "item-2", "2020-01-01T00:00:00Z");
tombstones = await store.getLedgerTombstonesByUserId(userA, Date.parse("2026-09-11T00:00:00Z"));
assert.equal(tombstones.length, 0, "Tombstones older than the retention window are pruned.");

assert.match(store.ledgerTimestampNow(new Date("2026-09-11T01:02:03.456Z")), /^2026-09-11T01:02:03Z$/, "Server stamps use second precision so they compare correctly with client stamps.");

// --- Ledger sanitizer keeps scenePackId --------------------------------------

const sanitized = sanitizeLedgerItem({ id: "x", title: "晚饭", amount: 20, category: "dining", source: "manual", createdAt: early, updatedAt: early, scenePackId: "commute" });
assert.equal(sanitized.ok, true);
assert.equal(sanitized.item.scenePackId, "commute", "scenePackId must survive the server whitelist.");

// --- IAP binding decision --------------------------------------------------

const boundToB = { userId: "user-b", originalTransactionId: "orig-1" };

// Apple's appAccountToken says the transaction is ours: always bind, even over a stale server binding.
assert.deepEqual(
  resolveIAPBindingDecision({ existing: boundToB, currentUserId: "user-a", hasAppAccountToken: true }),
  { action: "bind", rebound: true }
);

// No token and bound to somebody else: always reject, including Sandbox.
const rejected = resolveIAPBindingDecision({ existing: boundToB, currentUserId: "user-a", hasAppAccountToken: false });
assert.equal(rejected.action, "reject");
assert.equal(rejected.status, 409);
assert.equal(rejected.error, "TRANSACTION_ALREADY_BOUND");

// No token and no prior binding: cannot prove ownership.
const missing = resolveIAPBindingDecision({ existing: null, currentUserId: "user-a", hasAppAccountToken: false });
assert.equal(missing.action, "reject");
assert.equal(missing.error, "APP_ACCOUNT_TOKEN_MISSING");

// No token but already bound to me: idempotent re-verify.
assert.deepEqual(
  resolveIAPBindingDecision({ existing: { userId: "user-a" }, currentUserId: "user-a", hasAppAccountToken: false }),
  { action: "bind", rebound: false }
);

const transaction = {
  originalTransactionId: "orig-rebind",
  userId: "user-a",
  transactionId: "txn-1",
  productId: "com.xuzhang.app.member.lifetime",
  memberTier: "lifetime",
  memberExpiresAt: null,
  environment: "Sandbox",
  verifiedAt: early,
};
await store.upsertIAPTransaction(transaction);
await store.upsertIAPTransaction({ ...transaction, userId: "user-b", verifiedAt: later });
const persistedRebind = await store.getIAPTransactionByOriginalId(transaction.originalTransactionId);
assert.equal(persistedRebind.userId, "user-b", "A legitimate appAccountToken rebind must persist the new owner.");

console.log("Ledger tombstone retention, scenePackId whitelist and strict IAP binding verified.");
