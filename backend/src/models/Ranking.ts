import mongoose from "mongoose";

const rankingSchema = new mongoose.Schema(
  {
    userId: { type: String, index: true, required: true },
    season: { type: String, index: true, required: true },
    mmr: { type: Number, default: 0 },
    rank: { type: String, default: "Iron III" },
    tier: { type: String, default: "Iron" },
    division: { type: Number, default: 3 },
    peakMmr: { type: Number, default: 0 },
    wins: { type: Number, default: 0 },
    losses: { type: Number, default: 0 },
    rewardsClaimed: { type: [String], default: [] }
  },
  { timestamps: true }
);

rankingSchema.index({ season: 1, mmr: -1 });
rankingSchema.index({ userId: 1, season: 1 }, { unique: true });
rankingSchema.index({ season: 1, tier: 1, mmr: -1 });

export const RankingModel = mongoose.model("Ranking", rankingSchema);
