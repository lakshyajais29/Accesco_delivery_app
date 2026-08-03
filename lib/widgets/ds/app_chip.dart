import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';

/// A selectable pill — filters, sizes, colours, tags.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Renders the chip as unavailable: struck through and non-interactive.
  /// Used for out-of-stock sizes so the option stays visible but clearly dead.
  final bool disabled;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = disabled
        ? AppPalette.textTertiary
        : selected
            ? AppPalette.textOnDark
            : AppPalette.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      child: GestureDetector(
        onTap: disabled || onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!.call();
              },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 1,
          ),
          decoration: BoxDecoration(
            color: selected ? AppPalette.ink : AppPalette.surface,
            borderRadius: AppRadii.chip,
            border: Border.all(
              color: selected ? AppPalette.ink : AppPalette.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: foreground),
                const SizedBox(width: AppSpacing.xxs + 1),
              ],
              Text(
                label,
                style: AppType.label.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  decoration: disabled ? TextDecoration.lineThrough : null,
                  decorationColor: AppPalette.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A colour swatch selector for product variants.
class AppColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final bool available;
  final VoidCallback? onTap;
  final double size;

  const AppColorSwatch({
    super.key,
    required this.color,
    this.selected = false,
    this.available = true,
    this.onTap,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: available && onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!.call();
            }
          : null,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: size + 8,
        height: size + 8,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppPalette.ink : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppPalette.line),
          ),
          child: available
              ? null
              : const Center(
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppPalette.textOnDark,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The circular category tile from the reference screens — an icon well above
/// a tracked-out caps label, with the active entry filling in.
class AppCategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppCategoryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      selected ? AppPalette.accentSoft : AppPalette.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppPalette.accent : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? AppPalette.accentDeep
                      : AppPalette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppType.eyebrow.copyWith(
                  fontSize: 8.5,
                  letterSpacing: 1.1,
                  color: selected
                      ? AppPalette.textPrimary
                      : AppPalette.textTertiary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of [AppCategoryTile]s with page insets applied.
class AppCategoryRow extends StatelessWidget {
  final List<({IconData icon, String label})> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppCategoryRow({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: inset),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => AppCategoryTile(
          icon: items[i].icon,
          label: items[i].label,
          selected: i == selectedIndex,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}
