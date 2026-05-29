import mongoose from "mongoose";

const replaySchema = new mongoose.Schema(
  {
    matchId: { type: String, required: true, index: true },
    events: { type: [Object], default: [] },
    powerSuit: String,
    winnerTeam: String,
    durationMs: Number
  },
  { timestamps: true }
);

export const ReplayModel = mongoose.model("Replay", replaySchema);
