import 'package:flutter/material.dart';

import '../models/match_state.dart';
import 'arena_card_widget.dart';

/// Renders the 4 cards of the current trick in a cross layout.
/// Winner gets a golden glow. No animation controllers = no jank.
class TrickArea extends StatelessWidget {
  const TrickArea({super.key, required this.trick, required this.powerSuit});

  final CurrentTrick trick;
  final String? powerSuit;

  @override
  Widget build(BuildContext context) {
    final Map<int, TrickPlay> bySeats = {
      for (final play in trick.plays) play.seat: play,
    };

    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Seat 2 → top
          if (bySeats[2] != null)
            Positioned(top: 0, left: 0, right: 0,
              child: Center(child: _PlayedCard(play: bySeats[2]!, powerSuit: powerSuit, isWinner: trick.winnerSeat == 2))),

          // Seat 1 → right
          if (bySeats[1] != null)
            Positioned(right: 0, top: 0, bottom: 0,
              child: Center(child: _PlayedCard(play: bySeats[1]!, powerSuit: powerSuit, isWinner: trick.winnerSeat == 1))),

          // Seat 3 → left
          if (bySeats[3] != null)
            Positioned(left: 0, top: 0, bottom: 0,
              child: Center(child: _PlayedCard(play: bySeats[3]!, powerSuit: powerSuit, isWinner: trick.winnerSeat == 3))),

          // Seat 0 → bottom
          if (bySeats[0] != null)
            Positioned(bottom: 0, left: 0, right: 0,
              child: Center(child: _PlayedCard(play: bySeats[0]!, powerSuit: powerSuit, isWinner: trick.winnerSeat == 0))),

          // Empty centre hint
          if (trick.plays.isEmpty)
            const Center(child: Text('Play a card', style: TextStyle(color: Colors.white24, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _PlayedCard extends StatelessWidget {
  const _PlayedCard({required this.play, required this.powerSuit, required this.isWinner});

  final TrickPlay play;
  final String? powerSuit;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: isWinner
            ? [BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.5), blurRadius: 16, spreadRadius: 2)]
            : [],
      ),
      child: ArenaCardWidget(
        card: play.card,
        powerSuit: powerSuit,
        onPlay: () {},
        small: true,
      ),
    );
  }
}
