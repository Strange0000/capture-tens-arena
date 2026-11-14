import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'package:google_sign_in/google_sign_in.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GuestSession {
  const GuestSession({
    required this.token,
    required this.userId,
    required this.username,
  });

  final String token;
  final String userId;
  final String username;
}

class AuthService {
  AuthService({String? baseUrl}) 
    : baseUrl = baseUrl ?? 'https://capture-tens-arena.onrender.com';

  final String baseUrl;

  // PR-A (G3): ONE shared GoogleSignIn for the whole app, owned here and
  // injected into the web GIS button widget. A second instance would never
  // see the button's credential (it only arrives via this instance's
  // onCurrentUserChanged stream) and would fight over the cached account.
  //
  // Web construction stays client-ID-free: the client ID comes from
  // web/index.html's google-signin-client_id meta tag. The ID is only
  // passed on native, where there is no meta tag to read it from.
  static const String _envClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
  static const String _defaultClientId =
      '925721095742-omjs30pn4s3lcag3r8pr5grl514voisn.apps.googleusercontent.com';
  static String get _nativeClientId =>
      _envClientId.isNotEmpty ? _envClientId : _defaultClientId;

  final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? null : _nativeClientId,
    serverClientId: kIsWeb ? null : _nativeClientId,
    scopes: const ['email', 'profile', 'openid'],
  );

  /// Signs the cached Google account out and re-offers the account
  /// chooser, so the player can pick a different Google account instead
  /// of being silently signed into the one the browser last picked.
  ///
  /// Returns true if the chooser produced an account (the confirm dialog
  /// then follows via the credential stream); false if the prompt was
  /// suppressed or dismissed — the caller should then tell the player to
  /// tap the Google button. Failures are swallowed: there may simply be
  /// no cached account, and that is not an error.
  ///
  /// Round 2, bug 1: `signOut` alone only clears the cache and disables
  /// auto-select — nothing on screen changes until the player taps the
  /// GIS button again, so the old "Use a different account" link looked
  /// like a no-op. Prompting here shows the chooser right away. GIS may
  /// suppress the prompt (cool-down after a recent dismissal); that is
  /// not an error, and the false return lets the caller say so.
  Future<bool> switchGoogleAccount() async {
    try {
      await googleSignIn.signOut();
    } catch (error) {
      debugPrint('AuthService: Google signOut for account switch failed: $error');
    }
    try {
      await googleSignIn.disconnect();
    } catch (error) {
      debugPrint('AuthService: Google disconnect for account switch failed: $error');
    }
    try {
      // signInSilently() on web drives the GIS prompt (One Tap / FedCM
      // account chooser). It returns the picked account, or null when the
      // prompt was suppressed or dismissed. The 60s timeout guards a
      // prompt that never resolves; errors are swallowed (default
      // suppressErrors: true already returns null on error).
      final account = await googleSignIn
          .signInSilently()
          .timeout(const Duration(seconds: 60));
      return account != null;
    } catch (error) {
      debugPrint('AuthService: Google account chooser prompt failed: $error');
      return false;
    }
  }

  // Render's free service can take longer than 15 seconds to wake from idle.
  // Allow enough time for the backend cold start before treating login as failed.
  static const Duration _timeout = Duration(seconds: 60);

  Map<String, String> get _defaultHeaders => {};

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
    ..._defaultHeaders,
  };

  Future<GuestSession?> getCachedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('jwt');
    final cachedUser = prefs.getString('username');
    final cachedId = prefs.getString('userId');
    if (cached != null && cachedUser != null && cachedId != null) {
      return GuestSession(token: cached, userId: cachedId, username: cachedUser);
    }
    return null;
  }

  Future<GuestSession> guestLogin() async {
    // Return cached token if still valid (simple reuse strategy)
    final cachedSession = await getCachedSession();
    if (cachedSession != null) {
      try {
        await fetchMe(cachedSession.token);
        return cachedSession;
      } catch (_) {
        await clearSession();
      }
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/guest'),
      headers: _defaultHeaders,
    ).timeout(_timeout);
    if (response.statusCode >= 400) {
      throw Exception('Guest login failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    final userId = user['id'] as String;
    final username = user['username'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt', token);
    await prefs.setString('userId', userId);
    await prefs.setString('username', username);

    return GuestSession(token: token, userId: userId, username: username);
  }

  Future<GuestSession> googleLogin() async {
    // Web must use the Google Identity Services button widget. This method is
    // retained for native platforms; serverClientId is not supported on web.
    // It uses the shared instance (PR-A G3): a fresh per-call instance
    // would not share the cached account with the rest of the app.
    final account = await googleSignIn.signIn();
    if (account == null) throw Exception('Google Sign-In aborted');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google Sign-In did not return an ID token. Check your OAuth client configuration.',
      );
    }

    return googleLoginWithIdToken(
      idToken,
      username: account.displayName ?? account.email.split('@').first,
    );
  }

  /// Exchanges a Google ID token for the game's own JWT session.
  ///
  /// This is used by the web-only GIS button as well as native Google login.
  Future<GuestSession> googleLoginWithIdToken(
    String idToken, {
    String? username,
  }) async {
    if (idToken.trim().isEmpty) {
      throw Exception('Google Sign-In returned an empty ID token.');
    }

    final requestedName = username?.trim();
    final safeName = requestedName == null || requestedName.isEmpty
        ? 'Player'
        : String.fromCharCodes(requestedName.runes.take(24));

    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {
        'Content-Type': 'application/json',
        ..._defaultHeaders,
      },
      body: jsonEncode({
        'idToken': idToken,
        'username': safeName,
      }),
    ).timeout(_timeout);
    if (response.statusCode >= 400) {
      throw Exception('Google login failed: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    final userId = user['id'] as String;
    final savedUsername = user['username'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt', token);
    await prefs.setString('userId', userId);
    await prefs.setString('username', savedUsername);

    return GuestSession(token: token, userId: userId, username: savedUsername);
  }

  Future<Map<String, dynamic>> fetchMe(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: _authHeaders(token),
    ).timeout(_timeout);
    if (response.statusCode >= 400) throw Exception('Failed to fetch profile');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchFriends(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/friends'),
      headers: _authHeaders(token),
    ).timeout(_timeout);
    if (response.statusCode >= 400) throw Exception('Failed to fetch friends');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['friends']);
  }

  Future<void> sendFriendRequest(String token, String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/friends/request'),
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders(token),
      },
      body: jsonEncode({'username': username}),
    ).timeout(_timeout);
    if (response.statusCode >= 400) {
      final msg = jsonDecode(response.body)['error'] ?? 'Failed to send request';
      throw Exception(msg);
    }
  }

  Future<void> acceptFriendRequest(String token, String friendId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/friends/accept'),
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders(token),
      },
      body: jsonEncode({'friendId': friendId}),
    ).timeout(_timeout);
    if (response.statusCode >= 400) {
      final msg = jsonDecode(response.body)['error'] ?? 'Failed to accept request';
      throw Exception(msg);
    }
  }

  Future<void> removeFriend(String token, String friendId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/friends/$friendId'),
      headers: _authHeaders(token),
    ).timeout(_timeout);
    if (response.statusCode >= 400) {
      final msg = jsonDecode(response.body)['error'] ?? 'Failed to remove friend';
      throw Exception(msg);
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String token, String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/search').replace(queryParameters: {'q': query}),
      headers: _authHeaders(token),
    ).timeout(_timeout);
    if (response.statusCode >= 400) throw Exception('Search failed');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['users']);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('userId');
    await prefs.remove('username');
  }

  Future<List<Map<String, dynamic>>> fetchAchievements(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/achievements'),
      headers: _authHeaders(token),
    ).timeout(_timeout);
    if (response.statusCode >= 400) throw Exception('Failed to fetch achievements');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['achievements']);
  }
}
