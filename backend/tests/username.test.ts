import { describe, expect, it } from "vitest";
import {
  checkUsernameAvailability,
  claimUsername,
  fallbackUsername,
  isReservedUsername,
  sanitizeUsernameBase,
  validateUsername,
  type UsernameStore,
} from "../src/services/usernameService.js";

/** In-memory fake store implementing the UsernameStore surface. */
function fakeStore(initial: Array<{ _id: string; username: string; hasChosenUsername?: boolean; roles?: string[] }> = []) {
  const docs = new Map<string, { _id: string; username: string; usernameLower: string; hasChosenUsername: boolean; roles: string[] }>();
  for (const doc of initial) {
    docs.set(doc._id, {
      _id: doc._id,
      username: doc.username,
      usernameLower: doc.username.toLowerCase(),
      hasChosenUsername: doc.hasChosenUsername ?? false,
      roles: doc.roles ?? ["player"],
    });
  }
  const store: UsernameStore & { docs: typeof docs; throwDuplicateOnUpdate?: boolean } = {
    docs,
    async findOne(query) {
      for (const doc of docs.values()) {
        if (query.usernameLower !== undefined && doc.usernameLower !== query.usernameLower) continue;
        if (query._id !== undefined && doc._id !== query._id) continue;
        return { ...doc };
      }
      return null;
    },
    async findOneAndUpdate(filter, update) {
      if (store.throwDuplicateOnUpdate) {
        throw Object.assign(new Error("E11000 duplicate key"), { code: 11000 });
      }
      const doc = [...docs.values()].find((d) => {
        if (filter._id !== undefined && d._id !== filter._id) return false;
        const flag = (filter.hasChosenUsername as { $ne?: unknown } | undefined)?.$ne;
        if (flag === true && d.hasChosenUsername === true) return false;
        return true;
      });
      if (!doc) return null;
      const set = (update.$set ?? {}) as Record<string, unknown>;
      // Simulate the unique index: a colliding usernameLower fails.
      if (typeof set.usernameLower === "string") {
        for (const other of docs.values()) {
          if (other._id !== doc._id && other.usernameLower === set.usernameLower) {
            throw Object.assign(new Error("E11000 duplicate key"), { code: 11000 });
          }
        }
      }
      Object.assign(doc, set);
      return { ...doc };
    },
  };
  return store;
}

describe("username validation rules", () => {
  it("accepts a normal name", () => {
    expect(validateUsername("Arjun_99")).toEqual({ valid: true, username: "Arjun_99" });
  });

  it("rejects names shorter than 3 chars", () => {
    const result = validateUsername("Ab");
    expect(result.valid).toBe(false);
    if (!result.valid) expect(result.problem).toBe("too-short");
  });

  it("rejects names longer than 24 chars", () => {
    const result = validateUsername("A".repeat(25));
    expect(result.valid).toBe(false);
    if (!result.valid) expect(result.problem).toBe("too-long");
  });

  it("rejects names that do not start with a letter", () => {
    const result = validateUsername("9lives");
    expect(result.valid).toBe(false);
    if (!result.valid) expect(result.problem).toBe("bad-start");
    expect(validateUsername("_hidden").valid).toBe(false);
  });

  it("rejects spaces and special characters", () => {
    expect(validateUsername("Sumit Jaiswal").valid).toBe(false);
    expect(validateUsername("cool-name").valid).toBe(false);
    expect(validateUsername("naïve").valid).toBe(false);
  });

  it("rejects reserved names and the Guest prefix, any casing", () => {
    expect(isReservedUsername("admin")).toBe(true);
    expect(isReservedUsername("vector")).toBe(true);
    expect(isReservedUsername("nova")).toBe(true);
    expect(isReservedUsername("cipher")).toBe(true);
    expect(isReservedUsername("guest123")).toBe(true);
    expect(isReservedUsername("GuestAb12Cd".toLowerCase())).toBe(true);
    expect(validateUsername("Admin").valid).toBe(false);
    expect(validateUsername("GuestXyz").valid).toBe(false);
    expect(isReservedUsername("arjun")).toBe(false);
  });

  it("sanitizes a Google profile name into a valid base", () => {
    expect(sanitizeUsernameBase("Sumit Jaiswal")).toBe("SumitJaiswal");
    expect(sanitizeUsernameBase("  !!! ")).toBe("Player");
    expect(sanitizeUsernameBase("a-very-long-name-that-keeps-going-forever")).toHaveLength(20);
  });

  it("builds a valid fallback name", () => {
    const name = fallbackUsername("Sumit Jaiswal");
    expect(validateUsername(name).valid).toBe(true);
    expect(name.startsWith("SumitJaiswal")).toBe(true);
  });
});

describe("username availability", () => {
  it("reports a free name as available", async () => {
    const store = fakeStore([{ _id: "u1", username: "Arjun" }]);
    const result = await checkUsernameAvailability("Meera", store);
    expect(result.available).toBe(true);
    expect(result.suggestions).toEqual([]);
  });

  it("is case-insensitive: Arjun, arjun and ARJUN are the same name", async () => {
    const store = fakeStore([{ _id: "u1", username: "Arjun" }]);
    for (const attempt of ["arjun", "ARJUN", "ArJuN"]) {
      const result = await checkUsernameAvailability(attempt, store);
      expect(result.available).toBe(false);
      expect(result.reason).toBe("taken");
    }
  });

  it("returns free suggestions for a taken name", async () => {
    const store = fakeStore([{ _id: "u1", username: "Arjun" }]);
    const result = await checkUsernameAvailability("Arjun", store);
    expect(result.available).toBe(false);
    expect(result.suggestions.length).toBeGreaterThan(0);
    expect(result.suggestions).toContain("Arjun2");
    for (const suggestion of result.suggestions) {
      expect(validateUsername(suggestion).valid).toBe(true);
    }
  });

  it("reports invalid and reserved names without hitting the store for taken-ness", async () => {
    const store = fakeStore();
    expect((await checkUsernameAvailability("Ad", store)).reason).toBe("invalid");
    expect((await checkUsernameAvailability("Admin", store)).reason).toBe("reserved");
  });
});

describe("username claim (one per account)", () => {
  const issueToken = (user: { id: string; username: string; roles: string[] }) =>
    `token-for-${user.id}-${user.username}`;

  it("claims a free name and returns a fresh token with the new name", async () => {
    const store = fakeStore([{ _id: "u1", username: "GuestAb12Cd" }]);
    const result = await claimUsername("u1", "Meera_7", store, issueToken);
    expect(result.token).toBe("token-for-u1-Meera_7");
    expect(result.user).toEqual({ id: "u1", username: "Meera_7", hasChosenUsername: true });
    expect(store.docs.get("u1")?.usernameLower).toBe("meera_7");
  });

  it("refuses a second claim once a name is chosen", async () => {
    const store = fakeStore([{ _id: "u1", username: "Meera_7", hasChosenUsername: true }]);
    await expect(claimUsername("u1", "OtherName", store, issueToken)).rejects.toMatchObject({
      status: 409,
    });
  });

  it("refuses an invalid or reserved name", async () => {
    const store = fakeStore([{ _id: "u1", username: "GuestAb12Cd" }]);
    await expect(claimUsername("u1", "Ad", store, issueToken)).rejects.toMatchObject({ status: 400 });
    await expect(claimUsername("u1", "Vector", store, issueToken)).rejects.toMatchObject({ status: 400 });
  });

  it("reports a same-second duplicate claim as already taken (11000)", async () => {
    const store = fakeStore([
      { _id: "u1", username: "GuestAb12Cd" },
      { _id: "u2", username: "Arjun" },
    ]);
    // Simulate the unique index firing between the check and the write.
    store.throwDuplicateOnUpdate = true;
    await expect(claimUsername("u1", "Arjun", store, issueToken)).rejects.toMatchObject({
      status: 409,
    });
  });

  it("reports a missing account instead of claiming", async () => {
    const store = fakeStore();
    await expect(claimUsername("ghost", "Meera", store, issueToken)).rejects.toMatchObject({
      status: 404,
    });
  });
});
