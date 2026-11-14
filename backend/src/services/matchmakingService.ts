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

/** How long a party invite stays valid before the receiver must ask
 * for a fresh one. PR-B (F7): invites previously lived forever with
 * no acknowledgement and no way to decline. */
export const PARTY_INVITE_TTL_MS = 60_000;

export interface PartyInvite {
  partyId: string;
  fromUserId: string;
  fromUsername: string;
  targetUserId: string;
  expiresAt: number;
}

export class MatchmakingService {
  private rankedQueue: QueuePlayer[][] = [];
  private rooms = new Map<string, QueuePlayer[]>();
  private parties = new Map<string, QueuePlayer[]>();
  private userParty = new Map<string, string>();
  private pendingInvites = new Map<string, PartyInvite>();

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

  createPrivateRoom(owner: QueuePlayer) {
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
    const id = nanoid(8);
    this.parties.set(id, [owner]);
    this.userParty.set(owner.userId, id);
    return id;
  }

  joinParty(id: string, player: QueuePlayer): QueuePlayer[] {
    const party = this.parties.get(id);
    if (!party) throw new Error("Party not found");
    // A player already in a different party must leave it first —
    // without this they would sit in two parties at once and the
    // ranked queue would seat them twice.
    const existingPartyId = this.userParty.get(player.userId);
    if (existingPartyId && existingPartyId !== id) {
      throw new Error("You are already in a party — leave it first");
    }
    if (existingPartyId === id) return party;
    if (party.length >= 2) throw new Error("Party is full");
    party.push(player);
    this.userParty.set(player.userId, id);
    return party;
  }

  // ── Party invites (PR-B F7) ──────────────────────────────────────────
  // An invite is a short-lived record, not a bare socket event: the
  // receiver can accept, decline, or let it expire, and the inviter
  // gets an acknowledgement either way. Expired invites are swept
  // lazily — accept/decline/create all drop them first — so no timer
  // is needed and a stale invite can never be accepted late.

  createPartyInvite(
    fromUserId: string,
    fromUsername: string,
    targetUserId: string,
    partyId: string,
  ): PartyInvite {
    this.sweepExpiredInvites();
    const invite: PartyInvite = {
      partyId,
      fromUserId,
      fromUsername,
      targetUserId,
      expiresAt: Date.now() + PARTY_INVITE_TTL_MS,
    };
    this.pendingInvites.set(`${partyId}:${targetUserId}`, invite);
    return invite;
  }

  getPartyInvite(partyId: string, targetUserId: string): PartyInvite | undefined {
    const invite = this.pendingInvites.get(`${partyId}:${targetUserId}`);
    if (!invite) return undefined;
    if (invite.expiresAt <= Date.now()) {
      this.pendingInvites.delete(`${partyId}:${targetUserId}`);
      return undefined;
    }
    return invite;
  }

  /** Consumes the invite. Throws with a plain-words reason when there
   * is no live invite for this player and party. */
  acceptPartyInvite(partyId: string, targetUserId: string): PartyInvite {
    const invite = this.getPartyInvite(partyId, targetUserId);
    if (!invite) {
      throw new Error("This party invite has expired or was withdrawn — ask your friend to send a new one");
    }
    this.pendingInvites.delete(`${partyId}:${targetUserId}`);
    return invite;
  }

  /** Consumes the invite if one is live; returns it so the inviter can
   * be told, or null when there was nothing to decline (already
   * accepted, expired, or never sent — declining is still a no-op). */
  declinePartyInvite(partyId: string, targetUserId: string): PartyInvite | null {
    const key = `${partyId}:${targetUserId}`;
    const invite = this.pendingInvites.get(key) ?? null;
    if (invite) this.pendingInvites.delete(key);
    return invite;
  }

  /** Outstanding invites die when either side leaves: an invite from a
   * player who is no longer in a party, or to a player who left, must
   * never be accepted afterwards. */
  clearInvitesForUser(userId: string) {
    for (const [key, invite] of this.pendingInvites) {
      if (invite.fromUserId === userId || invite.targetUserId === userId) {
        this.pendingInvites.delete(key);
      }
    }
  }

  clearInvitesForParty(partyId: string) {
    for (const [key, invite] of this.pendingInvites) {
      if (invite.partyId === partyId) this.pendingInvites.delete(key);
    }
  }

  private sweepExpiredInvites() {
    const now = Date.now();
    for (const [key, invite] of this.pendingInvites) {
      if (invite.expiresAt <= now) this.pendingInvites.delete(key);
    }
  }

  leaveParty(userId: string) {
    const partyId = this.userParty.get(userId);
    if (!partyId) return null;
    // The party changed, so its outstanding invites are dead — a
    // receiver must never accept an invite into a party that has
    // already lost a member.
    this.clearInvitesForParty(partyId);
    this.clearInvitesForUser(userId);
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
