import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';
import 'app_product_card.dart';

/// The four things a data-backed screen can be showing: content, nothing,
/// a failure, or a success confirmation. These give all three non-content
/// states one consistent, unhurried treatment instead of a bare `Text('No
/// items')` per screen.
class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Color iconColor;
  final Color iconBackground;

  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.iconColor = AppPalette.accent,
    this.iconBackground = AppPalette.accentSoft,
  });

  /// Nothing here yet — an empty wishlist, no search results, no orders.
  const AppStateView.empty({
    super.key,
    this.icon = Icons.checkroom_outlined,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  })  : iconColor = AppPalette.accent,
        iconBackground = AppPalette.accentSoft;

  /// Something went wrong — network failure, permission denied.
  const AppStateView.error({
    super.key,
    this.icon = Icons.wifi_off_rounded,
    this.title = 'Something went wrong',
    this.message =
        'We couldn\'t load this just now. Check your connection and try again.',
    this.actionLabel = 'Try Again',
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  })  : iconColor = AppPalette.danger,
        iconBackground = AppPalette.dangerSoft;

  /// A completed action — order placed, profile saved.
  const AppStateView.success({
    super.key,
    this.icon = Icons.check_rounded,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  })  : iconColor = AppPalette.success,
        iconBackground = AppPalette.successSoft;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppType.displayMedium.responsive(context),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppType.bodyMedium,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: actionLabel!, onPressed: onAction),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton.ghost(
                  label: secondaryActionLabel!,
                  onPressed: onSecondaryAction,
                  fullWidth: true,
                  trailingIcon: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A centred brand spinner for full-screen waits.
class AppLoader extends StatelessWidget {
  final String? message;

  const AppLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppPalette.accent,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: AppType.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// A grid of product skeletons sized exactly like the real grid, so the
/// transition from loading to loaded doesn't shift anything on screen.
class AppProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const AppProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: AppProductGridDelegate.of(context),
      itemCount: itemCount,
      itemBuilder: (_, __) => const AppProductCardSkeleton(),
    );
  }
}

/// Sliver form of [AppProductGridSkeleton] for `CustomScrollView` screens.
class AppSliverProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const AppSliverProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
      sliver: SliverGrid(
        gridDelegate: AppProductGridDelegate.of(context),
        delegate: SliverChildBuilderDelegate(
          (_, __) => const AppProductCardSkeleton(),
          childCount: itemCount,
        ),
      ),
    );
  }
}
