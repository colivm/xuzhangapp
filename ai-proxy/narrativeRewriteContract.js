const ALLOWED_SCOPES = new Set(["day", "week", "month"]);
const ALLOWED_ROLES = new Set(["lead", "support", "mark", "evidence", "echo"]);
const ALLOWED_KINDS = new Set([
  "userText",
  "photo",
  "change",
  "structuredScene",
  "rhythm",
  "stableMark",
  "repeatRhythm",
  "returnAfterGap",
  "comparableChange",
]);
const FORBIDDEN_REWRITE_TERMS = [
  "治愈",
  "焦虑",
  "压力",
  "辛苦",
  "努力",
  "终于",
  "一定",
  "因为",
  "说明你",
  "建议",
  "应该",
  "需要减少",
  "预算",
  "省钱",
  "控制消费",
  "健康诊断",
  "财务风险",
  "投资",
  "收益",
  "联系方式",
  "手机号",
  "身份证",
  "银行卡",
  "密码",
  "验证码",
];
const UUID_PATTERN = /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i;

function validateNarrativeFactPacks(rawPacks) {
  if (!Array.isArray(rawPacks) || rawPacks.length < 1 || rawPacks.length > 3) {
    return invalid("factPacks must contain 1 to 3 scopes");
  }

  const seenScopes = new Set();
  for (const pack of rawPacks) {
    if (!isPlainObject(pack) || !hasOnlyKeys(pack, ["scope", "periodKey", "facts"])) {
      return invalid("fact pack has unsupported fields");
    }
    const scope = cleanText(pack.scope);
    const periodKey = cleanText(pack.periodKey);
    if (!ALLOWED_SCOPES.has(scope) || seenScopes.has(scope)) {
      return invalid("fact pack scope is invalid or duplicated");
    }
    if (!/^[0-9A-Za-z._:-]{1,40}$/.test(periodKey)) {
      return invalid("fact pack periodKey is invalid");
    }
    if (!Array.isArray(pack.facts) || pack.facts.length < 1 || pack.facts.length > 6) {
      return invalid("fact pack must contain 1 to 6 facts");
    }

    const seenFactIDs = new Set();
    let leadFactCount = 0;
    for (const fact of pack.facts) {
      if (
        !isPlainObject(fact) ||
        !hasOnlyKeys(fact, ["id", "role", "kind", "label", "statement", "evidenceCount"])
      ) {
        return invalid("fact has unsupported fields");
      }
      const id = cleanText(fact.id);
      const role = cleanText(fact.role);
      const kind = cleanText(fact.kind);
      const label = cleanText(fact.label);
      const statement = cleanText(fact.statement);
      if (!/^F[1-6]$/.test(id) || seenFactIDs.has(id)) {
        return invalid("fact id is invalid or duplicated");
      }
      if (!ALLOWED_ROLES.has(role) || !ALLOWED_KINDS.has(kind)) {
        return invalid("fact role or kind is unsupported");
      }
      if (!withinLength(label, 1, 32) || !withinLength(statement, 1, 120)) {
        return invalid("fact label or statement length is invalid");
      }
      if (!Number.isInteger(fact.evidenceCount) || fact.evidenceCount < 1 || fact.evidenceCount > 10000) {
        return invalid("fact evidenceCount is invalid");
      }
      if (UUID_PATTERN.test(`${label} ${statement}`) || /https?:\/\/|www\.|@/i.test(`${label} ${statement}`)) {
        return invalid("fact pack contains a forbidden identifier");
      }
      if (kind === "userText" && label !== "用户自写记录") {
        return invalid("user text must remain redacted");
      }
      if (kind === "photo" && label !== "有真实照片的记录") {
        return invalid("photo fact must remain redacted");
      }
      if (role === "lead") leadFactCount += 1;
      seenFactIDs.add(id);
    }
    if (leadFactCount !== 1) {
      return invalid("fact pack must contain exactly one lead fact");
    }
    seenScopes.add(scope);
  }

  return { ok: true };
}

function normalizeNarrativeRewriteBatch(content, rawPacks) {
  const packValidation = validateNarrativeFactPacks(rawPacks);
  if (!packValidation.ok || typeof content !== "string") return null;

  const object = parseJSONObject(content);
  if (!isPlainObject(object) || !hasOnlyKeys(object, ["rewrites"])) return null;
  if (!Array.isArray(object.rewrites) || object.rewrites.length < 1 || object.rewrites.length > rawPacks.length) {
    return null;
  }

  const packsByScope = new Map(rawPacks.map((pack) => [pack.scope, pack]));
  const seenScopes = new Set();
  const rewrites = [];

  for (const candidate of object.rewrites) {
    if (
      !isPlainObject(candidate) ||
      !hasOnlyKeys(candidate, ["scope", "periodKey", "headline", "summary", "supportingLine", "evidenceIDs"])
    ) {
      return null;
    }
    const scope = cleanText(candidate.scope);
    const periodKey = cleanText(candidate.periodKey);
    const headline = cleanText(candidate.headline);
    const summary = cleanText(candidate.summary);
    const supportingLine = candidate.supportingLine == null ? null : cleanText(candidate.supportingLine);
    const pack = packsByScope.get(scope);
    if (!pack || seenScopes.has(scope) || periodKey !== pack.periodKey) return null;
    if (!withinLength(headline, 4, 32) || !withinLength(summary, 6, 64)) return null;
    if (supportingLine !== null && !withinLength(supportingLine, 1, 48)) return null;
    if (copyKey(headline) === copyKey(summary)) return null;
    if (!Array.isArray(candidate.evidenceIDs) || candidate.evidenceIDs.length < 1 || candidate.evidenceIDs.length > 6) {
      return null;
    }

    const evidenceIDs = candidate.evidenceIDs.map(cleanText);
    if (new Set(evidenceIDs).size !== evidenceIDs.length) return null;
    const allowedFactIDs = new Set(pack.facts.map((fact) => fact.id));
    const leadFactID = pack.facts.find((fact) => fact.role === "lead")?.id;
    if (!leadFactID || !evidenceIDs.includes(leadFactID) || evidenceIDs.some((id) => !allowedFactIDs.has(id))) {
      return null;
    }

    const combined = [headline, summary, supportingLine].filter(Boolean).join(" ");
    if (FORBIDDEN_REWRITE_TERMS.some((term) => combined.toLowerCase().includes(term.toLowerCase()))) return null;
    if (/https?:\/\/|www\.|@/i.test(combined) || UUID_PATTERN.test(combined)) return null;
    const allowedNumbers = new Set(
      pack.facts.flatMap((fact) => [...numbersIn(fact.statement), fact.evidenceCount])
    );
    if (numbersIn(combined).some((value) => !allowedNumbers.has(value))) return null;

    rewrites.push({ scope, periodKey, headline, summary, supportingLine, evidenceIDs });
    seenScopes.add(scope);
  }

  return { rewrites };
}

function buildNarrativeRewriteMessages(rawPacks, rawTone) {
  const validation = validateNarrativeFactPacks(rawPacks);
  if (!validation.ok) return null;
  const tone = rawTone === "neutral" ? "中性" : "温和";
  const systemContent = [
    "你是“叙账”的轻量文案改写器，不是事实选择器。",
    "输入只包含本地规则已经选定的脱敏事实。只能改写这些事实，不得添加商户、地点、人物、原因、情绪、动机、建议或预测。",
    "每个结果必须原样返回 scope、periodKey，并用 evidenceIDs 引用输入里的 F 编号；至少引用 lead 事实。",
    `不得补充输入中没有的数字。语气为${tone}，自然、克制、像人话，不煽情、不说教。`,
    "headline 4-32 字，summary 6-64 字，supportingLine 可空且最多 48 字。",
    "只输出 JSON：{\"rewrites\":[{\"scope\":\"day\",\"periodKey\":\"...\",\"headline\":\"...\",\"summary\":\"...\",\"supportingLine\":null,\"evidenceIDs\":[\"F1\"]}]}",
  ].join("\n");
  return [
    { role: "system", content: systemContent },
    { role: "user", content: `脱敏事实包：${JSON.stringify(rawPacks)}` },
  ];
}

function parseJSONObject(content) {
  const trimmed = content.replace(/```json/gi, "").replace(/```/g, "").trim();
  const direct = safeJSONParse(trimmed);
  if (isPlainObject(direct)) return direct;
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  return safeJSONParse(trimmed.slice(start, end + 1));
}

function safeJSONParse(text) {
  try {
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
}

function cleanText(value) {
  if (typeof value !== "string") return "";
  return value.replace(/\s+/g, " ").trim();
}

function copyKey(value) {
  return cleanText(value).toLowerCase().replace(/[\s，。！？；：,.!?;:·「」『』（）()]/g, "");
}

function numbersIn(value) {
  return (String(value || "").match(/\d+/g) || []).map(Number).filter(Number.isFinite);
}

function withinLength(value, minimum, maximum) {
  const length = Array.from(value).length;
  return length >= minimum && length <= maximum;
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function hasOnlyKeys(value, allowedKeys) {
  const allowed = new Set(allowedKeys);
  return Object.keys(value).every((key) => allowed.has(key));
}

function invalid(reason) {
  return { ok: false, error: "INVALID_NARRATIVE_FACT_PACK", reason };
}

module.exports = {
  buildNarrativeRewriteMessages,
  normalizeNarrativeRewriteBatch,
  validateNarrativeFactPacks,
};
