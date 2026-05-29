import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { RankingModel } from "../models/Ranking.js";
import { StatisticsModel } from "../models/Statistics.js";
import { FriendModel } from "../models/Friend.js";
import { UserModel } from "../models/User.js";
import { env } from "../config/env.js";
import { rankForMmr, TIERS } from "../services/rankingService.js";

export const usersRouter = Router();

usersRouter.get("/me", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    const rank = rankForMmr(0);
    return res.json({ user: req.user, ranking: { mmr: 0, ...rank, wins: 0, losses: 0, peakMmr: 0 }, statistics: null });
  }
  try {
    const [ranking, statistics] = await Promise.all([
      RankingModel.findOne({ userId: req.user!.id, season: currentSeason() }),
      StatisticsModel.findOne({ userId: req.user!.id })
    ]);
    
    // Build rank detail even if no ranking doc exists yet
    const mmr = ranking?.mmr ?? 0;
    const rank = rankForMmr(mmr);
    
    res.json({
      user: req.user,
      ranking: ranking ? {
        mmr: ranking.mmr,
        peakMmr: ranking.peakMmr ?? ranking.mmr,
        wins: ranking.wins,
        losses: ranking.losses,
        ...rank,
      } : {
        mmr: 0,
        peakMmr: 0,
        wins: 0,
        losses: 0,
        ...rank,
      },
      statistics,
      season: currentSeason(),
    });
  } catch (error) {
    next(error);
  }
});

usersRouter.get("/rank/:userId", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.json({ rank: rankForMmr(0) });
  }
  try {
    const ranking = await RankingModel.findOne({ userId: req.params.userId, season: currentSeason() });
    const mmr = ranking?.mmr ?? 0;
    res.json({ rank: rankForMmr(mmr), mmr, wins: ranking?.wins ?? 0, losses: ranking?.losses ?? 0 });
  } catch (error) {
    next(error);
  }
});

usersRouter.get("/tiers", (_req, res) => {
  res.json({ tiers: TIERS });
});

usersRouter.get("/leaderboard", async (_req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.json({ season: currentSeason(), leaders: [] });
  }
  try {
    const leaders = await RankingModel.find({ season: currentSeason() }).sort({ mmr: -1 }).limit(100);
    const enriched = leaders.map(l => ({
      userId: l.userId,
      mmr: l.mmr,
      wins: l.wins,
      losses: l.losses,
      ...rankForMmr(l.mmr),
    }));
    res.json({ season: currentSeason(), leaders: enriched });
  } catch (error) {
    next(error);
  }
});

usersRouter.get("/search", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.json({ users: [] });
  }
  try {
    const q = (req.query.q as string)?.trim();
    if (!q || q.length < 2) return res.json({ users: [] });
    
    const users = await UserModel.find({
      username: { $regex: new RegExp(q, "i") },
      _id: { $ne: req.user!.id }
    }).select("username avatarUrl status").limit(10);
    
    res.json({ users: users.map(u => ({ id: u.id, username: u.username, avatarUrl: u.avatarUrl, status: u.status })) });
  } catch (error) {
    next(error);
  }
});

usersRouter.get("/friends", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.json({ friends: [] });
  }
  try {
    const userId = req.user!.id;
    const friends = await FriendModel.find({
      $or: [{ requesterId: userId }, { addresseeId: userId }]
    });
    
    // Get user details for friends
    const userIds = new Set<string>();
    for (const f of friends) {
      userIds.add(f.requesterId.toString());
      userIds.add(f.addresseeId.toString());
    }
    userIds.delete(userId);
    
    const users = await UserModel.find({ _id: { $in: Array.from(userIds) } }).select("username avatarUrl status");
    const userMap = new Map(users.map(u => [u.id.toString(), { id: u.id, username: u.username, avatarUrl: u.avatarUrl, status: u.status }]));

    const result = friends.map(f => {
      const isRequester = f.requesterId.toString() === userId;
      const otherId = isRequester ? f.addresseeId.toString() : f.requesterId.toString();
      return {
        id: f.id,
        user: userMap.get(otherId),
        status: f.status,
        isRequester
      };
    });

    res.json({ friends: result });
  } catch (error) {
    next(error);
  }
});

usersRouter.post("/friends/request", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.status(400).json({ error: "Cannot add friends in offline dev mode" });
  }
  try {
    const { username } = req.body;
    if (!username) return res.status(400).json({ error: "Username is required" });
    
    const targetUser = await UserModel.findOne({ username: { $regex: new RegExp(`^${username}$`, "i") } });
    if (!targetUser) return res.status(404).json({ error: "User not found" });
    if (targetUser.id === req.user!.id) return res.status(400).json({ error: "Cannot add yourself" });

    const existing = await FriendModel.findOne({
      $or: [
        { requesterId: req.user!.id, addresseeId: targetUser.id },
        { requesterId: targetUser.id, addresseeId: req.user!.id }
      ]
    });

    if (existing) {
      return res.status(400).json({ error: `Friend request already exists with status: ${existing.status}` });
    }

    const friend = await FriendModel.create({
      requesterId: req.user!.id,
      addresseeId: targetUser.id,
      status: "pending"
    });

    res.json({ success: true, friend });
  } catch (error) {
    next(error);
  }
});

usersRouter.post("/friends/accept", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.status(400).json({ error: "Cannot accept friends in offline dev mode" });
  }
  try {
    const { friendId } = req.body;
    if (!friendId) return res.status(400).json({ error: "Friend ID is required" });

    const friend = await FriendModel.findOne({
      _id: friendId,
      addresseeId: req.user!.id,
      status: "pending"
    });

    if (!friend) return res.status(404).json({ error: "Pending friend request not found" });

    friend.status = "accepted";
    await friend.save();

    // Update friend counts for both users
    await Promise.all([
      UserModel.updateOne({ _id: friend.requesterId }, { $inc: { friendCount: 1 } }),
      UserModel.updateOne({ _id: friend.addresseeId }, { $inc: { friendCount: 1 } }),
    ]);

    res.json({ success: true, friend });
  } catch (error) {
    next(error);
  }
});

usersRouter.delete("/friends/:id", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.status(400).json({ error: "Cannot remove friends in offline dev mode" });
  }
  try {
    const friend = await FriendModel.findOne({
      _id: req.params.id,
      $or: [{ requesterId: req.user!.id }, { addresseeId: req.user!.id }]
    });

    if (!friend) return res.status(404).json({ error: "Friend not found" });

    const wasAccepted = friend.status === "accepted";
    await friend.deleteOne();

    // Decrement friend counts if they were accepted friends
    if (wasAccepted) {
      await Promise.all([
        UserModel.updateOne({ _id: friend.requesterId }, { $inc: { friendCount: -1 } }),
        UserModel.updateOne({ _id: friend.addresseeId }, { $inc: { friendCount: -1 } }),
      ]);
    }

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

function currentSeason() {
  const now = new Date();
  return `${now.getUTCFullYear()}-Q${Math.floor(now.getUTCMonth() / 3) + 1}`;
}
