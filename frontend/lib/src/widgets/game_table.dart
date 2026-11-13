import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/match_state.dart';
import '../services/audio_service.dart';
import 'trick_area.dart';

/// Oval poker table, following the reference table Sumit shared:
/// a big green felt oval with a wooden rim, players seated around the
/// perimeter in small circular avatar chips (name + card count in a
/// compact pill under the avatar), and the played cards in the centre
/// of the table — nothing full-screen, nothing blocking the game, and
/// the played cards never overlap the player names (the chips live on
/// the rim, the cards live in the middle).
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobileLayout = constraints.maxWidth < 450;
        final availableWidth = (constraints.maxWidth - (mobileLayout ? 12.0 : 32.0))
            .clamp(100.0, double.infinity)
            .toDouble();
        final availableHeight = (constraints.maxHeight - (mobileLayout ? 8.0 : 16.0))
            .clamp(100.0, double.infinity)
            .toDouble();
        // Oval, not a small circle: fill the table area like a real
        // poker table (the old table was a 210px circle in the middle
        // of a full-screen background image). Clamped so the oval
        // (and the rim chips) always fit inside this area.
        var ovalWidth = math.min(availableWidth, availableHeight * 1.55);
        var ovalHeight = ovalWidth * 0.62;
        if (ovalHeight > availableHeight * 0.94) {
          ovalHeight = availableHeight * 0.94;
          ovalWidth = ovalHeight / 0.62;
        }
        ovalHeight = math.max(170.0, ovalHeight);

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobileLayout ? 6 : 16,
            vertical: mobileLayout ? 4 : 8,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Oval table: wooden rim + green felt ──
              Center(
                child: Container(
                  width: ovalWidth,
                  height: ovalHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(ovalWidth / 2, ovalHeight / 2),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8A5A2B), Color(0xFF5C3A17), Color(0xFF3E2712)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 28, offset: const Offset(0, 10)),
                    ],
                  ),
                  padding: const EdgeInsets.all(9),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.elliptical(999, 999)),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.25),
                        radius: 1.1,
                        colors: [
                          const Color(0xFF14663F),
                          const Color(0xFF0B3D2E),
                          const Color(0xFF072A20),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.22), width: 1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Centre: trick cards + trump pill, drag-and-drop zone ──
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
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: ovalWidth * 0.82,
                      // No fixed height: the trick cards + trump pill size
                      // the zone, so nothing is clipped on short screens.
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.elliptical(999, 999)),
                        color: isHoveredWithCard
                            ? const Color(0xFF48E5C2).withOpacity(0.14)
                            : Colors.transparent,
                        border: Border.all(
                          color: isHoveredWithCard
                              ? const Color(0xFF48E5C2)
                              : Colors.white.withOpacity(0.05),
                          width: isHoveredWithCard ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isHoveredWithCard)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                'RELEASE TO PLAY',
                                style: TextStyle(
                                  color: Color(0xFF48E5C2),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
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
                          if (match.powerSuit != null &&
                              match.currentTrick != null &&
                              (match.phase == 'playing' || match.phase == 'trick-resolving'))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _TrumpPill(suit: match.powerSuit!),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Player chips around the rim ──
              for (final player in match.players)
                _PlayerChip(
                  player: player,
                  mySeat: mySeat,
                  active: player.seat == match.currentTurnSeat,
                  deadline: player.seat == match.currentTurnSeat ? match.turnDeadline : null,
                  isLead: match.currentTrick != null &&
                      match.currentTrick!.plays.isEmpty &&
                      player.seat == match.currentTurnSeat,
                  mobileLayout: mobileLayout,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Trump pill (compact, sits under the centre cards) ───────────────────────

class _TrumpPill extends StatelessWidget {
  const _TrumpPill({required this.suit});
  final String suit;

  @override
  Widget build(BuildContext context) {
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
      _ => const Color(0xFFD7DEE8),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1220).withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(symbol, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 5),
          Text(
            '${suit.toUpperCase()} TRUMP',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

// ── Table Center Emblem (no trick in progress) ──────────────────────────────

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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TrumpPill(suit: match.powerSuit!),
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

// ── Player Chip (circular avatar on the rim, like the reference) ────────────

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.mySeat,
    required this.active,
    this.deadline,
    this.isLead = false,
    this.mobileLayout = false,
  });

  final MatchPlayer player;
  final int mySeat;
  final bool active;
  final int? deadline;
  final bool isLead;
  final bool mobileLayout;

  Alignment get _alignment {
    final relativeSeat = (player.seat - mySeat + 4) % 4;
    return switch (relativeSeat) {
      0 => const Alignment(0.0, 0.88), // You — bottom rim
      1 => const Alignment(0.88, 0.0), // Opponent — right rim
      2 => const Alignment(0.0, -0.88), // Partner — top rim
      _ => const Alignment(-0.88, 0.0), // Opponent — left rim
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
    final borderColor = !player.connected
        ? Colors.redAccent.withOpacity(0.8)
        : active
            ? accent
            : Colors.white.withOpacity(0.25);

    return Align(
      alignment: _alignment,
      child: active && deadline != null
          ? _TimedChip(
              player: player,
              deadline: deadline!,
              role: role,
              accentColor: accent,
              borderColor: borderColor,
              isLead: isLead,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AvatarCircle(
                  player: player,
                  accentColor: accent,
                  borderColor: borderColor,
                  active: active,
                  isLead: isLead,
                ),
                const SizedBox(height: 3),
                _NamePill(player: player, role: role, accentColor: accent),
              ],
            ),
    );
  }
}

/// Circular avatar: initial letter (or bot icon) in a gold/teal ring,
/// exactly like the reference table's seat chips.
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.player,
    required this.accentColor,
    required this.borderColor,
    required this.active,
    required this.isLead,
  });

  final MatchPlayer player;
  final Color accentColor;
  final Color borderColor;
  final bool active;
  final bool isLead;

  @override
  Widget build(BuildContext context) {
    final initial = player.username.isNotEmpty
        ? player.username[0].toUpperCase()
        : '?';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0B1424),
            border: Border.all(color: borderColor, width: active ? 2.5 : 1.5),
            boxShadow: active
                ? [BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 14, spreadRadius: 1)]
                : [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8)],
          ),
          child: Center(
            child: player.isBot
                ? Icon(Icons.smart_toy_rounded, size: 22, color: accentColor)
                : Text(
                    initial,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        if (isLead)
          const Positioned(
            top: -6,
            right: -4,
            child: Icon(Icons.star_rounded, color: Color(0xFFFFD166), size: 16),
          ),
      ],
    );
  }
}

/// Name + card count pill under the avatar — compact, never covering cards.
class _NamePill extends StatelessWidget {
  const _NamePill({required this.player, required this.role, required this.accentColor, this.secondsLeft});
  final MatchPlayer player;
  final String role;
  final Color accentColor;
  final int? secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF070B13).withOpacity(0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            role,
            style: TextStyle(color: accentColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              player.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '🂠 ${player.cardCount}',
            style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800),
          ),
          if (secondsLeft != null) ...[
            const SizedBox(width: 4),
            Text(
              '${secondsLeft}s',
              style: TextStyle(color: accentColor, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    );
  }
}

/// Active-turn chip: same circular avatar + pill, with a thin timer bar.
class _TimedChip extends StatefulWidget {
  const _TimedChip({
    required this.player,
    required this.deadline,
    required this.role,
    required this.accentColor,
    required this.borderColor,
    required this.isLead,
  });

  final MatchPlayer player;
  final int deadline;
  final String role;
  final Color accentColor;
  final Color borderColor;
  final bool isLead;

  @override
  State<_TimedChip> createState() => _TimedChipState();
}

class _TimedChipState extends State<_TimedChip> {
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
        _AvatarCircle(
          player: widget.player,
          accentColor: widget.accentColor,
          borderColor: timerColor,
          active: true,
          isLead: widget.isLead,
        ),
        const SizedBox(height: 3),
        _NamePill(
          player: widget.player,
          role: widget.role,
          accentColor: widget.accentColor,
          secondsLeft: _secondsLeft,
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 64,
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
