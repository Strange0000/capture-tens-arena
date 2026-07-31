import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rank_info.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
    final captures = match?.captures;
    final rank = app.rankInfo ?? RankInfo.fromMmr(0);
    final stats = app.statistics ?? {};
    final tierColor = rank.color;

    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      body: Stack(
        children: [
          // Full page background
          Positioned.fill(
            child: Image.asset(
              'assets/images/profile_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark overlay for readability
          Positioned.fill(
            child: Container(color: const Color(0xFF070B13).withOpacity(0.65)),
          ),

          // Scrollable content
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // ── Profile Banner + Avatar ───────────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Banner image
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage('assets/images/profile_banner.png'),
                          fit: BoxFit.cover,
                        ),
                        border: Border(
                          bottom: BorderSide(color: tierColor.withOpacity(0.6), width: 2),
                        ),
                      ),
                    ),
                    // Avatar circle positioned over the banner bottom edge
                    Positioned(
                      bottom: -50,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [tierColor, tierColor.withOpacity(0.4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: const Color(0xFF070B13), width: 4),
                          boxShadow: [
                            BoxShadow(color: tierColor.withOpacity(0.5), blurRadius: 28, spreadRadius: 4),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (app.username ?? 'G')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF070B13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 62),

                // ── Username & Rank ───────────────────────────────────────
                Text(
                  app.username ?? 'Guest Player',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 8),

                // Rank badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: tierColor.withOpacity(0.5)),
                      boxShadow: [BoxShadow(color: tierColor.withOpacity(0.2), blurRadius: 12)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(rank.icon, height: 22, width: 22),
                        const SizedBox(width: 8),
                        Text(
                          '${rank.displayName}  ·  ${rank.mmr} MMR',
                          style: TextStyle(color: tierColor, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Season ${rank.seasonDisplay}  ·  Peak ${rank.peakMmr} MMR',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                ),

                const SizedBox(height: 24),

                // ── MMR Progress Bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(rank.displayName,
                                style: TextStyle(color: tierColor, fontWeight: FontWeight.w800, fontSize: 12)),
                            Text('Next: ${rank.nextTierMmr} MMR',
                                style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: rank.progressInTier.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Stats Grid ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader('Season Stats'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _StatCard(label: 'Wins', value: '${rank.wins}', icon: Icons.emoji_events, color: const Color(0xFFFFC857))),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'Losses', value: '${rank.losses}', icon: Icons.close, color: Colors.redAccent)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'Win Rate', value: rank.winRate, icon: Icons.percent, color: const Color(0xFF48E5C2))),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Career Statistics ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader('Career Stats'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _StatRow('Total Matches', '${stats['matches'] ?? 0}'),
                        const Divider(color: Colors.white10, height: 24),
                        _StatRow('Tens Captured', '${stats['tensCaptured'] ?? 0}'),
                        const Divider(color: Colors.white10, height: 24),
                        _StatRow('Aces Captured', '${stats['acesCaptured'] ?? 0}'),
                        const Divider(color: Colors.white10, height: 24),
                        _StatRow('Current Win Streak', '${stats['currentWinStreak'] ?? 0}', accent: true),
                        const Divider(color: Colors.white10, height: 24),
                        _StatRow('Best Win Streak', '${stats['bestWinStreak'] ?? 0}', accent: true),
                      ],
                    ),
                  ),
                ),

                // ── Live match if in game ─────────────────────────────────
                if (captures != null) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader('Live Match'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF48E5C2).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          _StatRow('Tens (Team A)', '${captures.a.tens}', accent: true),
                          _StatRow('Tens (Team B)', '${captures.b.tens}', accent: true),
                          _StatRow('Cards (A / B)', '${captures.a.cards} / ${captures.b.cards}'),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Sign out ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await app.logout();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 2.5,
          color: Colors.white38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SuitCapture extends StatelessWidget {
  const _SuitCapture({required this.symbol, required this.label, required this.color});
  final String symbol;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(symbol, style: TextStyle(fontSize: 34, color: color)),
        const SizedBox(height: 6),
        const Text('0', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, {this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: accent ? const Color(0xFF48E5C2) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
