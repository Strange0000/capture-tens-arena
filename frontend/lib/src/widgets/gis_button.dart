// Conditional export for the Google Identity Services button.
//
// On web this renders the real GIS button (google_sign_in_web, which needs
// dart:js_interop and cannot even be imported in a VM test). Everywhere else
// it is a no-op placeholder — the login screen's own conditional import
// already swaps the whole GoogleSignInWebButton for a stub off-web, and the
// widget test pumps the real widget against a fake platform.
export 'gis_button_stub.dart'
    if (dart.library.html) 'gis_button_web.dart';
