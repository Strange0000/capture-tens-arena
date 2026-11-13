import { nanoid } from "nanoid";
import { createDeck, shuffleDeck, teamForSeat } from "./deck.js";
import { applyCapture, assertLegalMove, determineMatchWinner, determineTrickWinner } from "./rules.js";
import { Card, MatchMode, MatchState, MoveResult, PlayerSeat, Suit } from "./types.js";

const emptyCaptures = () => ({
  A: { tens: [] as Card[], cards: [] as Card[], aces: [] as Card[] },
  B: { tens: [] as Card[], cards: [] as Card[], aces: [] as Card[] }
});

export function createMatch(players: PlayerSeat[], mode: MatchMode = "casual", seed = Date.now()): MatchState {
  if (players.length !== 4) {
    throw new Error("Capture Tens requires exactly four players");
  }

  const deck = shuffleDeck(createDeck(), seed);
    const humanSeats = players.filter(p => !p.isBot).map(p => p.seat);
    const firstPlayerSeat = humanSeats.length > 0 ? humanSeats[(seed >>> 0) % humanSeats.length] : ((seed >>> 0) % 4);
    return {
      id: nanoid(12),
      mode,
      phase: "deal-five",
      players,
      hands: { 0: [], 1: [], 2: [], 3: [] },
      deck,
      dealerSeat: (firstPlayerSeat + 3) % 4,
      firstPlayerSeat,
      currentTurnSeat: firstPlayerSeat,
    completedTricks: [],
    captures: emptyCaptures(),
    updatedAt: Date.now(),
    turnGeneration: 0,
    replayEvents: [{ type: "match.created", at: Date.now(), payload: { players, seed } }]
  };
}

export function dealFirstFive(state: MatchState): MatchState {
  if (state.phase !== "deal-five") throw new Error("Cannot deal first five now");
  for (let round = 0; round < 5; round += 1) {
    for (let seat = 0; seat < 4; seat += 1) {
      state.hands[seat].push(state.deck.shift()!);
    }
  }
  state.phase = "power-select";
  record(state, "deal.firstFive", publicHandCounts(state));
  return touch(state);
}

export function selectPowerSuit(state: MatchState, seat: number, suit: Suit): MatchState {
  if (state.phase !== "power-select") throw new Error("Power suit cannot be selected now");
  if (seat !== state.firstPlayerSeat) throw new Error("Only first player may select power suit");
  state.powerSuit = suit;
  state.phase = "deal-rest";
  record(state, "power.selected", { seat, suit });
  return touch(state);
}

export function dealRemainingCards(state: MatchState): MatchState {
  if (state.phase !== "deal-rest") throw new Error("Cannot deal remaining cards now");
  for (const phaseSize of [4, 4]) {
    for (let round = 0; round < phaseSize; round += 1) {
      for (let seat = 0; seat < 4; seat += 1) {
        state.hands[seat].push(state.deck.shift()!);
      }
    }
    record(state, "deal.phase", publicHandCounts(state));
  }
  state.phase = "playing";
  state.startedAt = Date.now();
  state.currentTrick = { index: 0, leaderSeat: state.firstPlayerSeat, plays: [] };
  state.currentTurnSeat = state.firstPlayerSeat;
  record(state, "match.started", { powerSuit: state.powerSuit });
  return touch(state);
}

export function playCard(state: MatchState, seat: number, cardId: string): MoveResult {
  if (!state.currentTrick || !state.powerSuit) throw new Error("Match is not ready");
  const card = assertLegalMove(state, seat, cardId);
  state.hands[seat] = state.hands[seat].filter((item) => item.id !== cardId);
  state.currentTrick.plays.push({ seat, card, playedAt: Date.now() });
  state.turnGeneration = (state.turnGeneration || 0) + 1;
  record(state, "card.played", { seat, card });

  let trickCompleted = false;
  let matchCompleted = false;
  if (state.currentTrick.plays.length === 4) {
    trickCompleted = true;
    const winnerSeat = determineTrickWinner(state.currentTrick, state.powerSuit);
    state.currentTrick.winnerSeat = winnerSeat;
    applyCapture(state, winnerSeat, state.currentTrick.plays.map((play) => play.card));
    state.completedTricks.push(state.currentTrick);
    record(state, "trick.completed", { trick: state.currentTrick });

    if (state.completedTricks.length === 13) {
      state.phase = "complete";
      state.winnerTeam = determineMatchWinner(state);
      matchCompleted = true;
      record(state, "match.completed", { winnerTeam: state.winnerTeam, captures: state.captures });
    } else {
      state.phase = "trick-resolving";
      state.currentTurnSeat = winnerSeat;
    }
  } else {
    state.currentTurnSeat = (seat + 1) % 4;
  }

  return { state: touch(state), trickCompleted, matchCompleted };
}

export function startNextTrick(state: MatchState): MatchState {
  if (state.phase !== "trick-resolving") throw new Error("Cannot start next trick now");
  state.phase = "playing";
  state.currentTrick = { index: state.completedTricks.length, leaderSeat: state.currentTurnSeat, plays: [] };
  // state.turnDeadline is handled by the caller, but we touch the state
  return touch(state);
}

export function publicStateForSeat(state: MatchState, viewerSeat?: number) {
  return {
    id: state.id,
    mode: state.mode,
    phase: state.phase,
    players: state.players.map((player) => ({
      seat: player.seat,
      userId: player.userId,
      username: player.username,
      team: teamForSeat(player.seat),
      cardCount: state.hands[player.seat]?.length ?? 0,
      connected: player.connected,
      isBot: player.isBot
    })),
    hand: viewerSeat === undefined ? [] : state.hands[viewerSeat],
    powerSuit: state.powerSuit,
    currentTurnSeat: state.currentTurnSeat,
    currentTrick: state.currentTrick,
    completedTricks: state.completedTricks,
    captures: {
      A: { tens: state.captures.A.tens.length, tenCards: state.captures.A.tens, cards: state.captures.A.cards.length, aces: state.captures.A.aces.length },
      B: { tens: state.captures.B.tens.length, tenCards: state.captures.B.tens, cards: state.captures.B.cards.length, aces: state.captures.B.aces.length }
    },
    winnerTeam: state.winnerTeam,
    turnDeadline: state.turnDeadline,
    firstPlayerSeat: state.firstPlayerSeat,
    // Monotonic version of this match state. The client ignores a
    // match:state whose (turnGeneration, updatedAt) is older than the
    // one it already holds for the same match id: the in-memory
    // matchStore is per-process while the socket adapter is shared,
    // so a stale broadcast can otherwise revert the client — a played
    // card returning to the hand and the timer under the wrong player
    // (Round 10, trick 6). turnGeneration rises on every played card;
    // updatedAt rises on every engine mutation (touch()).
    turnGeneration: state.turnGeneration ?? 0,
    updatedAt: state.updatedAt ?? 0
  };
}

/// 52-card invariant: hands + deck + current trick + completed tricks
/// must contain exactly the 52 unique cards. Captures are a DERIVED
/// view of the completed tricks (applyCapture copies the same card
/// objects), so they are deliberately NOT counted here. Returns an
/// error string on violation, null when the invariant holds. Log-only:
/// callers must never throw on this — a false alarm must not break a
/// live game.
export function assertUniqueCards(state: MatchState): string | null {
  const seen = new Map<string, string>();
  const check = (card: Card, where: string): string | null => {
    const prev = seen.get(card.id);
    if (prev) return `duplicate ${card.id} in ${where} (already in ${prev})`;
    seen.set(card.id, where);
    return null;
  };
  for (const [seat, hand] of Object.entries(state.hands)) {
    for (const c of hand) {
      const e = check(c, `hand ${seat}`);
      if (e) return e;
    }
  }
  for (const c of state.deck) {
    const e = check(c, "deck");
    if (e) return e;
  }
  // During the "trick-resolving" window, playCard has already pushed
  // the finished trick into completedTricks but currentTrick still
  // references the SAME trick object (the client shows it for 2s).
  // Count it once: skip currentTrick when its index is already in
  // completedTricks.
  const completedIndexes = new Set(state.completedTricks.map((t) => t.index));
  if (state.currentTrick && !completedIndexes.has(state.currentTrick.index)) {
    for (const play of state.currentTrick.plays) {
      const e = check(play.card, `current trick (seat ${play.seat})`);
      if (e) return e;
    }
  }
  for (const trick of state.completedTricks) {
    for (const play of trick.plays) {
      const e = check(play.card, `completed trick ${trick.index} (seat ${play.seat})`);
      if (e) return e;
    }
  }
  if (seen.size !== 52) return `only ${seen.size} unique cards accounted for`;
  return null;
}

function publicHandCounts(state: MatchState) {
  return Object.fromEntries(Object.entries(state.hands).map(([seat, hand]) => [seat, hand.length]));
}

function record(state: MatchState, type: string, payload: unknown) {
  state.replayEvents.push({ type, at: Date.now(), payload });
}

function touch<T extends MatchState>(state: T): T {
  state.updatedAt = Date.now();
  return state;
}
