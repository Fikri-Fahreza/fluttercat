import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF708A5A);
  static const Color lightGreen = Color(0xFFEBF3E8);
  static const Color bgCream = Color(0xFFFAF6F0);
  static const Color cardCream = Color(0xFFFFFBF7);
  static const Color borderCream = Color(0xFFE8E2D9);
  static const Color textBrown = Color(0xFF4A3E3D);
  static const Color textMuted = Color(0xFFA09DBA);
  static const Color softGold = Color(0xFFE4C078);
  static const Color danger = Color(0xFFD96A6A);
  static const Color white = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgCream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        surface: AppColors.bgCream,
      ),
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        bodyLarge: GoogleFonts.nunito(color: AppColors.textBrown),
        bodyMedium: GoogleFonts.nunito(color: AppColors.textBrown),
        titleLarge: GoogleFonts.nunito(
          color: AppColors.textBrown,
          fontWeight: FontWeight.w800,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgCream,
        elevation: 0,
        titleTextStyle: GoogleFonts.nunito(
          color: AppColors.textBrown,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: AppColors.textBrown),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardCream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderCream),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderCream),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        labelStyle: GoogleFonts.nunito(color: AppColors.textMuted),
        hintStyle: GoogleFonts.nunito(color: AppColors.textMuted),
      ),
    );
  }
}
