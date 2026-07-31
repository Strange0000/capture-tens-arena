import { Card, Rank, Suit } from "./types.js";

export const suits: Suit[] = ["hearts", "diamonds", "clubs", "spades"];
export const ranks: Rank[] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"];

export const rankValue: Record<Rank, number> = {
  "2": 2,
  "3": 3,
  "4": 4,
  "5": 5,
  "6": 6,
  "7": 7,
  "8": 8,
  "9": 9,
  "10": 10,
  J: 11,
  Q: 12,
  K: 13,
  A: 14
};

export function createDeck(): Card[] {
  return suits.flatMap((suit) => ranks.map((rank) => ({ suit, rank, id: `${rank}-${suit}` })));
}

export function shuffleDeck(deck: Card[], _seed?: number): Card[] {
  const copy = [...deck];
  // Use crypto.getRandomValues for secure shuffling (Fisher-Yates)
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

export function teamForSeat(seat: number) {
  return seat % 2 === 0 ? "A" : "B";
}
