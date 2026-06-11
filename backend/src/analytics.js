const ANALYTICS_MAX_EVENTS = 5000;

const memoryEventsByUser = new Map();

const REDACT_PATTERNS = [
  { re: /https?:\/\/[^\s"'<>]+|www\.[^\s"'<>]+|[\w.-]+@[\w.-]+\.\w+/gi, token: "[REDACTED_LINK_OR_EMAIL]" },
  { re: /(?<!\d)1[3-9]\d{9}(?!\d)/g, token: "[REDACTED_PHONE]" },
  { re: /(?<!\d)\d{6}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[0-9Xx](?!\d)/g, token: "[REDACTED_ID_CARD]" },
  { re: /(?<!\d)(?:\d[ -]?){12,19}(?!\d)/g, token: "[REDACTED_BANK_CARD]" },
];

export function trackEvent(userId, event, props = {}) {
  const payload = {
    id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    event: String(event || "").trim(),
    props: sanitizeProps(props),
    at: new Date().toISOString(),
  };
  if (!payload.event) return payload;
  const list = memoryEventsByUser.get(userId) || [];
  list.unshift(payload);
  memoryEventsByUser.set(userId, list.slice(0, ANALYTICS_MAX_EVENTS));
  return payload;
}

export function deleteEventsByUserId(userId) {
  memoryEventsByUser.delete(userId);
}

export function listEvents(userId, { limit = 200 } = {}) {
  const list = memoryEventsByUser.get(userId) || [];
  return list.slice(0, Math.max(1, Math.min(Number(limit) || 200, 1000)));
}

function sanitizeProps(props) {
  if (!props || typeof props !== "object" || Array.isArray(props)) return {};
  const out = {};
  for (const [key, value] of Object.entries(props)) {
    if (/token|authorization|signed|key|secret/i.test(key)) continue;
    out[key] = sanitizeValue(value);
  }
  return out;
}

function sanitizeValue(value) {
  if (value == null) return value;
  if (typeof value === "string") return redact(value).slice(0, 160);
  if (typeof value === "number" || typeof value === "boolean") return value;
  if (Array.isArray(value)) return value.slice(0, 10).map(sanitizeValue);
  if (typeof value === "object") return sanitizeProps(value);
  return String(value).slice(0, 160);
}

function redact(value) {
  let text = String(value || "");
  for (const item of REDACT_PATTERNS) {
    text = text.replace(item.re, item.token);
  }
  return text;
}

export function summarizeEvents(userId, { days = 7 } = {}) {
  const maxDays = Math.max(1, Math.min(Number(days) || 7, 90));
  const start = new Date();
  start.setDate(start.getDate() - (maxDays - 1));
  start.setHours(0, 0, 0, 0);
  const rows = (memoryEventsByUser.get(userId) || []).filter((item) => new Date(item.at) >= start);
  const byEvent = rows.reduce((acc, item) => {
    acc[item.event] = (acc[item.event] || 0) + 1;
    return acc;
  }, {});
  return {
    windowDays: maxDays,
    eventCount: rows.length,
    byEvent,
  };
}

