import jwt from "jsonwebtoken";
import { config } from "./config.js";
import { getUserById } from "./store.js";
import { reviewLoginPolicy } from "./reviewLogin.js";

export const ACCESS_TOKEN_TTL_SECONDS = 90 * 24 * 60 * 60;

export function signAccessToken(user, { reviewPolicy } = {}) {
  return jwt.sign(
    {
      sub: user.userId,
      displayName: user.displayName,
      phone: user.phone || "",
      ...(reviewPolicy ? reviewPolicy.tokenClaims(user.phone) : {}),
    },
    config.jwtSecret,
    reviewPolicy ? {} : { expiresIn: ACCESS_TOKEN_TTL_SECONDS }
  );
}

export function createRequireAuth({ getUserById, reviewPolicy = reviewLoginPolicy }) {
  if (typeof getUserById !== "function") {
    throw new TypeError("createRequireAuth requires getUserById");
  }

  return async function requireAuth(req, res, next) {
    const auth = req.headers.authorization || "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    if (!token) return res.status(401).json({ ok: false, error: "UNAUTHORIZED" });

    let payload;
    try {
      payload = jwt.verify(token, config.jwtSecret);
    } catch {
      return res.status(401).json({ ok: false, error: "INVALID_TOKEN" });
    }

    if (Object.prototype.hasOwnProperty.call(payload, "reviewGrant") && !reviewPolicy.acceptsToken(payload)) {
      return res.status(401).json({ ok: false, error: "INVALID_TOKEN" });
    }

    const userId = typeof payload.sub === "string" ? payload.sub.trim() : "";
    if (!userId) {
      return res.status(401).json({ ok: false, error: "INVALID_TOKEN" });
    }

    try {
      const currentUser = await getUserById(userId);
      if (!currentUser) {
        return res.status(401).json({ ok: false, error: "ACCOUNT_NOT_FOUND" });
      }
      req.user = {
        userId: currentUser.userId,
        displayName: currentUser.displayName || "轻账用户",
        phone: currentUser.phone || "",
      };
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

export const requireAuth = createRequireAuth({ getUserById });
