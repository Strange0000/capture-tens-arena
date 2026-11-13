import 'package:flutter/material.dart';

import '../models/match_state.dart';
import '../theme.dart';

/// Premium centred game header — Round 4.
///
/// Round 3 left a slim but ugly bar: one full-width rectangle with raw
/// data crammed into a single line ("A 2 — 2 B · 16–32 cards · 1–3 aces
/// | DIAMONDS | TRICK 13 / 13 | Last trick: Cipher · Team B"). It read
/// like a spreadsheet row, and "16–32 cards · 1–3 aces" confused
/// players — which team has which, and why does it matter?
///
/// This is now a compact CENTRED floating pill (not edge-to-edge):
/// dark glass, gold border, clear hierarchy, plain words a new player
/// instantly gets — no jargon, no confusing raw numbers.
///
/// Layout (two compact rows, still slim — ~66px tall):
///   Row 1 — the game at a glance:
///     "TENS CAPTURED" label + big score "A 2 — 2 B" (leader gold)
///     + a plain-words status pill: "Tied 2–2" or "Team A leads"
///     + Trump chip ("Trump: ♦ Diamonds")
///     + Trick progress ("Trick 13 of 13" + a small progress bar)
///   Row 2 — small secondary line, only what matters right now:
///     "Last trick won by Cipher · Team B"
///     + the tiebreaker, ONLY when tens are tied, in plain words:
///       "Cards: Team A 16, Team B 32" (and aces too, only if the
///       cards are also tied — aces only decide when cards tie).
///     When tens are not tied, cards/aces are hidden: they do not
///     decide anything, so showing them only adds confusion.
/// Tiebreaker order (unchanged rules): most tens, then most cards,
/// then most aces.
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

    final aLeads = captures.a.tens > captures.b.tens;
    final bLeads = captures.b.tens > captures.a.tens;
    final tensTied = !aLeads && !bLeads;
    final trickNumber = (completedTricks + 1).clamp(1, 13);
    final progress = (completedTricks.clamp(0, 13)) / 13;

    // Plain-words status, obvious at a glance.
    final String statusText;
    if (tensTied) {
      statusText = 'Tied ${captures.a.tens}–${captures.b.tens}';
    } else if (aLeads) {
      statusText = 'Team A leads';
    } else {
      statusText = 'Team B leads';
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 4),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10192A).withOpacity(0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ArenaColors.gold.withOpacity(0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: trickWinnerMessage != null
                  ? SizedBox(
                      key: ValueKey(trickWinnerMessage),
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
                                color: ArenaColors.goldSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      key: const ValueKey('score_card'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1) Tens score — the headline. Fixed Team A /
                            // Team B order (not swapped by myTeam), so
                            // "A 2 — 1 B" always means the same thing.
                            // The leading side is gold.
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'TENS CAPTURED',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white38,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'A ${captures.a.tens}',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          color: aLeads
                                              ? ArenaColors.gold
                                              : Colors.white,
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          '—',
                                          style: TextStyle(fontSize: 13, color: Colors.white38),
                                        ),
                                      ),
                                      Text(
                                        '${captures.b.tens} B',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          color: bLeads
                                              ? ArenaColors.gold
                                              : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Plain-words leader / tie state.
                            _StatusPill(text: statusText, isTie: tensTied),
                            const SizedBox(width: 10),
                            const _Divider(),
                            const SizedBox(width: 10),
                            // 2) Trump — the only trump indicator; the
                            // floating "SPADES TRUMP" pill that used to
                            // sit over the hand is gone.
                            if (powerSuit != null)
                              _TrumpChip(suit: powerSuit!)
                            else
                              const Text(
                                'Trump\nnot chosen yet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: ArenaColors.gold,
                                  height: 1.2,
                                ),
                              ),
                            const SizedBox(width: 10),
                            const _Divider(),
                            const SizedBox(width: 10),
                            // 3) Trick progress — plain words + a bar,
                            // not just "13 / 13".
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Trick $trickNumber of 13',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: ArenaColors.cyan,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: isMobile ? 44 : 64,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: ArenaColors.gold,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // 4) Secondary line — only what matters now.
                        // Last trick, plus the tiebreaker in plain
                        // words, ONLY when tens are tied.
                        if (lastTrickWinnerLabel != null || tensTied) ...[
                          const SizedBox(height: 5),
                          Container(
                            height: 1,
                            color: Colors.white10,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (lastTrickWinnerLabel != null)
                                Flexible(
                                  child: Text(
                                    'Last trick won by $lastTrickWinnerLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: ArenaColors.goldSoft,
                                    ),
                                  ),
                                ),
                              if (lastTrickWinnerLabel != null && tensTied)
                                const SizedBox(width: 8),
                              if (tensTied)
                                Flexible(
                                  child: Text(
                                    _tiebreakerText(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tiebreaker in plain words, only called when tens are tied.
  /// Cards decide first; aces only matter if the cards are tied too,
  /// so aces are shown only in that case.
  String _tiebreakerText() {
    final cards = 'Cards: Team A ${captures.a.cards}, Team B ${captures.b.cards}';
    if (captures.a.cards == captures.b.cards) {
      return '$cards · Aces: Team A ${captures.a.aces}, Team B ${captures.b.aces}';
    }
    return cards;
  }
}

/// Thin vertical separator between header groups.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 26, color: Colors.white12);
  }
}

/// Plain-words status pill: "Tied 2–2" (neutral) or "Team A leads"
/// (gold tint, so the leader is obvious without reading numbers).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.isTie});
  final String text;
  final bool isTie;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTie
            ? Colors.white.withOpacity(0.08)
            : ArenaColors.gold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTie
              ? Colors.white24
              : ArenaColors.gold.withOpacity(0.45),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isTie ? Colors.white70 : ArenaColors.gold,
        ),
      ),
    );
  }
}

/// Trump chip with a plain label: "TRUMP" + suit icon + suit name.
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TRUMP',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w800,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(symbol, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(
                suit[0].toUpperCase() + suit.substring(1).toLowerCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
