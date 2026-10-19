import { nanoid } from "nanoid";
import { PlayerSeat } from "../game/types.js";

export interface QueuePlayer {
  userId: string;
  username: string;
  socketId: string;
  mmr: number;
  isBot?: boolean;
  botDifficulty?: "easy" | "medium" | "hard";
}

export class MatchmakingService {
  private rankedQueue: QueuePlayer[][] = [];
  private rooms = new Map<string, QueuePlayer[]>();
  private parties = new Map<string, QueuePlayer[]>();
  private userParty = new Map<string, string>();

  enqueueRanked(party: QueuePlayer[]): QueuePlayer[] | undefined {
    if (party.length < 1 || party.length > 2) throw new Error("Ranked parties must have one or two players");
    const userIds = party.map((player) => player.userId);
    if (new Set(userIds).size !== userIds.length) throw new Error("A player cannot occupy two ranked seats");
    for (const player of party) {
      const roomCode = this.getPrivateRoomCodeForUser(player.userId);
      if (roomCode) throw new Error(`Leave room ${roomCode} before joining ranked matchmaking`);
      const partyId = this.userParty.get(player.userId);
      if (partyId) {
        const members = this.parties.get(partyId) ?? [];
        if (members.length > 1) {
          const queuedIds = new Set(userIds);
          if (members.some((member) => !queuedIds.has(member.userId)) || userIds.length !== members.length) {
            throw new Error("Queue with your party or leave it first");
          }
        }
      }
    }
    this.rankedQueue = this.rankedQueue.filter(p => !p.some(u => userIds.includes(u.userId)));
    this.rankedQueue.push(party);
    return this.tryMatch();
  }

  private averageMmr(group: QueuePlayer[]): number {
    if (group.length === 0) return 0;
    return group.reduce((sum, player) => {
      const mmr = Number.isFinite(player.mmr) ? Math.max(0, player.mmr) : 0;
      return sum + mmr;
    }, 0) / group.length;
  }

  private removeQueuedGroups(groups: QueuePlayer[][]): void {
    const consumed = new Set(groups);
    this.rankedQueue = this.rankedQueue.filter((group) => !consumed.has(group));
  }

  private tryMatch(): QueuePlayer[] | undefined {
    const twos = this.rankedQueue.filter((group) => group.length === 2);
    const ones = this.rankedQueue.filter((group) => group.length === 1);

    // Keep premade duos together and choose the closest-rated pair of duos.
    if (twos.length >= 2) {
      let best: { first: QueuePlayer[]; second: QueuePlayer[]; gap: number } | undefined;
      for (let i = 0; i < twos.length; i += 1) {
        for (let j = i + 1; j < twos.length; j += 1) {
          const gap = Math.abs(this.averageMmr(twos[i]) - this.averageMmr(twos[j]));
          if (!best || gap < best.gap) best = { first: twos[i], second: twos[j], gap };
        }
      }
      if (best) {
        this.removeQueuedGroups([best.first, best.second]);
        return [best.first[0], best.second[0], best.first[1], best.second[1]];
      }
    }

    // Choose solo opponents whose average rating most closely matches a duo.
    if (twos.length >= 1 && ones.length >= 2) {
      let best: { duo: QueuePlayer[]; first: QueuePlayer[]; second: QueuePlayer[]; gap: number } | undefined;
      for (const duo of twos) {
        for (let i = 0; i < ones.length; i += 1) {
          for (let j = i + 1; j < ones.length; j += 1) {
            const soloAverage = (this.averageMmr(ones[i]) + this.averageMmr(ones[j])) / 2;
            const gap = Math.abs(this.averageMmr(duo) - soloAverage);
            if (!best || gap < best.gap) {
              best = { duo, first: ones[i], second: ones[j], gap };
            }
          }
        }
      }
      if (best) {
        this.removeQueuedGroups([best.duo, best.first, best.second]);
        return [best.duo[0], best.first[0], best.duo[1], best.second[0]];
      }
    }

    // For solo queues, take a close-rated group of four and balance the two teams.
    if (ones.length >= 4) {
      const sorted = [...ones].sort((a, b) => this.averageMmr(a) - this.averageMmr(b));
      let selected = sorted.slice(0, 4);
      let smallestRange = Number.POSITIVE_INFINITY;
      for (let i = 0; i <= sorted.length - 4; i += 1) {
        const window = sorted.slice(i, i + 4);
        const range = this.averageMmr(window[3]) - this.averageMmr(window[0]);
        if (range < smallestRange) {
          selected = window;
          smallestRange = range;
        }
      }

      const players = selected.map((group) => group[0]);
      const [a, b, c, d] = players;
      const partitions: Array<{ teamA: QueuePlayer[]; teamB: QueuePlayer[] }> = [
        { teamA: [a, b], teamB: [c, d] },
        { teamA: [a, c], teamB: [b, d] },
        { teamA: [a, d], teamB: [b, c] },
      ];
      const teamGap = (team: QueuePlayer[]) => {
        const otherTeam = players.filter((player) => !team.includes(player));
        return Math.abs(this.averageMmr(team) - this.averageMmr(otherTeam));
      };
      partitions.sort((left, right) => teamGap(left.teamA) - teamGap(right.teamA));
      const best = partitions[0];
      this.removeQueuedGroups(selected);
      // Teams are seats 0+2 and 1+3.
      return [best.teamA[0], best.teamB[0], best.teamA[1], best.teamB[1]];
    }
    return undefined;
  }

  removeFromQueue(userId: string) {
    this.rankedQueue = this.rankedQueue.filter(p => !p.some(u => u.userId === userId));
  }

  removeFromPrivateRooms(userId: string): Array<{ code: string; players: QueuePlayer[] }> {
    const changedRooms: Array<{ code: string; players: QueuePlayer[] }> = [];
    for (const [code, room] of this.rooms.entries()) {
      const filtered = room.filter((player) => player.userId !== userId);
      if (filtered.length === room.length) continue;
      if (filtered.length === 0) {
        this.rooms.delete(code);
      } else {
        this.rooms.set(code, filtered);
        changedRooms.push({ code, players: [...filtered] });
      }
    }
    return changedRooms;
  }

  getPrivateRoom(code: string): QueuePlayer[] | undefined {
    const room = this.rooms.get(code.trim().toUpperCase());
    return room ? [...room] : undefined;
  }

  isUserInRankedQueue(userId: string): boolean {
    return this.rankedQueue.some(p => p.some(u => u.userId === userId));
  }

  getRankedQueueGroupForUser(userId: string): QueuePlayer[] | undefined {
    const group = this.rankedQueue.find((players) =>
      players.some((player) => player.userId === userId),
    );
    return group ? [...group] : undefined;
  }

  getPrivateRoomCodeForUser(userId: string): string | undefined {
    for (const [code, members] of this.rooms.entries()) {
      if (members.some((member) => member.userId === userId)) return code;
    }
    return undefined;
  }

  leavePrivateRoom(userId: string, code?: string): { code: string; players: QueuePlayer[] } | undefined {
    const normalizedCode = code?.trim().toUpperCase();
    const target = normalizedCode
      ? ([normalizedCode, this.rooms.get(normalizedCode)] as const)
      : [...this.rooms.entries()].find(([, members]) => members.some((member) => member.userId === userId));
    if (!target || !target[1]) return undefined;
    const [roomCode, room] = target;
    if (!room.some((member) => member.userId === userId)) throw new Error("You are not a player in this room");
    const filtered = room.filter((member) => member.userId !== userId);
    if (filtered.length === 0) {
      this.rooms.delete(roomCode);
      return { code: roomCode, players: [] };
    }
    this.rooms.set(roomCode, filtered);
    return { code: roomCode, players: [...filtered] };
  }

  createPrivateRoom(owner: QueuePlayer) {
    if (this.isUserInRankedQueue(owner.userId)) throw new Error("Cancel ranked matchmaking before creating a room");
    if (this.userParty.has(owner.userId)) throw new Error("Leave your party before creating a private room");
    // A player must not silently create multiple active rooms.
    for (const [existingCode, members] of this.rooms.entries()) {
      if (members.some((member) => member.userId === owner.userId)) {
        throw new Error(`You already have an open room: ${existingCode}`);
      }
    }

    // Avoid the (very unlikely) chance of overwriting an active room code.
    let code = nanoid(6).toUpperCase();
    while (this.rooms.has(code)) {
      code = nanoid(6).toUpperCase();
    }
    this.rooms.set(code, [owner]);
    return code;
  }

  joinPrivateRoom(code: string, player: QueuePlayer): QueuePlayer[] | undefined {
    if (this.isUserInRankedQueue(player.userId)) throw new Error("Cancel ranked matchmaking before joining a room");
    if (this.userParty.has(player.userId)) throw new Error("Leave your party before joining a private room");
    const normalizedCode = code.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);
    if (!room) throw new Error("Room not found");

    // Prevent one account occupying several seats through repeated clicks.
    const existingPlayer = room.find((member) => member.userId === player.userId);
    if (existingPlayer) {
      existingPlayer.username = player.username;
      existingPlayer.socketId = player.socketId;
      return undefined;
    }

    // A player already waiting in a different room should leave it first.
    const otherRoom = [...this.rooms.entries()].find(
      ([roomCode, members]) => roomCode !== normalizedCode &&
        members.some((member) => member.userId === player.userId),
    );
    if (otherRoom) throw new Error(`Leave room ${otherRoom[0]} before joining another room`);

    if (room.length >= 4) throw new Error("Room is full");
    room.push(player);

    if (room.length !== 4) return undefined;

    // Consume the room once a four-player match is formed.
    this.rooms.delete(normalizedCode);
    return [...room];
  }

  startRoomWithBots(
    code: string,
    difficulty: "easy" | "medium" | "hard" = "medium",
    requesterUserId?: string,
  ): QueuePlayer[] {
    const normalizedCode = code.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);
    if (!room) throw new Error("Room not found");
    if (requesterUserId && !room.some((player) => player.userId === requesterUserId)) {
      throw new Error("Only a player in this room can start the match");
    }
    const botNames = ["Vector", "Nova", "Cipher"];
    while (room.length < 4) {
      room.push({
        userId: `bot-${nanoid(4)}`,
        username: botNames[room.length - 1] || "Bot",
        socketId: "bot",
        mmr: 0,
        isBot: true,
        botDifficulty: difficulty,
      });
    }
    this.rooms.delete(normalizedCode);
    return [...room];
  }

  createParty(owner: QueuePlayer) {
    if (this.userParty.has(owner.userId)) throw new Error("You are already in a party");
    if (this.isUserInRankedQueue(owner.userId)) throw new Error("Cancel ranked matchmaking before creating a party");
    if (this.getPrivateRoomCodeForUser(owner.userId)) throw new Error("Leave your private room before creating a party");
    const id = nanoid(8);
    this.parties.set(id, [owner]);
    this.userParty.set(owner.userId, id);
    return id;
  }

  joinParty(id: string, player: QueuePlayer): QueuePlayer[] {
    const party = this.parties.get(id);
    if (!party) throw new Error("Party not found");
    const existingPartyId = this.userParty.get(player.userId);
    if (existingPartyId && existingPartyId !== id) throw new Error("Leave your current party first");
    const existingMember = party.find((member) => member.userId === player.userId);
    if (existingMember) {
      existingMember.socketId = player.socketId;
      existingMember.username = player.username;
      return [...party];
    }
    if (this.isUserInRankedQueue(player.userId)) throw new Error("Cancel ranked matchmaking before joining a party");
    if (party.some((member) => this.isUserInRankedQueue(member.userId))) {
      throw new Error("The party is already searching for a ranked match");
    }
    if (this.getPrivateRoomCodeForUser(player.userId)) throw new Error("Leave your private room before joining a party");
    if (party.length >= 2) throw new Error("Party is full");
    party.push(player);
    this.userParty.set(player.userId, id);
    return [...party];
  }

  leaveParty(userId: string) {
    const partyId = this.userParty.get(userId);
    this.removeFromQueue(userId);
    if (!partyId) return null;
    let party = this.parties.get(partyId);
    if (party) {
      party = party.filter(p => p.userId !== userId);
      if (party.length === 0) {
        this.parties.delete(partyId);
      } else {
        this.parties.set(partyId, party);
      }
    }
    this.userParty.delete(userId);
    return partyId;
  }

  getParty(id: string) {
    return this.parties.get(id);
  }

  getPartyForUser(userId: string) {
    const partyId = this.userParty.get(userId);
    return partyId ? this.parties.get(partyId) : undefined;
  }

  getPartyIdForUser(userId: string) {
    return this.userParty.get(userId) ?? null;
  }

  toSeats(players: QueuePlayer[]): PlayerSeat[] {
    return players.map((player, seat) => ({
      seat,
      userId: player.userId,
      username: player.username,
      socketId: player.socketId,
      connected: true,
      isBot: !!(player as any).isBot,
      botDifficulty: (player as any).botDifficulty
    }));
  }
}

export const matchmaking = new MatchmakingService();
