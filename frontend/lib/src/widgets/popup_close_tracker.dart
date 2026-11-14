// Conditional export for the Google-popup close tracker.
//
// On web this watches window blur/focus (the Google sign-in popup opens in
// its own window). Everywhere else it is a never-firing placeholder — the
// login screen's own conditional import already swaps the whole
// GoogleSignInWebButton for a stub off-web.
export 'popup_close_tracker_stub.dart'
    if (dart.library.html) 'popup_close_tracker_web.dart';
