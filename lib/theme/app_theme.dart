import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// The single [ThemeData] for the app.
///
/// Anything configured here — input borders, snackbar shape, dialog radius,
/// page transitions — does not need to be re-specified at call sites. Screens
/// should reach for `Theme.of(context)` or the [AppPalette] / [AppType] tokens
/// rather than inventing local colours.
/// ═══════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  /// Status/navigation bar styling for light (ivory) screens.
  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppPalette.canvas,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// Status bar styling for screens whose top area is dark photography
  /// (product hero, swipe deck, try-on camera).
  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppPalette.ink,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppPalette.accent,
      onPrimary: AppPalette.textOnDark,
      primaryContainer: AppPalette.accentSoft,
      onPrimaryContainer: AppPalette.accentDeep,
      secondary: AppPalette.gold,
      onSecondary: AppPalette.ink,
      surface: AppPalette.surface,
      onSurface: AppPalette.textPrimary,
      surfaceContainerHighest: AppPalette.surfaceMuted,
      onSurfaceVariant: AppPalette.textSecondary,
      error: AppPalette.danger,
      onError: AppPalette.textOnDark,
      outline: AppPalette.line,
      outlineVariant: AppPalette.lineStrong,
      shadow: AppPalette.inkA12,
      scrim: AppPalette.scrim,
      inverseSurface: AppPalette.ink,
      onInverseSurface: AppPalette.textOnDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.canvas,
      canvasColor: AppPalette.canvas,
      dividerColor: AppPalette.line,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: AppPalette.inkA04,

      // ── Typography ──────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: AppType.displayLarge,
        displayMedium: AppType.displayMedium,
        displaySmall: AppType.displaySmall,
        headlineMedium: AppType.displayMedium,
        headlineSmall: AppType.displaySmall,
        titleLarge: AppType.titleLarge,
        titleMedium: AppType.titleMedium,
        titleSmall: AppType.titleSmall,
        bodyLarge: AppType.bodyLarge,
        bodyMedium: AppType.bodyMedium,
        bodySmall: AppType.bodySmall,
        labelLarge: AppType.label,
        labelMedium: AppType.overline,
        labelSmall: AppType.badge.copyWith(color: AppPalette.textSecondary),
      ),

      // ── App bar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.titleLarge,
        iconTheme: const IconThemeData(
          color: AppPalette.textPrimary,
          size: 22,
        ),
        systemOverlayStyle: lightOverlay,
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.ink,
          foregroundColor: AppPalette.textOnDark,
          disabledBackgroundColor: AppPalette.surfaceSunken,
          disabledForegroundColor: AppPalette.textTertiary,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: AppType.button,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.field),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.textPrimary,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: AppType.button.copyWith(color: AppPalette.textPrimary),
          side: const BorderSide(color: AppPalette.lineStrong),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.field),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.accent,
          textStyle: AppType.label.copyWith(
            fontWeight: FontWeight.w600,
            color: AppPalette.accent,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppPalette.textPrimary,
          highlightColor: AppPalette.inkA08,
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppType.bodyMedium.copyWith(color: AppPalette.textTertiary),
        labelStyle: AppType.bodyMedium,
        floatingLabelStyle: AppType.bodySmall.copyWith(
          color: AppPalette.accent,
          letterSpacing: 0.6,
        ),
        helperStyle: AppType.bodySmall,
        errorStyle: AppType.bodySmall.copyWith(color: AppPalette.danger),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: AppPalette.line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: AppPalette.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: AppPalette.accent, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: AppPalette.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: AppPalette.danger, width: 1.4),
        ),
      ),

      // ── Surfaces ────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.dialog),
        titleTextStyle: AppType.displaySmall,
        contentTextStyle: AppType.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.bottomSheet),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.ink,
        contentTextStyle: AppType.bodyMedium.copyWith(
          color: AppPalette.textOnDark,
        ),
        actionTextColor: AppPalette.gold,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.field),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.line,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surface,
        selectedColor: AppPalette.ink,
        surfaceTintColor: Colors.transparent,
        labelStyle: AppType.label,
        side: const BorderSide(color: AppPalette.line),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.chip),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.accent,
        linearTrackColor: AppPalette.surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppPalette.ink,
          borderRadius: AppRadii.badge,
        ),
        textStyle: AppType.bodySmall.copyWith(color: AppPalette.textOnDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        selectedItemColor: AppPalette.accent,
        unselectedItemColor: AppPalette.textTertiary,
        selectedLabelStyle: AppType.badge.copyWith(
          color: AppPalette.accent,
        ),
        unselectedLabelStyle: AppType.badge.copyWith(
          color: AppPalette.textTertiary,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Motion ──────────────────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionBuilder(),
        },
      ),
    );
  }
}

/// A restrained fade-and-rise page transition.
///
/// Material's default Android transition is a hard vertical slide, which reads
/// as utilitarian next to the editorial surfaces here. This fades the incoming
/// page in while lifting it a few points — closer to how the reference screens
/// are meant to feel.
class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
