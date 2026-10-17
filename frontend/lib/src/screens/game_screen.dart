import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/arena_card.dart';
import '../models/match_state.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../widgets/arena_card_widget.dart';
import '../widgets/captures_bar.dart';
import '../widgets/deal_animation.dart';
import '../widgets/emote_picker.dart';
import '../widgets/game_table.dart';
import '../widgets/match_result_overlay.dart';
import '../widgets/power_suit_picker.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _showDealAnimation = true;
  String? _trickWinnerMessage;
  String? _lastPowerSuit;
  int _lastTrickCount = 0;
  bool _waitTimedOut = false;
  int _waitSeconds = 0;
  String? _lastMatchDifficulty;

  // Preferences
  bool _highlightLegal = true;
  bool _autoSortHand = true;
  bool _tableTilt3d = false;

  // HUD Banner Alert (Top notification - never covers the cards!)
  String? _bannerAlert;
  IconData? _bannerIcon;
  Color? _bannerColor;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playGameBgm();
    _loadPreferences();
    _startWaitTimer();
    // Starting a match must be an explicit action from the lobby/retry button.
    // Auto-starting here made a remounted GameScreen launch another bot match
    // after the user had intentionally left the previous match.
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _highlightLegal = prefs.getBool('pref_highlight_legal') ?? true;
      _autoSortHand = prefs.getBool('pref_auto_sort_hand') ?? true;
      _tableTilt3d = prefs.getBool('pref_table_tilt_3d') ?? false;
    });
  }

  void _showBannerAlert(String message, IconData icon, Color color) {
    if (!mounted) return;
    setState(() {
      _bannerAlert = message;
      _bannerIcon = icon;
      _bannerColor = color;
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted && _bannerAlert == message) {
        setState(() => _bannerAlert = null);
      }
    });
  }

  @override
  void dispose() {
    AudioService.instance.playLobbyBgm();
    super.dispose();
  }

  void _startWaitTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      final app = context.read<AppState>();
      if (app.match != null) return;
      setState(() {
        _waitSeconds++;
        if (_waitSeconds >= 10) {
          _waitTimedOut = true;
        }
      });
      if (!_waitTimedOut) _startWaitTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

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

    final match = app.match;

    if (match == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B13),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_waitTimedOut) ...[
                const CircularProgressIndicator(color: Color(0xFF48E5C2)),
                const SizedBox(height: 20),
                Text(
                  'Setting up arena...',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gateway: ${app.socket.connected ? "connected" : "connecting..."} (${app.backendUrl})',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                ),
              ] else ...[
                Icon(Icons.wifi_off, color: Colors.white.withOpacity(0.5), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Connection timed out',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Could not connect to the match server.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF48E5C2),
                    foregroundColor: const Color(0xFF070B13),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _waitTimedOut = false;
                      _waitSeconds = 0;
                    });
                    app.startOffline(_lastMatchDifficulty ?? 'hard');
                    _startWaitTimer();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    app.leaveMatch();
                    Navigator.pushNamedAndRemoveUntil(context, '/lobby', (r) => false);
                  },
                  child: const Text('Back to Lobby', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Detect trick winner
    if (match.completedTricksCount > _lastTrickCount) {
      final winner = match.lastTrickWinner;
      if (winner != null && _trickWinnerMessage == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _trickWinnerMessage = '$winner captured the trick!');
          AudioService.instance.playTrickWin();
          AudioService.instance.hapticMedium();
          Future.delayed(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _trickWinnerMessage = null);
          });
        });
      }
    }
    _lastTrickCount = match.completedTricksCount;

    // Error notification (HUD banner, NOT bottom snackbar)
    if (app.errorMessage != null) {
      final msg = app.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        app.clearError();
        _showBannerAlert(msg, Icons.error_outline_rounded, Colors.redAccent);
      });
    }

    // Detect power suit selection (HUD banner, NOT bottom snackbar)
    if (match.powerSuit != null && _lastPowerSuit == null) {
      final selector = match.players.firstWhere((p) => p.seat == match.firstPlayerSeat, orElse: () => match.players.first).username;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showBannerAlert('$selector declared ${match.powerSuit!.toUpperCase()} as TRUMP!', Icons.flash_on_rounded, const Color(0xFFFFD166));
      });
    }
    _lastPowerSuit = match.powerSuit;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/game_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Leave Match',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
            onPressed: () => _confirmQuit(context, app),
          ),
          centerTitle: true,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: (match.mode == 'ranked'
                      ? const Color(0xFFFFD166)
                      : match.mode == 'private'
                          ? const Color(0xFFB388FF)
                          : const Color(0xFF48E5C2))
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (match.mode == 'ranked'
                        ? const Color(0xFFFFD166)
                        : match.mode == 'private'
                            ? const Color(0xFFB388FF)
                            : const Color(0xFF48E5C2))
                    .withOpacity(0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: match.mode == 'ranked'
                        ? const Color(0xFFFFD166)
                        : match.mode == 'private'
                            ? const Color(0xFFB388FF)
                            : const Color(0xFF48E5C2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  match.mode == 'ranked'
                      ? 'RANKED ARENA'
                      : match.mode == 'private'
                          ? 'CUSTOM SALON'
                          : 'BOT COMBAT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: match.mode == 'ranked'
                        ? const Color(0xFFFFD166)
                        : match.mode == 'private'
                            ? const Color(0xFFB388FF)
                            : const Color(0xFF48E5C2),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (match.players.any((p) => p.isBot) && match.mode != 'ranked')
              IconButton(
                tooltip: 'Restart Match',
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFFD166), size: 20),
                onPressed: () => _confirmRestart(context, app),
              ),
            IconButton(
              tooltip: AudioService.instance.soundEnabled ? 'Mute Sound' : 'Unmute Sound',
              icon: Icon(
                AudioService.instance.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: AudioService.instance.soundEnabled ? const Color(0xFF48E5C2) : Colors.white38,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  final next = !AudioService.instance.soundEnabled;
                  AudioService.instance.setSoundEnabled(next);
                  AudioService.instance.setMusicEnabled(next);
                });
              },
            ),
            IconButton(
              tooltip: 'Game Rules',
              icon: const Icon(Icons.menu_book_rounded, color: Colors.white70, size: 20),
              onPressed: () => _showQuickRules(context),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main game column
              Column(
                children: [
                  // Esports HUD Scoreboard
                  CapturesBar(
                    captures: match.captures,
                    completedTricks: match.completedTricksCount,
                    myTeam: app.myTeam,
                    powerSuit: match.powerSuit,
                    trickWinnerMessage: _trickWinnerMessage,
                  ),
                  // Table Arena (Clean, transparent, seamlessly integrating with table art)
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GameTable(
                            match: match,
                            mySeat: app.mySeat,
                            onCardPlayed: app.playCard,
                            tilt3d: _tableTilt3d,
                          ),
                        ),

                        // Emote picker (Bottom-Right)
                        Positioned(
                          bottom: 10,
                          right: 12,
                          child: EmotePicker(onEmote: (code) => app.sendEmote(code)),
                        ),

                        // Floating emote display
                        if (app.latestEmote != null)
                          Positioned(
                            top: 40,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10192A).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.4), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 14),
                                  ],
                                ),
                                child: Text(
                                  '${app.latestEmote!['username']}: ${_emoteEmoji(app.latestEmote!['emote'] as String? ?? '')}',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Power Suit Picker Section
                  if (match.phase == 'power-select')
                    SizedBox(
                      height: 160,
                      child: (match.players.firstWhere((p) => p.userId == app.userId, orElse: () => match.players.first).seat == match.firstPlayerSeat)
                          ? PowerSuitPicker(onSelect: app.selectPower)
                          : Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10192A).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Text(
                                  'Waiting for ${match.players.firstWhere((p) => p.seat == match.firstPlayerSeat).username} to select Power Suit...',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                    ),

                  // Player Hand Area
                  Builder(
                    builder: (context) {
                      final sw = MediaQuery.of(context).size.width;
                      final cw = (sw / 8).clamp(52.0, 92.0);
                      return SizedBox(
                        height: (cw * 1.428) + 38,
                        child: _showDealAnimation
                            ? const SizedBox.shrink()
                            : _HandArea(
                                app: app,
                                cardWidth: cw,
                                autoSort: _autoSortHand,
                                highlightLegal: _highlightLegal,
                              ),
                      );
                    },
                  ),
                ],
              ),

              // Top HUD Banner Alert (Positioned below scoreboard, never covers player cards!)
              Positioned(
                top: 76,
                left: 20,
                right: 20,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, -0.4),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: _bannerAlert == null
                      ? const SizedBox.shrink(key: ValueKey('empty_banner'))
                      : Center(
                          key: ValueKey(_bannerAlert),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1B2E).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: (_bannerColor ?? const Color(0xFFFFD166)).withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_bannerColor ?? const Color(0xFFFFD166)).withOpacity(0.35),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _bannerIcon ?? Icons.flash_on_rounded,
                                      color: _bannerColor ?? const Color(0xFFFFD166),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _bannerAlert!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              // Deal Animation (First time only)
              if (_showDealAnimation)
                Positioned.fill(
                  child: DealAnimation(
                    onComplete: () {
                      if (mounted) setState(() => _showDealAnimation = false);
                    },
                  ),
                ),

              // Match Result Overlay
              if (match.phase == 'complete')
                Positioned.fill(
                  child: MatchResultOverlay(
                    match: match,
                    myTeam: app.myTeam,
                    rankUpdate: app.lastRankUpdate,
                    onPlayAgain: () async {
                      final mode = match.mode;
                      app.leaveMatch();
                      setState(() {
                        _showDealAnimation = true;
                        _lastTrickCount = 0;
                      });
                      if (mode == 'offline') {
                        app.startOffline(_lastMatchDifficulty ?? 'hard');
                      } else if (mode == 'ranked') {
                        app.queueRanked();
                        if (context.mounted) Navigator.pushReplacementNamed(context, '/matchmaking');
                      } else {
                        if (context.mounted) Navigator.pushReplacementNamed(context, '/lobby');
                      }
                    },
                    onHome: () {
                      app.leaveMatch();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/lobby',
                          (route) => false,
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmQuit(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10192A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
        ),
        title: const Row(children: [
          Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 22),
          SizedBox(width: 10),
          Text('Leave Match?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          'Are you sure you want to quit this match? Your active hand and progress will be forfeited.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay in Game', style: TextStyle(color: Color(0xFF48E5C2), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave Match', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      app.leaveMatch();
      // Remove stale game/matchmaking routes. Leaving must never reveal an
      // older GameScreen which could restart or resurrect the previous match.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/lobby',
        (route) => false,
      );
    }
  }

  Future<void> _confirmRestart(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10192A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFFD166), width: 1.2),
        ),
        title: const Row(children: [
          Icon(Icons.refresh_rounded, color: Color(0xFFFFD166), size: 22),
          SizedBox(width: 10),
          Text('Restart Match?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          'This will restart the table with a fresh deal. Ready to redeal?',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD166),
              foregroundColor: const Color(0xFF070B13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart Now', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      app.leaveMatch();
      app.startOffline(_lastMatchDifficulty ?? 'hard');
    }
  }

  void _showQuickRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10192A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Capture Tens Arena Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFFD166))),
            const SizedBox(height: 14),
            const _QuickRule('🎯', 'Capture the most 10s! Most 10s wins the battle.'),
            const _QuickRule('⚡', 'Power Suit (Trump) beats all other suits regardless of card rank.'),
            const _QuickRule('🃏', 'Lead suit must be followed if you hold cards of that suit.'),
            const _QuickRule('⬆️', 'Card Rank: A > K > Q > J > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2.'),
            const _QuickRule('👥', '2v2 format: Work with your partner sitting across from you.'),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _QuickRule extends StatelessWidget {
  const _QuickRule(this.icon, this.text);
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

// ── Hand Area with Auto-Sort & Legal Move Highlighting ───────────────────────

class _HandArea extends StatelessWidget {
  const _HandArea({
    required this.app,
    required this.cardWidth,
    required this.autoSort,
    required this.highlightLegal,
  });

  final AppState app;
  final double cardWidth;
  final bool autoSort;
  final bool highlightLegal;

  static const _rankValues = {
    'A': 14, 'K': 13, 'Q': 12, 'J': 11, '10': 10,
    '9': 9, '8': 8, '7': 7, '6': 6, '5': 5, '4': 4, '3': 3, '2': 2,
  };

  static const _suitValues = {
    'spades': 4,
    'hearts': 3,
    'diamonds': 2,
    'clubs': 1,
  };

  bool _isCardLegal(ArenaCard card, CurrentTrick? trick, List<ArenaCard> hand) {
    if (trick == null || trick.plays.isEmpty) {
      return true;
    }
    final leadSuit = trick.leadSuit;
    if (leadSuit == null) return true;

    final hasLeadSuit = hand.any((c) => c.suit == leadSuit);
    if (hasLeadSuit) {
      return card.suit == leadSuit;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final match = app.match!;
    final isMyTurn = match.players.any(
      (p) => p.userId == app.userId && p.seat == match.currentTurnSeat,
    );

    // Prepare hand
    final hand = List<ArenaCard>.from(match.hand);
    if (autoSort) {
      hand.sort((a, b) {
        final sA = _suitValues[a.suit] ?? 0;
        final sB = _suitValues[b.suit] ?? 0;
        if (sA != sB) return sB.compareTo(sA);
        final rA = _rankValues[a.rank] ?? 0;
        final rB = _rankValues[b.rank] ?? 0;
        return rB.compareTo(rA);
      });
    }

    final N = hand.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final aw = constraints.maxWidth - 16;
        double widthFactor = 1.0;
        if (N > 1) {
          final maxOverlap = (aw - cardWidth) / (N - 1);
          final overlapWidth = maxOverlap.clamp(24.0, cardWidth + 4.0);
          widthFactor = overlapWidth / cardWidth;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(N, (index) {
                  final card = hand[index];
                  final isLegal = _isCardLegal(card, match.currentTrick, match.hand);
                  final canPlay = isMyTurn && isLegal;

                  // 3D fan arc
                  final double fanAngle = N > 1 ? (index - (N - 1) / 2) * 0.03 : 0.0;
                  final double yOffset = N > 1 ? ((index - (N - 1) / 2).abs() * 3).toDouble() : 0.0;

                  final cardWidget = ArenaCardWidget(
                    card: card,
                    powerSuit: match.powerSuit,
                    isLegal: highlightLegal ? isLegal : true,
                    onPlay: canPlay
                        ? () {
                            AudioService.instance.playCardPlace();
                            AudioService.instance.hapticLight();
                            app.playCard(card.id);
                          }
                        : null,
                    dimmed: !isMyTurn,
                    width: cardWidth,
                  );

                  Widget wrappedCard = Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..translate(0.0, yOffset, 0.0)
                      ..rotateZ(fanAngle),
                    alignment: Alignment.bottomCenter,
                    child: cardWidget,
                  );

                  if (canPlay) {
                    wrappedCard = Draggable<String>(
                      data: card.id,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Transform.scale(
                          scale: 1.12,
                          child: ArenaCardWidget(
                            card: card,
                            powerSuit: match.powerSuit,
                            onPlay: null,
                            dimmed: false,
                            width: cardWidth,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.25,
                        child: wrappedCard,
                      ),
                      child: wrappedCard,
                    );
                  }

                  if (index < N - 1) {
                    return Align(
                      widthFactor: widthFactor,
                      alignment: Alignment.centerLeft,
                      child: wrappedCard,
                    );
                  }
                  return wrappedCard;
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _emoteEmoji(String code) {
  const map = {
    'nice': '👏 Nice!',
    'gg': '🤝 GG!',
    'oops': '😬 Oops!',
    'wow': '😲 Wow!',
    'hurry': '⏰ Hurry up!',
    'angry': '😤 Urgh!',
  };
  return map[code] ?? code;
}
