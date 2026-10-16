import 'dart:math';
import 'package:flutter/material.dart';

import '../models/arena_card.dart';
import '../services/audio_service.dart';

/// Premium playing card with realistic look — proper corner pips,
/// center suit, clean shadows, and smooth press animation.
class ArenaCardWidget extends StatefulWidget {
  const ArenaCardWidget({
    super.key,
    required this.card,
    required this.powerSuit,
    required this.onPlay,
    this.dimmed = false,
    this.isLegal = true,
    this.small = false,
    this.faceDown = false,
    this.width,
  });

  final ArenaCard card;
  final String? powerSuit;
  final VoidCallback? onPlay;
  final bool dimmed;
  final bool isLegal;
  final bool small;
  final bool faceDown;
  final double? width;

  @override
  State<ArenaCardWidget> createState() => _ArenaCardWidgetState();
}

class _ArenaCardWidgetState extends State<ArenaCardWidget> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final double w = widget.width ?? (widget.small ? 50.0 : 70.0);
    final double h = w * 1.428;
    final double scale = w / 70.0;

    if (widget.faceDown) return _CardBack(width: w, height: h);

    final isPower = widget.card.suit == widget.powerSuit;
    final isTen = widget.card.rank == '10';
    final isRed = widget.card.suit == 'hearts' || widget.card.suit == 'diamonds';
    final suitColor = isRed ? const Color(0xFFCC1111) : const Color(0xFF111122);

    final isPlayable = widget.onPlay != null && widget.isLegal && !widget.dimmed;
    final effectivelyDimmed = widget.dimmed || (widget.onPlay != null && !widget.isLegal);
    final isHovered = _hovered && isPlayable;

    return Opacity(
      opacity: effectivelyDimmed ? 0.38 : 1.0,
      child: MouseRegion(
        onEnter: effectivelyDimmed
            ? null
            : (_) {
                AudioService.instance.playCardClick();
                setState(() => _hovered = true);
              },
        onExit: (_) => setState(() => _hovered = false),
        cursor: effectivelyDimmed
            ? SystemMouseCursors.basic
            : (widget.onPlay != null ? SystemMouseCursors.click : SystemMouseCursors.basic),
        child: GestureDetector(
          onTapDown: effectivelyDimmed ? null : (_) => setState(() => _pressed = true),
          onTapUp: effectivelyDimmed ? null : (_) => setState(() => _pressed = false),
          onTap: effectivelyDimmed ? null : widget.onPlay,
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.93 : 1.0,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: isHovered
                  ? (Matrix4.identity()
                    ..setEntry(3, 2, 0.003)
                    ..translate(0.0, -12.0, 30.0))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              width: w,
              height: h,
              margin: EdgeInsets.symmetric(horizontal: 3 * scale),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8 * scale),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF7F7F7), Color(0xFFEFEFEF)],
                ),
                border: Border.all(
                  color: isPower
                      ? const Color(0xFFFFD166)
                      : isTen
                          ? const Color(0xFF48E5C2)
                          : (isPlayable
                              ? const Color(0xFF64B5F6)
                              : const Color(0xFFCCCCCC)),
                  width: (isPower || isTen)
                      ? 2.0
                      : (isPlayable ? 1.4 : 0.8),
                ),
                boxShadow: [
                  // 3D edge/thickness effect
                  BoxShadow(
                    color: Colors.grey[300] ?? const Color(0xFFE0E0E0),
                    offset: Offset(0, 2.5 * scale),
                    blurRadius: 0,
                  ),
                  if (isPlayable)
                    BoxShadow(
                      color: isPower
                          ? const Color(0xFFFFD166).withOpacity(isHovered ? 0.6 : 0.25)
                          : isTen
                              ? const Color(0xFF48E5C2).withOpacity(isHovered ? 0.6 : 0.25)
                              : const Color(0xFF64B5F6).withOpacity(isHovered ? 0.45 : 0.15),
                      blurRadius: isHovered ? 18 : 8,
                      spreadRadius: isHovered ? 2 : 0,
                    ),
                  if (isHovered) ...[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ] else ...[
                    BoxShadow(
                      color: isPower
                          ? const Color(0xFFFFD166).withOpacity(0.3)
                          : isTen
                              ? const Color(0xFF48E5C2).withOpacity(0.25)
                              : Colors.black.withOpacity(0.12),
                      blurRadius: isPower ? 10 : 5,
                      offset: const Offset(0, 2),
                    ),
                    if (!widget.small)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7 * scale),
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
                      top: 4 * scale,
                      left: 5 * scale,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.card.rank,
                            style: TextStyle(
                              color: suitColor,
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            _suitSymbol(widget.card.suit),
                            style: TextStyle(
                              color: suitColor,
                              fontSize: 12 * scale,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center suit — large crisp symbol
                    Center(
                      child: Text(
                        _suitSymbol(widget.card.suit),
                        style: TextStyle(
                          color: suitColor.withOpacity(0.92),
                          fontSize: 32 * scale,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),

                    // Bottom-right pip (rotated)
                    Positioned(
                      bottom: 4 * scale,
                      right: 5 * scale,
                      child: Transform.rotate(
                        angle: pi,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.card.rank,
                              style: TextStyle(
                                color: suitColor,
                                fontSize: 16 * scale,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              _suitSymbol(widget.card.suit),
                              style: TextStyle(
                                color: suitColor,
                                fontSize: 12 * scale,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Power suit indicator — golden corner dot
                    if (isPower)
                      Positioned(
                        top: 2 * scale, right: 2 * scale,
                        child: Container(
                          width: 8 * scale,
                          height: 8 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD4A017),
                            boxShadow: [BoxShadow(color: const Color(0xFFD4A017).withOpacity(0.5), blurRadius: 4)],
                          ),
                        ),
                      ),

                    // Glossy light reflection overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
