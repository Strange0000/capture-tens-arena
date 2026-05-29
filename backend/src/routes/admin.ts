import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { MatchModel } from "../models/Match.js";
import { ReplayModel } from "../models/Replay.js";

export const adminRouter = Router();

adminRouter.get("/matches", requireAuth, async (req, res, next) => {
  try {
    if (!req.user!.roles.includes("admin")) return res.status(403).json({ error: "Admin only" });
    res.json(await MatchModel.find().sort({ createdAt: -1 }).limit(100));
  } catch (error) {
    next(error);
  }
});

adminRouter.get("/replays/:matchId", requireAuth, async (req, res, next) => {
  try {
    if (!req.user!.roles.includes("admin")) return res.status(403).json({ error: "Admin only" });
    res.json(await ReplayModel.findOne({ matchId: req.params.matchId }));
  } catch (error) {
    next(error);
  }
});
