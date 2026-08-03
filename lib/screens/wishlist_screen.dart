import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../services/wishlist_service.dart';
import '../widgets/ds/ds.dart';
import 'product_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WISHLIST — saved pieces.
//
//  Reads straight from [WishlistService]. Because that service is now a
//  ChangeNotifier, this screen no longer copies the list into local state and
//  re-reads it after every mutation — it rebuilds from the single source of
//  truth, so a heart toggled on the home grid is reflected here immediately.
// ─────────────────────────────────────────────────────────────────────────────

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    // Pull anything saved on another device before painting the grid.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WishlistService.instance.load();
    });
  }

  void _remove(ParentProduct product) {
    WishlistService.instance.toggle(product);
    AppSnack.show(
      context,
      '${product.name} removed',
      icon: Icons.heart_broken_outlined,
      actionLabel: 'Undo',
      onAction: () => WishlistService.instance.toggle(product),
    );
  }

  Future<void> _confirmClearAll(List<ParentProduct> items) async {
    final confirmed = await showAppDialog(
      context,
      icon: Icons.delete_outline,
      title: 'Clear wishlist?',
      message:
          'This removes all ${items.length} saved pieces. You can always add '
          'them again.',
      confirmLabel: 'Clear All',
      destructive: true,
    );

    if (confirmed != true || !mounted) return;
    for (final product in List<ParentProduct>.of(items)) {
      WishlistService.instance.toggle(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: ListenableBuilder(
          listenable: WishlistService.instance,
          builder: (context, _) {
            final service = WishlistService.instance;
            final items = service.items;

            return Column(
              children: [
                AppTopBar(
                  title: 'Wishlist',
                  subtitle: items.isEmpty
                      ? null
                      : '${items.length} saved '
                          '${items.length == 1 ? 'piece' : 'pieces'}',
                  serif: true,
                  actions: [
                    if (items.isNotEmpty)
                      AppIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Clear all',
                        onPressed: () => _confirmClearAll(items),
                      ),
                  ],
                ),
                if (service.isSyncing && items.isEmpty)
                  const Expanded(child: AppProductGridSkeleton())
                else if (items.isEmpty)
                  Expanded(
                    child: AppStateView.empty(
                      icon: Icons.favorite_border,
                      title: 'Nothing saved yet',
                      message: 'Tap the heart on any piece and it will wait '
                          'for you here.',
                      actionLabel: 'Start Browsing',
                      onAction: () => Navigator.of(context).maybePop(),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => service.load(force: true),
                      color: AppPalette.accent,
                      backgroundColor: AppPalette.surface,
                      child: GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          inset,
                          AppSpacing.md,
                          inset,
                          AppSpacing.safeBottom(
                            context,
                            extra: AppSpacing.xxl,
                          ),
                        ),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        gridDelegate: AppProductGridDelegate.of(context),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final product = items[i];
                          final heroTag = 'wishlist-${product.id}-$i';
                          return AppProductCard(
                            name: product.name,
                            subtitle: product.brand,
                            imageUrl: product.defaultImageUrl,
                            price: product.price,
                            originalPrice: product.originalPriceFormatted,
                            heroTag: heroTag,
                            soldOut: product.stock <= 0,
                            isWishlisted: true,
                            onWishlistToggle: () => _remove(product),
                            badge: product.stock > 0 && product.stock < 4
                                ? AppBadge(
                                    'Only ${product.stock} left',
                                    tone: AppBadgeTone.danger,
                                  )
                                : null,
                            onTap: () => Navigator.push(
                              context,
                              ProductDetailScreen.route(
                                product,
                                heroTag: heroTag,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
