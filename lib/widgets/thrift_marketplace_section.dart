import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/thrift_model.dart';
import '../services/thrift_api_service.dart';
import 'ds/ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THRIFT MARKETPLACE — home screen section.
//
//  Two parts, with different provenance — worth knowing when editing:
//
//  1. [ThriftMarketplaceBanner] is a 1:1 transcription of the Figma node
//     `578:6842` ("Thrift Marketplace Banner", ACCESCO LIVING → Page 2). Every
//     colour, size, radius, letter-spacing and line-height below is copied
//     from that node. Do not "tidy" these numbers — 6.94 and 17.88 are the
//     design's own values, not rounding errors.
//
//  2. [_NearbyStoresRail] has no Figma counterpart. It exists because the
//     feature calls for browsing nearby stores by location, which the banner
//     alone can't express. It is built from design-system components so it
//     reads as part of the same product.
// ─────────────────────────────────────────────────────────────────────────────

/// Figma spec constants for the banner, kept together so a redesign is a
/// single edit rather than a hunt through the tree.
class _Spec {
  const _Spec._();

  // Outer frame — node 578:6842
  static const double outerPaddingX = 20;
  static const double outerPaddingY = 8;

  // Card — node 578:6843 "Background+Border"
  static const double cardRadius = 16;
  static const double cardHeight = 165.75;
  static const double cardBorder = 1;

  // Left copy panel — node 578:6844, 208.8pt of a 347.99pt row
  static const int copyFlex = 2088;
  static const double copyPadding = 20;
  static const double copyBlockBottomPadding = 16;
  static const double copyGap = 6.94;

  // Right image well — node 578:6860, 139.19pt of the same row
  static const int imageFlex = 1392;
  static const double imagePadding = 8;
  static const double imageRadius = 12;

  // Icon — node 578:6848
  static const double iconSize = 20;
  static const double iconGap = 8;

  // Button — node 578:6858
  static const double buttonRadius = 12;
  static const double buttonPaddingX = 16;
  static const double buttonPaddingY = 8;
}

/// Figma type ramp for the banner.
///
/// These carry the design's exact sizes, weights, tracking and line-heights.
/// They resolve to the same Inter face the design system now uses app-wide,
/// so this component is consistent with everything around it — only the
/// precise metrics are pinned here.
class _BannerType {
  const _BannerType._();

  /// "THRIFT / MARKETPLACE" — node 578:6854.
  static final title = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0.6,
    color: AppPalette.textPrimary,
  );

  /// "Pre-loved styles. / Conscious choices." — node 578:6856.
  static final body = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 17.88 / 11,
    color: AppPalette.textMutedWarm,
  );

  /// "EXPLORE NOW" — node 578:6859.
  static final button = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0.3,
    color: AppPalette.textOnInk,
  );
}

/// The complete home-screen section: Figma banner plus the location-driven
/// nearby-stores rail.
///
/// Pass [latitude]/[longitude] to enable the rail. With no coordinates the
/// banner still renders on its own, so the section degrades cleanly when
/// location permission has been declined.
class ThriftMarketplaceSection extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final VoidCallback onExplore;
  final ValueChanged<ThriftStore>? onStoreTap;

  const ThriftMarketplaceSection({
    super.key,
    required this.onExplore,
    this.latitude,
    this.longitude,
    this.onStoreTap,
  });

  @override
  State<ThriftMarketplaceSection> createState() =>
      _ThriftMarketplaceSectionState();
}

class _ThriftMarketplaceSectionState extends State<ThriftMarketplaceSection> {
  late Future<List<ThriftStore>>? _storesFuture;

  bool get _hasLocation =>
      widget.latitude != null && widget.longitude != null;

  @override
  void initState() {
    super.initState();
    _storesFuture = _load();
  }

  @override
  void didUpdateWidget(ThriftMarketplaceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch only when the coordinates actually move, not on every rebuild
    // of the home screen.
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      // Block body, not an arrow: `() => x = future` *returns* the future,
      // and setState asserts its callback returns nothing. That assertion
      // throws inside didUpdateWidget, which aborts the enclosing viewport
      // update and cascades into duplicate-GlobalKey errors.
      setState(() {
        _storesFuture = _load();
      });
    }
  }

  Future<List<ThriftStore>>? _load() {
    if (!_hasLocation) return null;
    return ThriftApiService.instance.fetchNearbyStores(
      latitude: widget.latitude!,
      longitude: widget.longitude!,
    );
  }

  void _retry() {
    setState(() {
      _storesFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ThriftMarketplaceBanner(
          onTap: widget.onExplore,
          onExplore: widget.onExplore,
        ),
        if (_hasLocation)
          _NearbyStoresRail(
            future: _storesFuture!,
            onRetry: _retry,
            onStoreTap: widget.onStoreTap,
          ),
      ],
    );
  }
}

/// A 1:1 implementation of Figma node `578:6842`.
class ThriftMarketplaceBanner extends StatelessWidget {
  /// Tapping anywhere on the card.
  final VoidCallback onTap;

  /// Tapping the "EXPLORE NOW" pill specifically. Falls back to [onTap] when
  /// omitted — the pill sits inside the card's own gesture area, so it is
  /// never dead either way; this exists so the button can be given its own
  /// hit target, semantics and press feedback.
  final VoidCallback? onExplore;

  const ThriftMarketplaceBanner({
    super.key,
    required this.onTap,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _Spec.outerPaddingX,
        vertical: _Spec.outerPaddingY,
      ),
      child: Semantics(
        button: true,
        label: 'Thrift Marketplace. Pre-loved styles, conscious choices.',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: _Spec.cardHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppPalette.surfaceWarm,
              borderRadius: BorderRadius.circular(_Spec.cardRadius),
              border: Border.all(
                color: AppPalette.lineWarm,
                width: _Spec.cardBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Copy panel (node 578:6844) ────────────────────────
                Expanded(
                  flex: _Spec.copyFlex,
                  child: Padding(
                    padding: const EdgeInsets.all(_Spec.copyPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCopyBlock(),
                        _buildExploreButton(),
                      ],
                    ),
                  ),
                ),

                // ── Image well (node 578:6860) ────────────────────────
                Expanded(
                  flex: _Spec.imageFlex,
                  child: Container(
                    color: AppPalette.surfaceWarmAlt,
                    padding: const EdgeInsets.all(_Spec.imagePadding),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(_Spec.imageRadius),
                      child: Image.asset(
                        'assets/images/thrift/thrift_knitwear.png',
                        fit: BoxFit.cover,
                        // Figma offsets the photo left so the garment sits
                        // centred in the well rather than the raw frame.
                        alignment: const Alignment(-0.2, 0),
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: AppPalette.surfaceMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Icon + title row, then the two-line supporting copy (nodes 578:6845–56).
  Widget _buildCopyBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/icons/thrift_cart.svg',
              width: _Spec.iconSize,
              height: _Spec.iconSize,
              colorFilter: const ColorFilter.mode(
                AppPalette.textPrimary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: _Spec.iconGap),
            Flexible(
              child: Text(
                'THRIFT\nMARKETPLACE',
                style: _BannerType.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: _Spec.copyGap),
        Text(
          'Pre-loved styles.\nConscious choices.',
          style: _BannerType.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: _Spec.copyBlockBottomPadding),
      ],
    );
  }

  /// The ink pill (nodes 578:6857–59).
  Widget _buildExploreButton() {
    return Semantics(
      button: true,
      label: 'Explore the thrift marketplace',
      child: Material(
        color: AppPalette.ink,
        borderRadius: BorderRadius.circular(_Spec.buttonRadius),
        child: InkWell(
          onTap: onExplore ?? onTap,
          borderRadius: BorderRadius.circular(_Spec.buttonRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _Spec.buttonPaddingX,
              vertical: _Spec.buttonPaddingY,
            ),
            child: Text('EXPLORE NOW', style: _BannerType.button),
          ),
        ),
      ),
    );
  }
}

/// Location-driven rail of nearby stores.
///
/// Not part of the Figma file — composed from design-system components so it
/// belongs to the same product visually.
class _NearbyStoresRail extends StatelessWidget {
  final Future<List<ThriftStore>> future;
  final VoidCallback onRetry;
  final ValueChanged<ThriftStore>? onStoreTap;

  const _NearbyStoresRail({
    required this.future,
    required this.onRetry,
    this.onStoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ThriftStore>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RailShell(child: _StoreRailSkeleton());
        }

        if (snapshot.hasError) {
          final message = snapshot.error is ThriftApiException
              ? (snapshot.error as ThriftApiException).message
              : 'Could not load nearby stores.';
          return _RailShell(
            child: _RailMessage(
              icon: Icons.wifi_off_rounded,
              message: message,
              actionLabel: 'Retry',
              onAction: onRetry,
            ),
          );
        }

        final stores = snapshot.data ?? const <ThriftStore>[];
        if (stores.isEmpty) {
          return const _RailShell(
            child: _RailMessage(
              icon: Icons.storefront_outlined,
              message: 'No thrift stores near you yet — we\'re adding more.',
            ),
          );
        }

        return _RailShell(
          child: SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.page(context),
              ),
              itemCount: stores.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) => _StoreCard(
                store: stores[i],
                onTap: onStoreTap == null
                    ? null
                    : () => onStoreTap!(stores[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Section header + slot, shared by every rail state so the header never
/// pops in and out as the request resolves.
class _RailShell extends StatelessWidget {
  final Widget child;

  const _RailShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppSectionHeader(
          title: 'Thrift Stores Near You',
          subtitle: 'Pre-loved pieces within a short ride',
        ),
        child,
      ],
    );
  }
}

class _StoreCard extends StatelessWidget {
  final ThriftStore store;
  final VoidCallback? onTap;

  const _StoreCard({required this.store, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            AppImage(
              url: store.imageUrl,
              width: 56,
              height: 56,
              cacheWidth: 120,
              borderRadius: AppRadii.image,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          store.name,
                          style: AppType.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (store.isVerified) ...[
                        const SizedBox(width: AppSpacing.xxs),
                        const Icon(
                          Icons.verified,
                          size: 13,
                          color: AppPalette.accent,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${store.formattedDistance} · ${store.area}',
                    style: AppType.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: AppPalette.gold,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        store.rating.toStringAsFixed(1),
                        style: AppType.bodySmall.copyWith(
                          color: AppPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '${store.itemCount} pieces',
                          style: AppType.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreRailSkeleton extends StatelessWidget {
  const _StoreRailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, __) => const SizedBox(
          width: 220,
          child: AppShimmer(borderRadius: AppRadii.card),
        ),
      ),
    );
  }
}

/// Compact inline state for the rail — an empty or failed fetch shouldn't
/// take over the home screen the way a full-page state view would.
class _RailMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _RailMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
      child: AppCard(
        color: AppPalette.surfaceMuted,
        bordered: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppPalette.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppType.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null)
              AppButton.ghost(
                label: actionLabel!,
                size: AppButtonSize.small,
                trailingIcon: false,
                onPressed: onAction,
              ),
          ],
        ),
      ),
    );
  }
}
