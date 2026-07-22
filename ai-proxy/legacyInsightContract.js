function normalizeInsightPayload(content) {
  if (typeof content !== "string") return null;
  const trimmed = content.replace(/```json/g, "").replace(/```/g, "").trim();
  const object = safeJSONParse(trimmed) || tryExtractJSONObject(trimmed);
  if (object) {
    const summary = typeof object.summary === "string" ? object.summary.trim() : "";
    const action = typeof object.action === "string" ? object.action.trim() : "";
    const encourage = typeof object.encourage === "string" ? object.encourage.trim() : "";
    if (summary) {
      return {
        summary,
        action: action || "继续按你的节奏记录，慢慢就会更清晰。",
        encourage: encourage || "你已经在认真照顾自己的生活啦。",
      };
    }
  }
  // Preserve the existing plain-text fallback for daily/monthly/quarterly/yearly.
  return {
    summary: trimmed.slice(0, 180),
    action: "继续按你的节奏记录，慢慢就会更清晰。",
    encourage: "你已经在认真照顾自己的生活啦。",
  };
}

function safeJSONParse(text) {
  try {
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
}

function tryExtractJSONObject(text) {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  return safeJSONParse(text.slice(start, end + 1));
}

module.exports = {
  normalizeInsightPayload,
};
