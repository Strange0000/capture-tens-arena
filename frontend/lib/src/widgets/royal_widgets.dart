import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared Royal Casino building blocks: one felt background, one
/// gold-bordered panel and one gold button, used by the login / home,
/// lobby and game screens so the whole game reads as one casino room.
///
/// Colours come from [ArenaColors] — deep green felt, dark casino
/// black-green, gold as the single primary accent, cream text.

/// Full-screen casino felt: dark green radial felt over near-black,
/// a soft gold glow at the top, and very faint suit glyphs so the
/// background has texture without fighting the content.
class RoyalBackground extends StatelessWidget {
  const RoyalBackground({
    super.key,
    required this.child,
    this.showSuits = true,
    this.useCinematicBackdrop = true,
  });
  final Widget child;
  final bool showSuits;
  final bool useCinematicBackdrop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 1.25,
                colors: [
                  Color(0xFF0F3827),
                  Color(0xFF08150F),
                  Color(0xFF040A07),
                ],
              ),
            ),
          ),
        ),
        if (useCinematicBackdrop)
          Positioned.fill(
            child: Image.asset(
              'assets/images/arena_loading_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 1.15,
                colors: [
                  Colors.black.withOpacity(useCinematicBackdrop ? 0.38 : 0.0),
                  const Color(0xFF040A07).withOpacity(useCinematicBackdrop ? 0.86 : 0.40),
                  const Color(0xFF040A07),
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
          ),
        ),
        // Soft gold light from above, like a casino chandelier spotlight.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ArenaColors.gold.withOpacity(0.10),
                  Colors.transparent,
                  Colors.black.withOpacity(0.30),
                ],
                stops: const [0.0, 0.40, 1.0],
              ),
            ),
          ),
        ),
        if (showSuits)
          Positioned.fill(
            child: IgnorePointer(
              child: _FaintSuits(),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _FaintSuits extends StatelessWidget {
  static const _suits = ['♠', '♥', '♦', '♣'];
  static const _positions = [
    (0.06, 0.12, 54.0),
    (0.88, 0.08, 44.0),
    (0.12, 0.78, 46.0),
    (0.86, 0.72, 58.0),
    (0.48, 0.05, 36.0),
    (0.94, 0.45, 38.0),
    (0.03, 0.45, 34.0),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: _positions.asMap().entries.map((e) {
            final (fx, fy, size) = e.value;
            final suit = _suits[e.key % _suits.length];
            final isRed = suit == '♥' || suit == '♦';
            return Positioned(
              left: constraints.maxWidth * fx,
              top: constraints.maxHeight * fy,
              child: Text(
                suit,
                style: TextStyle(
                  fontSize: size,
                  color: (isRed ? ArenaColors.ruby : Colors.white)
                      .withOpacity(0.045),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Dark green panel with a thin gold border — the casino "plaque"
/// used for cards, banners and sheets across the app.
class RoyalPanel extends StatelessWidget {
  const RoyalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 18,
    this.goldBorder = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool goldBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF07140E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: goldBorder
              ? const Color(0xFFD4A017).withOpacity(0.42)
              : Colors.white.withOpacity(0.12),
          width: 1.2,
        ),
        boxShadow: [
          if (goldBorder)
            BoxShadow(
              color: const Color(0xFFD4A017).withOpacity(0.08),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Primary gold button: gold gradient, dark text, rounded corners —
/// the big "Play" button of the casino. Secondary is a dark frosted velvet
/// button with a gold outline and champagne text.
class RoyalGoldButton extends StatelessWidget {
  const RoyalGoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = true,
    this.loading = false,
    this.height = 56,
    this.labelWidget,
  });
  final String label;
  final VoidCallback? onTap;
  /// Optional rich label (e.g. "Continue as " + bold username).
  final Widget? labelWidget;
  final IconData? icon;
  final bool primary;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? ArenaColors.ink : ArenaColors.gold,
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 22, color: primary ? const Color(0xFF070B13) : ArenaColors.goldSoft),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: labelWidget ??
              Text(
                loading ? 'Please wait…' : label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: primary ? const Color(0xFF070B13) : ArenaColors.goldSoft,
                ),
              ),
        ),
      ],
    );
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: primary
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFF2C2),
                        Color(0xFFFFD166),
                        Color(0xFFFFC857),
                        Color(0xFFD4A017),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF132B1F),
                        Color(0xFF0A1811),
                      ],
                    ),
              borderRadius: BorderRadius.circular(12),
              border: primary
                  ? Border.all(color: const Color(0xFFB38615), width: 1.2)
                  : Border.all(color: ArenaColors.gold.withOpacity(0.50), width: 1.2),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD166).withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// Gold serif-style display title, like the mockups: gold gradient
/// text with an ornamental diamond rule underneath.
class RoyalTitle extends StatelessWidget {
  const RoyalTitle(
    this.text, {
    super.key,
    this.fontSize = 34,
    this.letterSpacing = 1.5,
    this.subtitle,
  });
  final String text;
  final double fontSize;
  final double letterSpacing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF2C2),
              Color(0xFFFFD166),
              Color(0xFFFFC857),
              Color(0xFFD4A017),
            ],
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.08,
              letterSpacing: letterSpacing,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    ArenaColors.gold.withOpacity(0.65),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '♦',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 11,
                  shadows: [
                    Shadow(color: Color(0x88FFD166), blurRadius: 6),
                  ],
                ),
              ),
            ),
            Container(
              width: 48,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ArenaColors.gold.withOpacity(0.65),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Color(0xFFD6C8A1),
            ),
          ),
        ],
      ],
    );
  }
}
