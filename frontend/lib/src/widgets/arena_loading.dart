import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Luxury casino-grade loading state used across the app — guest sign-in,
/// lobby transition, match setup, and server connecting.
///
/// Features:
/// - Deep casino emerald & onyx radial backdrop with subtle ambient light pool.
/// - Floating subtle card suit motes (♠ ♥ ♦ ♣).
/// - Pulsing golden hero medallion with soft breathing glow.
/// - Gold-foil gradient typography with ornamental diamond divider.
/// - Custom dual-ring golden astrolabe spinner with orbiting gems.
/// - Live status capsule with pulsing emerald beacon and dynamic atmosphere cues.
class ArenaLoading extends StatefulWidget {
  const ArenaLoading({
    super.key,
    required this.message,
    this.subMessage,
    this.showLogo = true,
  });

  final String message;
  final String? subMessage;
  final bool showLogo;

  @override
  State<ArenaLoading> createState() => _ArenaLoadingState();
}

class _ArenaLoadingState extends State<ArenaLoading> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _driftCtrl;
  Timer? _tipTimer;
  int _tipIndex = 0;

  static const List<String> _atmosphereCues = [
    'Shuffling the 52-card Royal deck…',
    'Entering the Grand Salon…',
    'Preparing your seat at the table…',
    'Balancing competitive tiers & MMR…',
    'Inspecting the emerald felt…',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _tipTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) {
        setState(() {
          _tipIndex = (_tipIndex + 1) % _atmosphereCues.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _pulseCtrl.dispose();
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSubMessage = widget.subMessage != null && widget.subMessage!.isNotEmpty
        ? widget.subMessage!
        : _atmosphereCues[_tipIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF040907),
      body: Stack(
        children: [
          // ── 1. Deep Casino Background (Radial + Cinematic Backdrop) ─────
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Deep radial base
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.15),
                      radius: 1.15,
                      colors: [
                        Color(0xFF0F3827), // Deep casino emerald center
                        Color(0xFF092218),
                        Color(0xFF040A07), // Velvet onyx vignette edge
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Cinematic background art
                Image.asset(
                  'assets/images/arena_loading_bg.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                // Dark velvet vignette overlay for contrast & readability
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.1),
                      radius: 1.0,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        const Color(0xFF040A07).withOpacity(0.85),
                        const Color(0xFF040A07),
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Floating Card Suit Motes ─────────────────────────────────
          AnimatedBuilder(
            animation: _driftCtrl,
            builder: (context, _) {
              final t = _driftCtrl.value * 2 * math.pi;
              return Stack(
                children: [
                  _FloatingSuit(
                    suit: '♠',
                    left: 0.12,
                    top: 0.20 + 0.03 * math.sin(t),
                    opacity: 0.06,
                    size: 38,
                  ),
                  _FloatingSuit(
                    suit: '♥',
                    left: 0.82,
                    top: 0.24 + 0.03 * math.cos(t),
                    opacity: 0.07,
                    size: 42,
                    color: const Color(0xFFFF5252),
                  ),
                  _FloatingSuit(
                    suit: '♦',
                    left: 0.18,
                    top: 0.72 + 0.02 * math.sin(t + 1),
                    opacity: 0.07,
                    size: 34,
                    color: const Color(0xFFFFD166),
                  ),
                  _FloatingSuit(
                    suit: '♣',
                    left: 0.78,
                    top: 0.76 + 0.02 * math.cos(t + 2),
                    opacity: 0.06,
                    size: 36,
                  ),
                ],
              );
            },
          ),

          // ── 3. Centered Content ─────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showLogo) ...[
                    // Breathing Hero Medallion with Golden Backglow
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, _) {
                        final pulse = _pulseCtrl.value;
                        return Transform.scale(
                          scale: 0.98 + (0.04 * pulse),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Radial light pool
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFC857).withOpacity(0.18 + 0.12 * pulse),
                                      blurRadius: 40 + (16 * pulse),
                                      spreadRadius: 8 + (6 * pulse),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF1B7A4D).withOpacity(0.35),
                                      blurRadius: 70,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              // Emblem container
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFFFC857).withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.6),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/images/lobby_hero_logo.png',
                                    height: 104,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Text(
                                      '♠ 10 ♥',
                                      style: TextStyle(fontSize: 48, color: ArenaColors.gold),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // Gold Foil Gradient Marquee
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFFFF9E6),
                          Color(0xFFFFD166),
                          Color(0xFFD4A017),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: const Text(
                        'CAPTURE TENS ARENA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Ornamental Diamond Divider
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFFFC857).withOpacity(0.55),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '♦',
                            style: TextStyle(
                              color: Color(0xFFFFC857),
                              fontSize: 9,
                            ),
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFFC857).withOpacity(0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                  ],

                  // ── 4. Dual-Ring Golden Astrolabe Loader ─────────────────
                  const _GoldenAstrolabeLoader(),

                  const SizedBox(height: 24),

                  // ── 5. Status Capsule ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C2B1E).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF3FA97C).withOpacity(0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3FA97C).withOpacity(0.14),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3FA97C),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF3FA97C),
                                blurRadius: 8,
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 6. Dynamic Atmosphere Lore / Submessage ─────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      effectiveSubMessage,
                      key: ValueKey<String>(effectiveSubMessage),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating semi-transparent card suit in background.
class _FloatingSuit extends StatelessWidget {
  const _FloatingSuit({
    required this.suit,
    required this.left,
    required this.top,
    required this.opacity,
    required this.size,
    this.color = const Color(0xFFFFC857),
  });

  final String suit;
  final double left;
  final double top;
  final double opacity;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sizeOf = MediaQuery.sizeOf(context);
    return Positioned(
      left: sizeOf.width * left,
      top: sizeOf.height * top,
      child: IgnorePointer(
        child: Text(
          suit,
          style: TextStyle(
            color: color.withOpacity(opacity),
            fontSize: size,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Custom luxury dual-ring celestial astrolabe loader.
/// Outer golden orbit with diamond pip counter-rotating against inner emerald ring.
class _GoldenAstrolabeLoader extends StatefulWidget {
  const _GoldenAstrolabeLoader();

  @override
  State<_GoldenAstrolabeLoader> createState() => _GoldenAstrolabeLoaderState();
}

class _GoldenAstrolabeLoaderState extends State<_GoldenAstrolabeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
      builder: (context, _) {
        final val = _ctrl.value;
        return SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating gold ring with diamond pip
              Transform.rotate(
                angle: val * 2 * math.pi,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFC857).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD166),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFFFD166),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Inner counter-rotating emerald ring
              Transform.rotate(
                angle: -val * 2 * math.pi * 1.5,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3FA97C).withOpacity(0.4),
                      width: 1.3,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3FA97C),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF3FA97C),
                            blurRadius: 6,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Core pulsating jewel
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD166).withOpacity(0.55 + 0.35 * math.sin(val * 2 * math.pi)),
                      blurRadius: 14,
                      spreadRadius: 2.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
