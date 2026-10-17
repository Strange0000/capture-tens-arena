import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rank_info.dart';
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

    // Auto-navigate to game when match starts
    if (app.match != null) {
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

    return Stack(
      children: [
        // Rich Atmospheric Background
        Positioned.fill(
          child: Image.asset('assets/images/lobby_bg.png', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.2,
                colors: [
                  const Color(0xFF10182E).withOpacity(0.70),
                  const Color(0xFF070B13).withOpacity(0.95),
                ],
              ),
            ),
          ),
        ),

        // Foreground content
        Positioned.fill(
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
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                            const SizedBox(height: 24),

                            // ── Active Matchmaking / Room Banners ────────────
                            if (app.lobbyStatus == LobbyStatus.queuing) ...[
                              _QueueBanner(onCancel: app.leaveMatch),
                              const SizedBox(height: 16),
                            ],

                            if (app.lobbyStatus == LobbyStatus.inRoom && app.roomCode != null) ...[
                              _RoomBanner(
                                code: app.roomCode!,
                                onStartWithBots: () {
                                  app.startRoomWithBots();
                                  Navigator.pushNamed(context, '/game');
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── Dynamic Responsive Body ──────────────────────
                            if (isWide)
                              _buildWideLayout(context, app)
                            else
                              _buildNarrowLayout(context, app),

                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Wide Desktop / Tablet Layout ───────────────────────────────────────────
  Widget _buildWideLayout(BuildContext context, AppState app) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Player Rank Trophy & Party
        SizedBox(
          width: 320,
          child: Column(
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
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Column: 3 Luxury Game Mode Portals
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('SELECT ARENA', 'Choose your game mode to enter the table'),
              const SizedBox(height: 16),
              _buildGamePortals(context, app),
            ],
          ),
        ),
      ],
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
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF48E5C2),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF48E5C2).withOpacity(0.6),
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
    return Column(
      children: [
        // ── Ranked Match Portal ─────────────────────────────────────────────
        _GamePortalCard(
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
        const SizedBox(height: 16),

        // ── Bot Match Portal ────────────────────────────────────────────────
        _GamePortalCard(
          themeColor: const Color(0xFF48E5C2),
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
        const SizedBox(height: 16),

        // ── Private Custom Room Portal ──────────────────────────────────────
        _GamePortalCard(
          themeColor: const Color(0xFFB388FF),
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
      backgroundColor: const Color(0xFF101826),
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
      backgroundColor: const Color(0xFF101826),
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
        backgroundColor: const Color(0xFF101826),
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
            color: Color(0xFF1F222A),
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
                  color: const Color(0xFF48E5C2).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF48E5C2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SEASON 1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF48E5C2),
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
                  iconColor: const Color(0xFF64B5F6),
                  onTap: onRules,
                ),
                _TopIconButton(
                  tooltip: 'Interactive Tutorial',
                  icon: Icons.school_rounded,
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
                  color: const Color(0xFF10192A),
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
                        Icon(Icons.menu_book_rounded, color: Color(0xFF64B5F6), size: 18),
                        SizedBox(width: 10),
                        Text('Rules', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'tutorial',
                      child: Row(children: [
                        Icon(Icons.school_rounded, color: Color(0xFF48E5C2), size: 18),
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
                iconColor: const Color(0xFF48E5C2),
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
                        backgroundColor: const Color(0xFF48E5C2).withOpacity(0.2),
                        child: const Icon(Icons.person, size: 14, color: Color(0xFF48E5C2)),
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
      backgroundColor: const Color(0xFF10182E).withOpacity(0.65),
      border: Border.all(color: tierColor.withOpacity(0.35), width: 1.2),
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
                  color: Colors.white.withOpacity(0.4),
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
                color: Colors.white,
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
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
              Text(
                'Peak: ${rank.peakMmr} MMR',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stats Badge Matrix
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCell(label: 'WINS', value: '${rank.wins}', color: const Color(0xFF48E5C2)),
                Container(width: 1, height: 26, color: Colors.white10),
                _StatCell(label: 'LOSSES', value: '${rank.losses}', color: Colors.redAccent),
                Container(width: 1, height: 26, color: Colors.white10),
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
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    foregroundColor: Colors.white70,
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
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    foregroundColor: Colors.white70,
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
            color: Colors.white.withOpacity(0.35),
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
  });

  final Color themeColor;
  final String badgeTag;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> perks;
  final String ctaText;
  final VoidCallback onTap;

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
                const Color(0xFF0F172A).withOpacity(0.85),
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
                      color: _isHovered ? widget.themeColor : widget.themeColor.withOpacity(0.18),
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
                            color: _isHovered ? const Color(0xFF070B13) : widget.themeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: _isHovered ? const Color(0xFF070B13) : widget.themeColor,
                        ),
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
      border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF48E5C2),
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
                    color: Color(0xFF48E5C2),
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
  const _RoomBanner({required this.code, required this.onStartWithBots});
  final String code;
  final VoidCallback onStartWithBots;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 520;

    return GlassPanel(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      backgroundColor: const Color(0xFF26193E).withOpacity(0.65),
      border: Border.all(color: const Color(0xFFB388FF).withOpacity(0.5)),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB388FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.meeting_room_rounded, color: Color(0xFFB388FF), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CUSTOM ROOM CODE',
                            style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            code,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Color(0xFFB388FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF30B89C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onStartWithBots,
                  icon: const Icon(Icons.smart_toy, size: 18),
                  label: const Text('Start with Bots', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB388FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.meeting_room_rounded, color: Color(0xFFB388FF), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CUSTOM ROOM CODE',
                        style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: Color(0xFFB388FF),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF30B89C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onStartWithBots,
                  icon: const Icon(Icons.smart_toy, size: 18),
                  label: const Text('Start with Bots', style: TextStyle(fontWeight: FontWeight.bold)),
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
      border: Border.all(color: const Color(0xFFB388FF).withOpacity(0.3)),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
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
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
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
      backgroundColor: const Color(0xFF7C4DFF).withOpacity(0.15),
      border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group, color: Color(0xFF7C4DFF), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your Party',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C4DFF),
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

class _FriendsSheet extends StatelessWidget {
  const _FriendsSheet({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const Text(
                'Friends',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 16),
              // Add friend
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Add by username',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final u = controller.text.trim();
                      if (u.isNotEmpty) {
                        app.sendFriendRequest(u);
                        controller.clear();
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Friend list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: app.friends.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (context, i) {
                    final f = app.friends[i];
                    final user = f['user'];
                    final status = f['status'];
                    final isReq = f['isRequester'];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF48E5C2).withOpacity(0.2),
                        child: Text(
                          user['username'].toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Color(0xFF48E5C2)),
                        ),
                      ),
                      title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(status, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status == 'pending' && !isReq)
                            TextButton(
                              onPressed: () => app.acceptFriendRequest(f['id']),
                              child: const Text('Accept'),
                            ),
                          if (status == 'accepted')
                            IconButton(
                              tooltip: 'Invite to Party',
                              icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF7C4DFF)),
                              onPressed: () {
                                app.inviteToParty(user['id']);
                                Navigator.pop(context);
                              },
                            ),
                        ],
                      ),
                    );
                  },
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
