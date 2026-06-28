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

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT DETAIL PAGE — InstaStyle Cinematic PDP
// Hero header + Glassmorphic body + Sticky action bar
// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailScreen extends StatelessWidget {
  final ParentProduct product;

  const ProductDetailScreen({super.key, required this.product});

  static Route<void> route(ParentProduct product) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => ProductDetailScreen(product: product),
        transitionDuration: const Duration(milliseconds: 420),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final screenH = mq.size.height;
    final topPad  = mq.padding.top;
    final botPad  = mq.padding.bottom;
    final imageH  = screenH * 0.57;

    final similar = CatalogService.getSimilarProducts(product);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundBase,
        extendBodyBehindAppBar: true,
        body: FilmGrainOverlay(
          opacity: 0.045,
          child: Stack(
            children: [

              // ── 1. HERO IMAGE — fixed background ──────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                height: imageH,
                child: Hero(
                  tag: product.id,
                  child: Image.network(
                    product.defaultImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.brandWarmBrown.withOpacity(0.22),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: AppColors.mutedText,
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 2. TOP GRADIENT — back/icons readability ───────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                height: imageH * 0.44,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
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
                    _GlassIconButton(
                      icon: Icons.favorite_border_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              // ── 5. STICKY ACTION BAR ───────────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
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
            color: const Color.fromRGBO(20, 18, 16, 0.91),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AppColors.separator, width: 1),
            ),
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
                    color: AppColors.mutedText.withOpacity(0.32),
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
                            color: AppColors.brandTan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Chip(label: product.category.toUpperCase()),
                        if (product.isNew) ...[
                          const SizedBox(width: 8),
                          _Chip(
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
                      style: AppText.outfitName(size: 34),
                    ),

                    const SizedBox(height: 16),

                    // ── Price row ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          product.lowestPrice,
                          style: AppText.priceCurrent(size: 26),
                        ),
                        if (product.originalPriceFormatted != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            product.originalPriceFormatted!,
                            style: AppText.priceOriginal(size: 16),
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
                    Divider(
                      color: AppColors.separator.withOpacity(0.55),
                      height: 1,
                      thickness: 1,
                    ),

                    const SizedBox(height: 22),

                    // ── Description ────────────────────────────────────────
                    Text(
                      'ABOUT THIS PIECE',
                      style: AppText.featureLabel(
                        size: 10,
                        color: AppColors.brandTan,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.description,
                      style: AppText.body(
                        size: 14.5,
                        color: AppColors.ivoryWhite.withOpacity(0.70),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── "You Might Also Like" header ───────────────────────
                    if (similar.isNotEmpty)
                      Text(
                        'YOU MIGHT ALSO LIKE',
                        style: AppText.featureLabel(size: 11),
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
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.separator, width: 1),
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
                  color: AppColors.brandWarmBrown.withOpacity(0.15),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: AppColors.mutedText,
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
                            color: AppColors.brandTan,
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
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Text(
                      product.lowestPrice,
                      style: AppText.precisionData(size: 12),
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
            color: const Color.fromRGBO(20, 18, 16, 0.90),
            border: Border(
              top: BorderSide(color: AppColors.separator, width: 1),
            ),
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
              ? AppColors.brandTan.withOpacity(0.08)
              : Colors.transparent,
          border: Border.all(
            color: AppColors.brandTan.withOpacity(_pressed ? 0.9 : 0.55),
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
                color: AppColors.brandTan,
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
              style: AppText.body(size: 13),
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
              : const [
                  BoxShadow(
                    color: Color.fromRGBO(196, 168, 130, 0.28),
                    offset: Offset(0, 1),
                    blurRadius: 0,
                    spreadRadius: -1,
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
  const _GlassIconButton({required this.icon, required this.onTap});

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
              color: Color.fromRGBO(20, 18, 16, _pressed ? 0.80 : 0.52),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.separator, width: 1),
            ),
            child: Icon(widget.icon, color: AppColors.ivoryWhite, size: 20),
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
        color: filled ? AppColors.brandWarmBrown.withOpacity(0.88) : null,
        border: filled
            ? null
            : Border.all(color: AppColors.separator, width: 1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppText.featureLabel(
          size: 8,
          color: filled ? AppColors.ivoryWhite : AppColors.mutedText,
        ),
      ),
    );
  }
}

/// Inline signal row chip — viewer count, order velocity, or stock urgency.
class _FomoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isUrgent;

  const _FomoChip({
    required this.icon,
    required this.label,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? AppColors.fomoRed : AppColors.mutedText;
    final borderColor =
        isUrgent ? AppColors.fomoRed.withOpacity(0.55) : AppColors.separator;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.secondary(size: 11).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
