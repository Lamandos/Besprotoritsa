// Theme palette members are accessed directly throughout the app.
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

/// Shared palette and Material treatment for the bark, wood, and ship-metal UI.
abstract final class BesprotoritsaTheme {
  static const ink = Color(0xFF171411);
  static const hull = Color(0xFF241D18);
  static const wood = Color(0xFF33271F);
  static const bark = Color(0xFFD8C39A);
  static const bone = Color(0xFFF1E5CA);
  static const bronze = Color(0xFFB8894D);
  static const ember = Color(0xFFC75B32);
  static const moss = Color(0xFF718263);

  static ThemeData get data {
    final scheme = ColorScheme.fromSeed(
      seedColor: bronze,
      brightness: Brightness.dark,
      primary: bronze,
      onPrimary: ink,
      secondary: moss,
      onSecondary: ink,
      tertiary: ember,
      onTertiary: bone,
      surface: hull,
      onSurface: bone,
      error: const Color(0xFFE27966),
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: bone,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: bone,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: wood,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF70573A)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF554334),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: bronze,
          foregroundColor: ink,
          disabledBackgroundColor: const Color(0xFF514333),
          disabledForegroundColor: const Color(0xFFB8AA91),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFD5AD70)),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: bone,
          side: const BorderSide(color: Color(0xFF8C704A)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1D1915),
        labelStyle: const TextStyle(color: bark),
        hintStyle: const TextStyle(color: Color(0xFF9D8F79)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF70573A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF70573A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: bronze, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: wood,
        contentTextStyle: TextStyle(color: bone),
      ),
    );
  }
}
