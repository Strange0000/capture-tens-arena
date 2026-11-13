import 'package:flutter/material.dart';

/// One cohesive visual identity for the whole app: a premium card room —
/// deep ink background, rich dark-felt green for the table, warm gold as
/// the single primary accent, cyan kept only as a small secondary accent.
/// No generic purple gradients and no default Flutter blue anywhere.
/// All screens should use these tokens instead of hardcoding colours.
class ArenaColors {
  static const ink = Color(0xFF070B13);
  static const surface = Color(0xFF101826);
  static const panel = Color(0xFF10192A);
  static const felt = Color(0xFF0B3D2E);
  static const feltDark = Color(0xFF072A20);
  static const feltLight = Color(0xFF11543F);
  static const gold = Color(0xFFFFC857);
  static const goldDeep = Color(0xFFD4A017);
  static const goldSoft = Color(0xFFFFD166);
  static const cyan = Color(0xFF48E5C2);
  static const cream = Color(0xFFF5EFE0);
  static const danger = Color(0xFFFF6B6B);
}

ThemeData buildArenaTheme() {
  const ink = ArenaColors.ink;
  const surface = ArenaColors.surface;
  const gold = ArenaColors.gold;
  const cyan = ArenaColors.cyan;

  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ink,
    colorScheme: ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      secondary: cyan,
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

    // Primary action = warm gold on ink. Secondary = outlined, never a
    // second saturated colour competing with gold.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(56, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: gold,
        foregroundColor: ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: gold, width: 1.5),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1C2B3A),
      contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
  );
}
