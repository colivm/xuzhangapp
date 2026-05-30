const ANALYTICS_MAX_EVENTS = 5000;

const memoryEventsByUser = new Map();

export function trackEvent(userId, event, props = {}) {
  const payload = {
    id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    event: String(event || "").trim(),
    props: props && typeof props === "object" ? props : {},
    at: new Date().toISOString(),
  };
  if (!payload.event) return payload;
  const list = memoryEventsByUser.get(userId) || [];
  list.unshift(payload);
  memoryEventsByUser.set(userId, list.slice(0, ANALYTICS_MAX_EVENTS));
  return payload;
}

export function listEvents(userId, { limit = 200 } = {}) {
  const list = memoryEventsByUser.get(userId) || [];
  return list.slice(0, Math.max(1, Math.min(Number(limit) || 200, 1000)));
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

