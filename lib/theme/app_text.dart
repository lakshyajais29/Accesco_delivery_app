import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// InstaStyle Typography System (Chapter 04)
/// Three fonts. One voice.
///
/// - Cormorant Garamond Bold → Display / Cinema
/// - Montserrat Black        → Feature Labels (ALL CAPS)
/// - Inter Regular/Medium    → Body / Interface
/// - Roboto Mono Bold        → Precision Data (ETAs, timers, prices)
class AppText {
  AppText._();

  // ── Display / Cinema (Cormorant Garamond Bold) ──────────────
  /// Hero headline. 48–72px · line-height 0.95 · letter-spacing -0.02em.
  static TextStyle hero({double size = 56}) => GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 0.95,
        letterSpacing: -0.02 * size,
        color: AppColors.ivoryWhite,
      );

  static TextStyle outfitName({double size = 28}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -0.02 * size,
        color: AppColors.ivoryWhite,
      );

  // ── Feature Labels (Montserrat Black, ALL CAPS) ─────────────
  /// 9–14px · ALL CAPS · letter-spacing 0.12–0.18em
  static TextStyle featureLabel({
    double size = 11,
    Color color = AppColors.ivoryWhite,
  }) =>
      GoogleFonts.montserrat(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.15 * size,
        color: color,
        height: 1.2,
      );

  // ── Body / Interface (Inter Regular/Medium) ─────────────────
  /// 13–16px · line-height 1.6 · weight 400/500
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ivoryWhite,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        height: 1.6,
        color: color,
      );

  static TextStyle secondary({double size = 13}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.mutedText,
      );

  // ── Precision Data (Roboto Mono Bold) ───────────────────────
  /// 14–18px · tabular-nums · color #C4A882 (brand tan)
  static TextStyle precisionData({
    double size = 16,
    Color color = AppColors.brandTan,
  }) =>
      GoogleFonts.robotoMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Stock counter — Montserrat Black, #C0392B (FOMO Red).
  static TextStyle stockCounter({double size = 11}) => GoogleFonts.montserrat(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.15 * size,
        color: AppColors.fomoRed,
      );

  /// Strikethrough original price (per typography rules).
  static TextStyle priceOriginal({double size = 14}) => GoogleFonts.robotoMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: AppColors.mutedText.withOpacity(0.45),
        decoration: TextDecoration.lineThrough,
        decorationColor: AppColors.mutedText.withOpacity(0.45),
      );

  /// Current price — Montserrat Black.
  static TextStyle priceCurrent({double size = 16}) => GoogleFonts.montserrat(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.08 * size,
        color: AppColors.ivoryWhite,
      );
}

/// Corner Radius Philosophy (Chapter 02):
/// Sharp CTAs signal authority. Rounded surfaces signal comfort.
class AppRadius {
  AppRadius._();
  static const double card = 16;
  static const double modal = 20;
  static const double pill = 100;
  static const double primaryCta = 0; // sharp — confidence
}