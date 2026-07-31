import 'package:flutter/foundation.dart';

import '../models/match_state.dart';
import '../models/rank_info.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

enum LobbyStatus { idle, queuing, inRoom, inMatch }

class AppState extends ChangeNotifier {
  late final String backendUrl;
  late final AuthService auth;
  final SocketService socket = SocketService();

  AppState() {
    String? url;

    // 1. Query parameter has highest priority (web only, safe on all platforms)
    try {
      final queryBackend = Uri.base.queryParameters['backend'];
      if (queryBackend != null && queryBackend.isNotEmpty) {
        url = queryBackend;
      }
    } catch (_) {}

    // 2. Compile-time dart-define
    if (url == null) {
      const envUrl = String.fromEnvironment('BACKEND_URL');
      if (envUrl.isNotEmpty) {
        url = envUrl;
      }
    }

    // 3. Fallback to default production URL
    url ??= 'https://capture-tens-arena.onrender.com';

    backendUrl = url;
    auth = AuthService(baseUrl: backendUrl);
    
    // Check for cached session on init and restore it
    _checkCachedSession();
  }

  String? token;
  String? userId;
  String? username;
  MatchState? match;
  LobbyStatus lobbyStatus = LobbyStatus.idle;
  String? roomCode;
  String? errorMessage;
  String? _leftMatchId; // Track left match to ignore stale server updates
  
  // Rank info & Statistics
  RankInfo? rankInfo;
  Map<String, dynamic>? lastRankUpdate; // from rank:updated socket event
  Map<String, dynamic>? statistics;

  // Friends & Party
  List<Map<String, dynamic>> friends = [];
  Map<String, bool> friendOnlineStatus = {}; // userId -> online
  List<dynamic>? party; // null if not in party
  Map<String, dynamic>? pendingPartyInvite;
  
  // Cached session info (for "Continue as" flow)
  String? cachedUsername;
  String? cachedUserId;
  bool isAuthChecking = true;
  bool get hasCachedSession => cachedUsername != null;

  // Emotes
  Map<String, dynamic>? latestEmote; // {seat, username, emote}
  
  // Achievement toasts
  List<Map<String, dynamic>> pendingAchievements = [];

  bool get isLoggedIn => token != null;

  // ── Cached session check ───────────────────────────────────────────────────

  Future<void> _checkCachedSession() async {
    try {
      final session = await auth.getCachedSession();
      if (session != null) {
        try {
          await auth.fetchMe(session.token);
          cachedUsername = session.username;
          cachedUserId = session.userId;
          
          // Auto-restore session since it is valid
          token = session.token;
          userId = session.userId;
          username = session.username;
          _connectSocket();
          _fetchInitialData();
        } catch (_) {
          await auth.clearSession();
          cachedUsername = null;
          cachedUserId = null;
        }
      }
    } finally {
      isAuthChecking = false;
      notifyListeners();
    }
  }

  // ── Auth & connection ────────────────────────────────────────────────────

  Future<void> continueAsExisting() async {
    final session = await auth.getCachedSession();
    if (session == null) throw Exception('No cached session');
    
    // Validate the token with the backend first
    await auth.fetchMe(session.token);
    
    token = session.token;
    userId = session.userId;
    username = session.username;
    _connectSocket();
    // Fetch rank and friends in background
    _fetchInitialData();
    notifyListeners();
  }

  Future<void> tryRestoreSession() async {
    final session = await auth.getCachedSession();
    if (session == null) return;
    token = session.token;
    userId = session.userId;
    username = session.username;
    _connectSocket();
    _fetchInitialData();
    notifyListeners();
  }

  Future<void> bootGuest() async {
    final session = await auth.guestLogin();
    token = session.token;
    userId = session.userId;
    username = session.username;
    _connectSocket();
    _fetchInitialData();
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    final session = await auth.googleLogin();
    token = session.token;
    userId = session.userId;
    username = session.username;
    _connectSocket();
    _fetchInitialData();
    notifyListeners();
  }

  Future<void> _fetchInitialData() async {
    try { await fetchRankInfo(); } catch (_) {}
    try { await fetchFriends(); } catch (_) {}
  }

  Future<void> logout() async {
    await auth.clearSession();
    token = null;
    userId = null;
    username = null;
    match = null;
    rankInfo = null;
    lastRankUpdate = null;
    friends = [];
    friendOnlineStatus = {};
    party = null;
    cachedUsername = null;
    cachedUserId = null;
    socket.disconnect();
    notifyListeners();
  }

  void _connectSocket() {
    AudioService.instance.init();
    socket.connect(
      token: token!,
      baseUrl: backendUrl,
      onMatchState: _onMatchState,
      onMatchCreated: _onMatchCreated,
      onQueueJoined: _onQueueJoined,
      onRoomCreated: _onRoomCreated,
      onRoomJoined: _onRoomJoined,
      onPartyUpdated: _onPartyUpdated,
      onPartyInvited: _onPartyInvited,
      onRankUpdated: _onRankUpdated,
      onFriendStatus: _onFriendStatus,
      onEmoteReceived: _onEmoteReceived,
      onAchievementUnlocked: _onAchievementUnlocked,
      onPlayerBotReplaced: _onPlayerBotReplaced,
      onError: _onError,
    );
  }

  // ── Socket event handlers ─────────────────────────────────────────────────

  void _onMatchState(Map<String, dynamic> json) {
    // debug: print('[AppState] match:state received, phase=${json['phase']}, id=${json['id']}');
    final incoming = MatchState.fromJson(json);
    // Ignore stale updates from a match we already left
    if (_leftMatchId != null && incoming.id == _leftMatchId) return;
    match = incoming;
    _leftMatchId = null; // Clear since we're in a valid match now
    // Set inMatch for any active phase so reconnecting players are navigated correctly
    const activePhases = {'deal-five', 'power-select', 'deal-rest', 'playing', 'trick-resolving', 'complete'};
    if (activePhases.contains(match!.phase)) {
      lobbyStatus = LobbyStatus.inMatch;
    }
    notifyListeners();
  }

  void _onMatchCreated(Map<String, dynamic> json) {
    // debug: print('[AppState] match:created received: $json');
    lobbyStatus = LobbyStatus.inMatch;
    notifyListeners();
  }

  void _onQueueJoined(Map<String, dynamic> _) {
    lobbyStatus = LobbyStatus.queuing;
    notifyListeners();
  }

  void _onRoomCreated(Map<String, dynamic> json) {
    roomCode = json['code'] as String?;
    lobbyStatus = LobbyStatus.inRoom;
    notifyListeners();
  }

  void _onRoomJoined(Map<String, dynamic> json) {
    lobbyStatus = LobbyStatus.inRoom;
    notifyListeners();
  }

  void _onPartyUpdated(Map<String, dynamic> json) {
    party = json['party'] as List<dynamic>?;
    notifyListeners();
  }

  void _onPartyInvited(Map<String, dynamic> json) {
    pendingPartyInvite = json;
    notifyListeners();
  }

  void _onRankUpdated(Map<String, dynamic> json) {
    lastRankUpdate = json;
    // Update local rank info with new MMR
    final newMmr = json['newMmr'] as int?;
    if (newMmr != null) {
      rankInfo = RankInfo.fromMmr(newMmr, peakMmr: rankInfo?.peakMmr ?? newMmr, wins: rankInfo?.wins ?? 0, losses: rankInfo?.losses ?? 0);
    }
    notifyListeners();
  }

  void _onFriendStatus(Map<String, dynamic> json) {
    final fUserId = json['userId'] as String?;
    final status = json['status'] as String?;
    if (fUserId != null && status != null) {
      friendOnlineStatus[fUserId] = status == 'online';
      notifyListeners();
    }
  }

  void _onError(String msg) {
    errorMessage = msg;
    if (msg.contains('Invalid auth token') || msg.contains('Missing auth token')) {
      logout();
    } else {
      notifyListeners();
    }
  }

  void _onEmoteReceived(Map<String, dynamic> json) {
    latestEmote = json;
    AudioService.instance.playEmote();
    AudioService.instance.hapticLight();
    notifyListeners();
    // Auto-clear after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (latestEmote == json) {
        latestEmote = null;
        notifyListeners();
      }
    });
  }

  void _onAchievementUnlocked(Map<String, dynamic> json) {
    final achievements = json['achievements'] as List<dynamic>? ?? [];
    for (final a in achievements) {
      if (a is Map<String, dynamic>) {
        pendingAchievements.add(a);
      }
    }
    AudioService.instance.playAchievement();
    AudioService.instance.hapticHeavy();
    notifyListeners();
  }

  void _onPlayerBotReplaced(Map<String, dynamic> json) {
    // A disconnected player was replaced by a bot
    notifyListeners();
  }

  void dismissAchievement() {
    if (pendingAchievements.isNotEmpty) {
      pendingAchievements.removeAt(0);
      notifyListeners();
    }
  }

  void sendEmote(String emote) {
    if (match != null) {
      socket.sendEmote(match!.id, emote);
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void clearRankUpdate() {
    lastRankUpdate = null;
    notifyListeners();
  }

  // ── Rank ─────────────────────────────────────────────────────────────────

  Future<void> fetchRankInfo() async {
    if (token == null) return;
    try {
      final data = await auth.fetchMe(token!);
      final ranking = data['ranking'] as Map<String, dynamic>?;
      if (ranking != null) {
        rankInfo = RankInfo.fromJson(ranking);
      } else {
        rankInfo = RankInfo.fromMmr(0);
      }
      statistics = data['statistics'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {
      rankInfo = RankInfo.fromMmr(0);
      statistics = null;
    }
  }

  // ── Friends & Party ──────────────────────────────────────────────────────

  Future<void> fetchFriends() async {
    if (token == null) return;
    try {
      friends = await auth.fetchFriends(token!);
      notifyListeners();
    } catch (_) {
      // Silently ignore — friends list is non-critical
      friends = [];
    }
  }

  Future<void> sendFriendRequest(String targetUsername) async {
    if (token == null) return;
    try {
      await auth.sendFriendRequest(token!, targetUsername);
      await fetchFriends();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> acceptFriendRequest(String friendId) async {
    if (token == null) return;
    try {
      await auth.acceptFriendRequest(token!, friendId);
      await fetchFriends();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> removeFriend(String friendId) async {
    if (token == null) return;
    try {
      await auth.removeFriend(token!, friendId);
      await fetchFriends();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void inviteToParty(String targetUserId) {
    socket.inviteToParty(targetUserId);
  }

  void acceptPartyInvite() {
    if (pendingPartyInvite == null) return;
    socket.acceptPartyInvite(pendingPartyInvite!['partyId']);
    pendingPartyInvite = null;
    notifyListeners();
  }

  void declinePartyInvite() {
    pendingPartyInvite = null;
    notifyListeners();
  }

  void leaveParty() {
    socket.leaveParty();
    party = null;
    notifyListeners();
  }

  void requestFriendStatuses() {
    socket.requestFriendStatuses();
  }

  // ── Game actions ─────────────────────────────────────────────────────────

  void queueRanked() {
    // debug: print('[AppState] queueRanked called, socket connected=${socket.connected}');
    socket.queueRanked(mmr: rankInfo?.mmr ?? 0);
    lobbyStatus = LobbyStatus.queuing;
    notifyListeners();
  }

  void startOffline(String difficulty) {
    // debug: print('[AppState] startOffline($difficulty) called, socket connected=${socket.connected}');
    socket.startOffline(difficulty);
    lobbyStatus = LobbyStatus.inMatch;
    notifyListeners();
  }

  void createRoom() {
    socket.createRoom();
  }

  void joinRoom(String code) {
    socket.joinRoom(code);
  }

  void startRoomWithBots() {
    if (roomCode != null) {
      socket.startRoomWithBots(roomCode!);
    }
  }

  void selectPower(String suit) {
    final current = match;
    if (current == null) return;
    socket.selectPower(current.id, suit);
  }

  void playCard(String cardId) {
    final current = match;
    if (current == null) return;
    socket.playCard(current.id, cardId);
  }

  /// Called when player returns to home after a completed match.
  void leaveMatch() {
    _leftMatchId = match?.id; // Remember so we ignore stale server updates
    socket.leaveMatch();
    match = null;
    lastRankUpdate = null;
    lobbyStatus = LobbyStatus.idle;
    roomCode = null;
    notifyListeners();
  }

  /// Which team the local player is on (A = seats 0,2 / B = seats 1,3).
  String get myTeam {
    if (match == null || userId == null) return 'A';
    final player = match!.players.firstWhere(
      (p) => p.userId == userId,
      orElse: () => match!.players.first,
    );
    return player.team;
  }

  /// Which seat the local player is sitting at (0, 1, 2, or 3).
  int get mySeat {
    if (match == null || userId == null) return 0; // Default to 0 for offline/spectator
    final player = match!.players.firstWhere(
      (p) => p.userId == userId,
      orElse: () => match!.players.first,
    );
    return player.seat;
  }
}
