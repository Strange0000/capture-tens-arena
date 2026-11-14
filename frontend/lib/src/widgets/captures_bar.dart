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
///   Row 2 — small secondary line, ALWAYS visible now (Round 10):
///     "Last trick won by Cipher · Team B" (or "No tricks played
///     yet" before the first trick) + the cards/aces count in plain
///     words: "Cards: Team A 16, Team B 32" (and aces too, only if
///     the cards are also tied — aces only decide when cards tie).
///     It used to appear only while the tens were tied / right after
///     a trick, so the pill kept collapsing to two lines mid-trick
///     and the Cards/Aces score was invisible most of the game.
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
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF123527), Color(0xFF0B241A)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ArenaColors.gold.withOpacity(0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScoreRows(
                  captures: captures,
                  completedTricks: completedTricks,
                  isMobile: isMobile,
                  powerSuit: powerSuit,
                  lastTrickWinnerLabel: lastTrickWinnerLabel,
                  tiebreakerText: _tiebreakerText(),
                ),
                if (trickWinnerMessage != null) ...[
                  const SizedBox(height: 5),
                  Container(height: 1, color: Colors.white10),
                  const SizedBox(height: 4),
                  Row(
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
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ArenaColors.goldSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
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
    );
  }

  /// Cards/aces count in plain words, always shown (Round 10/11).
  /// Cards decide the tiebreaker first; aces only matter if the cards
  /// are tied too — but both counts are always displayed, so the pill
  /// never loses a segment mid-game.
  String _tiebreakerText() {
    // Round 11: aces used to be shown only when the card counts were
    // tied — so in a real game they vanished after trick 2 (cards
    // were never tied again in tricks 5-13) and only reappeared in
    // the end modal. Cards and aces are both part of the score now,
    // always visible like the Cards line.
    return 'Cards: Team A ${captures.a.cards}, Team B ${captures.b.cards} '
        '· Aces: Team A ${captures.a.aces}, Team B ${captures.b.aces}';
  }
}


/// The score rows — always visible, even while the trick-winner banner
/// shows below them. (Round 4 bug: the banner REPLACED the whole pill,
/// so the score vanished for a few seconds every trick.)
class _ScoreRows extends StatelessWidget {
  const _ScoreRows({
    required this.captures,
    required this.completedTricks,
    required this.isMobile,
    required this.powerSuit,
    required this.lastTrickWinnerLabel,
    required this.tiebreakerText,
  });

  final MatchCaptures captures;
  final int completedTricks;
  final bool isMobile;
  final String? powerSuit;
  final String? lastTrickWinnerLabel;
  final String tiebreakerText;

  @override
  Widget build(BuildContext context) {
    final aLeads = captures.a.tens > captures.b.tens;
    final bLeads = captures.b.tens > captures.a.tens;
    final tensTied = !aLeads && !bLeads;
    final trickNumber = (completedTricks + 1).clamp(1, 13);
    final progress = (completedTricks.clamp(0, 13)) / 13;
    final statusText = tensTied
        ? 'Tied ${captures.a.tens}–${captures.b.tens}'
        : aLeads
            ? 'Team A leads'
            : 'Team B leads';


    return Column(
      key: const ValueKey('score_card'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1) Tens score — the headline. Fixed Team A / Team B order
            // (not swapped by myTeam), so "A 2 — 1 B" always means the
            // same thing. The leading side is gold.
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
                          color: aLeads ? ArenaColors.gold : Colors.white,
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
                          color: bLeads ? ArenaColors.gold : Colors.white,
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
            // 2) Trump — the only trump indicator.
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
            // 3) Trick progress — plain words + a bar, not just "13 / 13".
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trick $trickNumber of 13',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ArenaColors.gold,
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
        // 4) Secondary line — always visible (Round 10). Before the
        // first trick there is no last trick yet, so that half says
        // so instead of vanishing and collapsing the pill.
        const SizedBox(height: 5),
        Container(height: 1, color: Colors.white10),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                lastTrickWinnerLabel != null
                    ? 'Last trick won by $lastTrickWinnerLabel'
                    : 'No tricks played yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ArenaColors.goldSoft,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tiebreakerText,
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
    );
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
