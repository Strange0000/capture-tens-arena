import mongoose from "mongoose";

const matchSchema = new mongoose.Schema(
  {
    mode: { type: String, enum: ["casual", "ranked", "private", "offline"], required: true },
    state: { type: Object, required: true },
    players: [{ userId: String, seat: Number, username: String, isBot: Boolean }],
    winnerTeam: String,
    completedAt: Date
  },
  { timestamps: true }
);

matchSchema.index({ completedAt: -1 });
matchSchema.index({ "players.userId": 1, completedAt: -1 });
matchSchema.index({ mode: 1, completedAt: -1 });

export const MatchModel = mongoose.model("Match", matchSchema);
