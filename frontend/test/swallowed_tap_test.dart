// Round 12 regression tests: a legal first tap on a hand card must
// play the card EVERY time — including a mouse click that drifts a
// pixel or two, and a tap that lands while the screen rebuilds.
//
// Background (Round 11 final live test, commit 96a42a3): 12 of 13
// legal first taps worked, but Trick 7 silently swallowed one —
// Cipher led 2 diamonds, the tester tapped 3 diamonds with ~24s left
// on the timer, the card only raised with a gold outline, NO message
// appeared, the trick did not advance, and a second tap on the same
// card played it immediately. A tap that reaches _tryPlayCard can
// never be silent (it always plays or shows a plain-words reason),
// so the tap handler itself never ran. These tests pin down which
// part of the tap path swallows it.
import 'dart:math' as math;

import 'package:capture_tens_arena/src/models/arena_card.dart';
import 'package:capture_tens_arena/src/widgets/arena_card_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Trick 7 hand from the Round 11 live test, in the auto-sorted
/// order _HandArea produces (spades, hearts, diamonds, clubs; rank
/// descending): 10S 4S 7H 5H 4H QD 3D. 3D is the LAST card — the one
/// whose tap was swallowed.
List<ArenaCard> trick7Hand() => const [
      ArenaCard(id: 'spades_10', rank: '10', suit: 'spades'),
      ArenaCard(id: 'spades_4', rank: '4', suit: 'spades'),
      ArenaCard(id: 'hearts_7', rank: '7', suit: 'hearts'),
      ArenaCard(id: 'hearts_5', rank: '5', suit: 'hearts'),
      ArenaCard(id: 'hearts_4', rank: '4', suit: 'hearts'),
      ArenaCard(id: 'diamonds_Q', rank: 'Q', suit: 'diamonds'),
      ArenaCard(id: 'diamonds_3', rank: '3', suit: 'diamonds'),
    ];

/// A stateful copy of _HandArea's fan layout (SingleChildScrollView >
/// Row > Align(widthFactor) / Transform, cards keyed by id), with
/// hooks to rebuild the hand and to remove cards — the two things a
/// live game does around a tap (socket broadcasts rebuild the screen;
/// a played card leaves the hand).
class TestHand extends StatefulWidget {
  const TestHand({
    super.key,
    required this.onPlay,
    required this.onIllegalTap,
  });

  final void Function(ArenaCard card) onPlay;
  final void Function(ArenaCard card) onIllegalTap;

  @override
  State<TestHand> createState() => TestHandState();
}

class TestHandState extends State<TestHand> {
  List<ArenaCard> hand = List.of(trick7Hand());
  bool dimmed = false;

  /// Rebuild with the same cards (a socket broadcast arriving).
  void rebuildSameHand() => setState(() {});

  /// Flip the playable state mid-gesture (the turn arriving or
  /// leaving while the pointer is down).
  void setDimmed(bool value) => setState(() => dimmed = value);

  /// Remove a card (a play leaving the hand) — this also flips the
  /// wrapper of the card that becomes last (Align -> bare Transform).
  void removeCard(String id) =>
      setState(() => hand.removeWhere((c) => c.id == id));

  @override
  Widget build(BuildContext context) {
    const cardWidth = 44.0;
    final n = hand.length;
    return MaterialApp(
      home: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final aw = constraints.maxWidth - 16;
            double widthFactor = 1.0;
            double overlapWidth = cardWidth;
            if (n > 1) {
              final maxOverlap = (aw - cardWidth) / (n - 1);
              overlapWidth = maxOverlap.clamp(20.0, cardWidth);
              widthFactor = overlapWidth / cardWidth;
            }
            final rowWidth = n == 0
                ? 0.0
                : (n - 1) * overlapWidth +
                    cardWidth +
                    n * 6 * (cardWidth / 70);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(aw, rowWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(n, (index) {
                    final card = hand[index];
                    final cardWidget = ArenaCardWidget(
                      key: ValueKey(card.id),
                      card: card,
                      powerSuit: 'spades',
                      isLegal: true,
                      onPlay: () => widget.onPlay(card),
                      onIllegalTap: () => widget.onIllegalTap(card),
                      dimmed: dimmed,
                      width: cardWidth,
                    );
                    Widget wrappedCard = Transform(
                      key: ValueKey(card.id),
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateZ(0.0),
                      alignment: Alignment.bottomCenter,
                      child: cardWidget,
                    );
                    // Round 12 production layout: every card gets the
                    // same Align wrapper (last card widthFactor 1.0).
                    return Align(
                      key: ValueKey(card.id),
                      widthFactor: index < n - 1 ? widthFactor : 1.0,
                      alignment: Alignment.centerLeft,
                      child: wrappedCard,
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Clicks the centre of the given card with the mouse, optionally
/// drifting [drift] pixels before release — a real mouse click is
/// rarely pixel-perfect.
Future<void> clickCard(
  WidgetTester tester,
  Finder card, {
  Offset drift = Offset.zero,
}) async {
  final gesture =
      await tester.startGesture(tester.getCenter(card), kind: PointerDeviceKind.mouse);
  if (drift != Offset.zero) await gesture.moveBy(drift);
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('clean mouse click on a middle card plays it', (tester) async {
    final played = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    await clickCard(tester, find.byWidgetPredicate((w) =>
        w is ArenaCardWidget && w.card.id == 'diamonds_Q'));
    expect(played, ['diamonds_Q']);
  });

  testWidgets('clean mouse click on the LAST card plays it', (tester) async {
    final played = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    await clickCard(tester, find.byWidgetPredicate((w) =>
        w is ArenaCardWidget && w.card.id == 'diamonds_3'));
    expect(played, ['diamonds_3']);
  });

  testWidgets('mouse click that drifts 2px still plays the card',
      (tester) async {
    final played = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    await clickCard(tester, find.byWidgetPredicate((w) =>
        w is ArenaCardWidget && w.card.id == 'diamonds_3'),
        drift: const Offset(2, 1));
    expect(played, ['diamonds_3']);
  });

  testWidgets('touch tap that drifts 2px still plays the card',
      (tester) async {
    final played = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byWidgetPredicate((w) =>
          w is ArenaCardWidget && w.card.id == 'diamonds_3')),
    );
    await gesture.moveBy(const Offset(2, 1));
    await gesture.up();
    await tester.pump();
    expect(played, ['diamonds_3']);
  });

  testWidgets('rebuild between pointer-down and pointer-up still plays',
      (tester) async {
    final played = <String>[];
    late TestHandState state;
    await tester.pumpWidget(TestHand(
      key: GlobalKey<TestHandState>(),
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    state = tester.state(find.byType(TestHand));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byWidgetPredicate((w) =>
          w is ArenaCardWidget && w.card.id == 'diamonds_3')),
      kind: PointerDeviceKind.mouse,
    );
    // A socket broadcast lands mid-tap and rebuilds the whole hand
    // with fresh onPlay closures.
    state.rebuildSameHand();
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(played, ['diamonds_3']);
  });

  testWidgets('hand shrink between down and up still plays a middle card',
      (tester) async {
    final played = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    late TestHandState state;
    state = tester.state(find.byType(TestHand));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byWidgetPredicate((w) =>
          w is ArenaCardWidget && w.card.id == 'diamonds_Q')),
      kind: PointerDeviceKind.mouse,
    );
    // Another card leaves the hand mid-tap (a play resolving).
    state.removeCard('diamonds_3');
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(played, ['diamonds_Q']);
  });

  testWidgets('tap on the card that just became last still plays',
      (tester) async {
    final played = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    late TestHandState state;
    state = tester.state(find.byType(TestHand));
    // 3D was last; Q becomes last when 3D leaves. Tap Q after that
    // wrapper switch (Align -> bare Transform) — its Element was
    // unmounted and remounted, so its gesture state must be fresh.
    state.removeCard('diamonds_3');
    await tester.pump();
    await clickCard(tester, find.byWidgetPredicate((w) =>
        w is ArenaCardWidget && w.card.id == 'diamonds_Q'));
    expect(played, ['diamonds_Q']);
  });

  testWidgets('click during the hover-raise animation still plays',
      (tester) async {
    final played = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    final center = tester.getCenter(find.byWidgetPredicate((w) =>
        w is ArenaCardWidget && w.card.id == 'diamonds_3'));
    // Real hover onto the card (starts the 200ms -12px raise), then
    // click before the animation finishes.
    tester.binding.handlePointerEvent(
      PointerHoverEvent(position: center),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final click = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
    await click.up();
    await tester.pump();
    expect(played, ['diamonds_3']);
  });

  testWidgets('turn arrives between down and up: tap still plays',
      (tester) async {
    final played = <String>[];
    final illegal = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (c) => illegal.add(c.id),
    ));
    await tester.pump();
    final state = tester.state<TestHandState>(find.byType(TestHand));
    state.setDimmed(true); // not my turn yet
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byWidgetPredicate((w) =>
          w is ArenaCardWidget && w.card.id == 'diamonds_3')),
      kind: PointerDeviceKind.mouse,
    );
    state.setDimmed(false); // turn arrives mid-tap
    await tester.pump();
    await gesture.up();
    await tester.pump();
    // Either outcome is a visible one; silence is the bug.
    expect(played + illegal, ['diamonds_3']);
  });

  testWidgets('turn leaves between down and up: tap still says why',
      (tester) async {
    final played = <String>[];
    final illegal = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (c) => illegal.add(c.id),
    ));
    await tester.pump();
    final state = tester.state<TestHandState>(find.byType(TestHand));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byWidgetPredicate((w) =>
          w is ArenaCardWidget && w.card.id == 'diamonds_3')),
      kind: PointerDeviceKind.mouse,
    );
    state.setDimmed(true); // turn leaves mid-tap
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(played + illegal, ['diamonds_3']);
  });

  testWidgets('touch scroll-drag across the hand must NOT play a card',
      (tester) async {
    final played = <String>[];
    await tester.pumpWidget(TestHand(
      onPlay: (c) => played.add(c.id),
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byWidgetPredicate((w) =>
          w is ArenaCardWidget && w.card.id == 'diamonds_3')),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.up();
    await tester.pump();
    expect(played, isEmpty);
  });

  testWidgets('card that becomes last keeps its Element (no remount)',
      (tester) async {
    await tester.pumpWidget(TestHand(
      onPlay: (_) {},
      onIllegalTap: (_) {},
    ));
    await tester.pump();
    final state = tester.state<TestHandState>(find.byType(TestHand));
    final before = tester.state(find.byWidgetPredicate((w) =>
        w is ArenaCardWidget && w.card.id == 'diamonds_Q'));
    // Removing the last card (3D) makes Q the last card — its wrapper
    // switches from Align to bare Transform. If its Element is
    // unmounted and remounted, any tap in flight on Q dies silently.
    state.removeCard('diamonds_3');
    await tester.pump();
    final after = tester.state(find.byWidgetPredicate((w) =>
        w is ArenaCardWidget && w.card.id == 'diamonds_Q'));
    expect(identical(before, after), isTrue);
  });
}
