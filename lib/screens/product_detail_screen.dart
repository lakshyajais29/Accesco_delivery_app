import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product_model.dart';
import '../services/catalog_service.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/film_grain_overlay.dart';
import 'virtual_try_on_screen.dart';
import 'sku_variant_picker.dart';
import 'wishlist_screen.dart';
import '../services/wishlist_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT DETAIL PAGE — InstaStyle Cinematic PDP (LIGHT THEME)
// Hero header + Glassmorphic body + Sticky action bar
//
// Uses the AppColors.*Light tokens (backgroundLight, surfaceCardLight,
// separatorLight, textDark, textMutedLight) added alongside the dark palette.
// AppText's helpers (outfitName, priceCurrent, body, featureLabel, etc.)
// default their `color` param to the dark-mode tokens (ivoryWhite/mutedText),
// so every call below passes an explicit light-theme color override.
// Brand accents (brandWarmBrown, brandTan, brandDeepBrown) and signal colors
// (fomoRed) are theme-agnostic and used unchanged.
// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailScreen extends StatelessWidget {
  final ParentProduct product;
  final String? heroTag;

  const ProductDetailScreen({super.key, required this.product, this.heroTag});

  static Route<void> route(ParentProduct product, {String? heroTag}) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ProductDetailScreen(product: product, heroTag: heroTag),
        transitionDuration: const Duration(milliseconds: 420),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final topPad = mq.padding.top;
    final botPad = mq.padding.bottom;
    final imageH = screenH * 0.57;

    final similar = CatalogService.getSimilarProducts(product);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Kept light (white) status bar icons — this sits over the hero photo
      // and its dark top gradient, not over the light glass panel below.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        extendBodyBehindAppBar: true,
        body: FilmGrainOverlay(
          opacity: 0.03,
          child: Stack(
            children: [
              // ── 1. HERO IMAGE — fixed background ──────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: imageH,
                child: Hero(
                  tag: heroTag ?? product.id,
                  child: Image.network(
                    product.defaultImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.brandWarmBrown.withOpacity(0.12),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: AppColors.textMutedLight,
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 2. TOP GRADIENT — back/icons readability ───────────────────
              // Stays dark-to-transparent: it darkens the photo itself so the
              // floating icon buttons and system status bar read clearly,
              // independent of the app's light/dark theme.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: imageH * 0.38,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // ── 3. SCROLLABLE CONTENT ──────────────────────────────────────
              // Transparent spacer above the glass panel lets the fixed image show
              // through; glass panel overlaps the image by 40px for the cinematic
              // reveal as the user scrolls up.
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: imageH - 40),
                      _GlassBody(
                        product: product,
                        similar: similar,
                        botPad: botPad,
                      ),
                    ],
                  ),
                ),
              ),

              // ── 4. FLOATING NAV ICONS ──────────────────────────────────────
              Positioned(
                top: topPad + 8,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    StatefulBuilder(
                      builder: (context, setButtonState) {
                        final isWishlisted =
                            WishlistService.instance.contains(product);

                        return _GlassIconButton(
                          icon: isWishlisted
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          iconColor: isWishlisted ? AppColors.fomoRed : null,
                          onTap: () {
                            WishlistService.instance.toggle(product);
                            setButtonState(() {});
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  WishlistService.instance.contains(product)
                                      ? '${product.name} added to wishlist'
                                      : '${product.name} removed from wishlist',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── 5. STICKY ACTION BAR ───────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _StickyActionBar(product: product, botPad: botPad),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS BODY — full-width glassmorphic sheet that overlaps the hero image
// ─────────────────────────────────────────────────────────────────────────────

class _GlassBody extends StatelessWidget {
  final ParentProduct product;
  final List<ParentProduct> similar;
  final double botPad;

  const _GlassBody({
    required this.product,
    required this.similar,
    required this.botPad,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceCardLight.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(
              top: BorderSide(color: AppColors.separatorLight, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMutedLight.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Brand + category chips ─────────────────────────────
                    Row(
                      children: [
                        Text(
                          product.brand,
                          style: AppText.featureLabel(
                            size: 10,
                            color: AppColors.brandDeepBrown,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Chip(label: product.category.toUpperCase()),
                        if (product.isNew) ...[
                          const SizedBox(width: 8),
                          const _Chip(
                            label: 'NEW DROP',
                            filled: true,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Product title ──────────────────────────────────────
                    Text(
                      product.name,
                      style: AppText.outfitName(size: 34)
                          .copyWith(color: AppColors.textDark),
                    ),

                    const SizedBox(height: 16),

                    // ── Price row ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          product.lowestPrice,
                          style: AppText.priceCurrent(size: 26)
                              .copyWith(color: AppColors.textDark),
                        ),
                        if (product.originalPriceFormatted != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            product.originalPriceFormatted!,
                            style: AppText.priceOriginal(size: 16).copyWith(
                              color: AppColors.textMutedLight.withOpacity(0.75),
                              decorationColor:
                                  AppColors.textMutedLight.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── FOMO signals ───────────────────────────────────────
                    if (_hasFomo)
                      Wrap(
                        spacing: 8,
                        runSpacing: 7,
                        children: [
                          if (product.viewersNow > 0)
                            _FomoChip(
                              icon: Icons.visibility_outlined,
                              label: '${product.viewersNow} viewing now',
                            ),
                          if (product.orderedToday > 0)
                            _FomoChip(
                              icon: Icons.local_fire_department_outlined,
                              label: '${product.orderedToday} ordered today',
                              isRecency: true,
                            ),
                          if (product.stock < 4 && product.stock > 0)
                            _FomoChip(
                              icon: Icons.bolt_rounded,
                              label: 'Only ${product.stock} left',
                              isUrgent: true,
                            ),
                        ],
                      ),

                    SizedBox(height: _hasFomo ? 22 : 0),

                    // ── Separator ──────────────────────────────────────────
                    const Divider(
                      color: AppColors.separatorLight,
                      height: 1,
                      thickness: 1,
                    ),

                    const SizedBox(height: 22),

                    // ── Description ────────────────────────────────────────
                    Text(
                      'ABOUT THIS PIECE',
                      style: AppText.featureLabel(
                        size: 10,
                        color: AppColors.brandDeepBrown,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.description,
                      style: AppText.body(
                        size: 14.5,
                        color: AppColors.textDark.withOpacity(0.68),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── "You Might Also Like" header ───────────────────────
                    if (similar.isNotEmpty)
                      Text(
                        'YOU MIGHT ALSO LIKE',
                        style: AppText.featureLabel(size: 11)
                            .copyWith(color: AppColors.textDark.withOpacity(0.85)),
                      ),
                  ],
                ),
              ),

              // ── Similar products horizontal rail ───────────────────────
              if (similar.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 224,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemCount: similar.length,
                    itemBuilder: (context, i) =>
                        _SimilarProductCard(product: similar[i]),
                  ),
                ),
              ],

              // Bottom spacer clears the sticky bar
              SizedBox(height: 88 + (botPad > 0 ? botPad : 12) + 8),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasFomo =>
      product.viewersNow > 0 ||
      product.orderedToday > 0 ||
      (product.stock < 4 && product.stock > 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// SIMILAR PRODUCT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SimilarProductCard extends StatelessWidget {
  final ParentProduct product;
  const _SimilarProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, ProductDetailScreen.route(product)),
      child: Container(
        width: 142,
        height: 224,
        decoration: BoxDecoration(
          color: AppColors.surfaceCardLight,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.separatorLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 7,
              child: Image.network(
                product.defaultImageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.brandWarmBrown.withOpacity(0.10),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: AppColors.textMutedLight,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

            // Info strip
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.brand,
                          style: AppText.featureLabel(
                            size: 8,
                            color: AppColors.brandDeepBrown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          style: AppText.body(
                            size: 11,
                            weight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Text(
                      product.lowestPrice,
                      style: AppText.priceCurrent(size: 12)
                          .copyWith(color: AppColors.brandDeepBrown),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STICKY ACTION BAR — always visible at screen bottom
// ─────────────────────────────────────────────────────────────────────────────

class _StickyActionBar extends StatelessWidget {
  final ParentProduct product;
  final double botPad;

  const _StickyActionBar({required this.product, required this.botPad});

  @override
  Widget build(BuildContext context) {
    final safePad = botPad > 0 ? botPad : 12.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, safePad),
          decoration: BoxDecoration(
            color: AppColors.surfaceCardLight.withOpacity(0.94),
            border: const Border(
              top: BorderSide(color: AppColors.separatorLight, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Virtual Try-On (secondary) ───────────────────────────────
              Expanded(
                child: _TryOnButton(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VirtualTryOnScreen(),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ── Add to Bag (primary) ─────────────────────────────────────
              Expanded(
                child: _AddToBagButton(product: product),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TryOnButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TryOnButton({required this.onTap});

  @override
  State<_TryOnButton> createState() => _TryOnButtonState();
}

class _TryOnButtonState extends State<_TryOnButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 54,
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.brandTan.withOpacity(0.12)
              : Colors.transparent,
          border: Border.all(
            color: AppColors.brandDeepBrown.withOpacity(_pressed ? 0.9 : 0.45),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TRY-ON',
              style: AppText.featureLabel(
                size: 11,
                color: AppColors.brandDeepBrown,
              ),
            ),
            const SizedBox(width: 5),
            const Text('✨', style: TextStyle(fontSize: 13, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _AddToBagButton extends StatefulWidget {
  final ParentProduct product;
  const _AddToBagButton({required this.product});

  @override
  State<_AddToBagButton> createState() => _AddToBagButtonState();
}

class _AddToBagButtonState extends State<_AddToBagButton> {
  bool _pressed = false;

  void _openPicker() {
    VariantPickerSheet.show(
      context,
      parent: widget.product,
      onAddToCart: (CartPayload payload) {
        CartService.instance.addItem(payload);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.product.name} added to bag.',
              style: AppText.body(size: 13, color: AppColors.ivoryWhite),
            ),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // The filled CTA gradient + ivory label stays as designed — a saturated
    // brand-brown button with light text reads correctly on both light and
    // dark surfaces, so it's unchanged aside from a lighter drop shadow.
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _openPicker();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 54,
        decoration: BoxDecoration(
          gradient: _pressed
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandDeepBrown, AppColors.brandWarmBrown],
                )
              : AppColors.ctaGradient,
          // Sharp 0-radius per PrimaryCTA spec — authority
          boxShadow: _pressed
              ? null
              : [
                  BoxShadow(
                    color: AppColors.brandWarmBrown.withOpacity(0.30),
                    offset: const Offset(0, 3),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ADD TO BAG', style: AppText.featureLabel(size: 12)),
            const SizedBox(width: 8),
            const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.ivoryWhite,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              // Frosted white glass over the hero photo — reads as light-theme
              // chrome while the top gradient keeps it visible on busy images.
              color: AppColors.surfaceCardLight
                  .withOpacity(_pressed ? 0.90 : 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 1,
              ),
            ),
            child: Icon(
              widget.icon,
              color: widget.iconColor ?? AppColors.textDark,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill chip: outlined by default, filled warm-brown when [filled] = true.
class _Chip extends StatelessWidget {
  final String label;
  final bool filled;
  const _Chip({required this.label, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.brandWarmBrown.withOpacity(0.90) : null,
        border: filled
            ? null
            : Border.all(color: AppColors.separatorLight, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.featureLabel(
          size: 8,
          color: filled ? AppColors.ivoryWhite : AppColors.textMutedLight,
        ),
      ),
    );
  }
}

/// Inline signal row chip — viewer count, order velocity, or stock urgency.
///
/// Per Chapter 15 (FOMO Design System) of the design spec:
/// - Stock Counter ('Only X left'): Montserrat Black · FOMO Red (Chapter 04's
///   non-negotiable typography rule takes precedence over Ch.15's Roboto
///   Mono mention for this one).
/// - Social Proof ('X viewing now'): Montserrat Black · muted text colour.
/// - Recency Signal ('X ordered today'): Montserrat Black · brand tan.
/// All three are Feature Label territory, not body copy — hence
/// AppText.featureLabel / AppText.stockCounter (Montserrat), never
/// AppText.secondary (Inter).
class _FomoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isUrgent;
  final bool isRecency;

  const _FomoChip({
    required this.icon,
    required this.label,
    this.isUrgent = false,
    this.isRecency = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isUrgent
        ? AppColors.fomoRed
        : (isRecency ? AppColors.brandTan : AppColors.textMutedLight);
    final borderColor =
        isUrgent ? AppColors.fomoRed.withOpacity(0.45) : AppColors.separatorLight;
    final TextStyle textStyle = isUrgent
        ? AppText.stockCounter(size: 10)
        : AppText.featureLabel(size: 9, color: color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.fomoRed.withOpacity(0.06)
            : AppColors.surfaceCardLight,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}