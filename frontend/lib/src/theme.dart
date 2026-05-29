import 'package:flutter/material.dart';

ThemeData buildArenaTheme() {
  const ink = Color(0xFF070B13);
  const surface = Color(0xFF101826);
  const gold = Color(0xFFFFC857);
  const cyan = Color(0xFF48E5C2);

  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ink,
    colorScheme: ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
      primary: cyan,
      secondary: gold,
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

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(56, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: cyan,
        foregroundColor: ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cyan,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: cyan, width: 1.5),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1C2B3A),
      contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
  );
}
