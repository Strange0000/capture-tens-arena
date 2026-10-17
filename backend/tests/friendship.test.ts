import { describe, expect, it } from "vitest";
import {
  classifyFriendRequest,
  friendshipPairKey,
  FriendshipSnapshot,
} from "../src/services/friendshipService.js";

describe("friend request state machine", () => {
  const current = "user-a";
  const target = "user-b";

  it("creates a single stable pair key regardless of request direction", () => {
    expect(friendshipPairKey(current, target)).toBe(friendshipPairKey(target, current));
  });

  it("allows a request when no relationship exists", () => {
    expect(classifyFriendRequest(null, current, target)).toBe("create");
  });

  it("reports an outgoing pending request without creating another", () => {
    const outgoing: FriendshipSnapshot = {
      requesterId: current,
      addresseeId: target,
      status: "pending",
    };
    expect(classifyFriendRequest(outgoing, current, target)).toBe("already-sent");
  });

  it("accepts a reciprocal request by transitioning the inbound request", () => {
    const incoming: FriendshipSnapshot = {
      requesterId: target,
      addresseeId: current,
      status: "pending",
    };
    expect(classifyFriendRequest(incoming, current, target)).toBe("accept-incoming");
  });

  it("does not allow a duplicate request for accepted or blocked relationships", () => {
    expect(classifyFriendRequest({
      requesterId: current,
      addresseeId: target,
      status: "accepted",
    }, current, target)).toBe("already-friends");

    expect(classifyFriendRequest({
      requesterId: target,
      addresseeId: current,
      status: "blocked",
    }, current, target)).toBe("blocked");
  });
});
