import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import 'arena_card_widget.dart';

/// Premium glassmorphism power suit picker.
class PowerSuitPicker extends StatefulWidget {
  const PowerSuitPicker({super.key, required this.onSelect});
  final void Function(String suit) onSelect;

  @override
  State<PowerSuitPicker> createState() => _PowerSuitPickerState();
}

class _PowerSuitPickerState extends State<PowerSuitPicker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC857).withOpacity(0.12 + _ctrl.value * 0.12),
                blurRadius: 24 + _ctrl.value * 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFC857).withOpacity(0.2 + _ctrl.value * 0.25),
                    width: 1.2,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('👑', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                'CHOOSE POWER SUIT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFC857),
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SuitButton(suit: 'hearts', onSelect: widget.onSelect),
              _SuitButton(suit: 'diamonds', onSelect: widget.onSelect),
              _SuitButton(suit: 'clubs', onSelect: widget.onSelect),
              _SuitButton(suit: 'spades', onSelect: widget.onSelect),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuitButton extends StatefulWidget {
  const _SuitButton({required this.suit, required this.onSelect});
  final String suit;
  final void Function(String) onSelect;

  @override
  State<_SuitButton> createState() => _SuitButtonState();
}

class _SuitButtonState extends State<_SuitButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isRed = widget.suit == 'hearts' || widget.suit == 'diamonds';
    final color = isRed ? const Color(0xFFE53935) : Colors.white;
    final name = widget.suit[0].toUpperCase() + widget.suit.substring(1);
    final active = _pressed || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          AudioService.instance.playPowerSuit();
          AudioService.instance.hapticMedium();
          widget.onSelect(widget.suit);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 1.12 : _hovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.18) : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? color.withOpacity(0.7) : Colors.white.withOpacity(0.12),
                width: active ? 1.5 : 1.0,
              ),
              boxShadow: active
                  ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 20, spreadRadius: 2)]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                suitImage(widget.suit, 34),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? color : color.withOpacity(0.6),
                    fontWeight: FontWeight.w800,
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
