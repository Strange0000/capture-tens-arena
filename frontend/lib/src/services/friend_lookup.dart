// Pure helpers for the friends flow, kept free of HTTP and widgets so
// they are unit-testable. PR-B.

/// Outcome of an exact-username lookup before sending a friend
/// request (F2/F3).
enum FriendLookupOutcome {
  /// No account has that exact username.
  none,

  /// Exactly one account matches — show it for confirmation.
  one,

  /// Several accounts share the username — the player must pick one.
  many,
}

class FriendLookupResult {
  const FriendLookupResult(this.outcome, [this.single]);

  final FriendLookupOutcome outcome;

  /// The single match, only when [outcome] is [FriendLookupOutcome.one].
  final Map<String, dynamic>? single;
}

/// Decides what the "Send friend request" flow does with the
/// exact-match lookup results.
FriendLookupResult resolveFriendLookup(List<Map<String, dynamic>> matches) {
  if (matches.isEmpty) return const FriendLookupResult(FriendLookupOutcome.none);
  if (matches.length == 1) return FriendLookupResult(FriendLookupOutcome.one, matches.first);
  return const FriendLookupResult(FriendLookupOutcome.many);
}

/// Incoming pending requests in [current] that were not in [previous],
/// by friendship id. The lobby badge and the "new friend request"
/// toast must only fire for genuinely new requests — never for ones
/// already seen on an earlier refresh (F5).
List<Map<String, dynamic>> newIncomingFriendRequests(
  List<Map<String, dynamic>> previous,
  List<Map<String, dynamic>> current,
) {
  final previousIds = previous
      .where((f) => f['status'] == 'pending' && f['isRequester'] != true)
      .map((f) => f['id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
  return current.where((f) {
    if (f['status'] != 'pending' || f['isRequester'] == true) return false;
    final id = f['id']?.toString() ?? '';
    return id.isNotEmpty && !previousIds.contains(id);
  }).toList(growable: false);
}
