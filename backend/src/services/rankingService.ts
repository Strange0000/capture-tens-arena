import { RankingModel } from "../models/Ranking.js";
import { env } from "../config/env.js";

export interface TierDef {
  name: string;
  min: number;
  max: number;
  icon: string;
  color: string;
}

export const TIERS: TierDef[] = [
  { name: "Iron",         min: 0,    max: 99,   icon: "🪨", color: "#6B7280" },
  { name: "Bronze",       min: 100,  max: 199,  icon: "🥉", color: "#CD7F32" },
  { name: "Silver",       min: 200,  max: 299,  icon: "🥈", color: "#C0C0C0" },
  { name: "Gold",         min: 300,  max: 399,  icon: "🥇", color: "#FFD700" },
  { name: "Platinum",     min: 400,  max: 599,  icon: "💎", color: "#48E5C2" },
  { name: "Diamond",      min: 600,  max: 799,  icon: "♦️",  color: "#B9F2FF" },
  { name: "Master",       min: 800,  max: 999,  icon: "👑", color: "#FF6B6B" },
  { name: "Grandmaster",  min: 1000, max: 9999, icon: "🏆", color: "#FFC857" },
];

export interface RankDetail {
  tier: string;
  division: number; // 1, 2, or 3 (1 = highest within tier)
  icon: string;
  color: string;
  displayName: string;
  mmr: number;
  nextTierMmr: number;
  progressInTier: number; // 0.0 to 1.0
}

export function rankForMmr(mmr: number): RankDetail {
  const clamped = Math.max(0, mmr);
  const tierDef = [...TIERS].reverse().find((t) => clamped >= t.min) ?? TIERS[0];
  const tierIndex = TIERS.indexOf(tierDef);
  const nextTier = TIERS[tierIndex + 1];

  // Grandmaster has no divisions
  if (tierDef.name === "Grandmaster") {
    return {
      tier: tierDef.name,
      division: 0,
      icon: tierDef.icon,
      color: tierDef.color,
      displayName: "Grandmaster",
      mmr: clamped,
      nextTierMmr: 9999,
      progressInTier: 1.0,
    };
  }

  const range = tierDef.max - tierDef.min + 1;
  const inTier = clamped - tierDef.min;
  const third = range / 3;

  let division: number;
  if (inTier >= third * 2) {
    division = 1; // top third = I
  } else if (inTier >= third) {
    division = 2; // middle = II
  } else {
    division = 3; // bottom = III
  }

  const divisionNames: Record<number, string> = { 1: "I", 2: "II", 3: "III" };

  return {
    tier: tierDef.name,
    division,
    icon: tierDef.icon,
    color: tierDef.color,
    displayName: `${tierDef.name} ${divisionNames[division]}`,
    mmr: clamped,
    nextTierMmr: nextTier?.min ?? 9999,
    progressInTier: inTier / range,
  };
}

export function calculateMmr(current: number, opponent: number, won: boolean) {
  const K = 32;
  const expected = 1 / (1 + Math.pow(10, (opponent - current) / 400));
  const score = won ? 1 : 0;
  const delta = Math.round(K * (score - expected));
  return Math.max(0, current + delta);
}

const offlineMmrStore = new Map<string, number>();

export async function applyRankedResult(userId: string, season: string, opponentAverage: number, won: boolean) {
  if (env.OFFLINE_DEV_MODE) {
    const oldMmr = offlineMmrStore.get(userId) ?? 0;
    const newMmr = calculateMmr(oldMmr, opponentAverage, won);
    offlineMmrStore.set(userId, newMmr);
    const detail = rankForMmr(newMmr);
    return { ranking: {}, oldMmr, newMmr, mmrDelta: newMmr - oldMmr, rankDetail: detail };
  }
  
  const ranking = await RankingModel.findOneAndUpdate(
    { userId, season },
    { $setOnInsert: { userId, season, mmr: 0, rank: "Iron III", tier: "Iron", division: 3 } },
    { upsert: true, new: true }
  );
  const oldMmr = ranking.mmr;
  ranking.mmr = calculateMmr(ranking.mmr, opponentAverage, won);
  
  const detail = rankForMmr(ranking.mmr);
  ranking.rank = detail.displayName;
  ranking.tier = detail.tier;
  ranking.division = detail.division;
  
  if (ranking.mmr > (ranking.peakMmr ?? 0)) {
    ranking.peakMmr = ranking.mmr;
  }
  
  ranking.wins += won ? 1 : 0;
  ranking.losses += won ? 0 : 1;
  await ranking.save();
  
  return { ranking, oldMmr, newMmr: ranking.mmr, mmrDelta: ranking.mmr - oldMmr, rankDetail: detail };
}
