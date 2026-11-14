// PR-B (Friends) regression tests.
//
// F2/F3: the "Send friend request" button must look the name up
// exactly and confirm the exact player before sending — never fire a
// request at a bare typed name (a partial name 404'd, and a duplicate
// username could send it to the wrong account).
//
// F5: the lobby badge / toast must only fire for genuinely new
// incoming requests — never for ones already seen on an earlier
// refresh.
//
// F8: friend error paths must never surface a raw FormatException
// (or any raw exception text) when the server answers with something
// that is not JSON.
import 'dart:async';

import 'package:capture_tens_arena/src/services/auth_service.dart';
import 'package:capture_tens_arena/src/services/friend_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> friend({
  required String id,
  String status = 'pending',
  bool isRequester = false,
  String username = 'Player',
}) {
  return {
    'id': id,
    'status': status,
    'isRequester': isRequester,
    'user': {'id': 'user-$id', 'username': username},
  };
}

void main() {
  group('resolveFriendLookup (F2/F3)', () {
    test('no matches means no player with that name', () {
      final result = resolveFriendLookup([]);
      expect(result.outcome, FriendLookupOutcome.none);
      expect(result.single, isNull);
    });

    test('one match returns that exact player for confirmation', () {
      final match = {'id': 'u1', 'username': 'Sumit'};
      final result = resolveFriendLookup([match]);
      expect(result.outcome, FriendLookupOutcome.one);
      expect(result.single, match);
    });

    test('several matches means the player must pick one', () {
      final result = resolveFriendLookup([
        {'id': 'u1', 'username': 'Alex'},
        {'id': 'u2', 'username': 'Alex'},
      ]);
      expect(result.outcome, FriendLookupOutcome.many);
      expect(result.single, isNull);
    });
  });

  group('newIncomingFriendRequests (F5)', () {
    test('detects a request that arrived since the last refresh', () {
      final previous = [friend(id: 'f1')];
      final current = [friend(id: 'f1'), friend(id: 'f2', username: 'Maya')];

      final fresh = newIncomingFriendRequests(previous, current);
      expect(fresh.map((f) => f['id']), ['f2']);
    });

    test('does not re-report requests already seen', () {
      final previous = [friend(id: 'f1'), friend(id: 'f2')];
      final current = [friend(id: 'f1'), friend(id: 'f2')];

      expect(newIncomingFriendRequests(previous, current), isEmpty);
    });

    test('ignores outgoing requests and accepted friends', () {
      final previous = <Map<String, dynamic>>[];
      final current = [
        friend(id: 'out', isRequester: true),
        friend(id: 'acc', status: 'accepted'),
        friend(id: 'in', username: 'Maya'),
      ];

      final fresh = newIncomingFriendRequests(previous, current);
      expect(fresh.map((f) => f['id']), ['in']);
    });

    test('ignores entries without an id', () {
      final previous = <Map<String, dynamic>>[];
      final current = [
        {'status': 'pending', 'isRequester': false, 'user': {'username': 'Ghost'}},
      ];

      expect(newIncomingFriendRequests(previous, current), isEmpty);
    });
  });

  group('friendRequestErrorMessage (F8)', () {
    test('passes a server JSON error message through unchanged', () {
      expect(
        friendRequestErrorMessage(
          statusCode: 404,
          body: '{"error":"User not found"}',
        ),
        'User not found',
      );
    });

    test('a non-JSON 404 body becomes a plain-words message, never a FormatException', () {
      expect(
        friendRequestErrorMessage(statusCode: 404, body: '<html>Not Found</html>'),
        'Player not found — check the spelling and try again.',
      );
    });

    test('a non-JSON 500 body becomes a server-trouble message', () {
      expect(
        friendRequestErrorMessage(statusCode: 502, body: '<html>Bad Gateway</html>'),
        'The server is having trouble — please try again in a moment.',
      );
    });

    test('an empty body falls back to the status message', () {
      expect(
        friendRequestErrorMessage(statusCode: 409, body: ''),
        'That friend request already exists.',
      );
    });

    test('a timeout becomes a connection message', () {
      expect(
        friendRequestErrorMessage(error: TimeoutException('timed out')),
        'Could not reach the server — check your connection and try again.',
      );
    });

    test('any other failure becomes a generic plain-words message', () {
      expect(
        friendRequestErrorMessage(error: StateError('boom')),
        'Something went wrong — please try again.',
      );
    });
  });
}
