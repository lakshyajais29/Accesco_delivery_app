import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/ds/ds.dart';
import 'sell_item_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SELLER DASHBOARD — earnings, performance and listing management.
//
//  Figma's "Seller Dashboard" (490:676), "My Listings" (490:1413) and "Bulk
//  Listing" (490:1504) frames are layout stubs without populated content, so
//  this is interpolated from the design system rather than left unbuilt. Both
//  sections live on one screen behind a segmented control, because the two
//  views share a header and a seller flips between them constantly.
//
//  All figures below are placeholders with no backend behind them — every
//  number is labelled as such in the UI so nothing reads as a real balance.
// ─────────────────────────────────────────────────────────────────────────────

/// A seller's listing. Local to this screen until a listings API exists.
class _Listing {
  final String title;
  final String brand;
  final String price;
  final int views;
  final int likes;
  final _ListingStatus status;

  const _Listing({
    required this.title,
    required this.brand,
    required this.price,
    required this.views,
    required this.likes,
    required this.status,
  });
}

enum _ListingStatus { live, pending, sold }

extension _ListingStatusPresentation on _ListingStatus {
  String get label => switch (this) {
        _ListingStatus.live => 'Live',
        _ListingStatus.pending => 'In Review',
        _ListingStatus.sold => 'Sold',
      };

  AppBadgeTone get tone => switch (this) {
        _ListingStatus.live => AppBadgeTone.success,
        _ListingStatus.pending => AppBadgeTone.warning,
        _ListingStatus.sold => AppBadgeTone.neutral,
      };
}

class SellerDashboardScreen extends StatefulWidget {
  /// Opens directly on the listings tab — used by Profile ▸ "My Listings".
  final bool showListings;

  const SellerDashboardScreen({super.key, this.showListings = false});

  static Route<void> route({bool showListings = false}) => PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            SellerDashboardScreen(showListings: showListings),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  late bool _showListings;

  // Placeholder catalogue — replace with a listings endpoint.
  static const _listings = <_Listing>[
    _Listing(
      title: 'Wool Blend Blazer',
      brand: 'Zara',
      price: '₹899',
      views: 342,
      likes: 28,
      status: _ListingStatus.live,
    ),
    _Listing(
      title: 'Shoulder Bag',
      brand: 'Mango',
      price: '₹1,290',
      views: 197,
      likes: 15,
      status: _ListingStatus.live,
    ),
    _Listing(
      title: 'Slip Dress',
      brand: 'H&M',
      price: '₹640',
      views: 88,
      likes: 9,
      status: _ListingStatus.pending,
    ),
    _Listing(
      title: 'Wide Leg Denim',
      brand: 'Levi\'s',
      price: '₹1,150',
      views: 512,
      likes: 47,
      status: _ListingStatus.sold,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _showListings = widget.showListings;
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: Column(
          children: [
            AppTopBar(
              title: _showListings ? 'My Listings' : 'Seller Dashboard',
              serif: true,
              centerTitle: false,
              actions: [
                AppIconButton(
                  icon: Icons.add,
                  tooltip: 'List an item',
                  onPressed: () =>
                      Navigator.push(context, SellItemScreen.route()),
                ),
              ],
            ),

            // ── Segmented control ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                inset,
                AppSpacing.xs,
                inset,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: 'Overview',
                      selected: !_showListings,
                      onTap: () => setState(() => _showListings = false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _SegmentButton(
                      label: 'Listings',
                      selected: _showListings,
                      onTap: () => setState(() => _showListings = true),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _showListings
                  ? _buildListings(inset)
                  : _buildOverview(inset),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(double inset) {
    final live =
        _listings.where((l) => l.status == _ListingStatus.live).length;
    final sold =
        _listings.where((l) => l.status == _ListingStatus.sold).length;
    final views = _listings.fold<int>(0, (sum, l) => sum + l.views);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        inset,
        0,
        inset,
        AppSpacing.safeBottom(context, extra: AppSpacing.xl),
      ),
      children: [
        // Earnings — clearly marked as sample data.
        AppCard(
          color: AppPalette.ink,
          bordered: false,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available to withdraw'.toUpperCase(),
                style: AppType.eyebrow.copyWith(color: AppPalette.gold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '₹2,340',
                style: AppType.displayLarge.copyWith(
                  color: AppPalette.textOnDark,
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Sample figures — no payouts wired yet',
                style: AppType.bodySmall.copyWith(
                  color: AppPalette.textOnDark.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Withdraw',
                variant: AppButtonVariant.accent,
                size: AppButtonSize.small,
                fullWidth: false,
                onPressed: () => AppSnack.show(
                  context,
                  'Payouts are coming soon',
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.visibility_outlined,
                value: '$views',
                label: 'Total views',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                icon: Icons.sell_outlined,
                value: '$live',
                label: 'Live listings',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                icon: Icons.check_circle_outline,
                value: '$sold',
                label: 'Sold',
              ),
            ),
          ],
        ),
        const AppSectionHeader(
          title: 'Recent Activity',
          subtitle: 'How your pieces are performing',
        ),
        for (final listing in _listings.take(3)) ...[
          _ListingRow(listing: listing),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildListings(double inset) {
    if (_listings.isEmpty) {
      return AppStateView.empty(
        icon: Icons.sell_outlined,
        title: 'Nothing listed yet',
        message: 'List your first piece and it will show up here.',
        actionLabel: 'List an Item',
        onAction: () => Navigator.push(context, SellItemScreen.route()),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        inset,
        0,
        inset,
        AppSpacing.safeBottom(context, extra: AppSpacing.xl),
      ),
      itemCount: _listings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _ListingRow(listing: _listings[i]),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPalette.ink : AppPalette.surface,
          borderRadius: AppRadii.chip,
          border: Border.all(
            color: selected ? AppPalette.ink : AppPalette.line,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppType.overline.copyWith(
            color:
                selected ? AppPalette.textOnDark : AppPalette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppPalette.accent),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppType.priceLarge.copyWith(fontSize: 18)),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppType.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  final _Listing listing;

  const _ListingRow({required this.listing});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 62,
            decoration: const BoxDecoration(
              color: AppPalette.surfaceMuted,
              borderRadius: AppRadii.image,
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              size: 22,
              color: AppPalette.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        style: AppType.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppBadge(
                      listing.status.label,
                      tone: listing.status.tone,
                      soft: true,
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(listing.brand, style: AppType.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(listing.price, style: AppType.price),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.visibility_outlined,
                      size: 12,
                      color: AppPalette.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text('${listing.views}', style: AppType.bodySmall),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.favorite_border,
                      size: 12,
                      color: AppPalette.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text('${listing.likes}', style: AppType.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
