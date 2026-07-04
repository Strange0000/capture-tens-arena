import 'package:flutter/material.dart';

import '../models/match_state.dart';
import 'arena_card_widget.dart';

/// Renders the 4 cards of the current trick in a cross layout.
/// New cards fly in from the player's seat direction with a smooth animation.
class TrickArea extends StatefulWidget {
  const TrickArea({super.key, required this.trick, required this.powerSuit, required this.mySeat});

  final CurrentTrick trick;
  final String? powerSuit;
  final int mySeat;

  @override
  State<TrickArea> createState() => _TrickAreaState();
}

class _TrickAreaState extends State<TrickArea> with TickerProviderStateMixin {
  /// Track which seats have already been animated (by trick index + seat).
  final Set<String> _animatedKeys = {};

  /// Active animation controllers keyed by seat number.
  final Map<int, AnimationController> _controllers = {};
  final Map<int, Animation<Offset>> _slideAnimations = {};
  final Map<int, Animation<double>> _fadeAnimations = {};
  final Map<int, Animation<double>> _scaleAnimations = {};

  @override
  void didUpdateWidget(TrickArea oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If trick index changed, reset all tracked animations
    if (oldWidget.trick.index != widget.trick.index) {
      _disposeControllers();
      _animatedKeys.clear();
    }

    // Detect new plays and start animations for them
    for (final play in widget.trick.plays) {
      final key = '${widget.trick.index}-${play.seat}';
      if (!_animatedKeys.contains(key)) {
        _animatedKeys.add(key);
        _startFlyIn(play.seat);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Mark all existing plays as already animated (no animation on first build)
    for (final play in widget.trick.plays) {
      _animatedKeys.add('${widget.trick.index}-${play.seat}');
    }
  }

  void _startFlyIn(int seat) {
    // Dispose any previous controller for this seat
    _controllers[seat]?.dispose();

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Starting offset based on seat direction (relative to the card's final position)
    final beginOffset = _offsetForSeat(seat);

    _slideAnimations[seat] = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimations[seat] = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _scaleAnimations[seat] = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
    ));

    _controllers[seat] = controller;
    controller.forward();
  }

  /// Returns the starting offset for the fly-in animation based on relative seat position.
  /// Each seat's card enters from their visual direction.
  Offset _offsetForSeat(int seat) {
    final relativeSeat = (seat - widget.mySeat + 4) % 4;
    return switch (relativeSeat) {
      0 => const Offset(0.0, 2.5),   // Bottom → flies upward
      1 => const Offset(2.5, 0.0),   // Right  → flies leftward
      2 => const Offset(0.0, -2.5),  // Top    → flies downward
      3 => const Offset(-2.5, 0.0),  // Left   → flies rightward
      _ => Offset.zero,
    };
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _slideAnimations.clear();
    _fadeAnimations.clear();
    _scaleAnimations.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<int, TrickPlay> byRelativeSeats = {};
    for (final play in widget.trick.plays) {
      final relativeSeat = (play.seat - widget.mySeat + 4) % 4;
      byRelativeSeats[relativeSeat] = play;
    }

    final double sw = MediaQuery.of(context).size.width;
    final double size = (sw * 0.55).clamp(180.0, 260.0);
    final double cardWidth = (size * 0.25).clamp(45.0, 65.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Relative Seat 2 → top
          if (byRelativeSeats[2] != null)
            Positioned(top: 0, left: 0, right: 0,
              child: Center(child: _buildAnimatedCard(byRelativeSeats[2]!.seat, byRelativeSeats[2]!, cardWidth))),

          // Relative Seat 1 → right
          if (byRelativeSeats[1] != null)
            Positioned(right: 0, top: 0, bottom: 0,
              child: Center(child: _buildAnimatedCard(byRelativeSeats[1]!.seat, byRelativeSeats[1]!, cardWidth))),

          // Relative Seat 3 → left
          if (byRelativeSeats[3] != null)
            Positioned(left: 0, top: 0, bottom: 0,
              child: Center(child: _buildAnimatedCard(byRelativeSeats[3]!.seat, byRelativeSeats[3]!, cardWidth))),

          // Relative Seat 0 → bottom
          if (byRelativeSeats[0] != null)
            Positioned(bottom: 0, left: 0, right: 0,
              child: Center(child: _buildAnimatedCard(byRelativeSeats[0]!.seat, byRelativeSeats[0]!, cardWidth))),

          // Empty centre hint
          if (widget.trick.plays.isEmpty)
            const Center(child: Text('Play a card', style: TextStyle(color: Colors.white24, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard(int seat, TrickPlay play, double cardWidth) {
    final isWinner = widget.trick.winnerSeat == seat;
    final card = _PlayedCard(play: play, powerSuit: widget.powerSuit, isWinner: isWinner, cardWidth: cardWidth);

    // If there's an active animation for this seat, wrap in animated builders
    if (_controllers.containsKey(seat) && _slideAnimations.containsKey(seat)) {
      final controller = _controllers[seat]!;
      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimations[seat]!,
            child: FadeTransition(
              opacity: _fadeAnimations[seat]!,
              child: ScaleTransition(
                scale: _scaleAnimations[seat]!,
                child: child,
              ),
            ),
          );
        },
        child: card,
      );
    }

    return card;
  }
}

class _PlayedCard extends StatelessWidget {
  const _PlayedCard({required this.play, required this.powerSuit, required this.isWinner, required this.cardWidth});

  final TrickPlay play;
  final String? powerSuit;
  final bool isWinner;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: isWinner
            ? [BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.5), blurRadius: 16, spreadRadius: 2)]
            : [],
      ),
      child: ArenaCardWidget(
        card: play.card,
        powerSuit: powerSuit,
        onPlay: () {},
        width: cardWidth,
      ),
    );
  }
}
