import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Typography helpers. The design uses Bricolage Grotesque for UI text and
/// DM Mono for figures, codes, and references — same as the Customer app.
class AppText {
  AppText._();

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.inkHi,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.inkHi,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.dmMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

/// The app-wide Material theme, tuned to the warm, near-monochrome palette.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      surface: AppColors.surface,
      error: AppColors.danger,
      brightness: Brightness.light,
    ),
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: GoogleFonts.bricolageGrotesqueTextTheme(base.textTheme).apply(
      bodyColor: AppColors.inkHi,
      displayColor: AppColors.inkHi,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    // Placeholders must read clearly as *hints*, not pre-filled values: a faint
    // ink tone at normal weight, never the strong input ink.
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: GoogleFonts.bricolageGrotesque(
        color: AppColors.inkFaint,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}
