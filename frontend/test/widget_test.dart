import 'package:flutter_test/flutter_test.dart';

import '../lib/src/models/match_state.dart';

Map<String, dynamic> _matchJson({int? turnTimeoutMs}) => {
      'id': 'test-match',
      'mode': 'ranked',
      'phase': 'playing',
      'players': [
        {
          'seat': 0,
          'userId': 'player-0',
          'username': 'Player 0',
          'team': 'A',
          'cardCount': 13,
          'connected': true,
          'isBot': false,
        },
      ],
      'hand': <dynamic>[],
      'currentTurnSeat': 0,
      'powerSuit': 'spades',
      'winnerTeam': null,
      'currentTrick': null,
      'captures': {
        'A': {'tens': 0, 'cards': 0, 'aces': 0},
        'B': {'tens': 0, 'cards': 0, 'aces': 0},
      },
      'completedTricks': <dynamic>[],
      'firstPlayerSeat': 0,
      'turnDeadline': 123456789,
      if (turnTimeoutMs != null) 'turnTimeoutMs': turnTimeoutMs,
    };

void main() {
  test('uses the server-provided turn timeout', () {
    final match = MatchState.fromJson(_matchJson(turnTimeoutMs: 45000));
    expect(match.turnTimeoutMs, 45000);
  });

  test('defaults the turn timeout for older servers', () {
    final match = MatchState.fromJson(_matchJson());
    expect(match.turnTimeoutMs, 18000);
  });
}
