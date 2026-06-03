import 'package:flutter/material.dart';

/// Design tokens for the Lipa Agent app.
///
/// Lipa has no dedicated Agent design handoff, so this reuses the Customer
/// design system 1:1 (same warm near-monochrome palette, the same green brand,
/// the same radii and shadows). The Agent app adapts the *layouts* to agent
/// journeys, not the token set — keeping both apps visually one family.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF6F4EF); // warm off-white app background
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFAF8F3);
  static const surfaceDeep = Color(0xFF0C0C0C); // near-black structural panels
  static const nearBlack = Color(0xFF0A0A0A); // hero/balance panels

  static const inkHi = Color(0xFF171717);
  static const ink = Color(0xFF262624);
  static const inkMid = Color(0xFF5A5852);
  static const inkLow = Color(0xFF8A8780);
  // Placeholder / hint ink — deliberately faint so hints never read as values.
  static const inkFaint = Color(0xFFB8B4AA);

  static const border = Color(0xFFE9E5DC);
  static const borderHi = Color(0xFFDCD7C8);
  static const borderInk = Color(0xFF1D1D1B);

  static const brand = Color(0xFF4F8A6A); // muted fintech green
  static const brandDeep = Color(0xFF386851);
  static const brandSoft = Color(0xFFE8EFE9);

  static const success = Color(0xFF4F8A6A);
  static const warn = Color(0xFFB87208);
  static const warnSoft = Color(0xFFFCF0D9);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFBE7E5);
  static const pending = Color(0xFF5A5852);
  static const pendingSoft = Color(0xFFECEBE5);
  static const info = Color(0xFF1C4F87);
  static const infoSoft = Color(0xFFE1ECF7);

  /// Soft green glow under the central FAB.
  static const fabGlow = Color(0x6B4F8A6A);
}

/// Box shadows from the design.
class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x0A0F0F0F), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D0F0F0F), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const lift = [
    BoxShadow(color: Color(0x1F0F0F0F), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0F0F0F0F), blurRadius: 6, offset: Offset(0, 2)),
  ];
}

/// Common radii used throughout the design.
class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const xl = 16.0;
  static const xxl = 18.0;
  static const card = 20.0;
  static const hero = 24.0;
  static const pill = 999.0;
}
