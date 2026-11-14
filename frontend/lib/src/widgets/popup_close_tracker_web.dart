import 'dart:async';

import 'package:web/web.dart' as web;

/// Tracks "a popup window opened and then closed" (the Google sign-in
/// popup), so a failed Google attempt can be surfaced instead of failing
/// silently.
///
/// Why this exists: the Google sign-in popup opens in its own window, and
/// the `google_sign_in_web` plugin swallows the credential error when the
/// popup fails (e.g. Error 400 origin_mismatch) — nothing ever reaches the
/// app's credential stream. The one signal the app CAN see is the window
/// losing focus (popup opened) and regaining it (popup closed) without any
/// credential arriving.
///
/// A plain focus return is ignored unless a blur came first (page load
/// focuses the window with no preceding blur). The optional [events]
/// stream exists only so widget tests can drive the tracker without a
/// browser window.
class PopupCloseTracker {
  PopupCloseTracker({Stream<void>? events}) {
    if (events != null) {
      _events = events;
    } else {
      _controller = StreamController<void>.broadcast();
      _events = _controller!.stream;
      // Window is an EventTarget, not an Element, so the Element
      // onBlur/onFocus getters do not apply — use the providers directly.
      _blurSub = web.EventStreamProviders.blurEvent
          .forTarget(web.window)
          .listen((_) => _blurred = true);
      _focusSub = web.EventStreamProviders.focusEvent
          .forTarget(web.window)
          .listen((_) {
        if (_blurred) {
          _blurred = false;
          _controller!.add(null);
        }
      });
    }
  }

  late final Stream<void> _events;
  StreamController<void>? _controller;
  StreamSubscription<dynamic>? _blurSub;
  StreamSubscription<dynamic>? _focusSub;
  bool _blurred = false;

  /// Fires once per blur-then-focus cycle (web), or per event on the
  /// injected test stream.
  Stream<void> get onPopupClosed => _events;

  void dispose() {
    _blurSub?.cancel();
    _focusSub?.cancel();
    _controller?.close();
  }
}
