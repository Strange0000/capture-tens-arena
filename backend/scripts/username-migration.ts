/**
 * Username migration (PR-C) — run BEFORE deploying the PR-C code.
 *
 * Why first: the unique index on `usernameLower` cannot be created while
 * duplicate names exist (MongoDB refuses it), and the new code auto-creates
 * that index at boot. So the order is: audit → apply (cleanup + backfill)
 * → create indexes → deploy the code. This script uses raw collection
 * operations only, so it can run against the current production database
 * before the new code is deployed.
 *
 *   Audit (read-only report, safe to run any time):
 *     npx tsx scripts/username-migration.ts audit
 *
 *   Apply the cleanup + backfill + create the unique indexes:
 *     npx tsx scripts/username-migration.ts apply
 *
 *   Apply the cleanup but skip index creation (create them later by hand):
 *     npx tsx scripts/username-migration.ts apply --skip-indexes
 *
 * Connection: MONGO_URI from the environment (or --uri <uri>). On Render,
 * run it from a shell with the service's environment:
 *   render shell --service <backend-service>   (or the Render dashboard shell)
 *   MONGO_URI is already set there; then run the commands above from the
 *   backend directory.
 *
 * What apply does, in order:
 *   1. Backfills `usernameLower` for every doc missing it.
 *   2. For each duplicated name (case-insensitive): the OLDEST account
 *      keeps the name; every later duplicate is renamed to a unique
 *      placeholder (sanitized base + number) and flagged
 *      hasChosenUsername=false, so its owner picks a fresh name at next
 *      game entry.
 *   3. Sets hasChosenUsername=true for all other existing non-guest
 *      accounts (they keep their name and are never prompted). Guests
 *      stay false — they are prompted at first game entry, per the PR-C
 *      design.
 *   4. Creates the unique sparse indexes on `usernameLower` and `googleId`
 *      — but only after verifying no duplicates remain. Duplicate googleIds
 *      are NOT auto-fixed (they should not exist; unsetting one would break
 *      that account's Google login): if any are found the script reports
 *      them, skips the googleId index and exits non-zero for manual review.
 */

import "dotenv/config";
import mongoose from "mongoose";

const USERS = "users";

interface UserDoc {
  _id: mongoose.Types.ObjectId;
  username: string;
  usernameLower?: string;
  googleId?: string | null;
  guest?: boolean;
  hasChosenUsername?: boolean;
  createdAt?: Date;
}

function sanitizeBase(raw: string): string {
  const cleaned = raw.replace(/[^A-Za-z0-9_]/g, "");
  const stripped = cleaned.replace(/^[^A-Za-z]+/, "");
  return (stripped.length > 0 ? stripped : "Player").slice(0, 20);
}

function parseArgs(): { mode: "audit" | "apply"; skipIndexes: boolean; uri: string | undefined } {
  const args = process.argv.slice(2);
  const mode = args[0] === "apply" ? "apply" : "audit";
  const skipIndexes = args.includes("--skip-indexes");
  const uriFlag = args.indexOf("--uri");
  const uri = uriFlag >= 0 ? args[uriFlag + 1] : process.env.MONGO_URI;
  return { mode, skipIndexes, uri };
}

async function loadUsers(collection: mongoose.mongo.Collection<UserDoc>): Promise<UserDoc[]> {
  return collection.find({}).sort({ createdAt: 1, _id: 1 }).toArray() as Promise<UserDoc[]>;
}

function groupDuplicates(users: UserDoc[]): Map<string, UserDoc[]> {
  const groups = new Map<string, UserDoc[]>();
  for (const user of users) {
    const key = (user.usernameLower ?? user.username.trim().toLowerCase());
    const list = groups.get(key) ?? [];
    list.push(user);
    groups.set(key, list);
  }
  return new Map([...groups.entries()].filter(([, list]) => list.length > 1));
}

function groupGoogleIdDuplicates(users: UserDoc[]): Map<string, UserDoc[]> {
  const groups = new Map<string, UserDoc[]>();
  for (const user of users) {
    if (!user.googleId) continue;
    const list = groups.get(user.googleId) ?? [];
    list.push(user);
    groups.set(user.googleId, list);
  }
  return new Map([...groups.entries()].filter(([, list]) => list.length > 1));
}

async function main(): Promise<number> {
  const { mode, skipIndexes, uri } = parseArgs();
  if (!uri) {
    console.error("MONGO_URI is not set. Pass --uri <mongo-uri> or set MONGO_URI.");
    return 2;
  }
  console.log(`[username-migration] mode=${mode} uri=${uri.replace(/\/\/[^@]*@/, "//***@")}`);
  await mongoose.connect(uri);
  try {
    const collection = mongoose.connection.db!.collection<UserDoc>(USERS);
    const users = await loadUsers(collection);
    console.log(`[username-migration] ${users.length} user docs`);

    const missingLower = users.filter((u) => !u.usernameLower);
    console.log(`[username-migration] ${missingLower.length} docs missing usernameLower`);

    const duplicateNames = groupDuplicates(users);
    console.log(`[username-migration] ${duplicateNames.size} duplicated username(s)`);
    for (const [lower, list] of duplicateNames) {
      console.log(`  "${lower}" x${list.length}: oldest keeps it -> ${list[0]._id}`);
      for (const dup of list.slice(1)) {
        console.log(`    rename -> ${dup._id} (created ${dup.createdAt?.toISOString() ?? "?"})`);
      }
    }

    const duplicateGoogleIds = groupGoogleIdDuplicates(users);
    console.log(`[username-migration] ${duplicateGoogleIds.size} duplicated googleId(s)`);
    for (const [googleId, list] of duplicateGoogleIds) {
      console.log(`  googleId ${googleId} x${list.length}: ${list.map((u) => String(u._id)).join(", ")}`);
    }

    if (mode === "audit") {
      console.log("[username-migration] audit only — nothing was changed. Run `apply` to fix.");
      return duplicateGoogleIds.size > 0 ? 1 : 0;
    }

    // ── Apply ──────────────────────────────────────────────────────────
    const takenLowers = new Set(users.map((u) => (u.usernameLower ?? u.username.trim().toLowerCase())));
    const renamedIds = new Set<string>();

    // 1. Backfill usernameLower.
    for (const user of missingLower) {
      const lower = user.username.trim().toLowerCase();
      await collection.updateOne({ _id: user._id }, { $set: { usernameLower: lower } });
    }
    console.log(`[username-migration] backfilled usernameLower for ${missingLower.length} docs`);

    // 2. Rename later duplicates (oldest keeps the name).
    let renamed = 0;
    for (const [, list] of duplicateNames) {
      const sorted = [...list].sort(
        (a, b) =>
          (a.createdAt?.getTime() ?? 0) - (b.createdAt?.getTime() ?? 0) ||
          String(a._id).localeCompare(String(b._id)),
      );
      for (const dup of sorted.slice(1)) {
        const base = sanitizeBase(dup.username);
        let candidate = "";
        for (let n = 2; n <= 99; n++) {
          const name = `${base}${n}`;
          if (name.length <= 24 && !takenLowers.has(name.toLowerCase())) {
            candidate = name;
            break;
          }
        }
        if (!candidate) {
          candidate = `${base}${Math.floor(1000 + Math.random() * 9000)}`.slice(0, 24);
        }
        takenLowers.add(candidate.toLowerCase());
        await collection.updateOne(
          { _id: dup._id },
          { $set: { username: candidate, usernameLower: candidate.toLowerCase(), hasChosenUsername: false } },
        );
        renamedIds.add(String(dup._id));
        renamed++;
        console.log(`[username-migration] renamed ${dup._id} "${dup.username}" -> "${candidate}"`);
      }
    }
    console.log(`[username-migration] renamed ${renamed} duplicate account(s)`);

    // 3. Existing non-guest, non-renamed accounts keep their name and are
    //    never prompted; guests stay unflagged so they choose at first game.
    const flagged = await collection.updateMany(
      { guest: { $ne: true }, _id: { $nin: [...renamedIds].map((id) => new mongoose.Types.ObjectId(id)) } },
      { $set: { hasChosenUsername: true } },
    );
    console.log(`[username-migration] flagged ${flagged.modifiedCount} existing account(s) as hasChosenUsername=true`);

    // 4. Unique indexes — only when the data is actually clean.
    if (!skipIndexes) {
      const after = await loadUsers(collection);
      const remainingNameDupes = groupDuplicates(after);
      const remainingGoogleDupes = groupGoogleIdDuplicates(after);
      if (remainingNameDupes.size > 0) {
        console.error("[username-migration] ABORT: duplicate usernames remain, index NOT created.");
        return 1;
      }
      await collection.createIndex({ usernameLower: 1 }, { unique: true, sparse: true, name: "usernameLower_1" });
      console.log("[username-migration] created unique sparse index usernameLower_1");
      if (remainingGoogleDupes.size > 0) {
        console.error(
          "[username-migration] WARNING: duplicate googleIds remain — googleId unique index NOT created.\n" +
            "Review the accounts above by hand (unsetting a googleId breaks that account's Google login).",
        );
        return 1;
      }
      await collection.createIndex({ googleId: 1 }, { unique: true, sparse: true, name: "googleId_1" });
      console.log("[username-migration] created unique sparse index googleId_1");
    } else {
      console.log("[username-migration] --skip-indexes: indexes NOT created. Create them by hand after verifying the data is clean.");
    }

    console.log("[username-migration] done.");
    return 0;
  } finally {
    await mongoose.disconnect();
  }
}

main()
  .then((code) => process.exit(code))
  .catch((error) => {
    console.error("[username-migration] FAILED:", error);
    process.exit(2);
  });
