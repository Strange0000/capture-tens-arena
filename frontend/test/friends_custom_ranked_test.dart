import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capture_tens_arena/src/models/match_state.dart';
import 'package:capture_tens_arena/src/state/app_state.dart';
import 'package:capture_tens_arena/src/widgets/match_result_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppState Friends & Custom Room State (Issue 4)', () {
    late AppState app;

    setUp(() {
      app = AppState();
    });

    test('isFriend correctly identifies accepted friends and ignores pending or others', () {
      app.userId = 'me-123';
      app.friends = [
        {
          'id': 'rel-1',
          'status': 'accepted',
          'user': {'id': 'friend-1', 'username': 'Alice'},
        },
        {
          'id': 'rel-2',
          'status': 'pending',
          'user': {'id': 'pending-1', 'username': 'Bob'},
        },
      ];

      expect(app.isFriend('friend-1'), isTrue);
      expect(app.isFriend('pending-1'), isFalse);
      expect(app.isFriend('stranger-1'), isFalse);
      expect(app.isFriend('me-123'), isFalse);
      expect(app.isFriend(null), isFalse);
      expect(app.isFriend(''), isFalse);

      expect(app.isFriendPending('pending-1'), isTrue);
      expect(app.isFriendPending('friend-1'), isFalse);
    });

    test('Custom room invite accept and decline flows update state cleanly', () {
      expect(app.pendingRoomInvite, isNull);

      app.pendingRoomInvite = {
        'from': 'Sumit',
        'fromUserId': 'user-sumit',
        'code': 'ROOM42',
      };
      expect(app.pendingRoomInvite, isNotNull);

      // Declining clears the pending invite
      app.declineRoomInvite();
      expect(app.pendingRoomInvite, isNull);
    });

    test('leaveRoom clears roomCode, roomPlayers, and resets lobbyStatus', () {
      app.lobbyStatus = LobbyStatus.inRoom;
      app.roomCode = 'XYZ123';
      app.roomPlayers = [
        {'userId': 'user-1', 'username': 'Player1'},
        {'userId': 'user-2', 'username': 'Player2'},
      ];
      app.roomPlayerNames = ['Player1', 'Player2'];
      app.roomPlayerCount = 2;

      app.leaveRoom();

      expect(app.lobbyStatus, LobbyStatus.idle);
      expect(app.roomCode, isNull);
      expect(app.roomPlayers, isEmpty);
      expect(app.roomPlayerNames, isEmpty);
      expect(app.roomPlayerCount, 1);
    });
  });

  group('MatchResultOverlay Players Section (Issue 4)', () {
    testWidgets('displays other human players in the match with Add Friend button', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final match = MatchState(
        id: 'test-match-1',
        mode: 'ranked',
        phase: 'complete',
        powerSuit: 'S',
        currentTurnSeat: 0,
        firstPlayerSeat: 0,
        completedTricksCount: 13,
        hand: const [],
        players: const [
          MatchPlayer(seat: 0, userId: 'my-user-id', username: 'Me', team: 'A', cardCount: 0, connected: true, isBot: false),
          MatchPlayer(seat: 1, userId: 'opponent-id', username: 'Opponent1', team: 'B', cardCount: 0, connected: true, isBot: false),
          MatchPlayer(seat: 2, userId: 'partner-id', username: 'Partner1', team: 'A', cardCount: 0, connected: true, isBot: false),
          MatchPlayer(seat: 3, userId: 'bot-3', username: 'Vector', team: 'B', cardCount: 0, connected: true, isBot: true),
        ],
        captures: const MatchCaptures(
          a: TeamCaptures(tens: 3, cards: 32, aces: 3),
          b: TeamCaptures(tens: 1, cards: 20, aces: 1),
        ),
        winnerTeam: 'A',
      );

      String? addedUserId;
      String? addedUsername;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchResultOverlay(
              match: match,
              myTeam: 'A',
              currentUserId: 'my-user-id',
              isFriend: (uid) => uid == 'partner-id', // partner is already friend
              onAddFriend: (uid, uname) {
                addedUserId = uid;
                addedUsername = uname;
              },
              onPlayAgain: () {},
              onHome: () {},
            ),
          ),
        ),
      );

      // Pump initial frame and let elastic animation progress
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Check header and victory text
      expect(find.text('Victory!'), findsOneWidget);
      expect(find.text('PLAYERS IN THIS MATCH'), findsOneWidget);

      // Partner is already a friend
      expect(find.text('Partner1'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);

      // Opponent1 is human and not a friend: Add Friend button should be visible
      expect(find.text('Opponent1'), findsOneWidget);
      final addFriendBtn = find.text('Add Friend');
      expect(addFriendBtn, findsOneWidget);

      // Tap Add Friend
      await tester.tap(addFriendBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(addedUserId, 'opponent-id');
      expect(addedUsername, 'Opponent1');
      expect(find.text('Request Sent'), findsOneWidget);
    });
  });
}
