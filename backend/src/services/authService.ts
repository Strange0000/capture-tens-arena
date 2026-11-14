import { nanoid } from "nanoid";
import { isOfflineDevMode } from "../config/env.js";
import { UserModel } from "../models/User.js";
import { signJwt } from "../middleware/auth.js";

export async function createGuest() {
  const username = `Guest${nanoid(6)}`;
  if (isOfflineDevMode) {
    return issueSession(`guest-${nanoid(10)}`, username, ["player"], true);
  }
  const user = await UserModel.create({ username, guest: true, lastSeenAt: new Date() });
  return issueSession(user.id, username, ["player"], true);
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
  const user = await UserModel.findOneAndUpdate(
    { googleId: profile.googleId },
    {
      $setOnInsert: { googleId: profile.googleId, email: cleanEmail, username: cleanUsername },
      $set: { avatarUrl: cleanAvatarUrl, lastSeenAt: new Date() }
    },
    { upsert: true, new: true }
  );
  return issueSession(user.id, user.username, user.roles, user.guest ?? false);
}

function issueSession(id: string, username: string, roles: string[], guest: boolean) {
  const token = signJwt({ id, username, roles, guest });
  return { token, user: { id, username, roles, guest } };
}
