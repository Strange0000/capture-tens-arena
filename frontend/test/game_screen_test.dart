import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capture_tens_arena/src/state/app_state.dart';
import 'package:capture_tens_arena/src/screens/game_screen.dart';
import 'package:capture_tens_arena/src/models/models.dart';

void main() {
  testWidgets('GameScreen renders', (WidgetTester tester) async {
    final app = AppState();
    app.userId = 'mock_user';
    app.match = MatchState(
      id: 'mock',
      mode: 'offline',
      phase: 'playing',
      players: [
        PlayerState(seat: 0, userId: 'mock_user', username: 'Me', connected: true, isBot: false, hand: [
          CardState(id: 'c1', suit: 'hearts', rank: '10', power: 10),
          CardState(id: 'c2', suit: 'spades', rank: 'A', power: 11),
        ], capturedCards: [], score: 0),
        PlayerState(seat: 1, userId: 'bot1', username: 'Bot 1', connected: true, isBot: true, hand: [], capturedCards: [], score: 0),
        PlayerState(seat: 2, userId: 'bot2', username: 'Bot 2', connected: true, isBot: true, hand: [], capturedCards: [], score: 0),
        PlayerState(seat: 3, userId: 'bot3', username: 'Bot 3', connected: true, isBot: true, hand: [], capturedCards: [], score: 0),
      ],
      deckCount: 40,
      firstPlayerSeat: 0,
      currentTurnSeat: 0,
      completedTricksCount: 0,
      powerSuit: 'hearts',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    
    // Allow animations and async tasks to settle
    await tester.pumpAndSettle();
    
    expect(find.byType(GameScreen), findsOneWidget);
  });
}
