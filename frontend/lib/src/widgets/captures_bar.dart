import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/match_state.dart';

/// Luxury esports arena scoreboard with team glowing badges, live trick tracker,
/// and trump suit indicator.
class CapturesBar extends StatelessWidget {
  const CapturesBar({
    super.key,
    required this.captures,
    required this.completedTricks,
    this.myTeam = 'A',
    this.powerSuit,
    this.trickWinnerMessage,
  });

  final MatchCaptures captures;
  final int completedTricks;
  final String myTeam;
  final String? powerSuit;
  final String? trickWinnerMessage;

  @override
  Widget build(BuildContext context) {
    final isTeamA = myTeam.toUpperCase() == 'A';
    final myCaptures = isTeamA ? captures.a : captures.b;
    final rivalCaptures = isTeamA ? captures.b : captures.a;
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 450;
    final myLabel = isMobile
        ? (isTeamA ? 'SQUAD A' : 'SQUAD B')
        : (isTeamA ? 'YOUR SQUAD (A)' : 'YOUR SQUAD (B)');
    final rivalLabel = isMobile
        ? (isTeamA ? 'RIVALS B' : 'RIVALS A')
        : (isTeamA ? 'RIVALS (B)' : 'RIVALS (A)');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12, vertical: isMobile ? 4 : 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: isMobile ? 6 : 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF131F35).withOpacity(0.85),
                  const Color(0xFF090E1A).withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Your Squad (Left)
                Expanded(
                  child: _TeamScoreSection(
                    teamTitle: myLabel,
                    isMyTeam: true,
                    captures: myCaptures,
                    accentColor: const Color(0xFF48E5C2),
                    alignment: CrossAxisAlignment.start,
                  ),
                ),

                // Center Trick & Power Suit Hub
                _CenterMatchHub(
                  completedTricks: completedTricks,
                  powerSuit: powerSuit,
                  trickWinnerMessage: trickWinnerMessage,
                ),

                // Rival Squad (Right)
                Expanded(
                  child: _TeamScoreSection(
                    teamTitle: rivalLabel,
                    isMyTeam: false,
                    captures: rivalCaptures,
                    accentColor: const Color(0xFFFF6B6B),
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Center Match Hub ─────────────────────────────────────────────────────────

class _CenterMatchHub extends StatelessWidget {
  const _CenterMatchHub({
    required this.completedTricks,
    required this.powerSuit,
    this.trickWinnerMessage,
  });

  final int completedTricks;
  final String? powerSuit;
  final String? trickWinnerMessage;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: trickWinnerMessage != null
            ? const Color(0xFFF5A623).withOpacity(0.18)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: trickWinnerMessage != null
              ? const Color(0xFFFFD166).withOpacity(0.8)
              : Colors.white.withOpacity(0.08),
          width: trickWinnerMessage != null ? 1.5 : 1.0,
        ),
        boxShadow: trickWinnerMessage != null
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD166).withOpacity(0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: trickWinnerMessage != null
            ? Padding(
                key: ValueKey(trickWinnerMessage),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      trickWinnerMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                key: const ValueKey('normal_center'),
                mainAxisSize: MainAxisSize.min,
                children: [
          // Trump / Power Suit Badge or Trick Index
          if (powerSuit != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _suitIcon(powerSuit!),
                const SizedBox(width: 5),
                Text(
                  powerSuit!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: _suitColor(powerSuit!),
                  ),
                ),
              ],
            )
          else
            const Text(
              'POWER SUIT PENDING',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFC857),
                letterSpacing: 1,
              ),
            ),

          const SizedBox(height: 5),

          // 13-trick segmented LED tracker
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(13, (i) {
              final done = i < completedTricks;
              final isCurrent = i == completedTricks;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isCurrent ? 7 : 5,
                height: isCurrent ? 7 : 5,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF48E5C2)
                      : isCurrent
                          ? const Color(0xFFFFC857)
                          : Colors.white.withOpacity(0.12),
                  boxShadow: done || isCurrent
                      ? [
                          BoxShadow(
                            color: (done ? const Color(0xFF48E5C2) : const Color(0xFFFFC857)).withOpacity(0.8),
                            blurRadius: 6,
                          )
                        ]
                      : [],
                ),
              );
            }),
          ),

          const SizedBox(height: 4),

          // Trick Number Counter
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              children: [
                const TextSpan(text: 'TRICK ', style: TextStyle(color: Colors.white38)),
                TextSpan(
                  text: '${(completedTricks + 1).clamp(1, 13)}',
                  style: const TextStyle(color: Color(0xFF48E5C2)),
                ),
                const TextSpan(text: ' / 13', style: TextStyle(color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _suitIcon(String suit) {
    final symbol = switch (suit.toLowerCase()) {
      'hearts' => '♥',
      'diamonds' => '♦',
      'clubs' => '♣',
      _ => '♠',
    };
    final color = _suitColor(suit);
    return Text(
      symbol,
      style: TextStyle(
        fontSize: 14,
        color: color,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: color.withOpacity(0.8), blurRadius: 6),
        ],
      ),
    );
  }

  Color _suitColor(String suit) => switch (suit) {
        'hearts' => const Color(0xFFFF5252),
        'diamonds' => const Color(0xFFFF7043),
        'clubs' => const Color(0xFF81D4FA),
        _ => const Color(0xFFB388FF),
      };
}

// ── Team Score Section ───────────────────────────────────────────────────────

class _TeamScoreSection extends StatelessWidget {
  const _TeamScoreSection({
    required this.teamTitle,
    required this.isMyTeam,
    required this.captures,
    required this.accentColor,
    required this.alignment,
  });

  final String teamTitle;
  final bool isMyTeam;
  final TeamCaptures captures;
  final Color accentColor;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.8), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              teamTitle,
              style: TextStyle(
                fontSize: 10,
                color: accentColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: alignment == CrossAxisAlignment.start ? WrapAlignment.start : WrapAlignment.end,
          children: [
            // Tens Captured (Key Metric)
            _GlowingScoreBadge(
              iconText: '🔟',
              count: captures.tens,
              highlight: captures.tens > 0,
              badgeColor: const Color(0xFFFFD166),
              tooltip: 'Tens Captured (Target: Win on Tens)',
            ),
            // Total Cards Captured
            _GlowingScoreBadge(
              iconText: '🂠',
              count: captures.cards,
              highlight: false,
              badgeColor: Colors.white,
              tooltip: 'Total Cards (Tie-Breaker)',
            ),
            // Aces Captured
            _GlowingScoreBadge(
              iconText: 'A',
              count: captures.aces,
              highlight: captures.aces > 0,
              badgeColor: const Color(0xFF48E5C2),
              tooltip: 'Aces Captured (Second Tie-Breaker)',
            ),
          ],
        ),
      ],
    );
  }
}

// ── Glowing Score Badge ─────────────────────────────────────────────────────

class _GlowingScoreBadge extends StatelessWidget {
  const _GlowingScoreBadge({
    required this.iconText,
    required this.count,
    required this.highlight,
    required this.badgeColor,
    required this.tooltip,
  });

  final String iconText;
  final int count;
  final bool highlight;
  final Color badgeColor;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: highlight ? badgeColor.withOpacity(0.18) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight ? badgeColor.withOpacity(0.6) : Colors.white.withOpacity(0.1),
            width: highlight ? 1.2 : 0.8,
          ),
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: badgeColor.withOpacity(0.25),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              iconText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: highlight ? badgeColor : Colors.white54,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: highlight ? badgeColor : Colors.white70,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
