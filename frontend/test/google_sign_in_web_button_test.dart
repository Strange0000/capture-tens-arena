import 'dart:async';

import 'package:capture_tens_arena/src/widgets/google_sign_in_web_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Fake platform backing [GoogleSignIn] in tests. Its [userDataEvents]
/// stream is what the real web plugin uses to deliver the GIS button's
/// credential, so emitting on it reproduces exactly what the browser does
/// when it picks a Google account — including the auto-pick case PR-A fixes.
class FakeGoogleSignInPlatform extends GoogleSignInPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<GoogleSignInUserData?> userDataController =
      StreamController<GoogleSignInUserData?>.broadcast();

  bool signOutCalled = false;
  bool disconnectCalled = false;

  void emitUser(GoogleSignInUserData user) => userDataController.add(user);

  @override
  Stream<GoogleSignInUserData?>? get userDataEvents =>
      userDataController.stream;

  @override
  Future<void> initWithParams(SignInInitParameters params) async {}

  @override
  Future<GoogleSignInUserData?> signInSilently() async => null;

  @override
  Future<GoogleSignInTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async =>
      GoogleSignInTokenData(
        idToken: 'fake-id-token',
        accessToken: 'fake-access-token',
      );

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
  }

  @override
  Future<bool> isSignedIn() async => false;
}

void main() {
  late FakeGoogleSignInPlatform fakePlatform;
  late GoogleSignInPlatform previousPlatform;

  setUp(() {
    previousPlatform = GoogleSignInPlatform.instance;
    fakePlatform = FakeGoogleSignInPlatform();
    GoogleSignInPlatform.instance = fakePlatform;
  });

  tearDown(() {
    GoogleSignInPlatform.instance = previousPlatform;
  });

  /// Pumps the button with a fake platform and wires the platform's
  /// userDataEvents into [GoogleSignIn.onCurrentUserChanged], the way the
  /// real web plugin does on construction. Returns the spies.
  Future<({List<(String, String)> exchanged, List<Object> errors})>
      pumpButton(
    WidgetTester tester,
    GoogleSignIn googleSignIn,
  ) async {
    final exchanged = <(String, String)>[];
    final errors = <Object>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInWebButton(
            googleSignIn: googleSignIn,
            onIdToken: (idToken, username) async {
              exchanged.add((idToken, username));
            },
            onError: errors.add,
          ),
        ),
      ),
    );
    await tester.pump();
    // Triggers GoogleSignIn's internal subscription to userDataEvents.
    await googleSignIn.signInSilently();
    return (exchanged: exchanged, errors: errors);
  }

  GoogleSignInUserData testUser() => GoogleSignInUserData(
        email: 'test@example.com',
        id: 'google-123',
        displayName: 'Test User',
        idToken: 'fake-id-token',
      );

  testWidgets(
      'a streamed Google account does NOT auto-exchange without confirmation',
      (WidgetTester tester) async {
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final spies = await pumpButton(tester, googleSignIn);

    // The browser auto-picks an account (the PR-A bug: this used to sign
    // the player straight in as whichever account the browser chose).
    fakePlatform.emitUser(testUser());
    await tester.pumpAndSettle();

    // A confirmation dialog appears and nothing is exchanged yet.
    expect(
      find.text('Continue as Test User (test@example.com)?'),
      findsOneWidget,
    );
    expect(spies.exchanged, isEmpty);
    expect(spies.errors, isEmpty);

    // Dismissing the dialog via the barrier also exchanges nothing.
    await tester.tapAt(const Offset(50, 50));
    await tester.pumpAndSettle();
    expect(spies.exchanged, isEmpty);
    expect(find.text('Continue as Test User (test@example.com)?'), findsNothing);
  });

  testWidgets('tapping Continue exchanges the confirmed account',
      (WidgetTester tester) async {
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final spies = await pumpButton(tester, googleSignIn);

    fakePlatform.emitUser(testUser());
    await tester.pumpAndSettle();
    expect(spies.exchanged, isEmpty);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(spies.exchanged, [('fake-id-token', 'Test User')]);
    expect(spies.errors, isEmpty);
  });

  testWidgets(
      '"Use a different account" signs out and never exchanges the token',
      (WidgetTester tester) async {
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final spies = await pumpButton(tester, googleSignIn);

    fakePlatform.emitUser(testUser());
    await tester.pumpAndSettle();
    expect(spies.exchanged, isEmpty);

    await tester.tap(find.text('Use a different account'));
    await tester.pumpAndSettle();

    expect(spies.exchanged, isEmpty);
    expect(spies.errors, isEmpty);
    expect(fakePlatform.signOutCalled, isTrue);
  });
}
