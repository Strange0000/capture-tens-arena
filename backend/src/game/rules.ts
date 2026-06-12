import { rankValue, teamForSeat } from "./deck.js";
import { Card, MatchState, PlayedCard, Suit, TeamId, Trick } from "./types.js";

export function isTen(card: Card): boolean {
  return card.rank === "10";
}

export function isAce(card: Card): boolean {
  return card.rank === "A";
}

export function getLeadSuit(trick?: Trick): Suit | undefined {
  return trick?.plays[0]?.card.suit;
}

export function hasSuit(hand: Card[], suit: Suit): boolean {
  return hand.some((card) => card.suit === suit);
}

export function restrictedOnFirstTrick(card: Card, powerSuit: Suit): boolean {
  return card.suit === powerSuit || isTen(card);
}

export function legalCardsForSeat(state: MatchState, seat: number): Card[] {
  const hand = state.hands[seat] ?? [];
  if (state.phase !== "playing" || state.currentTurnSeat !== seat || !state.powerSuit) {
    return [];
  }

  const leadSuit = getLeadSuit(state.currentTrick);
  let candidates = hand;

  // Must follow lead suit if possible
  if (leadSuit && hasSuit(hand, leadSuit)) {
    candidates = hand.filter((card) => card.suit === leadSuit);

    // "Must play higher" rule — only applies after the first trick, and only unless teammate is currently winning
    if (state.currentTrick && state.currentTrick.plays.length > 0 && state.completedTricks.length > 0) {
      const teammateIsWinning = isTeammateWinning(state.currentTrick, seat, state.powerSuit!);

      if (!teammateIsWinning) {
        // Find the current highest card value in the lead suit
        const currentHighest = highestRankInSuit(state.currentTrick.plays, leadSuit!);
        if (currentHighest > 0) {
          const higherCards = candidates.filter((card) => rankValue[card.rank] > currentHighest);
          // Only force higher if player actually has a higher card
          if (higherCards.length > 0) {
            candidates = higherCards;
          }
        }
      }
      // If teammate IS winning, player can play any card of the lead suit (throw low)
    }
  }

  // Discarding 10s restriction (Cannot throw off-suit 10s unless hand <= 3)
  if (leadSuit && hand.length > 3) {
    const restrictedCandidates = candidates.filter((card) => {
      if (card.rank !== "10") return true;
      if (card.suit === state.powerSuit) return true;
      if (card.suit === leadSuit) return true;
      return false; // It's an off-suit 10, cannot be thrown
    });
    
    if (restrictedCandidates.length > 0) {
      candidates = restrictedCandidates;
    }
  }

  // First trick restriction: no power suit or tens unless forced
  if (state.completedTricks.length === 0) {
    const unrestricted = candidates.filter((card) => !restrictedOnFirstTrick(card, state.powerSuit!));
    if (unrestricted.length > 0) {
      return unrestricted;
    }
  }

  return candidates;
}

/** Returns true if the seat's teammate (partner) is currently winning the trick. */
function isTeammateWinning(trick: Trick, seat: number, powerSuit: Suit): boolean {
  if (trick.plays.length === 0) return false;

  const leadSuit = trick.plays[0].card.suit;
  const myTeam = teamForSeat(seat);

  // Determine who is currently winning
  const powerPlays = trick.plays.filter((p) => p.card.suit === powerSuit);
  const pool = powerPlays.length > 0 ? powerPlays : trick.plays.filter((p) => p.card.suit === leadSuit);
  const currentWinner = pool.reduce((best, cur) =>
    rankValue[cur.card.rank] > rankValue[best.card.rank] ? cur : best
  );

  // Is the current winner on the same team as the current player?
  return teamForSeat(currentWinner.seat) === myTeam;
}

/** Returns the highest rank value among plays of a specific suit. */
function highestRankInSuit(plays: PlayedCard[], suit: Suit): number {
  let highest = 0;
  for (const play of plays) {
    if (play.card.suit === suit && rankValue[play.card.rank] > highest) {
      highest = rankValue[play.card.rank];
    }
  }
  return highest;
}

export function assertLegalMove(state: MatchState, seat: number, cardId: string): Card {
  if (state.phase !== "playing") {
    throw new Error("Match is not in playing phase");
  }
  if (state.currentTurnSeat !== seat) {
    throw new Error("It is not your turn");
  }

  const card = state.hands[seat]?.find((item) => item.id === cardId);
  if (!card) {
    throw new Error("Card is not in your hand");
  }

  const legal = legalCardsForSeat(state, seat);
  if (!legal.some((item) => item.id === cardId)) {
    // Give a helpful error message explaining why
    const leadSuit = getLeadSuit(state.currentTrick);
    const hand = state.hands[seat] ?? [];
    
    if (leadSuit && hasSuit(hand, leadSuit) && card.suit !== leadSuit) {
      throw new Error(`You must follow the lead suit (${leadSuit})`);
    }
    if (state.completedTricks.length === 0 && restrictedOnFirstTrick(card, state.powerSuit!)) {
      throw new Error("Can't play power suit or tens on the first trick");
    }
    if (card.rank === "10" && leadSuit && card.suit !== leadSuit && card.suit !== state.powerSuit && hand.length > 3) {
      throw new Error("Can't discard off-suit tens while you have more than 3 cards");
    }
    throw new Error("You must play a higher card if possible");
  }

  return card;
}

export function determineTrickWinner(trick: Trick, powerSuit: Suit): number {
  const leadSuit = getLeadSuit(trick);
  if (!leadSuit || trick.plays.length !== 4) {
    throw new Error("Cannot resolve incomplete trick");
  }

  const powerPlays = trick.plays.filter((play) => play.card.suit === powerSuit);
  const pool = powerPlays.length > 0 ? powerPlays : trick.plays.filter((play) => play.card.suit === leadSuit);
  return pool.reduce((best: PlayedCard, current) => {
    return rankValue[current.card.rank] > rankValue[best.card.rank] ? current : best;
  }).seat;
}

export function applyCapture(state: MatchState, winnerSeat: number, cards: Card[]): void {
  const team = teamForSeat(winnerSeat) as TeamId;
  state.captures[team].cards.push(...cards);
  state.captures[team].tens.push(...cards.filter(isTen));
  state.captures[team].aces.push(...cards.filter(isAce));
}

export function determineMatchWinner(state: MatchState): TeamId | undefined {
  const a = state.captures.A;
  const b = state.captures.B;
  if (a.tens.length !== b.tens.length) return a.tens.length > b.tens.length ? "A" : "B";
  if (a.cards.length !== b.cards.length) return a.cards.length > b.cards.length ? "A" : "B";
  if (a.aces.length !== b.aces.length) return a.aces.length > b.aces.length ? "A" : "B";
  return undefined;
}
