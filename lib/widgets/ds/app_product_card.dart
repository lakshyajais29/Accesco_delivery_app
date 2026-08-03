import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import 'app_badge.dart';
import 'app_image.dart';
import 'app_shimmer.dart';

/// Portrait ratio of the product photograph. Fashion imagery is shot tall;
/// this is the single constant that keeps every grid and rail aligned.
const double kProductImageRatio = 3 / 4;

/// Height of the text block beneath the photo (name + meta + price).
const double kProductInfoHeight = 66;

/// The product card. One implementation serves the home rails, search results,
/// wishlist, thrift listings and "similar items" — sized by its parent rather
/// than hard-coding dimensions, so the same widget works in a fixed-width
/// horizontal rail and a responsive grid.
class AppProductCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String price;

  /// Struck-through original price. Null when the item isn't on sale.
  final String? originalPrice;

  /// Brand or category line under the name.
  final String? subtitle;

  final VoidCallback onTap;

  /// Hero tag shared with the detail screen. Null disables the flight.
  final String? heroTag;

  final bool isWishlisted;
  final VoidCallback? onWishlistToggle;

  /// Overlaid at the top-left of the photo — "NEW", "SALE", rank.
  final Widget? badge;

  /// A single metadata line under the price — stock, delivery, social proof.
  final Widget? signal;

  /// Dims the photo and stamps it when the item can't be bought.
  final bool soldOut;

  const AppProductCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.onTap,
    this.originalPrice,
    this.subtitle,
    this.heroTag,
    this.isWishlisted = false,
    this.onWishlistToggle,
    this.badge,
    this.signal,
    this.soldOut = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget photo = AppImage(
      url: imageUrl,
      fit: BoxFit.cover,
      cacheWidth: 400,
    );

    if (heroTag != null) {
      photo = Hero(tag: heroTag!, child: photo);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Photograph ────────────────────────────────────────────────
          AspectRatio(
            aspectRatio: kProductImageRatio,
            child: ClipRRect(
              borderRadius: AppRadii.image,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppPalette.surfaceMuted, child: photo),
                  if (soldOut)
                    const ColoredBox(
                      color: AppPalette.inkA55,
                      child: Center(
                        child: AppBadge('Sold Out', tone: AppBadgeTone.neutral),
                      ),
                    ),
                  if (badge != null)
                    Positioned(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: badge!,
                    ),
                  if (onWishlistToggle != null)
                    Positioned(
                      top: AppSpacing.xxs,
                      right: AppSpacing.xxs,
                      child: _WishlistHeart(
                        isWishlisted: isWishlisted,
                        onToggle: onWishlistToggle!,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Detail ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs + 2,
              left: AppSpacing.xxs,
              right: AppSpacing.xxs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppType.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: AppType.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        price,
                        style: AppType.price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (originalPrice != null) ...[
                      const SizedBox(width: AppSpacing.xxs + 1),
                      Flexible(
                        child: Text(
                          originalPrice!,
                          style: AppType.priceStrike,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (signal != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  signal!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The wishlist heart overlaid on a product photo. Animates on toggle so the
/// tap registers even though the icon barely changes shape.
class _WishlistHeart extends StatelessWidget {
  final bool isWishlisted;
  final VoidCallback onToggle;

  const _WishlistHeart({required this.isWishlisted, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onToggle();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: AppPalette.surfaceA92,
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              isWishlisted ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(isWishlisted),
              size: 16,
              color:
                  isWishlisted ? AppPalette.danger : AppPalette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder matching [AppProductCard]'s silhouette exactly, so the
/// grid doesn't reflow when real data arrives.
class AppProductCardSkeleton extends StatelessWidget {
  const AppProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AspectRatio(
          aspectRatio: kProductImageRatio,
          child: AppShimmer(borderRadius: AppRadii.image),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppShimmer.text(width: 100, height: 11),
        const SizedBox(height: AppSpacing.xs),
        AppShimmer.text(width: 62, height: 9),
        const SizedBox(height: AppSpacing.xs),
        AppShimmer.text(width: 46, height: 11),
      ],
    );
  }
}

/// Layout maths for product grids.
///
/// A grid needs `childAspectRatio`, but the card's height is *photo height +
/// fixed text block*, which depends on the column width. Computing that by
/// hand at each call site is where inconsistent grids come from — this derives
/// it from the current width, column count and gutter.
class AppProductGridDelegate {
  AppProductGridDelegate._();

  static SliverGridDelegate of(
    BuildContext context, {
    double spacing = AppSpacing.md,
    int? columns,
  }) {
    final cols = columns ?? AppBreakpoints.gridColumns(context);
    final inset = AppSpacing.page(context);
    final available =
        MediaQuery.sizeOf(context).width - (inset * 2) - (spacing * (cols - 1));
    final itemWidth = available / cols;
    final itemHeight = (itemWidth / kProductImageRatio) + kProductInfoHeight;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: cols,
      mainAxisSpacing: AppSpacing.xl,
      crossAxisSpacing: spacing,
      childAspectRatio: itemWidth / itemHeight,
    );
  }

  /// Fixed card width for horizontal rails, sized so roughly 2.4 cards are
  /// visible on a phone — enough to signal the rail scrolls.
  static double railCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.expanded) return 210;
    if (width >= AppBreakpoints.medium) return 190;
    return (width - (AppSpacing.page(context) * 2) - AppSpacing.md) / 2.25;
  }

  /// Total rail height for a card of [railCardWidth], including the text block
  /// and an optional extra allowance for a signal line.
  static double railHeight(BuildContext context, {double extra = 0}) =>
      (railCardWidth(context) / kProductImageRatio) +
      kProductInfoHeight +
      extra;
}
