import 'dart:math';
import 'package:flutter/material.dart';

import '../models/arena_card.dart';

/// Premium playing card with realistic look — proper corner pips,
/// center suit, clean shadows, and smooth press animation.
class ArenaCardWidget extends StatefulWidget {
  const ArenaCardWidget({
    super.key,
    required this.card,
    required this.powerSuit,
    required this.onPlay,
    this.dimmed = false,
    this.small = false,
    this.faceDown = false,
  });

  final ArenaCard card;
  final String? powerSuit;
  final VoidCallback? onPlay;
  final bool dimmed;
  final bool small;
  final bool faceDown;

  @override
  State<ArenaCardWidget> createState() => _ArenaCardWidgetState();
}

class _ArenaCardWidgetState extends State<ArenaCardWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final double w = widget.small ? 50 : 70;
    final double h = widget.small ? 72 : 100;

    if (widget.faceDown) return _CardBack(width: w, height: h);

    final isPower = widget.card.suit == widget.powerSuit;
    final isTen = widget.card.rank == '10';
    final isRed = widget.card.suit == 'hearts' || widget.card.suit == 'diamonds';
    final suitColor = isRed ? const Color(0xFFCC1111) : const Color(0xFF111122);
    final suitSymbol = _suitSymbol(widget.card.suit);

    return Opacity(
      opacity: widget.dimmed ? 0.35 : 1.0,
      child: GestureDetector(
        onTapDown: widget.dimmed ? null : (_) => setState(() => _pressed = true),
        onTapUp: widget.dimmed ? null : (_) => setState(() => _pressed = false),
        onTap: widget.dimmed ? null : widget.onPlay,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: w,
            height: h,
            margin: EdgeInsets.symmetric(horizontal: widget.small ? 1 : 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.small ? 6 : 8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF7F7F7), Color(0xFFEFEFEF)],
              ),
              border: Border.all(
                color: isPower
                    ? const Color(0xFFD4A017)
                    : isTen
                        ? const Color(0xFF30B89C)
                        : const Color(0xFFCCCCCC),
                width: (isPower || isTen) ? 2 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: isPower
                      ? const Color(0xFFD4A017).withOpacity(0.4)
                      : isTen
                          ? const Color(0xFF30B89C).withOpacity(0.3)
                          : Colors.black.withOpacity(0.12),
                  blurRadius: isPower ? 12 : 5,
                  offset: const Offset(0, 2),
                ),
                if (!widget.small)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 1, offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.small ? 5 : 7),
              child: Stack(
                children: [
                  // Subtle inner texture
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white.withOpacity(0.0), Colors.black.withOpacity(0.02)],
                        ),
                      ),
                    ),
                  ),

                  // Top-left pip
                  Positioned(
                    top: widget.small ? 3 : 5,
                    left: widget.small ? 4 : 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.card.rank,
                          style: TextStyle(
                            color: suitColor,
                            fontSize: widget.small ? 12 : 16,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        suitImage(widget.card.suit, widget.small ? 9 : 12),
                      ],
                    ),
                  ),

                  // Center suit — large
                  Center(
                    child: suitImage(widget.card.suit, widget.small ? 24 : 34),
                  ),

                  // Bottom-right pip (rotated)
                  Positioned(
                    bottom: widget.small ? 3 : 5,
                    right: widget.small ? 4 : 6,
                    child: Transform.rotate(
                      angle: pi,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.card.rank,
                            style: TextStyle(
                              color: suitColor,
                              fontSize: widget.small ? 12 : 16,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          suitImage(widget.card.suit, widget.small ? 9 : 12),
                        ],
                      ),
                    ),
                  ),

                  // Power suit indicator — golden corner dot
                  if (isPower)
                    Positioned(
                      top: 2, right: 2,
                      child: Container(
                        width: widget.small ? 6 : 8,
                        height: widget.small ? 6 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD4A017),
                          boxShadow: [BoxShadow(color: const Color(0xFFD4A017).withOpacity(0.5), blurRadius: 4)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card back design — premium navy with gold pattern
class _CardBack extends StatelessWidget {
  const _CardBack({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2744), Color(0xFF0E1A2E), Color(0xFF162240)],
        ),
        border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: [
            // Inner border
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.2), width: 0.5),
                ),
              ),
            ),
            // Center diamond pattern
            Center(
              child: Container(
                width: width * 0.4,
                height: width * 0.4,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Center(
                  child: Text('✦', style: TextStyle(
                    color: const Color(0xFFD4A017).withOpacity(0.4),
                    fontSize: width * 0.2,
                  )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String suitSymbol(String suit) {
  return _suitSymbol(suit);
}

String _suitSymbol(String suit) {
  return switch (suit) {
    'hearts' => '♥',
    'diamonds' => '♦',
    'clubs' => '♣',
    'spades' => '♠',
    _ => '?',
  };
}

Widget suitImage(String suit, double size) {
  return Image.asset(
    'assets/images/suit_$suit.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
}
