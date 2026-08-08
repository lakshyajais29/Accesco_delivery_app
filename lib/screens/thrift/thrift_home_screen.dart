import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/ds/ds.dart';
import '../browse_screen.dart';
import '../thrift_marketplace_screen.dart';
import 'sell_item_screen.dart';
import 'seller_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THRIFT HOME — the root of the nested thrift ecosystem.
//
//  Reached from the main app's "Thrift" tab. Everything resale lives *inside*
//  this subtree rather than on the main navigation: buying (Browse, the
//  marketplace grid) and selling (list an item, manage listings, seller
//  dashboard). The app's own five-tab bar — Home · Swipe · Build · Thrift ·
//  Trial — is untouched; this screen is pushed on top of it.
//
//  Routing map
//  ───────────
//    Thrift tab
//      └── ThriftHomeScreen                    ← you are here
//            ├── BrowseScreen                  (search + filter the catalogue)
//            ├── ThriftMarketplaceScreen       (existing listing grid)
//            ├── SellItemScreen                (list a piece)
//            ├── SellerDashboardScreen         (earnings + performance)
//            └── SellerDashboard ▸ listings    (manage what you've listed)
//
//  A single [ThriftHomeTab] argument lets callers deep-link straight to a
//  section — Profile ▸ "My Listings" opens here with the listings tab active
//  rather than dropping the user on the hub root.
// ─────────────────────────────────────────────────────────────────────────────

/// Sections of the thrift ecosystem a caller can deep-link into.
enum ThriftHomeTab { discover, listings, dashboard }

class ThriftHomeScreen extends StatefulWidget {
  final ThriftHomeTab initialTab;

  const ThriftHomeScreen({
    super.key,
    this.initialTab = ThriftHomeTab.discover,
  });

  /// Fade route matching the app's page transition.
  static Route<void> route({
    ThriftHomeTab initialTab = ThriftHomeTab.discover,
  }) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ThriftHomeScreen(initialTab: initialTab),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<ThriftHomeScreen> createState() => _ThriftHomeScreenState();
}

class _ThriftHomeScreenState extends State<ThriftHomeScreen> {
  @override
  void initState() {
    super.initState();
    // A deep link to a sub-section pushes that screen once the hub is on
    // screen, so the back gesture returns here rather than exiting the
    // ecosystem entirely.
    if (widget.initialTab != ThriftHomeTab.discover) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialTab) {
          case ThriftHomeTab.listings:
            _open(const SellerDashboardScreen(showListings: true));
          case ThriftHomeTab.dashboard:
            _open(const SellerDashboardScreen());
          case ThriftHomeTab.discover:
            break;
        }
      });
    }
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      ),
    );
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
            const AppTopBar(
              title: 'Thrift',
              subtitle: 'Buy pre-loved. Sell what you\'ve outgrown.',
              serif: true,
              centerTitle: false,
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: AppSpacing.safeBottom(context, extra: AppSpacing.xl),
                ),
                children: [
                  // ── Sell CTA — the hero action of this ecosystem ──────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      AppSpacing.xs,
                      inset,
                      AppSpacing.lg,
                    ),
                    child: _SellBanner(
                      onTap: () => _open(const SellItemScreen()),
                    ),
                  ),

                  // ── Buying ───────────────────────────────────────────
                  const AppSectionHeader(
                    title: 'Discover',
                    subtitle: 'Find your next second-hand favourite',
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.search,
                          title: 'Browse & Search',
                          subtitle: 'Filter by size, condition, distance',
                          onTap: () => _open(const BrowseScreen()),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _ActionTile(
                          icon: Icons.storefront_outlined,
                          title: 'Thrift Marketplace',
                          subtitle: 'The full listing grid near you',
                          onTap: () =>
                              _open(const ThriftMarketplaceScreen()),
                        ),
                      ],
                    ),
                  ),

                  // ── Selling ──────────────────────────────────────────
                  const AppSectionHeader(
                    title: 'Selling',
                    subtitle: 'Turn your wardrobe into credits',
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.add_a_photo_outlined,
                          title: 'List an Item',
                          subtitle: 'Photos, condition, price — in a minute',
                          onTap: () => _open(const SellItemScreen()),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _ActionTile(
                          icon: Icons.sell_outlined,
                          title: 'My Listings',
                          subtitle: 'Manage what you have on sale',
                          onTap: () => _open(
                            const SellerDashboardScreen(showListings: true),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _ActionTile(
                          icon: Icons.insights_outlined,
                          title: 'Seller Dashboard',
                          subtitle: 'Earnings, views and performance',
                          onTap: () => _open(const SellerDashboardScreen()),
                        ),
                      ],
                    ),
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

/// The primary "start selling" card, following the editorial banner language
/// established by the Thrift Marketplace banner on the home screen.
class _SellBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _SellBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppPalette.bannerWash,
          borderRadius: AppRadii.card,
          border: Border.all(color: AppPalette.lineWarm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Start Selling'.toUpperCase(),
                    style: AppType.eyebrow.copyWith(
                      color: AppPalette.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your closet,\nsomeone\'s find.',
                    style: AppType.displayMedium.responsive(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'List in under a minute. Earn Circular Credits.',
                    style: AppType.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'List an Item',
                    icon: Icons.arrow_forward,
                    trailingIcon: true,
                    size: AppButtonSize.small,
                    fullWidth: false,
                    onPressed: onTap,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppPalette.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 26,
                color: AppPalette.accentDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A navigable row within the hub.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppPalette.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: AppPalette.accentDeep),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppType.titleMedium),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: AppType.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppPalette.textTertiary,
          ),
        ],
      ),
    );
  }
}
