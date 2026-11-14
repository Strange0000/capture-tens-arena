import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' show GoogleSignInPlugin;
import 'package:google_sign_in_web/web_only.dart' as google_sign_in_web;

/// The real Google Identity Services button (web only).
///
/// Wraps the plugin's own renderButton in a [FutureBuilder] with a timeout /
/// error branch (PR-A G6): the GIS script is loaded from Google's CDN, so an
/// ad-blocker or a dead connection used to leave a blank "Getting ready"
/// area forever. After ~10s without the plugin initialising, the button is
/// replaced by plain words pointing the player at the guest path instead.
class GisButton extends StatefulWidget {
  const GisButton({
    super.key,
    required this.minimumWidth,
    required this.compact,
  });

  final double minimumWidth;
  final bool compact;

  @override
  State<GisButton> createState() => _GisButtonState();
}

class _GisButtonState extends State<GisButton> {
  Future<void>? _readyFuture;

  @override
  void initState() {
    super.initState();
    _readyFuture = _gisReadyFuture();
  }

  /// A future completing when the GIS plugin has loaded and initialised,
  /// or null when it cannot be observed (plugin not the web one, or init
  /// not called yet) — in that case renderButton's own loading state applies.
  static Future<void>? _gisReadyFuture() {
    final platform = GoogleSignInPlatform.instance;
    if (platform is! GoogleSignInPlugin) return null;
    try {
      // `initialized` is marked visible-for-testing by the plugin, but it
      // is the only public signal that the GIS SDK finished loading; the
      // timeout below is what turns a blocked script into a helpful message.
      // ignore: invalid_use_of_visible_for_testing_member
      return platform.initialized.timeout(const Duration(seconds: 10));
    } on StateError {
      // initWithParams hasn't been called yet; renderButton handles it.
      return null;
    }
  }

  Widget _renderButton() {
    return google_sign_in_web.renderButton(
      configuration: google_sign_in_web.GSIButtonConfiguration(
        type: google_sign_in_web.GSIButtonType.standard,
        theme: google_sign_in_web.GSIButtonTheme.filledBlack,
        size: google_sign_in_web.GSIButtonSize.large,
        text: google_sign_in_web.GSIButtonText.signinWith,
        shape: google_sign_in_web.GSIButtonShape.rectangular,
        minimumWidth: widget.minimumWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readyFuture = _readyFuture;
    if (readyFuture == null) return _renderButton();
    return FutureBuilder<void>(
      future: readyFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            "Google couldn't load — check your connection or ad-blocker, "
            'or play as a guest.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white70),
          );
        }
        return _renderButton();
      },
    );
  }
}
