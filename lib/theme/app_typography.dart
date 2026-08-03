import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// INSTASTYLE TYPE SCALE
///
/// Two voices, used with discipline:
///
///   • Cormorant Garamond — the *editorial* voice. Banner headlines, screen
///     titles, product names on detail pages. Never below 18px, never ALL CAPS.
///   • Jost — the *interface* voice. Everything else: eyebrows, labels, body,
///     buttons, prices, metadata.
///
/// Every style is a `static final` (not a getter) so `GoogleFonts.x()` resolves
/// exactly once per style for the whole app instead of on every `build()`.
/// Use `.copyWith(color: …)` at the call site when a variant colour is needed.
/// ═══════════════════════════════════════════════════════════════════════════
class AppType {
  AppType._();

  // ── Editorial / serif display ──────────────────────────────────────────
  /// Banner hero headline. "Fashion, Refined".
  static final displayLarge = GoogleFonts.cormorantGaramond(
    fontSize: 34,
    fontWeight: FontWeight.w600,
    height: 1.06,
    letterSpacing: -0.4,
    color: AppPalette.textPrimary,
  );

  /// Screen titles, sheet titles, section features.
  static final displayMedium = GoogleFonts.cormorantGaramond(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.12,
    letterSpacing: -0.2,
    color: AppPalette.textPrimary,
  );

  /// Product names on detail pages, card feature titles.
  static final displaySmall = GoogleFonts.cormorantGaramond(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppPalette.textPrimary,
  );

  /// The wordmark. Slightly tracked-out serif.
  static final wordmark = GoogleFonts.cormorantGaramond(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 0.4,
    color: AppPalette.textPrimary,
  );

  // ── Interface / sans ───────────────────────────────────────────────────
  /// Small tracked-out ALL CAPS kicker above a headline. "THE STUDIO".
  static final eyebrow = GoogleFonts.jost(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 2.4,
    color: AppPalette.textSecondary,
  );

  /// Section headers, tab labels, refine/sort bar. ALL CAPS.
  static final overline = GoogleFonts.jost(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1.6,
    color: AppPalette.textPrimary,
  );

  /// Sans title — list rows, card headers, dialog titles.
  static final titleLarge = GoogleFonts.jost(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.1,
    color: AppPalette.textPrimary,
  );

  static final titleMedium = GoogleFonts.jost(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.1,
    color: AppPalette.textPrimary,
  );

  /// Product card name.
  static final titleSmall = GoogleFonts.jost(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.1,
    color: AppPalette.textPrimary,
  );

  /// Default reading copy.
  static final bodyLarge = GoogleFonts.jost(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppPalette.textSecondary,
  );

  static final bodyMedium = GoogleFonts.jost(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppPalette.textSecondary,
  );

  /// Metadata, captions, helper text under inputs.
  static final bodySmall = GoogleFonts.jost(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppPalette.textTertiary,
  );

  /// Button text. Tracked slightly for weight at small sizes.
  static final button = GoogleFonts.jost(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 1.2,
    color: AppPalette.textOnDark,
  );

  /// Chip / tag / badge label.
  static final label = GoogleFonts.jost(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.4,
    color: AppPalette.textPrimary,
  );

  /// Micro ALL CAPS badge. "NEW", "SALE", "SOLD OUT".
  static final badge = GoogleFonts.jost(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1.0,
    color: AppPalette.textOnDark,
  );

  // ── Numeric ────────────────────────────────────────────────────────────
  /// Prices. Tabular figures so columns of prices align in grids.
  static final price = GoogleFonts.jost(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppPalette.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final priceLarge = GoogleFonts.jost(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppPalette.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Struck-through original price beside a sale price.
  static final priceStrike = GoogleFonts.jost(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: AppPalette.textTertiary,
    decoration: TextDecoration.lineThrough,
    decorationColor: AppPalette.textTertiary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Countdown timers, ETAs, order IDs — anything that must not reflow as it
  /// ticks. Monospaced with tabular figures.
  static final mono = GoogleFonts.robotoMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppPalette.textSecondary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Text scaling helper for small phones through tablets.
///
/// Rather than scattering `MediaQuery` maths through screens, call
/// `AppType.displayLarge.responsive(context)` to nudge display sizes down on
/// narrow devices and up on tablets, leaving body copy at the user's own
/// accessibility text scale.
extension ResponsiveTextStyle on TextStyle {
  TextStyle responsive(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final factor = width < 360
        ? 0.92
        : width >= 900
            ? 1.12
            : width >= 600
                ? 1.06
                : 1.0;
    if (factor == 1.0) return this;
    return copyWith(fontSize: (fontSize ?? 14) * factor);
  }
}
