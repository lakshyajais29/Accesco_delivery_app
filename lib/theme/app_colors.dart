import 'package:flutter/material.dart';

/// InstaStyle Colour System — Dark Mode Primary Experience (Chapter 03)
/// Every hex value taken directly from the design system spec.
class AppColors {
  AppColors._();

  // ── Surfaces ───────────────────────────────────────────────
  /// App background. Near-black with micro warmth. Never pure #000000.
  static const Color backgroundBase = Color(0xFF0B0B0B);

  /// All product and outfit cards. Warm dark brown-black. Feels like leather.
  static const Color surfaceCard = Color(0xFF141210);

  /// Modals, bottom sheets, drawers. Slightly lifted from base.
  static const Color surfaceElevated = Color(0xFF1C1916);

  // ── Light Theme Surfaces ───────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceCardLight = Color(0xFFFFFFFF);
  static const Color separatorLight = Color(0xFFEAEAEA);


  // ── Brand ──────────────────────────────────────────────────
  /// Primary CTAs. Active navigation. Logo. The brand's signature tone.
  static const Color brandWarmBrown = Color(0xFF8B6347);

  /// Text accents. Shimmer lines. Icon active states. Highlight elements.
  static const Color brandTan = Color(0xFFC4A882);

  /// Pressed/active CTA states. Dark variant of primary brand brown.
  static const Color brandDeepBrown = Color(0xFF5C3D22);

  // ── Text ───────────────────────────────────────────────────
  /// Primary text. Warm. Editorial. Never pure #FFFFFF.
  static const Color ivoryWhite = Color(0xFFF5F0EA);

  /// Secondary labels. Timestamps. Metadata. Placeholder text.
  static const Color mutedText = Color(0xFF8A8070);

  // ── Light Theme Text ───────────────────────────────────────────────────
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMutedLight = Color(0xFF666666);

  // ── Signals ────────────────────────────────────────────────
  /// Stock counters. Urgency badges. Used sparingly — maximum impact.
  static const Color fomoRed = Color(0xFFC0392B);

  /// Limited time signals. Sale ending. Trending now indicators.
  static const Color amberAlert = Color(0xFFD4870A);

  // ── Structural ─────────────────────────────────────────────
  /// Hairline rules between sections. Barely visible. Structural only.
  static const Color separator = Color.fromRGBO(196, 168, 130, 0.15);

  // ── Gradients ──────────────────────────────────────────────
  /// Full-screen outfit card backgrounds.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
    colors: [Color(0xFF0B0B0B), Color(0xFF1C1410), Color(0xFF0B0B0B)],
  );

  /// All primary action buttons.
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandWarmBrown, brandTan],
  );

  /// Low stock badges. Urgency bars.
  static const LinearGradient fomoGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [fomoRed, Color(0xFF8B1A1A)],
  );

  /// Animated left-to-right on all New Drop cards.
  static const LinearGradient shimmer = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    stops: [0.0, 0.5, 1.0],
    colors: [
      Colors.transparent,
      Color.fromRGBO(196, 168, 130, 0.3),
      Colors.transparent,
    ],
  );

  /// Bottom text overlay on all editorial photos.
  static const LinearGradient moodOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B0B0B), Color.fromRGBO(11, 11, 11, 0.6)],
  );

  /// Hero card bottom-to-top dark-to-transparent (per spec).
  static const LinearGradient heroBottomOverlay = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0.0, 0.6, 1.0],
    colors: [
      Color(0xFF0B0B0B),
      Color.fromRGBO(11, 11, 11, 0.7),
      Colors.transparent,
    ],
  );
}