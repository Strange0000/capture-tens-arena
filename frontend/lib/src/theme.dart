import 'package:flutter/material.dart';

/// One cohesive visual identity for the whole app — ROYAL CASINO.
///
/// Deep green felt, dark casino black-green, warm gold as the single
/// primary accent, cream-white cards. No generic purple gradients, no
/// default Flutter blue, no bright cyan: the old teal secondary is now
/// a muted felt green ("emerald"). All screens use these tokens instead
/// of hardcoding colours, so the whole game reads as one casino room:
/// home / login, lobby, game table, score pill, victory card.
class ArenaColors {
  // Casino room
  static const ink = Color(0xFF060D0A);
  static const surface = Color(0xFF0E1F17);
  static const panel = Color(0xFF0F2018);
  static const panelLight = Color(0xFF14291E);
  // Green felt
  static const felt = Color(0xFF0B3D2E);
  static const feltDark = Color(0xFF072A20);
  static const feltLight = Color(0xFF11543F);
  static const feltBright = Color(0xFF14663F);
  // Wooden table rim
  static const wood = Color(0xFF8A5A2B);
  static const woodDark = Color(0xFF5C3A17);
  static const woodDeep = Color(0xFF3E2712);
  // Gold — the one primary accent
  static const gold = Color(0xFFFFC857);
  static const goldDeep = Color(0xFFD4A017);
  static const goldSoft = Color(0xFFFFD166);
  static const champagne = Color(0xFFE9C46A);
  // Muted felt-green secondary (was bright cyan 0xFF48E5C2).
  // Kept under the old name so every screen that used it re-skins
  // automatically; new code should use `emerald`.
  static const cyan = Color(0xFF3FA97C);
  static const emerald = Color(0xFF3FA97C);
  static const cream = Color(0xFFF5EFE0);
  static const cardWhite = Color(0xFFFFFBF2);
  static const danger = Color(0xFFFF6B6B);
  static const ruby = Color(0xFFD96A6A);
}

ThemeData buildArenaTheme() {
  const ink = ArenaColors.ink;
  const surface = ArenaColors.surface;
  const gold = ArenaColors.gold;
  const emerald = ArenaColors.emerald;

  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ink,
    colorScheme: ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      secondary: emerald,
      surface: surface,
      error: const Color(0xFFFF6B6B),
    ),
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: Colors.white,
      ),
    ),

    // Primary action = warm gold on ink. Secondary = gold-outlined on
    // dark felt, never a second saturated colour competing with gold.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(56, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: gold,
        foregroundColor: ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        elevation: 2,
        shadowColor: gold.withOpacity(0.35),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: ArenaColors.cream,
        side: BorderSide(color: gold.withOpacity(0.45)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: gold,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: gold.withOpacity(0.18)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white54,
      textColor: Colors.white,
    ),

    dividerTheme: const DividerThemeData(
      color: Colors.white10,
      thickness: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: const TextStyle(color: Colors.white24),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gold, width: 1.5),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF14291E),
      contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}
