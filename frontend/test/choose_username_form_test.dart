import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capture_tens_arena/src/widgets/choose_username_form.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    Map<String, dynamic>? Function(String name)? onCheck,
    Future<void> Function(String name)? onClaim,
    String? currentUsername,
    bool isGuest = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChooseUsernameForm(
            currentUsername: currentUsername,
            isGuest: isGuest,
            onCheckAvailability: (name) async =>
                onCheck?.call(name) ??
                {'available': true, 'message': 'That name is free.', 'suggestions': []},
            onClaim: (name) async => onClaim?.call(name),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('invalid name shows the rule and keeps Save disabled',
      (WidgetTester tester) async {
    await pumpForm(tester);
    await tester.enterText(find.byType(TextField), 'Ad');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Username must be at least 3 characters long.'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('free name shows the green tick and enables Save, claim is called',
      (WidgetTester tester) async {
    String? claimed;
    await pumpForm(tester,
        onClaim: (name) async {
          claimed = name;
        });
    await tester.enterText(find.byType(TextField), 'Meera_7');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('That name is free.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
    await tester.tap(find.text('Save my username'));
    await tester.pump();
    expect(claimed, 'Meera_7');
  });

  testWidgets('taken name shows the message and suggestion chips; a chip fills the field',
      (WidgetTester tester) async {
    await pumpForm(tester, onCheck: (name) {
      if (name == 'Arjun') {
        return {
          'available': false,
          'message': 'That name is already taken.',
          'suggestions': ['Arjun2', 'Arjun3'],
        };
      }
      return {'available': true, 'message': 'That name is free.', 'suggestions': []};
    });
    await tester.enterText(find.byType(TextField), 'Arjun');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('That name is already taken.'), findsOneWidget);
    expect(find.text('Arjun2'), findsOneWidget);
    await tester.tap(find.text('Arjun2'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('That name is free.'), findsOneWidget);
  });

  testWidgets('a failed claim shows the plain-words error and keeps the dialog open',
      (WidgetTester tester) async {
    await pumpForm(tester, onClaim: (_) async {
      throw Exception('That name was just taken. Try another one.');
    });
    await tester.enterText(find.byType(TextField), 'Meera_7');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.tap(find.text('Save my username'));
    await tester.pump();
    expect(find.text('That name was just taken. Try another one.'), findsOneWidget);
    expect(find.text('Choose your username'), findsOneWidget);
  });

  testWidgets('a Google profile name is suggested pre-filled and checked',
      (WidgetTester tester) async {
    await pumpForm(tester,
        currentUsername: 'Sumit Jaiswal', isGuest: false);
    // The suggestion is the sanitized profile name.
    expect(find.text('SumitJaiswal'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('That name is free.'), findsOneWidget);
  });
}
