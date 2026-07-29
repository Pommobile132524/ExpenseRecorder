import 'package:flutter/material.dart';

/// ธีมโทนทอง สไตล์ห้างทอง
class AppTheme {
  static const gold = Color(0xFFC9A227);
  static const darkRed = Color(0xFF8B1A1A);
  static const cream = Color(0xFFFFF8E7);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          primary: gold,
          secondary: darkRed,
        ),
        scaffoldBackgroundColor: cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkRed,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: Colors.black87,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      );
}
