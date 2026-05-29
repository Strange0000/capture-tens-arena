export type Suit = "hearts" | "diamonds" | "clubs" | "spades";
export type Rank = "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "10" | "J" | "Q" | "K" | "A";
export type TeamId = "A" | "B";
export type MatchMode = "casual" | "ranked" | "private" | "offline";
export type MatchPhase = "waiting" | "deal-five" | "power-select" | "deal-rest" | "playing" | "trick-resolving" | "complete";
export type BotDifficulty = "easy" | "medium" | "hard";

export interface Card {
  suit: Suit;
  rank: Rank;
  id: string;
}

export interface PlayerSeat {
  seat: number;
  userId: string;
  username: string;
  connected: boolean;
  isBot: boolean;
  botDifficulty?: BotDifficulty;
}

export interface PlayedCard {
  seat: number;
  card: Card;
  playedAt: number;
}

export interface Trick {
  index: number;
  leaderSeat: number;
  plays: PlayedCard[];
  winnerSeat?: number;
}

export interface TeamCapture {
  tens: Card[];
  cards: Card[];
  aces: Card[];
}

export interface PublicPlayerState {
  seat: number;
  userId: string;
  username: string;
  team: TeamId;
  cardCount: number;
  connected: boolean;
  isBot: boolean;
}

export interface MatchState {
  id: string;
  mode: MatchMode;
  phase: MatchPhase;
  players: PlayerSeat[];
  hands: Record<number, Card[]>;
  deck: Card[];
  powerSuit?: Suit;
  dealerSeat: number;
  firstPlayerSeat: number;
  currentTurnSeat: number;
  currentTrick?: Trick;
  completedTricks: Trick[];
  captures: Record<TeamId, TeamCapture>;
  winnerTeam?: TeamId;
  startedAt?: number;
  updatedAt: number;
  turnDeadline?: number;
  replayEvents: ReplayEvent[];
}

export interface ReplayEvent {
  type: string;
  at: number;
  payload: unknown;
}

export interface MoveResult {
  state: MatchState;
  trickCompleted: boolean;
  matchCompleted: boolean;
}
