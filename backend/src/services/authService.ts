import { nanoid } from "nanoid";
import { isOfflineDevMode } from "../config/env.js";
import { UserModel } from "../models/User.js";
import { signJwt } from "../middleware/auth.js";
import { fallbackUsername, sanitizeUsernameBase } from "./usernameService.js";

function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    (error as { code?: unknown }).code === 11000
  );
}

export async function createGuest() {
  if (isOfflineDevMode) {
    const username = `Guest${nanoid(6)}`;
    return issueSession(`guest-${nanoid(10)}`, username, ["player"], false);
  }
  // Guest names are random, but the unique index on usernameLower makes a
  // (near-impossible) collision a hard failure — retry with a fresh name
  // instead of failing the login.
  for (let attempt = 0; attempt < 3; attempt++) {
    const username = `Guest${nanoid(6)}`;
    try {
      const user = await UserModel.create({
        username,
        usernameLower: username.toLowerCase(),
        hasChosenUsername: false,
        guest: true,
        lastSeenAt: new Date(),
      });
      return issueSession(user.id, username, ["player"], false);
    } catch (error) {
      if (!isDuplicateKeyError(error) || attempt === 2) throw error;
    }
  }
  throw new Error("Could not create a guest account. Try again.");
}

export async function loginWithGoogle(profile: { googleId: string; email?: string | null; username: string; avatarUrl?: string | null }) {
  const cleanEmail = profile.email || undefined;
  const cleanAvatarUrl = profile.avatarUrl || undefined;
  const cleanUsername = profile.username.substring(0, 24);

  if (isOfflineDevMode) {
    return issueSession(`google-${profile.googleId}`, cleanUsername, ["player"], false);
  }

  // PR-A (G8): username is set only on insert ($setOnInsert), so signing in
  // again with Google never renames an existing account. The verified
  // profile name is only the first-login default.
  //
  // PR-C: a brand-new Google account whose profile name already belongs to
  // someone else (e.g. two accounts both called "Sumit Jaiswal") must not
  // fail login outright on the unique username index. On a duplicate-key
  // error, retry the insert with a unique fallback name — the player is
  // then prompted to choose their own name at first game entry
  // (hasChosenUsername stays false).
  let candidate = sanitizeUsernameBase(cleanUsername);
  if (candidate.length < 3) candidate = fallbackUsername(cleanUsername);
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const user = await UserModel.findOneAndUpdate(
        { googleId: profile.googleId },
        {
          $setOnInsert: {
            googleId: profile.googleId,
            email: cleanEmail,
            username: candidate,
            usernameLower: candidate.toLowerCase(),
            hasChosenUsername: false,
          },
          $set: { avatarUrl: cleanAvatarUrl, lastSeenAt: new Date() },
        },
        { upsert: true, new: true },
      );
      return issueSession(user.id, user.username, user.roles, user.hasChosenUsername ?? false);
    } catch (error) {
      if (!isDuplicateKeyError(error) || attempt === 2) throw error;
      // The colliding name belongs to someone else — try a unique variant.
      candidate = fallbackUsername(cleanUsername);
    }
  }
  throw new Error("Google login failed. Try again.");
}

function issueSession(id: string, username: string, roles: string[], hasChosenUsername: boolean) {
  const token = signJwt({ id, username, roles });
  return { token, user: { id, username, roles, hasChosenUsername } };
}
