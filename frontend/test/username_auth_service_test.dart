import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capture_tens_arena/src/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AuthService serviceWith(MockClient client) =>
      AuthService(baseUrl: 'https://example.test', httpClient: client);

  test('checkUsernameAvailability returns the server answer verbatim', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/users/username/available');
      expect(request.url.queryParameters['username'], 'Arjun');
      expect(request.headers['Authorization'], 'Bearer tok');
      return http.Response(
        jsonEncode({
          'available': false,
          'reason': 'taken',
          'message': 'That name is already taken.',
          'suggestions': ['Arjun2'],
        }),
        200,
      );
    });
    final answer = await serviceWith(client).checkUsernameAvailability('tok', 'Arjun');
    expect(answer['available'], isFalse);
    expect(answer['reason'], 'taken');
    expect(answer['suggestions'], ['Arjun2']);
  });

  test('checkUsernameAvailability throws a plain-words error on transport failure', () async {
    final client = MockClient((_) async => http.Response('boom', 500));
    expect(
      () => serviceWith(client).checkUsernameAvailability('tok', 'Arjun'),
      throwsA(isA<Exception>()),
    );
  });

  test('claimUsername returns the fresh session and saves it', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/users/username/claim');
      return http.Response(
        jsonEncode({
          'token': 'fresh-jwt',
          'user': {'id': 'u1', 'username': 'Meera_7', 'hasChosenUsername': true},
        }),
        200,
      );
    });
    final session = await serviceWith(client).claimUsername('tok', 'Meera_7');
    expect(session.token, 'fresh-jwt');
    expect(session.username, 'Meera_7');
    expect(session.hasChosenUsername, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('jwt'), 'fresh-jwt');
    expect(prefs.getString('username'), 'Meera_7');
  });

  test('claimUsername surfaces the server message on failure', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({'error': 'That name was just taken. Try another one.'}),
          409,
        ));
    expect(
      () => serviceWith(client).claimUsername('tok', 'Arjun'),
      throwsA(predicate((e) => e.toString().contains('That name was just taken'))),
    );
  });
}
