import { describe, expect, it } from "vitest";
import { MatchmakingService, QueuePlayer } from "../src/services/matchmakingService.js";

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

describe("ranked party lifecycle", () => {
  it("prevents the same player from creating two parties", () => {
    const matchmaking = new MatchmakingService();
    matchmaking.createParty(player("one"));

    expect(() => matchmaking.createParty(player("one"))).toThrow(
      "Leave your current party before creating another one",
    );
  });

  it("makes repeated acceptance idempotent and refreshes the member socket", () => {
    const matchmaking = new MatchmakingService();
    const partyId = matchmaking.createParty(player("one"));
    matchmaking.joinParty(partyId, player("two"));

    const updated = matchmaking.joinParty(partyId, { ...player("two"), socketId: "reconnected-socket" });

    expect(updated).toHaveLength(2);
    expect(updated[1].socketId).toBe("reconnected-socket");
    expect(matchmaking.getPartyForUser("two")).toHaveLength(2);
  });

  it("rejects joining a second party and inviting a third member to a full party", () => {
    const matchmaking = new MatchmakingService();
    const firstParty = matchmaking.createParty(player("one"));
    matchmaking.joinParty(firstParty, player("two"));
    const otherParty = matchmaking.createParty(player("three"));

    expect(() => matchmaking.joinParty(otherParty, player("two"))).toThrow(
      "Leave your current party before joining another one",
    );
    expect(() => matchmaking.joinParty(firstParty, player("four"))).toThrow("Party is full");
    expect(matchmaking.getParty(firstParty)).toHaveLength(2);
  });

  it("removes the membership mapping when a party member leaves", () => {
    const matchmaking = new MatchmakingService();
    const partyId = matchmaking.createParty(player("one"));
    matchmaking.joinParty(partyId, player("two"));

    matchmaking.leaveParty("two");

    expect(matchmaking.getPartyForUser("two")).toBeUndefined();
    expect(matchmaking.getParty(partyId)?.map((member) => member.userId)).toEqual(["one"]);
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
});
