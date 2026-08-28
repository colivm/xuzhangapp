process.env.JWT_SECRET = "deleted-account-token-test-secret-32-bytes-minimum";

const {
  createRequireAuth,
  signAccessToken,
} = await import("../src/auth.js");

const user = {
  userId: "deleted-account-user",
  displayName: "Current Name",
  phone: "13800000000",
};
const users = new Map([[user.userId, user]]);
const requireAuth = createRequireAuth({
  getUserById: async (userId) => users.get(userId) || null,
});
const accessToken = signAccessToken({
  ...user,
  displayName: "Stale Token Name",
});

const activeResult = await invokeMiddleware(requireAuth, accessToken);
assert(activeResult.nextCalled, "An active account token should reach the protected route.");
assert(activeResult.req.user?.displayName === user.displayName, "Auth must use the current account profile, not stale JWT profile claims.");

users.delete(user.userId);
const deletedResult = await invokeMiddleware(requireAuth, accessToken);
assert(!deletedResult.nextCalled, "A deleted account token must not reach the protected route.");
assert(deletedResult.statusCode === 401, `Expected deleted account status 401, received ${deletedResult.statusCode}.`);
assert(deletedResult.body?.error === "ACCOUNT_NOT_FOUND", `Unexpected deleted account error: ${deletedResult.body?.error}.`);

const invalidResult = await invokeMiddleware(requireAuth, `${accessToken}invalid`);
assert(invalidResult.statusCode === 401, "A malformed token must remain unauthorized.");
assert(invalidResult.body?.error === "INVALID_TOKEN", "Malformed token behavior must remain unchanged.");

console.log("Deleted-account access token invalidation verified.");

async function invokeMiddleware(middleware, token) {
  const req = { headers: { authorization: `Bearer ${token}` } };
  const result = {
    req,
    statusCode: 200,
    body: null,
    nextCalled: false,
  };
  const res = {
    status(code) {
      result.statusCode = code;
      return this;
    },
    json(body) {
      result.body = body;
      return this;
    },
  };
  await middleware(req, res, (error) => {
    if (error) throw error;
    result.nextCalled = true;
  });
  return result;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}
