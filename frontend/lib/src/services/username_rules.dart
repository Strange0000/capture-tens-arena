/// Client-side mirror of backend/src/services/usernameService.ts.
/// Keep both in sync — the server is always authoritative; this is only
/// for instant feedback while typing, before the availability check runs.

const int kUsernameMinLength = 3;
const int kUsernameMaxLength = 24;

/// 3–24 chars, starts with a letter, letters/digits/underscore only.
final RegExp kUsernamePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]{2,23}$');

/// Names that can never be claimed (compared lower-cased). Mirrors the
/// backend blocklist: admin, support, system, the bot names Vector / Nova /
/// Cipher, and the obvious look-alike/system names. Any name starting with
/// "guest" is also reserved.
const Set<String> kReservedUsernames = {
  'admin',
  'administrator',
  'support',
  'system',
  'moderator',
  'mod',
  'official',
  'bot',
  'player',
  'vector',
  'nova',
  'cipher',
  'arena',
  'capturetens',
  'capture',
  'tens',
  'guest',
  'server',
  'owner',
  'root',
  'superuser',
  'anonymous',
};

bool isReservedUsername(String lower) =>
    lower.startsWith('guest') || kReservedUsernames.contains(lower);

/// Returns a plain-words problem message, or null when the name is valid.
/// The server re-checks everything — this only drives the inline hint.
String? validateUsernameLocally(String raw) {
  final username = raw.trim();
  if (username.length < kUsernameMinLength) {
    return 'Username must be at least 3 characters long.';
  }
  if (username.length > kUsernameMaxLength) {
    return 'Username must be at most 24 characters long.';
  }
  if (!RegExp(r'^[A-Za-z]').hasMatch(username)) {
    return 'Username must start with a letter.';
  }
  if (!kUsernamePattern.hasMatch(username)) {
    return 'Username can only use letters, numbers and underscore (_).';
  }
  if (isReservedUsername(username.toLowerCase())) {
    return 'That name is reserved. Pick a different username.';
  }
  return null;
}

/// Turn an arbitrary display name (e.g. a Google profile name like
/// "Sumit Jaiswal") into a valid suggestion: keep letters/digits/
/// underscore, drop everything else, cap at 20 chars.
String sanitizeUsernameBase(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
  final stripped = cleaned.replaceFirst(RegExp(r'^[^A-Za-z]+'), '');
  final base = stripped.isNotEmpty ? stripped : 'Player';
  return base.length > 20 ? base.substring(0, 20) : base;
}
