import { Server } from "socket.io";
import { createAdapter } from "@socket.io/redis-adapter";
import { env } from "../config/env.js";
import { redisPub, redisSub } from "../db/redis.js";
import { chooseBotCard } from "../game/bot.js";
import { createMatch, dealFirstFive, dealRemainingCards, playCard, publicStateForSeat, selectPowerSuit, startNextTrick } from "../game/engine.js";
import { legalCardsForSeat } from "../game/rules.js";
import { MatchMode, PlayerSeat, Suit } from "../game/types.js";
import { teamForSeat } from "../game/deck.js";
import { MatchModel } from "../models/Match.js";
import { ReplayModel } from "../models/Replay.js";
import { FriendModel } from "../models/Friend.js";
import { UserModel } from "../models/User.js";
import { matchmaking } from "../services/matchmakingService.js";
import { matchStore } from "../services/matchStore.js";
import { applyRankedResult } from "../services/rankingService.js";
import { authenticateSocket, AuthedSocket } from "./authSocket.js";
import { StatisticsModel } from "../models/Statistics.js";
import { RankingModel } from "../models/Ranking.js";
import { z } from "zod";
import { checkAndAwardAchievements, ACHIEVEMENTS } from "../game/achievements.js";

// Track online users for friend status
const onlineUsers = new Set<string>();
const activeSocketsByUser = new Map<string, Set<string>>();
const disconnectGraceTimers = new Map<string, NodeJS.Timeout>();
const rankedQueueRequests = new Map<string, number>();

function currentSeason() {
  const now = new Date();
  return `${now.getUTCFullYear()}-Q${Math.floor(now.getUTCMonth() / 3) + 1}`;
}

async function opponentAverageMmr(state: ReturnType<typeof requireMatch>, userId: string, season: string): Promise<number> {
  if (env.OFFLINE_DEV_MODE) return 0;
  const leaver = state.players.find((player) => player.userId === userId);
  if (!leaver) return 0;
  const opposingIds = state.players
    .filter((player) => !player.isBot && teamForSeat(player.seat) !== teamForSeat(leaver.seat))
    .map((player) => player.userId);
  if (opposingIds.length === 0) return 0;
  const ratings = await RankingModel.find({
    userId: { $in: opposingIds },
    season,
  }).select("mmr").lean();
  if (ratings.length === 0) return 0;
  return ratings.reduce((sum, ranking) => sum + ranking.mmr, 0) / ratings.length;
}

export function registerGameSockets(io: Server) {
  if (!env.OFFLINE_DEV_MODE) {
    io.adapter(createAdapter(redisPub, redisSub));
  }
  io.use(authenticateSocket);

  io.on("connection", (socket: AuthedSocket) => {
    const userId = socket.user!.id;
    console.log(`[SOCKET] User connected: ${userId} (${socket.user?.username})`);
    socket.join(`user:${userId}`);
    const userSockets = activeSocketsByUser.get(userId) ?? new Set<string>();
    userSockets.add(socket.id);
    activeSocketsByUser.set(userId, userSockets);
    onlineUsers.add(userId);
    reconnectMatch(io, socket);
    broadcastFriendStatus(io, userId, "online");

    socket.on("queue:ranked", async () => {
      const requestId = (rankedQueueRequests.get(userId) ?? 0) + 1;
      rankedQueueRequests.set(userId, requestId);
      console.log(`[SOCKET] queue:ranked from user ${userId} (${socket.user!.username})`);
      try {
        const requestedParty = matchmaking.getPartyForUser(userId) ?? [{
          userId,
          username: socket.user!.username,
          socketId: socket.id,
          mmr: 0,
        }];

        for (const player of requestedParty) {
          const activeMatch = matchStore.findByUser(player.userId);
          if (activeMatch && activeMatch.phase !== "complete") {
            throw new Error("Finish or leave your current match before queuing");
          }
        }

        // Ratings are server-owned; never trust a client-supplied MMR value.
        const ratingByUser = new Map<string, number>();
        if (!env.OFFLINE_DEV_MODE) {
          const ratings = await RankingModel.find({
            userId: { $in: requestedParty.map((player) => player.userId) },
            season: currentSeason(),
          }).select("userId mmr").lean();
          for (const rating of ratings) {
            ratingByUser.set(rating.userId, rating.mmr);
          }
        }
        if (requestId !== rankedQueueRequests.get(userId)) return;

        const ratedParty = requestedParty.map((player) => ({
          ...player,
          socketId: player.userId === userId ? socket.id : player.socketId,
          mmr: ratingByUser.get(player.userId) ?? 0,
        }));
        for (const player of ratedParty) {
          const activeMatch = matchStore.findByUser(player.userId);
          if (activeMatch && activeMatch.phase !== "complete") {
            throw new Error("Finish or leave your current match before queuing");
          }
        }
        const group = matchmaking.enqueueRanked(ratedParty);

        for (const player of ratedParty) {
          io.to("user:" + player.userId).emit("queue:joined", { mode: "ranked" });
        }
        if (group) startMatch(io, matchmaking.toSeats(group), "ranked");
      } catch (err) {
        console.error("[RankedQueue] Could not enqueue players:", err);
        socket.emit("error", {
          message: err instanceof Error ? err.message : "Could not enter ranked matchmaking",
        });
      }
    });

    socket.on("queue:cancel", () => {
      rankedQueueRequests.set(userId, (rankedQueueRequests.get(userId) ?? 0) + 1);
      const queuedGroup = matchmaking.getRankedQueueGroupForUser(userId) ?? [];
      const queuedIds = new Set<string>([userId, ...queuedGroup.map((player) => player.userId)]);

      matchmaking.removeFromQueue(userId);

      // The cancelling client resets its own state synchronously. Notify only
      // other party members so a late acknowledgement cannot cancel a brand-new
      // search started immediately after Play Again.
      for (const queuedUserId of queuedIds) {
        if (queuedUserId === userId) continue;
        io.to(`user:${queuedUserId}`).emit("queue:cancelled", { mode: "ranked" });
      }
      console.log(`[RankedQueue] Cancelled search for ${[...queuedIds].join(", ")}`);
    });

    socket.on("party:invite", async (payload: unknown) => {
      try {
        const parsed = z.object({ targetUserId: z.string().min(1).max(128) }).safeParse(payload);
        if (!parsed.success || parsed.data.targetUserId === userId) {
          socket.emit("error", { message: "Choose a valid player to invite" });
          return;
        }
        const { targetUserId } = parsed.data;
        const target = env.OFFLINE_DEV_MODE
          ? { id: targetUserId }
          : await UserModel.findById(targetUserId).select("_id").lean();
        if (!target) {
          socket.emit("error", { message: "Player not found" });
          return;
        }
        if (!env.OFFLINE_DEV_MODE) {
          const friendship = await FriendModel.findOne({
            status: "accepted",
            $or: [
              { requesterId: userId, addresseeId: targetUserId },
              { requesterId: targetUserId, addresseeId: userId },
            ],
          }).select("_id").lean();
          if (!friendship) {
            socket.emit("error", { message: "You can invite accepted friends only" });
            return;
          }
        }
        const activeMatch = matchStore.findByUser(userId);
        if (activeMatch && activeMatch.phase !== "complete") {
          throw new Error("Leave your match before inviting a party member");
        }
        let partyId = matchmaking.getPartyIdForUser(userId);
        if (!partyId) {
          partyId = matchmaking.createParty({
            userId,
            username: socket.user!.username,
            socketId: socket.id,
            mmr: 0,
          });
          socket.emit("party:updated", { party: matchmaking.getParty(partyId) });
        }
        io.to(`user:${targetUserId}`).emit("party:invited", {
          from: socket.user!.username,
          partyId,
        });
      } catch (err) {
        socket.emit("error", {
          message: err instanceof Error ? err.message : "Could not send party invitation",
        });
      }
    });

    socket.on("party:accept", (payload: unknown) => {
      try {
        const parsed = z.object({ partyId: z.string().min(1).max(128) }).safeParse(payload);
        if (!parsed.success) throw new Error("Invalid party invitation");
        const activeMatch = matchStore.findByUser(userId);
        if (activeMatch && activeMatch.phase !== "complete") {
          throw new Error("Leave your match before joining a party");
        }
        const party = matchmaking.joinParty(parsed.data.partyId, {
          userId,
          username: socket.user!.username,
          socketId: socket.id,
          mmr: 0
        });
        for (const p of party) {
          io.to(`user:${p.userId}`).emit("party:updated", { party });
        }
      } catch (err: any) {
        socket.emit("error", { message: err.message });
      }
    });

    socket.on("party:leave", () => {
      const queuedGroup = matchmaking.getRankedQueueGroupForUser(userId) ?? [];
      if (queuedGroup.length > 0) {
        matchmaking.removeFromQueue(userId);
        for (const queuedPlayer of queuedGroup) {
          io.to(`user:${queuedPlayer.userId}`).emit("queue:cancelled", { mode: "ranked" });
        }
      }
      const partyId = matchmaking.leaveParty(userId);
      if (partyId) {
        const party = matchmaking.getParty(partyId);
        if (party) {
          for (const p of party) {
            io.to(`user:${p.userId}`).emit("party:updated", { party });
          }
        }
      }
      socket.emit("party:updated", { party: null });
    });

    socket.on("room:create", () => {
      try {
        const activeMatch = matchStore.findByUser(userId);
        if (activeMatch && activeMatch.phase !== "complete") {
          throw new Error("Finish or leave your current match first");
        }
        const code = matchmaking.createPrivateRoom({
          userId,
          username: socket.user!.username,
          socketId: socket.id,
          mmr: 0,
        });
        socket.emit("room:created", { code });
        broadcastPrivateRoom(io, code);
      } catch (err: any) {
        socket.emit("error", { message: err?.message ?? "Could not create room" });
      }
    });

    socket.on("room:join", (data?: { code?: string }) => {
      try {
        const code = typeof data?.code === "string" ? data.code.trim().toUpperCase() : "";
        if (!code) throw new Error("Enter a room code");
        if (code.length !== 6) throw new Error("Room code must be 6 characters");

        const activeMatch = matchStore.findByUser(userId);
        if (activeMatch && activeMatch.phase !== "complete") {
          throw new Error("Finish or leave your current match first");
        }
        const group = matchmaking.joinPrivateRoom(code, {
          userId,
          username: socket.user!.username,
          socketId: socket.id,
          mmr: 0,
        });
        socket.emit("room:joined", { code });
        if (group) {
          startMatch(io, matchmaking.toSeats(group), "private");
        } else {
          broadcastPrivateRoom(io, code);
        }
      } catch (err: any) {
        socket.emit("error", { message: err?.message ?? "Could not join room" });
      }
    });

    socket.on("room:leave", (payload?: unknown) => {
      try {
        const parsed = z.object({ code: z.string().min(1).max(6).optional() }).safeParse(payload ?? {});
        if (!parsed.success) throw new Error("Invalid room code");
        const left = matchmaking.leavePrivateRoom(userId, parsed.data.code);
        if (!left) throw new Error("You are not in a private room");
        socket.emit("room:left", { code: left.code });
        if (left.players.length > 0) {
          broadcastPrivateRoom(io, left.code, left.players);
        }
      } catch (err) {
        socket.emit("error", { message: err instanceof Error ? err.message : "Could not leave room" });
      }
    });

    socket.on("room:startWithBots", (data?: { code?: string }) => {
      try {
        const code = typeof data?.code === "string" ? data.code.trim().toUpperCase() : "";
        if (!code) throw new Error("Create or join a room first");
        const activeMatch = matchStore.findByUser(userId);
        if (activeMatch && activeMatch.phase !== "complete") {
          throw new Error("Finish or leave your current match first");
        }
        const group = matchmaking.startRoomWithBots(code, "hard", userId);
        if (group) startMatch(io, matchmaking.toSeats(group), "private");
      } catch (err: any) {
        socket.emit("error", { message: err?.message ?? "Could not start room" });
      }
    });

    socket.on("bot:offline", (payload: unknown) => {
      const parsed = z.object({ difficulty: z.enum(["easy", "medium", "hard"]).optional() }).safeParse(payload ?? {});
      if (!parsed.success) {
        socket.emit("error", { message: "Choose a valid bot difficulty" });
        return;
      }
      const difficulty = parsed.data.difficulty ?? "medium";
      try {
        const existing = matchStore.findByUser(userId);
        if (existing && existing.phase !== "complete") {
          throw new Error("Leave your current match before starting another");
        }
        if (matchmaking.isUserInRankedQueue(userId)) {
          throw new Error("Cancel ranked matchmaking before starting a practice match");
        }
        if (matchmaking.getPrivateRoomCodeForUser(userId)) {
          throw new Error("Leave your private room before starting a practice match");
        }
        if (matchmaking.getPartyForUser(userId)?.length) {
          throw new Error("Leave your party before starting a practice match");
        }

      const seats: PlayerSeat[] = [
        { seat: 0, userId, username: socket.user!.username, connected: true, isBot: false },
        { seat: 1, userId: "bot-1", username: "Vector", connected: true, isBot: true, botDifficulty: difficulty },
        { seat: 2, userId: "bot-2", username: "Nova", connected: true, isBot: true, botDifficulty: difficulty },
        { seat: 3, userId: "bot-3", username: "Cipher", connected: true, isBot: true, botDifficulty: difficulty }
      ];
      startMatch(io, seats, "offline");
      } catch (err) {
        socket.emit("error", { message: err instanceof Error ? err.message : "Could not start practice match" });
      }
    });

    socket.on("match:leave", async () => {
      matchmaking.removeFromQueue(userId);
      const state = matchStore.findByUser(userId);
      if (state && state.phase !== "complete") {
        // Leaving an offline match should end that local table entirely instead
        // of quietly handing the player seat to a bot.
        if (state.mode === "offline") {
          socket.leave("match:" + state.id);
          io.to("match:" + state.id).emit("match:abandoned", { userLeft: userId, ended: true });
          matchStore.delete(state.id);
          console.log("[GAME] Offline match " + state.id + " ended because " + userId + " left");
          return;
        }
        if (state.mode === "ranked") {
          // Penalize quitting player
          const season = currentSeason();
          const opponentAvg = await opponentAverageMmr(state, userId, season);
          const result = await applyRankedResult(userId, season, opponentAvg, false);
          const totals = result.ranking as { wins?: number; losses?: number; peakMmr?: number };
          socket.emit("rank:updated", {
            oldMmr: result.oldMmr,
            newMmr: result.newMmr,
            mmrDelta: result.mmrDelta,
            rank: result.rankDetail,
            wins: totals.wins,
            losses: totals.losses,
            peakMmr: totals.peakMmr,
          });
        }
        const player = state.players.find(p => p.userId === userId);
        if (player) {
          player.connected = false;
          player.isBot = true;
          player.botDifficulty = "medium";
        }
        socket.leave(`match:${state.id}`);
        io.to(`match:${state.id}`).emit("match:abandoned", { userLeft: userId });
        matchStore.set(state);
        if (state.phase === "power-select" && state.firstPlayerSeat === player?.seat) {
          maybeBotPowerSelect(io, state.id);
        } else if (state.phase === "playing" && state.currentTurnSeat === player?.seat) {
          maybeBotTurn(io, state.id);
        }
      }
    });

    socket.on("power:select", (payload: unknown) => {
      try {
        const parsed = z.object({
          matchId: z.string().min(1),
          suit: z.enum(["hearts", "diamonds", "clubs", "spades"]),
        }).safeParse(payload);
        if (!parsed.success) {
          socket.emit("error", { message: "Invalid power suit selection" });
          return;
        }
        const { matchId, suit } = parsed.data;
        const state = requireMatch(matchId);
        const seat = seatForUser(state.players, userId);
        selectPowerSuit(state, seat, suit);
        dealRemainingCards(state);
        state.turnDeadline = state.mode === "offline" ? undefined : Date.now() + env.TURN_TIMEOUT_MS;
        matchStore.set(state);
        broadcastState(io, state.id);
        maybeBotTurn(io, state.id);
        if (!state.players[state.currentTurnSeat].isBot) {
          scheduleTurnTimeout(io, state.id, state.currentTurnSeat, state.turnDeadline, state.turnGeneration);
        }
      } catch (err: any) {
        socket.emit("error", { message: err.message });
      }
    });

    socket.on("card:play", (payload: unknown) => {
      try {
        const parsed = z.object({
          matchId: z.string().min(1),
          cardId: z.string().min(1).max(32),
        }).safeParse(payload);
        if (!parsed.success) {
          socket.emit("error", { message: "Invalid card play request" });
          return;
        }
        const { matchId, cardId } = parsed.data;
        const state = requireMatch(matchId);
        const seat = seatForUser(state.players, userId);
        const result = playCard(state, seat, cardId);
        
        // Always refresh deadline after any card play so clients show an accurate timer
        state.turnDeadline = state.mode === "offline" ? undefined : Date.now() + env.TURN_TIMEOUT_MS;
        
        matchStore.set(state);
        broadcastState(io, state.id);
        void persistIfComplete(io, state);
        
        if (result.trickCompleted && !result.matchCompleted) {
          setTimeout(() => {
            const fresh = matchStore.get(matchId);
            if (fresh && fresh.phase === "trick-resolving") {
              startNextTrick(fresh);
              fresh.turnDeadline = fresh.mode === "offline" ? undefined : Date.now() + env.TURN_TIMEOUT_MS;
              matchStore.set(fresh);
              broadcastState(io, matchId);
              maybeBotTurn(io, matchId);
              if (!fresh.players[fresh.currentTurnSeat].isBot) {
                scheduleTurnTimeout(io, matchId, fresh.currentTurnSeat, fresh.turnDeadline, fresh.turnGeneration);
              }
            }
          }, 2000);
        } else {
          maybeBotTurn(io, state.id);
          if (state.phase === "playing" && !state.players[state.currentTurnSeat].isBot) {
            scheduleTurnTimeout(io, state.id, state.currentTurnSeat, state.turnDeadline!, state.turnGeneration);
          }
        }
      } catch (err: any) {
        socket.emit("error", { message: err.message });
      }
    });

    socket.on("spectate:join", (payload: unknown) => {
      try {
        const parsed = z.object({ matchId: z.string().min(1) }).safeParse(payload);
        if (!parsed.success) throw new Error("Invalid match id");
        const { matchId } = parsed.data;
        const state = requireMatch(matchId);
        socket.join(`match:${matchId}:spectators`);
        socket.emit("match:spectatorState", {
          ...publicStateForSeat(state),
          turnTimeoutMs: env.TURN_TIMEOUT_MS,
        });
      } catch (err) {
        socket.emit("error", { message: err instanceof Error ? err.message : "Could not spectate match" });
      }
    });

    socket.on("friends:status", async () => {
      if (env.OFFLINE_DEV_MODE) return socket.emit("friends:statusList", { statuses: [] });
      try {
        const friends = await FriendModel.find({
          status: "accepted",
          $or: [{ requesterId: userId }, { addresseeId: userId }]
        });
        const statuses = friends.map(f => {
          const otherId = f.requesterId.toString() === userId ? f.addresseeId.toString() : f.requesterId.toString();
          return { userId: otherId, online: onlineUsers.has(otherId) };
        });
        socket.emit("friends:statusList", { statuses });
      } catch (err) {
        console.error("Friends status error:", err);
      }
    });

    // ── Emotes ────────────────────────────────────────────────────────
    const lastEmoteTime = new Map<string, number>();
    socket.on("emote:send", (payload: unknown) => {
      const parsed = z.object({
        matchId: z.string().min(1),
        emote: z.enum(["nice", "gg", "oops", "wow", "hurry", "angry"]),
      }).safeParse(payload);
      if (!parsed.success) return;
      const { matchId, emote } = parsed.data;
      const now = Date.now();
      const last = lastEmoteTime.get(userId) ?? 0;
      if (now - last < 3000) return; // Rate limit: 1 emote per 3 seconds
      lastEmoteTime.set(userId, now);
      
      
      const emoteState = matchStore.get(matchId);
      if (!emoteState) return;
      const emotePlayer = emoteState.players.find(p => p.userId === userId);
      if (!emotePlayer) return;
      
      io.to(`match:${matchId}`).emit("emote:received", {
        seat: emotePlayer.seat,
        username: emotePlayer.username,
        emote,
      });
    });

    socket.on("disconnect", () => {
      rankedQueueRequests.set(userId, (rankedQueueRequests.get(userId) ?? 0) + 1);
      const liveSockets = activeSocketsByUser.get(userId);
      liveSockets?.delete(socket.id);
      if (liveSockets && liveSockets.size > 0) {
        // Multiple tabs/devices share one user room; one closing must not
        // mark the account offline or replace its live player's seat.
        return;
      }
      activeSocketsByUser.delete(userId);
      onlineUsers.delete(userId);
      const queuedGroup = matchmaking.getRankedQueueGroupForUser(userId) ?? [];
      matchmaking.removeFromQueue(userId);
      for (const queuedPlayer of queuedGroup) {
        if (queuedPlayer.userId !== userId) {
          io.to(`user:${queuedPlayer.userId}`).emit("queue:cancelled", { mode: "ranked" });
        }
      }
      for (const changedRoom of matchmaking.removeFromPrivateRooms(userId)) {
        broadcastPrivateRoom(io, changedRoom.code, changedRoom.players);
      }
      broadcastFriendStatus(io, userId, "offline");
      
      const partyId = matchmaking.leaveParty(userId);
      if (partyId) {
        const party = matchmaking.getParty(partyId);
        if (party) {
          for (const p of party) {
            io.to(`user:${p.userId}`).emit("party:updated", { party });
          }
        }
      }

      const state = matchStore.findByUser(userId);
      if (!state) return;
      const player = state.players.find((item) => item.userId === userId);
      if (!player) return;
      
      // Mark as disconnected but start grace period before converting to bot
      player.connected = false;
      matchStore.set(state);
      broadcastState(io, state.id);
      
      const graceTimer = setTimeout(() => {
        disconnectGraceTimers.delete(userId);
        const freshState = matchStore.get(state.id);
        if (!freshState || freshState.phase === "complete") return;
        const freshPlayer = freshState.players.find(p => p.userId === userId);
        if (!freshPlayer || freshPlayer.connected) return;
        
        freshPlayer.isBot = true;
        freshPlayer.botDifficulty = "medium";
        matchStore.set(freshState);
        if (freshState.mode === "ranked") {
          // Disconnect abandonment must not bypass the ranked-loss penalty.
          const season = currentSeason();
          void opponentAverageMmr(freshState, userId, season)
            .then((opponentAvg) => applyRankedResult(userId, season, opponentAvg, false))
            .then((result) => {
              const totals = result.ranking as { wins?: number; losses?: number; peakMmr?: number };
              io.to(`user:${userId}`).emit("rank:updated", {
                oldMmr: result.oldMmr,
                newMmr: result.newMmr,
                mmrDelta: result.mmrDelta,
                rank: result.rankDetail,
                wins: totals.wins,
                losses: totals.losses,
                peakMmr: totals.peakMmr,
              });
            })
            .catch((err) => console.error(`Failed to apply disconnect penalty for ${userId}:`, err));
        }
        io.to(`match:${freshState.id}`).emit("match:playerBotReplaced", { userId, username: freshPlayer.username });
        broadcastState(io, freshState.id);
        
        if (freshState.phase === "power-select" && freshState.firstPlayerSeat === freshPlayer.seat) {
          maybeBotPowerSelect(io, freshState.id);
        } else if (freshState.phase === "playing" && freshState.currentTurnSeat === freshPlayer.seat) {
          maybeBotTurn(io, freshState.id);
        }
      }, env.DISCONNECT_GRACE_MS);
      
      disconnectGraceTimers.set(userId, graceTimer);
    });
  });
}

function broadcastPrivateRoom(
  io: Server,
  code: string,
  knownPlayers?: Array<{ userId: string; username: string }>,
) {
  const players = knownPlayers ?? matchmaking.getPrivateRoom(code);
  if (!players || players.length === 0) return;

  const update = {
    code,
    players: players.map((player) => ({
      userId: player.userId,
      username: player.username,
    })),
    playerCount: players.length,
    capacity: 4,
  };
  for (const player of players) {
    io.to(`user:${player.userId}`).emit("room:updated", update);
  }
}

function startMatch(io: Server, players: PlayerSeat[], mode: MatchMode) {
  if (players.length !== 4 || new Set(players.map((player) => player.seat)).size !== 4 ||
      players.some((player) => !Number.isInteger(player.seat) || player.seat < 0 || player.seat > 3)) {
    throw new Error("A match requires four unique seats from 0 to 3");
  }
  const humanIds = players.filter((player) => !player.isBot).map((player) => player.userId);
  if (new Set(humanIds).size !== humanIds.length) {
    throw new Error("A player cannot occupy more than one seat");
  }
  for (const player of players.filter((item) => !item.isBot)) {
    const activeMatch = matchStore.findByUser(player.userId);
    if (activeMatch && activeMatch.phase !== "complete") {
      throw new Error(`${player.username} is already in an active match`);
    }
  }
  const state = dealFirstFive(createMatch(players, mode));
  state.turnDeadline = state.mode === "offline" ? undefined : Date.now() + env.TURN_TIMEOUT_MS;
  matchStore.set(state);
  console.log(`[GAME] Starting match ${state.id} (${mode}) with players: ${players.map(p => `${p.username}(${p.userId})`).join(', ')}`);
  for (const player of players) {
    io.to(`user:${player.userId}`).socketsJoin(`match:${state.id}`);
    io.to(`user:${player.userId}`).emit("match:created", { matchId: state.id, mode });
  }
  io.to(`match:${state.id}`).emit("match:created", { matchId: state.id, mode });
  broadcastState(io, state.id);
  maybeBotPowerSelect(io, state.id);
}

function broadcastState(io: Server, matchId: string) {
  const state = requireMatch(matchId);
  console.log(`[GAME] Broadcasting state for match ${matchId}, phase: ${state.phase}`);
  for (const player of state.players) {
    io.to(`user:${player.userId}`).emit("match:state", {
      ...publicStateForSeat(state, player.seat),
      turnTimeoutMs: env.TURN_TIMEOUT_MS,
    });
  }
  io.to(`match:${matchId}:spectators`).emit("match:spectatorState", {
    ...publicStateForSeat(state),
    turnTimeoutMs: env.TURN_TIMEOUT_MS,
  });
}

function reconnectMatch(io: Server, socket: AuthedSocket) {
  // Cancel any pending disconnect grace timer
  const graceTimer = disconnectGraceTimers.get(socket.user!.id);
  if (graceTimer) {
    clearTimeout(graceTimer);
    disconnectGraceTimers.delete(socket.user!.id);
  }

  const state = matchStore.findByUser(socket.user!.id);
  if (!state) return;
  const player = state.players.find((item) => item.userId === socket.user!.id);
  if (player) player.connected = true;
  matchStore.set(state);
  socket.join(`match:${state.id}`);
  broadcastState(io, state.id);
}

function maybeBotPowerSelect(io: Server, matchId: string) {
  const state = requireMatch(matchId);
  const first = state.players[state.firstPlayerSeat];
  if (!first?.isBot || state.phase !== "power-select") return;
  setTimeout(() => {
    const fresh = matchStore.get(matchId);
    if (!fresh || fresh.phase !== "power-select") return;
    // Pick the suit the bot has the most cards of
    const botHand = fresh.hands[fresh.firstPlayerSeat] || [];
    const suitCounts: Record<string, number> = {};
    for (const c of botHand) { suitCounts[c.suit] = (suitCounts[c.suit] || 0) + 1; }
    const bestSuit = (Object.entries(suitCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "spades") as Suit;
    const stateAfterDeal = dealRemainingCards(selectPowerSuit(fresh, fresh.firstPlayerSeat, bestSuit));
    stateAfterDeal.turnDeadline = stateAfterDeal.mode === "offline" ? undefined : Date.now() + env.TURN_TIMEOUT_MS;
    matchStore.set(stateAfterDeal);
    broadcastState(io, matchId);
    maybeBotTurn(io, matchId);
    if (!stateAfterDeal.players[stateAfterDeal.currentTurnSeat].isBot) {
      scheduleTurnTimeout(io, matchId, stateAfterDeal.currentTurnSeat, stateAfterDeal.turnDeadline, stateAfterDeal.turnGeneration);
    }
  }, env.BOT_THINK_MS);
}

function maybeBotTurn(io: Server, matchId: string) {
  const state = matchStore.get(matchId);
  if (!state || state.phase !== "playing") return;
  const expectedSeat = state.currentTurnSeat;
  const expectedGeneration = state.turnGeneration;
  const player = state.players[expectedSeat];
  if (!player?.isBot) return;
  setTimeout(() => {
    const fresh = matchStore.get(matchId);
    if (!fresh || fresh.phase !== "playing") return;
    // Deduplicate scheduled bot actions and ignore timers from prior turns.
    if (fresh.currentTurnSeat !== expectedSeat || fresh.turnGeneration !== expectedGeneration) return;
    const bot = fresh.players[fresh.currentTurnSeat];
    if (!bot?.isBot) return;
    let card;
    try {
      card = chooseBotCard(fresh, fresh.currentTurnSeat, bot.botDifficulty ?? "medium");
    } catch (err) {
      console.error(`[BOT] chooseBotCard failed for seat ${fresh.currentTurnSeat}, falling back:`, err);
      const legal = legalCardsForSeat(fresh, fresh.currentTurnSeat);
      if (!legal || legal.length === 0) return;
      card = legal[0];
    }
    const result = playCard(fresh, fresh.currentTurnSeat, card.id);
    matchStore.set(fresh);
    broadcastState(io, matchId);
    void persistIfComplete(io, fresh);

    if (result.trickCompleted && !result.matchCompleted) {
      setTimeout(() => {
        const freshAfterTrick = matchStore.get(matchId);
        if (freshAfterTrick && freshAfterTrick.phase === "trick-resolving") {
          startNextTrick(freshAfterTrick);
          freshAfterTrick.turnDeadline = freshAfterTrick.mode === "offline" ? undefined : Date.now() + env.TURN_TIMEOUT_MS;
          matchStore.set(freshAfterTrick);
          broadcastState(io, matchId);
          maybeBotTurn(io, matchId);
          if (!freshAfterTrick.players[freshAfterTrick.currentTurnSeat].isBot) {
            scheduleTurnTimeout(io, matchId, freshAfterTrick.currentTurnSeat, freshAfterTrick.turnDeadline, freshAfterTrick.turnGeneration);
          }
        }
      }, 2000);
    } else {
      maybeBotTurn(io, matchId);
      if (fresh.phase === "playing" && !fresh.players[fresh.currentTurnSeat].isBot) {
        scheduleTurnTimeout(io, matchId, fresh.currentTurnSeat, fresh.turnDeadline!, fresh.turnGeneration);
      }
    }
  }, env.BOT_THINK_MS);
}

async function persistIfComplete(io: Server, state: ReturnType<typeof requireMatch>) {
  if (state.phase !== "complete") return;

  const rankResults: Record<string, any> = {};

  // Apply ranked MMR updates BEFORE cleanup
  if (state.mode === "ranked") {
    const season = currentSeason();
    const humanPlayers = state.players.filter(p => !p.isBot);
    
    // Snapshot this season's pre-match ratings so all players are scored
    // against the opposing team's actual average, not a hard-coded zero.
    const ratingByUser = new Map<string, number>();
    if (!env.OFFLINE_DEV_MODE) {
      try {
        const ratings = await RankingModel.find({
          userId: { $in: humanPlayers.map((player) => player.userId) },
          season,
        }).select("userId mmr").lean();
        for (const rating of ratings) ratingByUser.set(rating.userId, rating.mmr);
      } catch (err) {
        console.error("[RankedResult] Could not load ratings for team averages:", err);
      }
    }
    const teamAPlayers = humanPlayers.filter((player) => teamForSeat(player.seat) === "A");
    const teamBPlayers = humanPlayers.filter((player) => teamForSeat(player.seat) === "B");
    const averageMmr = (team: typeof humanPlayers) => team.length === 0
      ? 0
      : team.reduce((sum, player) => sum + (ratingByUser.get(player.userId) ?? 0), 0) / team.length;
    const teamAMmr = averageMmr(teamAPlayers);
    const teamBMmr = averageMmr(teamBPlayers);

    for (const player of humanPlayers) {
      const myTeam = teamForSeat(player.seat);
      const won = state.winnerTeam === myTeam;
      const opponentAvg = myTeam === "A" ? teamBMmr : teamAMmr;
      
      try {
        const result = await applyRankedResult(player.userId, season, opponentAvg, won);
        const rankingTotals = result.ranking as { wins?: number; losses?: number; peakMmr?: number };
        rankResults[player.userId] = {
          oldMmr: result.oldMmr,
          newMmr: result.newMmr,
          mmrDelta: result.mmrDelta,
          rank: result.rankDetail,
          wins: rankingTotals.wins,
          losses: rankingTotals.losses,
          peakMmr: rankingTotals.peakMmr,
        };
      } catch (err) {
        console.error(`Failed to update rank for ${player.userId}:`, err);
      }
    }
    
    // Send rank update to each player
    for (const player of humanPlayers) {
      if (rankResults[player.userId]) {
        io.to(`user:${player.userId}`).emit("rank:updated", rankResults[player.userId]);
      }
    }
  }

  // ── Update Statistics & Check Achievements ────────────────────────
  const matchDurationMs = state.startedAt ? Date.now() - state.startedAt : undefined;
  for (const player of state.players.filter((player) => !player.isBot && state.mode !== "offline")) {
    const myTeam = teamForSeat(player.seat);
    const won = state.winnerTeam === myTeam;
    const teamCaptures = state.captures[myTeam];
    const tensCapturedThisMatch = teamCaptures?.tens?.length ?? 0;
    const acesCapturedThisMatch = teamCaptures?.aces?.length ?? 0;

    if (!env.OFFLINE_DEV_MODE) {
      try {
        const stats = await StatisticsModel.findOneAndUpdate(
          { userId: player.userId },
          {
            $inc: {
              matches: 1,
              wins: won ? 1 : 0,
              tensCaptured: tensCapturedThisMatch,
              acesCaptured: acesCapturedThisMatch,
            },
            $setOnInsert: { currentWinStreak: 0, bestWinStreak: 0 },
          },
          { upsert: true, new: true }
        );

        const newStreak = won ? (stats.currentWinStreak + 1) : 0;
        const bestStreak = Math.max(stats.bestWinStreak, newStreak);
        await StatisticsModel.updateOne(
          { userId: player.userId },
          { $set: { currentWinStreak: newStreak, bestWinStreak: bestStreak } }
        );

        const rankTier = rankResults[player.userId]?.rank?.tier;
        const newAchievements = await checkAndAwardAchievements(
          player.userId, state, won,
          {
            matches: stats.matches,
            wins: stats.wins,
            tensCaptured: stats.tensCaptured,
            acesCaptured: stats.acesCaptured,
            currentWinStreak: newStreak,
            bestWinStreak: bestStreak,
          },
          rankTier,
          matchDurationMs
        );

        if (newAchievements.length > 0) {
          const defs = newAchievements.map(code => ACHIEVEMENTS.find(a => a.code === code)).filter(Boolean);
          io.to(`user:${player.userId}`).emit("achievements:unlocked", { achievements: defs });
        }
      } catch (err) {
        console.error(`Failed to update statistics for ${player.userId}:`, err);
      }
    }
  }

  setTimeout(() => {
    matchStore.delete(state.id);
  }, 10000);

  if (env.OFFLINE_DEV_MODE) return;
  await MatchModel.create({
    mode: state.mode,
    state,
    players: state.players,
    winnerTeam: state.winnerTeam,
    completedAt: new Date()
  });
  await ReplayModel.create({
    matchId: state.id,
    events: state.replayEvents,
    powerSuit: state.powerSuit,
    winnerTeam: state.winnerTeam,
    durationMs: matchDurationMs
  });
}

function requireMatch(matchId: string) {
  const state = matchStore.get(matchId);
  if (!state) throw new Error("Match not found");
  return state;
}

function seatForUser(players: PlayerSeat[], userId: string) {
  const player = players.find((item) => item.userId === userId);
  if (!player) throw new Error("User is not seated in this match");
  return player.seat;
}

async function broadcastFriendStatus(io: Server, userId: string, status: "online" | "offline") {
  if (env.OFFLINE_DEV_MODE) return;
  try {
    const friends = await FriendModel.find({
      status: "accepted",
      $or: [{ requesterId: userId }, { addresseeId: userId }]
    });
    for (const f of friends) {
      const otherId = f.requesterId.toString() === userId ? f.addresseeId.toString() : f.requesterId.toString();
      io.to(`user:${otherId}`).emit("friend:status", { userId, status });
    }
    // Update user status in DB
    await UserModel.updateOne({ _id: userId }, { $set: { status, lastSeenAt: new Date() } });
  } catch (err) {
    console.error("broadcastFriendStatus error:", err);
  }
}

function scheduleTurnTimeout(io: Server, matchId: string, expectedSeat: number, deadline: number | undefined, expectedGeneration: number) {
  const current = matchStore.get(matchId);
  if (!current || current.mode === "offline" || typeof deadline !== "number") return;
  const waitMs = Math.max(0, deadline - Date.now());
  
  setTimeout(() => {
    const state = matchStore.get(matchId);
    if (!state || state.phase !== "playing" || state.currentTurnSeat !== expectedSeat) return;
    if (state.turnGeneration !== expectedGeneration) return; // Reject stale timeout
    
    // Disable auto-play timer for humans in offline (bot) matches
    if (state.mode === "offline") return;

    const player = state.players[expectedSeat];
    if (player.isBot) return;
    
    const legalCards = legalCardsForSeat(state, expectedSeat);
    if (!legalCards || legalCards.length === 0) return;
    
    let cardToPlay = legalCards[0];
    
    try {
      const result = playCard(state, expectedSeat, cardToPlay.id);
      
      // Always refresh deadline after any auto-played card
      state.turnDeadline = state.mode === "offline" ? undefined : Date.now() + env.TURN_TIMEOUT_MS;
      
      matchStore.set(state);
      broadcastState(io, matchId);
      void persistIfComplete(io, state);
      
      if (result.trickCompleted && !result.matchCompleted) {
        setTimeout(() => {
          const fresh = matchStore.get(matchId);
          if (fresh && fresh.phase === "trick-resolving") {
            startNextTrick(fresh);
            fresh.turnDeadline = fresh.mode === "offline" ? undefined : Date.now() + env.TURN_TIMEOUT_MS;
            matchStore.set(fresh);
            broadcastState(io, matchId);
            maybeBotTurn(io, matchId);
            if (!fresh.players[fresh.currentTurnSeat].isBot) {
               scheduleTurnTimeout(io, matchId, fresh.currentTurnSeat, fresh.turnDeadline, fresh.turnGeneration);
            }
          }
        }, 2000);
      } else {
        maybeBotTurn(io, matchId);
         if (state.phase === "playing" && !state.players[state.currentTurnSeat].isBot) {
            scheduleTurnTimeout(io, matchId, state.currentTurnSeat, state.turnDeadline!, state.turnGeneration);
         }
      }
    } catch (err) {
      console.error("Auto-play timeout error", err);
    }
  }, waitMs);
}
