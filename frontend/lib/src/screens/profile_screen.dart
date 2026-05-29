import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rank_info.dart';
import '../state/app_state.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final match = app.match;
    final captures = match?.captures;
    final rank = app.rankInfo ?? RankInfo.fromMmr(0);
    final tierColor = rank.color;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar with tier glow
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [tierColor, tierColor.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: tierColor.withOpacity(0.4), blurRadius: 24, spreadRadius: 4)],
              ),
              child: Center(
                child: Text(
                  (app.username ?? 'G')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF070B13)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            app.username ?? 'Guest Player',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),

          // Rank badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tierColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(rank.icon, height: 24, width: 24),
                  const SizedBox(width: 6),
                  Text(
                    '${rank.displayName}  ·  ${rank.mmr} MMR',
                    style: TextStyle(color: tierColor, fontSize: 13, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 20),

          // MMR progress bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101826),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(rank.displayName, style: TextStyle(color: tierColor, fontWeight: FontWeight.w700, fontSize: 12)),
                    Text('${rank.nextTierMmr} MMR', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rank.progressInTier.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Current match captures (live if in match)
          if (captures != null) ...[
            const _SectionHeader('Live Match'),
            _StatTile(label: 'Tens Captured (A)', value: '${captures.a.tens}', accent: true),
            _StatTile(label: 'Tens Captured (B)', value: '${captures.b.tens}', accent: true),
            _StatTile(label: 'Cards (A / B)', value: '${captures.a.cards} / ${captures.b.cards}'),
            const SizedBox(height: 20),
          ],

          // Overall stats
          const _SectionHeader('Season Stats'),
          _StatTile(label: 'Win Rate', value: rank.winRate, accent: true),
          _StatTile(label: 'Wins', value: '${rank.wins}'),
          _StatTile(label: 'Losses', value: '${rank.losses}'),
          _StatTile(label: 'Peak MMR', value: '${rank.peakMmr}', accent: true),
          const SizedBox(height: 28),

          // Suit stat icons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['♥', '♦', '♣', '♠'].asMap().entries.map((e) {
              final isRed = e.key < 2;
              return Column(
                children: [
                  Text(e.value, style: TextStyle(fontSize: 32, color: isRed ? const Color(0xFFE53935) : Colors.white70)),
                  const SizedBox(height: 4),
                  Text('0', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const Text('tens', style: TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              );
            }).toList(),
          ),

          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              await app.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: accent ? const Color(0xFFFFC857) : Colors.white,
        ),
      ),
    );
  }
}
