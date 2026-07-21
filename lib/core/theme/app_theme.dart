import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.functionalBlue,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        primary: AppColors.functionalBlue,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.bricolageGrotesqueTextTheme().copyWith(
        displayLarge: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        bodyMedium: const TextStyle(color: AppColors.textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
    );
  }
}
