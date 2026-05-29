import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/arena_card_widget.dart';
import '../widgets/captures_bar.dart';
import '../widgets/deal_animation.dart';
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
  int _lastTrickCount = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final match = app.match;

    if (match == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Detect trick winner
    if (match.completedTricksCount > _lastTrickCount && _lastTrickCount > 0) {
      final winner = match.lastTrickWinner;
      if (winner != null && _trickWinnerMessage == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _trickWinnerMessage = '$winner won the trick!');
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted) setState(() => _trickWinnerMessage = null);
          });
        });
      }
    }
    _lastTrickCount = match.completedTricksCount;

    // Who leads this trick
    final leader = match.currentTrick != null && match.currentTrick!.plays.isEmpty
        ? match.players.where((p) => p.seat == match.currentTurnSeat).firstOrNull?.username
        : null;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/game_table_bg.png'),
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
            onPressed: () {
              app.leaveMatch();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
            label: const Text('QUIT', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          actions: [
            if (match.players.any((p) => p.isBot) && match.mode != 'ranked')
              TextButton.icon(
                onPressed: () {
                  app.leaveMatch(); // cleans up backend and frontend
                  app.startOffline('hard'); // hardcode to hard for now, or just start a new bot match
                },
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
                        child: GameTable(match: match, onCardPlayed: app.playCard),
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

                SizedBox(
                  height: 160,
                  child: match.phase == 'power-select'
                      ? PowerSuitPicker(onSelect: app.selectPower)
                      : const SizedBox.shrink(),
                ),

                SizedBox(
                  height: 110,
                  child: _showDealAnimation ? const SizedBox.shrink() : _HandArea(app: app),
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
                    app.leaveMatch();
                    await app.bootGuest();
                    setState(() {
                      _showDealAnimation = true;
                      _lastTrickCount = 0;
                    });
                    app.startOffline('hard');
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
  const _HandArea({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final match = app.match!;
    final isMyTurn = match.players.any(
      (p) => p.username == app.username && p.seat == match.currentTurnSeat,
    );

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: match.hand.length,
      itemBuilder: (context, index) {
        final card = match.hand[index];
        final cardWidget = ArenaCardWidget(
          card: card,
          powerSuit: match.powerSuit,
          onPlay: isMyTurn ? () => app.playCard(card.id) : () {},
          dimmed: !isMyTurn,
        );

        if (!isMyTurn) return cardWidget;

        return Draggable<String>(
          data: card.id,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.1,
              child: ArenaCardWidget(
                card: card,
                powerSuit: match.powerSuit,
                onPlay: () {},
                dimmed: false,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.2,
            child: cardWidget,
          ),
          child: cardWidget,
        );
      },
    );
  }
}
