import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'gis_button.dart';
import 'popup_close_tracker.dart';

/// Callback used to exchange Google's signed ID token for the game's session.
typedef GoogleIdTokenCallback = Future<void> Function(
  String idToken,
  String username,
);

/// What the player chose in the "Continue as …?" confirmation dialog.
enum _ConfirmChoice { cont, switchAccount, dismissed }

/// Uses the official Google Identity Services button on web.
///
/// The Google web plugin's deprecated signIn() flow only returns an access
/// token. The rendered GIS button emits an authenticated account with an ID
/// token, which the game's backend can securely verify.
///
/// PR-A: the account the GIS button emits is NEVER exchanged automatically.
/// The browser may pick whichever Google account it likes (including the
/// wrong one); the player must first confirm "Continue as <name> (<email>)?"
/// — only then is [onIdToken] called. "Use a different account" signs the
/// cached Google account out and re-offers the account chooser.
///
/// Round 2: the plugin swallows the error when the Google popup itself
/// fails (e.g. Error 400 origin_mismatch) — nothing ever reaches the
/// credential stream, so the attempt failed silently. The widget therefore
/// also watches for the popup window closing without a credential
/// ([PopupCloseTracker]) and surfaces that as a plain-words failure via
/// [onError]. A failed attempt never leaves the button greyed out: the
/// button is only dimmed while [_confirming] or [_exchanging], both of
/// which always reset (dialog close / finally block).
class GoogleSignInWebButton extends StatefulWidget {
  const GoogleSignInWebButton({
    super.key,
    required this.googleSignIn,
    required this.onIdToken,
    required this.onError,
    required this.onSwitchAccount,
    this.popupCloseTracker,
    this.compact = false,
  });

  /// The single shared GoogleSignIn instance owned by [AuthService].
  /// Do NOT create a second instance here: the GIS button's credential
  /// only arrives via this instance's onCurrentUserChanged stream, and a
  /// second instance would never see it (and would fight over the cache).
  final GoogleSignIn googleSignIn;
  final GoogleIdTokenCallback onIdToken;
  final ValueChanged<Object> onError;

  /// Signs the cached Google account out and re-offers the account
  /// chooser. Returns true if the chooser produced an account (the
  /// confirm dialog then follows via the credential stream). Owned by
  /// [AuthService] so the widget stays dumb about how switching works.
  final Future<bool> Function() onSwitchAccount;

  /// Tracks the Google popup closing. Injected for tests; defaults to
  /// the real window blur/focus tracker.
  final PopupCloseTracker? popupCloseTracker;
  final bool compact;

  @override
  State<GoogleSignInWebButton> createState() => _GoogleSignInWebButtonState();
}

class _GoogleSignInWebButtonState extends State<GoogleSignInWebButton> {
  StreamSubscription<GoogleSignInAccount?>? _subscription;
  StreamSubscription<void>? _popupClosedSub;
  late final PopupCloseTracker _popupTracker;

  /// A confirmation dialog is on screen for a streamed account.
  bool _confirming = false;

  /// A user-confirmed exchange (fetching the ID token / calling onIdToken)
  /// is running.
  bool _exchanging = false;

  /// Fires shortly after the Google popup closes, unless a credential
  /// arrived first. Gives the credential a moment to arrive after the
  /// popup closes (focus can return a beat before the postMessage does),
  /// so a slow-but-successful sign-in is never reported as failed.
  Timer? _popupClosedTimer;

  @override
  void initState() {
    super.initState();
    // KEEP this subscription: the GIS button's credential only arrives via
    // this stream — deleting it breaks the button. The stream is only a
    // trigger for the confirmation dialog now, never an auto sign-in.
    _subscription = widget.googleSignIn.onCurrentUserChanged.listen(
      _handleAccountChanged,
      onError: _handleStreamError,
    );
    _popupTracker = widget.popupCloseTracker ?? PopupCloseTracker();
    _popupClosedSub =
        _popupTracker.onPopupClosed.listen((_) => _handlePopupClosed());
  }

  bool get _signInInProgress => _confirming || _exchanging;

  void _cancelPopupClosedTimer() {
    _popupClosedTimer?.cancel();
    _popupClosedTimer = null;
  }

  /// The Google popup window closed. If no credential arrived, the
  /// attempt failed (e.g. Google's Error 400 origin_mismatch page, or
  /// the player closed the popup) — say so in plain words instead of
  /// leaving the player staring at an unchanged login screen.
  void _handlePopupClosed() {
    if (!mounted || _signInInProgress) return;
    _cancelPopupClosedTimer();
    _popupClosedTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _signInInProgress) return;
      widget.onError(Exception('Google sign-in did not complete'));
    });
  }

  Future<void> _handleAccountChanged(GoogleSignInAccount? account) async {
    if (account == null || _signInInProgress || !mounted) return;

    // A credential arrived — the popup (if any) succeeded, so no failure
    // message is due.
    _cancelPopupClosedTimer();

    // G2: gate the token exchange behind an explicit confirmation.
    // A streamed account means "the browser picked this Google account",
    // not "the player wants to play as this account".
    setState(() => _confirming = true);
    final choice = await _showConfirmDialog(account);
    if (!mounted) return;
    setState(() => _confirming = false);

    if (choice == _ConfirmChoice.switchAccount) {
      // Round 2, bug 1: signOut alone only clears the cache and disables
      // auto-select — nothing on screen changes until the player taps the
      // GIS button again, so the old link looked like a no-op. The
      // callback re-offers the account chooser right away; if the prompt
      // is suppressed, the caller says so and the GIS button stays usable.
      await widget.onSwitchAccount();
      return;
    }
    if (choice != _ConfirmChoice.cont) return;

    // G4: from here on the exchange IS user-confirmed, so a failure is a
    // real sign-in failure and may surface via onError.
    setState(() => _exchanging = true);
    try {
      final idToken = (await account.authentication).idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google did not return an ID token. Check the Web OAuth client ID '
          'and the Authorized JavaScript origins in Google Cloud Console.',
        );
      }

      final displayName = account.displayName?.trim();
      final username = displayName != null && displayName.isNotEmpty
          ? displayName
          : account.email.split('@').first;
      await widget.onIdToken(idToken, username);
    } catch (error) {
      if (mounted) widget.onError(error);
    } finally {
      if (mounted) setState(() => _exchanging = false);
    }
  }

  Future<_ConfirmChoice> _showConfirmDialog(GoogleSignInAccount account) async {
    final displayName = account.displayName?.trim();
    final name = displayName != null && displayName.isNotEmpty
        ? displayName
        : account.email.split('@').first;
    final result = await showDialog<_ConfirmChoice>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Sign in with Google?'),
        content: Text('Continue as $name (${account.email})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ConfirmChoice.switchAccount),
            child: const Text('Use a different account'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ConfirmChoice.cont),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? _ConfirmChoice.dismissed;
  }

  void _handleStreamError(Object error) {
    // G4: background stream failures (GIS auto-select, a stale cached
    // account, the plugin racing its own init) are NOT a failed sign-in
    // and must never surface as a red error banner. Only a failure while
    // the player is actively signing in may reach onError.
    if (_signInInProgress) {
      _cancelPopupClosedTimer();
      if (mounted) widget.onError(error);
    } else {
      debugPrint('GoogleSignInWebButton: background stream error ignored: $error');
    }
  }

  @override
  void dispose() {
    _cancelPopupClosedTimer();
    _popupClosedSub?.cancel();
    _popupTracker.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desiredWidth = widget.compact ? 180.0 : 300.0;
        final buttonWidth = constraints.maxWidth.isFinite &&
                constraints.maxWidth < desiredWidth
            ? constraints.maxWidth
            : desiredWidth;
        return SizedBox(
          width: buttonWidth,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              IgnorePointer(
                ignoring: _signInInProgress,
                child: Opacity(
                  opacity: _signInInProgress ? 0.45 : 1,
                  child: GisButton(
                    minimumWidth: buttonWidth,
                    compact: widget.compact,
                  ),
                ),
              ),
              if (_exchanging)
                const Positioned(
                  right: 8,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
