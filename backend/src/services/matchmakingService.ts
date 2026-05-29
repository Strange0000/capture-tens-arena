import { nanoid } from "nanoid";
import { PlayerSeat } from "../game/types.js";

export interface QueuePlayer {
  userId: string;
  username: string;
  socketId: string;
  mmr: number;
}

export class MatchmakingService {
  private rankedQueue: QueuePlayer[][] = [];
  private rooms = new Map<string, QueuePlayer[]>();
  private parties = new Map<string, QueuePlayer[]>();
  private userParty = new Map<string, string>();

  enqueueRanked(party: QueuePlayer[]): QueuePlayer[] | undefined {
    if (party.length > 2) throw new Error("Ranked parties max 2 players");
    const userIds = party.map(p => p.userId);
    this.rankedQueue = this.rankedQueue.filter(p => !p.some(u => userIds.includes(u.userId)));
    this.rankedQueue.push(party);
    return this.tryMatch();
  }

  private tryMatch(): QueuePlayer[] | undefined {
    const twos = this.rankedQueue.filter(p => p.length === 2);
    const ones = this.rankedQueue.filter(p => p.length === 1);
    
    if (twos.length >= 2) {
      const matchTwos = [twos[0], twos[1]];
      this.rankedQueue = this.rankedQueue.filter(p => p !== matchTwos[0] && p !== matchTwos[1]);
      return [matchTwos[0][0], matchTwos[1][0], matchTwos[0][1], matchTwos[1][1]];
    }
    
    if (twos.length >= 1 && ones.length >= 2) {
      const matchTwo = twos[0];
      const matchOnes = [ones[0], ones[1]];
      this.rankedQueue = this.rankedQueue.filter(p => p !== matchTwo && p !== matchOnes[0] && p !== matchOnes[1]);
      return [matchTwo[0], matchOnes[0][0], matchTwo[1], matchOnes[1][0]];
    }
    
    if (ones.length >= 4) {
      const matchOnes = [ones[0], ones[1], ones[2], ones[3]];
      this.rankedQueue = this.rankedQueue.filter(p => !matchOnes.includes(p));
      return [matchOnes[0][0], matchOnes[1][0], matchOnes[2][0], matchOnes[3][0]];
    }
    return undefined;
  }

  removeFromQueue(userId: string) {
    this.rankedQueue = this.rankedQueue.filter(p => !p.some(u => u.userId === userId));
    for (const [code, room] of this.rooms.entries()) {
      const filtered = room.filter(u => u.userId !== userId);
      if (filtered.length === 0) {
        this.rooms.delete(code);
      } else {
        this.rooms.set(code, filtered);
      }
    }
  }

  isUserInRankedQueue(userId: string): boolean {
    return this.rankedQueue.some(p => p.some(u => u.userId === userId));
  }

  createPrivateRoom(owner: QueuePlayer) {
    const code = nanoid(6).toUpperCase();
    this.rooms.set(code, [owner]);
    return code;
  }

  joinPrivateRoom(code: string, player: QueuePlayer): QueuePlayer[] | undefined {
    const room = this.rooms.get(code);
    if (!room) throw new Error("Room not found");
    if (room.length >= 4) throw new Error("Room is full");
    room.push(player);
    return room.length === 4 ? room : undefined;
  }

  createParty(owner: QueuePlayer) {
    const id = nanoid(8);
    this.parties.set(id, [owner]);
    this.userParty.set(owner.userId, id);
    return id;
  }

  joinParty(id: string, player: QueuePlayer): QueuePlayer[] {
    const party = this.parties.get(id);
    if (!party) throw new Error("Party not found");
    if (party.length >= 2) throw new Error("Party is full");
    party.push(player);
    this.userParty.set(player.userId, id);
    return party;
  }

  leaveParty(userId: string) {
    const partyId = this.userParty.get(userId);
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
      connected: true,
      isBot: false
    }));
  }
}

export const matchmaking = new MatchmakingService();
