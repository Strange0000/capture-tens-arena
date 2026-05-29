import 'package:flutter/material.dart';

import 'arena_card_widget.dart';

/// Power suit selector — clean, performant, no BackdropFilter.
class PowerSuitPicker extends StatefulWidget {
  const PowerSuitPicker({super.key, required this.onSelect});
  final void Function(String suit) onSelect;

  @override
  State<PowerSuitPicker> createState() => _PowerSuitPickerState();
}

class _PowerSuitPickerState extends State<PowerSuitPicker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

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
        return Transform.scale(
          scale: 1.0 + (_ctrl.value * 0.02), // subtle breathing scale
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF101826).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.3 + (_ctrl.value * 0.3))),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.08 + (_ctrl.value * 0.1)), blurRadius: 20 + (_ctrl.value * 10), spreadRadius: 2),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CHOOSE POWER SUIT',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFFC857), letterSpacing: 2.5),
          ),
          const SizedBox(height: 12),
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

  @override
  Widget build(BuildContext context) {
    final isRed = widget.suit == 'hearts' || widget.suit == 'diamonds';
    final color = isRed ? const Color(0xFFE53935) : Colors.white;
    final symbol = suitSymbol(widget.suit);
    final name = widget.suit[0].toUpperCase() + widget.suit.substring(1);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => widget.onSelect(widget.suit),
      onTapCancel: () => setState(() => _pressed = false),
      child: Transform.scale(
        scale: _pressed ? 1.1 : 1.0,
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _pressed ? color.withOpacity(0.15) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _pressed ? color.withOpacity(0.5) : Colors.white12),
            boxShadow: _pressed
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, spreadRadius: 2)]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              suitImage(widget.suit, 32),
              const SizedBox(height: 4),
              Text(name, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
