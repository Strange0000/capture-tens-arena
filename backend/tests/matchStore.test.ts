import { describe, expect, it } from "vitest";
import { createMatch } from "../src/game/engine.js";
import { MatchStore } from "../src/services/matchStore.js";

function makeMatch(userIds: string[]) {
  return createMatch(
    userIds.map((userId, seat) => ({
      seat,
      userId,
      username: userId,
      connected: true,
      isBot: false,
    })),
    "offline",
    42,
  );
}

describe("MatchStore player lifecycle", () => {
  it("stops reconnecting a player after their seat is replaced by a bot", () => {
    const store = new MatchStore();
    const match = makeMatch(["leaver", "p1", "p2", "p3"]);
    store.set(match);

    expect(store.findByUser("leaver")?.id).toBe(match.id);

    match.players[0].isBot = true;
    store.set(match);

    expect(store.findByUser("leaver")).toBeUndefined();
    expect(store.findByUser("p1")?.id).toBe(match.id);
  });

  it("does not clear a player's newer match mapping when an older match is deleted", () => {
    const store = new MatchStore();
    const oldMatch = makeMatch(["same-user", "old-1", "old-2", "old-3"]);
    const newMatch = makeMatch(["same-user", "new-1", "new-2", "new-3"]);

    store.set(oldMatch);
    store.set(newMatch);
    store.delete(oldMatch.id);

    expect(store.findByUser("same-user")?.id).toBe(newMatch.id);
  });

  it("clears all current mappings when a match is deleted", () => {
    const store = new MatchStore();
    const match = makeMatch(["p0", "p1", "p2", "p3"]);
    store.set(match);

    store.delete(match.id);

    for (const userId of ["p0", "p1", "p2", "p3"]) {
      expect(store.findByUser(userId)).toBeUndefined();
    }
  });
});
