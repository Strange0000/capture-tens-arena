import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, trim: true, maxlength: 24 },
    // Lower-case lookup key for case-insensitive uniqueness. Unique + sparse
    // so the database itself refuses a duplicate name even if two players
    // claim the same name in the same second (PR-C). Sparse lets
    // pre-migration docs without the field exist until the migration
    // backfills them — run backend/scripts/username-migration.ts BEFORE
    // deploying code that relies on this index.
    usernameLower: { type: String, sparse: true, unique: true, index: true },
    // True once the player has picked their own username (at first game
    // entry). New accounts start false; pre-migration accounts are set true
    // by the migration script unless they were renamed as duplicates.
    hasChosenUsername: { type: Boolean, default: false },
    email: { type: String, sparse: true, index: true },
    // Unique + sparse (PR-C; PR-A deliberately left this a plain index
    // because no DB was reachable to check for duplicate googleIds first).
    // The migration script audits for duplicate googleIds before creating
    // this index — see backend/scripts/username-migration.ts.
    googleId: { type: String, sparse: true, unique: true, index: true },
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

// Keep the lookup key in sync whenever a doc is saved through Mongoose
// (findOneAndUpdate paths set it explicitly — this is the safety net).
userSchema.pre("save", function (next) {
  const doc = this as mongoose.Document & { username?: string; usernameLower?: string };
  if (doc.username != null && typeof doc.username === "string") {
    doc.usernameLower = doc.username.trim().toLowerCase();
  }
  next();
});

export const UserModel = mongoose.model("User", userSchema);
