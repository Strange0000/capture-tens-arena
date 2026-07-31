import { AchievementModel } from "../models/Achievement.js";
import { FriendModel } from "../models/Friend.js";
import { env } from "../config/env.js";
import { MatchState } from "./types.js";
import { teamForSeat } from "./deck.js";

export interface AchievementDef {
  code: string;
  name: string;
  description: string;
  icon: string;
}

export const ACHIEVEMENTS: AchievementDef[] = [
  { code: "first_win", name: "First Blood", description: "Win your first match", icon: "⚔️" },
  { code: "ten_wins", name: "Veteran", description: "Win 10 matches", icon: "🎖️" },
  { code: "fifty_wins", name: "Commander", description: "Win 50 matches", icon: "🏅" },
  { code: "clean_sweep", name: "Clean Sweep", description: "Capture all 4 tens in one match", icon: "🧹" },
  { code: "ace_collector", name: "Ace Collector", description: "Capture 50 aces across all matches", icon: "🃏" },
  { code: "streak_5", name: "On Fire", description: "Win 5 matches in a row", icon: "🔥" },
  { code: "streak_10", name: "Unstoppable", description: "Win 10 matches in a row", icon: "💥" },
  { code: "rank_gold", name: "Golden Age", description: "Reach Gold rank", icon: "🥇" },
  { code: "rank_diamond", name: "Diamond Hands", description: "Reach Diamond rank", icon: "💎" },
  { code: "rank_master", name: "Grand Master", description: "Reach Master rank", icon: "👑" },
  { code: "hundred_tens", name: "Ten Hunter", description: "Capture 100 tens across all matches", icon: "🔟" },
  { code: "play_100", name: "Dedicated", description: "Play 100 matches", icon: "📚" },
  { code: "social_butterfly", name: "Social Butterfly", description: "Add 5 friends", icon: "🦋" },
  { code: "first_ranked", name: "Into the Arena", description: "Complete your first ranked match", icon: "🏟️" },
  { code: "speed_demon", name: "Speed Demon", description: "Win a match in under 3 minutes", icon: "⚡" },
];

export async function checkAndAwardAchievements(
  userId: string,
  state: MatchState,
  won: boolean,
  stats: { matches: number; wins: number; tensCaptured: number; acesCaptured: number; currentWinStreak: number; bestWinStreak: number },
  rankTier?: string,
  matchDurationMs?: number
): Promise<string[]> {
  if (env.OFFLINE_DEV_MODE) return [];

  const newlyUnlocked: string[] = [];
  const existing = await AchievementModel.find({ userId }).select("code");
  const has = new Set(existing.map(a => a.code));

  async function tryAward(code: string) {
    if (has.has(code)) return;
    try {
      await AchievementModel.create({ userId, code });
      newlyUnlocked.push(code);
    } catch (_) { /* duplicate key = already exists */ }
  }

  // Win-based
  if (won && stats.wins >= 1) await tryAward("first_win");
  if (won && stats.wins >= 10) await tryAward("ten_wins");
  if (won && stats.wins >= 50) await tryAward("fifty_wins");

  // Tens in this match — check if team captured all 4
  const myPlayer = state.players.find(p => p.userId === userId);
  if (myPlayer) {
    const team = teamForSeat(myPlayer.seat);
    const teamCaptures = state.captures[team];
    if (teamCaptures && teamCaptures.tens && teamCaptures.tens.length === 4) {
      await tryAward("clean_sweep");
    }
  }

  // Cumulative stats
  if (stats.tensCaptured >= 100) await tryAward("hundred_tens");
  if (stats.acesCaptured >= 50) await tryAward("ace_collector");
  if (stats.matches >= 100) await tryAward("play_100");

  // Streaks
  if (stats.currentWinStreak >= 5) await tryAward("streak_5");
  if (stats.currentWinStreak >= 10) await tryAward("streak_10");

  // Rank-based
  if (rankTier) {
    if (["Gold", "Platinum", "Diamond", "Master", "Grandmaster"].includes(rankTier)) await tryAward("rank_gold");
    if (["Diamond", "Master", "Grandmaster"].includes(rankTier)) await tryAward("rank_diamond");
    if (["Master", "Grandmaster"].includes(rankTier)) await tryAward("rank_master");
  }

  // Ranked match
  if (state.mode === "ranked") await tryAward("first_ranked");

  // Speed demon
  if (won && matchDurationMs && matchDurationMs < 180000) await tryAward("speed_demon");

  // Social butterfly
  try {
    const friendCount = await FriendModel.countDocuments({
      status: "accepted",
      $or: [{ requesterId: userId }, { addresseeId: userId }]
    });
    if (friendCount >= 5) await tryAward("social_butterfly");
  } catch (_) {}

  return newlyUnlocked;
}
