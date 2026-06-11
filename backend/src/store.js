import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { config } from "./config.js";

const memory = {
  usersByPhone: new Map(),
  sessionsByUserId: new Map(),
  ledgersByUserId: new Map(),
  smsCodeByPhone: new Map(),
  iapTransactionsByOriginalId: new Map(),
};

let pool = null;
let usePostgres = false;

export async function initStore() {
  if (!config.databaseUrl) return { mode: "memory" };
  pool = new Pool({ connectionString: config.databaseUrl });
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      user_id TEXT PRIMARY KEY,
      phone TEXT UNIQUE NOT NULL,
      display_name TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sessions (
      user_id TEXT PRIMARY KEY,
      member_tier TEXT NOT NULL DEFAULT 'free',
      member_expires_at TEXT NULL
    );
    CREATE TABLE IF NOT EXISTS ledgers (
      user_id TEXT NOT NULL,
      item_id TEXT NOT NULL,
      payload JSONB NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (user_id, item_id)
    );
    CREATE TABLE IF NOT EXISTS sms_codes (
      phone TEXT PRIMARY KEY,
      code TEXT NOT NULL,
      expire_at BIGINT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS iap_transactions (
      original_transaction_id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      transaction_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      member_tier TEXT NOT NULL,
      member_expires_at TEXT NULL,
      environment TEXT NULL,
      verified_at TEXT NOT NULL
    );
  `);
  usePostgres = true;
  return { mode: "postgres" };
}

export async function setSmsCode(phone, code, expireAt) {
  if (!usePostgres) {
    memory.smsCodeByPhone.set(phone, { code, expireAt });
    return;
  }
  await pool.query(
    `INSERT INTO sms_codes(phone, code, expire_at)
     VALUES ($1, $2, $3)
     ON CONFLICT (phone) DO UPDATE SET code = EXCLUDED.code, expire_at = EXCLUDED.expire_at`,
    [phone, code, expireAt]
  );
}

export async function getSmsCode(phone) {
  if (!usePostgres) return memory.smsCodeByPhone.get(phone) || null;
  const result = await pool.query(`SELECT code, expire_at FROM sms_codes WHERE phone = $1`, [phone]);
  if (!result.rowCount) return null;
  return {
    code: result.rows[0].code,
    expireAt: Number(result.rows[0].expire_at),
  };
}

export async function deleteSmsCode(phone) {
  if (!usePostgres) {
    memory.smsCodeByPhone.delete(phone);
    return;
  }
  await pool.query(`DELETE FROM sms_codes WHERE phone = $1`, [phone]);
}

export async function getOrCreateUserByPhone(phone) {
  if (!usePostgres) {
    const existing = memory.usersByPhone.get(phone);
    if (existing) return existing;
    const user = { userId: randomUUID(), displayName: `用户${phone.slice(-4)}`, phone };
    memory.usersByPhone.set(phone, user);
    memory.sessionsByUserId.set(user.userId, { memberTier: "free", memberExpiresAt: null });
    memory.ledgersByUserId.set(user.userId, []);
    return user;
  }

  const existing = await pool.query(`SELECT user_id, display_name, phone FROM users WHERE phone = $1`, [phone]);
  if (existing.rowCount) {
    return {
      userId: existing.rows[0].user_id,
      displayName: existing.rows[0].display_name,
      phone: existing.rows[0].phone,
    };
  }
  const userId = randomUUID();
  const displayName = `用户${phone.slice(-4)}`;
  await pool.query(`INSERT INTO users(user_id, phone, display_name) VALUES ($1, $2, $3)`, [userId, phone, displayName]);
  await pool.query(
    `INSERT INTO sessions(user_id, member_tier, member_expires_at) VALUES ($1, 'free', NULL)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  );
  return { userId, displayName, phone };
}

export async function getSessionByUserId(userId) {
  if (!usePostgres) return memory.sessionsByUserId.get(userId) || { memberTier: "free", memberExpiresAt: null };
  const result = await pool.query(`SELECT member_tier, member_expires_at FROM sessions WHERE user_id = $1`, [userId]);
  if (!result.rowCount) return { memberTier: "free", memberExpiresAt: null };
  return {
    memberTier: result.rows[0].member_tier || "free",
    memberExpiresAt: result.rows[0].member_expires_at || null,
  };
}

export async function setSessionByUserId(userId, nextSession) {
  if (!usePostgres) {
    memory.sessionsByUserId.set(userId, nextSession);
    return;
  }
  await pool.query(
    `INSERT INTO sessions(user_id, member_tier, member_expires_at)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id) DO UPDATE SET member_tier = EXCLUDED.member_tier, member_expires_at = EXCLUDED.member_expires_at`,
    [userId, nextSession.memberTier, nextSession.memberExpiresAt]
  );
}

export async function getIAPTransactionByOriginalId(originalTransactionId) {
  if (!usePostgres) {
    return memory.iapTransactionsByOriginalId.get(originalTransactionId) || null;
  }
  const result = await pool.query(
    `SELECT original_transaction_id, user_id, transaction_id, product_id, member_tier, member_expires_at, environment, verified_at
     FROM iap_transactions WHERE original_transaction_id = $1`,
    [originalTransactionId]
  );
  if (!result.rowCount) return null;
  const row = result.rows[0];
  return {
    originalTransactionId: row.original_transaction_id,
    userId: row.user_id,
    transactionId: row.transaction_id,
    productId: row.product_id,
    memberTier: row.member_tier,
    memberExpiresAt: row.member_expires_at,
    environment: row.environment,
    verifiedAt: row.verified_at,
  };
}

export async function upsertIAPTransaction(record) {
  if (!usePostgres) {
    memory.iapTransactionsByOriginalId.set(record.originalTransactionId, record);
    return;
  }
  await pool.query(
    `INSERT INTO iap_transactions(original_transaction_id, user_id, transaction_id, product_id, member_tier, member_expires_at, environment, verified_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (original_transaction_id) DO UPDATE
     SET transaction_id = EXCLUDED.transaction_id,
         product_id = EXCLUDED.product_id,
         member_tier = EXCLUDED.member_tier,
         member_expires_at = EXCLUDED.member_expires_at,
         environment = EXCLUDED.environment,
         verified_at = EXCLUDED.verified_at`,
    [
      record.originalTransactionId,
      record.userId,
      record.transactionId,
      record.productId,
      record.memberTier,
      record.memberExpiresAt,
      record.environment || null,
      record.verifiedAt,
    ]
  );
}

export async function getLedgersByUserId(userId) {
  if (!usePostgres) return memory.ledgersByUserId.get(userId) || [];
  const result = await pool.query(`SELECT payload FROM ledgers WHERE user_id = $1 ORDER BY updated_at DESC`, [userId]);
  return result.rows.map((row) => row.payload);
}

export async function upsertLedger(userId, item) {
  const incomingUpdatedAt = String(item.updatedAt || item.createdAt || new Date().toISOString());
  if (!usePostgres) {
    const rows = memory.ledgersByUserId.get(userId) || [];
    const existing = rows.find((x) => x.id === item.id);
    if (existing) {
      const existingUpdatedAt = String(existing.updatedAt || existing.createdAt || "");
      if (existingUpdatedAt > incomingUpdatedAt) return;
    }
    const next = [{ ...item, updatedAt: incomingUpdatedAt }, ...rows.filter((x) => x.id !== item.id)];
    memory.ledgersByUserId.set(userId, next);
    return;
  }
  await pool.query(
    `INSERT INTO ledgers(user_id, item_id, payload, updated_at)
     VALUES ($1, $2, $3::jsonb, $4)
     ON CONFLICT (user_id, item_id)
     DO UPDATE SET payload = EXCLUDED.payload, updated_at = EXCLUDED.updated_at
     WHERE ledgers.updated_at <= EXCLUDED.updated_at`,
    [userId, item.id, JSON.stringify({ ...item, updatedAt: incomingUpdatedAt }), incomingUpdatedAt]
  );
}

export async function deleteLedger(userId, itemId) {
  if (!usePostgres) {
    const rows = memory.ledgersByUserId.get(userId) || [];
    memory.ledgersByUserId.set(
      userId,
      rows.filter((x) => x.id !== itemId)
    );
    return;
  }
  await pool.query(`DELETE FROM ledgers WHERE user_id = $1 AND item_id = $2`, [userId, itemId]);
}

export async function deleteLedgersByUserId(userId) {
  if (!usePostgres) {
    memory.ledgersByUserId.set(userId, []);
    return;
  }
  await pool.query(`DELETE FROM ledgers WHERE user_id = $1`, [userId]);
}

export async function deleteAccountByUserId(userId) {
  if (!usePostgres) {
    let phoneToDelete = "";
    for (const [phone, user] of memory.usersByPhone.entries()) {
      if (user.userId === userId) {
        phoneToDelete = phone;
        break;
      }
    }
    if (phoneToDelete) {
      memory.usersByPhone.delete(phoneToDelete);
      memory.smsCodeByPhone.delete(phoneToDelete);
    }
    memory.sessionsByUserId.delete(userId);
    memory.ledgersByUserId.delete(userId);
    for (const [key, tx] of memory.iapTransactionsByOriginalId.entries()) {
      if (tx.userId === userId) memory.iapTransactionsByOriginalId.delete(key);
    }
    return;
  }

  await pool.query("BEGIN");
  try {
    const userResult = await pool.query(`SELECT phone FROM users WHERE user_id = $1`, [userId]);
    const phone = userResult.rows[0]?.phone || "";
    await pool.query(`DELETE FROM ledgers WHERE user_id = $1`, [userId]);
    await pool.query(`DELETE FROM sessions WHERE user_id = $1`, [userId]);
    await pool.query(`DELETE FROM iap_transactions WHERE user_id = $1`, [userId]);
    if (phone) {
      await pool.query(`DELETE FROM sms_codes WHERE phone = $1`, [phone]);
    }
    await pool.query(`DELETE FROM users WHERE user_id = $1`, [userId]);
    await pool.query("COMMIT");
  } catch (error) {
    await pool.query("ROLLBACK");
    throw error;
  }
}
