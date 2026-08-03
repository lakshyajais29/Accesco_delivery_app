import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';

enum AppBadgeTone { neutral, accent, danger, warning, success, inverse }

/// A small ALL CAPS marker overlaid on imagery or set beside a title —
/// "NEW", "SALE", "ONLY 2 LEFT", "SOLD OUT".
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  /// Softens the fill to a tinted wash with coloured text, for badges that sit
  /// on a light surface rather than over a photo.
  final bool soft;

  const AppBadge(
    this.label, {
    super.key,
    this.tone = AppBadgeTone.inverse,
    this.icon,
    this.soft = false,
  });

  ({Color bg, Color fg}) get _colors {
    if (soft) {
      return switch (tone) {
        AppBadgeTone.accent => (
            bg: AppPalette.accentSoft,
            fg: AppPalette.accentDeep
          ),
        AppBadgeTone.danger => (
            bg: AppPalette.dangerSoft,
            fg: AppPalette.danger
          ),
        AppBadgeTone.warning => (
            bg: AppPalette.warningSoft,
            fg: AppPalette.warning
          ),
        AppBadgeTone.success => (
            bg: AppPalette.successSoft,
            fg: AppPalette.success
          ),
        AppBadgeTone.neutral || AppBadgeTone.inverse => (
            bg: AppPalette.surfaceMuted,
            fg: AppPalette.textSecondary
          ),
      };
    }
    return switch (tone) {
      AppBadgeTone.accent => (
          bg: AppPalette.accent,
          fg: AppPalette.textOnDark
        ),
      AppBadgeTone.danger => (
          bg: AppPalette.danger,
          fg: AppPalette.textOnDark
        ),
      AppBadgeTone.warning => (
          bg: AppPalette.warning,
          fg: AppPalette.textOnDark
        ),
      AppBadgeTone.success => (
          bg: AppPalette.success,
          fg: AppPalette.textOnDark
        ),
      AppBadgeTone.neutral => (
          bg: AppPalette.surface,
          fg: AppPalette.textPrimary
        ),
      AppBadgeTone.inverse => (
          bg: AppPalette.ink,
          fg: AppPalette.textOnDark
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs - 1,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.badge,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: c.fg),
            const SizedBox(width: 3),
          ],
          Text(
            label.toUpperCase(),
            style: AppType.badge.copyWith(color: c.fg),
          ),
        ],
      ),
    );
  }
}

/// A numeric count bubble anchored to an icon — unread notifications, cart
/// quantity. Renders nothing at zero so callers don't need the null check.
class AppCountBadge extends StatelessWidget {
  final int count;
  final Widget child;
  final Color color;

  const AppCountBadge({
    super.key,
    required this.count,
    required this.child,
    this.color = AppPalette.danger,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -5,
          right: -6,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.surface, width: 1.5),
            ),
            child: Center(
              child: Text(
                count > 99 ? '99+' : '$count',
                style: AppType.badge.copyWith(
                  fontSize: 8,
                  letterSpacing: 0,
                  color: AppPalette.textOnDark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An inline metadata line under a card — "Only 2 left", "12 ordered today".
/// Keeps the icon/label/colour rhythm consistent across every rail.
class AppSignalTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const AppSignalTag({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.bodySmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
