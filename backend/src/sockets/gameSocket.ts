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
import { matchmaking, type QueuePlayer } from "../services/matchmakingService.js";
import { matchStore } from "../services/matchStore.js";
import { applyRankedResult } from "../services/rankingService.js";
import { authenticateSocket, AuthedSocket } from "./authSocket.js";
import { StatisticsModel } from "../models/Statistics.js";
import { checkAndAwardAchievements, ACHIEVEMENTS } from "../game/achievements.js";

// Track online users for friend status
const onlineUsers = new Set<string>();
const disconnectGraceTimers = new Map<string, NodeJS.Timeout>();

function currentSeason() {
  const now = new Date();
  return `${now.getUTCFullYear()}-Q${Math.floor(now.getUTCMonth() / 3) + 1}`;
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
    onlineUsers.add(userId);
    reconnectMatch(io, socket);
    broadcastFriendStatus(io, userId, "online");

    socket.on("queue:ranked", () => {
      console.log(`[SOCKET] queue:ranked from user ${userId} (${socket.user!.username})`);
      let party = matchmaking.getPartyForUser(userId);
      if (!party) {
        party = [{
          userId,
          username: socket.user!.username,
          socketId: socket.id,
          mmr: 0,
        }];
      }

      const group = matchmaking.enqueueRanked(party);
      for (const player of party) {
        io.to("user:" + player.userId).emit("queue:joined", { mode: "ranked" });
      }

      // Ranked matches must be human-only. Keep players queued until a real
      // group is available; clients can cancel at any time.
      if (group) {
        startMatch(io, matchmaking.toSeats(group), "ranked");
      }
    });

    socket.on("queue:cancel", () => {
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

    socket.on("party:invite", async ({ targetUserId }: { targetUserId: string }) => {
      try {
        if (typeof targetUserId !== "string" || !targetUserId.trim() || targetUserId === userId) {
          throw new Error("Choose a valid friend to invite");
        }
        if (!env.OFFLINE_DEV_MODE) {
          const friendship = await FriendModel.findOne({
            status: "accepted",
            $or: [
              { requesterId: userId, addresseeId: targetUserId },
              { requesterId: targetUserId, addresseeId: userId },
            ],
          });
          if (!friendship) throw new Error("You can only invite accepted friends");
        }

        const existingParty = matchmaking.getPartyForUser(userId);
        if (existingParty && existingParty.length >= 2) {
          throw new Error("Your party is full");
        }
        if (matchmaking.getPartyForUser(targetUserId)) {
          throw new Error("That friend is already in a party");
        }

        // Leaving ranked search before making a duo prevents the old solo
        // fallback timer from launching a match after the invite is sent.
        const queuedGroup = matchmaking.getRankedQueueGroupForUser(userId) ?? [];
        const queuedIds = new Set<string>([userId, ...queuedGroup.map((player) => player.userId)]);
        for (const queuedUserId of queuedIds) clearQueueTimeout(queuedUserId);
        if (queuedGroup.length > 0) {
          matchmaking.removeFromQueue(userId);
          for (const queuedUserId of queuedIds) {
            io.to(`user:${queuedUserId}`).emit("queue:cancelled", { mode: "ranked", reason: "party-invite" });
          }
        }

        let partyId: string | null = null;
        if (!existingParty) {
          partyId = matchmaking.createParty({
            userId,
            username: socket.user!.username,
            socketId: socket.id,
            mmr: 0
          });
          socket.emit("party:updated", { party: matchmaking.getParty(partyId) });
        }
        const activePartyId = partyId ?? matchmaking.getPartyIdForUser(userId);
        if (!activePartyId) throw new Error("Could not create a party");
        io.to(`user:${targetUserId}`).emit("party:invited", {
          from: socket.user!.username,
          partyId: activePartyId,
        });
      } catch (err: any) {
        socket.emit("error", { message: err?.message ?? "Could not invite friend" });
      }
    });

    socket.on("room:invite", async ({ targetUserId, code }: { targetUserId: string; code: string }) => {
      try {
        if (typeof targetUserId !== "string" || !targetUserId.trim() || targetUserId === userId) {
          throw new Error("Choose a valid friend to invite");
        }
        const normalizedCode = typeof code === "string" ? code.trim().toUpperCase() : "";
        if (normalizedCode.length !== 6) throw new Error("Invalid room code");
        const room = matchmaking.getPrivateRoom(normalizedCode);
        if (!room) throw new Error("This private room is no longer available");
        if (!room.some((player) => player.userId === userId)) {
          throw new Error("You must be in the room to invite friends");
        }
        if (room.some((player) => player.userId === targetUserId)) {
          throw new Error("That friend is already in this room");
        }
        if (room.length >= 4) throw new Error("This room is full");
        if (!env.OFFLINE_DEV_MODE) {
          const friendship = await FriendModel.findOne({
            status: "accepted",
            $or: [
              { requesterId: userId, addresseeId: targetUserId },
              { requesterId: targetUserId, addresseeId: userId },
            ],
          });
          if (!friendship) throw new Error("You can only invite accepted friends");
        }
        // The room may have filled or been removed while the friendship query
        // was in flight; never send an invitation to a stale room code.
        const currentRoom = matchmaking.getPrivateRoom(normalizedCode);
        if (!currentRoom || !currentRoom.some((player) => player.userId === userId)) {
          throw new Error("This private room is no longer available");
        }
        if (currentRoom.some((player) => player.userId === targetUserId)) {
          throw new Error("That friend is already in this room");
        }
        if (currentRoom.length >= 4) throw new Error("This room is full");
        io.to(`user:${targetUserId}`).emit("room:invited", {
          from: socket.user!.username,
          code: normalizedCode,
        });
      } catch (err: any) {
        socket.emit("error", { message: err?.message ?? "Could not invite friend to room" });
      }
    });

    socket.on("party:accept", ({ partyId }: { partyId: string }) => {
      try {
        const invitedParty = matchmaking.getParty(partyId);
        if (!invitedParty) throw new Error("Party not found");
        const currentPartyId = matchmaking.getPartyIdForUser(userId);
        if (currentPartyId && currentPartyId !== partyId) {
          throw new Error("Leave your current party before joining another one");
        }
        if (currentPartyId !== partyId && invitedParty.length >= 2) {
          throw new Error("Party is full");
        }

        // A player may have started a fresh solo search while their invite
        // was pending. Cancel stale queues for both the invitee and the host
        // before the party becomes a duo, so they can't be matched separately.
        if (currentPartyId !== partyId) {
          const queueMembers = new Map<string, QueuePlayer>();
          const partyMemberIds = new Set<string>([
            userId,
            ...invitedParty.map((member) => member.userId),
          ]);
          for (const memberId of partyMemberIds) {
            const queuedGroup = matchmaking.getRankedQueueGroupForUser(memberId) ?? [];
            for (const queuedPlayer of queuedGroup) {
              queueMembers.set(queuedPlayer.userId, queuedPlayer);
            }
          }
          for (const queuedUserId of queueMembers.keys()) {
            clearQueueTimeout(queuedUserId);
            matchmaking.removeFromQueue(queuedUserId);
          }
          for (const queuedUserId of queueMembers.keys()) {
            io.to(`user:${queuedUserId}`).emit("queue:cancelled", {
              mode: "ranked",
              reason: "party-joined",
            });
          }
        }
        const party = matchmaking.joinParty(partyId, {
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

        // Validate and reserve the room seat before cancelling an active queue.
        // An invalid/full room code must not silently cancel ranked matchmaking.
        const group = matchmaking.joinPrivateRoom(code, {
          userId,
          username: socket.user!.username,
          socketId: socket.id,
          mmr: 0,
        });

        const queuedGroup = matchmaking.getRankedQueueGroupForUser(userId) ?? [];
        const queuedIds = new Set<string>([userId, ...queuedGroup.map((player) => player.userId)]);
        for (const queuedUserId of queuedIds) clearQueueTimeout(queuedUserId);
        if (queuedGroup.length > 0) {
          matchmaking.removeFromQueue(userId);
          for (const queuedUserId of queuedIds) {
            if (queuedUserId !== userId) {
              io.to(`user:${queuedUserId}`).emit("queue:cancelled", { mode: "ranked", reason: "private-room" });
            }
          }
        }

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

    socket.on("room:leave", () => {
      const changedRooms = matchmaking.removeFromPrivateRooms(userId);
      for (const changedRoom of changedRooms) {
        broadcastPrivateRoom(io, changedRoom.code, changedRoom.players);
      }
      socket.emit("room:left", {});
    });

    socket.on("room:startWithBots", (data?: { code?: string }) => {
      try {
        const code = typeof data?.code === "string" ? data.code.trim().toUpperCase() : "";
        if (!code) throw new Error("Create or join a room first");
        const group = matchmaking.startRoomWithBots(code, "hard", userId);
        if (group) startMatch(io, matchmaking.toSeats(group), "private");
      } catch (err: any) {
        socket.emit("error", { message: err?.message ?? "Could not start room" });
      }
    });

    socket.on("bot:offline", (data?: any) => {
      const difficulty: "easy" | "medium" | "hard" = (data && data.difficulty) ? data.difficulty : "medium";
      console.log(`[SOCKET] bot:offline received for user ${userId}, difficulty: ${difficulty}`);
      // If user is already in a match, clean it up first
      const existing = matchStore.findByUser(userId);
      if (existing) matchStore.delete(existing.id);

      const seats: PlayerSeat[] = [
        { seat: 0, userId, username: socket.user!.username, connected: true, isBot: false },
        { seat: 1, userId: "bot-1", username: "Vector", connected: true, isBot: true, botDifficulty: difficulty },
        { seat: 2, userId: "bot-2", username: "Nova", connected: true, isBot: true, botDifficulty: difficulty },
        { seat: 3, userId: "bot-3", username: "Cipher", connected: true, isBot: true, botDifficulty: difficulty }
      ];
      startMatch(io, seats, "offline");
    });

    socket.on("match:leave", async () => {
      matchmaking.removeFromQueue(userId);
      const state = matchStore.findByUser(userId);
      if (state) {
        // Leaving an offline match should end that local table entirely instead
        // of quietly handing the player seat to a bot.
        if (state.mode === "offline") {
          socket.leave("match:" + state.id);
          io.to("match:" + state.id).emit("match:abandoned", { userLeft: userId, ended: true });
          matchStore.delete(state.id);
          console.log("[GAME] Offline match " + state.id + " ended because " + userId + " left");
          return;
        }
        if (state.mode === "ranked" && state.phase !== "complete") {
          // Penalize quitting player
          const result = await applyRankedResult(userId, currentSeason(), 0, false);
          socket.emit("rank:updated", result);
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
        if (state.phase === "playing" && state.currentTurnSeat === player?.seat) {
          maybeBotTurn(io, state.id);
        }
      }
    });

    socket.on("power:select", ({ matchId, suit }: { matchId: string; suit: Suit }) => {
      try {
        const state = requireMatch(matchId);
        const seat = seatForUser(state.players, userId);
        selectPowerSuit(state, seat, suit);
        dealRemainingCards(state);
        state.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
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

    socket.on("card:play", ({ matchId, cardId }: { matchId: string; cardId: string }) => {
      try {
        const state = requireMatch(matchId);
        const seat = seatForUser(state.players, userId);
        const result = playCard(state, seat, cardId);
        
        // Always refresh deadline after any card play so clients show an accurate timer
        state.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
        
        matchStore.set(state);
        broadcastState(io, state.id);
        void persistIfComplete(io, state);
        
        if (result.trickCompleted && !result.matchCompleted) {
          setTimeout(() => {
            const fresh = matchStore.get(matchId);
            if (fresh && fresh.phase === "trick-resolving") {
              startNextTrick(fresh);
              fresh.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
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

    socket.on("spectate:join", ({ matchId }: { matchId: string }) => {
      const state = requireMatch(matchId);
      socket.join(`match:${matchId}:spectators`);
      socket.emit("match:spectatorState", publicStateForSeat(state));
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
    socket.on("emote:send", ({ matchId, emote }: { matchId: string; emote: string }) => {
      const now = Date.now();
      const last = lastEmoteTime.get(userId) ?? 0;
      if (now - last < 3000) return; // Rate limit: 1 emote per 3 seconds
      lastEmoteTime.set(userId, now);
      
      const validEmotes = ["nice", "gg", "oops", "wow", "hurry", "angry"];
      if (!validEmotes.includes(emote)) return;
      
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
      onlineUsers.delete(userId);
      matchmaking.removeFromQueue(userId);
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
        io.to(`match:${freshState.id}`).emit("match:playerBotReplaced", { userId, username: freshPlayer.username });
        broadcastState(io, freshState.id);
        
        if (freshState.phase === "playing" && freshState.currentTurnSeat === freshPlayer.seat) {
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
  const state = dealFirstFive(createMatch(players, mode));
  state.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
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
    io.to(`user:${player.userId}`).emit("match:state", publicStateForSeat(state, player.seat));
  }
  io.to(`match:${matchId}:spectators`).emit("match:spectatorState", publicStateForSeat(state));
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
  io.to(`match:${state.id}:spectators`).emit("match:spectatorState", publicStateForSeat(state));
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
    stateAfterDeal.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
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
  const player = state.players[state.currentTurnSeat];
  if (!player?.isBot) return;
  setTimeout(() => {
    const fresh = matchStore.get(matchId);
    if (!fresh || fresh.phase !== "playing") return;
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
          freshAfterTrick.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
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
  if (state.mode === "offline") return;
  
  const rankResults: Record<string, any> = {};

  // Apply ranked MMR updates BEFORE cleanup
  if (state.mode === "ranked") {
    const season = currentSeason();
    const humanPlayers = state.players.filter(p => !p.isBot);
    
    // Calculate average MMR of each team for opponent average
    const teamAPlayers = humanPlayers.filter(p => teamForSeat(p.seat) === "A");
    const teamBPlayers = humanPlayers.filter(p => teamForSeat(p.seat) === "B");
    
    for (const player of humanPlayers) {
      const myTeam = teamForSeat(player.seat);
      const won = state.winnerTeam === myTeam;
      // Use 0 as default opponent MMR (simple estimate for Iron III)
      const opponentAvg = 0;
      
      try {
        const result = await applyRankedResult(player.userId, season, opponentAvg, won);
        rankResults[player.userId] = {
          oldMmr: result.oldMmr,
          newMmr: result.newMmr,
          mmrDelta: result.mmrDelta,
          rank: result.rankDetail,
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
  for (const player of state.players.filter(p => !p.isBot)) {
    const myTeam = teamForSeat(player.seat);
    const won = state.winnerTeam === myTeam;
    const teamCaptures = state.captures[myTeam];
    const tensCapturedThisMatch = teamCaptures?.tens?.length ?? 0;
    const acesCapturedThisMatch = teamCaptures?.aces ?? 0;

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

function scheduleTurnTimeout(io: Server, matchId: string, expectedSeat: number, deadline: number, expectedGeneration: number) {
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
      state.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
      
      matchStore.set(state);
      broadcastState(io, matchId);
      void persistIfComplete(io, state);
      
      if (result.trickCompleted && !result.matchCompleted) {
        setTimeout(() => {
          const fresh = matchStore.get(matchId);
          if (fresh && fresh.phase === "trick-resolving") {
            startNextTrick(fresh);
            fresh.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
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
