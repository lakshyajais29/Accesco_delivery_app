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
//  PRODUCT DETAIL — a translation of Figma node 490:944 ("Item").
//
//  Structure, top to bottom, matching the design:
//    1. Gallery      — hero photo with side peeks, index pill, thumbnail strip
//    2. Identity     — brand (serif), name (serif), price / strike / % off
//    3. Provenance   — condition grade chip + verified-item mark
//    4. Seller       — avatar, name, rating, verified seller, chevron
//    5. Attributes   — Size · Color · Condition · Brand
//    6. Assurance    — delivery ETA and try-&-return window
//    7. Action bar   — wishlist square + brown "Add to Cart"
//
//  Behaviour is unchanged from the previous implementation: variant picker →
//  CartService.addItem, wishlist toggle, virtual try-on, and similar products
//  from CatalogService.
// ─────────────────────────────────────────────────────────────────────────────

/// Figma measurements for this screen, kept together so the layout can be
/// checked against the design without reading the whole tree.
class _Spec {
  const _Spec._();

  // Gallery — nodes 490:983–988
  static const double heroHeight = 229;
  static const double heroSidePeek = 24;
  static const double indexPillRadius = 10;

  // Thumbnails — nodes 490:955–960
  static const double thumbHeight = 67;
  static const double thumbWidth = 58;
  static const double thumbRadius = 5;

  // Cards — nodes 490:964, 490:965
  static const double cardRadius = 5;
  static const double sellerCardHeight = 49;
  static const double assuranceCardHeight = 79;

  // Action bar — nodes 490:961, 490:963
  static const double ctaHeight = 47;
  static const double ctaRadius = 5;
  static const double wishlistWidth = 48;
}

/// Figma palette for this screen. The browns already exist in [AppPalette];
/// the near-neutral card borders and muted greys are specific to this design.
class _Ink {
  const _Ink._();

  /// Card hairline. Figma `#f0f1f1`.
  static const Color cardBorder = Color(0xFFF0F1F1);

  /// Assurance card wash. Figma `#f9f6fc`.
  static const Color assuranceFill = Color(0xFFF9F6FC);

  /// Struck-through original price. Figma `#726767`.
  static const Color priceStrike = Color(0xFF726767);

  /// Fine print under the assurance rows. Figma `#8f8686`.
  static const Color finePrint = Color(0xFF8F8686);

  /// Gallery side peeks. Figma `#cdc1b7` / `#e1d9d2`.
  static const Color peekLeft = Color(0xFFCDC1B7);
  static const Color peekRight = Color(0xFFE1D9D2);

  /// Index pill. Figma `#6c6b6a`.
  static const Color indexPill = Color(0xFF6C6B6A);

  /// Brand brown used for the CTA, grade chip and verification marks.
  /// Figma `#5d3b22` — matches [AppPalette.accentDeep] (`#5C3D22`) to within
  /// one unit, so the token is used rather than a second near-identical hex.
  static const Color brand = AppPalette.accentDeep;
}

class ProductDetailScreen extends StatefulWidget {
  final ParentProduct product;
  final String? heroTag;

  const ProductDetailScreen({super.key, required this.product, this.heroTag});

  static Route<void> route(ParentProduct product, {String? heroTag}) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ProductDetailScreen(product: product, heroTag: heroTag),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _galleryController = PageController();
  int _galleryIndex = 0;
  bool _isAddingToCart = false;

  late final List<ParentProduct> _similar;

  /// Gallery sources. The catalogue carries one image per product plus one per
  /// variant, so variant art is folded in to build the strip the design shows.
  late final List<String> _images;

  @override
  void initState() {
    super.initState();
    _similar = CatalogService.getSimilarProducts(widget.product);

    final seen = <String>{widget.product.defaultImageUrl};
    for (final variant in widget.product.variantMap.values) {
      final url = variant.imageUrl;
      if (url != null && url.isNotEmpty) seen.add(url);
    }
    _images = seen.toList(growable: false);
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
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
    } catch (_) {
      if (!mounted) return;
      // Most often the "not signed in" StateError from CartService.
      AppSnack.error(context, 'Could not add to bag. Please sign in first.');
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _toggleWishlist() {
    final wasSaved = WishlistService.instance.containsId(widget.product.id);
    WishlistService.instance.toggle(widget.product);
    AppSnack.show(
      context,
      wasSaved
          ? '${widget.product.name} removed from wishlist'
          : '${widget.product.name} saved to wishlist',
      icon: wasSaved ? Icons.heart_broken_outlined : Icons.favorite,
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final inset = AppSpacing.page(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: AppSpacing.safeBottom(context, extra: AppSpacing.xl),
                  ),
                  children: [
                    _buildGallery(),
                    if (_images.length > 1) _buildThumbnailStrip(inset),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          _buildIdentity(product),
                          const SizedBox(height: AppSpacing.sm),
                          _buildProvenance(product),
                          const SizedBox(height: AppSpacing.lg),
                          if (product.sellerName != null) ...[
                            _buildSellerCard(product),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _buildAttributes(product),
                          const SizedBox(height: AppSpacing.lg),
                          _buildAssuranceCard(product),
                          const SizedBox(height: AppSpacing.lg),
                          _buildDescription(product),
                        ],
                      ),
                    ),
                    if (_similar.isNotEmpty) _buildSimilarRail(),
                  ],
                ),
              ),
              _buildActionBar(product),
            ],
          ),
        ),
      ),
    );
  }

  // ── 0. Top bar (nodes 490:950, 490:953) ─────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.page(context) - AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: WishlistService.instance,
            builder: (context, _) {
              final saved =
                  WishlistService.instance.containsId(widget.product.id);
              return AppIconButton(
                icon: saved ? Icons.favorite : Icons.favorite_border,
                color: saved ? AppPalette.danger : null,
                tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
                onPressed: _toggleWishlist,
              );
            },
          ),
          AppIconButton(
            icon: Icons.ios_share,
            tooltip: 'Share',
            onPressed: () => AppSnack.show(
              context,
              'Sharing ${widget.product.name}',
              icon: Icons.ios_share,
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Gallery (nodes 490:983–988) ──────────────────────────────────────
  Widget _buildGallery() {
    return SizedBox(
      height: _Spec.heroHeight,
      child: Stack(
        children: [
          // Side peeks: the design shows the neighbouring frames bleeding in
          // at both edges so the gallery reads as horizontally scrollable.
          const Positioned.fill(
            child: Row(
              children: [
                SizedBox(
                  width: _Spec.heroSidePeek,
                  child: ColoredBox(color: _Ink.peekLeft),
                ),
                Spacer(),
                SizedBox(
                  width: _Spec.heroSidePeek,
                  child: ColoredBox(color: _Ink.peekRight),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _Spec.heroSidePeek,
            ),
            child: PageView.builder(
              controller: _galleryController,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _galleryIndex = i),
              itemBuilder: (context, i) {
                final image = AppImage(url: _images[i], cacheWidth: 800);
                // Only the first frame carries the hero tag — tagging every
                // page would create duplicate tags in the same tree.
                return i == 0
                    ? Hero(
                        tag: widget.heroTag ?? widget.product.id,
                        child: image,
                      )
                    : image;
              },
            ),
          ),
          if (_images.length > 1)
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xxl,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _Ink.indexPill,
                  borderRadius: BorderRadius.circular(_Spec.indexPillRadius),
                ),
                child: Text(
                  '${_galleryIndex + 1}/${_images.length}',
                  style: AppType.badge.copyWith(
                    fontSize: 8,
                    letterSpacing: 0.4,
                    color: AppPalette.textOnDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailStrip(double inset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, AppSpacing.md, inset, 0),
      child: SizedBox(
        height: _Spec.thumbHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _images.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
          itemBuilder: (context, i) {
            final selected = i == _galleryIndex;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _galleryController.animateToPage(
                  i,
                  duration: AppMotion.normal,
                  curve: AppMotion.standard,
                );
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                width: _Spec.thumbWidth,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_Spec.thumbRadius),
                  border: Border.all(
                    color: selected ? _Ink.brand : _Ink.cardBorder,
                    width: selected ? 1 : 0.5,
                  ),
                ),
                child: AppImage(url: _images[i], cacheWidth: 160),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 2. Identity (nodes 490:989–998) ─────────────────────────────────────
  Widget _buildIdentity(ParentProduct product) {
    final discount = product.discountPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.brand.toUpperCase(),
          style: AppType.displaySmall.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          product.name,
          style: AppType.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              product.lowestPrice,
              style: AppType.priceLarge.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.9,
              ),
            ),
            if (product.originalPriceFormatted != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                product.originalPriceFormatted!,
                style: AppType.priceStrike.copyWith(
                  fontSize: 10,
                  color: _Ink.priceStrike,
                  decorationColor: _Ink.priceStrike,
                ),
              ),
            ],
            if (discount != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$discount% off',
                style: AppType.bodySmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: _Ink.brand,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── 3. Provenance (nodes 490:992–995) ───────────────────────────────────
  Widget _buildProvenance(ParentProduct product) {
    final grade = product.conditionGrade;
    if (grade == null && !product.isVerifiedItem) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (grade != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppPalette.textOnInk,
              borderRadius: BorderRadius.circular(_Spec.indexPillRadius),
              border: Border.all(color: _Ink.brand, width: 0.5),
            ),
            child: Text(
              grade,
              style: AppType.badge.copyWith(
                fontSize: 8,
                letterSpacing: 0.4,
                color: _Ink.brand,
              ),
            ),
          ),
        if (product.isVerifiedItem) ...[
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.check_circle, size: 9, color: _Ink.brand),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Verified Item',
            style: AppType.badge.copyWith(
              fontSize: 8,
              letterSpacing: 0.4,
              color: _Ink.brand,
            ),
          ),
        ],
      ],
    );
  }

  // ── 4. Seller (nodes 490:965, 490:1008–1015) ────────────────────────────
  Widget _buildSellerCard(ParentProduct product) {
    return GestureDetector(
      onTap: () => AppSnack.show(
        context,
        'Seller profiles are coming soon',
        icon: Icons.storefront_outlined,
      ),
      child: Container(
        height: _Spec.sellerCardHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_Spec.cardRadius),
          border: Border.all(color: _Ink.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppPalette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 16,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.sellerName!,
                    style: AppType.bodySmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppPalette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (product.sellerRating != null) ...[
                        Text(
                          product.sellerRating!.toStringAsFixed(1),
                          style: AppType.bodySmall.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          '(${product.sellerReviewCount})',
                          style: AppType.bodySmall.copyWith(fontSize: 10),
                        ),
                      ],
                      if (product.isVerifiedSeller) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.verified,
                          size: 8,
                          color: _Ink.brand,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            'Verified Seller',
                            style: AppType.badge.copyWith(
                              fontSize: 8,
                              letterSpacing: 0.4,
                              color: _Ink.brand,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppPalette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Attributes (nodes 490:975–982) ───────────────────────────────────
  Widget _buildAttributes(ParentProduct product) {
    final entries = <({String label, String value})>[
      if (product.sizes.isNotEmpty)
        (label: 'Size', value: product.sizes.first),
      if (product.colors.isNotEmpty)
        (label: 'Color', value: product.colors.first.name),
      if (product.conditionLabel != null)
        (label: 'Condition', value: product.conditionLabel!),
      (label: 'Brand', value: product.brand),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: AppType.bodySmall.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: AppPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  entry.value,
                  style: AppType.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── 6. Assurance (nodes 490:964, 490:966–974) ───────────────────────────
  Widget _buildAssuranceCard(ParentProduct product) {
    return Container(
      height: _Spec.assuranceCardHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: _Ink.assuranceFill,
        borderRadius: BorderRadius.circular(_Spec.cardRadius),
        border: Border.all(color: _Ink.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AssuranceEntry(
              icon: Icons.local_shipping_outlined,
              title: 'Delivered in',
              value: product.deliveryEta ?? '2 hours',
              note: product.deliveryNote ?? 'Express delivery',
            ),
          ),
          Expanded(
            child: _AssuranceEntry(
              icon: Icons.access_time,
              title: 'Try & Return',
              value: product.returnWindow ?? '30 min window',
              note: product.returnNote ?? 'Easy return if it doesn\'t fit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(ParentProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About This Piece'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.xs),
        Text(product.description, style: AppType.bodyMedium),
      ],
    );
  }

  Widget _buildSimilarRail() {
    final cardWidth = AppProductGridDelegate.railCardWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'More Like This'),
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

  // ── 7. Action bar (nodes 490:961–963) ───────────────────────────────────
  Widget _buildActionBar(ParentProduct product) {
    final canBuy = product.stock > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page(context),
        AppSpacing.sm,
        AppSpacing.page(context),
        AppSpacing.safeBottom(context, extra: AppSpacing.sm),
      ),
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(top: BorderSide(color: _Ink.cardBorder)),
      ),
      child: Row(
        children: [
          // Wishlist square — node 490:963.
          ListenableBuilder(
            listenable: WishlistService.instance,
            builder: (context, _) {
              final saved = WishlistService.instance.containsId(product.id);
              return GestureDetector(
                onTap: _toggleWishlist,
                child: Container(
                  width: _Spec.wishlistWidth,
                  height: _Spec.ctaHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_Spec.ctaRadius),
                    border: Border.all(color: _Ink.cardBorder),
                  ),
                  child: Icon(
                    saved ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color:
                        saved ? AppPalette.danger : AppPalette.textSecondary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          // Try-on stays available: it is existing functionality the design
          // has no slot for, so it sits as a compact square rather than being
          // dropped.
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VirtualTryOnScreen()),
            ),
            child: Container(
              width: _Spec.wishlistWidth,
              height: _Spec.ctaHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_Spec.ctaRadius),
                border: Border.all(color: _Ink.cardBorder),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 20,
                color: AppPalette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Add to Cart — node 490:961, brown fill, 5px radius.
          Expanded(
            child: GestureDetector(
              onTap: canBuy && !_isAddingToCart ? _openVariantPicker : null,
              child: Container(
                height: _Spec.ctaHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canBuy ? _Ink.brand : AppPalette.surfaceSunken,
                  borderRadius: BorderRadius.circular(_Spec.ctaRadius),
                ),
                child: _isAddingToCart
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppPalette.textOnDark,
                        ),
                      )
                    : Text(
                        canBuy ? 'Add to Cart' : 'Sold Out',
                        style: AppType.bodyLarge.copyWith(
                          fontSize: 16,
                          letterSpacing: 0.8,
                          color: canBuy
                              ? AppPalette.textOnDark
                              : AppPalette.textTertiary,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the assurance card: icon, label, value and fine print.
class _AssuranceEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String note;

  const _AssuranceEntry({
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 17, color: AppPalette.textPrimary),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppType.bodySmall.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: AppPalette.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: AppType.bodySmall.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: AppPalette.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                note,
                style: AppType.bodySmall.copyWith(
                  fontSize: 8,
                  letterSpacing: 0.4,
                  color: _Ink.finePrint,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
