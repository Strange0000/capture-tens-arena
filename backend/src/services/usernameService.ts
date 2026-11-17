/**
 * Unique usernames (PR-C).
 *
 * Rules (single source of truth for the backend; the Flutter client mirrors
 * them in lib/src/services/username_rules.dart — keep both in sync):
 *  - 3–24 characters, letters/digits/underscore only, must start with a letter.
 *  - Case-insensitive uniqueness: "Arjun", "arjun" and "ARJUN" are the same
 *    name. The stored `usernameLower` field carries a unique index, so the
 *    database itself refuses a duplicate even if two players claim the same
 *    name in the same second.
 *  - Reserved: the Guest* prefix and bot/system names (Vector, Nova,
 *    Cipher, Admin, ...) can never be claimed.
 *
 * The DB-touching functions below take a minimal store interface instead of
 * the Mongoose model directly, so they can be unit-tested with a fake store
 * (see backend/tests/username.test.ts) without a live MongoDB.
 */

export const USERNAME_MIN_LENGTH = 3;
export const USERNAME_MAX_LENGTH = 24;

/** 3–24 chars, starts with a letter, letters/digits/underscore only. */
export const USERNAME_PATTERN = /^[A-Za-z][A-Za-z0-9_]{2,23}$/;

/**
 * Names that can never be claimed (compared lower-cased). Covers the plan's
 * blocklist (admin, support, system, the bot names Vector/Nova/Cipher) plus
 * the obvious look-alike/system names. The "guest" prefix is handled
 * separately — any name starting with "guest" is reserved.
 */
export const RESERVED_USERNAMES: ReadonlySet<string> = new Set([
  "admin",
  "administrator",
  "support",
  "system",
  "moderator",
  "mod",
  "official",
  "bot",
  "player",
  "vector",
  "nova",
  "cipher",
  "arena",
  "capturetens",
  "capture",
  "tens",
  "guest",
  "server",
  "owner",
  "root",
  "superuser",
  "anonymous",
]);

export type UsernameProblem =
  | "too-short"
  | "too-long"
  | "bad-start"
  | "bad-chars"
  | "reserved";

export function usernameProblemMessage(problem: UsernameProblem): string {
  switch (problem) {
    case "too-short":
      return "Username must be at least 3 characters long.";
    case "too-long":
      return "Username must be at most 24 characters long.";
    case "bad-start":
      return "Username must start with a letter.";
    case "bad-chars":
      return "Username can only use letters, numbers and underscore (_).";
    case "reserved":
      return "That name is reserved. Pick a different username.";
  }
}

/** Lower-case lookup key. */
export function normalizeUsername(raw: string): string {
  return raw.trim().toLowerCase();
}

export function isReservedUsername(lower: string): boolean {
  return lower.startsWith("guest") || RESERVED_USERNAMES.has(lower);
}

export type UsernameValidation =
  | { valid: true; username: string }
  | { valid: false; problem: UsernameProblem; message: string };

export function validateUsername(raw: string): UsernameValidation {
  const username = raw.trim();
  if (username.length < USERNAME_MIN_LENGTH) {
    return { valid: false, problem: "too-short", message: usernameProblemMessage("too-short") };
  }
  if (username.length > USERNAME_MAX_LENGTH) {
    return { valid: false, problem: "too-long", message: usernameProblemMessage("too-long") };
  }
  if (!/^[A-Za-z]/.test(username)) {
    return { valid: false, problem: "bad-start", message: usernameProblemMessage("bad-start") };
  }
  if (!USERNAME_PATTERN.test(username)) {
    return { valid: false, problem: "bad-chars", message: usernameProblemMessage("bad-chars") };
  }
  if (isReservedUsername(username.toLowerCase())) {
    return { valid: false, problem: "reserved", message: usernameProblemMessage("reserved") };
  }
  return { valid: true, username };
}

/**
 * Turn an arbitrary display name (e.g. a Google profile name like
 * "Sumit Jaiswal") into a valid username base: keep letters/digits/
 * underscore, drop everything else, make sure it starts with a letter,
 * cap at 20 chars so a numeric suffix still fits in 24.
 */
export function sanitizeUsernameBase(raw: string): string {
  const cleaned = raw.replace(/[^A-Za-z0-9_]/g, "");
  const stripped = cleaned.replace(/^[^A-Za-z]+/, "");
  const base = stripped.length > 0 ? stripped : "Player";
  return base.slice(0, 20);
}

/** Random suffix for fallback names (2–4 chars, letters/digits). */
function randomSuffix(length = 4): string {
  const alphabet = "abcdefghjkmnpqrstuvwxyz23456789";
  let out = "";
  for (let i = 0; i < length; i++) {
    out += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return out;
}

/**
 * A guaranteed-unique-ish fallback name for a brand-new account whose
 * profile name collides with an existing username (used by Google login so
 * sign-in never fails outright on a name clash — the player is then
 * prompted to choose their own name at first game entry).
 */
export function fallbackUsername(rawBase: string): string {
  const base = sanitizeUsernameBase(rawBase);
  return `${base}${randomSuffix()}`.slice(0, USERNAME_MAX_LENGTH);
}

/** Minimal store surface the username logic needs (Mongoose model or fake). */
export interface UsernameStore {
  findOne(query: Record<string, unknown>): Promise<{
    _id: unknown;
    username: string;
    usernameLower?: string;
    hasChosenUsername?: boolean;
    roles?: string[];
  } | null>;
  findOneAndUpdate(
    filter: Record<string, unknown>,
    update: Record<string, unknown>,
    options: { new: boolean },
  ): Promise<{
    _id: unknown;
    username: string;
    usernameLower?: string;
    hasChosenUsername?: boolean;
    roles?: string[];
  } | null>;
}

export class UsernameError extends Error {
  readonly status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    (error as { code?: unknown }).code === 11000
  );
}

/**
 * Build up to 3 free suggestions for a taken name: base2…base9, then
 * base + two random digits. Each candidate is checked against the store.
 */
export async function suggestUsernames(
  base: string,
  store: Pick<UsernameStore, "findOne">,
): Promise<string[]> {
  const cleanBase = sanitizeUsernameBase(base).slice(0, 21);
  const candidates: string[] = [];
  for (let n = 2; n <= 9 && candidates.length < 6; n++) {
    candidates.push(`${cleanBase}${n}`);
  }
  const suggestions: string[] = [];
  for (const candidate of candidates) {
    if (suggestions.length >= 3) break;
    const taken = await store.findOne({ usernameLower: candidate.toLowerCase() });
    if (!taken) suggestions.push(candidate);
  }
  // If the numbered ones are all taken, try random two-digit suffixes.
  let guard = 0;
  while (suggestions.length < 3 && guard < 10) {
    guard++;
    const candidate = `${cleanBase}${Math.floor(10 + Math.random() * 90)}`;
    if (suggestions.includes(candidate)) continue;
    const taken = await store.findOne({ usernameLower: candidate.toLowerCase() });
    if (!taken) suggestions.push(candidate);
  }
  return suggestions;
}

export interface AvailabilityResult {
  available: boolean;
  /** Why it is not available: invalid format, reserved, or already taken. */
  reason?: "invalid" | "reserved" | "taken";
  message: string;
  suggestions: string[];
}

export async function checkUsernameAvailability(
  raw: string,
  store: Pick<UsernameStore, "findOne">,
): Promise<AvailabilityResult> {
  const validation = validateUsername(raw);
  if (!validation.valid) {
    return {
      available: false,
      reason: validation.problem === "reserved" ? "reserved" : "invalid",
      message: validation.message,
      suggestions: [],
    };
  }
  const lower = validation.username.toLowerCase();
  const taken = await store.findOne({ usernameLower: lower });
  if (!taken) {
    return { available: true, message: "That name is free.", suggestions: [] };
  }
  const suggestions = await suggestUsernames(validation.username, store);
  return {
    available: false,
    reason: "taken",
    message: "That name is already taken.",
    suggestions,
  };
}

/**
 * Claim a username for an account, exactly once.
 *
 * Atomic: the update only applies while hasChosenUsername is not true
 * (the `$ne: true` filter also matches pre-migration docs that lack the
 * field entirely), and the unique index on usernameLower makes the
 * database refuse a same-second duplicate claim with a 11000 error,
 * which is surfaced as "already taken".
 */
export async function claimUsername(
  userId: string,
  raw: string,
  store: UsernameStore,
  issueToken: (user: { id: string; username: string; roles: string[] }) => string,
): Promise<{ token: string; user: { id: string; username: string; hasChosenUsername: boolean } }> {
  const validation = validateUsername(raw);
  if (!validation.valid) {
    throw new UsernameError(400, validation.message);
  }
  const username = validation.username;
  const lower = username.toLowerCase();
  let updated;
  try {
    updated = await store.findOneAndUpdate(
      { _id: userId, hasChosenUsername: { $ne: true } },
      { $set: { username, usernameLower: lower, hasChosenUsername: true } },
      { new: true },
    );
  } catch (error) {
    if (isDuplicateKeyError(error)) {
      throw new UsernameError(409, "That name was just taken. Try another one.");
    }
    throw error;
  }
  if (!updated) {
    const existing = await store.findOne({ _id: userId });
    if (!existing) {
      throw new UsernameError(404, "Account not found. Sign in again.");
    }
    if (existing.hasChosenUsername === true) {
      throw new UsernameError(409, "You have already chosen a username. It cannot be changed yet.");
    }
    throw new UsernameError(409, "That name was just taken. Try another one.");
  }
  const id = String(updated._id);
  const roles = updated.roles ?? ["player"];
  const token = issueToken({ id, username: updated.username, roles });
  return { token, user: { id, username: updated.username, hasChosenUsername: true } };
}
