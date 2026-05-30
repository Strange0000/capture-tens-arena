import 'package:flutter/material.dart';

class ReplayScreen extends StatelessWidget {
  const ReplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const entries = [
      _ReplayEntry(title: 'Bot Match — Hard', subtitle: 'Spades power · Team A won · 13 tricks', duration: '4m 12s', won: true),
      _ReplayEntry(title: 'Ranked Match', subtitle: 'Hearts power · Team B won · 13 tricks', duration: '6m 08s', won: false),
      _ReplayEntry(title: 'Bot Match — Medium', subtitle: 'Clubs power · Team A won · 13 tricks', duration: '5m 30s', won: true),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Replays',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset('assets/images/replay_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: const Color(0xFF070B13).withOpacity(0.75)),
          ),

          SafeArea(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Icon(Icons.history_toggle_off, size: 52, color: Color(0xFF48E5C2)),
                        ),
                        const SizedBox(height: 20),
                        const Text('No replays yet', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text('Finish a match to see it here', style: TextStyle(color: Colors.white30, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ReplayTile(entry: entries[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReplayEntry {
  const _ReplayEntry({required this.title, required this.subtitle, required this.duration, required this.won});
  final String title;
  final String subtitle;
  final String duration;
  final bool won;
}

class _ReplayTile extends StatefulWidget {
  const _ReplayTile({required this.entry});
  final _ReplayEntry entry;

  @override
  State<_ReplayTile> createState() => _ReplayTileState();
}

class _ReplayTileState extends State<_ReplayTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final winColor = widget.entry.won ? const Color(0xFF48E5C2) : Colors.redAccent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? winColor.withOpacity(0.4) : Colors.white.withOpacity(0.08),
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: winColor.withOpacity(0.1), blurRadius: 16)]
              : [],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: winColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: winColor.withOpacity(0.3)),
            ),
            child: Icon(
              widget.entry.won ? Icons.emoji_events_rounded : Icons.replay_rounded,
              color: winColor,
              size: 22,
            ),
          ),
          title: Text(
            widget.entry.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: winColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.entry.won ? 'WIN' : 'LOSS',
                    style: TextStyle(color: winColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.entry.subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF48E5C2), size: 22),
              const SizedBox(height: 4),
              Text(widget.entry.duration, style: const TextStyle(color: Colors.white30, fontSize: 11)),
            ],
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Replay playback coming soon'),
                backgroundColor: const Color(0xFF101826),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
      ),
    );
  }
}
