import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Rail item data
class RailItem {
  final String imageUrl;
  final String name;
  final double price;
  final String? badge; // "NEW", countdown, etc.
  final int? stockLeft; // depleting bar
  final String? metadata; // "Worn by 1.2K · Mumbai"
  final bool friendsApproved; // for Vibe Check rail

  const RailItem({
    required this.imageUrl,
    required this.name,
    required this.price,
    this.badge,
    this.stockLeft,
    this.metadata,
    this.friendsApproved = false,
  });
}

enum RailType {
  justDropped, // < 2hr old, shimmer animation, NEW badge with radial glow
  almostGone, // low stock, depleting bar
  trending, // city popularity rank, heatmap-style
  vibeCheckPicks, // friends voted YES on, social proof visual
  quickReorder, // last 3 ordered outfits, one-tap reorder
}

/// FOMO Horizontal Rail — Below Hero
/// Each rail has its own personality but shares the spec language.
class FomoRail extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<RailItem> items;
  final RailType type;

  const FomoRail({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header with hairline rule ─────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: AppText.featureLabel(
                  size: 12,
                  color: AppColors.ivoryWhite,
                ),
              ),
              const SizedBox(width: 8),
              if (subtitle != null)
                Expanded(
                  child: Text(
                    subtitle!,
                    style: AppText.secondary(size: 11),
                  ),
                ),
              const Spacer(),
              Text(
                'SEE ALL',
                style: AppText.featureLabel(
                  size: 10,
                  color: AppColors.brandTan,
                ),
              ),
            ],
          ),
        ),
        // ── Hairline separator (Chapter 03 — barely visible structure) ─
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 1,
          color: AppColors.separator,
        ),
        const SizedBox(height: 16),
        // ── Horizontal scroll list ─────────────────────────
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => _RailCard(
              item: items[i],
              type: type,
            ),
          ),
        ),
      ],
    );
  }
}

class _RailCard extends StatefulWidget {
  final RailItem item;
  final RailType type;

  const _RailCard({required this.item, required this.type});

  @override
  State<_RailCard> createState() => _RailCardState();
}

class _RailCardState extends State<_RailCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    // Shimmer animation only on JUST DROPPED rail (per spec).
    if (widget.type == RailType.justDropped) {
      _shimmerCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image + overlays ────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16), // Cards: 16px per spec
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Warm-graded image
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      1.05, 0, 0, 0, 5,
                      0, 0.98, 0, 0, 0,
                      0, 0, 0.88, 0, -8,
                      0, 0, 0, 1, 0,
                    ]),
                    child: Image.network(
                      widget.item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceCard,
                        child: Icon(
                          Icons.checkroom_outlined,
                          size: 40,
                          color: AppColors.brandTan.withOpacity(0.3),
                        ),
                      ),
                      loadingBuilder: (_, child, p) =>
                          p == null ? child : Container(color: AppColors.surfaceCard),
                    ),
                  ),

                  // Mood Overlay gradient at bottom
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [
                            AppColors.backgroundBase.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Type-specific overlays
                  ..._buildOverlays(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Name ────────────────────────────────────────
          Text(
            widget.item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              size: 13,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // ── Price ───────────────────────────────────────
          Text(
            '\$${widget.item.price.toStringAsFixed(0)}',
            style: AppText.priceCurrent(size: 14),
          ),
          if (widget.item.metadata != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.item.metadata!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.secondary(size: 10),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildOverlays() {
    switch (widget.type) {
      case RailType.justDropped:
        return [
          // Shimmer animation left-to-right
          if (_shimmerCtrl != null)
            AnimatedBuilder(
              animation: _shimmerCtrl!,
              builder: (context, _) {
                return Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      _shimmerCtrl!.value * 340 - 170,
                      0,
                    ),
                    child: Container(
                      width: 80,
                      decoration: const BoxDecoration(
                        gradient: AppColors.shimmer,
                      ),
                    ),
                  ),
                );
              },
            ),
          // NEW badge with radial glow
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brandTan,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandTan.withOpacity(0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                'NEW',
                style: AppText.featureLabel(
                  size: 9,
                  color: AppColors.backgroundBase,
                ),
              ),
            ),
          ),
        ];

      case RailType.almostGone:
        // Depleting bar — fills right-to-left to zero like a countdown.
        final stock = widget.item.stockLeft ?? 0;
        final fillRatio = (stock / 10).clamp(0.0, 1.0);
        return [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              color: AppColors.fomoRed.withOpacity(0.2),
              child: Row(
                children: [
                  Expanded(
                    flex: (fillRatio * 100).toInt().clamp(1, 100),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.fomoGradient,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - fillRatio) * 100).toInt().clamp(0, 99),
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.backgroundBase.withOpacity(0.75),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.fomoRed.withOpacity(0.5),
                  width: 0.8,
                ),
              ),
              child: Text(
                '$stock LEFT',
                style: AppText.stockCounter(size: 9),
              ),
            ),
          ),
        ];

      case RailType.trending:
        // Heatmap-style local demand pulse
        return [
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amberAlert.withOpacity(0.92),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    size: 10,
                    color: AppColors.backgroundBase,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'TRENDING',
                    style: AppText.featureLabel(
                      size: 8,
                      color: AppColors.backgroundBase,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];

      case RailType.vibeCheckPicks:
        // "Outfits friends voted YES on. Social proof visual."
        return [
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.backgroundBase.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.brandTan.withOpacity(0.4),
                ),
              ),
              child: const Icon(
                Icons.favorite,
                size: 12,
                color: AppColors.brandTan,
              ),
            ),
          ),
          // Stacked friend avatars
          Positioned(
            bottom: 10,
            left: 10,
            child: SizedBox(
              width: 56,
              height: 20,
              child: Stack(
                children: List.generate(3, (i) {
                  return Positioned(
                    left: i * 14.0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: [
                          AppColors.brandWarmBrown,
                          AppColors.brandTan,
                          AppColors.brandDeepBrown,
                        ][i],
                        border: Border.all(
                          color: AppColors.backgroundBase,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ];

      case RailType.quickReorder:
        return [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.brandWarmBrown,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandWarmBrown.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.refresh,
                size: 16,
                color: AppColors.ivoryWhite,
              ),
            ),
          ),
        ];
    }
  }
}