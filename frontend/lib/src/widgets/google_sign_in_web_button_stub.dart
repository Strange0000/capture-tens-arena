import 'package:flutter/material.dart';

typedef GoogleIdTokenCallback = Future<void> Function(
  String idToken,
  String username,
);

/// Non-web placeholder. Native platforms continue to use the app's custom button.
class GoogleSignInWebButton extends StatelessWidget {
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
