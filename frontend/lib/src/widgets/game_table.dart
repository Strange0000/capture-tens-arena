import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/match_state.dart';
import '../services/audio_service.dart';
import 'trick_area.dart';

/// Clean arena game table that layers directly and seamlessly over the cyber-velvet table art.
/// Positions 4 player seat pods naturally around the rails with illuminated drop zone in the spotlight.
class GameTable extends StatelessWidget {
  const GameTable({
    super.key,
    required this.match,
    required this.mySeat,
    this.onCardPlayed,
    this.tilt3d = false,
  });

  final MatchState match;
  final int mySeat;
  final ValueChanged<String>? onCardPlayed;
  final bool tilt3d;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          // Center Trick Area & Drag-and-Drop Drop Zone
          Center(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (_) => match.phase == 'playing',
              onAcceptWithDetails: (details) {
                AudioService.instance.playCardPlace();
                AudioService.instance.hapticMedium();
                onCardPlayed?.call(details.data);
              },
              builder: (context, candidateData, rejectedData) {
                final isHoveredWithCard = candidateData.isNotEmpty;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Illuminated drop zone ring when dragging a card
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isHoveredWithCard ? 260 : 210,
                      height: isHoveredWithCard ? 260 : 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isHoveredWithCard
                            ? const Color(0xFF48E5C2).withOpacity(0.18)
                            : Colors.transparent,
                        border: Border.all(
                          color: isHoveredWithCard
                              ? const Color(0xFF48E5C2)
                              : Colors.white.withOpacity(0.06),
                          width: isHoveredWithCard ? 2.5 : 1.0,
                        ),
                        boxShadow: isHoveredWithCard
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF48E5C2).withOpacity(0.4),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: isHoveredWithCard
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_downward_rounded,
                                      color: Color(0xFF48E5C2), size: 30),
                                  const SizedBox(height: 6),
                                  Text(
                                    'RELEASE TO PLAY',
                                    style: TextStyle(
                                      color: const Color(0xFF48E5C2),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          color: const Color(0xFF48E5C2).withOpacity(0.8),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),

                    // Trick cards in centre
                    if (match.currentTrick != null &&
                        (match.phase == 'playing' || match.phase == 'trick-resolving'))
                      TrickArea(
                        key: ValueKey(match.currentTrick!.index),
                        trick: match.currentTrick!,
                        powerSuit: match.powerSuit,
                        mySeat: mySeat,
                      )
                    else
                      _TableCenterEmblem(
                        match: match,
                        isMyTurn: match.players.any(
                          (p) => p.seat == match.currentTurnSeat && p.seat == mySeat,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Four Player Seat Pods positioned directly on the table rails
          for (final player in match.players)
            _PlayerBadge(
              player: player,
              mySeat: mySeat,
              active: player.seat == match.currentTurnSeat,
              deadline: player.seat == match.currentTurnSeat ? match.turnDeadline : null,
              isLead: match.currentTrick != null &&
                  match.currentTrick!.plays.isEmpty &&
                  player.seat == match.currentTurnSeat,
            ),
        ],
      ),
    );
  }
}

// ── Table Center Emblem ──────────────────────────────────────────────────────

class _TableCenterEmblem extends StatelessWidget {
  const _TableCenterEmblem({required this.match, required this.isMyTurn});
  final MatchState match;
  final bool isMyTurn;

  @override
  Widget build(BuildContext context) {
    if (match.phase == 'power-select') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A2C).withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('👑', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'SELECTING TRUMP SUIT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD166),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (match.powerSuit != null) {
      final suit = match.powerSuit!;
      final symbol = switch (suit) {
        'hearts' => '♥',
        'diamonds' => '♦',
        'clubs' => '♣',
        _ => '♠',
      };
      final color = switch (suit) {
        'hearts' => const Color(0xFFFF5252),
        'diamonds' => const Color(0xFFFF7043),
        'clubs' => const Color(0xFF81D4FA),
        _ => const Color(0xFFB388FF),
      };

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1220).withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.35), width: 1.2),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.15), blurRadius: 16),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(symbol, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(
                  '${suit.toUpperCase()} TRUMP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMyTurn ? 'YOUR TURN · PLAY A CARD' : 'Waiting for turn...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMyTurn ? FontWeight.w900 : FontWeight.w600,
              color: isMyTurn ? const Color(0xFF48E5C2) : Colors.white24,
              letterSpacing: 1.0,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Player Seat Badge ────────────────────────────────────────────────────────

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.player,
    required this.mySeat,
    required this.active,
    this.deadline,
    this.isLead = false,
  });

  final MatchPlayer player;
  final int mySeat;
  final bool active;
  final int? deadline;
  final bool isLead;

  Alignment get _alignment {
    final relativeSeat = (player.seat - mySeat + 4) % 4;
    return switch (relativeSeat) {
      0 => const Alignment(0.0, 0.98),   // Bottom (You) - lowered down to bottom rail
      1 => const Alignment(0.94, 0.0),   // Right (Opponent 2)
      2 => const Alignment(0.0, -0.90),  // Top (Partner) - moved up to top rail
      _ => const Alignment(-0.94, 0.0),  // Left (Opponent 1)
    };
  }

  String _seatRole(int relativeSeat) {
    return switch (relativeSeat) {
      0 => 'YOU',
      2 => 'PARTNER',
      _ => 'OPPONENT',
    };
  }

  Color _teamAccent(int relativeSeat) {
    return switch (relativeSeat) {
      0 => const Color(0xFF48E5C2), // Self = Teal
      2 => const Color(0xFF38BDF8), // Partner = Sky Blue
      _ => const Color(0xFFFF6B6B), // Opponents = Crimson/Ruby
    };
  }

  @override
  Widget build(BuildContext context) {
    final relativeSeat = (player.seat - mySeat + 4) % 4;
    final role = _seatRole(relativeSeat);
    final accent = _teamAccent(relativeSeat);

    return Align(
      alignment: _alignment,
      child: active && deadline != null
          ? _TimedBadge(
              player: player,
              deadline: deadline!,
              role: role,
              accentColor: accent,
              isLead: isLead,
              isSelf: relativeSeat == 0,
            )
          : _StaticBadge(
              player: player,
              active: active,
              role: role,
              accentColor: accent,
              isLead: isLead,
              isSelf: relativeSeat == 0,
            ),
    );
  }
}

// ── Static Badge ─────────────────────────────────────────────────────────────

class _StaticBadge extends StatelessWidget {
  const _StaticBadge({
    required this.player,
    required this.active,
    required this.role,
    required this.accentColor,
    required this.isLead,
    required this.isSelf,
  });

  final MatchPlayer player;
  final bool active;
  final String role;
  final Color accentColor;
  final bool isLead;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final borderColor = !player.connected
        ? Colors.redAccent.withOpacity(0.8)
        : active
            ? accentColor
            : Colors.white.withOpacity(0.12);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? accentColor.withOpacity(0.25)
                : const Color(0xFF0B1424).withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: active ? 1.8 : 1.0),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 18,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8),
                  ],
          ),
          child: _BadgeRow(
            player: player,
            role: role,
            accentColor: accentColor,
            active: active,
            isLead: isLead,
            isSelf: isSelf,
          ),
        ),
      ),
    );
  }
}

// ── Timed Badge with Animated Timer ──────────────────────────────────────────

class _TimedBadge extends StatefulWidget {
  const _TimedBadge({
    required this.player,
    required this.deadline,
    required this.role,
    required this.accentColor,
    required this.isLead,
    required this.isSelf,
  });

  final MatchPlayer player;
  final int deadline;
  final String role;
  final Color accentColor;
  final bool isLead;
  final bool isSelf;

  @override
  State<_TimedBadge> createState() => _TimedBadgeState();
}

class _TimedBadgeState extends State<_TimedBadge> {
  Timer? _timer;
  double _progress = 1.0;
  int _secondsLeft = 18;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final remainingMs = widget.deadline - DateTime.now().millisecondsSinceEpoch;
    const totalMs = 18000;
    if (!mounted) return;
    setState(() {
      _progress = (remainingMs / totalMs).clamp(0.0, 1.0);
      _secondsLeft = (remainingMs / 1000).ceil().clamp(0, 18);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerColor = _progress > 0.4
        ? widget.accentColor
        : _progress > 0.2
            ? const Color(0xFFFFD166)
            : const Color(0xFFFF5252);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: timerColor.withOpacity(0.24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: timerColor.withOpacity(0.85), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: timerColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _BadgeRow(
                player: widget.player,
                role: widget.role,
                accentColor: widget.accentColor,
                active: true,
                isLead: widget.isLead,
                isSelf: widget.isSelf,
                secondsLeft: _secondsLeft,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 3.5,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Badge Inner Content ─────────────────────────────────────────────────────

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({
    required this.player,
    required this.role,
    required this.accentColor,
    required this.active,
    required this.isLead,
    required this.isSelf,
    this.secondsLeft,
  });

  final MatchPlayer player;
  final String role;
  final Color accentColor;
  final bool active;
  final bool isLead;
  final bool isSelf;
  final int? secondsLeft;

  @override
  Widget build(BuildContext context) {
    final textColor = active ? Colors.white : Colors.white70;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lead star badge
        if (isLead) ...[
          const Icon(Icons.star_rounded, color: Color(0xFFFFD166), size: 14),
          const SizedBox(width: 3),
        ],

        // Role pill or Bot icon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accentColor.withOpacity(0.4), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (player.isBot) ...[
                Icon(Icons.smart_toy_rounded, size: 11, color: accentColor),
                const SizedBox(width: 3),
              ],
              Text(
                role,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),

        // Username
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 75),
          child: Text(
            player.username,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),

        // Seconds Left indicator when active
        if (secondsLeft != null) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF070B13).withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${secondsLeft}s',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],

        const SizedBox(width: 5),

        // Card count in hand
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🂠', style: TextStyle(fontSize: 10, color: Colors.white54)),
              const SizedBox(width: 2),
              Text(
                '${player.cardCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
