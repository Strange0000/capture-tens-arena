import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/arena_loading.dart';
import '../widgets/royal_widgets.dart';
import '../widgets/google_sign_in_web_button_stub.dart'
    if (dart.library.html) '../widgets/google_sign_in_web_button.dart' as google_web;

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
  /// Shown after ~6s of waiting: the Render free tier can take ~25-30s
  /// to wake, and a bare "Connecting…" gives the player no explanation.
  bool _showSlowHint = false;
  bool _buttonsVisible = false;
  // Bumped after "Use a different Google account" so the GIS button is
  // rendered fresh (PR-A G3).
  int _googleButtonKey = 0;
  double _mouseX = 0.0;
  double _mouseY = 0.0;

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
      if (mounted) {
        setState(() {
          _loading = false;
          _showSlowHint = false;
        });
      }
    }
  }

  /// PR-A (G3): forget the cached Google account and re-render the GIS
  /// button, so the player can pick a different Google account instead of
  /// being silently signed into the one the browser last picked.
  ///
  /// Round 2, bug 1: returns true when the chooser produced an account
  /// (the confirm dialog follows on its own). When it returns false the
  /// prompt was suppressed or dismissed, so say so in plain words and
  /// re-render the button — the player can still tap the Google button
  /// and pick an account there. Never signs out on mount.
  Future<void> _switchGoogleAccount() async {
    final app = context.read<AppState>();
    final pickedAccount = await app.auth.switchGoogleAccount();
    if (!mounted) return;
    if (pickedAccount) return;
    setState(() => _googleButtonKey++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Signed out of Google — tap "Sign in with Google" and pick an account.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// Shows the "waking up the server" hint after ~6s of waiting. Shared by
  /// the guest and Google paths (PR-A G6): the Render free tier can take
  /// ~25-30s to wake for either one.
  void _startSlowHintTimer() {
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _loading) setState(() => _showSlowHint = true);
    });
  }

  Future<void> _loginAsGuest() async {
    setState(() {
      _loading = true;
      _showSlowHint = false;
    });
    _startSlowHintTimer();
    final app = context.read<AppState>();
    try {
      await app.bootGuest();
      if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _showSlowHint = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _showSlowHint = false;
    });
    _startSlowHintTimer();
    final app = context.read<AppState>();
    try {
      await app.loginWithGoogle();
      if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_friendlyGoogleError(e)),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _showSlowHint = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final hasCached = app.hasCachedSession;

    return Scaffold(
      body: MouseRegion(
        onHover: (event) {
          final size = MediaQuery.of(context).size;
          if (size.width > 0 && size.height > 0) {
            setState(() {
              _mouseX = ((event.position.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
              _mouseY = ((event.position.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
            });
          }
        },
        onExit: (_) {
          setState(() {
            _mouseX = 0.0;
            _mouseY = 0.0;
          });
        },
        child: Stack(
          children: [
            // Royal Casino felt background — deep green felt,
            // soft gold light from above, faint suit glyphs.
            const Positioned.fill(child: RoyalBackground(child: SizedBox.shrink())),
            // Main content
            Positioned.fill(
              child: RepaintBoundary(
                child: TweenAnimationBuilder<Offset>(
                  tween: Tween<Offset>(
                    begin: Offset.zero,
                    end: Offset(_mouseX * 5, _mouseY * 5),
                  ),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  builder: (context, offset, child) => Transform.translate(
                    offset: offset,
                    child: child,
                  ),
                  child: SafeArea(
                    child: FadeTransition(
                      opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 420),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 12),
                                    // Premium logo
                                    _buildLogo(),
                                    const SizedBox(height: 24),

                                    // Title — gold serif, like the mockup.
                                    const RoyalTitle('Capture Tens Arena', fontSize: 36),
                                    const SizedBox(height: 8),
                                    const Text('Capture the most 10s. Win the table.', style: TextStyle(
                                      fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w600, letterSpacing: 0.5,
                                    )),

                                    const SizedBox(height: 24),

                                    // Card suits strip with dividers
                                    _buildSuitStrip(),
                                    const SizedBox(height: 28),

                                    // Buttons — "Welcome back" card, like the
                                    // mockup: Google first, guest below.
                                    AnimatedOpacity(
                                      opacity: _buttonsVisible ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 700),
                                      child: AnimatedSlide(
                                        offset: _buttonsVisible ? Offset.zero : const Offset(0, 0.2),
                                        duration: const Duration(milliseconds: 700),
                                        curve: Curves.easeOutCubic,
                                        child: RoyalPanel(
                                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Welcome back',
                                                style: TextStyle(
                                                  fontFamily: 'Georgia',
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w900,
                                                  color: ArenaColors.goldSoft,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Multiplayer card game · Play now',
                                                style: TextStyle(fontSize: 12, color: Colors.white54),
                                              ),
                                              const SizedBox(height: 18),
                                              _buildButtons(hasCached, app),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 28),

                                    Text(
                                      'v1.0  ·  Strategy • Teamwork • Tens',
                                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.15), letterSpacing: 1),
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton.icon(
                                      onPressed: () => Navigator.pushNamed(context, '/tutorial'),
                                      icon: const Icon(Icons.menu_book_rounded, size: 16),
                                      label: const Text('How to Play'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Full-screen branded loading while signing in. Previously
            // only the button itself showed a small spinner + "Connecting…"
            // while the guest backend woke up (~25s), which looked stuck.
            if (_loading)
              Positioned.fill(
                child: ArenaLoading(
                  message: 'Connecting to the Arena…',
                  subMessage: _showSlowHint
                      ? 'Waking up the server — this can take about 30 seconds on the free tier. Please wait, no need to tap again.'
                      : 'Signing you in…',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(
        begin: Offset.zero,
        end: Offset(_mouseX, _mouseY),
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, mouseOffset, child) {
        return AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_pulseCtrl.value);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(mouseOffset.dx * 0.1)
                ..rotateX(-mouseOffset.dy * 0.1),
              child: Builder(
                builder: (context) {
                  final logoSize = (MediaQuery.of(context).size.width * 0.35).clamp(110.0, 150.0);
                  return Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFC857).withOpacity(0.15 + t * 0.2),
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
          ),
        );
      },
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

  /// Plain-words version of a Google sign-in failure. The raw SDK
  /// errors ("Bad state: Future already completed") mean nothing to a
  /// player, and a stale one used to sit on screen as a red banner
  /// even for guest play. A failed sign-in must never block guest play.
  String _friendlyGoogleError(Object e) {
    final msg = e.toString();
    if (msg.contains('Future already completed') || msg.contains('Bad state')) {
      return 'Google sign-in is busy right now. Please tap again.';
    }
    if (msg.contains('popup_closed') || msg.contains('cancelled')) {
      return 'Google sign-in was cancelled. You can still play as a guest.';
    }
    if (msg.contains('network') || msg.contains('Failed to fetch')) {
      return 'Could not reach Google. Check your connection and try again.';
    }
    // PR-A (G4): backend failures, told apart by status / machine code.
    // The backend returns a `code` (token_expired / invalid_audience /
    // invalid_token) with its 401s, and the message carries the status.
    if (msg.contains('500') || msg.contains('not configured')) {
      return "Google login isn't set up on the server yet — please play as a guest.";
    }
    if (msg.contains('401') ||
        msg.contains('token_expired') ||
        msg.contains('invalid_audience') ||
        msg.contains('invalid_token')) {
      return "Google couldn't verify that account — try a different Google account.";
    }
    if (msg.contains('TimeoutException')) {
      return 'The server is waking up — try again in a few seconds.';
    }
    // Round 2, bug 2: the Google popup closed without a credential
    // (e.g. Google's Error 400 page). The plugin never reports the
    // underlying error, so this is the only signal the attempt failed.
    if (msg.contains('did not complete')) {
      return "Google sign-in didn't work — try again or play as a guest.";
    }
    return 'Google sign-in did not work. You can still play as a guest.';
  }

  Widget _buildGoogleButton(AppState app, {bool compact = false}) {
    if (kIsWeb) {
      return google_web.GoogleSignInWebButton(
        // Remounted after "Use a different Google account" so the GIS
        // button renders fresh (PR-A G3).
        key: ValueKey('google-$_googleButtonKey'),
        googleSignIn: app.auth.googleSignIn,
        compact: compact,
        onSwitchAccount: () => app.auth.switchGoogleAccount(),
        onIdToken: (idToken, username) async {
          setState(() {
            _loading = true;
            _showSlowHint = false;
          });
          _startSlowHintTimer();
          try {
            await app.loginWithGoogleIdToken(idToken, username: username);
            if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
          } finally {
            if (mounted) {
              setState(() {
                _loading = false;
                _showSlowHint = false;
              });
            }
          }
        },
        onError: (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(_friendlyGoogleError(error)),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 4),
              ),
            );
        },
      );
    }

    return RoyalGoldButton(
      label: compact ? 'Google' : 'Sign in with Google',
      icon: Icons.g_mobiledata,
      loading: _loading,
      onTap: _loginWithGoogle,
      primary: false,
    );
  }

  /// PR-A (G3): lets the player pick a different Google account than the
  /// one the browser would otherwise auto-select. Signs the cached Google
  /// account out and re-renders the GIS button; never signs out on mount.
  Widget _buildSwitchGoogleAccountButton() {
    return TextButton(
      onPressed: _switchGoogleAccount,
      child: const Text(
        'Use a different Google account',
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildButtons(bool hasCached, AppState app) {
    if (hasCached) {
      return Column(children: [
        RoyalGoldButton(
          label: 'Continue as ${app.cachedUsername}',
          // Two-part label: plain "Continue as" + bold username, so
          // the name can never read as run-on text.
          labelWidget: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: ArenaColors.ink,
              ),
              children: [
                const TextSpan(text: 'Continue as  '),
                TextSpan(
                  text: app.cachedUsername,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          icon: Icons.arrow_forward_rounded,
          loading: _loading,
          onTap: _continueAsExisting,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: RoyalGoldButton(
              label: 'New Guest',
              icon: Icons.play_arrow_rounded,
              loading: false,
              onTap: _loginAsGuest,
              primary: false,
              height: 50,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _buildGoogleButton(app, compact: true)),
        ]),
        const SizedBox(height: 6),
        _buildSwitchGoogleAccountButton(),
      ]);
    }
    return Column(children: [
      // "Welcome back" card: Google first, guest below, plain words.
      _buildGoogleButton(app),
      const SizedBox(height: 6),
      _buildSwitchGoogleAccountButton(),
      const SizedBox(height: 8),
      RoyalGoldButton(
        label: 'Play as Guest',
        icon: Icons.play_arrow_rounded,
        loading: _loading,
        onTap: _loginAsGuest,
        primary: false,
      ),
    ]);
  }
}
