import { Request, Router } from "express";
import type { Server } from "socket.io";
import { requireAuth } from "../middleware/auth.js";
import { RankingModel } from "../models/Ranking.js";
import { StatisticsModel } from "../models/Statistics.js";
import { FriendModel } from "../models/Friend.js";
import { UserModel } from "../models/User.js";
import { isOfflineDevMode } from "../config/env.js";
import { rankForMmr, TIERS } from "../services/rankingService.js";
import { AchievementModel } from "../models/Achievement.js";
import { ACHIEVEMENTS } from "../game/achievements.js";
import { classifyFriendRequest, friendshipPairKey } from "../services/friendshipService.js";

export const usersRouter = Router();

usersRouter.get("/me", requireAuth, async (req, res, next) => {
  if (isOfflineDevMode) {
    const rank = rankForMmr(0);
    return res.json({ user: req.user, ranking: { ...rank, wins: 0, losses: 0, peakMmr: 0 }, statistics: null });
  }
  try {
    const [ranking, statistics, dbUser] = await Promise.all([
      RankingModel.findOne({ userId: req.user!.id, season: currentSeason() }),
      StatisticsModel.findOne({ userId: req.user!.id }),
      // PR-B (F10): the guest flag comes from the DB, not the username
      // prefix and not the (7-day, possibly pre-PR-B) JWT — a guest who
      // picked a non-"Guest" name in a later PR must still be a guest,
      // and a Google user must never be mistaken for one.
      UserModel.findById(req.user!.id).select("guest"),
    ]);
    const user = { ...req.user, guest: dbUser?.guest ?? req.user!.guest ?? false };
    
    // Build rank detail even if no ranking doc exists yet
    const mmr = ranking?.mmr ?? 0;
    const rank = rankForMmr(mmr);
    
    res.json({
      user,
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
  if (isOfflineDevMode) {
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

usersRouter.get("/achievements", requireAuth, async (req, res, next) => {
  if (isOfflineDevMode) {
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
  if (isOfflineDevMode) {
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
  if (isOfflineDevMode) return res.json({ users: [] });
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
/**
 * PR-B (F2/F3): exact-username lookup for the "Send friend request"
 * confirm step. /search is a partial match (any substring) and
 * /friends/request used to take a bare username and silently pick the
 * first exact match — with duplicate usernames that could send the
 * request to the wrong person. This endpoint matches the whole
 * username (case-insensitive) and returns EVERY match, so the client
 * can confirm the exact player — or ask the player to pick one when
 * several accounts share the name. `createdAt` is included so
 * duplicates can be told apart ("joined May 2026").
 */
usersRouter.get("/lookup", requireAuth, async (req, res, next) => {
  if (isOfflineDevMode) return res.json({ users: [] });
  try {
    const q = typeof req.query.username === "string" ? req.query.username.trim() : "";
    if (q.length < 2 || q.length > 24) return res.status(400).json({ error: "Enter a username between 2 and 24 characters" });
    const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const users = await UserModel.find({
      username: { $regex: new RegExp("^" + escaped + "$", "i") },
      _id: { $ne: req.user!.id },
    }).select("username avatarUrl status createdAt").sort({ createdAt: 1 }).limit(10);
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
      createdAt: (user as any).createdAt?.toISOString?.() ?? null,
      relationship: byUser.get(user.id) ?? null,
    })) });
  } catch (error) { next(error); }
});

usersRouter.get("/friends", requireAuth, async (req, res, next) => {
  if (isOfflineDevMode) {
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
  if (isOfflineDevMode) return res.status(400).json({ error: "Friend requests are unavailable in offline dev mode" });
  try {
    // PR-B (F2/F3): the client sends a userId once the player has seen
    // and confirmed the exact account (lookup / search row). A bare
    // username is still accepted for older clients, but it must match
    // exactly ONE account — with duplicate usernames the request used
    // to go to whichever account findOne returned first.
    const rawUserId = req.body?.userId;
    const userId = typeof rawUserId === "string" ? rawUserId.trim() : "";
    const raw = req.body?.username;
    const username = typeof raw === "string" ? raw.trim() : "";
    if (!userId && (username.length < 2 || username.length > 24)) return res.status(400).json({ error: "Enter a username between 2 and 24 characters" });
    let target: { id: string; username: string } | null = null;
    if (userId) {
      const found = await UserModel.findById(userId).select("_id username");
      if (!found) return res.status(404).json({ error: "User not found" });
      target = { id: found.id, username: found.username };
    } else {
      const escaped = username.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const matches = await UserModel.find({ username: { $regex: new RegExp("^" + escaped + "$", "i") } }).select("_id username").limit(2);
      if (matches.length === 0) return res.status(404).json({ error: "User not found" });
      if (matches.length > 1) return res.status(409).json({ error: "Several players have that username — search for the player and pick the exact one" });
      target = { id: matches[0].id, username: matches[0].username };
    }
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
  if (isOfflineDevMode) return res.status(400).json({ error: "Friend requests are unavailable in offline dev mode" });
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
  if (isOfflineDevMode) return res.status(400).json({ error: "Friend requests are unavailable in offline dev mode" });
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
