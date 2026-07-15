import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../models/product_model.dart';
import '../services/wishlist_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/film_grain_overlay.dart';
import 'product_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WISHLIST SCREEN — Cinematic Grid View (LIGHT THEME)
//
// Uses AppColors.*Light tokens (backgroundLight, surfaceCardLight,
// separatorLight, textDark, textMutedLight) alongside the theme-agnostic
// brand accents (brandTan/brandWarmBrown/brandDeepBrown, fomoRed). AppText
// helpers default their `color` to dark-mode tokens, so light-theme colors
// are passed explicitly wherever text is rendered.
// ─────────────────────────────────────────────────────────────────────────────

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  // Assuming WishlistService.instance.items returns a List<ParentProduct>
  late List<ParentProduct> _wishlistItems;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  void _loadWishlist() {
    setState(() {
      // Update this if your getter is named differently (e.g., .savedItems)
      _wishlistItems = WishlistService.instance.items; 
    });
  }

  void _removeFromWishlist(ParentProduct product) {
    WishlistService.instance.toggle(product);
    _loadWishlist(); // Refresh the grid

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} removed from wishlist',
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
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status bar icons — the glass app bar underneath is now light,
      // unlike the PDP where the status bar sits over a dark-gradiented photo.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        extendBodyBehindAppBar: true,
        body: FilmGrainOverlay(
          opacity: 0.03,
          child: Stack(
            children: [
              // ── 1. MAIN CONTENT (GRID OR EMPTY STATE) ──────────────────────
              if (_wishlistItems.isEmpty)
                _EmptyWishlistState()
              else
                Positioned.fill(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.only(
                          top: topPad + 80, // Space for the glass app bar
                          left: 16,
                          right: 16,
                          bottom: mq.padding.bottom + 24,
                        ),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.58, // Taller cinematic cards
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final product = _wishlistItems[index];
                              return _WishlistGridCard(
                                product: product,
                                onRemove: () => _removeFromWishlist(product),
                              );
                            },
                            childCount: _wishlistItems.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── 2. GLASSMORPHIC APP BAR ────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCardLight.withOpacity(0.80),
                        border: const Border(
                          bottom: BorderSide(
                            color: AppColors.separatorLight,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _GlassIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          Text(
                            'WISHLIST',
                            style: AppText.featureLabel(
                              size: 14,
                              color: AppColors.textDark,
                            ),
                          ),
                          // Invisible placeholder to perfectly center the title
                          const SizedBox(width: 44), 
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyWishlistState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 64,
            color: AppColors.textMutedLight.withOpacity(0.4),
          ),
          const SizedBox(height: 24),
          Text(
            'YOUR WISHLIST IS EMPTY',
            style: AppText.featureLabel(
              size: 14,
              color: AppColors.brandDeepBrown,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Save the pieces you love to build\nyour perfect collection.',
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 14,
              color: AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WISHLIST GRID CARD
// ─────────────────────────────────────────────────────────────────────────────

class _WishlistGridCard extends StatelessWidget {
  final ParentProduct product;
  final VoidCallback onRemove;

  const _WishlistGridCard({
    required this.product,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, ProductDetailScreen.route(product)),
      child: Container(
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Expanded(
                  flex: 65,
                  child: CachedNetworkImage(
                    imageUrl: product.defaultImageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.brandWarmBrown.withOpacity(0.10)),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.brandWarmBrown.withOpacity(0.10),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: AppColors.textMutedLight,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

                // Info Strip
                Expanded(
                  flex: 35,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
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
                                size: 9,
                                color: AppColors.brandDeepBrown,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.name,
                              style: AppText.body(
                                size: 13,
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
                          style: AppText.priceCurrent(size: 14)
                              .copyWith(color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Floating Remove Button (Filled Heart) ──
            // Kept as a dark frosted circle with a light heart icon — it sits
            // directly over the product photo, so it needs photo-contrast
            // chrome regardless of the app's light/dark theme (same pattern
            // as the PDP's floating nav icons over its hero image).
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(20, 18, 16, 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: AppColors.fomoRed,
                        size: 16,
                      ),
                    ),
                  ),
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
// SHARED SUB-WIDGET
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
              color: AppColors.surfaceCardLight
                  .withOpacity(_pressed ? 0.95 : 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.separatorLight, width: 1),
            ),
            child: Icon(widget.icon, color: AppColors.textDark, size: 20),
          ),
        ),
      ),
    );
  }
}