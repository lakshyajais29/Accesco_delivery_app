import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HeroOutfit {
  final String imageUrl;
  final String occasion;
  final String name;
  final int stockLeft;
  final int etaMinutes;
  final int price;
  final int originalPrice;

  const HeroOutfit({
    required this.imageUrl,
    required this.occasion,
    required this.name,
    required this.stockLeft,
    required this.etaMinutes,
    required this.price,
    required this.originalPrice,
  });
}

/// HERO OUTFIT CARD — Full-bleed editorial photograph.
/// Auto-swipes every 3 seconds. Pauses 6s after user interaction.
class HeroOutfitCard extends StatefulWidget {
  final List<HeroOutfit> outfits;
  final ValueChanged<int>? onOutfitChanged;

  /// How long between auto-advances.
  final Duration autoSwipeInterval;

  /// How long to wait after a manual swipe before resuming auto-swipe.
  final Duration resumeDelay;

  const HeroOutfitCard({
    super.key,
    required this.outfits,
    this.onOutfitChanged,
    this.autoSwipeInterval = const Duration(seconds: 3),
    this.resumeDelay = const Duration(seconds: 6),
  });

  @override
  State<HeroOutfitCard> createState() => _HeroOutfitCardState();
}

class _HeroOutfitCardState extends State<HeroOutfitCard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _autoSwipeTimer;
  Timer? _resumeTimer;

  // Brighter red — Vermillion/Crimson. More legible than fomoRed at low opacity.
  static const Color _accentRed = Color(0xFFFF3B47);

  @override
  void initState() {
    super.initState();
    _startAutoSwipe();
  }

  @override
  void dispose() {
    _autoSwipeTimer?.cancel();
    _resumeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSwipe() {
    _autoSwipeTimer?.cancel();
    _autoSwipeTimer = Timer.periodic(widget.autoSwipeInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final int nextIndex = (_currentIndex + 1) % widget.outfits.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pauseAutoSwipe() {
    _autoSwipeTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.resumeDelay, () {
      if (mounted) _startAutoSwipe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.78;
    final topSafe = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Listener(
        onPointerDown: (_) => _pauseAutoSwipe(),
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.outfits.length,
          onPageChanged: (i) {
            setState(() => _currentIndex = i);
            widget.onOutfitChanged?.call(i);
          },
          itemBuilder: (context, index) {
            final outfit = widget.outfits[index];
            return _HeroOutfitSlide(
              outfit: outfit,
              topSafe: topSafe,
              currentIndex: _currentIndex,
              totalSlides: widget.outfits.length,
              accentRed: _accentRed,
            );
          },
        ),
      ),
    );
  }
}

class _HeroOutfitSlide extends StatelessWidget {
  final HeroOutfit outfit;
  final double topSafe;
  final int currentIndex;
  final int totalSlides;
  final Color accentRed;

  const _HeroOutfitSlide({
    required this.outfit,
    required this.topSafe,
    required this.currentIndex,
    required this.totalSlides,
    required this.accentRed,
  });

  @override
  Widget build(BuildContext context) {
    final double pillRowTop = topSafe + 64 + 20;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Full-bleed editorial image ────────────────
        Image.network(
          outfit.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.brandWarmBrown.withOpacity(0.3),
            child: const Center(
              child: Icon(Icons.image_outlined,
                  color: AppColors.mutedText, size: 64),
            ),
          ),
        ),

        // ── Bottom gradient overlay ───────────────────
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.heroBottomOverlay,
            ),
          ),
        ),

        // ── Top pill row: occasion (left) + stock (right) ──
        Positioned(
          top: pillRowTop,
          left: 16,
          right: 16,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool stack = constraints.maxWidth < 360;
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OccasionPill(text: outfit.occasion),
                    const SizedBox(height: 8),
                    _StockPill(
                      stockLeft: outfit.stockLeft,
                      accentRed: accentRed,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: _OccasionPill(text: outfit.occasion)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _StockPill(
                      stockLeft: outfit.stockLeft,
                      accentRed: accentRed,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // ── Bottom copy block ─────────────────────────
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                outfit.name,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.w700,
                  fontSize: 45,
                  height: 1.0,
                  color: AppColors.ivoryWhite,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Price row — Rupee symbol
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${outfit.price}',
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: AppColors.ivoryWhite,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '₹${outfit.originalPrice}',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                      color: AppColors.mutedText.withOpacity(0.7),
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.mutedText.withOpacity(0.7),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _DeliveryEtaBadge(etaMinutes: outfit.etaMinutes),
              const SizedBox(height: 20),

              // Secondary CTA — Vibe Check ghost
              Row(
                children: [
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'VIBE CHECK',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.8,
                            color: AppColors.ivoryWhite,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward,
                            color: AppColors.ivoryWhite, size: 16),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const _AddToCartButton(),
              const SizedBox(height: 18),
              _PageIndicator(
                count: totalSlides,
                currentIndex: currentIndex,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OCCASION PILL
// ─────────────────────────────────────────────────────────────
class _OccasionPill extends StatelessWidget {
  final String text;
  const _OccasionPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandWarmBrown.withOpacity(0.85),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.6,
          color: AppColors.ivoryWhite,
          height: 1.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STOCK COUNTER — frosted glass with red tint, white text
// Clean, modern, no heavy black backdrop
// ─────────────────────────────────────────────────────────────
class _StockPill extends StatefulWidget {
  final int stockLeft;
  final Color accentRed;
  const _StockPill({required this.stockLeft, required this.accentRed});

  @override
  State<_StockPill> createState() => _StockPillState();
}

class _StockPillState extends State<_StockPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Pulsing red dot
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.accentRed,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.accentRed
                    .withOpacity(0.4 + 0.5 * _pulse.value),
                blurRadius: 6 + 4 * _pulse.value,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),

      const SizedBox(width: 8),

      Text(
        'ONLY ${widget.stockLeft} LEFT IN YOUR SIZE',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'RobotoMono',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.0,
          color: Color.fromARGB(255, 169, 17, 17),
          shadows: [
    Shadow(
      color: Color.fromARGB(180, 57, 38, 38),
      blurRadius: 4,
    ),
  ],
          height: 1.0,
        ),
      ),
    ],
  );
}
}

// ─────────────────────────────────────────────────────────────
// DELIVERY ETA BADGE
// ─────────────────────────────────────────────────────────────
class _DeliveryEtaBadge extends StatelessWidget {
  final int etaMinutes;
  const _DeliveryEtaBadge({required this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppColors.brandTan.withOpacity(0.7),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: AppColors.brandTan,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '$etaMinutes MIN FROM NEAREST PILL',
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.0,
              color: AppColors.brandTan,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PRIMARY CTA — ADD TO CART
// ─────────────────────────────────────────────────────────────
class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.ctaGradient,
          borderRadius: BorderRadius.circular(4),
        ),
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ADD TO CART',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 2.0,
                  color: AppColors.ivoryWhite,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward,
                  color: AppColors.ivoryWhite, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAGE INDICATOR
// ─────────────────────────────────────────────────────────────
class _PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  const _PageIndicator({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 24 : 6,
          height: 3,
          decoration: BoxDecoration(
            color: active
                ? AppColors.ivoryWhite
                : AppColors.ivoryWhite.withOpacity(0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}