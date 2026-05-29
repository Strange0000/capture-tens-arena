import { Router } from "express";
import { z } from "zod";
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
      googleId: z.string().min(1),
      email: z.string().nullish(),
      username: z.string().min(1).max(30),
      avatarUrl: z.string().nullish()
    }).parse(req.body);
    res.json(await loginWithGoogle(body));
  } catch (error) {
    next(error);
  }
});
