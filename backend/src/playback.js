export function buildTodayPlayback(items = []) {
  const today = new Date().toISOString().slice(0, 10);
  const timeline = items
    .filter((item) => String(item.createdAt || "").slice(0, 10) === today)
    .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))
    .slice(0, 16)
    .map((item) => ({
      id: item.id,
      at: item.createdAt,
      category: item.category,
      amount: Number(item.amount || 0),
      title: item.title || "",
    }));
  return {
    durationMs: 10000,
    count: timeline.length,
    timeline,
  };
}

