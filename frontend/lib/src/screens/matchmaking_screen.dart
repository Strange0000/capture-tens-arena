import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'lobby_screen.dart' show showFriendsPicker;

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
  final TextEditingController _friendUsernameController = TextEditingController();

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
    _friendUsernameController.dispose();
    super.dispose();
  }

  String get _elapsed {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showPartyInviteDialog(AppState app) {
    final invite = app.pendingPartyInvite;
    if (invite == null) return;
    app.pendingPartyInvite = null;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101826),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Duo invite', style: TextStyle(color: Colors.white)),
        content: Text('${invite['from'] ?? 'A friend'} invited you to form a ranked duo.',
          style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(onPressed: () { app.declinePartyInvite(); Navigator.pop(dialogContext); }, child: const Text('Not now')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC857), foregroundColor: const Color(0xFF1C1608)),
            onPressed: () { app.acceptPartyInvite(invite['partyId']?.toString()); Navigator.pop(dialogContext); },
            icon: const Icon(Icons.people_alt_rounded), label: const Text('Join duo'),
          ),
        ],
      ),
    );
  }

  void _showRoomInviteDialog(AppState app) {
    final invite = app.pendingRoomInvite;
    if (invite == null) return;
    app.pendingRoomInvite = null;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101826),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Private room invite', style: TextStyle(color: Colors.white)),
        content: Text('${invite['from'] ?? 'A friend'} invited you to room ${invite['code'] ?? ''}. Joining will leave your current search.',
          style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(onPressed: () { app.declineRoomInvite(); Navigator.pop(dialogContext); }, child: const Text('Not now')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB388FF), foregroundColor: const Color(0xFF160D27)),
            onPressed: () { app.acceptRoomInvite(invite['code']?.toString()); Navigator.pop(dialogContext); },
            icon: const Icon(Icons.login_rounded), label: const Text('Join room'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isCustom = app.roomCode != null || app.match?.mode == 'private';

    if (app.pendingPartyInvite != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPartyInviteDialog(app);
      });
    }
    if (app.pendingRoomInvite != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRoomInviteDialog(app);
      });
    }

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
      _navigationTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }

    return Scaffold(
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

          // Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Animated radar/portal
                    _AnimatedPortal(
                      pulseCtrl: _pulseCtrl,
                      rotateCtrl: _rotateCtrl,
                      searchCtrl: _searchCtrl,
                    ),

                    const SizedBox(height: 48),

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

                    const SizedBox(height: 32),

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

                    const Spacer(flex: 2),

                    // Dot animation
                    _DotLoader(),

                    const SizedBox(height: 32),

                    // Invite a teammate while searching. The backend cancels this
                    // queue before the invited duo can start a fresh ranked search.
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: const Color(0xFFB388FF).withOpacity(0.65)),
                        foregroundColor: const Color(0xFFD4C0FF),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isCustom ? null : () => showFriendsPicker(
                        context,
                        controller: _friendUsernameController,
                        subtitle: 'Invite an accepted friend to form a duo. Ranked search pauses while you build your team.',
                        onInvite: app.inviteToParty,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Invite teammate', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 12),

                    // Cancel button
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
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
  });

  final AnimationController pulseCtrl;
  final AnimationController rotateCtrl;
  final AnimationController searchCtrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulseCtrl, rotateCtrl, searchCtrl]),
        builder: (context, _) {
          final pulse = Curves.easeInOut.transform(pulseCtrl.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 220,
                height: 220,
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
                width: 160,
                height: 160,
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
                  size: const Size(140, 140),
                  painter: _ArcPainter(),
                ),
              ),
              // Inner core
              Container(
                width: 80,
                height: 80,
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
                child: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF48E5C2),
                  size: 32,
                ),
              ),
              // Scanning line
              Transform.rotate(
                angle: searchCtrl.value * 2 * pi,
                child: Container(
                  width: 1.5,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 80),
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
