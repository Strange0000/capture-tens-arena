import 'dart:math';
import 'package:flutter/material.dart';

/// Simple shuffle + deal animation. Shows only once at game start.
/// A deck wobbles briefly, then cards fan out and fade.
class DealAnimation extends StatefulWidget {
  const DealAnimation({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<DealAnimation> createState() => _DealAnimationState();
}

class _DealAnimationState extends State<DealAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;

        // Phase 1: 0-0.4 = shuffle wobble
        // Phase 2: 0.4-0.85 = cards fly out
        // Phase 3: 0.85-1.0 = fade out

        final fadeOut = t > 0.85 ? ((t - 0.85) / 0.15).clamp(0.0, 1.0) : 0.0;

        return Opacity(
          opacity: 1.0 - fadeOut,
          child: Stack(
            children: [
              // Dark overlay
              Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.75))),

              // Deck stack with shuffle wobble
              if (t < 0.5)
                ...List.generate(5, (i) {
                  final wobbleT = (t / 0.4).clamp(0.0, 1.0);
                  final wobble = sin(wobbleT * pi * 8 + i) * 6 * (1 - wobbleT);
                  return Positioned(
                    left: size.width / 2 - 25 + wobble + i * 0.5,
                    top: size.height / 2 - 36 - i * 2,
                    child: _CardBack(),
                  );
                }),

              // Flying cards (phase 2)
              if (t >= 0.35)
                ...List.generate(16, (i) {
                  final dealT = ((t - 0.35 - i * 0.02) / 0.15).clamp(0.0, 1.0);
                  if (dealT <= 0) return const SizedBox.shrink();

                  final eased = Curves.easeOutCubic.transform(dealT);
                  
                  final startX = size.width / 2 - 25;
                  final startY = size.height / 2 - 36;

                  double targetX;
                  double targetY;
                  final playerIdx = i % 4;
                  if (playerIdx == 0) { // Bottom (User)
                    targetX = startX;
                    targetY = size.height - 120;
                  } else if (playerIdx == 1) { // Left
                    targetX = 40;
                    targetY = startY;
                  } else if (playerIdx == 2) { // Top
                    targetX = startX;
                    targetY = 120;
                  } else { // Right
                    targetX = size.width - 90;
                    targetY = startY;
                  }

                  final x = startX + (targetX - startX) * eased;
                  final y = startY + (targetY - startY) * eased;

                  return Positioned(
                    left: x, top: y,
                    child: Opacity(
                      opacity: (1.0 - eased * 0.8).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1.0 - eased * 0.3,
                        child: Transform.rotate(
                          // Slightly rotate cards as they fly
                          angle: eased * pi * (playerIdx % 2 == 0 ? 0.2 : -0.2),
                          child: _CardBack(),
                        ),
                      ),
                    ),
                  );
                }),

              // "Shuffling..." / "Dealing..." text
              Positioned(
                bottom: size.height * 0.32,
                left: 0, right: 0,
                child: Center(
                  child: Text(
                    t < 0.4 ? 'Shuffling...' : 'Dealing...',
                    style: const TextStyle(
                      color: Color(0xFFFFC857), fontSize: 15,
                      fontWeight: FontWeight.w700, letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardBack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50, height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A2744), Color(0xFF0E1A2E)],
        ),
        border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.35), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 2))],
      ),
      child: Center(child: Text('✦', style: TextStyle(color: const Color(0xFFD4A017).withOpacity(0.3), fontSize: 14))),
    );
  }
}
