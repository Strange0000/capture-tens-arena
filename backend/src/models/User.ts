import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, trim: true, maxlength: 24 },
    email: { type: String, sparse: true, index: true },
    googleId: { type: String, sparse: true, index: true },
    passwordHash: String,
    avatarUrl: String,
    guest: { type: Boolean, default: false },
    roles: { type: [String], default: ["player"] },
    status: { type: String, enum: ["online", "offline", "in-match"], default: "offline" },
    friendCount: { type: Number, default: 0 },
    lastSeenAt: Date
  },
  { timestamps: true }
);

export const UserModel = mongoose.model("User", userSchema);
