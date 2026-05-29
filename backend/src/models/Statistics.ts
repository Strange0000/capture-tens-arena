import mongoose from "mongoose";

const statisticsSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true },
    matches: { type: Number, default: 0 },
    wins: { type: Number, default: 0 },
    tensCaptured: { type: Number, default: 0 },
    acesCaptured: { type: Number, default: 0 },
    bestWinStreak: { type: Number, default: 0 },
    currentWinStreak: { type: Number, default: 0 }
  },
  { timestamps: true }
);

export const StatisticsModel = mongoose.model("Statistics", statisticsSchema);
