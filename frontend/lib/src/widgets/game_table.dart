import 'dart:async';

import 'package:flutter/material.dart';

import '../models/match_state.dart';
import 'trick_area.dart';

/// Premium game table with velvet felt, gold trim, and clean player badges.
class GameTable extends StatelessWidget {
  const GameTable({super.key, required this.match, this.onCardPlayed});

  final MatchState match;
  final ValueChanged<String>? onCardPlayed;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Stack(
          children: [
            // Premium felt (transparent now, as it's the full background)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  // Background is handled by game_screen.dart now!
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, spreadRadius: 2),
                  ],
                ),
              ),
            ),

            // Inner border line (double border effect)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFD4A017).withOpacity(0.06),
                    width: 0.5,
                  ),
                ),
              ),
            ),

            // Player badges at four seats
            for (final player in match.players)
              _PlayerBadge(
                player: player,
                active: player.seat == match.currentTurnSeat,
                deadline: player.seat == match.currentTurnSeat ? match.turnDeadline : null,
              ),

            // Trick cards in centre
            Center(
              child: DragTarget<String>(
                onWillAcceptWithDetails: (_) => match.phase == 'playing',
                onAcceptWithDetails: (details) => onCardPlayed?.call(details.data),
                builder: (context, candidateData, rejectedData) {
                  if (match.currentTrick != null && (match.phase == 'playing' || match.phase == 'trick-resolving')) {
                    return TrickArea(
                      key: ValueKey(match.currentTrick!.index),
                      trick: match.currentTrick!,
                      powerSuit: match.powerSuit,
                    );
                  }
                  return _CentreLabel(match: match);
                },
              ),
            ),
          ],
        ),
      );
  }
}

class _CentreLabel extends StatelessWidget {
  const _CentreLabel({required this.match});
  final MatchState match;

  @override
  Widget build(BuildContext context) {
    final String text;
    final String? subText;
    if (match.phase == 'power-select') {
      text = '👑';
      subText = 'Choose power suit';
    } else if (match.powerSuit != null) {
      text = _suitEmoji(match.powerSuit!);
      subText = '${match.powerSuit!.toUpperCase()} POWER';
    } else {
      text = '';
      subText = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(fontSize: 36)),
        if (subText != null) ...[
          const SizedBox(height: 6),
          Text(subText, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            color: Color(0xFFFFC857), letterSpacing: 1.5,
          )),
          ],
        ],
      );
  }

  String _suitEmoji(String suit) => switch (suit) {
    'hearts' => '♥️',
    'diamonds' => '♦️',
    'clubs' => '♣️',
    'spades' => '♠️',
    _ => '🃏',
  };
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({required this.player, required this.active, this.deadline});

  final MatchPlayer player;
  final bool active;
  final int? deadline;

  Alignment get _alignment => switch (player.seat) {
        0 => Alignment.bottomCenter,
        1 => Alignment.centerRight,
        2 => Alignment.topCenter,
        _ => Alignment.centerLeft,
      };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _alignment,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: active && deadline != null
            ? _TimedBadge(player: player, deadline: deadline!)
            : _StaticBadge(player: player, active: active),
      ),
    );
  }
}

class _StaticBadge extends StatelessWidget {
  const _StaticBadge({required this.player, required this.active});
  final MatchPlayer player;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF48E5C2) : const Color(0xDD101826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !player.connected
              ? Colors.redAccent.withOpacity(0.6)
              : active
                  ? const Color(0xFF48E5C2)
                  : const Color(0xFFD4A017).withOpacity(0.15),
          width: active ? 1.5 : 0.5,
        ),
        boxShadow: active
            ? [BoxShadow(color: const Color(0xFF48E5C2).withOpacity(0.2), blurRadius: 12)]
            : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
      ),
      child: _BadgeContent(player: player, active: active),
    );
  }
}

class _TimedBadge extends StatefulWidget {
  const _TimedBadge({required this.player, required this.deadline});
  final MatchPlayer player;
  final int deadline;

  @override
  State<_TimedBadge> createState() => _TimedBadgeState();
}

class _TimedBadgeState extends State<_TimedBadge> {
  Timer? _timer;
  double _progress = 1.0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final remaining = widget.deadline - DateTime.now().millisecondsSinceEpoch;
    const total = 18000;
    if (!mounted) return;
    setState(() => _progress = (remaining / total).clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _progress > 0.4
        ? const Color(0xFF48E5C2)
        : _progress > 0.2
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF48E5C2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.6)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10)],
          ),
          child: _BadgeContent(player: widget.player, active: true),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeContent extends StatelessWidget {
  const _BadgeContent({required this.player, required this.active});
  final MatchPlayer player;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final textColor = active ? const Color(0xFF070B13) : Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (player.isBot)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(Icons.smart_toy_rounded, size: 13, color: textColor.withOpacity(0.6)),
          ),
        Text(
          player.username,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF070B13).withOpacity(0.15) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${player.cardCount}',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
