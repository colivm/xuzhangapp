function isProductionEnvironment(nodeEnv) {
  return String(nodeEnv || "").trim().toLowerCase() === "production";
}

function allowsDevelopmentRoutes(nodeEnv) {
  return !isProductionEnvironment(nodeEnv);
}

module.exports = {
  allowsDevelopmentRoutes,
  isProductionEnvironment,
};
