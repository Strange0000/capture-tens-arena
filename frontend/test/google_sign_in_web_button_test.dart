import 'dart:async';

import 'package:capture_tens_arena/src/services/auth_service.dart';
import 'package:capture_tens_arena/src/widgets/gis_button.dart';
import 'package:capture_tens_arena/src/widgets/google_sign_in_web_button.dart';
import 'package:capture_tens_arena/src/widgets/popup_close_tracker.dart';
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
  int signInSilentlyCalls = 0;
  GoogleSignInUserData? signInSilentlyResult;

  /// When true, signInSilently() never completes — reproduces a GIS
  /// prompt that never fires a moment (e.g. Error 400 origin_mismatch),
  /// which is how the live test's switch tap and Google button tap hung.
  bool signInSilentlyHang = false;

  void emitUser(GoogleSignInUserData user) => userDataController.add(user);

  @override
  Stream<GoogleSignInUserData?>? get userDataEvents =>
      userDataController.stream;

  @override
  Future<void> initWithParams(SignInInitParameters params) async {}

  @override
  Future<GoogleSignInUserData?> signInSilently() async {
    signInSilentlyCalls++;
    if (signInSilentlyHang) {
      return Completer<GoogleSignInUserData?>().future;
    }
    return signInSilentlyResult;
  }

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
  Future<
      ({
        List<(String, String)> exchanged,
        List<Object> errors,
        List<bool> switchCalls,
      })> pumpButton(
    WidgetTester tester,
    GoogleSignIn googleSignIn, {
    PopupCloseTracker? popupCloseTracker,
    Future<void> Function()? onSwitchAccount,
    Future<void> Function(String idToken, String username)? onIdToken,
    Duration? promptTimeout,
    Duration? exchangeTimeout,
  }) async {
    final exchanged = <(String, String)>[];
    final errors = <Object>[];
    final switchCalls = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInWebButton(
            googleSignIn: googleSignIn,
            onIdToken: onIdToken ??
                (idToken, username) async {
                  exchanged.add((idToken, username));
                },
            onError: errors.add,
            onSwitchAccount: onSwitchAccount ??
                () async {
                  switchCalls.add(true);
                },
            popupCloseTracker: popupCloseTracker,
            promptTimeout: promptTimeout ?? kGooglePromptTimeout,
            exchangeTimeout: exchangeTimeout ?? const Duration(seconds: 75),
          ),
        ),
      ),
    );
    await tester.pump();
    // Triggers GoogleSignIn's internal subscription to userDataEvents.
    await googleSignIn.signInSilently();
    return (exchanged: exchanged, errors: errors, switchCalls: switchCalls);
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
      '"Use a different account" calls the switch callback and never exchanges the token',
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
    // The widget delegates the actual sign-out + chooser prompt to the
    // switch callback (AuthService); it must not sign out itself and
    // leave the player with no chooser (Round 2, bug 1).
    expect(spies.switchCalls, [true]);
    expect(fakePlatform.signOutCalled, isFalse);
  });

  test('AuthService.switchGoogleAccount signs out and prompts the chooser',
      () async {
    final auth = AuthService();
    fakePlatform.signInSilentlyResult = testUser();
    final result = await auth.switchGoogleAccount();

    expect(result, GoogleSwitchResult.picked);
    expect(fakePlatform.signOutCalled, isTrue);
    expect(fakePlatform.disconnectCalled, isTrue);
    expect(fakePlatform.signInSilentlyCalls, 1);
  });

  test(
      'AuthService.switchGoogleAccount returns suppressed when the chooser prompt is suppressed',
      () async {
    final auth = AuthService();
    fakePlatform.signInSilentlyResult = null;
    final result = await auth.switchGoogleAccount();

    expect(result, GoogleSwitchResult.suppressed);
    expect(fakePlatform.signOutCalled, isTrue);
    expect(fakePlatform.disconnectCalled, isTrue);
    expect(fakePlatform.signInSilentlyCalls, 1);
  });

  test(
      'AuthService.switchGoogleAccount returns timedOut when the chooser prompt never resolves',
      () async {
    // Round 3: a hung prompt (GIS never fires a moment on an unauthorized
    // origin) used to hang the switch for 60s with no feedback. It must
    // now resolve as timedOut within the (short, test-injected) bound so
    // the caller can say so in plain words.
    final auth = AuthService();
    fakePlatform.signInSilentlyHang = true;
    final result = await auth.switchGoogleAccount(
      promptTimeout: const Duration(milliseconds: 100),
    );

    expect(result, GoogleSwitchResult.timedOut);
    expect(fakePlatform.signOutCalled, isTrue);
    expect(fakePlatform.disconnectCalled, isTrue);
    expect(fakePlatform.signInSilentlyCalls, 1);
  });

  testWidgets('a popup closing without a credential surfaces a failure',
      (WidgetTester tester) async {
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final popupEvents = StreamController<void>.broadcast();
    final tracker = PopupCloseTracker(events: popupEvents.stream);
    final spies =
        await pumpButton(tester, googleSignIn, popupCloseTracker: tracker);

    // The Google popup opened and closed (e.g. Error 400) with no
    // credential — the plugin swallows the error, so this focus cycle is
    // the only signal. The failure must surface, not fail silently.
    popupEvents.add(null);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(spies.errors, hasLength(1));
    expect(spies.errors.first.toString(), contains('did not complete'));
    expect(spies.exchanged, isEmpty);
    await popupEvents.close();
  });

  testWidgets(
      'a credential arriving after the popup closes cancels the failure',
      (WidgetTester tester) async {
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final popupEvents = StreamController<void>.broadcast();
    final tracker = PopupCloseTracker(events: popupEvents.stream);
    final spies =
        await pumpButton(tester, googleSignIn, popupCloseTracker: tracker);

    popupEvents.add(null);
    await tester.pump(const Duration(seconds: 1));
    fakePlatform.emitUser(testUser());
    await tester.pumpAndSettle();

    // The credential arrived within the grace window: the confirm dialog
    // appears and no failure is reported, even after the window passes.
    expect(
      find.text('Continue as Test User (test@example.com)?'),
      findsOneWidget,
    );
    expect(spies.errors, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    expect(spies.errors, isEmpty);
    await popupEvents.close();
  });

  testWidgets('a popup closing during confirmation reports no failure',
      (WidgetTester tester) async {
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final popupEvents = StreamController<void>.broadcast();
    final tracker = PopupCloseTracker(events: popupEvents.stream);
    final spies =
        await pumpButton(tester, googleSignIn, popupCloseTracker: tracker);

    fakePlatform.emitUser(testUser());
    await tester.pumpAndSettle();
    expect(
      find.text('Continue as Test User (test@example.com)?'),
      findsOneWidget,
    );

    popupEvents.add(null);
    await tester.pump(const Duration(seconds: 4));
    expect(spies.errors, isEmpty);
    await popupEvents.close();
  });

  testWidgets(
      'a hung prompt surfaces a failure and restores the button (Round 3)',
      (WidgetTester tester) async {
    // Live: tapping "Sign in with Google" on an unauthorized origin opened
    // Chrome's FedCM sheet (no popup, no credential, no error) and the
    // page sat dimmed with a greyed-out button. The prompt must now be
    // bounded: the failure surfaces and the button becomes usable again.
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final spies = await pumpButton(
      tester,
      googleSignIn,
      promptTimeout: const Duration(milliseconds: 200),
    );
    fakePlatform.signInSilentlyHang = true;

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(spies.errors, hasLength(1));
    expect(spies.errors.first.toString(), contains('did not complete'));
    expect(spies.exchanged, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // The button is usable again: a second tap is accepted and its own
    // bounded attempt reports the failure again. (The plugin queue stays
    // wedged behind the first hung prompt until reload, so the retry
    // cannot open a new prompt — but it must still resolve, never hang.)
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(spies.errors, hasLength(2));
    expect(spies.errors.last.toString(), contains('did not complete'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a suppressed prompt reveals the GIS fallback button',
      (WidgetTester tester) async {
    // FedCM cooldown / no Google session: the prompt returns null at
    // once. The rendered GIS button's popup flow still works there, so
    // it is offered instead of leaving the player with a dead button.
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    fakePlatform.signInSilentlyResult = null;
    final spies = await pumpButton(
      tester,
      googleSignIn,
      promptTimeout: const Duration(milliseconds: 200),
    );

    expect(find.byType(GisButton), findsNothing);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(spies.errors, hasLength(1));
    expect(spies.errors.first.toString(), contains('prompt suppressed'));
    expect(find.byType(GisButton), findsOneWidget);
    expect(spies.exchanged, isEmpty);
  });

  testWidgets('a stuck exchange is recovered by the watchdog (Round 3)',
      (WidgetTester tester) async {
    // The player confirmed the account, but the exchange never finishes
    // (e.g. the backend call hangs). The button must not stay greyed out
    // forever: the watchdog restores it and surfaces the failure.
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final exchangeNeverCompletes = Completer<void>();
    final spies = await pumpButton(
      tester,
      googleSignIn,
      onIdToken: (_, __) => exchangeNeverCompletes.future,
      exchangeTimeout: const Duration(milliseconds: 300),
    );

    fakePlatform.emitUser(testUser());
    await tester.pumpAndSettle();
    expect(
      find.text('Continue as Test User (test@example.com)?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(spies.errors, hasLength(1));
    expect(spies.errors.first.toString(), contains('did not complete'));
    expect(spies.exchanged, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a second tap while a prompt is running starts no second prompt',
      (WidgetTester tester) async {
    // The plugin serializes its calls, so a second prompt would queue
    // behind the first and hang with it. The button must ignore the
    // second tap while the first attempt is still running.
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile', 'openid'],
    );
    final spies = await pumpButton(
      tester,
      googleSignIn,
      promptTimeout: const Duration(milliseconds: 200),
    );
    fakePlatform.signInSilentlyHang = true;

    final callsBefore = fakePlatform.signInSilentlyCalls;
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    // While the first prompt is running the button shows its busy label;
    // tapping it again must start no second prompt. The tap is expected
    // to hit nothing (IgnorePointer), so silence the hit-test warning.
    expect(find.text('Opening Google sign-in…'), findsOneWidget);
    await tester.tap(
      find.text('Opening Google sign-in…'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(fakePlatform.signInSilentlyCalls, callsBefore + 1);
    expect(spies.errors, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
