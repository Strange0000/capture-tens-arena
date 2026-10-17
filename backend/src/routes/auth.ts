import { Router } from "express";
import { OAuth2Client } from "google-auth-library";
import { z } from "zod";
import { env } from "../config/env.js";
import { createGuest, loginWithGoogle } from "../services/authService.js";
import { AppError } from "../middleware/error.js";

export const authRouter = Router();

authRouter.post("/guest", async (_req, res, next) => {
  try {
    res.json(await createGuest());
  } catch (error) {
    next(error);
  }
});

authRouter.post("/google", async (req, res, next) => {
  try {
    const body = z.object({
      idToken: z.string().min(1),
      username: z.string().min(1).max(30).optional(),
    }).parse(req.body);

    // Verify the Google ID token
    let googleId: string;
    let email: string | undefined;
    let avatarUrl: string | undefined;
    let displayName: string | undefined;

    if (env.OFFLINE_DEV_MODE) {
      // In dev mode, trust the token as a mock googleId
      googleId = body.idToken;
      displayName = body.username;
    } else {
      // Production requires the Web OAuth client ID used to mint the frontend ID token.
      if (!env.GOOGLE_CLIENT_ID) {
        throw new AppError(
          500,
          "Google login is not configured on the backend (missing GOOGLE_CLIENT_ID).",
        );
      }

      try {
        const client = new OAuth2Client(env.GOOGLE_CLIENT_ID);
        const ticket = await client.verifyIdToken({
          idToken: body.idToken,
          audience: env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        if (!payload || !payload.sub) throw new Error("Invalid Google ID token");
        googleId = payload.sub;
        email = payload.email;
        avatarUrl = payload.picture;
        displayName = payload.name;
      } catch (_) {
        throw new AppError(
          401,
          "Google ID token verification failed. Confirm that GOOGLE_CLIENT_ID matches the frontend Web OAuth client ID.",
        );
      }
    }

    res.json(await loginWithGoogle({
      googleId,
      email,
      username: body.username ?? displayName ?? email?.split("@")[0] ?? `User${googleId.slice(-6)}`,
      avatarUrl,
    }));
  } catch (error) {
    next(error);
  }
});
