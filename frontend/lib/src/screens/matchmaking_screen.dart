import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;
  late final AnimationController _searchCtrl;
  int _elapsedSeconds = 0;
  bool _navigationTriggered = false;
  /// Round 10: true once this screen has started leaving (a pop is
  /// already in progress or was requested). The auto-pop branch below
  /// must never fire during its own pop transition — see build().
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _searchCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    // Increment elapsed time every second
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      _startTimer();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _elapsed {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isCustom = app.roomCode != null || app.match?.mode == 'private';

    // Auto-redirect to login if not logged in
    if (!app.isLoggedIn) {
      if (app.isAuthChecking) {
        return const Scaffold(
          backgroundColor: Color(0xFF070B13),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        }
      });
      return const Scaffold(
        backgroundColor: Color(0xFF070B13),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Make a single navigation decision per screen instance. Previously the
    // cancel button popped manually while this state listener also popped,
    // which could leave the route stack stuck or pop the lobby as well.
    if (!_navigationTriggered && app.match != null) {
      _navigationTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/game');
        }
      });
    } else if (!_navigationTriggered &&
        app.lobbyStatus == LobbyStatus.idle &&
        app.match == null) {
      // Round 10 — the black screen on browser Back: Back pops this
      // route, then PopScope (below) cancels the queue, which sets
      // lobbyStatus = idle and rebuilds THIS screen while its pop
      // transition is still running. The unguarded post-frame pop
      // below then fired a SECOND pop — popping the lobby route (or
      // stalling the transition) and leaving this near-black
      // Scaffold on screen with the URL already at #/lobby. Only
      // auto-pop when this route is still current AND no leave is
      // already in progress.
      if (ModalRoute.of(context)?.isCurrent == true && !_leaving) {
        _navigationTriggered = true;
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
      }
    }

    // Round 8: leaving this screen must always cancel the queue.
    // Browser back used to just pop the route, leaving the search
    // running — the lobby then showed "MATCHMAKING IN PROGRESS" and
    // only its banner could stop it. PopScope cancels on any pop
    // (back button, swipe, or programmatic) — but only while still
    // searching: when a match was just found, the route is replaced
    // by /game, and cancelling then would wipe the new match
    // (cancelRankedQueue clears app.match), so that case is guarded.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Round 10: mark the leave FIRST — the cancel below rebuilds
        // this screen mid-pop with lobbyStatus == idle, and the
        // auto-pop branch in build() must not fire a second pop.
        if (didPop) _leaving = true;
        if (didPop &&
            app.match == null &&
            app.lobbyStatus == LobbyStatus.queuing) {
          app.cancelRankedQueue();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF070B13),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/images/matchmaking_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF070B13).withOpacity(0.5),
                    const Color(0xFF070B13).withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          // Content — Round 8: scrollable, so the Cancel button is
          // always reachable. The old fixed Column (220px portal +
          // spacers + timer + badge) was ~640px tall, so at a 506px
          // window the Cancel button sat below the viewport and the
          // screen looked like it had no Cancel at all. On short
          // screens the portal and gaps shrink too.
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isShort = constraints.maxHeight < 560;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: isShort ? 8 : 24),

                          // Animated radar/portal
                          _AnimatedPortal(
                            pulseCtrl: _pulseCtrl,
                            rotateCtrl: _rotateCtrl,
                            searchCtrl: _searchCtrl,
                            size: isShort ? 140 : 220,
                          ),

                          SizedBox(height: isShort ? 24 : 48),

                    // Searching text
                    Text(
                      isCustom ? 'CUSTOM ROOM' : 'FINDING OPPONENTS',
                      style: const TextStyle(
                        fontSize: 13,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFC857),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isCustom ? 'Room ${app.roomCode ?? ""}' : 'Ranked Match',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCustom
                          ? 'Waiting for players to join…'
                          : 'Searching for players of similar rank…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                    ),

                    SizedBox(height: isShort ? 16 : 32),

                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Color(0xFF48E5C2), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _elapsed,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF48E5C2),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // MMR badge (ONLY shown for Ranked Matches!)
                    if (!isCustom && app.rankInfo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: app.rankInfo!.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: app.rankInfo!.color.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(app.rankInfo!.icon, height: 20, width: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${app.rankInfo!.displayName}  ·  ${app.rankInfo!.mmr} MMR',
                              style: TextStyle(
                                color: app.rankInfo!.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: isShort ? 16 : 32),

                    // Dot animation
                    _DotLoader(),

                    SizedBox(height: isShort ? 16 : 32),

                    // Cancel button — always reachable now: the
                    // scrollable layout guarantees it is on screen
                    // (or one scroll away) at any window height.
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        app.cancelRankedQueue();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel Search', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),

                    SizedBox(height: isShort ? 16 : 40),
                  ],
                ),
              ),
            ),
          );
            },
          ),
        ),
      ],
    ),
  ),
);
  }
}

// ── Animated radar portal ──────────────────────────────────────────────────────

class _AnimatedPortal extends StatelessWidget {
  const _AnimatedPortal({
    required this.pulseCtrl,
    required this.rotateCtrl,
    required this.searchCtrl,
    this.size = 220,
  });

  final AnimationController pulseCtrl;
  final AnimationController rotateCtrl;
  final AnimationController searchCtrl;

  /// Outer diameter. Round 8: shrinks on short screens (140px) so
  /// the Cancel button still fits in the viewport.
  final double size;

  @override
  Widget build(BuildContext context) {
    final f = size / 220;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulseCtrl, rotateCtrl, searchCtrl]),
        builder: (context, _) {
          final pulse = Curves.easeInOut.transform(pulseCtrl.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFC857).withOpacity(0.15 + pulse * 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC857).withOpacity(0.05 + pulse * 0.1),
                      blurRadius: 30 + pulse * 20,
                      spreadRadius: pulse * 8,
                    ),
                  ],
                ),
              ),
              // Middle ring
              Container(
                width: 160 * f,
                height: 160 * f,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF48E5C2).withOpacity(0.2 + pulse * 0.2),
                    width: 1.5,
                  ),
                ),
              ),
              // Rotating arc
              Transform.rotate(
                angle: rotateCtrl.value * 2 * pi,
                child: CustomPaint(
                  size: Size(140 * f, 140 * f),
                  painter: _ArcPainter(),
                ),
              ),
              // Inner core
              Container(
                width: 80 * f,
                height: 80 * f,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF48E5C2).withOpacity(0.3 + pulse * 0.2),
                      const Color(0xFF48E5C2).withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF48E5C2).withOpacity(0.6),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: const Color(0xFF48E5C2),
                  size: 32 * f,
                ),
              ),
              // Scanning line
              Transform.rotate(
                angle: searchCtrl.value * 2 * pi,
                child: Container(
                  width: 1.5,
                  height: 80 * f,
                  margin: EdgeInsets.only(bottom: 80 * f),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF48E5C2).withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC857).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    );
    canvas.drawArc(rect, 0, pi * 0.8, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Dot loader ────────────────────────────────────────────────────────────────

class _DotLoader extends StatefulWidget {
  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _activeDot = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _activeDot = (_activeDot + 1) % 3);
          _ctrl.reset();
          _ctrl.forward();
        }
      });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final active = i == _activeDot;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFFC857)
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
