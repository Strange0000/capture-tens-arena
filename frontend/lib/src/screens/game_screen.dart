import 'dart:math' as math;
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
import '../theme.dart';
import '../widgets/power_suit_picker.dart';
import '../widgets/royal_widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _showDealAnimation = true;
  String? _trickWinnerMessage;
  /// Persistent "Last trick: <name> · Team A" — never auto-cleared,
  /// unlike the 2.2s transient [_trickWinnerMessage] banner.
  String? _lastTrickLabel;
  String? _lastPowerSuit;
  int _lastTrickCount = 0;
  bool _waitTimedOut = false;
  int _waitSeconds = 0;
  String? _lastMatchDifficulty;
  /// Set the moment the player taps Home / Play Again on the victory
  /// modal. The overlay unmounts immediately, so the buttons can never
  /// look dead — even if navigation or a late server broadcast is slow,
  /// the player sees the result go away at once. Reset when a new match
  /// id arrives (see build, below).
  bool _resultDismissed = false;
  /// Guard: the quit dialog must never open twice. Two stacked
  /// identical dialogs made the first tap look dead in the Round 5
  /// test — it only popped the top copy.
  bool _quitDialogOpen = false;
  String? _lastMatchId;

  // Preferences
  bool _highlightLegal = true;
  bool _autoSortHand = true;
  bool _tableTilt3d = false;

  // HUD Banner Alert (Top notification - never covers the cards!)
  String? _bannerAlert;
  /// True when the banner is a sticky illegal-tap hint: it stays until
  /// the player's turn starts (or they play a legal card), instead of
  /// auto-clearing after 3s.
  bool _bannerSticky = false;
  /// When the current banner was shown — a sticky hint must stay
  /// readable for at least 1.5s (see the turn-change clear in build).
  DateTime? _bannerShownAt;
  /// Turn state on the previous build — a sticky hint clears only when
  /// the turn CHANGES to the player, not on every build during their
  /// own turn (an illegal tap on their own turn, e.g. wrong suit, must
  /// keep its hint visible until they play a legal card).
  bool _wasMyTurn = false;
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

  void _showBannerAlert(String message, IconData icon, Color color,
      {bool sticky = false}) {
    if (!mounted) return;
    setState(() {
      _bannerAlert = message;
      _bannerIcon = icon;
      _bannerColor = color;
      _bannerSticky = sticky;
      _bannerShownAt = DateTime.now();
    });
    if (sticky) return; // Cleared when the player can act again (below).
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
    final viewport = MediaQuery.sizeOf(context);
    final isVeryNarrowPhone = viewport.width < 360;
    // Round 9: the Round 7/8 side-panel layout (score panel left,
    // hand fanned vertically right) is REVERTED. Sumit saw it live
    // and said the previous table was much better — the side layout
    // squeezed the hand into a thin strip and left the table mostly
    // empty. The game is back to the previous layout on every width:
    // centred score pill on top, oval table in the centre, hand
    // fanned horizontally along the bottom with big readable cards.
    final isCompactGameControls = viewport.width < 400;
    final isShortPhone = viewport.height < 700;

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
                const CircularProgressIndicator(color: Color(0xFF3FA97C)),
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
                    backgroundColor: const Color(0xFFFFC857),
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

    // A new match id means a fresh table: the victory modal may show
    // again when this match completes. (Field assignment only — no
    // setState during build.)
    if (match.id != _lastMatchId) {
      _lastMatchId = match.id;
      _resultDismissed = false;
    }

    // A sticky illegal-tap hint ("Wait — it's not your turn yet.")
    // clears the moment the turn changes to the player.
    final isMyTurnNow = match.players.any(
      (pl) => pl.userId == app.userId && pl.seat == match.currentTurnSeat,
    );
    if (_bannerSticky && isMyTurnNow && !_wasMyTurn) {
      // Round 10: a hint the player only just tapped ("Wait — it's
      // not your turn yet.") must stay readable for at least 1.5s.
      // The turn can change a frame after the tap, and clearing
      // instantly made the tap look like a silent no-op (Round 9:
      // the first 9♥ tap showed nothing; the second played it).
      const minShow = Duration(milliseconds: 1500);
      final shownFor =
          DateTime.now().difference(_bannerShownAt ?? DateTime.now());
      if (shownFor >= minShow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _bannerAlert = null; _bannerSticky = false; });
        });
      } else {
        final shownMessage = _bannerAlert;
        Future.delayed(minShow - shownFor, () {
          if (mounted && _bannerSticky && _bannerAlert == shownMessage) {
            setState(() { _bannerAlert = null; _bannerSticky = false; });
          }
        });
      }
    }
    _wasMyTurn = isMyTurnNow;

    // Detect trick winner
    if (match.completedTricksCount > _lastTrickCount) {
      final winner = match.lastTrickWinner;
      if (winner != null) {
        final team = match.lastTrickWinnerTeam;
        _lastTrickLabel = team == null ? winner : '$winner · Team $team';
      }
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
        // Round 10: sticky, so a server rejection (e.g. a card the
        // UI wrongly showed as playable) stays visible in plain
        // words until the player acts — it must never flash past
        // unnoticed and leave only a hidden error behind.
        _showBannerAlert(msg, Icons.error_outline_rounded, Colors.redAccent, sticky: true);
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
    final modeLabel = match.mode == 'ranked'
        ? (isVeryNarrowPhone ? 'RANKED' : 'RANKED ARENA')
        : match.mode == 'private'
            ? (isVeryNarrowPhone ? 'CUSTOM' : 'CUSTOM SALON')
            : (isVeryNarrowPhone ? 'BOT MATCH' : 'BOT COMBAT');

    // Royal Casino room (poker reference): the old game_bg.png photo —
    // a chrome/cyan sci-fi table — is gone. The drawn wood-rim oval in
    // GameTable IS the table now, on a code-drawn felt background.
    return RoyalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: isShortPhone ? 50 : kToolbarHeight,
          leadingWidth: isCompactGameControls ? 82 : 56,
          leading: isCompactGameControls
              ? Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _confirmQuit(context, app),
                    icon: const Icon(Icons.exit_to_app_rounded, size: 17),
                    label: Text(
                      isVeryNarrowPhone ? 'EXIT' : 'LEAVE',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Leave Match',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
                  onPressed: () => _confirmQuit(context, app),
                ),
          centerTitle: true,
          title: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVeryNarrowPhone ? 7 : (isCompactGameControls ? 10 : 14),
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: (match.mode == 'ranked'
                      ? const Color(0xFFFFD166)
                      : match.mode == 'private'
                          ? const Color(0xFFD4A017)
                          : const Color(0xFF3FA97C))
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (match.mode == 'ranked'
                        ? const Color(0xFFFFD166)
                        : match.mode == 'private'
                            ? const Color(0xFFD4A017)
                            : const Color(0xFF3FA97C))
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
                            ? const Color(0xFFD4A017)
                            : const Color(0xFF3FA97C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  modeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: match.mode == 'ranked'
                        ? const Color(0xFFFFD166)
                        : match.mode == 'private'
                            ? const Color(0xFFD4A017)
                            : const Color(0xFF3FA97C),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (isCompactGameControls)
              PopupMenuButton<String>(
                tooltip: 'Game options',
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
                color: ArenaColors.panel,
                onSelected: (action) {
                  if (action == 'restart') {
                    _confirmRestart(context, app);
                  } else if (action == 'sound') {
                    setState(() {
                      final next = !AudioService.instance.soundEnabled;
                      AudioService.instance.setSoundEnabled(next);
                      AudioService.instance.setMusicEnabled(next);
                    });
                  } else if (action == 'rules') {
                    _showQuickRules(context);
                  }
                },
                itemBuilder: (context) => [
                  if (match.players.any((p) => p.isBot) && match.mode != 'ranked')
                    const PopupMenuItem(
                      value: 'restart',
                      child: Row(children: [
                        Icon(Icons.refresh_rounded, color: Color(0xFFFFD166), size: 18),
                        SizedBox(width: 10),
                        Text('Restart Match'),
                      ]),
                    ),
                  PopupMenuItem(
                    value: 'sound',
                    child: Row(children: [
                      Icon(
                        AudioService.instance.soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: const Color(0xFF3FA97C),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(AudioService.instance.soundEnabled ? 'Mute Sound' : 'Unmute Sound'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'rules',
                    child: Row(children: [
                      Icon(Icons.menu_book_rounded, color: Colors.white70, size: 18),
                      SizedBox(width: 10),
                      Text('Game Rules'),
                    ]),
                  ),
                ],
              )
            else ...[
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
                  color: AudioService.instance.soundEnabled ? const Color(0xFF3FA97C) : Colors.white38,
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
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main game area — the previous table layout on
              // every width: centred score pill on top, oval table
              // in the centre, hand fanned along the bottom.
              Column(
                children: [
                  // Esports HUD Scoreboard
                  CapturesBar(
                    captures: match.captures,
                    completedTricks: match.completedTricksCount,
                    myTeam: app.myTeam,
                    powerSuit: match.powerSuit,
                    trickWinnerMessage: _trickWinnerMessage,
                    lastTrickWinnerLabel: _lastTrickLabel,
                  ),
                  // Power-suit phase banner — in the Column, above
                  // the table, so it can never cover a player chip.
                  // (Round 11: the old centred emblem inside the
                  // table overlapped the bottom player's avatar/name
                  // on short screens, because the table area shrinks
                  // to ~135px while the picker and hand are showing.)
                  if (match.phase == 'power-select')
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B3D2E).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFFC857), width: 1),
                        ),
                        child: const Text(
                          '👑  SELECTING TRUMP SUIT',
                          style: TextStyle(
                            color: Color(0xFFFFC857),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  // Table Arena (Clean, transparent, seamlessly integrating with table art)
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GameTable(
                            match: match,
                            mySeat: app.mySeat,
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
                                  color: ArenaColors.panel.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF3FA97C).withOpacity(0.4), width: 1.5),
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
                      // Round 10: the picker content needs ~134px;
                      // 144px on short screens leaves the table room
                      // (160px starved it — see the hand budget below).
                      height: isShortPhone ? 144.0 : 160.0,
                      child: (match.players.firstWhere((p) => p.userId == app.userId, orElse: () => match.players.first).seat == match.firstPlayerSeat)
                          ? PowerSuitPicker(onSelect: app.selectPower)
                          : Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: ArenaColors.panel.withOpacity(0.9),
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

                  // Player Hand Area — Round 3: cards were up to 92px
                  // wide (~170px tall with padding), which left almost
                  // no room for the table. Capped at 64px wide (~107px
                  // tall total) so the oval gets the screen back.
                  Builder(
                    builder: (context) {
                      final sw = MediaQuery.sizeOf(context).width;
                      final sh = MediaQuery.sizeOf(context).height;
                      var cw = sw < 375
                          ? 36.0
                          : sw < 450
                              ? 40.0
                              : (sw / 9).clamp(48.0, 64.0);
                      // Short viewports: shrink the cards so the whole
                      // hand fits above the bottom edge (Round 5 test:
                      // the bottom ~20-30% of the hand was clipped).
                      if (sh < 600) cw = cw.clamp(36.0, 44.0).toDouble();
                      if (sh < 700) cw = cw.clamp(36.0, 52.0).toDouble();
                      // Round 8: the hand is the LAST child of the
                      // Column, so if the fixed children above it
                      // (app bar + score pill + power-suit picker)
                      // ever exceed the viewport, the hand is the
                      // part that gets pushed off the bottom edge.
                      // Reserve room for those plus a minimum table
                      // height, and shrink the cards to fit what is
                      // left — the hand can never be clipped again.
                      // Round 10: the picker height above must match
                      // this budget, and the table minimum is smaller
                      // on short screens so the table still gets room.
                      final pickerHeight = match.phase == 'power-select'
                          ? (sh < 700 ? 144.0 : 160.0)
                          : 0.0;
                      final reserved = 56.0 + 120.0 + pickerHeight +
                          (sh < 700 ? 80.0 : 100.0);
                      final handBudget =
                          (sh - reserved).clamp(64.0, 220.0).toDouble();
                      // Round 10 — the blank power-suit phase: during
                      // 'power-select' at 506px height, handBudget was
                      // 70, so the upper bound here was (70-28)/1.428
                      // ≈ 29.4 — LESS than the 36.0 lower bound — and
                      // num.clamp throws ArgumentError when lower >
                      // upper (verified against the Dart SDK). In
                      // release mode the failed hand subtree becomes a
                      // light-grey RenderErrorBox (0xF0C0C0C0, sized
                      // by parent) that eats the Column's remaining
                      // height and starves the Expanded table to zero
                      // — exactly the blank grey lower ~45% (only the
                      // faint background suit glyphs showing) in the
                      // Round 9 test and Sumit's screenshot. The
                      // bounds must never invert.
                      final maxCw = math.max(
                        36.0,
                        (handBudget - 28) / 1.428,
                      );
                      cw = cw.clamp(36.0, maxCw).toDouble();
                      return SizedBox(
                        height: (cw * 1.428) + 28,
                        child: _showDealAnimation
                            ? const SizedBox.shrink()
                            : _HandArea(
                                app: app,
                                cardWidth: cw,
                                autoSort: _autoSortHand,
                                highlightLegal: _highlightLegal,
                                onIllegalTap: (reason) => _showBannerAlert(
                                  reason,
                                  Icons.info_outline_rounded,
                                  const Color(0xFFFFD166),
                                  sticky: true,
                                ),
                                onLegalPlay: () {
                                  if (_bannerSticky) {
                                    setState(() {
                                      _bannerAlert = null;
                                      _bannerSticky = false;
                                    });
                                  }
                                },
                              ),
                      );
                    },
                  ),
                ],
              ),

              // Top HUD Banner Alert — just below the slim score strip
              // (AppBar ~50 + strip ~44), floating over the table's top
              // margin, never over the centre cards or the hand.
              Positioned(
                top: 52,
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
                                  color: ArenaColors.panel.withOpacity(0.92),
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

              // Match Result Overlay — compact dialog, NOT a full-screen
              // blocking panel (see match_result_overlay.dart). Hidden
              // the instant Home / Play Again is tapped (_resultDismissed)
              // so the buttons can never appear dead.
              if (match.phase == 'complete' && !_resultDismissed)
                Positioned.fill(
                  child: MatchResultOverlay(
                    match: match,
                    myTeam: app.myTeam,
                    rankUpdate: app.lastRankUpdate,
                    onPlayAgain: () async {
                      final mode = match.mode;
                      debugPrint('[Game] Play Again tapped — leaving match');
                      setState(() {
                        _resultDismissed = true;
                        _showDealAnimation = true;
                        _lastTrickCount = 0;
                      });
                      app.leaveMatch();
                      // Let the leave reach the server before starting
                      // a new table, otherwise the old match can be
                      // re-broadcast and resurrect the finished game.
                      await Future.delayed(const Duration(milliseconds: 200));
                      if (!mounted) return;
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
                      // 1) Hide the modal immediately — instant feedback.
                      // 2) Leave the match (AppState ignores any later
                      //    re-broadcast of this finished match id).
                      // 3) Navigate after the frame, so the leave's
                      //    notifyListeners rebuild cannot race the push.
                      debugPrint('[Game] Home tapped — leaving match');
                      setState(() => _resultDismissed = true);
                      app.leaveMatch();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/lobby',
                          (route) => false,
                        );
                      });
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
    // A finished match is not forfeited by leaving — say so, instead of
    // warning about losing "your active hand and progress".
    final isFinished = app.match?.phase == 'complete';
    if (_quitDialogOpen) return;
    _quitDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArenaColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
        ),
        title: Row(children: [
          Icon(isFinished ? Icons.home_rounded : Icons.exit_to_app_rounded, color: isFinished ? const Color(0xFFFFC857) : Colors.redAccent, size: 22),
          const SizedBox(width: 10),
          Text(isFinished ? 'Back to Lobby?' : 'Leave Match?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        content: Text(
          isFinished
              ? 'This match is already finished. Return to the lobby?'
              : 'Are you sure you want to quit this match? Your active hand and progress will be forfeited.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isFinished ? 'Stay Here' : 'Stay in Game', style: const TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.w700)),
          ),
          // Plain InkWell tap target with an opaque hit area, not
          // an ElevatedButton: quick taps on this button did nothing
          // in the Round 5 test.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(ctx, true),
              child: Ink(
                decoration: BoxDecoration(
                  color: isFinished ? const Color(0xFFFFC857) : Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Text(
                  isFinished ? 'Back to Lobby' : 'Leave Match',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isFinished ? const Color(0xFF070B13) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    _quitDialogOpen = false;
    if (confirmed == true && context.mounted) {
      setState(() => _resultDismissed = true);
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
        backgroundColor: ArenaColors.panel,
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
      backgroundColor: ArenaColors.panel,
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
            const _QuickRule('🎯', 'Capture the most 10s over 13 tricks! Most 10s wins; tied? Most cards, then most aces.'),
            const _QuickRule('🚫', 'First trick: no Power Suit cards and no 10s.'),
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

const _rankValues = {
  'A': 14, 'K': 13, 'Q': 12, 'J': 11, '10': 10,
  '9': 9, '8': 8, '7': 7, '6': 6, '5': 5, '4': 4, '3': 3, '2': 2,
};

/// The cards the local player may legally play RIGHT NOW, mirroring
/// backend/src/game/rules.ts legalCardsForSeat exactly. Round 10:
/// the frontend used to implement only follow-suit, so cards the UI
/// showed as playable were rejected by the server (must-play-higher,
/// off-suit-10 discard, first-trick "unless forced"), and taps during
/// the 2s trick-resolving window were judged against the just-
/// completed trick — whose lead suit and currentTurnSeat (the winner)
/// made a legal lead-suit card look illegal. Returns [] unless the
/// match is in 'playing' phase, it is the player's turn, and a power
/// suit is chosen.
List<ArenaCard> _legalCardsFor(
  MatchState match,
  List<ArenaCard> hand,
  String myTeam,
  bool isMyTurn,
) {
  if (match.phase != 'playing' || !isMyTurn || match.powerSuit == null) {
    return const [];
  }
  final trick = match.currentTrick;
  final leadSuit = trick?.leadSuit;
  var candidates = List<ArenaCard>.from(hand);
  if (leadSuit != null && hand.any((c) => c.suit == leadSuit)) {
    candidates = hand.where((c) => c.suit == leadSuit).toList();
    // Must play higher — but only after the first trick, and only
    // when the teammate is not currently winning the trick.
    if (trick != null &&
        trick.plays.isNotEmpty &&
        match.completedTricksCount > 0) {
      if (!_teammateCurrentlyWinning(trick, match.powerSuit!, myTeam)) {
        final highest = _highestRankInSuit(trick.plays, leadSuit);
        if (highest > 0) {
          final higher = candidates
              .where((c) => (_rankValues[c.rank] ?? 0) > highest)
              .toList();
          if (higher.isNotEmpty) candidates = higher;
        }
      }
    }
  }
  // Cannot discard off-suit 10s while holding more than 3 cards.
  if (leadSuit != null && hand.length > 3) {
    final restricted = candidates.where((c) {
      if (c.rank != '10') return true;
      if (c.suit == match.powerSuit) return true;
      if (c.suit == leadSuit) return true;
      return false;
    }).toList();
    if (restricted.isNotEmpty) candidates = restricted;
  }
  // First trick: no Power Suit cards and no 10s — unless forced
  // (every card in hand is restricted).
  if (match.completedTricksCount == 0) {
    final unrestricted = candidates.where((c) {
      return c.suit != match.powerSuit && c.rank != '10';
    }).toList();
    if (unrestricted.isNotEmpty) return unrestricted;
  }
  return candidates;
}

/// Is the local player's teammate currently winning this trick?
/// Mirrors backend rules.ts currentWinner: a power-suit play beats
/// any non-power play; otherwise the highest card of the lead suit
/// wins. Teams are seats 0,2 = A and 1,3 = B.
bool _teammateCurrentlyWinning(
  CurrentTrick trick,
  String powerSuit,
  String myTeam,
) {
  if (trick.plays.isEmpty || trick.leadSuit == null) return false;
  final powerPlays =
      trick.plays.where((p) => p.card.suit == powerSuit).toList();
  final pool = powerPlays.isNotEmpty
      ? powerPlays
      : trick.plays.where((p) => p.card.suit == trick.leadSuit).toList();
  TrickPlay best = pool.first;
  for (final p in pool) {
    if ((_rankValues[p.card.rank] ?? 0) > (_rankValues[best.card.rank] ?? 0)) {
      best = p;
    }
  }
  final winnerTeam = best.seat % 2 == 0 ? 'A' : 'B';
  return winnerTeam == myTeam;
}

int _highestRankInSuit(List<TrickPlay> plays, String suit) {
  var highest = 0;
  for (final p in plays) {
    if (p.card.suit == suit) {
      final v = _rankValues[p.card.rank] ?? 0;
      if (v > highest) highest = v;
    }
  }
  return highest;
}

/// Plain-words reason a card cannot be played right now, in the same
/// order the backend's assertLegalMove raises its errors — so the
/// message can never blame the wrong rule. Round 10: this used to
/// return the follow-suit message whenever the hand held a lead-suit
/// card, WITHOUT checking the tapped card's suit — so a diamond
/// tapped on a diamond lead was "rejected" with "You must follow
/// the lead suit (diamonds)".
String? _illegalReasonFor(
  ArenaCard card,
  MatchState match,
  List<ArenaCard> hand,
  bool isMyTurn,
  String myTeam,
) {
  // Not in a playable phase (trick being collected, power-select,
  // dealing): the tap landed between tricks, not on a real turn.
  if (match.phase != 'playing') {
    return 'Wait — the trick is being collected. Play when your turn starts.';
  }
  if (!isMyTurn) return "Wait — it's not your turn yet.";
  final leadSuit = match.currentTrick?.leadSuit;
  // Follow suit — only when the tapped card is actually OFF-suit.
  if (leadSuit != null &&
      card.suit != leadSuit &&
      hand.any((c) => c.suit == leadSuit)) {
    return 'You must follow the lead suit ($leadSuit) — play a $leadSuit card.';
  }
  if (match.completedTricksCount == 0 &&
      (card.rank == '10' ||
          (match.powerSuit != null && card.suit == match.powerSuit))) {
    return 'No Power Suit cards or 10s on the first trick.';
  }
  if (card.rank == '10' &&
      leadSuit != null &&
      card.suit != leadSuit &&
      card.suit != match.powerSuit &&
      hand.length > 3) {
    return "You can't throw away a 10 of another suit while you have more than 3 cards.";
  }
  // Every other rejection the server can raise is the higher rule:
  // the card follows suit but a higher card of the lead suit is
  // available and the teammate is not winning.
  return 'You must play a higher card if possible.';
}

/// Tap-time play decision, made from the CURRENT match state — not
/// the state at build time. Round 8 fixed the stale-build-time check;
/// Round 10 fixes what that check was judging: the old legality only
/// knew follow-suit, and it never checked the phase, so a tap during
/// the 2s trick-resolving window was judged against the completed
/// trick (wrong lead suit, winner as current turn). Now a legal card
/// always plays on the first tap, and the reason always names the
/// rule that actually blocks the card. Returns true when played.
/// The single tap path for playing a card (Round 11: drag-to-play
/// was removed — see _HandArea — so this is the only play path).
bool _tryPlayCard({
  required AppState app,
  required ArenaCard card,
  required void Function(String reason) onIllegalTap,
  required VoidCallback onLegalPlay,
}) {
  final m = app.match;
  if (m == null) return false;
  final nowMyTurn = m.players.any(
    (p) => p.userId == app.userId && p.seat == m.currentTurnSeat,
  );
  final legalIds =
      _legalCardsFor(m, m.hand, app.myTeam, nowMyTurn).map((c) => c.id).toSet();
  if (nowMyTurn && m.phase == 'playing' && legalIds.contains(card.id)) {
    onLegalPlay();
    app.playCard(card.id);
    return true;
  }
  final reason = _illegalReasonFor(card, m, m.hand, nowMyTurn, app.myTeam);
  if (reason != null) onIllegalTap(reason);
  return false;
}

// ── Hand Area with Auto-Sort & Legal Move Highlighting ───────────────────────

class _HandArea extends StatelessWidget {
  const _HandArea({
    required this.app,
    required this.cardWidth,
    required this.autoSort,
    required this.highlightLegal,
    this.onIllegalTap,
    this.onLegalPlay,
  });

  final AppState app;
  final double cardWidth;
  final bool autoSort;
  final bool highlightLegal;
  /// Called (with a plain-words reason) when the player taps a card
  /// they cannot play. Previously such taps did nothing at all.
  final void Function(String reason)? onIllegalTap;
  /// Called when the player plays a legal card — the game screen uses
  /// it to clear a sticky illegal-tap hint, so a stale hint ("You must
  /// follow the lead suit") cannot linger after the player complied.
  final VoidCallback? onLegalPlay;

  static const _suitValues = {
    'spades': 4,
    'hearts': 3,
    'diamonds': 2,
    'clubs': 1,
  };

  /// One tap path for both outcomes: _tryPlayCard re-checks
  /// playability at tap time against the CURRENT match state with
  /// the faithful legality (Round 10) — if the card is playable it
  /// plays, otherwise the player gets the plain-words reason
  /// instead of silence. Sound/haptics only on a real play.
  void _handleCardTap(AppState app, ArenaCard card) {
    final played = _tryPlayCard(
      app: app,
      card: card,
      onIllegalTap: (reason) => onIllegalTap?.call(reason),
      onLegalPlay: () => onLegalPlay?.call(),
    );
    if (played) {
      AudioService.instance.playCardPlace();
      AudioService.instance.hapticLight();
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = app.match!;
    final isMyTurn = match.players.any(
      (p) => p.userId == app.userId && p.seat == match.currentTurnSeat,
    );
    // Round 11: NO Draggable wrapper on hand cards. The old code
    // wrapped playable cards in Draggable on desktop widths, and a
    // mouse's hit slop is 1.0 logical pixel (Flutter
    // computeHitSlop: PointerDeviceKind.mouse -> kPrecisePointerHitSlop).
    // ImmediateMultiDragGestureRecognizer resolves "accepted" as soon
    // as the pointer moves >1px — a normal mouse click drifts that far
    // — so the drag recognizer won the gesture arena and the tap
    // recognizer lost: the first tap was silently swallowed (the card
    // only raised / showed drag feedback), and the next click could
    // land on a neighbouring off-suit card, which the legality code
    // then rightly rejected with a follow-suit message. That is the
    // Round 10 turn-change tap failures (A-clubs, 8-hearts, K-diamonds):
    // the legality rules were already correct; the gesture layer was
    // misrouting the taps. Tapping is the only play interaction now.
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

    // Round 10: the dim/highlight state uses the same faithful
    // legality as the tap handler, so a card the UI shows as
    // playable can never be rejected by the server. Outside
    // 'playing' (power-select, trick being collected) there is
    // nothing to highlight — every card looks normal.
    final legalIds = match.phase == 'playing'
        ? _legalCardsFor(match, match.hand, app.myTeam, isMyTurn)
            .map((c) => c.id)
            .toSet()
        : <String>{};

    return LayoutBuilder(
      builder: (context, constraints) {
        final aw = constraints.maxWidth - 16;
        double widthFactor = 1.0;
        double overlapWidth = cardWidth;
        if (N > 1) {
          final maxOverlap = (aw - cardWidth) / (N - 1);
          // At least 20px of each card stays visible — the corner pip
          // (rank + suit) needs ~16px, so a card is always readable.
          overlapWidth = maxOverlap.clamp(20.0, cardWidth);
          widthFactor = overlapWidth / cardWidth;
        }
        // Full row width, including each card's horizontal margin
        // (3 × scale on each side inside ArenaCardWidget).
        final rowWidth = N == 0
            ? 0.0
            : (N - 1) * overlapWidth + cardWidth + N * 6 * (cardWidth / 70);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          // Round 8: this used to be Center > SingleChildScrollView.
          // When the row is wider than the viewport, Center centres
          // it — so it overflows equally on BOTH sides and the
          // leftmost card sits off-screen with no way to scroll to
          // it (scroll offset 0 is the left edge). Now the scroll
          // child's width is max(available, row): when the row fits
          // it is centred; when it does not, it starts at the left
          // edge and the leftmost card is always reachable.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(aw, rowWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(N, (index) {
                  final card = hand[index];
                  final isLegal = match.phase == 'playing'
                      ? legalIds.contains(card.id)
                      : true;
                  // 3D fan arc — shallow, so the outer cards don't
                  // ride up over the table.
                  final double fanAngle = N > 1 ? (index - (N - 1) / 2) * 0.015 : 0.0;
                  final double yOffset = N > 1 ? ((index - (N - 1) / 2).abs() * 1).toDouble() : 0.0;

                  final cardWidget = ArenaCardWidget(
                    key: ValueKey(card.id),
                    card: card,
                    powerSuit: match.powerSuit,
                    isLegal: highlightLegal ? isLegal : true,
                    // One tap path for both outcomes: _handleCardTap
                    // re-checks playability at tap time (Round 8).
                    onPlay: () => _handleCardTap(app, card),
                    onIllegalTap: () => _handleCardTap(app, card),
                    dimmed: !isMyTurn,
                    width: cardWidth,
                  );

                  // Keyed by card id, so a hand rebuild (new state
                  // arriving exactly as a tap lands) can never reuse
                  // one card's Element/gesture state for another card.
                  // Round 12: EVERY card gets the same Align wrapper
                  // (the last card used to be a bare Transform). The
                  // old shape change meant the card that became last
                  // when the hand shrank was unmounted and remounted
                  // — and a tap in flight on it died silently when
                  // its gesture recognizer was disposed mid-gesture
                  // (proven in swallowed_tap_test.dart). The last
                  // card's Align keeps widthFactor 1.0 so it stays
                  // fully visible and the row width is unchanged.
                  Widget wrappedCard = Transform(
                    key: ValueKey(card.id),
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..translate(0.0, yOffset, 0.0)
                      ..rotateZ(fanAngle),
                    alignment: Alignment.bottomCenter,
                    child: cardWidget,
                  );

                  return Align(
                    key: ValueKey(card.id),
                    widthFactor: index < N - 1 ? widthFactor : 1.0,
                    alignment: Alignment.centerLeft,
                    child: wrappedCard,
                  );
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
