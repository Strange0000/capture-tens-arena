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

  Map<String, String> get _defaultHeaders => {
    'Bypass-Tunnel-Reminder': 'true',
    'ngrok-skip-browser-warning': 'true',
  };

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
    if (cachedSession != null) return cachedSession;

    final response = await http.post(
      Uri.parse('$baseUrl/auth/guest'),
      headers: _defaultHeaders,
    );
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
    final googleSignIn = GoogleSignIn(
      clientId: '925721095742-omjs30pn4s3lcag3r8pr5grl514voisn.apps.googleusercontent.com',
      scopes: ['email'],
    );
    final account = await googleSignIn.signIn();
    if (account == null) throw Exception('Google Sign-In aborted');
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {
        'Content-Type': 'application/json',
        ..._defaultHeaders,
      },
      body: jsonEncode({
        'googleId': account.id,
        'email': account.email,
        'username': account.displayName ?? account.email.split('@').first,
        'avatarUrl': account.photoUrl,
      }),
    );
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
    );
    if (response.statusCode >= 400) throw Exception('Failed to fetch profile');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchFriends(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/friends'),
      headers: _authHeaders(token),
    );
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
    );
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
    );
    if (response.statusCode >= 400) {
      final msg = jsonDecode(response.body)['error'] ?? 'Failed to accept request';
      throw Exception(msg);
    }
  }

  Future<void> removeFriend(String token, String friendId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/friends/$friendId'),
      headers: _authHeaders(token),
    );
    if (response.statusCode >= 400) {
      final msg = jsonDecode(response.body)['error'] ?? 'Failed to remove friend';
      throw Exception(msg);
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String token, String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/search?q=$query'),
      headers: _authHeaders(token),
    );
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
}
