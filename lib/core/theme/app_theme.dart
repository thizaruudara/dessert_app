import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── 1. Core Brand Colors (From EduPeak Website Design System) ───────────────
  static const Color primary = Color(0xFF227AFF); // Primary Brand Blue
  static const Color primaryDark = Color(0xFF1565D8); // Primary Dark / Accent
  static const Color primaryLight = Color(0xFF4490FF); // Primary Light

  // ── 2. Backgrounds & Surfaces ──────────────────────────────────────────────
  static const Color background = Color(0xFFF6FAFF); // Soft Ice-Blue Tint
  static const Color backgroundSoft = Color(0xFFEFF5FF); // Pill capsules & soft backgrounds
  static const Color surface = Color(0xFFFFFFFF); // Surface & Card White
  static const Color card = Color(0xFFFFFFFF); // Main Cards
  static const Color cardAlt = Color(0xFFEFF5FF); // Soft Card Tint
  static const Color border = Color(0xFFE2E8F0); // Delicate Slate Border
  static const Color borderLight = Color(0xFFF1F5F9); // Extra subtle border

  // ── 3. Typography ──────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A); // Main Text (Dark Slate)
  static const Color textSecondary = Color(0xFF334155); // Body Text
  static const Color textMuted = Color(0xFF64748B); // Muted Text / Timestamps

  // ── 4. Accents & Status Indicators ─────────────────────────────────────────
  static const Color liveRed = Color(0xFFEF4444); // Live Stream Red
  static const Color error = Color(0xFFEF4444); // Error
  static const Color success = Color(0xFF10B981); // Success / Distinction
  static const Color gold = Color(0xFFF59E0B); // Gold Trophy / Credits
  static const Color warning = Color(0xFFF59E0B); // Warning
  static const Color accent = Color(0xFF1565D8); // Dark Accent

  // ── 5. Backward Compatibility Aliases ──────────────────────────────────────
  static const Color darkBg = Color(0xFFF6FAFF);
  static const Color darkSurface = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFFFFFFFF);
  static const Color darkCardAlt = Color(0xFFEFF5FF);
  static const Color darkBorder = Color(0xFFE2E8F0);
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.3,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16, color: AppColors.textSecondary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14, color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 0,
        shadowColor: const Color(0x0A0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
        hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
