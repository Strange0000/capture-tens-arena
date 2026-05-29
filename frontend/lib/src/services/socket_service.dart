import 'package:socket_io_client/socket_io_client.dart' as io;

typedef StateCallback = void Function(Map<String, dynamic> json);
typedef VoidJsonCallback = void Function(Map<String, dynamic> json);

class SocketService {
  io.Socket? _socket;

  bool get connected => _socket?.connected ?? false;

  void connect({
    required String token,
    required String baseUrl,
    required StateCallback onMatchState,
    required VoidJsonCallback onMatchCreated,
    required VoidJsonCallback onQueueJoined,
    required VoidJsonCallback onRoomCreated,
    required VoidJsonCallback onRoomJoined,
    required VoidJsonCallback onPartyUpdated,
    required VoidJsonCallback onPartyInvited,
    required VoidJsonCallback onRankUpdated,
    required VoidJsonCallback onFriendStatus,
    required void Function(String msg) onError,
  }) {
    _socket?.dispose();
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setExtraHeaders({
            'Bypass-Tunnel-Reminder': 'true',
            'ngrok-skip-browser-warning': 'true',
          })
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );

    _socket!
      ..on('connect', (_) => print('[Socket] Connected to $baseUrl'))
      ..on('connect_error', (err) => print('[Socket] Connection error: $err'))
      ..on('disconnect', (reason) => print('[Socket] Disconnected: $reason'))
      ..on('match:state', (data) => onMatchState(_asMap(data)))
      ..on('match:created', (data) => onMatchCreated(_asMap(data)))
      ..on('queue:joined', (data) => onQueueJoined(_asMap(data)))
      ..on('room:created', (data) => onRoomCreated(_asMap(data)))
      ..on('room:joined', (data) => onRoomJoined(_asMap(data)))
      ..on('party:updated', (data) => onPartyUpdated(_asMap(data)))
      ..on('party:invited', (data) => onPartyInvited(_asMap(data)))
      ..on('rank:updated', (data) => onRankUpdated(_asMap(data)))
      ..on('friend:status', (data) => onFriendStatus(_asMap(data)))
      ..on('error', (data) {
        final msg = data is Map ? (data['message'] ?? 'Socket error') : data.toString();
        onError(msg as String);
      });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  // ── Game actions ──────────────────────────────────────────────────────────

  void queueRanked({int mmr = 0}) =>
      _emit('queue:ranked', {'mmr': mmr});

  void startOffline(String difficulty) =>
      _emit('bot:offline', {'difficulty': difficulty});

  void leaveMatch() => _emit('match:leave', {});

  void createRoom() => _emit('room:create', {});

  void joinRoom(String code) => _emit('room:join', {'code': code.toUpperCase()});

  void inviteToParty(String targetUserId) => _emit('party:invite', {'targetUserId': targetUserId});
  
  void acceptPartyInvite(String partyId) => _emit('party:accept', {'partyId': partyId});

  void leaveParty() => _emit('party:leave', {});

  void selectPower(String matchId, String suit) =>
      _emit('power:select', {'matchId': matchId, 'suit': suit});

  void playCard(String matchId, String cardId) =>
      _emit('card:play', {'matchId': matchId, 'cardId': cardId});

  void requestFriendStatuses() => _emit('friends:status', {});

  // ── Internals ─────────────────────────────────────────────────────────────

  void _emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}
