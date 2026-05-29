import 'package:flutter/material.dart';

class ReplayScreen extends StatelessWidget {
  const ReplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder entries — will be populated from the /admin/replays API
    // once the user is authenticated with an account that has match history.
    const entries = [
      _ReplayEntry(title: 'Bot Match — Hard', subtitle: 'Spades power · Team A won · 13 tricks', duration: '4m 12s'),
      _ReplayEntry(title: 'Ranked Match', subtitle: 'Hearts power · Team B won · 13 tricks', duration: '6m 08s'),
      _ReplayEntry(title: 'Bot Match — Medium', subtitle: 'Clubs power · Team A won · 13 tricks', duration: '5m 30s'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Replays')),
      body: entries.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off, size: 56, color: Colors.white12),
                  SizedBox(height: 12),
                  Text('No replays yet', style: TextStyle(color: Colors.white38)),
                  SizedBox(height: 4),
                  Text('Finish a match to see it here', style: TextStyle(color: Colors.white24, fontSize: 12)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final e = entries[index];
                return _ReplayTile(entry: e);
              },
            ),
    );
  }
}

class _ReplayEntry {
  const _ReplayEntry({
    required this.title,
    required this.subtitle,
    required this.duration,
  });

  final String title;
  final String subtitle;
  final String duration;
}

class _ReplayTile extends StatelessWidget {
  const _ReplayTile({required this.entry});

  final _ReplayEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF48E5C2).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_circle_outline, color: Color(0xFF48E5C2)),
        ),
        title: Text(
          entry.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            entry.subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            Text(
              entry.duration,
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Replay playback coming soon')),
          );
        },
      ),
    );
  }
}
