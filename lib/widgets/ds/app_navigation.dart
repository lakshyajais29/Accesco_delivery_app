import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';

/// The branded home app bar: serif wordmark on the left, icon actions right.
class AppBrandBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;
  final VoidCallback? onLogoTap;

  const AppBrandBar({super.key, this.actions = const [], this.onLogoTap});

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.canvas,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
      ),
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
          child: Row(
            children: [
              GestureDetector(
                onTap: onLogoTap,
                child: RichText(
                  text: TextSpan(
                    style: AppType.wordmark,
                    children: const [
                      TextSpan(text: 'Insta'),
                      TextSpan(
                        text: 'Style',
                        style: TextStyle(color: AppPalette.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// A standard interior-screen app bar: back arrow, centred title, actions.
/// Use in place of Material's [AppBar] so titles, spacing and the back
/// affordance stay identical on every pushed route.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool centerTitle;

  /// Use the serif voice for the title. Good for feature screens
  /// ("Virtual Try-On"), less so for utility screens.
  final bool serif;

  /// Transparent background for bars that float over photography.
  final bool transparent;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.centerTitle = true,
    this.serif = false,
    this.transparent = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final foreground =
        transparent ? AppPalette.textOnDark : AppPalette.textPrimary;

    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (serif ? AppType.displaySmall : AppType.titleMedium)
              .copyWith(color: foreground),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: AppType.bodySmall.copyWith(
              color: transparent
                  ? AppPalette.textOnDark.withValues(alpha: 0.7)
                  : AppPalette.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    return Container(
      color: transparent ? Colors.transparent : AppPalette.canvas,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.page(context) - AppSpacing.xs,
          ),
          child: Row(
            children: [
              if (canPop || onBack != null)
                AppIconButton(
                  icon: Icons.arrow_back,
                  color: foreground,
                  filled: transparent,
                  background: transparent ? AppPalette.inkA55 : null,
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: AppSpacing.xs),
              if (centerTitle) ...[
                Expanded(child: Center(child: titleBlock)),
              ] else ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: titleBlock),
              ],
              ...actions,
              // Balances the leading back button so a centred title stays
              // optically centred when there are no actions.
              if (centerTitle && actions.isEmpty)
                const SizedBox(width: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// One destination in [AppBottomNav].
class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Count bubble on the icon. Zero hides it.
  final int badgeCount;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

/// The app's bottom navigation. A hairline top rule, warm accent for the
/// active destination, and a sliding indicator that tracks selection.
class AppBottomNav extends StatelessWidget {
  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(top: BorderSide(color: AppPalette.line)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavDestination(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () {
                    if (i != currentIndex) HapticFeedback.selectionClick();
                    onTap(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppPalette.accent : AppPalette.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active indicator — a short rule above the icon.
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              height: 2,
              width: selected ? 18 : 0,
              decoration: const BoxDecoration(
                color: AppPalette.accent,
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _Badged(
              count: item.badgeCount,
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 21,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs + 1),
            Text(
              item.label.toUpperCase(),
              style: AppType.badge.copyWith(
                fontSize: 8,
                letterSpacing: 0.8,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Local count bubble — kept private so [AppBottomNav] has no dependency on
/// the badge module's layout choices.
class _Badged extends StatelessWidget {
  final int count;
  final Widget child;

  const _Badged({required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -7,
          child: Container(
            constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: AppPalette.danger,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                count > 9 ? '9+' : '$count',
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
