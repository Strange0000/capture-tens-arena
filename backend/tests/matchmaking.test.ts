import { describe, expect, it, vi } from "vitest";
import { MatchmakingService, QueuePlayer, PARTY_INVITE_TTL_MS } from "../src/services/matchmakingService.js";

function player(userId: string): QueuePlayer {
  return {
    userId,
    username: userId.toUpperCase(),
    socketId: `socket-${userId}`,
    mmr: 0,
  };
}

describe("private room lifecycle", () => {
  it("lets up to four different players join a case-insensitive room code", () => {
    const matchmaking = new MatchmakingService();
    const code = matchmaking.createPrivateRoom(player("owner"));

    expect(code).toHaveLength(6);
    expect(matchmaking.joinPrivateRoom(code.toLowerCase(), player("p2"))).toBeUndefined();
    expect(matchmaking.joinPrivateRoom(code, player("p3"))).toBeUndefined();

    const fullRoom = matchmaking.joinPrivateRoom(code, player("p4"));
    expect(fullRoom?.map((member) => member.userId)).toEqual(["owner", "p2", "p3", "p4"]);
    expect(matchmaking.getPrivateRoom(code)).toBeUndefined();
  });

  it("does not let repeated join events occupy extra seats", () => {
    const matchmaking = new MatchmakingService();
    const owner = player("owner");
    const code = matchmaking.createPrivateRoom(owner);

    expect(matchmaking.joinPrivateRoom(code, { ...owner, socketId: "reconnected-socket" })).toBeUndefined();
    const members = matchmaking.getPrivateRoom(code);

    expect(members).toHaveLength(1);
    expect(members?.[0].socketId).toBe("reconnected-socket");
  });

  it("prevents a user from joining two open rooms", () => {
    const matchmaking = new MatchmakingService();
    const firstCode = matchmaking.createPrivateRoom(player("owner"));
    const secondCode = matchmaking.createPrivateRoom(player("other-owner"));

    expect(() => matchmaking.joinPrivateRoom(secondCode, player("owner"))).toThrow(
      `Leave room ${firstCode} before joining another room`,
    );
  });

  it("lets a room member start with bots and then consumes the room", () => {
    const matchmaking = new MatchmakingService();
    const code = matchmaking.createPrivateRoom(player("owner"));
    matchmaking.joinPrivateRoom(code, player("friend"));

    expect(() => matchmaking.startRoomWithBots(code, "hard", "outsider")).toThrow(
      "Only a player in this room can start the match",
    );

    const seats = matchmaking.startRoomWithBots(code, "hard", "friend");
    expect(seats).toHaveLength(4);
    expect(seats.filter((member) => member.isBot)).toHaveLength(2);
    expect(matchmaking.getPrivateRoom(code)).toBeUndefined();
  });

  it("updates the room roster when a player disconnects", () => {
    const matchmaking = new MatchmakingService();
    const code = matchmaking.createPrivateRoom(player("owner"));
    matchmaking.joinPrivateRoom(code, player("friend"));

    const changedRooms = matchmaking.removeFromPrivateRooms("friend");
    expect(changedRooms).toHaveLength(1);
    expect(changedRooms[0].code).toBe(code);
    expect(changedRooms[0].players.map((member) => member.userId)).toEqual(["owner"]);
  });
});

describe("party invites (PR-B F7)", () => {
  it("creates an invite that can be accepted exactly once", () => {
    const matchmaking = new MatchmakingService();
    const partyId = matchmaking.createParty(player("inviter"));

    const invite = matchmaking.createPartyInvite("inviter", "INVITER", "friend", partyId);
    expect(invite.partyId).toBe(partyId);
    expect(invite.expiresAt - Date.now()).toBeLessThanOrEqual(PARTY_INVITE_TTL_MS);

    expect(matchmaking.acceptPartyInvite(partyId, "friend")).toBe(invite);
    // Consumed: a second accept is a stale invite, not a second join.
    expect(() => matchmaking.acceptPartyInvite(partyId, "friend")).toThrow(
      "This party invite has expired or was withdrawn — ask your friend to send a new one",
    );
  });

  it("rejects an invite after its 60s expiry", () => {
    vi.useFakeTimers();
    try {
      const matchmaking = new MatchmakingService();
      const partyId = matchmaking.createParty(player("inviter"));
      matchmaking.createPartyInvite("inviter", "INVITER", "friend", partyId);

      vi.advanceTimersByTime(PARTY_INVITE_TTL_MS + 1000);
      expect(matchmaking.getPartyInvite(partyId, "friend")).toBeUndefined();
      expect(() => matchmaking.acceptPartyInvite(partyId, "friend")).toThrow(
        "This party invite has expired",
      );
    } finally {
      vi.useRealTimers();
    }
  });

  it("declining an invite removes it and returns it for the inviter notice", () => {
    const matchmaking = new MatchmakingService();
    const partyId = matchmaking.createParty(player("inviter"));
    const invite = matchmaking.createPartyInvite("inviter", "INVITER", "friend", partyId);

    expect(matchmaking.declinePartyInvite(partyId, "friend")).toBe(invite);
    expect(matchmaking.getPartyInvite(partyId, "friend")).toBeUndefined();
    // Declining twice is a no-op, not an error.
    expect(matchmaking.declinePartyInvite(partyId, "friend")).toBeNull();
  });

  it("does not let a player sit in two parties at once", () => {
    const matchmaking = new MatchmakingService();
    const firstParty = matchmaking.createParty(player("one"));
    const secondParty = matchmaking.createParty(player("two"));
    matchmaking.joinParty(firstParty, player("member"));

    expect(() => matchmaking.joinParty(secondParty, player("member"))).toThrow(
      "You are already in a party — leave it first",
    );
  });

  it("re-accepting the party you are already in is a no-op", () => {
    const matchmaking = new MatchmakingService();
    const partyId = matchmaking.createParty(player("owner"));
    const party = matchmaking.joinParty(partyId, player("member"));

    expect(matchmaking.joinParty(partyId, player("member"))).toBe(party);
    expect(party).toHaveLength(2);
  });

  it("kills outstanding invites when the inviter leaves the party", () => {
    const matchmaking = new MatchmakingService();
    const partyId = matchmaking.createParty(player("inviter"));
    matchmaking.createPartyInvite("inviter", "INVITER", "friend", partyId);

    matchmaking.leaveParty("inviter");
    expect(matchmaking.getPartyInvite(partyId, "friend")).toBeUndefined();
  });
});
describe("ranked queue cancellation", () => {
  it("exposes and removes a queued solo player so a fallback cannot start after cancel", () => {
    const matchmaking = new MatchmakingService();
    const queued = player("queued-user");

    matchmaking.enqueueRanked([queued]);
    expect(matchmaking.isUserInRankedQueue(queued.userId)).toBe(true);
    expect(matchmaking.getRankedQueueGroupForUser(queued.userId)?.map((p) => p.userId))
      .toEqual(["queued-user"]);

    matchmaking.removeFromQueue(queued.userId);

    expect(matchmaking.isUserInRankedQueue(queued.userId)).toBe(false);
    expect(matchmaking.getRankedQueueGroupForUser(queued.userId)).toBeUndefined();
  });

  it("cancelling one queued party member removes the entire queued group", () => {
    const matchmaking = new MatchmakingService();
    const duo = [player("party-one"), player("party-two")];

    matchmaking.enqueueRanked(duo);
    expect(matchmaking.getRankedQueueGroupForUser("party-two")?.map((p) => p.userId))
      .toEqual(["party-one", "party-two"]);

    matchmaking.removeFromQueue("party-two");

    expect(matchmaking.isUserInRankedQueue("party-one")).toBe(false);
    expect(matchmaking.isUserInRankedQueue("party-two")).toBe(false);
  });

  it("pairs party members on the same team (Team A = seats 0 & 2)", () => {
    const matchmaking = new MatchmakingService();
    const party1 = [player("leader-1"), player("friend-1")];
    const party2 = [player("leader-2"), player("friend-2")];

    matchmaking.enqueueRanked(party1);
    const matched = matchmaking.enqueueRanked(party2);

    expect(matched).toBeDefined();
    expect(matched?.map((p) => p.userId)).toEqual(["leader-1", "leader-2", "friend-1", "friend-2"]);
    // Seats 0 and 2 are on Team A: leader-1 and friend-1 are teammates!
    // Seats 1 and 3 are on Team B: leader-2 and friend-2 are teammates!
    expect(matched?.[0].userId).toBe("leader-1");
    expect(matched?.[2].userId).toBe("friend-1");
    expect(matched?.[1].userId).toBe("leader-2");
    expect(matched?.[3].userId).toBe("friend-2");
  });

  it("pairs party with two solo players on the same team", () => {
    const matchmaking = new MatchmakingService();
    const party = [player("leader"), player("friend")];
    const solo1 = [player("solo-1")];
    const solo2 = [player("solo-2")];

    matchmaking.enqueueRanked(party);
    matchmaking.enqueueRanked(solo1);
    const matched = matchmaking.enqueueRanked(solo2);

    expect(matched).toBeDefined();
    expect(matched?.[0].userId).toBe("leader");
    expect(matched?.[2].userId).toBe("friend");
    expect(matched?.[1].userId).toBe("solo-1");
    expect(matched?.[3].userId).toBe("solo-2");
  });
});
