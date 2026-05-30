import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  bool _loading = false;
  bool _buttonsVisible = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);

    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _buttonsVisible = true);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _continueAsExisting() async {
    setState(() => _loading = true);
    final app = context.read<AppState>();
    try {
      await app.continueAsExisting();
      if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session expired. Please sign in again.'), backgroundColor: Colors.redAccent));
        await app.auth.clearSession();
        app.cachedUsername = null;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginAsGuest() async {
    setState(() => _loading = true);
    final app = context.read<AppState>();
    try {
      await app.bootGuest();
      if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    final app = context.read<AppState>();
    try {
      await app.loginWithGoogle();
      if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final hasCached = app.hasCachedSession;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Premium background image
          Positioned.fill(
            child: Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          ),
          // Dark glass overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF070B13).withOpacity(0.55),
                    const Color(0xFF070B13).withOpacity(0.80),
                    const Color(0xFF070B13).withOpacity(0.92),
                  ],
                ),
              ),
            ),
          ),

          // Ambient glow spots
          Positioned(top: -120, right: -80, child: _GlowOrb(color: const Color(0xFF48E5C2), size: 350, opacity: 0.05)),
          Positioned(bottom: -100, left: -60, child: _GlowOrb(color: const Color(0xFFFFC857), size: 300, opacity: 0.04)),
          Positioned(top: screenHeight * 0.3, left: -140, child: _GlowOrb(color: const Color(0xFF7C4DFF), size: 280, opacity: 0.03)),

          // Floating suit symbols
          ..._buildFloatingSuits(),

          // Main content
          Positioned.fill(
            child: SafeArea(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

                      // Premium logo
                      _buildLogo(),
                      const SizedBox(height: 32),

                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFB0BEC5)],
                        ).createShader(bounds),
                        child: const Text('Capture Tens', style: TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1, letterSpacing: -1,
                        )),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF48E5C2), Color(0xFF30B89C)],
                        ).createShader(bounds),
                        child: const Text('Arena', style: TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2, letterSpacing: -1,
                        )),
                      ),
                      const SizedBox(height: 10),
                      const Text('The ultimate trick-taking card game', style: TextStyle(
                        fontSize: 13, color: Colors.white30, fontWeight: FontWeight.w500, letterSpacing: 0.5,
                      )),

                      const Spacer(flex: 2),

                      // Card suits strip with dividers
                      _buildSuitStrip(),
                      const SizedBox(height: 36),

                      // Buttons
                      AnimatedOpacity(
                        opacity: _buttonsVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 700),
                        child: AnimatedSlide(
                          offset: _buttonsVisible ? Offset.zero : const Offset(0, 0.2),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          child: _buildButtons(hasCached, app),
                        ),
                      ),

                      const Spacer(),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'v1.0  ·  Strategy • Teamwork • Tens',
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.15), letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulseCtrl.value);
        return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF48E5C2).withOpacity(0.15 + t * 0.2),
                blurRadius: 30 + t * 20,
                spreadRadius: t * 6,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/lobby_hero_logo.png',
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  Widget _buildSuitStrip() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SuitIcon('♥', const Color(0xFFE53935)),
        _dot(),
        _SuitIcon('♦', const Color(0xFFE53935)),
        _dot(),
        _SuitIcon('♣', Colors.white),
        _dot(),
        _SuitIcon('♠', Colors.white),
      ],
    );
  }

  Widget _dot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10)),
  );

  Widget _SuitIcon(String s, Color c) => Text(s, style: TextStyle(fontSize: 28, color: c.withOpacity(0.18)));

  Widget _buildButtons(bool hasCached, AppState app) {
    if (hasCached) {
      return Column(children: [
        _PremiumButton(
          label: 'Continue as ${app.cachedUsername}',
          icon: Icons.arrow_forward_rounded,
          loading: _loading,
          onTap: _continueAsExisting,
          primary: true,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _PremiumButton(label: 'New Guest', icon: Icons.play_arrow_rounded, loading: false, onTap: _loginAsGuest, primary: false)),
          const SizedBox(width: 10),
          Expanded(child: _PremiumButton(label: 'Google', icon: Icons.g_mobiledata, loading: false, onTap: _loginWithGoogle, primary: false)),
        ]),
      ]);
    }
    return Column(children: [
      _PremiumButton(label: 'Play as Guest', icon: Icons.play_arrow_rounded, loading: _loading, onTap: _loginAsGuest, primary: true),
      const SizedBox(height: 14),
      _PremiumButton(label: 'Sign in with Google', icon: Icons.g_mobiledata, loading: _loading, onTap: _loginWithGoogle, primary: false),
    ]);
  }

  List<Widget> _buildFloatingSuits() {
    final rng = Random(42);
    return List.generate(16, (i) {
      final suit = ['♥', '♦', '♣', '♠'][i % 4];
      final isRed = i % 4 < 2;
      return Positioned(
        left: rng.nextDouble() * 600,
        top: rng.nextDouble() * 900,
        child: Text(suit, style: TextStyle(
          fontSize: 14 + rng.nextDouble() * 22,
          color: (isRed ? const Color(0xFFE53935) : Colors.white).withOpacity(0.02 + rng.nextDouble() * 0.03),
        )),
      );
    });
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent]),
      ),
    );
  }
}

class _PremiumButton extends StatefulWidget {
  const _PremiumButton({required this.label, required this.icon, required this.loading, required this.onTap, required this.primary});
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); if (!widget.loading) widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: widget.primary ? 58 : 50,
          decoration: BoxDecoration(
            gradient: widget.primary
                ? const LinearGradient(colors: [Color(0xFF48E5C2), Color(0xFF30B89C)])
                : null,
            color: widget.primary ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: widget.primary ? null : Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: widget.primary
                ? [BoxShadow(color: const Color(0xFF48E5C2).withOpacity(_pressed ? 0.15 : 0.25), blurRadius: 20, spreadRadius: 2)]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.primary ? const Color(0xFF070B13) : Colors.white70,
                ))
              else
                Icon(widget.icon, size: widget.primary ? 24 : 20,
                  color: widget.primary ? const Color(0xFF070B13) : Colors.white54),
              const SizedBox(width: 10),
              Text(
                widget.loading ? 'Connecting…' : widget.label,
                style: TextStyle(
                  fontSize: widget.primary ? 17 : 14,
                  fontWeight: FontWeight.w800,
                  color: widget.primary ? const Color(0xFF070B13) : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
