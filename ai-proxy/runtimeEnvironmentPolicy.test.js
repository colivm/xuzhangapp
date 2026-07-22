const test = require("node:test");
const assert = require("node:assert/strict");
const {
  allowsDevelopmentRoutes,
  isProductionEnvironment,
} = require("./runtimeEnvironmentPolicy");

test("production never registers development routes", () => {
  assert.equal(isProductionEnvironment("production"), true);
  assert.equal(isProductionEnvironment(" PRODUCTION "), true);
  assert.equal(allowsDevelopmentRoutes("production"), false);
  assert.equal(allowsDevelopmentRoutes(" PRODUCTION "), false);
});

test("local and staging retain explicit development routes", () => {
  assert.equal(allowsDevelopmentRoutes("development"), true);
  assert.equal(allowsDevelopmentRoutes("staging"), true);
  assert.equal(allowsDevelopmentRoutes("test"), true);
  assert.equal(allowsDevelopmentRoutes(undefined), true);
});
