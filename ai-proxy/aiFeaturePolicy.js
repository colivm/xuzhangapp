const SUPPORTED_FEATURES = new Set([
  "daily",
  "monthly",
  "quarterly",
  "yearly",
  "narrative_rewrite_batch",
]);

function normalizedSupportedFeature(rawFeature) {
  const feature = String(rawFeature || "daily").trim().toLowerCase();
  return SUPPORTED_FEATURES.has(feature) ? feature : null;
}

module.exports = {
  normalizedSupportedFeature,
};
