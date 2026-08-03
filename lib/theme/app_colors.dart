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

/// ═══════════════════════════════════════════════════════════════════════════
/// EDITORIAL LIGHT PALETTE — the app-wide design language.
///
/// Warm ivory surfaces, a single warm-brown brand accent, and hairline rules.
/// The legacy [AppColors] constants above are retained untouched so existing
/// screens keep compiling while they migrate over to these tokens.
/// ═══════════════════════════════════════════════════════════════════════════
class AppPalette {
  AppPalette._();

  // ── Surfaces ───────────────────────────────────────────────────────────
  /// Page background. Warm ivory — never pure white.
  static const Color canvas = Color(0xFFFBF9F6);

  /// Cards, sheets, app bars. The lifted plane above [canvas].
  static const Color surface = Color(0xFFFFFFFF);

  /// Editorial banners, image placeholders, inactive tiles. Warm beige.
  static const Color surfaceMuted = Color(0xFFF2EDE6);

  /// Pressed / hovered fills on light surfaces.
  static const Color surfaceSunken = Color(0xFFEDE7DE);

  /// Inverted surface — dark CTAs, snackbars, sold-out overlays.
  static const Color ink = Color(0xFF1C1917);

  // ── Text ───────────────────────────────────────────────────────────────
  /// Headlines and primary copy. Warm near-black.
  static const Color textPrimary = Color(0xFF1C1917);

  /// Body copy, descriptions, supporting sentences.
  static const Color textSecondary = Color(0xFF6F6660);

  /// Metadata, placeholders, disabled labels.
  static const Color textTertiary = Color(0xFFA39A92);

  /// Text drawn on [ink] or on the brand accent.
  static const Color textOnDark = Color(0xFFFAF7F2);

  // ── Brand ──────────────────────────────────────────────────────────────
  /// Primary accent. Active nav, links, key affordances.
  static const Color accent = Color(0xFF8B6347);

  /// Soft accent. Selected chip fills, tinted icon wells.
  static const Color accentSoft = Color(0xFFEDE3D8);

  /// Pressed accent state.
  static const Color accentDeep = Color(0xFF5C3D22);

  /// Gilded highlight — rules under headlines, premium markers.
  static const Color gold = Color(0xFFC4A882);

  // ── Signals ────────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFC0392B);
  static const Color warning = Color(0xFFD4870A);
  static const Color success = Color(0xFF3F7D58);
  static const Color info = Color(0xFF5B6E8C);

  /// Soft signal washes for badge and banner backgrounds.
  static const Color dangerSoft = Color(0xFFFBEDEB);
  static const Color warningSoft = Color(0xFFFDF3E3);
  static const Color successSoft = Color(0xFFECF3EF);

  // ── Structural ─────────────────────────────────────────────────────────
  /// Hairline rules. Barely visible — structure, not decoration.
  static const Color line = Color(0xFFEAE4DC);

  /// Stronger divider for section breaks.
  static const Color lineStrong = Color(0xFFDCD3C8);

  /// Scrim behind modals and bottom sheets.
  static const Color scrim = Color(0x591C1917);

  // ── Pre-computed alpha variants ────────────────────────────────────────
  // Declared as consts so they never allocate inside build()/paint().
  static const Color inkA04 = Color(0x0A1C1917);
  static const Color inkA08 = Color(0x141C1917);
  static const Color inkA12 = Color(0x1F1C1917);
  static const Color inkA55 = Color(0x8C1C1917);
  static const Color inkA70 = Color(0xB31C1917);
  static const Color surfaceA80 = Color(0xCCFFFFFF);
  static const Color surfaceA92 = Color(0xEBFFFFFF);
  static const Color accentA12 = Color(0x1F8B6347);

  // ── Gradients ──────────────────────────────────────────────────────────
  /// Bottom-up scrim over editorial photography so text stays legible.
  static const LinearGradient photoScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color(0xB31C1917),
      Color(0x4D1C1917),
      Color(0x001C1917),
    ],
  );

  /// Skeleton shimmer sweep on warm surfaces.
  static const LinearGradient shimmerSweep = LinearGradient(
    stops: [0.0, 0.5, 1.0],
    colors: [
      Color(0xFFEFE9E1),
      Color(0xFFF8F4EF),
      Color(0xFFEFE9E1),
    ],
  );

  /// Warm wash used behind editorial banner cards.
  static const LinearGradient bannerWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6F1EA), Color(0xFFEFE7DC)],
  );
}