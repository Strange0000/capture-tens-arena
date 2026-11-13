import 'package:flutter/material.dart';

import '../theme.dart';

/// Branded loading state used everywhere the app has to wait — guest
/// sign-in, lobby gate, match setup. Never a bare spinner on a blank
/// screen: logo, gold spinner, a clear message, and (optionally) a
/// second line explaining a slow wait, e.g. the backend waking up.
class ArenaLoading extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: ArenaColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLogo) ...[
                Image.asset(
                  'assets/images/lobby_hero_logo.png',
                  height: 84,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    '♠ ♥',
                    style: TextStyle(fontSize: 40, color: ArenaColors.gold),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CAPTURE TENS ARENA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: ArenaColors.gold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  subMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
