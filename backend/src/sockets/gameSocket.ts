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

// Track online users for friend status
const onlineUsers = new Set<string>();

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
    socket.join(`user:${userId}`);
    onlineUsers.add(userId);
    reconnectMatch(io, socket);
    broadcastFriendStatus(io, userId, "online");

    socket.on("queue:ranked", ({ mmr = 0 }: { mmr?: number }) => {
      let party = matchmaking.getPartyForUser(userId);
      if (!party) {
        party = [{
          userId,
          username: socket.user!.username,
          socketId: socket.id,
          mmr
        }];
      }
      
      const group = matchmaking.enqueueRanked(party);
      for (const p of party) {
        io.to(`user:${p.userId}`).emit("queue:joined", { mode: "ranked" });
      }
      
      if (group) {
        startMatch(io, matchmaking.toSeats(group), "ranked");
      } else {
        // Fallback: If still in queue after 15 seconds, fill with bots!
        setTimeout(() => {
          console.log(`[RankedQueue] Timeout fired for user ${userId}. InQueue: ${matchmaking.isUserInRankedQueue(userId)}`);
          if (!matchmaking.isUserInRankedQueue(userId)) return;
          
          matchmaking.removeFromQueue(userId);
          const seats: PlayerSeat[] = [];
          
          if (party.length === 2) {
            seats.push({ seat: 0, userId: party[0].userId, username: party[0].username, connected: true, isBot: false });
            seats.push({ seat: 1, userId: party[1].userId, username: party[1].username, connected: true, isBot: false });
            seats.push({ seat: 2, userId: "bot-1", username: "Vector", connected: true, isBot: true, botDifficulty: "hard" });
            seats.push({ seat: 3, userId: "bot-2", username: "Nova", connected: true, isBot: true, botDifficulty: "hard" });
          } else {
            seats.push({ seat: 0, userId, username: socket.user!.username, connected: true, isBot: false });
            seats.push({ seat: 1, userId: "bot-1", username: "Vector", connected: true, isBot: true, botDifficulty: "hard" });
            seats.push({ seat: 2, userId: "bot-2", username: "Nova", connected: true, isBot: true, botDifficulty: "hard" });
            seats.push({ seat: 3, userId: "bot-3", username: "Cipher", connected: true, isBot: true, botDifficulty: "hard" });
          }
          
          startMatch(io, seats, "ranked");
        }, 3000);
      }
    });

    socket.on("party:invite", ({ targetUserId }: { targetUserId: string }) => {
      let existingParty = matchmaking.getPartyForUser(userId);
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
      // Get the partyId from userParty map
      const activePartyId = partyId ?? matchmaking.getPartyIdForUser(userId);
      if (activePartyId) {
        io.to(`user:${targetUserId}`).emit("party:invited", {
          from: socket.user!.username,
          partyId: activePartyId
        });
      }
    });

    socket.on("party:accept", ({ partyId }: { partyId: string }) => {
      try {
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
      const code = matchmaking.createPrivateRoom({
        userId,
        username: socket.user!.username,
        socketId: socket.id,
        mmr: 0
      });
      socket.emit("room:created", { code });
    });

    socket.on("room:join", ({ code }: { code: string }) => {
      try {
        const group = matchmaking.joinPrivateRoom(code.toUpperCase(), {
          userId,
          username: socket.user!.username,
          socketId: socket.id,
          mmr: 0
        });
        socket.emit("room:joined", { code });
        if (group) startMatch(io, matchmaking.toSeats(group), "private");
      } catch (err: any) {
        socket.emit("error", { message: err.message });
      }
    });

    socket.on("room:startWithBots", ({ code }: { code: string }) => {
      try {
        const group = matchmaking.startRoomWithBots(code.toUpperCase(), "hard");
        if (group) startMatch(io, matchmaking.toSeats(group), "private");
      } catch (err: any) {
        socket.emit("error", { message: err.message });
      }
    });

    socket.on("bot:offline", ({ difficulty = "medium" }: { difficulty?: "easy" | "medium" | "hard" }) => {
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
      const state = matchStore.findByUser(userId);
      if (state) {
        if (state.mode === "ranked" && state.phase !== "complete") {
          // Penalize quitting player
          const result = await applyRankedResult(userId, currentSeason(), 0, false);
          socket.emit("rank:updated", result);
        }
        matchStore.delete(state.id);
        socket.leave(`match:${state.id}`);
        io.to(`match:${state.id}`).emit("match:abandoned", { userLeft: userId });
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
          scheduleTurnTimeout(io, state.id, state.currentTurnSeat, state.turnDeadline);
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
        matchStore.set(state);
        broadcastState(io, state.id);
        persistIfComplete(io, state);
        
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
                scheduleTurnTimeout(io, matchId, fresh.currentTurnSeat, fresh.turnDeadline);
              }
            }
          }, 2000);
        } else {
          maybeBotTurn(io, state.id);
          if (state.phase === "playing" && !state.players[state.currentTurnSeat].isBot) {
            scheduleTurnTimeout(io, state.id, state.currentTurnSeat, state.turnDeadline!);
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

    socket.on("disconnect", () => {
      onlineUsers.delete(userId);
      matchmaking.removeFromQueue(userId);
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
      if (player) player.connected = false;
      broadcastState(io, state.id);
    });
  });
}

function startMatch(io: Server, players: PlayerSeat[], mode: MatchMode) {
  const state = dealFirstFive(createMatch(players, mode));
  state.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
  matchStore.set(state);
  for (const player of players) {
    io.to(`user:${player.userId}`).socketsJoin(`match:${state.id}`);
  }
  io.to(`match:${state.id}`).emit("match:created", { matchId: state.id, mode });
  broadcastState(io, state.id);
  maybeBotPowerSelect(io, state.id);
}

function broadcastState(io: Server, matchId: string) {
  const state = requireMatch(matchId);
  for (const player of state.players) {
    io.to(`user:${player.userId}`).emit("match:state", publicStateForSeat(state, player.seat));
  }
  io.to(`match:${matchId}:spectators`).emit("match:spectatorState", publicStateForSeat(state));
}

function reconnectMatch(io: Server, socket: AuthedSocket) {
  const state = matchStore.findByUser(socket.user!.id);
  if (!state) return;
  const player = state.players.find((item) => item.userId === socket.user!.id);
  if (player) player.connected = true;
  socket.join(`match:${state.id}`);
  socket.emit("match:state", publicStateForSeat(state, player?.seat));
  io.to(`match:${state.id}:spectators`).emit("match:spectatorState", publicStateForSeat(state));
}

function maybeBotPowerSelect(io: Server, matchId: string) {
  const state = requireMatch(matchId);
  const first = state.players[state.firstPlayerSeat];
  if (!first?.isBot || state.phase !== "power-select") return;
  setTimeout(() => {
    const fresh = matchStore.get(matchId);
    if (!fresh || fresh.phase !== "power-select") return;
    selectPowerSuit(fresh, fresh.firstPlayerSeat, "spades");
    dealRemainingCards(fresh);
    broadcastState(io, matchId);
    maybeBotTurn(io, matchId);
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
    const card = chooseBotCard(fresh, fresh.currentTurnSeat, bot.botDifficulty ?? "medium");
    const result = playCard(fresh, fresh.currentTurnSeat, card.id);
    matchStore.set(fresh);
    broadcastState(io, matchId);
    persistIfComplete(io, fresh);

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
            scheduleTurnTimeout(io, matchId, freshAfterTrick.currentTurnSeat, freshAfterTrick.turnDeadline);
          }
        }
      }, 2000);
    } else {
      maybeBotTurn(io, matchId);
      if (fresh.phase === "playing" && !fresh.players[fresh.currentTurnSeat].isBot) {
        scheduleTurnTimeout(io, matchId, fresh.currentTurnSeat, fresh.turnDeadline!);
      }
    }
  }, env.BOT_THINK_MS);
}

async function persistIfComplete(io: Server, state: ReturnType<typeof requireMatch>) {
  if (state.phase !== "complete") return;
  if (state.mode === "offline") return;
  
  // Apply ranked MMR updates BEFORE cleanup
  if (state.mode === "ranked") {
    const season = currentSeason();
    const humanPlayers = state.players.filter(p => !p.isBot);
    
    // Calculate average MMR of each team for opponent average
    const teamAPlayers = humanPlayers.filter(p => teamForSeat(p.seat) === "A");
    const teamBPlayers = humanPlayers.filter(p => teamForSeat(p.seat) === "B");
    
    const rankResults: Record<string, any> = {};
    
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
    durationMs: state.startedAt ? Date.now() - state.startedAt : undefined
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

function scheduleTurnTimeout(io: Server, matchId: string, expectedSeat: number, deadline: number) {
  const waitMs = Math.max(0, deadline - Date.now());
  
  setTimeout(() => {
    const state = matchStore.get(matchId);
    if (!state || state.phase !== "playing" || state.currentTurnSeat !== expectedSeat) return;
    
    // Disable auto-play timer for humans in offline (bot) matches
    if (state.mode === "offline") return;

    const player = state.players[expectedSeat];
    if (player.isBot) return;
    
    const legalCards = legalCardsForSeat(state, expectedSeat);
    if (!legalCards || legalCards.length === 0) return;
    
    let cardToPlay = legalCards[0];
    
    try {
      state.turnDeadline = Date.now() + env.TURN_TIMEOUT_MS;
      const result = playCard(state, expectedSeat, cardToPlay.id);
      matchStore.set(state);
      broadcastState(io, matchId);
      persistIfComplete(io, state);
      
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
               scheduleTurnTimeout(io, matchId, fresh.currentTurnSeat, fresh.turnDeadline);
            }
          }
        }, 2000);
      } else {
        maybeBotTurn(io, matchId);
        if (state.phase === "playing" && !state.players[state.currentTurnSeat].isBot) {
           scheduleTurnTimeout(io, matchId, state.currentTurnSeat, state.turnDeadline);
        }
      }
    } catch (err) {
      console.error("Auto-play timeout error", err);
    }
  }, waitMs);
}
