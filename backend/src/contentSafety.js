const PRIVACY_PATTERNS = [
  { re: /https?:\/\/[^\s"'<>]+|www\.[^\s"'<>]+|[\w.-]+@[\w.-]+\.\w+/i, label: "LINK_OR_EMAIL" },
  { re: /(?<!\d)1[3-9]\d{9}(?!\d)/, label: "PHONE" },
  { re: /(?<!\d)\d{6}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[0-9Xx](?!\d)/, label: "ID_CARD" },
  { re: /(?<!\d)(?:\d[ -]?){12,19}(?!\d)/, label: "BANK_CARD" },
];

const SENSITIVE_WORDS = [
  "傻逼",
  "操你",
  "约炮",
  "裸聊",
  "色情",
  "赌博",
  "毒品",
  "自杀",
  "杀人",
  "恐怖袭击",
];

// Narrow public-safety guard. It is intentionally small to avoid blocking normal notes
// such as news, school courses, meetings, or personal life records.
const PUBLIC_SAFETY_PHRASES = [
  "推翻政府",
  "颠覆国家政权",
  "分裂国家",
  "煽动暴乱",
  "恐怖组织",
  "制作炸弹",
  "爆炸物教程",
];

export function normalizeUserText(value, maxLength = 64) {
  return String(value || "")
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

export function riskReasonForText(value, { includePublicSafety = false } = {}) {
  const text = String(value || "").trim();
  if (!text) return null;
  const privacyHit = PRIVACY_PATTERNS.find((item) => item.re.test(text));
  if (privacyHit) return { code: privacyHit.label, message: "包含手机号、证件号、卡号、链接或邮箱" };
  const compact = text.replace(/\s/g, "").toLowerCase();
  if (SENSITIVE_WORDS.some((word) => compact.includes(word.toLowerCase()))) {
    return { code: "UNSAFE_WORD", message: "包含不适合展示的词" };
  }
  if (includePublicSafety && PUBLIC_SAFETY_PHRASES.some((word) => compact.includes(word.toLowerCase()))) {
    return { code: "PUBLIC_SAFETY", message: "包含不适合公开展示或生成的内容" };
  }
  if (/\d/.test(text) && /(验证码|密码|口令|token|密钥|银行卡|身份证|手机号|api\s*key)/i.test(text)) {
    return { code: "SECRET_LIKE", message: "包含隐私或密钥信息" };
  }
  return null;
}

export function sanitizeLedgerItem(rawItem) {
  const raw = rawItem && typeof rawItem === "object" ? rawItem : {};
  const item = {
    id: normalizeUserText(raw.id, 80),
    title: normalizeUserText(raw.title, 32),
    amount: Number(raw.amount),
    category: normalizeUserText(raw.category, 24),
    source: normalizeUserText(raw.source, 16),
    createdAt: normalizeUserText(raw.createdAt, 40),
    updatedAt: normalizeUserText(raw.updatedAt, 40),
  };
  const emotionTag = normalizeUserText(raw.emotionTag, 32);
  const merchantBrandId = normalizeUserText(raw.merchantBrandId, 48);
  if (emotionTag) item.emotionTag = emotionTag;
  if (merchantBrandId) item.merchantBrandId = merchantBrandId;
  if (raw.userEditedTitle === true) item.userEditedTitle = true;
  const draftMeta = sanitizeDraftMeta(raw.draftMeta);
  if (draftMeta) item.draftMeta = draftMeta;

  if (!item.title) {
    return { ok: false, error: "INVALID_LEDGER_TITLE", message: "账单标题不能为空" };
  }
  const titleRisk = riskReasonForText(item.title, { includePublicSafety: true });
  if (titleRisk) {
    return { ok: false, error: "CONTENT_REJECTED", message: titleRisk.message, reason: titleRisk.code };
  }
  if (item.emotionTag) {
    const emotionRisk = riskReasonForText(item.emotionTag, { includePublicSafety: true });
    if (emotionRisk) {
      return { ok: false, error: "CONTENT_REJECTED", message: emotionRisk.message, reason: emotionRisk.code };
    }
  }
  if (!Number.isFinite(item.amount) || item.amount <= 0) {
    return { ok: false, error: "INVALID_LEDGER_AMOUNT", message: "金额无效" };
  }
  return { ok: true, item };
}

function sanitizeDraftMeta(rawDraftMeta) {
  if (!rawDraftMeta || typeof rawDraftMeta !== "object") return null;
  const batchId = normalizeUserText(rawDraftMeta.batchId, 80);
  const importedAt = normalizeUserText(rawDraftMeta.importedAt, 40);
  const status = normalizeUserText(rawDraftMeta.status, 16);
  if (!batchId || !importedAt) return null;
  if (!["pending", "resolved"].includes(status)) return null;
  return { batchId, importedAt, status };
}

export function validateAIRequestBody(body) {
  const text = collectText(body).slice(0, 8000);
  const risk = riskReasonForText(text, { includePublicSafety: true });
  if (risk) return { ok: false, error: "AI_INPUT_REJECTED", message: risk.message, reason: risk.code };
  return { ok: true };
}

export function validateAIOutputText(text) {
  const risk = riskReasonForText(String(text || "").slice(0, 4000), { includePublicSafety: true });
  if (risk) return { ok: false, error: "AI_OUTPUT_REJECTED", message: risk.message, reason: risk.code };
  return { ok: true };
}

export function redactForLog(value) {
  let text = String(value || "");
  for (const item of PRIVACY_PATTERNS) {
    text = text.replace(toGlobalRegExp(item.re), `[REDACTED_${item.label}]`);
  }
  return text.slice(0, 500);
}

function toGlobalRegExp(re) {
  return new RegExp(re.source, re.flags.includes("g") ? re.flags : `${re.flags}g`);
}

function collectText(value) {
  if (value == null) return "";
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  if (Array.isArray(value)) return value.map(collectText).join("\n");
  if (typeof value === "object") {
    return Object.entries(value)
      .filter(([key]) => !/token|key|authorization|signed|secret/i.test(key))
      .map(([, nested]) => collectText(nested))
      .join("\n");
  }
  return "";
}
