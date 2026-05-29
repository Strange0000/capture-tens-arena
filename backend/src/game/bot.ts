import { legalCardsForSeat } from "./rules.js";
import { Card, MatchState, BotDifficulty } from "./types.js";
import { rankValue } from "./deck.js";

export function chooseBotCard(state: MatchState, seat: number, difficulty: BotDifficulty): Card {
  const legal = legalCardsForSeat(state, seat);
  if (legal.length === 0) throw new Error("Bot has no legal card");
  if (difficulty === "easy") return legal[Math.floor(Math.random() * legal.length)];
  if (difficulty === "medium") return mediumPick(state, legal);
  return hardPick(state, seat, legal);
}

function mediumPick(state: MatchState, legal: Card[]): Card {
  const ten = legal.find((card) => card.rank === "10");
  if (ten && state.currentTrick && state.currentTrick.plays.length >= 2) return ten;
  return [...legal].sort((a, b) => rankValue[a.rank] - rankValue[b.rank])[0];
}

function hardPick(state: MatchState, seat: number, legal: Card[]): Card {
  const powerSuit = state.powerSuit!;
  const trick = state.currentTrick;
  const playedCards = state.completedTricks.flatMap((item) => item.plays.map((play) => play.card));
  if (trick) playedCards.push(...trick.plays.map((play) => play.card));
  const unseenTens = ["hearts", "diamonds", "clubs", "spades"].filter((suit) => {
    return !playedCards.some((card) => card.rank === "10" && card.suit === suit);
  });

  const sortedLow = [...legal].sort((a, b) => rankValue[a.rank] - rankValue[b.rank]);
  const sortedHigh = [...legal].sort((a, b) => rankValue[b.rank] - rankValue[a.rank]);
  const hasTen = legal.find((card) => card.rank === "10");
  const partnerSeat = (seat + 2) % 4;
  const partnerWinning = trick?.plays.length
    ? estimateCurrentWinner(state) === partnerSeat
    : false;

  if (partnerWinning && hasTen) {
    if (trick?.plays.length === 3) {
      // We are the last player, partner already secured the win
      return hasTen;
    }
    // "Guess" if the remaining opponent can beat the partner
    const partnerCard = trick?.plays.find((p) => p.seat === partnerSeat)?.card;
    if (partnerCard) {
      const isStrong = rankValue[partnerCard.rank] >= 13 || (partnerCard.suit === powerSuit && rankValue[partnerCard.rank] >= 10);
      if (isStrong) return hasTen;
    }
  }
  
  if (trick?.plays.length === 3 && hasTen && canLikelyWin(state, sortedHigh[0])) return hasTen;
  if (unseenTens.length > 0) {
    const power = legal.filter((card) => card.suit === powerSuit).sort((a, b) => rankValue[b.rank] - rankValue[a.rank])[0];
    if (power && trick?.plays.length && !partnerWinning) return power;
  }
  return sortedLow[0];
}

function estimateCurrentWinner(state: MatchState): number | undefined {
  const trick = state.currentTrick;
  if (!trick || trick.plays.length === 0 || !state.powerSuit) return undefined;
  const power = trick.plays.filter((play) => play.card.suit === state.powerSuit);
  const leadSuit = trick.plays[0].card.suit;
  const pool = power.length > 0 ? power : trick.plays.filter((play) => play.card.suit === leadSuit);
  return pool.reduce((best, current) => (rankValue[current.card.rank] > rankValue[best.card.rank] ? current : best)).seat;
}

function canLikelyWin(state: MatchState, card: Card): boolean {
  const trick = state.currentTrick;
  if (!trick || trick.plays.length === 0) return true;
  if (card.suit === state.powerSuit) return true;
  return card.suit === trick.plays[0].card.suit && rankValue[card.rank] >= 12;
}
