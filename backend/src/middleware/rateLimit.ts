import rateLimit from "express-rate-limit";
import { env } from "../config/env.js";

export const apiRateLimit = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false
});

// PR-C: the username availability check runs while the player types
// (client debounces to ~500ms), so it needs a higher ceiling than the
// one-shot claim. Both sit behind auth; the claim is also one-per-account
// by design (hasChosenUsername flips to true on success).
export const usernameCheckRateLimit = rateLimit({
  windowMs: 60_000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many username checks. Wait a moment and try again." },
});

export const usernameClaimRateLimit = rateLimit({
  windowMs: 60_000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many username attempts. Wait a moment and try again." },
});
