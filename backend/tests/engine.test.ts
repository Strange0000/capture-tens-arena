import { describe, expect, it } from "vitest";
import { createMatch, dealFirstFive, dealRemainingCards, playCard, selectPowerSuit } from "../src/game/engine.js";

const players = [0, 1, 2, 3].map((seat) => ({
  seat,
  userId: `u${seat}`,
  username: `P${seat}`,
  connected: true,
  isBot: false
}));

describe("engine lifecycle", () => {
  it("deals in required phases", () => {
    const state = dealFirstFive(createMatch(players, "casual", 42));
    expect(Object.values(state.hands).map((hand) => hand.length)).toEqual([5, 5, 5, 5]);
    selectPowerSuit(state, state.firstPlayerSeat, "spades");
    dealRemainingCards(state);
    expect(Object.values(state.hands).map((hand) => hand.length)).toEqual([13, 13, 13, 13]);
    expect(state.phase).toBe("playing");
  });

  it("plays a legal opening card", () => {
    const state = dealFirstFive(createMatch(players, "casual", 99));
    selectPowerSuit(state, state.firstPlayerSeat, "clubs");
    dealRemainingCards(state);
    const legal = state.hands[state.firstPlayerSeat].find((card) => card.rank !== "10" && card.suit !== "clubs")!;
    const result = playCard(state, state.firstPlayerSeat, legal.id);
    expect(result.state.currentTrick?.plays).toHaveLength(1);
    expect(result.state.hands[state.firstPlayerSeat]).toHaveLength(12);
  });
});
