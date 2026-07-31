import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/audio_service.dart';
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

  @override
  void initState() {
    super.initState();
    _startWaitTimer();
  }

  void _startWaitTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      final app = context.read<AppState>();
      if (app.match != null) return; // Match arrived, stop counting
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
                  'Setting up match...',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Socket: ${app.socket.connected ? "connected" : "connecting..."}',
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
                  'Could not start the match. The server may be waking up.',
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
                    // Re-emit the bot match request
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
          setState(() => _trickWinnerMessage = '$winner won the trick!');
          AudioService.instance.playTrickWin();
          AudioService.instance.hapticMedium();
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted) setState(() => _trickWinnerMessage = null);
          });
        });
      }
    }
    _lastTrickCount = match.completedTricksCount;

    // Error snackbar
    if (app.errorMessage != null) {
      final msg = app.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        app.clearError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }

    // Detect power suit selection
    if (match.powerSuit != null && _lastPowerSuit == null) {
      final selector = match.players.firstWhere((p) => p.seat == match.firstPlayerSeat).username;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF101826).withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30B89C).withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF30B89C).withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Color(0xFFFFC857)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$selector selected ${match.powerSuit!.toUpperCase()} as the Power Suit!',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
    _lastPowerSuit = match.powerSuit;

    // Who leads this trick
    final leader = match.currentTrick != null && match.currentTrick!.plays.isEmpty
        ? match.players.where((p) => p.seat == match.currentTurnSeat).firstOrNull?.username
        : null;

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
          title: Text(
            match.phase == 'complete'
                ? 'Match Over'
                : match.phase == 'power-select'
                    ? 'Choose Power Suit'
                    : 'Trick ${match.completedTricksCount + 1} of 13',
          ),
          leadingWidth: 80,
          leading: TextButton.icon(
            onPressed: () => _confirmQuit(context, app),
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
            label: const Text('QUIT', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          actions: [
            if (match.players.any((p) => p.isBot) && match.mode != 'ranked')
              TextButton.icon(
                onPressed: () => _confirmRestart(context, app),
                icon: const Icon(Icons.refresh, color: Color(0xFFFFC857), size: 18),
                label: const Text('RESTART', style: TextStyle(color: Color(0xFFFFC857), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            IconButton(tooltip: 'Rules', onPressed: () => _showQuickRules(context), icon: const Icon(Icons.menu_book_rounded, size: 20)),
          ],
        ),
        body: SafeArea(
          child: Stack(
          children: [
            // Main game layout
            Column(
              children: [
                CapturesBar(captures: match.captures, completedTricks: match.completedTricksCount),

                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GameTable(match: match, mySeat: app.mySeat, onCardPlayed: app.playCard),
                      ),
                      // Emote picker
                      Positioned(
                        bottom: 8, right: 8,
                        child: EmotePicker(onEmote: (code) => app.sendEmote(code)),
                      ),
                      // Floating emote display
                      if (app.latestEmote != null)
                        Positioned(
                          top: 60, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF101826).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.3)),
                              ),
                              child: Text(
                                '${app.latestEmote!['username']}: ${_emoteEmoji(app.latestEmote!['emote'] as String? ?? '')}',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      if (app.errorMessage != null)
                        Positioned(
                          top: 8, left: 40, right: 40,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(app.errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => app.clearError(),
                                )
                              ],
                            ),
                          ),
                        )
                      else if (leader != null && match.phase == 'playing')
                        Positioned(
                          top: 8, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF101826).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.3)),
                              ),
                              child: Text('$leader leads',
                                style: const TextStyle(color: Color(0xFF48E5C2), fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      if (_trickWinnerMessage != null)
                        Positioned(
                          top: 40, left: 40, right: 40,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFFC857), Color(0xFFD4A017)]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.3), blurRadius: 16)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🏆', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Flexible(child: Text(_trickWinnerMessage!,
                                  style: const TextStyle(color: Color(0xFF070B13), fontSize: 13, fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (match.phase == 'power-select')
                  SizedBox(
                    height: 160,
                    child: (match.players.firstWhere((p) => p.userId == app.userId, orElse: () => match.players.first).seat == match.firstPlayerSeat)
                        ? PowerSuitPicker(onSelect: app.selectPower)
                        : Center(
                            child: Text(
                              'Waiting for ${match.players.firstWhere((p) => p.seat == match.firstPlayerSeat).username} to select Power Suit...',
                              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),

                Builder(
                  builder: (context) {
                    final sw = MediaQuery.of(context).size.width;
                    final cw = (sw / 8).clamp(50.0, 90.0);
                    return SizedBox(
                      height: (cw * 1.428) + 20,
                      child: _showDealAnimation ? const SizedBox.shrink() : _HandArea(app: app, cardWidth: cw),
                    );
                  }
                ),
              ],
            ),

            // Deal animation (only first time)
            if (_showDealAnimation)
              Positioned.fill(
                child: DealAnimation(
                  onComplete: () {
                    if (mounted) setState(() => _showDealAnimation = false);
                  },
                ),
              ),

            // Match result overlay
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
                    if (context.mounted) Navigator.pushReplacementNamed(context, '/lobby');
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: null,
      bottomSheet: null,
    ),
    );
  }

  void _showQuickRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101826),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Quick Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFFC857))),
            const SizedBox(height: 12),
            const _QuickRule('🎯', 'Capture the most 10s to win'),
            const _QuickRule('⚡', 'Power suit beats all other suits'),
            const _QuickRule('🃏', 'Must follow the lead suit if you can'),
            const _QuickRule('⬆️', 'Must play higher unless teammate is winning'),
            const _QuickRule('🛡️', 'Can\'t discard off-suit 10s (hand > 3)'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  Future<void> _confirmQuit(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101826),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.exit_to_app, color: Colors.redAccent, size: 22),
          SizedBox(width: 10),
          Text('Quit Match?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          'Are you sure you want to leave this match? Your progress will be lost.',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay', style: TextStyle(color: Color(0xFF48E5C2), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      app.leaveMatch();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _confirmRestart(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101826),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.refresh_rounded, color: Color(0xFFFFC857), size: 22),
          SizedBox(width: 10),
          Text('Restart Match?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          'This will end the current game and start a fresh bot match. Are you sure?',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC857),
              foregroundColor: const Color(0xFF070B13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      app.leaveMatch();
      app.startOffline(_lastMatchDifficulty ?? 'hard');
    }
  }
}

class _QuickRule extends StatelessWidget {
  const _QuickRule(this.icon, this.text);
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
      ]),
    );
  }
}

/// Completely static hand — NO animation controllers, NO stagger.
/// Cards just appear instantly. Zero jank.
class _HandArea extends StatelessWidget {
  const _HandArea({required this.app, required this.cardWidth});
  final AppState app;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final match = app.match!;
    final isMyTurn = match.players.any(
      (p) => p.userId == app.userId && p.seat == match.currentTurnSeat,
    );
    final hand = match.hand;
    final N = hand.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final aw = constraints.maxWidth - 16;
        double widthFactor = 1.0;
        if (N > 1) {
          final maxOverlap = (aw - cardWidth) / (N - 1);
          final overlapWidth = maxOverlap.clamp(20.0, cardWidth + 4.0);
          widthFactor = overlapWidth / cardWidth;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(N, (index) {
                  final card = hand[index];
                  final cardWidget = ArenaCardWidget(
                    card: card,
                    powerSuit: match.powerSuit,
                    onPlay: isMyTurn ? () {
                      AudioService.instance.playCardPlace();
                      AudioService.instance.hapticLight();
                      app.playCard(card.id);
                    } : null,
                    dimmed: !isMyTurn,
                    width: cardWidth,
                  );

                  Widget wrappedCard = cardWidget;
                  if (isMyTurn) {
                    wrappedCard = Draggable<String>(
                      data: card.id,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Transform.scale(
                          scale: 1.1,
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
                        opacity: 0.2,
                        child: cardWidget,
                      ),
                      child: cardWidget,
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
    'nice': '👏',
    'gg': '🤝',
    'oops': '😬',
    'wow': '😲',
    'hurry': '⏰',
    'angry': '😤',
  };
  return map[code] ?? code;
}
