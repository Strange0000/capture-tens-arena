import 'dart:js' as js;

import 'package:flutter/foundation.dart';

import '../models/match_state.dart';
import '../models/rank_info.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

enum LobbyStatus { idle, queuing, inRoom, inMatch }

class AppState extends ChangeNotifier {
  late final String backendUrl;
  late final AuthService auth;
  final SocketService socket = SocketService();

  AppState() {
    // Priority: 1) window.BACKEND_URL from backend_config.js
    //           2) --dart-define=BACKEND_URL
    //           3) ?backend= query parameter
    //           4) localhost fallback
    String url = 'https://capture-tens-arena.onrender.com';

    // Read from JavaScript global (set by backend_config.js)
    try {
      if (js.context.hasProperty('BACKEND_URL')) {
        final jsUrl = js.context['BACKEND_URL'] as String?;
        if (jsUrl != null && jsUrl.isNotEmpty) {
          url = jsUrl;
        }
      }
    } catch (_) {}

    // Fallback to dart-define
    if (url == 'https://capture-tens-arena.onrender.com') {
      const envUrl = String.fromEnvironment('BACKEND_URL');
      if (envUrl.isNotEmpty) url = envUrl;
    }

    // Fallback to query parameter
    if (url == 'https://capture-tens-arena.onrender.com' &&
        Uri.base.queryParameters['backend'] != null) {
      url = Uri.base.queryParameters['backend']!;
    }

    backendUrl = url;
    // ignore: avoid_print
    print('[AppState] Backend URL: $backendUrl');
    auth = AuthService(baseUrl: backendUrl);
    
    // Check for cached session on init (but don't auto-connect)
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
  
  // Rank info
  RankInfo? rankInfo;
  Map<String, dynamic>? lastRankUpdate; // from rank:updated socket event

  // Friends & Party
  List<Map<String, dynamic>> friends = [];
  Map<String, bool> friendOnlineStatus = {}; // userId -> online
  List<dynamic>? party; // null if not in party
  Map<String, dynamic>? pendingPartyInvite;
  
  // Cached session info (for "Continue as" flow)
  String? cachedUsername;
  String? cachedUserId;
  bool get hasCachedSession => cachedUsername != null;

  bool get isLoggedIn => token != null;

  // ── Cached session check ───────────────────────────────────────────────────

  Future<void> _checkCachedSession() async {
    final session = await auth.getCachedSession();
    if (session != null) {
      cachedUsername = session.username;
      cachedUserId = session.userId;
      notifyListeners();
    }
  }

  // ── Auth & connection ────────────────────────────────────────────────────

  Future<void> continueAsExisting() async {
    final session = await auth.getCachedSession();
    if (session == null) throw Exception('No cached session');
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
    if (token != null) return; // already booted
    final session = await auth.guestLogin();
    token = session.token;
    userId = session.userId;
    username = session.username;
    _connectSocket();
    _fetchInitialData();
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    if (token != null) return;
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
      onError: _onError,
    );
  }

  // ── Socket event handlers ─────────────────────────────────────────────────

  void _onMatchState(Map<String, dynamic> json) {
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
    notifyListeners();
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
      notifyListeners();
    } catch (_) {
      rankInfo = RankInfo.fromMmr(0);
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
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> acceptFriendRequest(String friendId) async {
    if (token == null) return;
    try {
      await auth.acceptFriendRequest(token!, friendId);
      await fetchFriends();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeFriend(String friendId) async {
    if (token == null) return;
    try {
      await auth.removeFriend(token!, friendId);
      await fetchFriends();
    } catch (e) {
      errorMessage = e.toString();
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
    socket.queueRanked(mmr: rankInfo?.mmr ?? 0);
    lobbyStatus = LobbyStatus.queuing;
    notifyListeners();
  }

  void startOffline(String difficulty) {
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
