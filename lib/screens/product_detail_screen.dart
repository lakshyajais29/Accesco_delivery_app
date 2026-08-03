import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../services/cart_service.dart';
import '../services/catalog_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/ds/ds.dart';
import 'sku_variant_picker.dart';
import 'virtual_try_on_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PRODUCT DETAIL
//
//  A full-bleed hero photograph the content sheet scrolls up over, then the
//  editorial detail: brand, name, price, urgency signals, description and a
//  rail of related pieces. A sticky action bar carries try-on and add-to-bag.
//
//  Behaviour preserved from the original: hero flight from the originating
//  card, variant picker → CartService.addItem, wishlist toggle, virtual try-on
//  navigation, and CatalogService.getSimilarProducts for the rail.
// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailScreen extends StatefulWidget {
  final ParentProduct product;
  final String? heroTag;

  const ProductDetailScreen({super.key, required this.product, this.heroTag});

  static Route<void> route(ParentProduct product, {String? heroTag}) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ProductDetailScreen(product: product, heroTag: heroTag),
        transitionDuration: AppMotion.slow,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _scrollController = ScrollController();

  /// Drives the app bar's fade from transparent-over-photo to solid canvas.
  final _scrolledPastHero = ValueNotifier<bool>(false);

  late final List<ParentProduct> _similar;
  bool _isAddingToCart = false;

  double get _heroHeight =>
      (MediaQuery.sizeOf(context).height * 0.52).clamp(280.0, 560.0);

  @override
  void initState() {
    super.initState();
    _similar = CatalogService.getSimilarProducts(widget.product);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrolledPastHero.dispose();
    super.dispose();
  }

  void _onScroll() {
    // A ValueNotifier rather than setState: the app bar is the only thing that
    // depends on scroll position, so the rest of the page never rebuilds.
    final past = _scrollController.offset > _heroHeight - 120;
    if (past != _scrolledPastHero.value) _scrolledPastHero.value = past;
  }

  void _openVariantPicker() {
    VariantPickerSheet.show(
      context,
      parent: widget.product,
      onAddToCart: _addToCart,
    );
  }

  Future<void> _addToCart(CartPayload payload) async {
    setState(() => _isAddingToCart = true);
    try {
      await CartService.instance.addItem(payload);
      if (!mounted) return;
      AppSnack.success(
        context,
        '${payload.productName} · ${payload.size} added to bag',
      );
    } catch (error) {
      if (!mounted) return;
      // Most often this is the "not signed in" StateError from CartService.
      AppSnack.error(context, 'Could not add to bag. Please sign in first.');
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _toggleWishlist() {
    final wasWishlisted =
        WishlistService.instance.containsId(widget.product.id);
    WishlistService.instance.toggle(widget.product);
    AppSnack.show(
      context,
      wasWishlisted
          ? '${widget.product.name} removed from wishlist'
          : '${widget.product.name} saved to wishlist',
      icon: wasWishlisted ? Icons.heart_broken_outlined : Icons.favorite,
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final inset = AppSpacing.page(context);
    final heroHeight = _heroHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: Stack(
          children: [
            // ── Hero photograph, pinned behind the sheet ─────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight,
              child: Hero(
                tag: widget.heroTag ?? product.id,
                child: AppImage(url: product.defaultImageUrl),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppPalette.inkA55, Color(0x001C1917)],
                  ),
                ),
              ),
            ),

            // ── Scrolling content sheet ──────────────────────────────────
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: heroHeight - AppSpacing.xxl),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppPalette.canvas,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadii.sheet),
                      ),
                      boxShadow: AppShadows.overlay,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(child: AppSheetHandle()),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            inset,
                            AppSpacing.xs,
                            inset,
                            0,
                          ),
                          child: _buildDetail(product, context),
                        ),
                        if (_similar.isNotEmpty) _buildSimilarRail(),
                        // Clears the sticky action bar.
                        SizedBox(
                          height: AppSpacing.safeBottom(
                            context,
                            extra: 96,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Floating app bar ─────────────────────────────────────────
            ValueListenableBuilder<bool>(
              valueListenable: _scrolledPastHero,
              builder: (context, scrolled, _) => AnimatedContainer(
                duration: AppMotion.fast,
                color: scrolled ? AppPalette.canvas : Colors.transparent,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: inset - AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          AppIconButton(
                            icon: Icons.arrow_back,
                            filled: !scrolled,
                            background:
                                scrolled ? null : AppPalette.surfaceA92,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),
                          ListenableBuilder(
                            listenable: WishlistService.instance,
                            builder: (context, _) {
                              final saved = WishlistService.instance
                                  .containsId(product.id);
                              return AppIconButton(
                                icon: saved
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: saved ? AppPalette.danger : null,
                                filled: !scrolled,
                                background:
                                    scrolled ? null : AppPalette.surfaceA92,
                                tooltip: saved
                                    ? 'Remove from wishlist'
                                    : 'Save to wishlist',
                                onPressed: _toggleWishlist,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Sticky action bar ────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ActionBar(
                canBuy: product.stock > 0,
                isLoading: _isAddingToCart,
                onTryOn: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VirtualTryOnScreen(),
                  ),
                ),
                onAddToBag: _openVariantPicker,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(ParentProduct product, BuildContext context) {
    final signals = <Widget>[
      if (product.viewersNow > 0)
        AppBadge(
          '${product.viewersNow} viewing now',
          icon: Icons.visibility_outlined,
          tone: AppBadgeTone.neutral,
          soft: true,
        ),
      if (product.orderedToday > 0)
        AppBadge(
          '${product.orderedToday} ordered today',
          icon: Icons.local_fire_department_outlined,
          tone: AppBadgeTone.warning,
          soft: true,
        ),
      if (product.stock > 0 && product.stock < 4)
        AppBadge(
          'Only ${product.stock} left',
          icon: Icons.bolt_rounded,
          tone: AppBadgeTone.danger,
          soft: true,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Flexible(
              child: Text(
                product.brand.toUpperCase(),
                style: AppType.eyebrow.copyWith(color: AppPalette.accent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('·', style: AppType.eyebrow),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                product.category.toUpperCase(),
                style: AppType.eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (product.isNew) ...[
              const SizedBox(width: AppSpacing.xs),
              const AppBadge('New Drop', tone: AppBadgeTone.accent),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          product.name,
          style: AppType.displayLarge.responsive(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              product.lowestPrice,
              style: AppType.priceLarge.copyWith(fontSize: 24),
            ),
            if (product.originalPriceFormatted != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                product.originalPriceFormatted!,
                style: AppType.priceStrike.copyWith(fontSize: 15),
              ),
            ],
          ],
        ),
        if (signals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: signals,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const AppDivider(),
        const SizedBox(height: AppSpacing.lg),
        Text('About This Piece'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.xs),
        Text(product.description, style: AppType.bodyLarge),
        if (product.sizes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Available Sizes'.toUpperCase(), style: AppType.eyebrow),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final size in product.sizes)
                AppChip(
                  label: size,
                  disabled: !product.sizeHasStock(size),
                  onTap: _openVariantPicker,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSimilarRail() {
    final cardWidth = AppProductGridDelegate.railCardWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'You Might Also Like'),
        SizedBox(
          height: AppProductGridDelegate.railHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.page(context),
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: _similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) {
              final item = _similar[i];
              return SizedBox(
                width: cardWidth,
                child: ListenableBuilder(
                  listenable: WishlistService.instance,
                  builder: (context, _) => AppProductCard(
                    name: item.name,
                    subtitle: item.brand,
                    imageUrl: item.defaultImageUrl,
                    price: item.price,
                    originalPrice: item.originalPriceFormatted,
                    soldOut: item.stock <= 0,
                    isWishlisted:
                        WishlistService.instance.containsId(item.id),
                    onWishlistToggle: () =>
                        WishlistService.instance.toggle(item),
                    onTap: () => Navigator.pushReplacement(
                      context,
                      ProductDetailScreen.route(item),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The persistent buy bar. Sits above the safe area and stays reachable no
/// matter how far the page is scrolled.
class _ActionBar extends StatelessWidget {
  final bool canBuy;
  final bool isLoading;
  final VoidCallback onTryOn;
  final VoidCallback onAddToBag;

  const _ActionBar({
    required this.canBuy,
    required this.isLoading,
    required this.onTryOn,
    required this.onAddToBag,
  });

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        inset,
        AppSpacing.sm,
        inset,
        AppSpacing.safeBottom(context, extra: AppSpacing.sm),
      ),
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(top: BorderSide(color: AppPalette.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              label: 'Try On',
              icon: Icons.camera_alt_outlined,
              onPressed: onTryOn,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: AppButton(
              label: canBuy ? 'Add to Bag' : 'Sold Out',
              icon: canBuy ? Icons.shopping_bag_outlined : null,
              isLoading: isLoading,
              onPressed: canBuy ? onAddToBag : null,
            ),
          ),
        ],
      ),
    );
  }
}
