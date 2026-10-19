import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  bool _loading = true;
  String? _error;
  List<_ReplayEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReplays());
  }

  Future<void> _loadReplays() async {
    final app = context.read<AppState>();
    final token = app.token;
    if (token == null) {
      if (mounted) setState(() { _loading = false; _error = 'Sign in to view your match history.'; });
      return;
    }
    try {
      final results = await app.auth.fetchReplays(token);
      if (!mounted) return;
      setState(() {
        _entries = results.map(_ReplayEntry.fromJson).toList(growable: false);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your replays. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Replays', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () {
              setState(() { _loading = true; _error = null; });
              _loadReplays();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/replay_bg.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: const Color(0xFF070B13).withOpacity(0.75))),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF48E5C2)))
                : _error != null
                    ? _MessagePanel(
                        title: 'Replays unavailable',
                        message: _error!,
                        icon: Icons.cloud_off_rounded,
                        onRetry: () {
                          setState(() { _loading = true; _error = null; });
                          _loadReplays();
                        },
                      )
                    : _entries.isEmpty
                        ? const _MessagePanel(
                            title: 'No replays yet',
                            message: 'Finish a match to see your real match history here.',
                            icon: Icons.history_toggle_off,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _ReplayTile(
                              entry: _entries[index],
                              onTap: () => _showTimeline(context, _entries[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showTimeline(BuildContext context, _ReplayEntry entry) {
    final timeline = entry.timeline;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101826),
        title: Text('${entry.title} · Timeline', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 520,
          height: MediaQuery.of(context).size.height * 0.6,
          child: timeline.isEmpty
              ? const Center(child: Text('No move events were saved for this match.', style: TextStyle(color: Colors.white60)))
              : ListView.separated(
                  itemCount: timeline.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 12),
                  itemBuilder: (context, index) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text('${index + 1}.', style: const TextStyle(color: Color(0xFF48E5C2), fontWeight: FontWeight.w800)),
                      ),
                      Expanded(child: Text(timeline[index], style: const TextStyle(color: Colors.white70, height: 1.35))),
                    ],
                  ),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.title, required this.message, required this.icon, this.onRetry});
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: const Color(0xFF48E5C2)),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      );
}

class _ReplayEntry {
  const _ReplayEntry({
    required this.matchId,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.won,
    required this.events,
    required this.playerNames,
  });

  final String matchId;
  final String title;
  final String subtitle;
  final String duration;
  final bool won;
  final List<Map<String, dynamic>> events;
  final Map<int, String> playerNames;

  factory _ReplayEntry.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
    final names = <int, String>{};
    for (final player in players) {
      final seat = (player['seat'] as num?)?.toInt();
      if (seat != null) names[seat] = player['username'] as String? ?? 'Player';
    }
    final events = (json['events'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);

    final mode = json['mode'] as String? ?? 'casual';
    final title = switch (mode) {
      'ranked' => 'Ranked Match',
      'private' => 'Private Room Match',
      'offline' => 'Bot Practice',
      _ => 'Casual Match',
    };
    final power = json['powerSuit'] as String?;
    final winner = json['winnerTeam'] as String? ?? '?';
    final tricks = (json['tricks'] as num?)?.toInt() ?? 0;
    final durationMs = (json['durationMs'] as num?)?.toInt() ?? 0;
    final minutes = durationMs ~/ 60000;
    final seconds = (durationMs % 60000) ~/ 1000;
    final powerLabel = power == null ? 'Power suit unknown' : '${power[0].toUpperCase()}${power.substring(1)} power';

    return _ReplayEntry(
      matchId: json['matchId'] as String? ?? '',
      title: title,
      subtitle: '$powerLabel · Team $winner won · $tricks tricks',
      duration: '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
      won: json['won'] as bool? ?? false,
      events: events,
      playerNames: names,
    );
  }

  List<String> get timeline {
    final lines = <String>[];
    for (final event in events) {
      final type = event['type'] as String? ?? '';
      final payload = event['payload'] is Map
          ? Map<String, dynamic>.from(event['payload'] as Map)
          : <String, dynamic>{};
      if (type == 'power.selected') {
        final seat = (payload['seat'] as num?)?.toInt();
        lines.add('${seat == null ? 'A player' : playerNames[seat] ?? 'Player'} selected ${payload['suit'] ?? 'unknown'} as the power suit.');
      } else if (type == 'card.played') {
        final seat = (payload['seat'] as num?)?.toInt();
        final card = payload['card'] is Map ? Map<String, dynamic>.from(payload['card'] as Map) : <String, dynamic>{};
        lines.add('${playerNames[seat] ?? 'Player'} played ${card['rank'] ?? '?'} of ${card['suit'] ?? 'unknown suit'}.');
      } else if (type == 'trick.completed') {
        final trick = payload['trick'] is Map ? Map<String, dynamic>.from(payload['trick'] as Map) : <String, dynamic>{};
        final seat = (trick['winnerSeat'] as num?)?.toInt();
        final trickNumber = lines.where((line) => line.startsWith('Trick ')).length + 1;
        lines.add('Trick $trickNumber won by ${playerNames[seat] ?? 'a player'}.');
      } else if (type == 'match.completed') {
        lines.add('Match completed. Team ${payload['winnerTeam'] ?? '?'} won.');
      }
    }
    return lines;
  }
}

class _ReplayTile extends StatefulWidget {
  const _ReplayTile({required this.entry, required this.onTap});
  final _ReplayEntry entry;
  final VoidCallback onTap;

  @override
  State<_ReplayTile> createState() => _ReplayTileState();
}

class _ReplayTileState extends State<_ReplayTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.entry.won ? const Color(0xFF48E5C2) : Colors.redAccent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovered ? color.withOpacity(0.4) : Colors.white.withOpacity(0.08)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Icon(widget.entry.won ? Icons.emoji_events_rounded : Icons.replay_rounded, color: color, size: 26),
          title: Text(widget.entry.title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('${widget.entry.won ? 'WIN' : 'LOSS'} · ${widget.entry.subtitle}', style: TextStyle(color: color.withOpacity(0.85), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.list_alt_rounded, color: Color(0xFF48E5C2), size: 22),
              const SizedBox(height: 4),
              Text(widget.entry.duration, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
