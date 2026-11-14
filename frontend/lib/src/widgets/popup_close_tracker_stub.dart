import 'dart:async';

/// Tracks "a popup window opened and then closed" (the Google sign-in
/// popup), so a failed Google attempt can be surfaced instead of failing
/// silently.
///
/// Off-web this never fires — there is no popup to track. The optional
/// [events] stream exists only so widget tests can drive the tracker
/// without a browser window.
class PopupCloseTracker {
  PopupCloseTracker({Stream<void>? events})
      : _events = events ?? const Stream<void>.empty();

  final Stream<void> _events;

  /// Fires once per blur-then-focus cycle (web), or per event on the
  /// injected test stream.
  Stream<void> get onPopupClosed => _events;

  void dispose() {}
}
