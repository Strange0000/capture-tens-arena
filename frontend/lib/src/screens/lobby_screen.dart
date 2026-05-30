import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rank_info.dart';
import '../state/app_state.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  final _roomCodeController = TextEditingController();
  final _friendUsernameController = TextEditingController();
  bool _showRoomPanel = false;
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _friendUsernameController.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // Auto-navigate to game when match starts
    if (app.match != null && app.lobbyStatus == LobbyStatus.inMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pushNamed(context, '/game');
        }
      });
    }

    // Show errors
    if (app.errorMessage != null) {
      final msg = app.errorMessage!;
      app.clearError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
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
        Positioned.fill(
          child: Image.asset('assets/images/lobby_bg.png', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF070B13).withOpacity(0.60),
                  const Color(0xFF070B13).withOpacity(0.85),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
            child: FadeTransition(
          opacity: _entryAnim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(_entryAnim),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  // ── Header ────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Image.asset(
                            'assets/images/lobby_hero_logo.png',
                            height: 64,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Rules button
                      IconButton.filledTonal(
                        tooltip: 'How to Play',
                        onPressed: () => _showRulesSheet(context),
                        icon: const Icon(Icons.menu_book_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Friends',
                        onPressed: () => _showFriendsSheet(context),
                        icon: const Icon(Icons.people_alt),
                      ),
                      const SizedBox(width: 4),
                      // Profile button
                      IconButton.filledTonal(
                        tooltip: 'Profile',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/profile'),
                        icon: const Icon(Icons.person),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Rank panel ────────────────────────────────────────
                  _RankPanel(username: app.username, rankInfo: app.rankInfo),
                  const SizedBox(height: 16),

                  if (app.party != null) ...[
                    _PartyBanner(party: app.party!, onLeave: app.leaveParty),
                    const SizedBox(height: 16),
                  ],



                  const Spacer(),

                  // ── Queue / Room status ───────────────────────────────
                  if (app.lobbyStatus == LobbyStatus.queuing) ...[
                    _QueueBanner(onCancel: app.leaveMatch),
                    const SizedBox(height: 12),
                  ],

                  if (app.lobbyStatus == LobbyStatus.inRoom &&
                      app.roomCode != null) ...[
                    _RoomBanner(code: app.roomCode!),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30B89C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        app.startRoomWithBots();
                        Navigator.pushNamed(context, '/matchmaking');
                      },
                      icon: const Icon(Icons.smart_toy, size: 20),
                      label: const Text('Start with Bots', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Main actions ──────────────────────────────────────
                  if (app.lobbyStatus == LobbyStatus.idle) ...[
                    // Ranked Match
                    _ActionCard(
                      icon: Icons.military_tech,
                      iconColor: const Color(0xFFFFC857),
                      title: 'Ranked Match',
                      subtitle: 'Climb the leaderboard',
                      onTap: () {
                        app.queueRanked();
                        Navigator.pushNamed(context, '/matchmaking');
                      },
                    ),
                    const SizedBox(height: 10),

                    // Bot Match
                    _ActionCard(
                      icon: Icons.smart_toy,
                      iconColor: const Color(0xFF48E5C2),
                      title: 'Bot Match',
                      subtitle: 'Practice against AI',
                      onTap: () {
                        app.startOffline('hard');
                        if (context.mounted) {
                          Navigator.pushNamed(context, '/game');
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Private Room
                    _ActionCard(
                      icon: _showRoomPanel
                          ? Icons.expand_less
                          : Icons.group_add,
                      iconColor: Colors.white70,
                      title: 'Private Room',
                      subtitle: 'Play with friends',
                      onTap: () =>
                          setState(() => _showRoomPanel = !_showRoomPanel),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: _showRoomPanel
                          ? _PrivateRoomPanel(
                              controller: _roomCodeController,
                              onCreate: () => app.createRoom(),
                              onJoin: () {
                                final code =
                                    _roomCodeController.text.trim();
                                if (code.isEmpty) return;
                                app.joinRoom(code);
                              },
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/replay'),
                          icon: const Icon(Icons.history, size: 20),
                          label: const Text('Replays'),
                        ),
                        const SizedBox(width: 24),
                        TextButton.icon(
                          onPressed: () => _showTiersSheet(context),
                          icon: const Icon(Icons.leaderboard, size: 20),
                          label: const Text('Rank Tiers'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),          // closes SafeArea(
          ),  // closes Scaffold body:
        ),    // closes Scaffold(
      ),      // closes Positioned.fill(
    ],        // closes Stack children: [
    );        // closes Stack(
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
    app.pendingPartyInvite = null; // clear it immediately so it doesn't loop
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
              // we temporarily store it back to accept
              app.pendingPartyInvite = invite;
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
              const Text('Competitive Tiers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Win: +25 RP  |  Loss: -15 RP', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
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
                      trailing: Text('${tier.min} RP', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
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
              // Drag handle
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

              // Title
              const Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      color: Color(0xFFFFC857), size: 28),
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
                body: 'Before the game begins, the dealer\'s partner chooses a Power Suit. '
                    'Cards of the power suit beat all other suits, regardless of rank. '
                    'Think of it as the ultimate trump card!',
              ),

              _RuleSection(
                icon: '🃏',
                title: 'Playing a Trick',
                body: '• The leader plays any card to start a trick\n'
                    '• Other players must follow the lead suit if they can\n'
                    '• If you can\'t follow suit, you may play any card\n'
                    '• The highest card of the lead suit wins (unless trumped by power suit)',
              ),

              _RuleSection(
                icon: '⬆️',
                title: 'Must Play Higher',
                body: 'If you follow the lead suit, you must play a higher card than the current highest '
                    '— unless your teammate (partner) is already winning the trick. '
                    'In that case, you can play low to save your strong cards!',
              ),

              _RuleSection(
                icon: '🛡️',
                title: '10s Protection',
                body: 'You cannot discard an off-suit 10 unless you have 3 or fewer cards remaining. '
                    'This protects your valuable 10s from being wasted early!',
              ),

              _RuleSection(
                icon: '1️⃣',
                title: 'First Trick Rule',
                body: 'On the very first trick, you cannot play 10s or power suit cards '
                    'unless your entire hand consists of those cards.',
              ),

              _RuleSection(
                icon: '👑',
                title: 'Card Hierarchy',
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

              // Close button
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
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFC857),
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
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Supporting widgets (ported from old home_screen.dart)
// ═══════════════════════════════════════════════════════════════════════════════

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white24, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankPanel extends StatelessWidget {
  const _RankPanel({this.username, this.rankInfo});
  final String? username;
  final RankInfo? rankInfo;
  @override
  Widget build(BuildContext context) {
    final rank = rankInfo ?? RankInfo.fromMmr(0);
    final tierColor = rank.color;

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      backgroundColor: Colors.black.withOpacity(0.3),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [tierColor, tierColor.withOpacity(0.5)],
                  ),
                  boxShadow: [BoxShadow(color: tierColor.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Center(
                  child: Image.asset(rank.icon, height: 28, width: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username ?? 'Guest',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    Text(
                      '${rank.displayName}  ·  ${rank.mmr} MMR',
                      style: TextStyle(color: tierColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rank.seasonDisplay,
                  style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // MMR progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rank.progressInTier.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('W: ${rank.wins}  L: ${rank.losses}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
              Text('Peak: ${rank.peakMmr} MMR', style: const TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueueBanner extends StatelessWidget {
  const _QueueBanner({required this.onCancel});
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      backgroundColor: const Color(0xFF1B5E20).withOpacity(0.4),
      border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF48E5C2),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Searching for players…',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF48E5C2),
              ),
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _RoomBanner extends StatelessWidget {
  const _RoomBanner({required this.code});
  final String code;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFC857).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.meeting_room, color: Color(0xFFFFC857), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share this code with friends',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Color(0xFFFFC857),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFFC857),
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
    return GlassPanel(
      backgroundColor: const Color(0xFF101826).withOpacity(0.5),
      border: Border.all(color: Colors.white12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create New Room'),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Divider(color: Colors.white12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'or join',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: Colors.white12)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'Enter room code',
              counterText: '',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: const TextStyle(
              letterSpacing: 4,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.login),
            label: const Text('Join Room'),
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
      padding: const EdgeInsets.all(12),
      backgroundColor: const Color(0xFF7C4DFF).withOpacity(0.15),
      border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.5)),
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
