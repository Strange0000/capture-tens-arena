import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/match_state.dart';
import '../models/rank_info.dart';
import '../services/audio_service.dart';

/// Full-screen overlay shown when phase == 'complete'.
/// Shows win/lose, score summary, rank change, and confetti for the winner.
class MatchResultOverlay extends StatefulWidget {
  const MatchResultOverlay({
    super.key,
    required this.match,
    required this.myTeam,
    required this.onPlayAgain,
    required this.onHome,
    this.rankUpdate,
  });

  final MatchState match;
  final String myTeam;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;
  final Map<String, dynamic>? rankUpdate;

  @override
  State<MatchResultOverlay> createState() => _MatchResultOverlayState();
}

class _MatchResultOverlayState extends State<MatchResultOverlay>
    with TickerProviderStateMixin {
  late final ConfettiController _confetti;
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;
  late final AnimationController _countCtrl;
  late final Animation<double> _countAnim;
  late final AnimationController _flashCtrl;

  bool get _won => widget.match.winnerTeam == widget.myTeam;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _countCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _countAnim = CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic);

    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _confetti = ConfettiController(duration: const Duration(seconds: 6));

    // Sequence animations
    if (_won) {
      _flashCtrl.forward().then((_) => _flashCtrl.reverse());
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _confetti.play();
      });
      AudioService.instance.playMatchWin();
      AudioService.instance.hapticHeavy();
    } else {
      AudioService.instance.playMatchLose();
      AudioService.instance.hapticMedium();
    }
    _anim.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _countCtrl.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _glowCtrl.dispose();
    _countCtrl.dispose();
    _flashCtrl.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.match.winnerTeam;
    final a = widget.match.captures.a;
    final b = widget.match.captures.b;
    final ru = widget.rankUpdate;

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.92),
                  const Color(0xFF070B13).withOpacity(0.97),
                ],
              ),
            ),
          ),
        ),

        // Golden flash for victory
        if (_won)
          AnimatedBuilder(
            animation: _flashCtrl,
            builder: (context, _) => Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857).withOpacity(_flashCtrl.value * 0.15),
                ),
              ),
            ),
          ),

        // Confetti
        if (_won)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 35,
              colors: const [
                Color(0xFFFFC857), Color(0xFF48E5C2), Colors.white,
                Color(0xFFFF6B6B), Color(0xFF7C4DFF),
              ],
              gravity: 0.18,
              emissionFrequency: 0.06,
              maxBlastForce: 18,
              minBlastForce: 6,
            ),
          ),

        // Content card
        Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF101826),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _won ? const Color(0xFFFFC857).withOpacity(0.6) : Colors.white12,
                  width: _won ? 2 : 1,
                ),
                boxShadow: _won
                    ? [BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.25), blurRadius: 50, spreadRadius: 6)]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with pulsing glow
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (context, child) => Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: _won
                            ? [BoxShadow(
                                color: const Color(0xFFFFC857).withOpacity(_glowAnim.value * 0.5),
                                blurRadius: 30 + _glowAnim.value * 20,
                                spreadRadius: _glowAnim.value * 8,
                              )]
                            : [],
                      ),
                      child: child,
                    ),
                    child: _won
                        ? const Icon(Icons.emoji_events_rounded, size: 72, color: Color(0xFFFFC857))
                        : const Icon(Icons.sentiment_dissatisfied_rounded, size: 72, color: Colors.white38),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    _won ? 'Victory!' : 'Defeated',
                    style: TextStyle(
                      fontSize: 38, fontWeight: FontWeight.w900,
                      color: _won ? const Color(0xFFFFC857) : Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _won ? 'Congratulations! You captured the most tens!' : 'Better luck next time!',
                    style: TextStyle(fontSize: 13, color: _won ? Colors.white60 : Colors.white38, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),

                  if (winner != null) ...[
                    const SizedBox(height: 4),
                    Text('Team $winner wins',
                      style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Rank change display
                  if (ru != null) ...[
                    const SizedBox(height: 16),
                    _RankChangeWidget(rankUpdate: ru),
                  ],

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  // Animated score table
                  AnimatedBuilder(
                    animation: _countAnim,
                    builder: (context, _) => Row(
                      children: [
                        _ScoreCol(label: 'Team A', captures: a, highlight: winner == 'A', progress: _countAnim.value),
                        const SizedBox(width: 16),
                        Container(width: 1, height: 80, color: Colors.white10),
                        const SizedBox(width: 16),
                        _ScoreCol(label: 'Team B', captures: b, highlight: winner == 'B', progress: _countAnim.value),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onHome,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(56, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Home'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onPlayAgain,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(56, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Play Again'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated rank change display
class _RankChangeWidget extends StatelessWidget {
  const _RankChangeWidget({required this.rankUpdate});
  final Map<String, dynamic> rankUpdate;

  @override
  Widget build(BuildContext context) {
    final oldMmr = rankUpdate['oldMmr'] as int? ?? 0;
    final newMmr = rankUpdate['newMmr'] as int? ?? 0;
    final delta = rankUpdate['mmrDelta'] as int? ?? 0;
    final gained = delta >= 0;

    final oldRank = RankInfo.fromMmr(oldMmr);
    final newRank = RankInfo.fromMmr(newMmr);
    final tierChanged = oldRank.displayName != newRank.displayName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gained ? const Color(0xFF48E5C2).withOpacity(0.3) : Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          if (tierChanged) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(oldRank.icon, height: 24, width: 24),
                const SizedBox(width: 4),
                Text(oldRank.displayName, style: TextStyle(color: oldRank.color, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 16, color: gained ? const Color(0xFF48E5C2) : Colors.redAccent),
                const SizedBox(width: 8),
                Image.asset(newRank.icon, height: 24, width: 24),
                const SizedBox(width: 4),
                Text(newRank.displayName, style: TextStyle(color: newRank.color, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text(
            '${gained ? "+" : ""}$delta MMR',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: gained ? const Color(0xFF48E5C2) : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCol extends StatelessWidget {
  const _ScoreCol({required this.label, required this.captures, required this.highlight, required this.progress});
  final String label;
  final TeamCaptures captures;
  final bool highlight;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: highlight ? const Color(0xFFFFC857) : Colors.white54)),
          const SizedBox(height: 10),
          _AnimRow(label: '10s', value: captures.tens, highlight: highlight && captures.tens > 0, progress: progress),
          _AnimRow(label: 'Cards', value: captures.cards, highlight: false, progress: progress),
          _AnimRow(label: 'Aces', value: captures.aces, highlight: false, progress: progress),
        ],
      ),
    );
  }
}

class _AnimRow extends StatelessWidget {
  const _AnimRow({required this.label, required this.value, required this.highlight, required this.progress});
  final String label;
  final int value;
  final bool highlight;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Text('${(value * progress).round()}',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: highlight ? const Color(0xFFFFC857) : Colors.white),
          ),
        ],
      ),
    );
  }
}
