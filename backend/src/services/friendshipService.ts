export type FriendshipStatus = "pending" | "accepted" | "blocked";

export interface FriendshipSnapshot {
  status: FriendshipStatus;
  requesterId: string;
  addresseeId: string;
}

export type FriendRequestAction =
  | "create"
  | "accept-incoming"
  | "already-sent"
  | "already-friends"
  | "blocked";

/** Order-independent key for exactly one relationship between two accounts. */
export function friendshipPairKey(firstUserId: string, secondUserId: string): string {
  return [firstUserId, secondUserId].sort().join(":");
}

/**
 * A reciprocal request accepts the pending inbound request, instead of making
 * a second record. Other existing states produce explicit, stable outcomes.
 */
export function classifyFriendRequest(
  existing: FriendshipSnapshot | null | undefined,
  currentUserId: string,
  targetUserId: string,
): FriendRequestAction {
  if (!existing) return "create";
  if (existing.status === "accepted") return "already-friends";
  if (existing.status === "blocked") return "blocked";

  const isIncoming =
    existing.requesterId === targetUserId &&
    existing.addresseeId === currentUserId;
  return isIncoming ? "accept-incoming" : "already-sent";
}
