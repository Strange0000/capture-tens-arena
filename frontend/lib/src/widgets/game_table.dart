import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/match_state.dart';
import '../services/audio_service.dart';
import '../theme.dart';
import 'trick_area.dart';

/// Oval poker table, following the reference table Sumit shared:
/// a big green felt oval with a wooden rim, players seated around the
/// perimeter in small circular avatar chips (name + card count in a
/// compact pill under the avatar), and the played cards in the centre
/// of the table — nothing full-screen, nothing blocking the game.
///
/// Round 3 — why the screen was crowded (see the screenshot):
/// the player chips were positioned with `Align(±0.88)` against the
/// WHOLE table area, not against the oval. When the table area was
/// short (tall score bar + huge hand), the top/bottom chips collapsed
/// toward the centre and landed on top of the played cards, and the
/// "PARTNER N…" / "YOU G…" pills covered the centre cards. The chips
/// are now positioned with explicit coordinates computed FROM the oval
/// and the trick cluster: the partner pill always ends 8px above the
/// top played card, the self pill always starts 8px below the bottom
/// played card, and the side chips sit on the left/right rim — so no
/// chip can ever cover a played card, on any screen size. The score
/// bar is slim and the hand cards are smaller, so the table area (and
/// the oval) is much taller than before, which is what makes the
/// clearance possible in the first place.
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
        final stackW = constraints.maxWidth;
        final stackH = constraints.maxHeight;
        final centreX = stackW / 2;
        final centreY = stackH / 2;
        final availableWidth = (stackW - (mobileLayout ? 12.0 : 32.0))
            .clamp(100.0, double.infinity)
            .toDouble();
        final availableHeight = (stackH - (mobileLayout ? 8.0 : 16.0))
            .clamp(100.0, double.infinity)
            .toDouble();
        // Oval, not a small circle: fill the table area like a real
        // poker table. Clamped so the oval (and the rim chips) always
        // fit inside this area.
        var ovalWidth = math.min(availableWidth, availableHeight * 1.6);
        var ovalHeight = ovalWidth * 0.60;
        if (ovalHeight > availableHeight * 0.92) {
          ovalHeight = availableHeight * 0.92;
          ovalWidth = ovalHeight / 0.60;
        }
        ovalHeight = math.max(160.0, ovalHeight);
        final ovalLeft = (stackW - ovalWidth) / 2;

        // Trick cluster size — shared with TrickArea via trickAreaMetrics,
        // so the chip positions below are computed from the REAL card
        // positions. On a short oval the cluster shrinks (0.8 / 0.7) so
        // the rim chips still have a clear lane around it.
        final trickScale = ovalHeight < 200
            ? 0.7
            : ovalHeight < 260
                ? 0.8
                : 1.0;
        final trickMetrics = trickAreaMetrics(stackW, scale: trickScale);
        final trickHalfH = trickMetrics.height / 2;

        // Chip slot: avatar + name pill (+ timer bar when active).
        // Smaller on short ovals so the lane around the cards survives.
        final double chipH = ovalHeight < 200
            ? (mobileLayout ? 47.0 : 51.0)
            : (mobileLayout ? 53.0 : 59.0);
        final double chipW = 150.0;
        const double chipGap = 8.0; // clear space between a chip and a played card

        Offset chipPosition(MatchPlayer player) {
          final relativeSeat = (player.seat - mySeat + 4) % 4;
          final isActiveTurn = player.seat == match.currentTurnSeat;
          final double h = isActiveTurn && match.turnDeadline != null ? chipH + 10 : chipH;
          switch (relativeSeat) {
            case 0: // You — bottom rim, pill starts below the bottom card.
              final top = math.min(centreY + trickHalfH + chipGap, stackH - h - 2);
              return Offset(centreX - chipW / 2, top);
            case 2: // Partner — top rim, pill ends above the top card.
              final top = math.max(2.0, centreY - trickHalfH - chipGap - h);
              return Offset(centreX - chipW / 2, top);
            case 1: // Opponent — right rim, avatar centred on the rim.
              final left = math.min(ovalLeft + ovalWidth - chipW / 2, stackW - chipW - 2);
              return Offset(left, centreY - h / 2);
            default: // Opponent — left rim, avatar centred on the rim.
              final left = math.max(2.0, ovalLeft - chipW / 2);
              return Offset(left, centreY - h / 2);
          }
        }

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobileLayout ? 6 : 16,
            vertical: mobileLayout ? 4 : 8,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
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
                      border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.45), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Centre: trick cards only, drag-and-drop zone ──
              // No trump pill here any more: trump lives in the slim
              // score strip at the top, and the old centre pill used to
              // float down over the hand cards.
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
                      width: ovalWidth * 0.78,
                      // No fixed height: the trick cards size the zone,
                      // so nothing is clipped on short screens.
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.elliptical(999, 999)),
                        color: isHoveredWithCard
                            ? ArenaColors.gold.withOpacity(0.12)
                            : Colors.transparent,
                        border: Border.all(
                          color: isHoveredWithCard
                              ? ArenaColors.gold
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
                                  color: ArenaColors.gold,
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
                              scale: trickScale,
                            )
                          else
                            _TableCenterEmblem(
                              match: match,
                              isMyTurn: match.players.any(
                                (p) => p.seat == match.currentTurnSeat && p.seat == mySeat,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Player chips around the rim, anchored to the oval ──
              for (final player in match.players)
                Builder(
                  builder: (context) {
                    final pos = chipPosition(player);
                    return Positioned(
                      left: pos.dx,
                      top: pos.dy,
                      width: chipW,
                      child: _PlayerChip(
                        player: player,
                        mySeat: mySeat,
                        active: player.seat == match.currentTurnSeat,
                        deadline: player.seat == match.currentTurnSeat ? match.turnDeadline : null,
                        isLead: match.currentTrick != null &&
                            match.currentTrick!.plays.isEmpty &&
                            player.seat == match.currentTurnSeat,
                        mobileLayout: mobileLayout,
                        avatarSize: ovalHeight < 200
                            ? 30.0
                            : mobileLayout
                                ? 32.0
                                : 36.0,
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
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
      return Text(
        isMyTurn ? 'YOUR TURN · PLAY A CARD' : 'Waiting for turn...',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isMyTurn ? FontWeight.w900 : FontWeight.w600,
          color: isMyTurn ? ArenaColors.gold : Colors.white24,
          letterSpacing: 1.0,
        ),
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
    this.avatarSize = 36.0,
  });

  final MatchPlayer player;
  final int mySeat;
  final bool active;
  final int? deadline;
  final bool isLead;
  final bool mobileLayout;
  final double avatarSize;

  String _seatRole(int relativeSeat) {
    return switch (relativeSeat) {
      0 => 'YOU',
      2 => 'PARTNER',
      _ => 'OPPONENT',
    };
  }

  Color _teamAccent(int relativeSeat) {
    return switch (relativeSeat) {
      0 => ArenaColors.gold, // You = Gold
      2 => ArenaColors.emerald, // Partner = Felt green
      _ => ArenaColors.ruby, // Opponents = Muted ruby
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

    if (active && deadline != null) {
      return _TimedChip(
        player: player,
        deadline: deadline!,
        role: role,
        accentColor: accent,
        borderColor: borderColor,
        isLead: isLead,
        avatarSize: avatarSize,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AvatarCircle(
          player: player,
          accentColor: accent,
          borderColor: borderColor,
          active: active,
          isLead: isLead,
          size: avatarSize,
        ),
        const SizedBox(height: 3),
        _NamePill(player: player, role: role, accentColor: accent),
      ],
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
    this.size = 36.0,
  });

  final MatchPlayer player;
  final Color accentColor;
  final Color borderColor;
  final bool active;
  final bool isLead;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = player.username.isNotEmpty
        ? player.username[0].toUpperCase()
        : '?';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
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
                ? Icon(Icons.smart_toy_rounded, size: size * 0.48, color: accentColor)
                : Text(
                    initial,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: size * 0.44,
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
      constraints: const BoxConstraints(maxWidth: 140),
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
          // A real icon, not the 🂠 emoji: that glyph is missing from
          // the font and rendered as a tofu box ("■ 8") in the screenshot.
          const Icon(Icons.style_rounded, size: 10, color: Colors.white70),
          const SizedBox(width: 2),
          Text(
            '${player.cardCount}',
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
    this.avatarSize = 36.0,
  });

  final MatchPlayer player;
  final int deadline;
  final String role;
  final Color accentColor;
  final Color borderColor;
  final bool isLead;
  final double avatarSize;

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
          size: widget.avatarSize,
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
          width: 56,
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
