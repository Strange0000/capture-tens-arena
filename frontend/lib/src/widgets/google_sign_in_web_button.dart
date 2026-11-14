import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart' show kGooglePromptTimeout;
import 'gis_button.dart';
import 'popup_close_tracker.dart';

/// Callback used to exchange Google's signed ID token for the game's session.
typedef GoogleIdTokenCallback = Future<void> Function(
  String idToken,
  String username,
);

/// What the player chose in the "Continue as …?" confirmation dialog.
enum _ConfirmChoice { cont, switchAccount, dismissed }

/// Signs in with Google on web.
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
/// [onError].
///
/// Round 3: the rendered GIS button turned out to be a black box the app
/// cannot observe. With the plugin's `use_fedcm_for_prompt: true`, clicking
/// it opens Chrome's FedCM account-chooser sheet (browser chrome, not a
/// popup tab): no window blur, no credential, no error when the origin is
/// unauthorized — so the popup tracker never fires, the page sits dimmed
/// behind the browser sheet, and the live test saw silence plus a stuck
/// greyed-out button. The primary button is therefore the app's own
/// "Sign in with Google" button, which drives the GIS prompt
/// (`signInSilently`) directly: the attempt is observable and bounded by
/// [promptTimeout], so a failed attempt ALWAYS surfaces a failure message
/// and restores the button. The rendered GIS button survives only as a
/// fallback, shown after a suppressed prompt — its popup flow still works
/// where One Tap / FedCM is blocked. A failed attempt never leaves the
/// button greyed out: [_confirming]/[_exchanging] always reset (dialog
/// close / finally block / exchange watchdog) and [_googleBusy] is bounded
/// by the prompt timeout.
class GoogleSignInWebButton extends StatefulWidget {
  const GoogleSignInWebButton({
    super.key,
    required this.googleSignIn,
    required this.onIdToken,
    required this.onError,
    required this.onSwitchAccount,
    this.popupCloseTracker,
    this.compact = false,
    this.promptTimeout = kGooglePromptTimeout,
    this.exchangeTimeout = const Duration(seconds: 75),
  });

  /// The single shared GoogleSignIn instance owned by [AuthService].
  /// Do NOT create a second instance here: the GIS button's credential
  /// only arrives via this instance's onCurrentUserChanged stream, and a
  /// second instance would never see it (and would fight over the cache).
  final GoogleSignIn googleSignIn;
  final GoogleIdTokenCallback onIdToken;
  final ValueChanged<Object> onError;

  /// Signs the cached Google account out and re-offers the account
  /// chooser, saying so in plain words. Owned by the login screen (which
  /// shows the outcome) so the widget stays dumb about how switching works.
  final Future<void> Function() onSwitchAccount;

  /// Tracks the Google popup closing. Injected for tests; defaults to
  /// the real window blur/focus tracker.
  final PopupCloseTracker? popupCloseTracker;
  final bool compact;

  /// Bound for a GIS prompt that never resolves (e.g. Error 400
  /// origin_mismatch: GIS never fires a prompt moment). Injectable so
  /// tests can use a short bound instead of waiting out the real one.
  final Duration promptTimeout;

  /// Backstop for an exchange that never finishes (the backend call is
  /// already capped at 60s; this only catches a pathological hang).
  /// Injectable so tests can use a short bound.
  final Duration exchangeTimeout;

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

  /// A prompt attempt started from the app's own button is running.
  bool _googleBusy = false;

  /// The rendered GIS button is shown as a fallback (after a suppressed
  /// prompt — its popup flow works where One Tap / FedCM is blocked).
  bool _showGisFallback = false;

  /// Fires shortly after the Google popup closes, unless a credential
  /// arrived first. Gives the credential a moment to arrive after the
  /// popup closes (focus can return a beat before the postMessage does),
  /// so a slow-but-successful sign-in is never reported as failed.
  Timer? _popupClosedTimer;

  /// Hard backstop: if an exchange is still running when this fires, the
  /// button is restored and the failure is surfaced instead of leaving
  /// the player staring at a greyed-out button forever.
  Timer? _exchangeWatchdog;

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

  void _cancelExchangeWatchdog() {
    _exchangeWatchdog?.cancel();
    _exchangeWatchdog = null;
  }

  /// The Google popup window closed. If no credential arrived, the
  /// attempt failed (e.g. Google's Error 400 origin_mismatch page, or
  /// the player closed the popup) — say so in plain words instead of
  /// leaving the player staring at an unchanged login screen.
  ///
  /// Only applies to the rendered GIS button's popup flow: the app's own
  /// button drives the prompt directly and reports its own outcome, so a
  /// popup-close during a prompt attempt is the prompt's business, not
  /// this tracker's.
  void _handlePopupClosed() {
    if (!mounted || _signInInProgress || _googleBusy) return;
    _cancelPopupClosedTimer();
    _popupClosedTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _signInInProgress || _googleBusy) return;
      widget.onError(Exception('Google sign-in did not complete'));
    });
  }

  /// Starts a Google sign-in from the app's own button.
  ///
  /// Round 3: driving the GIS prompt directly makes the attempt
  /// observable — it resolves with an account, returns null when the
  /// prompt was suppressed or dismissed, or never resolves (bounded by
  /// [promptTimeout]). Every outcome restores the button within seconds:
  /// a credential opens the confirm dialog via the stream, a suppressed
  /// prompt reveals the rendered GIS button as a fallback, and a hung
  /// prompt surfaces the plain-words failure. A tap while an attempt is
  /// already running is ignored — the plugin serializes its calls, so a
  /// second prompt would queue behind the first and hang with it.
  Future<void> _startGoogleSignIn() async {
    if (_googleBusy || _signInInProgress || !mounted) return;
    setState(() => _googleBusy = true);
    try {
      final account = await widget.googleSignIn
          .signInSilently(reAuthenticate: true)
          .timeout(widget.promptTimeout);
      if (!mounted) return;
      if (account != null) {
        // The credential also arrives via the stream, which opens the
        // confirm dialog; reAuthenticate forces a fresh prompt, so a new
        // stream event follows even for the already-known account.
        return;
      }
      // The prompt was suppressed or dismissed (FedCM cooldown, or no
      // Google session in the browser): the rendered GIS button's popup
      // flow still works there, so offer it instead of leaving the player
      // with a dead button.
      setState(() => _showGisFallback = true);
      widget.onError(Exception('Google sign-in prompt suppressed'));
    } on TimeoutException {
      // The prompt never resolved (e.g. Error 400 origin_mismatch: GIS
      // never fires a prompt moment). The attempt failed — say so and
      // restore the button instead of leaving it greyed out.
      if (mounted) widget.onError(Exception('Google sign-in did not complete'));
    } catch (error) {
      if (mounted) widget.onError(error);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
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
    _ConfirmChoice choice;
    try {
      choice = await _showConfirmDialog(account);
    } catch (error) {
      // Round 3: if showing the dialog throws, the button must not stay
      // greyed out and pointer-ignored forever — treat it as dismissed.
      debugPrint('GoogleSignInWebButton: confirm dialog failed: $error');
      choice = _ConfirmChoice.dismissed;
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
    if (!mounted) return;

    if (choice == _ConfirmChoice.switchAccount) {
      // Round 2, bug 1: signOut alone only clears the cache and disables
      // auto-select — nothing on screen changes until the player taps the
      // GIS button again, so the old link looked like a no-op. The
      // callback re-offers the account chooser right away; if the prompt
      // is suppressed or hangs, the caller says so in plain words.
      // The button stays busy while the switch runs, so a concurrent tap
      // cannot start a second prompt behind the first one (the plugin
      // serializes its calls — a second prompt would hang with it).
      setState(() => _googleBusy = true);
      try {
        await widget.onSwitchAccount();
      } finally {
        if (mounted) setState(() => _googleBusy = false);
      }
      return;
    }
    if (choice != _ConfirmChoice.cont) return;

    // G4: from here on the exchange IS user-confirmed, so a failure is a
    // real sign-in failure and may surface via onError.
    setState(() => _exchanging = true);
    _armExchangeWatchdog();
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
      _cancelExchangeWatchdog();
      if (mounted) setState(() => _exchanging = false);
    }
  }

  /// Hard backstop for an exchange that never finishes: restore the
  /// button and surface the failure instead of leaving the player stuck
  /// on a greyed-out button with no message.
  void _armExchangeWatchdog() {
    _cancelExchangeWatchdog();
    _exchangeWatchdog = Timer(widget.exchangeTimeout, () {
      if (!mounted || !_exchanging) return;
      _cancelExchangeWatchdog();
      setState(() => _exchanging = false);
      widget.onError(Exception('Google sign-in did not complete'));
    });
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
    // the player is actively signing in may reach onError. A stream error
    // while a prompt is merely running is not forwarded either — the
    // prompt's own timeout reports if the attempt never resolves.
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
    _cancelExchangeWatchdog();
    _popupClosedSub?.cancel();
    _popupTracker.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  /// The app's own "Sign in with Google" button. It looks like Google's
  /// button (dark, Google "G", white text) but the tap is ours: it drives
  /// the GIS prompt directly, so the attempt is observable and bounded.
  /// The rendered GIS button ([GisButton]) is only a fallback, shown after
  /// a suppressed prompt.
  Widget _buildOwnGoogleButton(double width) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _startGoogleSignIn,
        child: SizedBox(
          width: width,
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4285F4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _googleBusy
                      ? 'Opening Google sign-in…'
                      : (widget.compact ? 'Google' : 'Sign in with Google'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        final busy = _signInInProgress || _googleBusy;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: buttonWidth,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  IgnorePointer(
                    ignoring: busy,
                    child: Opacity(
                      opacity: busy ? 0.45 : 1,
                      child: _buildOwnGoogleButton(buttonWidth),
                    ),
                  ),
                  if (_exchanging || _googleBusy)
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
            ),
            if (_showGisFallback) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: buttonWidth,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    IgnorePointer(
                      ignoring: busy,
                      child: Opacity(
                        opacity: busy ? 0.45 : 1,
                        child: GisButton(
                          minimumWidth: buttonWidth,
                          compact: widget.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
