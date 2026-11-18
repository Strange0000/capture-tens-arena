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
    this.teammateName,
    this.opponentNames,
  });

  final MatchCaptures captures;
  final int completedTricks;
  final String myTeam;
  final String? powerSuit;
  final String? trickWinnerMessage;
  final String? teammateName;
  final String? opponentNames;

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
                  myTeam: myTeam,
                  isMobile: isMobile,
                  powerSuit: powerSuit,
                  lastTrickWinnerLabel: lastTrickWinnerLabel,
                  tiebreakerText: _tiebreakerText(),
                  teammateName: teammateName,
                  opponentNames: opponentNames,
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
    final isMyTeamA = myTeam == 'A';
    final myCards = isMyTeamA ? captures.a.cards : captures.b.cards;
    final oppCards = isMyTeamA ? captures.b.cards : captures.a.cards;
    final myAces = isMyTeamA ? captures.a.aces : captures.b.aces;
    final oppAces = isMyTeamA ? captures.b.aces : captures.a.aces;
    return 'Cards: You $myCards, Opp $oppCards · Aces: You $myAces, Opp $oppAces';
  }
}


/// The score rows — always visible, even while the trick-winner banner
/// shows below them. (Round 4 bug: the banner REPLACED the whole pill,
/// so the score vanished for a few seconds every trick.)
class _ScoreRows extends StatelessWidget {
  const _ScoreRows({
    required this.captures,
    required this.completedTricks,
    required this.myTeam,
    required this.isMobile,
    required this.powerSuit,
    required this.lastTrickWinnerLabel,
    required this.tiebreakerText,
    this.teammateName,
    this.opponentNames,
  });

  final MatchCaptures captures;
  final int completedTricks;
  final String myTeam;
  final bool isMobile;
  final String? powerSuit;
  final String? lastTrickWinnerLabel;
  final String tiebreakerText;
  final String? teammateName;
  final String? opponentNames;

  @override
  Widget build(BuildContext context) {
    final isMyTeamA = myTeam == 'A';
    final myTens = isMyTeamA ? captures.a.tens : captures.b.tens;
    final oppTens = isMyTeamA ? captures.b.tens : captures.a.tens;
    final youLead = myTens > oppTens;
    final oppLeads = oppTens > myTens;
    final tensTied = myTens == oppTens;
    final trickNumber = (completedTricks + 1).clamp(1, 13);
    final progress = (completedTricks.clamp(0, 13)) / 13;
    final statusText = tensTied
        ? 'Tied $myTens–$oppTens'
        : youLead
            ? 'You Lead'
            : 'Opponents Lead';

    final teamNamesLabel = teammateName != null
        ? 'YOU & $teammateName'
        : 'YOUR TEAM';
    final oppNamesLabel = opponentNames != null
        ? opponentNames!
        : 'OPPONENTS';

    return Column(
      key: const ValueKey('score_card'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1) Tens score — You vs Opponents with Team indicator
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: ArenaColors.emerald.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: ArenaColors.emerald.withOpacity(0.6), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 5, height: 5, decoration: const BoxDecoration(color: ArenaColors.emerald, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(
                              teamNamesLabel,
                              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: ArenaColors.emerald, letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('vs', style: TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: ArenaColors.ruby.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: ArenaColors.ruby.withOpacity(0.6), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 5, height: 5, decoration: const BoxDecoration(color: ArenaColors.ruby, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(
                              oppNamesLabel,
                              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFFF8585), letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$myTens',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: youLead ? ArenaColors.emerald : (oppLeads ? Colors.white70 : Colors.white),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          '—',
                          style: TextStyle(fontSize: 14, color: Colors.white38),
                        ),
                      ),
                      Text(
                        '$oppTens',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: oppLeads ? ArenaColors.ruby : (youLead ? Colors.white70 : Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '10s',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.55)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Plain-words leader / tie state.
            _StatusPill(text: statusText, isTie: tensTied, isLead: youLead),
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
                    ? lastTrickWinnerLabel!
                    : (teammateName != null
                        ? '🟢 You & $teammateName vs 🔴 $opponentNames'
                        : 'No tricks played yet'),
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

/// Plain-words status pill: "Tied 2–2" (neutral), "You Lead" (emerald),
/// or "Opponents Lead" (ruby).
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.isTie,
    this.isLead = false,
  });
  final String text;
  final bool isTie;
  final bool isLead;

  @override
  Widget build(BuildContext context) {
    final bg = isTie
        ? Colors.white.withOpacity(0.08)
        : isLead
            ? ArenaColors.emerald.withOpacity(0.18)
            : ArenaColors.ruby.withOpacity(0.18);
    final border = isTie
        ? Colors.white24
        : isLead
            ? ArenaColors.emerald.withOpacity(0.55)
            : ArenaColors.ruby.withOpacity(0.55);
    final fg = isTie
        ? Colors.white70
        : isLead
            ? ArenaColors.emerald
            : const Color(0xFFFF8585);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: fg,
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
