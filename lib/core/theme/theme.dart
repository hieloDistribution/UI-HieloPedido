import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: TailwindColors.indigo600,
        onPrimary: Colors.white,
        secondary: TailwindColors.indigo500,
        onSecondary: Colors.white,
        background: TailwindColors.slate50,
        onBackground: TailwindColors.slate900,
        surface: Colors.white,
        onSurface: TailwindColors.slate900,
        error: TailwindColors.rose600,
        onError: Colors.white,
        outline: TailwindColors.slate300,
      ),
      scaffoldBackgroundColor: TailwindColors.slate50,
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: TailwindColors.slate900,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.outfit(
          color: TailwindColors.slate900,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: TailwindColors.slate700,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: TailwindColors.slate600,
          fontWeight: FontWeight.normal,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: TailwindColors.slate900),
        titleTextStyle: TextStyle(
          color: TailwindColors.slate900,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TailwindColors.slate200, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TailwindColors.indigo600,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TailwindColors.slate300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TailwindColors.slate200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TailwindColors.indigo500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TailwindColors.rose500, width: 1),
        ),
        labelStyle: const TextStyle(color: TailwindColors.slate500),
        hintStyle: const TextStyle(color: TailwindColors.slate400),
      ),
    );
  }
}
