import mongoose from "mongoose";

const achievementSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    code: { type: String, required: true },
    unlockedAt: { type: Date, default: Date.now },
    metadata: Object
  },
  { timestamps: true }
);

achievementSchema.index({ userId: 1, code: 1 }, { unique: true });

export const AchievementModel = mongoose.model("Achievement", achievementSchema);
