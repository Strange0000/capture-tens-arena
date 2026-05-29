import { describe, expect, it } from "vitest";
import { legalCardsForSeat, determineTrickWinner } from "../src/game/rules.js";
import { MatchState } from "../src/game/types.js";

function baseState(): MatchState {
  return {
    id: "test",
    phase: "playing",
    players: [],
    hands: {
      0: [
        { id: "10-spades", rank: "10", suit: "spades" },
        { id: "7-hearts", rank: "7", suit: "hearts" },
        { id: "3-clubs", rank: "3", suit: "clubs" }
      ],
      1: [],
      2: [],
      3: []
    },
    deck: [],
    powerSuit: "spades",
    dealerSeat: 3,
    firstPlayerSeat: 0,
    currentTurnSeat: 0,
    currentTrick: { index: 0, leaderSeat: 0, plays: [] },
    completedTricks: [],
    captures: { A: { tens: [], cards: [], aces: [] }, B: { tens: [], cards: [], aces: [] } },
    updatedAt: Date.now(),
    replayEvents: []
  };
}

describe("Capture Tens rules", () => {
  it("blocks power suit and tens on first trick when alternatives exist", () => {
    const legal = legalCardsForSeat(baseState(), 0).map((card) => card.id);
    expect(legal).toEqual(["7-hearts", "3-clubs"]);
  });

  it("allows restricted cards on first trick when no alternative exists", () => {
    const state = baseState();
    state.hands[0] = [
      { id: "10-spades", rank: "10", suit: "spades" },
      { id: "A-spades", rank: "A", suit: "spades" }
    ];
    expect(legalCardsForSeat(state, 0).map((card) => card.id)).toEqual(["10-spades", "A-spades"]);
  });

  it("lets highest power suit win over lead suit", () => {
    const winner = determineTrickWinner(
      {
        index: 3,
        leaderSeat: 1,
        plays: [
          { seat: 1, card: { id: "A-hearts", rank: "A", suit: "hearts" }, playedAt: 1 },
          { seat: 2, card: { id: "2-spades", rank: "2", suit: "spades" }, playedAt: 2 },
          { seat: 3, card: { id: "K-hearts", rank: "K", suit: "hearts" }, playedAt: 3 },
          { seat: 0, card: { id: "9-spades", rank: "9", suit: "spades" }, playedAt: 4 }
        ]
      },
      "spades"
    );
    expect(winner).toBe(0);
  });
});

describe("Must play higher rule", () => {
  it("forces player to play higher card when opponent is winning", () => {
    const state = baseState();
    state.completedTricks = [{ index: 0, leaderSeat: 0, plays: [], winnerSeat: 0 }]; // past first trick
    state.currentTrick = {
      index: 1,
      leaderSeat: 1,
      plays: [
        // Seat 1 (Team B) led with 7 of hearts
        { seat: 1, card: { id: "7-hearts", rank: "7", suit: "hearts" }, playedAt: 1 }
      ]
    };
    state.currentTurnSeat = 2; // Seat 2 (Team A) must play higher
    state.hands[2] = [
      { id: "3-hearts", rank: "3", suit: "hearts" },
      { id: "K-hearts", rank: "K", suit: "hearts" },
      { id: "5-clubs", rank: "5", suit: "clubs" }
    ];

    const legal = legalCardsForSeat(state, 2).map((c) => c.id);
    // Must play K-hearts (only card that beats 7), 3-hearts is NOT allowed
    expect(legal).toEqual(["K-hearts"]);
  });

  it("allows playing low when teammate is winning", () => {
    const state = baseState();
    state.completedTricks = [{ index: 0, leaderSeat: 0, plays: [], winnerSeat: 0 }];
    state.currentTrick = {
      index: 1,
      leaderSeat: 0,
      plays: [
        // Seat 0 (Team A) led with K of hearts
        { seat: 0, card: { id: "K-hearts", rank: "K", suit: "hearts" }, playedAt: 1 },
        // Seat 1 (Team B) played 3 of hearts
        { seat: 1, card: { id: "3-hearts", rank: "3", suit: "hearts" }, playedAt: 2 }
      ]
    };
    state.currentTurnSeat = 2; // Seat 2 (Team A — same team as seat 0 who is winning)
    state.hands[2] = [
      { id: "2-hearts", rank: "2", suit: "hearts" },
      { id: "A-hearts", rank: "A", suit: "hearts" },
      { id: "5-clubs", rank: "5", suit: "clubs" }
    ];

    const legal = legalCardsForSeat(state, 2).map((c) => c.id);
    // Teammate is winning — can play ANY hearts card (throw low is fine)
    expect(legal).toEqual(["2-hearts", "A-hearts"]);
  });

  it("allows any lead-suit card when no card can beat current highest", () => {
    const state = baseState();
    state.completedTricks = [{ index: 0, leaderSeat: 0, plays: [], winnerSeat: 0 }];
    state.currentTrick = {
      index: 1,
      leaderSeat: 1,
      plays: [
        // Seat 1 (Team B) led with A of hearts — can't beat an ace
        { seat: 1, card: { id: "A-hearts", rank: "A", suit: "hearts" }, playedAt: 1 }
      ]
    };
    state.currentTurnSeat = 2;
    state.hands[2] = [
      { id: "3-hearts", rank: "3", suit: "hearts" },
      { id: "7-hearts", rank: "7", suit: "hearts" },
      { id: "5-clubs", rank: "5", suit: "clubs" }
    ];

    const legal = legalCardsForSeat(state, 2).map((c) => c.id);
    // No hearts card can beat the Ace, so allow all hearts
    expect(legal).toEqual(["3-hearts", "7-hearts"]);
  });
});

describe("Discarding 10s rule", () => {
  it("prevents throwing an off-suit 10 when hand has more than 3 cards", () => {
    const state = baseState();
    state.completedTricks = [{ index: 0, leaderSeat: 0, plays: [], winnerSeat: 0 }];
    state.currentTrick = {
      index: 1,
      leaderSeat: 1,
      plays: [{ seat: 1, card: { id: "2-hearts", rank: "2", suit: "hearts" }, playedAt: 1 }]
    };
    state.currentTurnSeat = 2;
    state.powerSuit = "spades"; // power suit
    // Void in hearts (lead suit), has 4 cards (so > 3)
    state.hands[2] = [
      { id: "10-clubs", rank: "10", suit: "clubs" }, // off-suit 10 (ILLEGAL)
      { id: "10-diamonds", rank: "10", suit: "diamonds" }, // off-suit 10 (ILLEGAL)
      { id: "10-spades", rank: "10", suit: "spades" }, // power 10 (LEGAL)
      { id: "4-clubs", rank: "4", suit: "clubs" } // normal card (LEGAL)
    ];

    const legal = legalCardsForSeat(state, 2).map((c) => c.id);
    expect(legal).toEqual(["10-spades", "4-clubs"]);
  });

  it("allows throwing an off-suit 10 when hand has 3 or fewer cards", () => {
    const state = baseState();
    state.completedTricks = [{ index: 0, leaderSeat: 0, plays: [], winnerSeat: 0 }];
    state.currentTrick = {
      index: 1,
      leaderSeat: 1,
      plays: [{ seat: 1, card: { id: "2-hearts", rank: "2", suit: "hearts" }, playedAt: 1 }]
    };
    state.currentTurnSeat = 2;
    state.powerSuit = "spades";
    // Void in hearts, has exactly 3 cards
    state.hands[2] = [
      { id: "10-clubs", rank: "10", suit: "clubs" }, // off-suit 10 (LEGAL because <= 3 cards)
      { id: "4-clubs", rank: "4", suit: "clubs" },
      { id: "7-diamonds", rank: "7", suit: "diamonds" }
    ];

    const legal = legalCardsForSeat(state, 2).map((c) => c.id);
    expect(legal).toEqual(["10-clubs", "4-clubs", "7-diamonds"]);
  });
});
