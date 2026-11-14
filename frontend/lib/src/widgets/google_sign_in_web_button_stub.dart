import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

typedef GoogleIdTokenCallback = Future<void> Function(
  String idToken,
  String username,
);

/// Non-web placeholder. Native platforms continue to use the app's custom button.
/// Accepts the same constructor as the web button (including the shared
/// [GoogleSignIn] instance) so the login screen compiles unchanged off-web.
class GoogleSignInWebButton extends StatelessWidget {
  const GoogleSignInWebButton({
    super.key,
    required this.googleSignIn,
    required this.onIdToken,
    required this.onError,
    required this.onSwitchAccount,
    this.compact = false,
  });

  final GoogleSignIn googleSignIn;
  final GoogleIdTokenCallback onIdToken;
  final ValueChanged<Object> onError;

  /// Accepted for API parity with the web button; never called off-web.
  final Future<bool> Function() onSwitchAccount;
  final bool compact;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
