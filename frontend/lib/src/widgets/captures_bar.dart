import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/match_state.dart';

/// Premium glassmorphism scoreboard.
class CapturesBar extends StatelessWidget {
  const CapturesBar({super.key, required this.captures, required this.completedTricks});

  final MatchCaptures captures;
  final int completedTricks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12),
              ],
            ),
            child: Row(
              children: [
                _TeamScore(label: 'TEAM A', captures: captures.a, alignment: CrossAxisAlignment.start),
                const Spacer(),
                _TrickProgress(completedTricks: completedTricks),
                const Spacer(),
                _TeamScore(label: 'TEAM B', captures: captures.b, alignment: CrossAxisAlignment.end),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrickProgress extends StatelessWidget {
  const _TrickProgress({required this.completedTricks});
  final int completedTricks;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(13, (i) {
            final done = i < completedTricks;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: done ? 6 : 4,
              height: done ? 6 : 4,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? const Color(0xFF48E5C2) : Colors.white.withOpacity(0.15),
                boxShadow: done
                    ? [BoxShadow(color: const Color(0xFF48E5C2).withOpacity(0.6), blurRadius: 6)]
                    : [],
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
            children: [
              TextSpan(text: '$completedTricks', style: const TextStyle(color: Color(0xFF48E5C2))),
              const TextSpan(text: ' / 13', style: TextStyle(color: Colors.white30)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({required this.label, required this.captures, required this.alignment});
  final String label;
  final TeamCaptures captures;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(
          fontSize: 9, color: Colors.white38, fontWeight: FontWeight.w800, letterSpacing: 2,
        )),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScorePill(icon: '🔟', count: captures.tens, highlight: captures.tens > 0, highlightColor: const Color(0xFFFFC857)),
            const SizedBox(width: 5),
            _ScorePill(icon: '🃏', count: captures.cards, highlight: false, highlightColor: Colors.white),
            const SizedBox(width: 5),
            _ScorePill(icon: 'A', count: captures.aces, highlight: captures.aces > 0, highlightColor: const Color(0xFF48E5C2)),
          ],
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.icon, required this.count, required this.highlight, required this.highlightColor});
  final String icon;
  final int count;
  final bool highlight;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: highlight ? highlightColor.withOpacity(0.15) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: highlight ? highlightColor.withOpacity(0.4) : Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: highlight ? highlightColor : Colors.white38,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
