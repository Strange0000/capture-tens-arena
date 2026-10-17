import 'dart:convert';

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

  static const Duration _timeout = Duration(seconds: 15);

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
    const envClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
    const defaultClientId =
        '925721095742-omjs30pn4s3lcag3r8pr5grl514voisn.apps.googleusercontent.com';
    final clientId = envClientId.isNotEmpty ? envClientId : defaultClientId;

    // google_sign_in 6.x supports this API on web, but its signIn() flow is
    // deprecated for web. Keep the existing native flow; use renderButton on web
    // in a follow-up migration rather than passing an access token to ID-token verification.
    final googleSignIn = GoogleSignIn(
      clientId: clientId,
      serverClientId: clientId,
      scopes: ['email', 'profile', 'openid'],
    );
    final account = await googleSignIn.signIn();
    if (account == null) throw Exception('Google Sign-In aborted');

    final auth = await account.authentication;
    // The backend /auth/google endpoint verifies a Google ID token. Never fall
    // back to auth.accessToken here: it is not an ID token and will fail
    // verifyIdToken (and the backend fallback depends on provider permissions).
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google Sign-In did not return an ID token. Check the Web OAuth client ID '
        'and GOOGLE_CLIENT_ID configuration.',
      );
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {
        'Content-Type': 'application/json',
        ..._defaultHeaders,
      },
      body: jsonEncode({
        'idToken': idToken,
        'username': account.displayName ?? account.email.split('@').first,
      }),
    ).timeout(_timeout);
    if (response.statusCode >= 400) {
      throw Exception('Google login failed: ${response.statusCode} - ${response.body}');
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
