import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// First-page hero (concept 2, "Hero tens"): a fan of playing cards
/// with a big glowing golden 10 of spades in front, gold sparkles
/// drifting up behind them, and a soft glow pulse for the main button.
///
/// Pure decoration — no auth, no navigation, no network. The fan is
/// drawn with plain Flutter widgets (no image assets), so the first
/// page stays fast to load. All motion is slow and smooth on purpose:
/// a casino glow, not a flashing banner. Nothing here can cover or
/// delay the login buttons — the fan sits above them and is not
/// tappable.

/// The hero fan: 7 cards fanned across the screen, the golden 10♠ in
/// front, sparkles behind. Cards fan in one by one on page load
/// ([_fanCtrl]); the hero 10 then gently breathes with [pulse], the
/// login screen's existing 3s pulse controller.
class HeroCardFan extends StatefulWidget {
  const HeroCardFan({super.key, required this.pulse});

  /// Repeating 0→1→0 animation that drives the hero card's glow.
  final Animation<double> pulse;

  @override
  State<HeroCardFan> createState() => _HeroCardFanState();
}

class _HeroCardFanState extends State<HeroCardFan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fanCtrl;

  /// (rank, suit, face-up?, red?) — left to right, matching the
  /// concept art: white faces at the edges, dark gold backs inside.
  static const _fan = [
    ('Q', '♣', true, false),
    ('J', '♠', false, false),
    ('K', '♠', false, false),
    ('Q', '♦', false, false),
    ('K', '♦', false, false),
    ('K', '♥', true, true),
    ('A', '♦', true, true),
  ];

  @override
  void initState() {
    super.initState();
    _fanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _fanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fanWidth = math.min(constraints.maxWidth, 360.0);
        final cardW = fanWidth * 0.17;
        final heroW = cardW * 1.75;
        final heroH = heroW * 1.42;
        // Tall enough for the fanned cards plus the hero 10 overlapping
        // them in front and a little room for its glow.
        final height = heroH + 84;

        return SizedBox(
          width: fanWidth,
          height: height,
          child: RepaintBoundary(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ambient casino table light pool under the cards
                Container(
                  width: fanWidth * 0.95,
                  height: height * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ArenaColors.gold.withOpacity(0.18),
                        const Color(0xFF0F3827).withOpacity(0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                const Positioned.fill(child: SparkleField()),
                AnimatedBuilder(
                  animation: _fanCtrl,
                  builder: (context, child) {
                    final cards = <Widget>[];
                    for (var i = 0; i < _fan.length; i++) {
                      final (rank, suit, face, red) = _fan[i];
                      // Staggered entrance: each card starts 80ms after
                      // the previous one, then eases into its fanned spot.
                      final interval = Interval(
                        i * 0.07,
                        0.45 + i * 0.07,
                        curve: Curves.easeOutCubic,
                      );
                      final t = interval.transform(_fanCtrl.value);
                      final angleDeg = -30 + i * 10;
                      final angle = angleDeg * math.pi / 180;
                      // Cards sit on an arc: outer cards swing out and
                      // drop, so the fan opens like a real hand.
                      final target = Offset(
                        math.sin(angle) * 148,
                        (1 - math.cos(angle)) * 118 + 6,
                      );
                      final offset = Offset.lerp(
                        const Offset(0, 64),
                        target,
                        t,
                      )!;
                      cards.add(
                        Positioned(
                          top: 8,
                          child: Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: offset,
                              child: Transform.rotate(
                                angle: angle * t,
                                child: _MiniCard(
                                  rank: rank,
                                  suit: suit,
                                  faceUp: face,
                                  red: red,
                                  width: cardW,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    // The hero 10♠ arrives last, rising out of the fan.
                    final heroT = const Interval(
                      0.55,
                      0.9,
                      curve: Curves.easeOutBack,
                    ).transform(_fanCtrl.value);
                    cards.add(
                      Positioned(
                        top: 46,
                        child: Opacity(
                          opacity: heroT.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 26 * (1 - heroT)),
                            child: Transform.scale(
                              scale: 0.72 + 0.28 * heroT,
                              child: AnimatedBuilder(
                                animation: widget.pulse,
                                builder: (context, child) {
                                  final p = Curves.easeInOut.transform(
                                    widget.pulse.value,
                                  );
                                  return Transform.scale(
                                    scale: 1.0 + 0.025 * p,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: ArenaColors.gold.withOpacity(
                                              0.35 + 0.3 * p,
                                            ),
                                            blurRadius: 26 + 18 * p,
                                            spreadRadius: 2 + 4 * p,
                                          ),
                                        ],
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _HeroTenCard(width: heroW),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    return Stack(alignment: Alignment.center, children: cards);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One small decorative playing card. Face-up cards are cream with a
/// corner rank and a big centre suit; face-down cards are the dark
/// navy-and-gold back from the concept art.
class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.rank,
    required this.suit,
    required this.faceUp,
    required this.red,
    required this.width,
  });

  final String rank;
  final String suit;
  final bool faceUp;
  final bool red;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.42;
    final pip = red ? const Color(0xFFC62828) : const Color(0xFF1A1A1A);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: faceUp
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFBF2), Color(0xFFEFE6CF)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16263F), Color(0xFF0A1424)],
              ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: faceUp
              ? Colors.black.withOpacity(0.25)
              : ArenaColors.gold.withOpacity(0.6),
          width: faceUp ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 3,
            child: Column(
              children: [
                Text(
                  rank,
                  style: TextStyle(
                    fontSize: width * 0.26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: faceUp ? pip : ArenaColors.gold,
                  ),
                ),
                Text(
                  suit,
                  style: TextStyle(
                    fontSize: width * 0.22,
                    height: 1.1,
                    color: faceUp ? pip : ArenaColors.gold,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              suit,
              style: TextStyle(
                fontSize: width * 0.5,
                color: faceUp
                    ? pip.withOpacity(0.9)
                    : ArenaColors.gold.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The golden 10 of spades: gold gradient face, big serif "10",
/// spades in the corners and centre — the hero card from the concept.
class _HeroTenCard extends StatelessWidget {
  const _HeroTenCard({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.42;
    const deep = Color(0xFF6B4E00);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9A8), Color(0xFFFFC857), Color(0xFFD4A017)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A6D1B), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 6,
            child: Column(
              children: [
                Text(
                  '10',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: width * 0.24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: deep,
                  ),
                ),
                const Text('♠', style: TextStyle(fontSize: 16, color: deep)),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 6,
            child: Text(
              '♠',
              style: TextStyle(fontSize: width * 0.2, color: deep),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '♠',
                  style: TextStyle(
                    fontSize: width * 0.3,
                    color: deep.withOpacity(0.9),
                  ),
                ),
                Text(
                  '10',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: width * 0.52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: deep,
                  ),
                ),
                Text(
                  '♠',
                  style: TextStyle(
                    fontSize: width * 0.3,
                    color: deep.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 6,
            child: Transform.rotate(
              angle: math.pi,
              child: Column(
                children: [
                  Text(
                    '10',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: width * 0.24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: deep,
                    ),
                  ),
                  const Text('♠', style: TextStyle(fontSize: 16, color: deep)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold sparkles drifting slowly upward, looping forever. One
/// repeating controller drives a [CustomPainter] — cheap on purpose:
/// ~18 tiny dots in a small box, no images, no per-sparkle widgets.
class SparkleField extends StatefulWidget {
  const SparkleField({super.key});

  @override
  State<SparkleField> createState() => _SparkleFieldState();
}

class _SparkleFieldState extends State<SparkleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) =>
          CustomPaint(painter: _SparklePainter(_ctrl.value), willChange: true),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.progress);

  /// 0→1, loops every 9 seconds.
  final double progress;

  static double _frac(double v) => v - v.floor();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final x = _frac(math.sin(i * 12.9898) * 43758.5453) * size.width;
      // Each sparkle rises at its own slow speed, then loops.
      final speed = 0.10 + _frac(math.sin(i * 78.233) * 12543.21) * 0.16;
      final rise = (i * 0.0618 + progress * speed) % 1.0;
      final y = size.height * (1 - rise);
      // Fade in at the bottom, out at the top, and twinkle as it goes.
      final fade = math.sin(math.pi * rise);
      final twinkle =
          0.55 + 0.45 * math.sin((progress * 12 + i * 1.7) * math.pi);
      final alpha = (0.8 * fade * twinkle).clamp(0.0, 1.0);
      if (alpha < 0.03) continue;
      final r = 1.0 + (i % 3) * 0.7;
      paint.color = ArenaColors.gold.withOpacity(alpha);
      canvas.drawCircle(Offset(x, y), r, paint);
      // Every fifth sparkle gets a tiny 4-point star glint.
      if (i % 5 == 0) {
        final g = r * 3.2;
        paint.strokeWidth = 0.8;
        canvas.drawLine(Offset(x - g, y), Offset(x + g, y), paint);
        canvas.drawLine(Offset(x, y - g), Offset(x, y + g), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.progress != progress;
}

/// Soft gold glow that breathes around the main Play/Continue button
/// so the eye lands on it first. Wraps the button only — it never
/// moves, resizes or covers anything.
class GlowPulse extends StatefulWidget {
  const GlowPulse({super.key, required this.child});

  final Widget child;

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

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
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: ArenaColors.gold.withOpacity(0.22 + 0.30 * t),
                blurRadius: 14 + 16 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
