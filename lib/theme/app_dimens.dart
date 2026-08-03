import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SPACING — a 4pt scale. Never hard-code a gap; pick the nearest step.
/// ═══════════════════════════════════════════════════════════════════════════
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 56;

  /// Standard horizontal page inset. Scales up on wider devices so content
  /// never stretches edge-to-edge on a tablet.
  static double page(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.expanded) return xxxl;
    if (width >= AppBreakpoints.medium) return xxl;
    if (width < 360) return sm;
    return md;
  }

  /// Bottom padding that clears the home indicator plus a comfortable gap.
  static double safeBottom(BuildContext context, {double extra = md}) =>
      MediaQuery.paddingOf(context).bottom + extra;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// RADII — rounded surfaces signal comfort; only badges stay tight.
/// ═══════════════════════════════════════════════════════════════════════════
class AppRadii {
  AppRadii._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double sheet = 28;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius image = BorderRadius.all(Radius.circular(md));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius badge = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius bottomSheet =
      BorderRadius.vertical(top: Radius.circular(sheet));
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ELEVATION — soft, warm, low-contrast. Shadows suggest lift, never drama.
/// ═══════════════════════════════════════════════════════════════════════════
class AppShadows {
  AppShadows._();

  /// Resting cards.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D1C1917),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Raised elements — floating action bars, selected cards.
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x141C1917),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Sheets, dialogs, sticky bars that overlap scrolling content.
  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: Color(0x1F1C1917),
      blurRadius: 32,
      offset: Offset(0, -4),
    ),
  ];

  /// Pressed / inset state — no shadow, just a tightened outline.
  static const List<BoxShadow> none = [];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// MOTION — one easing family, three speeds. Consistency reads as quality.
/// ═══════════════════════════════════════════════════════════════════════════
class AppMotion {
  AppMotion._();

  /// Micro-interactions: taps, chip selection, icon state.
  static const Duration fast = Duration(milliseconds: 180);

  /// Standard: expand/collapse, cross-fade, list reorder.
  static const Duration normal = Duration(milliseconds: 300);

  /// Deliberate: page transitions, sheet presentation, hero flights.
  static const Duration slow = Duration(milliseconds: 460);

  /// Entrance easing — decelerates into place. The house curve.
  static const Curve enter = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Exit easing — accelerates away.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric easing for reversible state (chips, toggles).
  static const Curve standard = Curves.easeOutCubic;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// BREAKPOINTS — phone → large phone → tablet.
/// ═══════════════════════════════════════════════════════════════════════════
class AppBreakpoints {
  AppBreakpoints._();

  /// Large phones and small foldables.
  static const double medium = 600;

  /// Tablets and desktop-class widths.
  static const double expanded = 900;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < medium;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  /// Product grid column count for the current width. Keeps card width in a
  /// readable band from a 320pt phone to a 1024pt tablet.
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) return 5;
    if (width >= AppBreakpoints.expanded) return 4;
    if (width >= AppBreakpoints.medium) return 3;
    return 2;
  }

  /// Caps content width on tablets so text lines stay readable.
  static double contentMaxWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded ? 720 : double.infinity;
}

/// A hairline rule at the design-system's line colour.
///
/// `Divider` with the right thickness/colour spelled out every time is noise;
/// this is the one-liner used everywhere instead.
class AppDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  final Color? color;

  const AppDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
      color: color ?? AppPalette.line,
    );
  }
}
