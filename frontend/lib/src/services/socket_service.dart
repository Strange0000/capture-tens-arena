import 'package:socket_io_client/socket_io_client.dart' as io;

typedef StateCallback = void Function(Map<String, dynamic> json);
typedef VoidJsonCallback = void Function(Map<String, dynamic> json);

class SocketService {
  io.Socket? _socket;
  String? _connectedToken;
  String? _connectedBaseUrl;
  final List<_PendingEmit> _pendingEmits = [];

  bool get connected => _socket?.connected ?? false;

  void connect({
    required String token,
    required String baseUrl,
    required StateCallback onMatchState,
    required VoidJsonCallback onMatchCreated,
    required VoidJsonCallback onQueueJoined,
    required VoidJsonCallback onQueueCancelled,
    required VoidJsonCallback onRoomCreated,
    required VoidJsonCallback onRoomJoined,
    required VoidJsonCallback onRoomUpdated,
    required VoidJsonCallback onRoomInvited,
    required void Function() onRoomLeft,
    required VoidJsonCallback onPartyUpdated,
    required VoidJsonCallback onPartyInvited,
    required VoidJsonCallback onRankUpdated,
    required VoidJsonCallback onFriendStatus,
    required VoidJsonCallback onFriendsChanged,
    required VoidJsonCallback onFriendsStatusList,
    required VoidJsonCallback onPartyInviteSent,
    required VoidJsonCallback onPartyDeclined,
    required VoidJsonCallback onEmoteReceived,
    required VoidJsonCallback onAchievementUnlocked,
    required VoidJsonCallback onPlayerBotReplaced,
    VoidJsonCallback? onMatchAnnouncement,
    required void Function(String msg) onError,
    void Function()? onConnected,
  }) {
    // Avoid tearing down and re-opening the socket when already connected
    // with the exact same credentials — a redundant reconnect fires an
    // asynchronous disconnect on the old socket that would falsely mark
    // the user offline on the server.
    if (_socket != null && _socket!.connected && _connectedToken == token && _connectedBaseUrl == baseUrl) {
      print('[Socket] Already connected with same token to $baseUrl, reusing connection');
      return;
    }

    _connectedToken = token;
    _connectedBaseUrl = baseUrl;
    _socket?.disconnect();
    _socket?.dispose();
    _pendingEmits.clear();
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({})
          .setAuth({'token': token})
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!
      ..on('connect', (_) {
        print('[Socket] Connected to $baseUrl');
        // Replay any events that were emitted before connection was ready
        if (_pendingEmits.isNotEmpty) {
          print('[Socket] Replaying ${_pendingEmits.length} pending events');
          for (final pending in _pendingEmits) {
            _socket!.emit(pending.event, pending.data);
          }
          _pendingEmits.clear();
        }
        // PR-B (F5): a (re)connect is a fresh chance to pull friend
        // state the client may have missed while offline.
        onConnected?.call();
      })
      ..on('connect_error', (err) {
        print('[Socket] Connection error to $baseUrl: $err');
        onError(err.toString());
      })
      ..on('disconnect', (reason) => print('[Socket] Disconnected: $reason'))
      ..on('match:state', (data) {
        print('[Socket] Received match:state');
        onMatchState(_asMap(data));
      })
      ..on('match:created', (data) {
        print('[Socket] Received match:created');
        onMatchCreated(_asMap(data));
      })
      ..on('queue:joined', (data) => onQueueJoined(_asMap(data)))
      ..on('queue:cancelled', (data) => onQueueCancelled(_asMap(data)))
      ..on('room:created', (data) => onRoomCreated(_asMap(data)))
      ..on('room:joined', (data) => onRoomJoined(_asMap(data)))
      ..on('room:updated', (data) => onRoomUpdated(_asMap(data)))
      ..on('room:invited', (data) => onRoomInvited(_asMap(data)))
      ..on('room:left', (_) => onRoomLeft())
      ..on('party:updated', (data) => onPartyUpdated(_asMap(data)))
      ..on('party:invited', (data) => onPartyInvited(_asMap(data)))
      ..on('party:inviteSent', (data) => onPartyInviteSent(_asMap(data)))
      ..on('party:declined', (data) => onPartyDeclined(_asMap(data)))
      ..on('rank:updated', (data) => onRankUpdated(_asMap(data)))
      ..on('friend:status', (data) => onFriendStatus(_asMap(data)))
      ..on('friends:changed', (data) => onFriendsChanged(_asMap(data)))
      // PR-B (F6): the reply to 'friends:status' finally has a
      // listener — previously the client asked for the list and then
      // dropped the answer on the floor.
      ..on('friends:statusList', (data) => onFriendsStatusList(_asMap(data)))
      ..on('emote:received', (data) => onEmoteReceived(_asMap(data)))
      ..on('achievements:unlocked', (data) => onAchievementUnlocked(_asMap(data)))
      ..on('match:playerBotReplaced', (data) => onPlayerBotReplaced(_asMap(data)))
      ..on('match:announcement', (data) => onMatchAnnouncement?.call(_asMap(data)))
      ..on('match:abandoned', (data) {
        final map = _asMap(data);
        final uname = map['username']?.toString() ?? 'A player';
        if (map['ended'] != true) {
          onMatchAnnouncement?.call({'message': '$uname left the game. Bot took over!'});
        }
      })
      ..on('error', (data) {
        final msg = data is Map ? (data['message'] ?? 'Socket error') : data.toString();
        print('[Socket] Socket error: $msg');
        onError(msg as String);
      });

    print('[Socket] Initiating connect to $baseUrl');
    _socket!.connect();
  }

  void disconnect() {
    _connectedToken = null;
    _connectedBaseUrl = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _pendingEmits.clear();
  }

  // ── Game actions ──────────────────────────────────────────────────────────

  void queueRanked({int mmr = 0}) =>
      _emit('queue:ranked', {'mmr': mmr});

  void startQueueWithBots() =>
      _emit('queue:startBots', {});

  void cancelRankedQueue() => _emit('queue:cancel', {});

  void startOffline(String difficulty) =>
      _emit('bot:offline', {'difficulty': difficulty});

  void leaveMatch() => _emit('match:leave', {});

  void createRoom() => _emit('room:create', {});

  void joinRoom(String code) => _emit('room:join', {'code': code.toUpperCase()});

  void inviteToRoom(String targetUserId, String code) =>
      _emit('room:invite', {'targetUserId': targetUserId, 'code': code.toUpperCase()});

  void leaveRoom() => _emit('room:leave', {});

  void startRoomWithBots(String code) => _emit('room:startWithBots', {'code': code});

  void inviteToParty(String targetUserId) => _emit('party:invite', {'targetUserId': targetUserId});

  void acceptPartyInvite(String partyId) => _emit('party:accept', {'partyId': partyId});

  /// PR-B (F7): declining now tells the server, so the inviter hears
  /// about it and the invite dies. Previously this was local-only.
  void declinePartyInvite(String partyId) => _emit('party:decline', {'partyId': partyId});

  void leaveParty() => _emit('party:leave', {});

  void selectPower(String matchId, String suit) =>
      _emit('power:select', {'matchId': matchId, 'suit': suit});

  void playCard(String matchId, String cardId) =>
      _emit('card:play', {'matchId': matchId, 'cardId': cardId});

  void requestFriendStatuses() => _emit('friends:status', {});

  void sendEmote(String matchId, String emote) =>
      _emit('emote:send', {'matchId': matchId, 'emote': emote});

  // ── Internals ─────────────────────────────────────────────────────────────

  void _emit(String event, Map<String, dynamic> data) {
    if (_socket == null || !_socket!.connected) {
      print('[Socket] Socket not ready, buffering event: $event');
      _pendingEmits.add(_PendingEmit(event, data));
      return;
    }
    print('[Socket] Emitting: $event $data');
    _socket!.emit(event, data);
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}

class _PendingEmit {
  final String event;
  final Map<String, dynamic> data;
  _PendingEmit(this.event, this.data);
}
