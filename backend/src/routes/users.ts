import { Request, Router } from "express";
import type { Server } from "socket.io";
import { requireAuth } from "../middleware/auth.js";
import { RankingModel } from "../models/Ranking.js";
import { StatisticsModel } from "../models/Statistics.js";
import { MatchModel } from "../models/Match.js";
import { ReplayModel } from "../models/Replay.js";
import { FriendModel } from "../models/Friend.js";
import { UserModel } from "../models/User.js";
import { env } from "../config/env.js";
import { rankForMmr, TIERS } from "../services/rankingService.js";
import { AchievementModel } from "../models/Achievement.js";
import { ACHIEVEMENTS } from "../game/achievements.js";
import { classifyFriendRequest, friendshipPairKey } from "../services/friendshipService.js";

export const usersRouter = Router();

usersRouter.get("/me", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    const rank = rankForMmr(0);
    return res.json({ user: req.user, ranking: { ...rank, wins: 0, losses: 0, peakMmr: 0 }, statistics: null });
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
        ...rank,
        peakMmr: ranking.peakMmr ?? ranking.mmr,
        wins: ranking.wins,
        losses: ranking.losses,
      } : {
        ...rank,
        peakMmr: 0,
        wins: 0,
        losses: 0,
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

usersRouter.get("/replays", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) return res.json({ replays: [] });

  try {
    const userId = req.user!.id;
    const matches = await MatchModel.find({ "players.userId": userId })
      .sort({ completedAt: -1 })
      .limit(50)
      .select("mode players winnerTeam completedAt state")
      .lean();

    const matchIds = matches
      .map((match) => (match.state as any)?.id)
      .filter((id): id is string => typeof id === "string" && id.length > 0);
    if (matchIds.length === 0) return res.json({ replays: [] });

    const savedReplays = await ReplayModel.find({ matchId: { $in: matchIds } })
      .select("matchId events powerSuit winnerTeam durationMs createdAt")
      .lean();
    const replayByMatchId = new Map(savedReplays.map((replay) => [replay.matchId, replay]));

    const replays = matches.flatMap((match) => {
      const state = match.state as any;
      const matchId = typeof state?.id === "string" ? state.id : "";
      const replay = replayByMatchId.get(matchId);
      const players = (match.players ?? []) as Array<{
        userId?: string;
        seat?: number;
        username?: string;
        isBot?: boolean;
      }>;
      const me = players.find((player) => player.userId === userId);
      if (!replay || !me || !matchId) return [];

      const myTeam = (me.seat ?? -1) % 2 === 0 ? "A" : "B";
      const completedAt = match.completedAt ?? replay.createdAt;
      const startTime = typeof state?.startedAt === "number" ? state.startedAt : undefined;
      const durationMs = typeof replay.durationMs === "number"
        ? replay.durationMs
        : startTime && completedAt
          ? Math.max(0, new Date(completedAt).getTime() - startTime)
          : 0;

      return [{
        matchId,
        mode: match.mode,
        players: players.map((player) => ({
          seat: player.seat,
          username: player.username ?? "Player",
          isBot: !!player.isBot,
        })),
        winnerTeam: replay.winnerTeam ?? match.winnerTeam ?? null,
        won: (replay.winnerTeam ?? match.winnerTeam) === myTeam,
        powerSuit: replay.powerSuit ?? state?.powerSuit ?? null,
        tricks: Array.isArray(state?.completedTricks) ? state.completedTricks.length : 0,
        durationMs,
        completedAt,
        events: Array.isArray(replay.events) ? replay.events : [],
      }];
    });

    res.json({ replays });
  } catch (error) {
    next(error);
  }
});

usersRouter.get("/achievements", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.json({ achievements: ACHIEVEMENTS.map(a => ({ ...a, unlocked: false, unlockedAt: null })) });
  }
  try {
    const unlocked = await AchievementModel.find({ userId: req.user!.id });
    const unlockedCodes = new Set(unlocked.map(a => a.code));
    const result = ACHIEVEMENTS.map(a => ({
      ...a,
      unlocked: unlockedCodes.has(a.code),
      unlockedAt: unlocked.find(u => u.code === a.code)?.unlockedAt ?? null,
    }));
    res.json({ achievements: result });
  } catch (error) {
    next(error);
  }
});

usersRouter.get("/leaderboard", async (_req, res, next) => {
  if (env.OFFLINE_DEV_MODE) {
    return res.json({ season: currentSeason(), leaders: [] });
  }
  try {
    const leaders = await RankingModel.find({ season: currentSeason() }).sort({ mmr: -1 }).limit(100);
    const enriched = leaders.map(l => ({
      userId: l.userId,
      ...rankForMmr(l.mmr),
      wins: l.wins,
      losses: l.losses,
    }));
    res.json({ season: currentSeason(), leaders: enriched });
  } catch (error) {
    next(error);
  }
});

usersRouter.get("/search", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) return res.json({ users: [] });
  try {
    const q = typeof req.query.q === "string" ? req.query.q.trim() : "";
    if (q.length < 2) return res.json({ users: [] });
    const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const users = await UserModel.find({
      username: { $regex: new RegExp(escaped, "i") },
      _id: { $ne: req.user!.id },
    }).select("username avatarUrl status").sort({ username: 1 }).limit(10);
    const ids = users.map((user) => user.id);
    const relationships = ids.length ? await FriendModel.find({
      $or: [
        { requesterId: req.user!.id, addresseeId: { $in: ids } },
        { addresseeId: req.user!.id, requesterId: { $in: ids } },
      ],
    }).select("requesterId addresseeId status") : [];
    const byUser = new Map<string, { status: string; isRequester: boolean; friendId: string }>();
    for (const relation of relationships) {
      const isRequester = relation.requesterId.toString() === req.user!.id;
      const otherId = isRequester ? relation.addresseeId.toString() : relation.requesterId.toString();
      byUser.set(otherId, { status: relation.status, isRequester, friendId: relation.id });
    }
    res.json({ users: users.map((user) => ({
      id: user.id, username: user.username, avatarUrl: user.avatarUrl, status: user.status,
      relationship: byUser.get(user.id) ?? null,
    })) });
  } catch (error) { next(error); }
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
  if (env.OFFLINE_DEV_MODE) return res.status(400).json({ error: "Friend requests are unavailable in offline dev mode" });
  try {
    const raw = req.body?.username;
    const username = typeof raw === "string" ? raw.trim() : "";
    if (username.length < 2 || username.length > 24) return res.status(400).json({ error: "Enter a username between 2 and 24 characters" });
    const escaped = username.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const target = await UserModel.findOne({ username: { $regex: new RegExp("^" + escaped + "$", "i") } }).select("_id username");
    if (!target) return res.status(404).json({ error: "User not found" });
    if (target.id === req.user!.id) return res.status(400).json({ error: "You cannot add yourself as a friend" });
    const requesterId = req.user!.id;
    const addresseeId = target.id;
    const pairKey = friendshipPairKey(requesterId, addresseeId);
    const findPair = () => FriendModel.findOne({ $or: [
      { requesterId, addresseeId },
      { requesterId: addresseeId, addresseeId: requesterId },
      { pairKey },
    ] });
    let existing = await findPair();
    const requestAction = classifyFriendRequest(existing ? {
      status: existing.status,
      requesterId: existing.requesterId.toString(),
      addresseeId: existing.addresseeId.toString(),
    } : null, requesterId, addresseeId);
    if (requestAction === "already-friends") return res.status(409).json({ error: "You are already friends" });
    if (requestAction === "blocked") return res.status(403).json({ error: "This friendship is blocked and cannot receive requests" });
    if (requestAction === "accept-incoming" && existing) {
      const accepted = await FriendModel.findOneAndUpdate({ _id: existing._id, status: "pending", addresseeId: requesterId }, { $set: { status: "accepted" } }, { new: true });
      if (accepted) {
        await incrementFriendCounts(accepted.requesterId.toString(), accepted.addresseeId.toString());
        emitFriendsChanged(req, [requesterId, addresseeId]);
        return res.json({ success: true, status: "accepted", message: "You and " + target.username + " are now friends", friend: accepted });
      }
      existing = await findPair();
      if (existing?.status === "accepted") return res.status(409).json({ error: "You are already friends" });
    }
    if (requestAction === "already-sent") return res.status(409).json({ error: "Friend request already sent" });
    try {
      const friend = await FriendModel.create({ requesterId, addresseeId, pairKey, status: "pending" });
      emitFriendsChanged(req, [addresseeId]);
      return res.status(201).json({ success: true, status: "pending", message: "Friend request sent to " + target.username, friend });
    } catch (error: any) {
      if (error?.code !== 11000) throw error;
      existing = await findPair();
      const racedAction = classifyFriendRequest(existing ? {
        status: existing.status,
        requesterId: existing.requesterId.toString(),
        addresseeId: existing.addresseeId.toString(),
      } : null, requesterId, addresseeId);
      if (racedAction === "already-friends") return res.status(409).json({ error: "You are already friends" });
      if (racedAction === "blocked") return res.status(403).json({ error: "This friendship is blocked and cannot receive requests" });
      if (racedAction === "accept-incoming" && existing) {
        const accepted = await FriendModel.findOneAndUpdate({ _id: existing._id, status: "pending", addresseeId: requesterId }, { $set: { status: "accepted" } }, { new: true });
        if (accepted) {
          await incrementFriendCounts(accepted.requesterId.toString(), accepted.addresseeId.toString());
          emitFriendsChanged(req, [requesterId, addresseeId]);
          return res.json({ success: true, status: "accepted", message: "You and " + target.username + " are now friends", friend: accepted });
        }
      }
      return res.status(409).json({ error: "A friend request already exists" });
    }
  } catch (error) { next(error); }
});
usersRouter.post("/friends/accept", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) return res.status(400).json({ error: "Friend requests are unavailable in offline dev mode" });
  try {
    const friendId = typeof req.body?.friendId === "string" ? req.body.friendId : "";
    if (!friendId) return res.status(400).json({ error: "Friend request ID is required" });
    const friend = await FriendModel.findOneAndUpdate({ _id: friendId, addresseeId: req.user!.id, status: "pending" }, { $set: { status: "accepted" } }, { new: true });
    if (!friend) {
      const visible = await FriendModel.findOne({ _id: friendId, $or: [{ requesterId: req.user!.id }, { addresseeId: req.user!.id }] });
      if (visible?.status === "accepted") return res.json({ success: true, status: "accepted", message: "You are already friends" });
      return res.status(404).json({ error: "Incoming friend request not found or already handled" });
    }
    await incrementFriendCounts(friend.requesterId.toString(), friend.addresseeId.toString());
    emitFriendsChanged(req, [friend.requesterId.toString(), friend.addresseeId.toString()]);
    return res.json({ success: true, status: "accepted", message: "Friend request accepted", friend });
  } catch (error) { next(error); }
});
usersRouter.delete("/friends/:id", requireAuth, async (req, res, next) => {
  if (env.OFFLINE_DEV_MODE) return res.status(400).json({ error: "Friend requests are unavailable in offline dev mode" });
  try {
    // Delete atomically so accept/remove races cannot double-adjust friendCount.
    const friend = await FriendModel.findOneAndDelete({
      _id: req.params.id,
      $or: [{ requesterId: req.user!.id }, { addresseeId: req.user!.id }],
    });
    if (!friend) return res.status(404).json({ error: "Friend request or friendship not found" });
    if (friend.status === "accepted") {
      await Promise.all([
        UserModel.updateOne({ _id: friend.requesterId, friendCount: { $gt: 0 } }, { $inc: { friendCount: -1 } }),
        UserModel.updateOne({ _id: friend.addresseeId, friendCount: { $gt: 0 } }, { $inc: { friendCount: -1 } }),
      ]);
    }
    emitFriendsChanged(req, [friend.requesterId.toString(), friend.addresseeId.toString()]);
    return res.json({ success: true, message: friend.status === "accepted" ? "Friend removed" : "Friend request cancelled" });
  } catch (error) { next(error); }
});
function emitFriendsChanged(req: Request, userIds: string[]) {
  const io = req.app.get("io") as Server | undefined;
  if (!io) return;
  for (const userId of new Set(userIds)) {
    io.to("user:" + userId).emit("friends:changed", {});
  }
}

async function incrementFriendCounts(requesterId: string, addresseeId: string) {
  await Promise.all([
    UserModel.updateOne({ _id: requesterId }, { $inc: { friendCount: 1 } }),
    UserModel.updateOne({ _id: addresseeId }, { $inc: { friendCount: 1 } }),
  ]);
}

function currentSeason() {
  const now = new Date();
  return `${now.getUTCFullYear()}-Q${Math.floor(now.getUTCMonth() / 3) + 1}`;
}
