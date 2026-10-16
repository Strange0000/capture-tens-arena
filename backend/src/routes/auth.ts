import { Router } from "express";
import { OAuth2Client } from "google-auth-library";
import { z } from "zod";
import { env } from "../config/env.js";
import { createGuest, loginWithGoogle } from "../services/authService.js";

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
      // In production, verify with Google
      let googleId: string;
      let email: string | undefined;
      let avatarUrl: string | undefined;
      let displayName: string | undefined;

      try {
        const client = new OAuth2Client(env.GOOGLE_CLIENT_ID);
        const ticket = await client.verifyIdToken({
          idToken: body.idToken,
          audience: env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        if (!payload || !payload.sub) throw new Error("Invalid Google token");
        googleId = payload.sub;
        email = payload.email;
        avatarUrl = payload.picture;
        displayName = payload.name;
      } catch (verifyErr) {
        // Fallback: If body.idToken is an OAuth2 access token from GIS, verify with userinfo API
        try {
          const res = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
            headers: { Authorization: `Bearer ${body.idToken}` },
          });
          if (!res.ok) throw verifyErr;
          const payload = (await res.json()) as any;
          if (!payload || !payload.sub) throw verifyErr;
          googleId = payload.sub;
          email = payload.email;
          avatarUrl = payload.picture;
          displayName = payload.name;
        } catch (_) {
          throw verifyErr;
        }
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
