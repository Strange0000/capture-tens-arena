import { nanoid } from "nanoid";
import { env } from "../config/env.js";
import { UserModel } from "../models/User.js";
import { signJwt } from "../middleware/auth.js";

export async function createGuest() {
  const username = `Guest${nanoid(6)}`;
  if (env.OFFLINE_DEV_MODE) {
    return issueSession(`guest-${nanoid(10)}`, username, ["player"]);
  }
  const user = await UserModel.create({ username, guest: true, lastSeenAt: new Date() });
  return issueSession(user.id, username, ["player"]);
}

export async function loginWithGoogle(profile: { googleId: string; email?: string | null; username: string; avatarUrl?: string | null }) {
  const cleanEmail = profile.email || undefined;
  const cleanAvatarUrl = profile.avatarUrl || undefined;
  const cleanUsername = profile.username.substring(0, 24);

  if (env.OFFLINE_DEV_MODE) {
    return issueSession(`google-${profile.googleId}`, cleanUsername, ["player"]);
  }

  const user = await UserModel.findOneAndUpdate(
    { googleId: profile.googleId },
    {
      $setOnInsert: { googleId: profile.googleId, email: cleanEmail },
      $set: { username: cleanUsername, avatarUrl: cleanAvatarUrl, lastSeenAt: new Date() }
    },
    { upsert: true, new: true }
  );
  return issueSession(user.id, user.username, user.roles);
}

function issueSession(id: string, username: string, roles: string[]) {
  const token = signJwt({ id, username, roles });
  return { token, user: { id, username, roles } };
}
