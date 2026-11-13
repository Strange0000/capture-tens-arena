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
  const RoyalBackground({super.key, required this.child, this.showSuits = true});
  final Widget child;
  final bool showSuits;

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
                  Color(0xFF0E3A28),
                  Color(0xFF08130D),
                  Color(0xFF050B08),
                ],
              ),
            ),
          ),
        ),
        // Soft gold light from above, like a casino lamp.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ArenaColors.gold.withOpacity(0.07),
                  Colors.transparent,
                  Colors.black.withOpacity(0.25),
                ],
                stops: const [0.0, 0.35, 1.0],
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
        color: ArenaColors.panel.withOpacity(0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: goldBorder
              ? ArenaColors.gold.withOpacity(0.35)
              : Colors.white.withOpacity(0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Primary gold button: gold gradient, dark text, rounded corners —
/// the big "Play" button of the casino. Secondary is a gold outline
/// on dark felt.
class RoyalGoldButton extends StatelessWidget {
  const RoyalGoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = true,
    this.loading = false,
    this.height = 56,
  });
  final String label;
  final VoidCallback? onTap;
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
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ArenaColors.ink,
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 22, color: primary ? ArenaColors.ink : ArenaColors.gold),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            loading ? 'Please wait…' : label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: primary ? ArenaColors.ink : ArenaColors.gold,
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
                      colors: [Color(0xFFFFD166), Color(0xFFFFC857), Color(0xFFD4A017)],
                    )
                  : null,
              color: primary ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: primary
                  ? Border.all(color: const Color(0xFF8A6D1B), width: 1)
                  : Border.all(color: ArenaColors.gold.withOpacity(0.5), width: 1),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: ArenaColors.gold.withOpacity(0.30),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// Gold serif-style display title, like the mockups: gold gradient
/// text with a thin gold rule underneath.
class RoyalTitle extends StatelessWidget {
  const RoyalTitle(this.text, {super.key, this.fontSize = 34});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFE9A8), Color(0xFFFFC857), Color(0xFFD4A017)],
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.05,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 1, color: ArenaColors.gold.withOpacity(0.5)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('✦', style: TextStyle(color: ArenaColors.gold, fontSize: 10)),
            ),
            Container(width: 44, height: 1, color: ArenaColors.gold.withOpacity(0.5)),
          ],
        ),
      ],
    );
  }
}
