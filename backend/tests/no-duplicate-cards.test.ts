import { describe, expect, it } from "vitest";
import { chooseBotCard } from "../src/game/bot.js";
import {
  createMatch,
  dealFirstFive,
  dealRemainingCards,
  playCard,
  publicStateForSeat,
  selectPowerSuit,
  startNextTrick,
} from "../src/game/engine.js";
import type { MatchState, PlayerSeat } from "../src/game/types.js";

// Round 8 regression test — a Round 7 live test reported a "duplicate
// 2♣": a 2♣ on the table while the tester still held a 2♣, then
// another 2♣ played later. The engine was traced and simulated (300
// full bot games, 15,600 plays — see the Round 8 report): the deck
// is a single 52-card set, every card is dealt exactly once, and
// playCard removes the card from the hand. No duplicate is possible
// at the state level; the sightings were a rendering issue (the trick
// cluster clipped the top/bottom cards' corner pips — fixed in
// trick_area.dart). This test pins the invariant so a real duplicate
// can never regress silently: at every step of a full game, the
// cards across hands + deck + current trick + completed tricks are
// exactly the 52 unique cards, captures equal the completed tricks,
// and no seat's public state ever shows the same card in both its
// hand and the current trick.

const players: PlayerSeat[] = [0, 1, 2, 3].map((seat) => ({
  seat,
  userId: seat === 0 ? "human" : `bot-${seat}`,
  username: ["You", "Vector", "Nova", "Cipher"][seat],
  connected: true,
  isBot: seat !== 0,
  botDifficulty: "hard" as const,
}));

const all52 = new Set<string>(
  ["hearts", "diamonds", "clubs", "spades"].flatMap((suit) =>
    ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"].map(
      (rank) => `${rank}-${suit}`,
    ),
  ),
);

function assertNoDuplicates(state: MatchState, where: string) {
  const ids: string[] = [];
  for (const hand of Object.values(state.hands)) {
    for (const card of hand) ids.push(card.id);
  }
  for (const card of state.deck) ids.push(card.id);
  // During trick-resolving, currentTrick IS completedTricks.last (the
  // same object) — count its cards once.
  const lastCompleted =
    state.completedTricks[state.completedTricks.length - 1];
  if (state.currentTrick && state.currentTrick !== lastCompleted) {
    for (const play of state.currentTrick.plays) ids.push(play.card.id);
  }
  for (const trick of state.completedTricks) {
    for (const play of trick.plays) ids.push(play.card.id);
  }
  expect(ids, where).toHaveLength(52);
  expect(new Set(ids), where).toEqual(all52);

  // Captures are a copy of the completed tricks' cards — same set.
  const captured = [
    ...state.captures.A.cards,
    ...state.captures.B.cards,
  ].map((card) => card.id);
  const completed = state.completedTricks.flatMap((trick) =>
    trick.plays.map((play) => play.card.id),
  );
  expect([...captured].sort(), where).toEqual([...completed].sort());

  // No seat's public state may show a card in both hand and trick.
  for (let seat = 0; seat < 4; seat += 1) {
    const pub = publicStateForSeat(state, seat);
    const handIds = new Set(pub.hand.map((card) => card.id));
    const trickIds = (pub.currentTrick?.plays ?? []).map(
      (play) => play.card.id,
    );
    expect(
      trickIds.filter((id) => handIds.has(id)),
      `${where} (seat ${seat})`,
    ).toEqual([]);
  }
}

function playFullBotGame(seed: number) {
  let state = createMatch(players, "offline", seed);
  assertNoDuplicates(state, "created");
  state = dealFirstFive(state);
  assertNoDuplicates(state, "deal-five");

  const firstHand = state.hands[state.firstPlayerSeat];
  const counts: Record<string, number> = {};
  for (const card of firstHand) {
    counts[card.suit] = (counts[card.suit] ?? 0) + 1;
  }
  const bestSuit = (Object.entries(counts).sort(
    (a, b) => b[1] - a[1],
  )[0]?.[0] ?? "spades") as "hearts" | "diamonds" | "clubs" | "spades";
  state = dealRemainingCards(
    selectPowerSuit(state, state.firstPlayerSeat, bestSuit),
  );
  assertNoDuplicates(state, "dealt");

  let guard = 0;
  while (state.phase !== "complete" && guard < 200) {
    guard += 1;
    if (state.phase === "trick-resolving") {
      state = startNextTrick(state);
      assertNoDuplicates(state, "next-trick");
      continue;
    }
    expect(state.phase).toBe("playing");
    const seat = state.currentTurnSeat;
    const card = chooseBotCard(state, seat, "hard");
    const result = playCard(state, seat, card.id);
    state = result.state;
    assertNoDuplicates(state, `after seat ${seat} played ${card.id}`);
    for (let s = 0; s < 4; s += 1) {
      expect(
        state.hands[s].some((item) => item.id === card.id),
        `played card ${card.id} still in seat ${s} hand`,
      ).toBe(false);
    }
  }
  expect(state.phase).toBe("complete");
  assertNoDuplicates(state, "complete");
  expect(
    state.captures.A.cards.length + state.captures.B.cards.length,
  ).toBe(52);
}

describe("no duplicate cards", () => {
  it("plays 25 full bot games without any card ever appearing twice", () => {
    for (let g = 0; g < 25; g += 1) {
      playFullBotGame(1000 + g);
    }
  });
});
