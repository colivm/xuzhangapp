import jwt from "jsonwebtoken";
import { config } from "./config.js";

export const ACCESS_TOKEN_TTL_SECONDS = 90 * 24 * 60 * 60;

export function signAccessToken(user) {
  return jwt.sign(
    {
      sub: user.userId,
      displayName: user.displayName,
      phone: user.phone || "",
    },
    config.jwtSecret,
    { expiresIn: ACCESS_TOKEN_TTL_SECONDS }
  );
}

export function requireAuth(req, res, next) {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) return res.status(401).json({ ok: false, error: "UNAUTHORIZED" });
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.user = {
      userId: payload.sub,
      displayName: payload.displayName || "轻账用户",
      phone: payload.phone || "",
    };
    return next();
  } catch {
    return res.status(401).json({ ok: false, error: "INVALID_TOKEN" });
  }
}
