import mongoose from "mongoose";

const friendSchema = new mongoose.Schema(
  {
    requesterId: { type: String, required: true, index: true },
    addresseeId: { type: String, required: true, index: true },
    status: { type: String, enum: ["pending", "accepted", "blocked"], default: "pending" }
  },
  { timestamps: true }
);

friendSchema.index({ requesterId: 1, addresseeId: 1 }, { unique: true });
friendSchema.index({ status: 1 });

export const FriendModel = mongoose.model("Friend", friendSchema);
