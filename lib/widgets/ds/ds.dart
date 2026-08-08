/// InstaStyle Design System.
///
/// One import gives a screen the full vocabulary — tokens and components:
///
/// ```dart
/// import '../widgets/ds/ds.dart';
/// ```
///
/// Rules of the road:
///   • Never hard-code a colour, radius, duration or gap. Reach for
///     [AppPalette], [AppRadii], [AppMotion], [AppSpacing].
///   • Never re-implement a button, card, chip, sheet or empty state. If a
///     component is *nearly* right, extend it here rather than forking it into
///     a screen — that is how the old per-screen `_C`/`_T` token blocks grew.
///   • Screen-specific composition stays in the screen. Anything used twice
///     belongs in this folder.
library;

export '../../theme/app_colors.dart';
export '../../theme/app_dimens.dart';
export '../../theme/app_theme.dart';
export '../../theme/app_typography.dart';
export 'app_badge.dart';
export 'app_button.dart';
export 'app_chip.dart';
export 'app_image.dart';
export 'app_input.dart';
export 'app_navigation.dart';
export 'app_overlays.dart';
export 'app_product_card.dart';
export 'app_progress_overlay.dart';
export 'app_shimmer.dart';
export 'app_state_views.dart';
export 'app_surfaces.dart';
