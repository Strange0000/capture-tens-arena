import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomCodeController = TextEditingController();
  bool _showRoomPanel = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.match != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && ModalRoute.of(context)?.settings.name == '/') {
          Navigator.pushNamed(context, '/game');
        }
      });
    }

    if (app.errorMessage != null) {
      final msg = app.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
        app.clearError();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Capture Tens', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
                        Text('Arena', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF48E5C2), height: 1)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Profile',
                    onPressed: () => Navigator.pushNamed(context, '/profile'),
                    icon: const Icon(Icons.person),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Rank panel
              _RankPanel(username: app.username),
              const SizedBox(height: 16),

              // Suit strip decoration
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['♥', '♦', '♣', '♠'].asMap().entries.map((e) {
                  final isRed = e.key < 2;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(e.value, style: TextStyle(fontSize: 28, color: (isRed ? const Color(0xFFE53935) : Colors.white).withOpacity(0.25))),
                  );
                }).toList(),
              ),

              const Spacer(),

              // Queue status
              if (app.lobbyStatus == LobbyStatus.queuing) ...[
                _QueueBanner(onCancel: app.leaveMatch),
                const SizedBox(height: 12),
              ],

              // Room code display
              if (app.lobbyStatus == LobbyStatus.inRoom && app.roomCode != null) ...[
                _RoomBanner(code: app.roomCode!),
                const SizedBox(height: 12),
              ],

              // Main action buttons
              if (app.lobbyStatus == LobbyStatus.idle) ...[
                ElevatedButton.icon(
                  onPressed: () async { await app.bootGuest(); app.queueRanked(); },
                  icon: const Icon(Icons.military_tech),
                  label: const Text('Ranked Match'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await app.bootGuest();
                    app.startOffline('hard');
                    if (context.mounted) Navigator.pushNamed(context, '/game');
                  },
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('Hard Bot Match'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showRoomPanel = !_showRoomPanel),
                  icon: Icon(_showRoomPanel ? Icons.expand_less : Icons.group_add),
                  label: const Text('Private Room'),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  child: _showRoomPanel
                      ? _PrivateRoomPanel(
                          controller: _roomCodeController,
                          onCreate: () async { await app.bootGuest(); app.createRoom(); },
                          onJoin: () async {
                            final code = _roomCodeController.text.trim();
                            if (code.isEmpty) return;
                            await app.bootGuest();
                            app.joinRoom(code);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/replay'),
                  icon: const Icon(Icons.history),
                  label: const Text('Replays'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RankPanel extends StatelessWidget {
  const _RankPanel({this.username});
  final String? username;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF101826), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
      child: Row(
        children: [
          const Icon(Icons.diamond, color: Color(0xFFFFC857), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const Text('Iron III  ·  0 MMR', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const Text('Season Q2', style: TextStyle(color: Colors.white38, fontSize: 12)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF48E5C2).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.3))),
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF48E5C2))),
          const SizedBox(width: 12),
          const Expanded(child: Text('Searching for players…', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF48E5C2)))),
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
      decoration: BoxDecoration(color: const Color(0xFFFFC857).withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.meeting_room, color: Color(0xFFFFC857), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share this code with friends', style: TextStyle(fontSize: 12, color: Colors.white54)),
                Text(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFFFFC857))),
              ],
            ),
          ),
          const Text('Waiting…', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PrivateRoomPanel extends StatelessWidget {
  const _PrivateRoomPanel({required this.controller, required this.onCreate, required this.onJoin});
  final TextEditingController controller;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF101826), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create New Room')),
          const SizedBox(height: 12),
          const Row(children: [
            Expanded(child: Divider(color: Colors.white12)),
            Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or join', style: TextStyle(color: Colors.white38, fontSize: 12))),
            Expanded(child: Divider(color: Colors.white12)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(hintText: 'Enter room code', counterText: '', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: onJoin, icon: const Icon(Icons.login), label: const Text('Join Room')),
        ],
      ),
    );
  }
}
