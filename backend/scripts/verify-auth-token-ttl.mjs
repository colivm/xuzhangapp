process.env.JWT_SECRET = "fix-008-auth-token-test-secret-32-bytes-minimum";

const jwt = (await import("jsonwebtoken")).default;
const {
  ACCESS_TOKEN_TTL_SECONDS,
  signAccessToken,
} = await import("../src/auth.js");

const token = signAccessToken({
  userId: "fix-008-user",
  displayName: "Token Test",
  phone: "",
});
const payload = jwt.decode(token);

if (!payload || !Number.isFinite(payload.iat) || !Number.isFinite(payload.exp)) {
  throw new Error("Access token is missing numeric iat/exp claims.");
}

const actualTTL = payload.exp - payload.iat;
if (ACCESS_TOKEN_TTL_SECONDS !== 90 * 24 * 60 * 60) {
  throw new Error(`Unexpected configured access-token TTL: ${ACCESS_TOKEN_TTL_SECONDS}`);
}
if (actualTTL !== ACCESS_TOKEN_TTL_SECONDS) {
  throw new Error(`Signed access-token TTL mismatch: ${actualTTL}`);
}

console.log(`Auth token TTL verified: ${actualTTL} seconds (90 days).`);
