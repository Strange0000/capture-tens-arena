import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/arena_loading.dart';
import '../widgets/royal_widgets.dart';

import '../models/arena_card.dart';
import '../models/rank_info.dart';
import '../widgets/arena_card_widget.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with TickerProviderStateMixin {
  final _roomCodeController = TextEditingController();
  final _friendUsernameController = TextEditingController();
  bool _showRoomPanel = false;
  /// One-shot guard for the auto-navigate below (see build): without it
  /// every rebuild while app.match != null re-pushed /game — so after
  /// Home/Leave, a stale match state bounced the lobby straight back
  /// to the game screen and Home looked dead.
  bool _navigationTriggered = false;
  bool _tutorialPromptChecked = false;

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryAnim;

  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playLobbyBgm();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _entryCtrl.forward();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    _maybePromptTutorial();
  }

  /// First visit only: offer the interactive tutorial / rules instead
  /// of dropping a new guest straight into the portals. The
  /// 'tutorial_completed' flag was previously write-only — nothing
  /// ever read it, so new players were never prompted.
  Future<void> _maybePromptTutorial() async {
    if (_tutorialPromptChecked) return;
    _tutorialPromptChecked = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('tutorial_completed') == true) return;
    if (!mounted) return;
    // Let the lobby settle first so the prompt does not fight the entry animation.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArenaColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFFFFC857).withOpacity(0.4)),
        ),
        title: const Text(
          'New to Capture Tens?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Learn the rules in about 2 minutes — capture the most 10s over 13 tricks, and how the Power Suit works.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip for now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('How to Play'),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      Navigator.pushNamed(context, '/tutorial');
    }
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _friendUsernameController.dispose();
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // Auto-redirect to login if not logged in
    if (!app.isLoggedIn) {
      if (app.isAuthChecking) {
        return const Scaffold(
          backgroundColor: Color(0xFF070B13),
          body: ArenaLoading(message: 'Loading the Arena…'),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        }
      });
      return const Scaffold(
        backgroundColor: Color(0xFF070B13),
        body: ArenaLoading(message: 'Loading the Arena…'),
      );
    }

    // Auto-navigate to game when match starts — one-shot only.
    if (app.match == null) {
      _navigationTriggered = false;
    } else if (!_navigationTriggered) {
      _navigationTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pushNamed(context, '/game');
        }
      });
    }

    // Show errors
    if (app.errorMessage != null) {
      final msg = app.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        app.clearError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
          ),
        );
      });
    }

    if (app.pendingPartyInvite != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _showPartyInviteDialog(context, app);
      });
    }

    // Royal Casino room (poker reference): the old lobby_bg.png photo
    // (dark teal neon hall) is gone — felt background, drawn in code.
    return RoyalBackground(
      child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: FadeTransition(
                opacity: _entryAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(_entryAnim),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      // Round 10: at 506px height the wide layout's
                      // How to Play / Tutorial buttons sat ~48px below
                      // the fold. Compact mode trims paddings/gaps and
                      // shrinks the centre table so everything fits in
                      // the initial view (scrolling still works).
                      final isShort =
                          MediaQuery.sizeOf(context).height < 560;
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24, vertical: isShort ? 10 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Top Command Bar ──────────────────────────────
                            _LobbyTopBar(
                              app: app,
                              onRules: () => _showRulesSheet(context),
                              onTutorial: () => Navigator.pushNamed(context, '/tutorial'),
                              onFriends: () => _showFriendsSheet(context),
                              onAchievements: () => Navigator.pushNamed(context, '/achievements'),
                              onSettings: () => Navigator.pushNamed(context, '/settings'),
                              onProfile: () => Navigator.pushNamed(context, '/profile'),
                            ),
                            SizedBox(height: isShort ? 12 : 24),

                            // ── Active Matchmaking / Room Banners ────────────
                            if (app.lobbyStatus == LobbyStatus.queuing) ...[
                              _QueueBanner(onCancel: app.leaveMatch),
                              const SizedBox(height: 16),
                            ],

                            if (app.lobbyStatus == LobbyStatus.inRoom && app.roomCode != null) ...[
                              _RoomBanner(
                                code: app.roomCode!,
                                playerNames: app.roomPlayerNames,
                                playerCount: app.roomPlayerCount,
                                capacity: app.roomCapacity,
                                onCopyCode: () {
                                  Clipboard.setData(ClipboardData(text: app.roomCode!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Room code copied')),
                                  );
                                },
                                onStartWithBots: app.startRoomWithBots,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── Dynamic Responsive Body ──────────────────────
                            if (isWide)
                              _buildWideLayout(context, app, compact: isShort)
                            else
                              _buildNarrowLayout(context, app),

                            SizedBox(height: isShort ? 12 : 24),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
    );
  }

  // ── Wide Desktop / Tablet Layout ───────────────────────────────────────────
  // Round 7 — a NEW layout, not a recolour: a big oval felt table in
  // the CENTRE with the three game modes as round gold chips on its
  // rim, a small career plaque at the TOP LEFT, and the Friends panel
  // as a slim vertical strip on the RIGHT. The old structure (tall
  // rank card on the left + stacked mode rows in the middle) is gone.
  Widget _buildWideLayout(BuildContext context, AppState app,
      {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: small career plaque (top-left) + party.
            SizedBox(
              width: 264,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CareerPlaque(
                    username: app.username,
                    rankInfo: app.rankInfo,
                    onViewTiers: () => _showTiersSheet(context),
                    onViewReplays: () => Navigator.pushNamed(context, '/replay'),
                  ),
                  if (app.party != null) ...[
                    const SizedBox(height: 12),
                    _PartyBanner(party: app.party!, onLeave: app.leaveParty),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Centre: the oval table with the mode chips on its rim.
            Expanded(child: _LobbyTable(context: context, app: app, compact: compact, showRoomPanel: _showRoomPanel, onToggleRoomPanel: () => setState(() => _showRoomPanel = !_showRoomPanel), roomController: _roomCodeController)),
            const SizedBox(width: 16),
            // Right: slim Friends strip.
            SizedBox(
              width: 272,
              child: _FriendsPanel(
                app: app,
                onAdd: () => _showFriendsSheet(context),
                onRemove: (friendId, username) => _confirmRemoveFriend(context, app, friendId, username),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 14),
        // How to Play / Tutorial — under the table, centred.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                onPressed: () => _showRulesSheet(context),
                icon: const Icon(Icons.menu_book_rounded, color: Color(0xFFFFC857), size: 20),
                label: const Text('How to Play'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFFFC857), width: 1.2),
                  padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/tutorial'),
                icon: const Icon(Icons.school_rounded, color: Color(0xFFFFC857), size: 20),
                label: const Text('Interactive Tutorial'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Lobby centre table ─────────────────────────────────────────────────────
  // Oval felt table (same wood rim + gold pinstripe as the game table)
  // with three sample cards in the middle and the game modes as round
  // gold chips sitting on its rim — Ranked top, Bot Practice bottom
  // left, Private Room bottom right. Tapping a chip enters that mode.
  Widget _LobbyTable({
    required BuildContext context,
    required AppState app,
    required bool showRoomPanel,
    required VoidCallback onToggleRoomPanel,
    required TextEditingController roomController,
    bool compact = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Round 10: compact mode (short viewports) shrinks the table
        // so the How to Play / Tutorial buttons fit in the initial
        // view — the table is decoration here, the chips are the nav.
        final tableW = constraints.maxWidth.clamp(
          320.0,
          compact ? 380.0 : 640.0,
        );
        final tableH = tableW * 0.58;
        final chipD = compact ? 96.0 : 118.0;
        return Column(
          children: [
            SizedBox(
              width: tableW,
              height: tableH + chipD * 0.55,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // The oval table.
                  Center(
                    child: Container(
                      width: tableW,
                      height: tableH,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.elliptical(999, 999)),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFB07A45), Color(0xFF7A4E24), Color(0xFF4A2C14)],
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 28, offset: const Offset(0, 10)),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.elliptical(999, 999)),
                          border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFC857), width: 2)),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.elliptical(999, 999)),
                            gradient: RadialGradient(
                              center: Alignment(0, -0.25),
                              radius: 1.1,
                              colors: [Color(0xFF1B7A4D), Color(0xFF0E5C38), Color(0xFF0B3D2E)],
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.rotate(angle: -0.08, child: ArenaCardWidget(card: const ArenaCard(id: 'lobby-a', rank: 'A', suit: 'spades'), powerSuit: null, onPlay: null, width: 52)),
                                const SizedBox(width: 6),
                                Transform.rotate(angle: 0.04, child: ArenaCardWidget(card: const ArenaCard(id: 'lobby-k', rank: 'K', suit: 'hearts'), powerSuit: null, onPlay: null, width: 52)),
                                const SizedBox(width: 6),
                                Transform.rotate(angle: 0.1, child: ArenaCardWidget(card: const ArenaCard(id: 'lobby-q', rank: 'Q', suit: 'clubs'), powerSuit: null, onPlay: null, width: 52)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Ranked — top rim.
                  Positioned(
                    top: -6,
                    child: _ModeChip(
                      label: 'Ranked',
                      sublabel: '2v2 · +25 MMR',
                      icon: Icons.military_tech_rounded,
                      color: const Color(0xFFFFC857),
                      diameter: chipD,
                      onTap: () {
                        app.queueRanked();
                        Navigator.pushNamed(context, '/matchmaking');
                      },
                    ),
                  ),
                  // Bot Practice — bottom-left rim.
                  Positioned(
                    left: tableW * 0.06,
                    bottom: -6,
                    child: _ModeChip(
                      label: 'Bot Practice',
                      sublabel: 'Solo · Risk free',
                      icon: Icons.smart_toy_rounded,
                      color: const Color(0xFF3FA97C),
                      diameter: chipD,
                      onTap: () {
                        app.startOffline('hard');
                        Navigator.pushNamed(context, '/game');
                      },
                    ),
                  ),
                  // Private Room — bottom-right rim.
                  Positioned(
                    right: tableW * 0.06,
                    bottom: -6,
                    child: _ModeChip(
                      label: 'Private Room',
                      sublabel: 'Custom code',
                      icon: Icons.group_add_rounded,
                      color: const Color(0xFFD4A017),
                      diameter: chipD,
                      onTap: onToggleRoomPanel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'SELECT A MODE TO START',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: ArenaColors.gold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ranked — competitive 2v2 · Bot Practice — solo vs bots · Private Room — play with friends',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: showRoomPanel
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _PrivateRoomPanel(
                        controller: roomController,
                        onCreate: () => app.createRoom(),
                        onJoin: () {
                          final code = roomController.text.trim();
                          if (code.isEmpty) return;
                          app.joinRoom(code);
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  // ── Small career plaque (top-left of the wide lobby) ────────────────
  // Compact cream/gold plaque: crest, name, tier, wins/losses — the
  // tall rank showcase card lives on in the narrow layout only.
  Widget _CareerPlaque({
    required String? username,
    required RankInfo? rankInfo,
    required VoidCallback onViewTiers,
    required VoidCallback onViewReplays,
  }) {
    final rank = rankInfo ?? RankInfo.fromMmr(0);
    final tierColor = rank.color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE0).withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CAREER RATING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B2A22).withOpacity(0.55),
                  letterSpacing: 2.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rank.seasonDisplay,
                  style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Image.asset(rank.icon, height: 52, width: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username ?? 'Guest Player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B2A22)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rank.displayName}  ·  ${rank.mmr} MMR',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tierColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rank.progressInTier.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF1B2A22).withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Next: ${rank.nextTierMmr} MMR', style: TextStyle(color: const Color(0xFF1B2A22).withOpacity(0.5), fontSize: 11)),
              Text('Peak: ${rank.peakMmr} MMR', style: TextStyle(color: const Color(0xFF1B2A22).withOpacity(0.5), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2A22).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1B2A22).withOpacity(0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCell(label: 'WINS', value: '${rank.wins}', color: const Color(0xFF3FA97C)),
                Container(width: 1, height: 24, color: const Color(0xFF1B2A22).withOpacity(0.12)),
                _StatCell(label: 'LOSSES', value: '${rank.losses}', color: Colors.redAccent),
                Container(width: 1, height: 24, color: const Color(0xFF1B2A22).withOpacity(0.12)),
                _StatCell(label: 'WIN RATE', value: rank.winRate, color: const Color(0xFFFFC857)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewTiers,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF1B2A22).withOpacity(0.25)),
                    foregroundColor: const Color(0xFF1B2A22).withOpacity(0.85),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.leaderboard_rounded, size: 16),
                  label: const Text('Tier List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewReplays,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF1B2A22).withOpacity(0.25)),
                    foregroundColor: const Color(0xFF1B2A22).withOpacity(0.85),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Replays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Narrow Mobile Layout ───────────────────────────────────────────────────
  Widget _buildNarrowLayout(BuildContext context, AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RankShowcaseCard(
          username: app.username,
          rankInfo: app.rankInfo,
          floatAnim: _floatAnim,
          onViewTiers: () => _showTiersSheet(context),
          onViewReplays: () => Navigator.pushNamed(context, '/replay'),
        ),
        if (app.party != null) ...[
          const SizedBox(height: 16),
          _PartyBanner(party: app.party!, onLeave: app.leaveParty),
        ],
        const SizedBox(height: 24),
        _buildSectionHeader('SELECT ARENA', 'Choose your game mode'),
        const SizedBox(height: 16),
        _buildGamePortals(context, app),
        const SizedBox(height: 16),
        _FriendsPanel(
          app: app,
          onAdd: () => _showFriendsSheet(context),
          onRemove: (friendId, username) => _confirmRemoveFriend(context, app, friendId, username),
        ),
      ],
    );
  }

  /// Remove a friend from the lobby's Friends panel (not only from
  /// inside the sheet): confirm first, then show plain-words feedback.
  Future<void> _confirmRemoveFriend(
    BuildContext context,
    AppState app,
    String friendId,
    String username,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F2018),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ArenaColors.gold.withOpacity(0.35)),
        ),
        title: const Text('Remove friend?', style: TextStyle(color: Colors.white)),
        content: Text('Remove $username from your friends list?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep friend'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await app.removeFriend(friendId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Friend removed' : (app.friendActionError ?? 'Could not remove friend')),
        backgroundColor: ok ? const Color(0xFF167D68) : Colors.redAccent.shade700,
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC857),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC857).withOpacity(0.6),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGamePortals(BuildContext context, AppState app) {
    // The three portals, built once per layout: tall gold-bordered
    // cards in a row on wide screens (reference mockup), horizontal
    // rows on narrow screens. One shared builder, so the layout can
    // only change when the available width crosses the breakpoint —
    // never between visits at the same width.
    List<Widget> portals({required bool vertical}) => [
          _GamePortalCard(
            vertical: vertical,
            themeColor: const Color(0xFFFFC857),
            badgeTag: 'COMPETITIVE 2v2',
            title: 'Ranked Match',
            subtitle: 'Climb competitive tiers and earn seasonal MMR points',
            icon: Icons.military_tech_rounded,
            perks: const ['⚡ +25 MMR / Win', '🏆 Tier Leaderboard', '👥 2v2 Teams'],
            ctaText: 'PLAY RANKED',
            onTap: () {
              app.queueRanked();
              Navigator.pushNamed(context, '/matchmaking');
            },
          ),
          _GamePortalCard(
            vertical: vertical,
            themeColor: const Color(0xFF3FA97C),
            badgeTag: 'SOLO PRACTICE',
            title: 'Bot Practice',
            subtitle: 'Hone your strategy against advanced neural AI bots',
            icon: Icons.smart_toy_rounded,
            perks: const ['🤖 Hard AI', '⚡ Instant Match', '🎯 Risk Free'],
            ctaText: 'PLAY PRACTICE',
            onTap: () {
              app.startOffline('hard');
              Navigator.pushNamed(context, '/game');
            },
          ),
          _GamePortalCard(
            vertical: vertical,
            themeColor: const Color(0xFFD4A017),
            badgeTag: 'CUSTOM ROOM',
            title: 'Private Room',
            subtitle: 'Create a private salon with custom codes for friends or bots',
            icon: Icons.group_add_rounded,
            perks: const ['🔒 Private Code', '👥 Custom Squads', '🤖 Fill with Bots'],
            ctaText: _showRoomPanel ? 'HIDE ROOM PANEL' : 'HOST OR JOIN ROOM',
            onTap: () {
              setState(() => _showRoomPanel = !_showRoomPanel);
            },
          ),
        ];

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              final cards = portals(vertical: true);
              return SizedBox(
                height: 330,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[2]),
                  ],
                ),
              );
            }
            final cards = portals(vertical: false);
            return Column(
              children: [
                cards[0],
                const SizedBox(height: 16),
                cards[1],
                const SizedBox(height: 16),
                cards[2],
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ── How to Play ─────────────────────────────────────────────────
        // Text-labelled entry in the lobby body (previously only a small
        // top-bar icon / overflow item, easy to miss).
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRulesSheet(context),
                icon: const Icon(Icons.menu_book_rounded, color: Color(0xFFFFC857), size: 20),
                label: const Text('How to Play'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFFFC857), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/tutorial'),
                icon: const Icon(Icons.school_rounded, color: Color(0xFFFFC857), size: 20),
                label: const Text('Interactive Tutorial'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),

        // Custom room drawer
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: _showRoomPanel
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _PrivateRoomPanel(
                    controller: _roomCodeController,
                    onCreate: () => app.createRoom(),
                    onJoin: () {
                      final code = _roomCodeController.text.trim();
                      if (code.isEmpty) return;
                      app.joinRoom(code);
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }


  void _showRulesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ArenaColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _RulesSheet(),
    );
  }

  void _showFriendsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ArenaColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FriendsSheet(controller: _friendUsernameController),
    );
  }

  void _showPartyInviteDialog(BuildContext context, AppState app) {
    final invite = app.pendingPartyInvite!;
    app.pendingPartyInvite = null;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArenaColors.panel,
        title: const Text('Party Invite', style: TextStyle(color: Colors.white)),
        content: Text(
          '${invite['from']} invited you to join their party.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              app.declinePartyInvite();
              Navigator.pop(context);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              app.acceptPartyInvite();
              Navigator.pop(context);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showTiersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Container(
          decoration: const BoxDecoration(
            color: ArenaColors.panelLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Competitive Tiers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Win: +25 RP  |  Loss: -15 RP',
                  style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: RankInfo.tiers.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final tier = RankInfo.tiers.reversed.toList()[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Image.asset(tier.icon, height: 32, width: 32),
                      title: Text(tier.name, style: TextStyle(color: tier.color, fontWeight: FontWeight.bold)),
                      trailing: Text('${tier.min} RP',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Top Command Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _LobbyTopBar extends StatelessWidget {
  const _LobbyTopBar({
    required this.app,
    required this.onRules,
    required this.onTutorial,
    required this.onFriends,
    required this.onAchievements,
    required this.onSettings,
    required this.onProfile,
  });

  final AppState app;
  final VoidCallback onRules;
  final VoidCallback onTutorial;
  final VoidCallback onFriends;
  final VoidCallback onAchievements;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 680;

    return Row(
      children: [
        // Brand Logo & Live Season Badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/lobby_hero_logo.png',
              height: isCompact ? 36 : 48,
              fit: BoxFit.contain,
            ),
            if (!isCompact) ...[
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC857),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SEASON 1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFC857),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const Spacer(),

        // Right Action Capsule & Profile
        GlassPanel(
          borderRadius: 24,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8, vertical: 4),
          backgroundColor: Colors.white.withOpacity(0.04),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCompact) ...[
                _TopIconButton(
                  tooltip: 'Game Rules',
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFFFFC857),
                  onTap: onRules,
                ),
                _TopIconButton(
                  tooltip: 'Interactive Tutorial',
                  icon: Icons.school_rounded,
                  iconColor: const Color(0xFFFFC857),
                  onTap: onTutorial,
                ),
                _TopIconButton(
                  tooltip: 'Achievements',
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFFFC857),
                  onTap: onAchievements,
                ),
              ] else ...[
                // Compact overflow menu button on mobile
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                  color: ArenaColors.panel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  onSelected: (val) {
                    if (val == 'rules') onRules();
                    if (val == 'tutorial') onTutorial();
                    if (val == 'achievements') onAchievements();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rules',
                      child: Row(children: [
                        Icon(Icons.menu_book_rounded, color: Color(0xFFFFC857), size: 18),
                        SizedBox(width: 10),
                        Text('Rules', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'tutorial',
                      child: Row(children: [
                        Icon(Icons.school_rounded, color: Color(0xFFFFC857), size: 18),
                        SizedBox(width: 10),
                        Text('Tutorial', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'achievements',
                      child: Row(children: [
                        Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC857), size: 18),
                        SizedBox(width: 10),
                        Text('Achievements', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ]),
                    ),
                  ],
                ),
              ],
              _TopIconButton(
                tooltip: 'Friends',
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFFFFC857),
                onTap: onFriends,
              ),
              _TopIconButton(
                tooltip: 'Settings',
                icon: Icons.settings_rounded,
                onTap: onSettings,
              ),
              const SizedBox(width: 4),
              // Profile Pill Button
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onProfile,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFFFFC857).withOpacity(0.2),
                        child: const Icon(Icons.person, size: 14, color: Color(0xFFFFC857)),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            app.username ?? 'Player',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      onPressed: onTap,
      icon: Icon(icon, color: iconColor ?? Colors.white70),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Player Rank Showcase Hero Card (Left Column)
// ═══════════════════════════════════════════════════════════════════════════════

class _RankShowcaseCard extends StatelessWidget {
  const _RankShowcaseCard({
    required this.username,
    required this.rankInfo,
    required this.floatAnim,
    required this.onViewTiers,
    required this.onViewReplays,
  });

  final String? username;
  final RankInfo? rankInfo;
  final Animation<double> floatAnim;
  final VoidCallback onViewTiers;
  final VoidCallback onViewReplays;

  @override
  Widget build(BuildContext context) {
    final rank = rankInfo ?? RankInfo.fromMmr(0);
    final tierColor = rank.color;

    return GlassPanel(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      // Cream casino plaque (gold-trimmed cream card), not the old
      // dark-navy panel.
      backgroundColor: const Color(0xFFF5EFE0).withOpacity(0.97),
      border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.6), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header with Season Pip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CAREER RATING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B2A22).withOpacity(0.55),
                  letterSpacing: 2.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rank.seasonDisplay,
                  style: TextStyle(
                    color: tierColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Floating 3D Rank Trophy Crest
          Center(
            child: AnimatedBuilder(
              animation: floatAnim,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, floatAnim.value),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radial aura glow
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tierColor.withOpacity(0.35),
                              blurRadius: 36,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      Image.asset(rank.icon, height: 90, width: 90),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Player Name & Tier Title
          Center(
            child: Text(
              username ?? 'Guest Player',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B2A22),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${rank.displayName}  ·  ${rank.mmr} MMR',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tierColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // MMR Progress to Next Tier
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rank.progressInTier.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next: ${rank.nextTierMmr} MMR',
                style: TextStyle(color: const Color(0xFF1B2A22).withOpacity(0.5), fontSize: 11),
              ),
              Text(
                'Peak: ${rank.peakMmr} MMR',
                style: TextStyle(color: const Color(0xFF1B2A22).withOpacity(0.5), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stats Badge Matrix
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2A22).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1B2A22).withOpacity(0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCell(label: 'WINS', value: '${rank.wins}', color: const Color(0xFF3FA97C)),
                Container(width: 1, height: 26, color: const Color(0xFF1B2A22).withOpacity(0.12)),
                _StatCell(label: 'LOSSES', value: '${rank.losses}', color: Colors.redAccent),
                Container(width: 1, height: 26, color: const Color(0xFF1B2A22).withOpacity(0.12)),
                _StatCell(label: 'WIN RATE', value: rank.winRate, color: const Color(0xFFFFC857)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewTiers,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF1B2A22).withOpacity(0.25)),
                    foregroundColor: const Color(0xFF1B2A22).withOpacity(0.85),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.leaderboard_rounded, size: 16),
                  label: const Text('Tier List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewReplays,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF1B2A22).withOpacity(0.25)),
                    foregroundColor: const Color(0xFF1B2A22).withOpacity(0.85),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Replays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF1B2A22).withOpacity(0.55),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Luxury 3D Game Portal Card
// ═══════════════════════════════════════════════════════════════════════════════

class _GamePortalCard extends StatefulWidget {
  const _GamePortalCard({
    required this.themeColor,
    required this.badgeTag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.perks,
    required this.ctaText,
    required this.onTap,
    this.vertical = false,
  });

  final Color themeColor;
  final String badgeTag;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> perks;
  final String ctaText;
  final VoidCallback onTap;
  /// Tall card (crest on top, gold button at the bottom) for the
  /// wide-screen 3-column row, like the reference mockup.
  final bool vertical;

  @override
  State<_GamePortalCard> createState() => _GamePortalCardState();
}

class _GamePortalCardState extends State<_GamePortalCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        AudioService.instance.playCardClick();
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          AudioService.instance.playButtonTap();
          AudioService.instance.hapticSelection();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: _isHovered
              ? (Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..translate(0.0, -6.0, 0.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.themeColor.withOpacity(_isHovered ? 0.20 : 0.10),
                ArenaColors.panel.withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color: widget.themeColor.withOpacity(_isHovered ? 0.70 : 0.25),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.themeColor.withOpacity(_isHovered ? 0.25 : 0.05),
                blurRadius: _isHovered ? 28 : 12,
                spreadRadius: _isHovered ? 3 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 480;

                Widget ctaButton({bool fullWidth = false}) {
                  return Container(
                    width: fullWidth ? double.infinity : null,
                    alignment: fullWidth ? Alignment.center : null,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      color: widget.themeColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.themeColor.withOpacity(0.6)),
                      boxShadow: _isHovered
                          ? [
                              BoxShadow(
                                color: widget.themeColor.withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        Text(
                          widget.ctaText,
                          style: TextStyle(
                            color: const Color(0xFF070B13),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: const Color(0xFF070B13),
                        ),
                      ],
                    ),
                  );
                }

                // Tall card: crest on top, gold button pinned to the
                // bottom — the wide-screen row from the reference mockup.
                if (widget.vertical) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.themeColor.withOpacity(0.14),
                            border: Border.all(
                              color: widget.themeColor.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.themeColor.withOpacity(0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.themeColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.badgeTag,
                            style: TextStyle(
                              color: widget.themeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.55),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: widget.perks.map((p) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const Spacer(),
                        ctaButton(fullWidth: true),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Glowing Portal Crest
                          Container(
                            width: isMobile ? 48 : 64,
                            height: isMobile ? 48 : 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.themeColor.withOpacity(0.14),
                              border: Border.all(
                                color: widget.themeColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.themeColor.withOpacity(0.3),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.themeColor,
                              size: isMobile ? 24 : 32,
                            ),
                          ),
                          SizedBox(width: isMobile ? 12 : 20),

                          // Middle: Mode Information & Perks
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: widget.themeColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.badgeTag,
                                    style: TextStyle(
                                      color: widget.themeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Title
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: isMobile ? 18 : 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Subtitle
                                Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.55),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Perks Row
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: widget.perks.map((p) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        p,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.75),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),

                          if (!isMobile) ...[
                            const SizedBox(width: 16),
                            ctaButton(fullWidth: false),
                          ],
                        ],
                      ),
                      if (isMobile) ...[
                        const SizedBox(height: 14),
                        ctaButton(fullWidth: true),
                      ],
                    ],
                  ),
                );
              },
            ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Queue & Room Status Banners
// ═══════════════════════════════════════════════════════════════════════════════

class _QueueBanner extends StatelessWidget {
  const _QueueBanner({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      backgroundColor: const Color(0xFF0A2B1D).withOpacity(0.6),
      border: Border.all(color: const Color(0xFF3FA97C).withOpacity(0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF3FA97C),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MATCHMAKING IN PROGRESS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Color(0xFFFFC857),
                  ),
                ),
                Text(
                  'Searching for players of similar skill level…',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel Queue'),
          ),
        ],
      ),
    );
  }
}

class _RoomBanner extends StatelessWidget {
  const _RoomBanner({
    required this.code,
    required this.playerNames,
    required this.playerCount,
    required this.capacity,
    required this.onCopyCode,
    required this.onStartWithBots,
  });

  final String code;
  final List<String> playerNames;
  final int playerCount;
  final int capacity;
  final VoidCallback onCopyCode;
  final VoidCallback onStartWithBots;

  Widget _roomDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRIVATE ROOM CODE',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white54,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          code,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            color: Color(0xFFFFC857),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$playerCount of $capacity players joined',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (playerNames.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            playerNames.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 520;

    return GlassPanel(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      backgroundColor: const Color(0xFF2A2113).withOpacity(0.65),
      border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.5)),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.meeting_room_rounded,
                        color: Color(0xFFD4A017), size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: _roomDetails()),
                    IconButton(
                      tooltip: 'Copy room code',
                      onPressed: onCopyCode,
                      icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC857),
                    foregroundColor: const Color(0xFF070B13),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onStartWithBots,
                  icon: const Icon(Icons.smart_toy, size: 18),
                  label: const Text(
                    'Start with Bots',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.meeting_room_rounded,
                    color: Color(0xFFD4A017), size: 32),
                const SizedBox(width: 16),
                Expanded(child: _roomDetails()),
                IconButton(
                  tooltip: 'Copy room code',
                  onPressed: onCopyCode,
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC857),
                    foregroundColor: const Color(0xFF070B13),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onStartWithBots,
                  icon: const Icon(Icons.smart_toy, size: 18),
                  label: const Text(
                    'Start with Bots',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PrivateRoomPanel extends StatelessWidget {
  const _PrivateRoomPanel({
    required this.controller,
    required this.onCreate,
    required this.onJoin,
  });

  final TextEditingController controller;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 560;

    return GlassPanel(
      backgroundColor: const Color(0xFF161F33).withOpacity(0.75),
      border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.3)),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC857),
                    foregroundColor: const Color(0xFF070B13),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create New Room', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '── OR JOIN WITH CODE ──',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: 'ROOM CODE',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        style: const TextStyle(
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onJoin,
                      child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                // Create Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC857),
                      foregroundColor: const Color(0xFF070B13),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Create New Room', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Text('OR', style: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                // Code field
                Expanded(
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: 'ROOM CODE',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: const TextStyle(
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Join Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onJoin,
                  child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }
}

class _PartyBanner extends StatelessWidget {
  const _PartyBanner({required this.party, required this.onLeave});
  final List<dynamic> party;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      backgroundColor: const Color(0xFFFFC857).withOpacity(0.12),
      border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group, color: Color(0xFFFFC857), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your Party',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFC857),
                  ),
                ),
              ),
              TextButton(
                onPressed: onLeave,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Leave'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...party.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Text(
                      p['username'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Rules Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _RulesSheet extends StatelessWidget {
  const _RulesSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: Color(0xFFFFC857), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'How to Play',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Capture Tens is a 4-player trick-taking card game played in teams of 2.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _RuleSection(
                icon: '🎯',
                title: 'Objective',
                body: 'Capture the most 10s! The team with more 10s at the end of 13 tricks wins. '
                    'If tied, the team with the most total cards wins. '
                    'Still tied? Most aces breaks it.',
              ),
              _RuleSection(
                icon: '⚡',
                title: 'Power Suit (Trump)',
                body: 'The first player selects the Power Suit based on their first 5 cards. '
                    'Cards of the Power Suit beat all other suits.',
              ),
              _RuleSection(
                icon: '🔄',
                title: 'Gameplay',
                body: 'Each player plays 1 card per trick clockwise. '
                    'You MUST follow the lead suit if you can. '
                    'If you have no cards of the lead suit, you may play any card (including Power Suit).',
              ),
              _RuleSection(
                icon: '🚫',
                title: 'First Trick',
                body: 'On the very first trick, no Power Suit cards and no 10s can be played (unless you have no other option).',
              ),
              _RuleSection(
                icon: '📊',
                title: 'Card Ranking',
                body: 'A > K > Q > J > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2\n\n'
                    'Power suit always beats non-power suit cards, regardless of rank.',
              ),
              _RuleSection(
                icon: '🏆',
                title: 'Winning',
                body: 'After all 13 tricks:\n'
                    '1. Team with the most 10s wins\n'
                    '2. If tied on 10s → most total captured cards\n'
                    '3. If still tied → most aces',
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Got it!'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Friends Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _FriendsSheet extends StatefulWidget {
  const _FriendsSheet({required this.controller});
  final TextEditingController controller;

  @override
  State<_FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<_FriendsSheet> {
  Timer? _searchDebounce;
  final Set<String> _busyKeys = {};
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    final app = context.read<AppState>();
    app.fetchFriends();
    if (widget.controller.text.trim().length >= 2) {
      app.searchFriends(widget.controller.text.trim());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {});
    final app = context.read<AppState>();
    if (value.trim().length < 2) {
      app.searchFriends("");
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<AppState>().searchFriends(value);
    });
  }

  Future<void> _runAction(
    String key,
    Future<bool> Function() action,
    String successMessage,
  ) async {
    if (_busyKeys.contains(key)) return;
    setState(() => _busyKeys.add(key));
    final app = context.read<AppState>();
    final success = await action();
    if (!mounted) return;
    setState(() => _busyKeys.remove(key));
    final message = success ? successMessage : (app.friendActionError ?? "Could not update friend relationship");
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF167D68) : Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Widget _avatar(String username, {bool online = false}) {
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFFFC857).withOpacity(0.15),
          child: Text(
            username.trim().isEmpty ? "?" : username.trim()[0].toUpperCase(),
            style: const TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.w800),
          ),
        ),
        if (online)
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 11, height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF3FA97C),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F2018), width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(children: [
        Expanded(child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1.4))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(20)),
          child: Text("$count", style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _searchResultTile(AppState app, Map<String, dynamic> user) {
    final username = user["username"]?.toString() ?? "Player";
    final id = user["id"]?.toString() ?? username;
    final raw = user["relationship"];
    final relation = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final status = relation?["status"]?.toString();
    final isRequester = relation?["isRequester"] == true;
    final friendId = relation?["friendId"]?.toString() ?? "";
    final busy = _busyKeys.contains("search:$id");
    Widget action;
    if (status == "accepted") {
      action = IconButton(
        tooltip: "Invite to party",
        onPressed: busy ? null : () { app.inviteToParty(id); Navigator.pop(context); },
        icon: const Icon(Icons.group_add_rounded, color: Color(0xFFD4A017)),
      );
    } else if (status == "pending" && !isRequester) {
      action = Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: "Accept request",
          onPressed: busy || friendId.isEmpty ? null : () => _runAction("search:$id", () => app.acceptFriendRequest(friendId), "Friend request accepted"),
          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF3FA97C)),
        ),
        IconButton(
          tooltip: "Decline request",
          onPressed: busy || friendId.isEmpty ? null : () => _runAction("search:$id", () => app.removeFriend(friendId), "Friend request declined"),
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
        ),
      ]);
    } else if (status == "pending" && isRequester) {
      action = TextButton(
        onPressed: busy || friendId.isEmpty ? null : () => _runAction("search:$id", () => app.removeFriend(friendId), "Friend request cancelled"),
        child: Text(busy ? "…" : "Sent", style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );
    } else if (status == "blocked") {
      action = const Text("Blocked", style: TextStyle(color: Colors.redAccent, fontSize: 11));
    } else {
      action = ElevatedButton(
        onPressed: busy ? null : () => _runAction("search:$id", () => app.sendFriendRequest(username), "Friend request sent"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC857).withOpacity(0.15),
          foregroundColor: const Color(0xFFFFC857),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(busy ? "…" : "Add", style: const TextStyle(fontWeight: FontWeight.w800)),
      );
    }
    final subtitle = status == "accepted"
        ? (user["status"] == "online" ? "Friend • Online" : "Friend • Offline")
        : status == "pending"
            ? (isRequester ? "Request sent" : "Wants to be friends")
            : status == "blocked"
                ? "Unavailable"
                : (user["status"] == "online" ? "Online • Player" : "Player");
    return ListTile(
      key: ValueKey("search-$id"),
      contentPadding: EdgeInsets.zero,
      leading: _avatar(username, online: user["status"] == "online"),
      title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: action,
    );
  }

  Widget _relationshipTile(AppState app, Map<String, dynamic> f) {
    final rawUser = f["user"];
    final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : <String, dynamic>{};
    final username = user["username"]?.toString() ?? "Unknown player";
    final id = user["id"]?.toString() ?? "";
    final friendId = f["id"]?.toString() ?? "";
    final status = f["status"]?.toString() ?? "pending";
    final isRequester = f["isRequester"] == true;
    final busy = _busyKeys.contains("friend:$friendId");
    final online = user["status"] == "online" || app.friendOnlineStatus[id] == true;
    Widget trailing;
    if (status == "pending" && !isRequester) {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: "Accept request",
          onPressed: busy ? null : () => _runAction("friend:$friendId", () => app.acceptFriendRequest(friendId), "Friend request accepted"),
          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF3FA97C)),
        ),
        IconButton(
          tooltip: "Decline request",
          onPressed: busy ? null : () => _runAction("friend:$friendId", () => app.removeFriend(friendId), "Friend request declined"),
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
        ),
      ]);
    } else if (status == "accepted") {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: "Invite to party",
          onPressed: id.isEmpty ? null : () { app.inviteToParty(id); Navigator.pop(context); },
          icon: const Icon(Icons.group_add_rounded, color: Color(0xFFD4A017)),
        ),
        IconButton(
          tooltip: "Remove friend",
          onPressed: busy ? null : () => _confirmRemove(friendId, username),
          icon: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.white54),
        ),
      ]);
    } else {
      trailing = TextButton(
        onPressed: busy ? null : () => _runAction("friend:$friendId", () => app.removeFriend(friendId), isRequester ? "Friend request cancelled" : "Relationship removed"),
        child: Text(busy ? "…" : (isRequester ? "Cancel" : "Remove"), style: const TextStyle(color: Colors.white54)),
      );
    }
    final subtitle = status == "accepted"
        ? (online ? "Online" : user["status"]?.toString() == "in-match" ? "In a match" : "Offline")
        : status == "pending"
            ? (isRequester ? "Request sent • Waiting for response" : "Incoming friend request")
            : "Blocked";
    return ListTile(
      key: ValueKey("friend-$friendId"),
      contentPadding: EdgeInsets.zero,
      leading: _avatar(username, online: online),
      title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: trailing,
    );
  }

  Future<void> _confirmRemove(String friendId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ArenaColors.panel,
        title: const Text("Remove friend?", style: TextStyle(color: Colors.white)),
        content: Text("Remove $username from your friends list?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text("Keep friend")),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runAction("friend:$friendId", () => context.read<AppState>().removeFriend(friendId), "Friend removed");
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final incoming = app.friends.where((f) => f["status"] == "pending" && f["isRequester"] != true).toList();
    final outgoing = app.friends.where((f) => f["status"] == "pending" && f["isRequester"] == true).toList();
    final accepted = app.friends.where((f) => f["status"] == "accepted").toList();
    final query = widget.controller.text.trim();
    final showSearch = query.length >= 2;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      maxChildSize: 0.94,
      minChildSize: 0.55,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              const Text("Friends", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 5),
              const Text("Find players, manage requests, and invite friends to your party.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 14),
              if (app.isGuest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: ArenaColors.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ArenaColors.gold.withOpacity(0.25)),
                  ),
                  child: const Text(
                    'You are playing as a guest. Friends you add here stay in this browser only — sign in with Google to keep them on every device.',
                    style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                  ),
                ),
              if (app.isGuest) const SizedBox(height: 10),
              TextField(
                controller: widget.controller,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                onChanged: _onSearchChanged,
                onSubmitted: (value) => context.read<AppState>().searchFriends(value),
                decoration: InputDecoration(
                  hintText: "Search username (at least 2 characters)",
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                  suffixIcon: query.isEmpty ? null : IconButton(
                    tooltip: "Clear search",
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () { widget.controller.clear(); _onSearchChanged(""); setState(() {}); },
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              if (app.friendActionError != null) ...[
                const SizedBox(height: 6),
                Text(app.friendActionError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              // Direct add: type the exact username and send — no need
              // to wait for search results first.
              const SizedBox(height: 10),
              RoyalGoldButton(
                label: 'Send friend request',
                icon: Icons.person_add_alt_1_rounded,
                height: 46,
                onTap: widget.controller.text.trim().length < 2
                    ? null
                    : () => _runAction(
                          "direct:${widget.controller.text.trim()}",
                          () => context.read<AppState>().sendFriendRequest(widget.controller.text.trim()),
                          "Friend request sent",
                        ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (showSearch) ...[
                      _sectionTitle("Players", app.friendSearchResults.length),
                      if (app.friendSearchLoading) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      if (!app.friendSearchLoading && app.friendSearchError != null) Padding(padding: const EdgeInsets.all(12), child: Text(app.friendSearchError!, style: const TextStyle(color: Colors.redAccent))),
                      if (!app.friendSearchLoading && app.friendSearchError == null && app.friendSearchResults.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text("No players found. Try a different username.", style: TextStyle(color: Colors.white54))),
                      ...app.friendSearchResults.map((user) => _searchResultTile(app, user)),
                      const Divider(color: Colors.white12, height: 24),
                    ],
                    if (app.friendsLoading && app.friends.isEmpty) const Padding(padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    if (app.friendsError != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(app.friendsError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                    if (incoming.isNotEmpty) ...[
                      _sectionTitle("Incoming requests", incoming.length),
                      ...incoming.map((friend) => _relationshipTile(app, friend)),
                    ],
                    if (outgoing.isNotEmpty) ...[
                      _sectionTitle("Sent requests", outgoing.length),
                      ...outgoing.map((friend) => _relationshipTile(app, friend)),
                    ],
                    _sectionTitle("Friends", accepted.length),
                    if (accepted.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("No friends yet. Search for a username above to send a request.", style: TextStyle(color: Colors.white54, fontSize: 12))),
                    ...accepted.map((friend) => _relationshipTile(app, friend)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Friends Panel — visible in the lobby body (mockup), not only behind a
// small top-bar icon. This is why "friend list add n remove" looked
// broken: the only entry point was a tiny icon, and the sheet it opened
// gave no feedback when a guest's friends lived only in one browser.
// The panel lists accepted friends with a Remove button each, an Add
// button that opens the sheet, and a plain-words guest note.
// ═══════════════════════════════════════════════════════════════════════════════

class _FriendsPanel extends StatelessWidget {
  const _FriendsPanel({
    required this.app,
    required this.onAdd,
    required this.onRemove,
  });

  final AppState app;
  final VoidCallback onAdd;
  final void Function(String friendId, String username) onRemove;

  @override
  Widget build(BuildContext context) {
    final accepted = app.friends.where((f) => f["status"] == "accepted").toList();
    final incoming = app.friends.where((f) => f["status"] == "pending" && f["isRequester"] != true).toList();
    final onlineCount = accepted.where((f) {
      final user = f["user"];
      final id = user is Map ? user["id"]?.toString() ?? "" : "";
      return (user is Map && user["status"] == "online") || app.friendOnlineStatus[id] == true;
    }).length;

    return RoyalPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: ArenaColors.gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Friends',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ArenaColors.emerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$onlineCount Online',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ArenaColors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (incoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${incoming.length} friend request${incoming.length == 1 ? '' : 's'} waiting — tap Add to reply.',
                style: const TextStyle(fontSize: 12, color: ArenaColors.goldSoft, fontWeight: FontWeight.w700),
              ),
            ),
          if (app.isGuest)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'You are playing as a guest. Sign in with Google to keep your friends on every device.',
                style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.35),
              ),
            ),
          if (app.friendsLoading && app.friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ArenaColors.gold))),
            )
          else if (accepted.isEmpty && incoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No friends yet. Add a friend by their username to play together.',
                style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
              ),
            )
          else
            ...accepted.take(4).map((f) {
              final rawUser = f["user"];
              final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : <String, dynamic>{};
              final username = user["username"]?.toString() ?? "Unknown player";
              final id = user["id"]?.toString() ?? "";
              final friendId = f["id"]?.toString() ?? "";
              final online = (user["status"] == "online") || app.friendOnlineStatus[id] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: ArenaColors.gold.withOpacity(0.15),
                          child: Text(
                            username.isEmpty ? "?" : username[0].toUpperCase(),
                            style: const TextStyle(color: ArenaColors.gold, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                        if (online)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: ArenaColors.emerald,
                                shape: BoxShape.circle,
                                border: Border.all(color: ArenaColors.panel, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          Text(
                            online ? 'Online' : 'Offline',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove friend',
                      visualDensity: VisualDensity.compact,
                      onPressed: friendId.isEmpty ? null : () => onRemove(friendId, username),
                      icon: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.white54, size: 18),
                    ),
                  ],
                ),
              );
            }),
          if (accepted.length > 4)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '+ ${accepted.length - 4} more friends',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: RoyalGoldButton(
                  label: 'Add',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: onAdd,
                  height: 44,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RoyalGoldButton(
                  label: 'Remove',
                  icon: Icons.person_remove_alt_1_rounded,
                  onTap: onAdd,
                  primary: false,
                  height: 44,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Glass Container Component
// ═══════════════════════════════════════════════════════════════════════════════

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 14.0,
    this.backgroundColor,
    this.padding,
    this.border,
  });

  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Round gold mode chip (sits on the lobby table rim) ──────────────────
class _ModeChip extends StatefulWidget {
  const _ModeChip({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.diameter,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final double diameter;
  final VoidCallback onTap;

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovering ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: Container(
              width: widget.diameter,
              height: widget.diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.color,
                    widget.color.withOpacity(0.75),
                  ],
                ),
                border: Border.all(color: const Color(0xFF3A2410), width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 14, offset: const Offset(0, 5)),
                  BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 26, color: const Color(0xFF2A1A0A)),
                  const SizedBox(height: 3),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2A1A0A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.sublabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2A1A0A).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

