import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';

enum AppButtonVariant {
  /// Solid ink. The single most important action on a screen.
  primary,

  /// Outlined. Secondary actions that sit beside a primary.
  secondary,

  /// Warm brand fill. Promotional / delight actions.
  accent,

  /// Text-only with no chrome. Tertiary actions, inline links.
  ghost,

  /// Solid danger. Destructive confirmation only.
  danger,
}

enum AppButtonSize { small, medium, large }

/// The app's button. Every tappable command should be one of these rather than
/// a bespoke `GestureDetector` + `Container`.
///
/// Handles the details that make a button feel expensive: a subtle scale-down
/// on press, haptic feedback, an in-place loading spinner that preserves width
/// so the layout never jumps, and a disabled state that reads as deliberate.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool trailingIcon;
  final bool fullWidth;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.trailingIcon = false,
    this.fullWidth = true,
    this.isLoading = false,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.trailingIcon = false,
    this.fullWidth = true,
    this.isLoading = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.trailingIcon = true,
    this.fullWidth = false,
    this.isLoading = false,
  }) : variant = AppButtonVariant.ghost;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  double get _height => switch (widget.size) {
        AppButtonSize.small => 38,
        AppButtonSize.medium => 46,
        AppButtonSize.large => 54,
      };

  double get _horizontalPadding => switch (widget.size) {
        AppButtonSize.small => AppSpacing.md,
        AppButtonSize.medium => AppSpacing.lg,
        AppButtonSize.large => AppSpacing.xl,
      };

  double get _fontSize => switch (widget.size) {
        AppButtonSize.small => 11,
        AppButtonSize.medium => 12,
        AppButtonSize.large => 13,
      };

  ({Color background, Color foreground, Color? border}) get _colors {
    if (!_enabled) {
      return widget.variant == AppButtonVariant.ghost
          ? (
              background: Colors.transparent,
              foreground: AppPalette.textTertiary,
              border: null,
            )
          : (
              background: AppPalette.surfaceSunken,
              foreground: AppPalette.textTertiary,
              border: null,
            );
    }
    return switch (widget.variant) {
      AppButtonVariant.primary => (
          background: AppPalette.ink,
          foreground: AppPalette.textOnDark,
          border: null,
        ),
      AppButtonVariant.secondary => (
          background: Colors.transparent,
          foreground: AppPalette.textPrimary,
          border: AppPalette.lineStrong,
        ),
      AppButtonVariant.accent => (
          background: AppPalette.accent,
          foreground: AppPalette.textOnDark,
          border: null,
        ),
      AppButtonVariant.ghost => (
          background: Colors.transparent,
          foreground: AppPalette.accent,
          border: null,
        ),
      AppButtonVariant.danger => (
          background: AppPalette.danger,
          foreground: AppPalette.textOnDark,
          border: null,
        ),
    };
  }

  void _handleTap() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final isGhost = widget.variant == AppButtonVariant.ghost;

    final label = Text(
      widget.label.toUpperCase(),
      style: AppType.button.copyWith(
        color: c.foreground,
        fontSize: _fontSize,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final icon = widget.icon == null
        ? null
        : Icon(widget.icon, size: _fontSize + 4, color: c.foreground);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: _enabled
            ? (_) {
                setState(() => _pressed = false);
                _handleTap();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: _height,
            width: widget.fullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: isGhost ? AppSpacing.xs : _horizontalPadding,
            ),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: isGhost ? AppRadii.badge : AppRadii.field,
              border: c.border == null
                  ? null
                  : Border.all(color: c.border!, width: 1.2),
            ),
            child: Row(
              mainAxisSize:
                  widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: _fontSize + 4,
                    height: _fontSize + 4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.foreground,
                    ),
                  )
                else ...[
                  if (icon != null && !widget.trailingIcon) ...[
                    icon,
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(child: label),
                  if (icon != null && widget.trailingIcon) ...[
                    const SizedBox(width: AppSpacing.xs),
                    icon,
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular icon affordance — app bar actions, card overlays, wishlist
/// hearts. [filled] gives it a surface well; leave it false for bare icons.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? background;
  final bool filled;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 20,
    this.color,
    this.background,
    this.filled = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkResponse(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!.call();
            },
      radius: size + AppSpacing.sm,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: filled
            ? BoxDecoration(
                color: background ?? AppPalette.surfaceA92,
                shape: BoxShape.circle,
                boxShadow: background == null ? AppShadows.card : null,
              )
            : null,
        child: Icon(
          icon,
          size: size,
          color: color ??
              (onPressed == null
                  ? AppPalette.textTertiary
                  : AppPalette.textPrimary),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
