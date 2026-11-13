import 'package:flutter/material.dart';

import '../models/match_state.dart';

/// Slim one-row score strip — Round 3.
///
/// The old scoreboard was a ~130px tall panel (big headline + caption +
/// trump + 13 dots + trick counter + last-trick line + two side badge
/// columns). On a short screen it ate ~35% of the viewport and squeezed
/// the table into a cramped strip, which is why the chips and played
/// cards ended up piled on top of each other. This is now ONE row,
/// ~44px tall: live tens score, trump, trick number, last trick.
/// Same information, a fraction of the height — the table gets the
/// screen back.
class CapturesBar extends StatelessWidget {
  const CapturesBar({
    super.key,
    required this.captures,
    required this.completedTricks,
    this.myTeam = 'A',
    this.powerSuit,
    this.trickWinnerMessage,
    this.lastTrickWinnerLabel,
  });

  final MatchCaptures captures;
  final int completedTricks;
  final String myTeam;
  final String? powerSuit;
  final String? trickWinnerMessage;

  /// Persistent "Last trick: <name> · Team A" — unlike
  /// [trickWinnerMessage], this is never cleared after 2 seconds.
  final String? lastTrickWinnerLabel;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 450;
    final isWide = sw >= 600;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0B3D2E).withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.28), width: 1),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: trickWinnerMessage != null
              ? SizedBox(
                  key: ValueKey(trickWinnerMessage),
                  width: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          trickWinnerMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  key: const ValueKey('score_row'),
                  children: [
                    // Live tens score — the headline number of the game.
                    // Fixed Team A / Team B order (not swapped by myTeam),
                    // so "A 2 — 1 B" always means the same thing. The
                    // leading side is gold.
                    Text(
                      'A ${captures.a.tens}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: captures.a.tens > captures.b.tens
                            ? const Color(0xFFFFC857)
                            : Colors.white70,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Text('—', style: TextStyle(fontSize: 13, color: Colors.white38)),
                    ),
                    Text(
                      '${captures.b.tens} B',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: captures.b.tens > captures.a.tens
                            ? const Color(0xFFFFC857)
                            : Colors.white70,
                      ),
                    ),
                    // Tiebreaker detail (cards / aces) on wide screens
                    // only — it is detail, not the headline.
                    if (isWide) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· ${captures.a.cards}–${captures.b.cards} cards · ${captures.a.aces}–${captures.b.aces} aces',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38),
                      ),
                    ],
                    const SizedBox(width: 10),
                    // Trump / Power Suit — also the only trump indicator
                    // now; the floating "SPADES TRUMP" pill that used to
                    // sit over the hand in the table centre is gone.
                    if (powerSuit != null)
                      _TrumpChip(suit: powerSuit!)
                    else
                      const Text(
                        'POWER SUIT PENDING',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFFFC857), letterSpacing: 0.8),
                      ),
                    const SizedBox(width: 10),
                    // Trick number — the 13-dot tracker is gone; it cost
                    // a whole row for information "5 / 13" gives in 6 chars.
                    Text(
                      'TRICK ${(completedTricks + 1).clamp(1, 13)} / 13',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF48E5C2), letterSpacing: 0.6),
                    ),
                    // Last trick — flexible so it truncates instead of
                    // pushing the score off the row on narrow screens.
                    if (lastTrickWinnerLabel != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Last trick: $lastTrickWinnerLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFFD166)),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Compact trump chip for the slim score strip.
class _TrumpChip extends StatelessWidget {
  const _TrumpChip({required this.suit});
  final String suit;

  @override
  Widget build(BuildContext context) {
    final symbol = switch (suit.toLowerCase()) {
      'hearts' => '♥',
      'diamonds' => '♦',
      'clubs' => '♣',
      _ => '♠',
    };
    final color = switch (suit.toLowerCase()) {
      'hearts' => const Color(0xFFFF5252),
      'diamonds' => const Color(0xFFFF7043),
      'clubs' => const Color(0xFF81D4FA),
      _ => const Color(0xFFD7DEE8),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(symbol, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(
            suit.toUpperCase(),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
