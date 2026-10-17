import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_sign_in_web;

/// Callback used to exchange Google's signed ID token for the game's session.
typedef GoogleIdTokenCallback = Future<void> Function(
  String idToken,
  String username,
);

/// Uses the official Google Identity Services button on web.
///
/// The Google web plugin's deprecated signIn() flow only returns an access
/// token. The rendered GIS button emits an authenticated account with an ID
/// token, which the game's backend can securely verify.
class GoogleSignInWebButton extends StatefulWidget {
  const GoogleSignInWebButton({
    super.key,
    required this.onIdToken,
    required this.onError,
    this.compact = false,
  });

  final GoogleIdTokenCallback onIdToken;
  final ValueChanged<Object> onError;
  final bool compact;

  @override
  State<GoogleSignInWebButton> createState() => _GoogleSignInWebButtonState();
}

class _GoogleSignInWebButtonState extends State<GoogleSignInWebButton> {
  // On web, the client ID is read from web/index.html's google-signin-client_id
  // meta tag. Do not provide serverClientId; that parameter is unsupported on web.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile', 'openid'],
  );

  StreamSubscription<GoogleSignInAccount?>? _subscription;
  bool _handlingSignIn = false;

  @override
  void initState() {
    super.initState();
    _subscription = _googleSignIn.onCurrentUserChanged.listen(
      _handleAccountChanged,
      onError: _handleStreamError,
    );
    // Ensure the plugin is initialized before renderButton asks it to draw GIS.
    unawaited(_initializePlugin());
  }

  Future<void> _initializePlugin() async {
    try {
      await _googleSignIn.isSignedIn();
    } catch (error) {
      if (mounted) widget.onError(error);
    }
  }

  Future<void> _handleAccountChanged(GoogleSignInAccount? account) async {
    if (account == null || _handlingSignIn || !mounted) return;

    setState(() => _handlingSignIn = true);
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
      if (mounted) setState(() => _handlingSignIn = false);
    }
  }

  void _handleStreamError(Object error) {
    if (mounted) widget.onError(error);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonWidth = widget.compact ? 180.0 : 300.0;
    return SizedBox(
      width: buttonWidth,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          IgnorePointer(
            ignoring: _handlingSignIn,
            child: Opacity(
              opacity: _handlingSignIn ? 0.45 : 1,
              child: google_sign_in_web.renderButton(
                configuration: google_sign_in_web.GSIButtonConfiguration(
                  type: google_sign_in_web.GSIButtonType.standard,
                  theme: google_sign_in_web.GSIButtonTheme.filledBlack,
                  size: google_sign_in_web.GSIButtonSize.large,
                  text: google_sign_in_web.GSIButtonText.signinWith,
                  shape: google_sign_in_web.GSIButtonShape.rectangular,
                  minimumWidth: buttonWidth,
                ),
              ),
            ),
          ),
          if (_handlingSignIn)
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
  }
}
