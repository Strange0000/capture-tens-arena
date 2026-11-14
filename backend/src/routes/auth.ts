import { Router } from "express";
import { OAuth2Client } from "google-auth-library";
import { z } from "zod";
import { env, isOfflineDevMode } from "../config/env.js";
import { createGuest, loginWithGoogle } from "../services/authService.js";
import { AppError } from "../middleware/error.js";

export const authRouter = Router();

// PR-A (G7): one shared OAuth2Client for the process instead of a new
// client per /auth/google request.
const oauth2Client = new OAuth2Client(env.GOOGLE_CLIENT_ID);

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
      // PR-A (G8): usernames are capped at 24 everywhere (model maxlength).
      username: z.string().min(1).max(24).optional(),
    }).parse(req.body);

    // Verify the Google ID token
    let googleId: string;
    let email: string | undefined;
    let avatarUrl: string | undefined;
    let displayName: string | undefined;

    if (isOfflineDevMode) {
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
        const ticket = await oauth2Client.verifyIdToken({
          idToken: body.idToken,
          audience: env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        if (!payload || !payload.sub) throw new Error("Invalid Google ID token");
        googleId = payload.sub;
        email = payload.email;
        avatarUrl = payload.picture;
        displayName = payload.name;
      } catch (error) {
        // Log the failure reason, never the token itself.
        const message = error instanceof Error ? error.message : "Unknown verification error";
        console.error("Google ID token verification failed", { message });
        // Machine-readable code so the client can tell an expired token
        // from a wrong-audience one without parsing the message.
        const code = /expired|too late/i.test(message)
          ? "token_expired"
          : /audience|recipient/i.test(message)
            ? "invalid_audience"
            : "invalid_token";
        throw new AppError(
          401,
          "Google ID token verification failed. Confirm that GOOGLE_CLIENT_ID matches the frontend Web OAuth client ID.",
          code,
        );
      }
    }

    // PR-A (G8): prefer the verified Google profile name over the
    // client-supplied username — the token payload is the trusted source.
    res.json(await loginWithGoogle({
      googleId,
      email,
      username: displayName ?? body.username ?? email?.split("@")[0] ?? `User${googleId.slice(-6)}`,
      avatarUrl,
    }));
  } catch (error) {
    next(error);
  }
});
