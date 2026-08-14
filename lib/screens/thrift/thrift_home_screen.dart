import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/product_model.dart';
import '../../services/catalog_service.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/ds/ds.dart';
import '../browse_screen.dart';
import '../product_detail_screen.dart';
import '../style_circle_screen.dart';
import '../thrift_marketplace_screen.dart';
import '../wishlist_screen.dart';
import 'sell_item_screen.dart';
import 'seller_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THRIFT HOME — the root of the nested thrift ecosystem.
//
//  Reached from the main app's "Thrift" tab and from the Thrift Marketplace
//  banner on the home screen. Everything resale lives *inside* this subtree
//  rather than on the main navigation: buying (Browse, the marketplace grid)
//  and selling (list an item, manage listings, seller dashboard). The app's own
//  five-tab bar — Home · Swipe · Build · Thrift · Trial — is untouched; this
//  screen is pushed on top of it and carries its own bottom navigation.
//
//  Structure, top to bottom:
//    1. Brand bar       — "InstaStyle Thrift" + wishlist / notifications
//    2. Location        — the city the marketplace is scoped to
//    3. Search          — free text, handed to BrowseScreen on submit
//    4. Banner          — "Pre-loved Fashion", into the marketplace grid
//    5. Categories      — eight departments, handed to BrowseScreen
//    6. Trending Now    — a rail of pieces moving fastest right now
//    7. Style Circle    — the sell-your-wardrobe prompt
//    8. Bottom nav      — Home · Browse · Sell · Orders · Profile
//
//  Routing map — every destination the previous hub exposed is still reachable
//  ─────────────────────────────────────────────────────────────────────────
//    Thrift tab / home banner
//      └── ThriftHomeScreen                    ← you are here
//            ├── BrowseScreen                  nav ▸ Browse, search, categories
//            ├── ThriftMarketplaceScreen       banner ▸ Explore, rail ▸ View all
//            ├── SellItemScreen                nav ▸ Sell, Style Circle ▸ Scan
//            ├── SellerDashboard ▸ listings    nav ▸ Orders
//            └── SellerDashboardScreen         nav ▸ Profile
//
//  A single [ThriftHomeTab] argument lets callers deep-link straight to a
//  section — Profile ▸ "My Listings" opens here with the listings tab active
//  rather than dropping the user on the hub root.
// ─────────────────────────────────────────────────────────────────────────────

/// Sections of the thrift ecosystem a caller can deep-link into.
enum ThriftHomeTab { discover, listings, dashboard }

/// One department in the eight-tile category grid.
///
/// Each hands its label to [BrowseScreen] as a search term — the marketplace
/// has no separate department index, and search over the shared catalogue is
/// the behaviour Browse already implements.
class _ThriftCategory {
  final String label;
  final IconData icon;

  const _ThriftCategory(this.label, this.icon);
}

const _categories = <_ThriftCategory>[
  _ThriftCategory('Women', Icons.woman_outlined),
  _ThriftCategory('Men', Icons.man_outlined),
  _ThriftCategory('Bags', Icons.shopping_bag_outlined),
  _ThriftCategory('Shoes', Icons.directions_walk_outlined),
  _ThriftCategory('Luxury', Icons.diamond_outlined),
  _ThriftCategory('Vintage', Icons.watch_outlined),
  _ThriftCategory('Streetwear', Icons.skateboarding_outlined),
  _ThriftCategory('Lifestyle', Icons.spa_outlined),
];

/// Cities the marketplace operates in. The picker writes the selection into
/// screen state; the rails are catalogue-backed, so the label is currently
/// presentational — wire it into the query when the service takes a city.
const _cities = <String>['Gurgaon', 'Delhi', 'Noida', 'Mumbai', 'Bengaluru'];

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
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _city = _cities.first;
  int _navIndex = 0;

  /// The Trending Now rail.
  ///
  /// Read once from [CatalogService] — the same in-memory catalogue Browse and
  /// the home rails read — rather than from the thrift backend, so the rail is
  /// populated whether or not the service is reachable. Computed in initState
  /// because `getTrending()` filters and sorts the full catalogue on every
  /// call, which has no business running inside `build()`.
  late final List<ParentProduct> _trending;

  @override
  void initState() {
    super.initState();

    _trending = CatalogService.getTrending().take(8).toList(growable: false);

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
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

  // ── Actions ─────────────────────────────────────────────────────────────
  void _submitSearch(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    _searchFocus.unfocus();
    Navigator.push(context, BrowseScreen.route(initialQuery: query));
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {});
  }

  void _openCategory(_ThriftCategory category) {
    Navigator.push(context, BrowseScreen.route(initialQuery: category.label));
  }

  void _openProduct(ParentProduct product, String heroTag) {
    Navigator.push(
      context,
      ProductDetailScreen.route(product, heroTag: heroTag),
    );
  }

  Future<void> _pickCity() async {
    _searchFocus.unfocus();
    final selected = await showAppSheet<String>(
      context,
      child: AppSheet(
        title: 'Your City',
        subtitle: 'Pre-loved pieces are matched to where you are',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final city in _cities)
              ListTile(
                onTap: () => Navigator.of(context).pop(city),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.page(context),
                ),
                leading: Icon(
                  Icons.location_on_outlined,
                  size: 19,
                  color: city == _city
                      ? AppPalette.accent
                      : AppPalette.textTertiary,
                ),
                title: Text(
                  city,
                  style: AppType.bodyLarge.copyWith(
                    color: AppPalette.textPrimary,
                    fontWeight:
                        city == _city ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: city == _city
                    ? const Icon(Icons.check, size: 19, color: AppPalette.accent)
                    : null,
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (selected == null || selected == _city || !mounted) return;
    setState(() => _city = selected);
  }

  /// Bottom navigation. Home stays put; every other destination pushes, which
  /// keeps this screen the root of the subtree the user can always get back to.
  void _handleNavTap(int index) {
    _searchFocus.unfocus();
    switch (index) {
      case 1:
        _open(const BrowseScreen());
      case 2:
        Navigator.push(context, SellItemScreen.route());
      case 3:
        Navigator.push(context, SellerDashboardScreen.route(showListings: true));
      case 4:
        Navigator.push(context, SellerDashboardScreen.route());
      default:
        setState(() => _navIndex = index);
    }
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
            RepaintBoundary(
              child: _ThriftBrandBar(
                city: _city,
                onCityTap: _pickCity,
                onWishlist: () => _open(const WishlistScreen()),
                onNotifications: () => AppSnack.show(
                  context,
                  'You\'re all caught up on thrift activity',
                  icon: Icons.notifications_none,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: AppSpacing.safeBottom(context, extra: AppSpacing.xl),
                ),
                children: [
                  // ── 3. Search ────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      AppSpacing.xs,
                      inset,
                      AppSpacing.md,
                    ),
                    child: AppSearchBar(
                      hint: 'Search pre-loved fashion…',
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      fillColor: AppPalette.surfaceMuted,
                      borderColor: Colors.transparent,
                      onChanged: (value) {
                        if (value.isEmpty || value.length == 1) setState(() {});
                      },
                      onSubmitted: _submitSearch,
                      onClear: _searchCtrl.text.isEmpty ? null : _clearSearch,
                    ),
                  ),

                  // ── 4. Pre-loved banner ──────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: _PreLovedBanner(
                      onExplore: () => _open(const ThriftMarketplaceScreen()),
                    ),
                  ),

                  // ── 5. Categories ────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      AppSpacing.xl,
                      inset,
                      0,
                    ),
                    child: _CategoryGrid(
                      categories: _categories,
                      onSelected: _openCategory,
                    ),
                  ),

                  // ── 6. Trending Now ──────────────────────────────────
                  AppSectionHeader(
                    title: 'Trending Now',
                    subtitle: 'Moving fastest in $_city',
                    actionLabel: 'View All',
                    onAction: () => _open(const ThriftMarketplaceScreen()),
                  ),
                  _buildTrendingRail(),

                  // ── 7. Style Circle ──────────────────────────────────
                  AppSectionHeader(
                    title: 'Style Circle',
                    actionLabel: 'View All',
                    onAction: () =>
                        Navigator.push(context, StyleCircleScreen.route()),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: _StyleCircleBanner(
                      onScan: () =>
                          Navigator.push(context, SellItemScreen.route()),
                    ),
                  ),
                ],
              ),
            ),
            RepaintBoundary(
              child: _ThriftBottomNav(
                currentIndex: _navIndex,
                onTap: _handleNavTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trending rail ───────────────────────────────────────────────────────
  Widget _buildTrendingRail() {
    if (_trending.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
        child: AppCard(
          color: AppPalette.surfaceMuted,
          bordered: false,
          child: Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: AppPalette.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Nothing trending in $_city yet — check back shortly.',
                  style: AppType.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        height: 236,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
          addAutomaticKeepAlives: false,
          itemCount: _trending.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) {
            final product = _trending[i];
            final heroTag = 'thrift-trending-${product.id}-$i';
            return _TrendingCard(
              product: product,
              heroTag: heroTag,
              onTap: () => _openProduct(product, heroTag),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Components
// ─────────────────────────────────────────────────────────────────────────────

/// The thrift wordmark bar plus the location row beneath it.
///
/// Carries a back affordance when this screen was pushed: the route is a fade,
/// so there is no interactive swipe-back to fall back on.
class _ThriftBrandBar extends StatelessWidget {
  final String city;
  final VoidCallback onCityTap;
  final VoidCallback onWishlist;
  final VoidCallback onNotifications;

  const _ThriftBrandBar({
    required this.city,
    required this.onCityTap,
    required this.onWishlist,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final inset = AppSpacing.page(context);

    return Container(
      color: AppPalette.canvas,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 54,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Row(
                children: [
                  if (canPop) ...[
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(right: AppSpacing.xs),
                        child: Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  // Flexible, not fixed: on a 320pt phone the wordmark, the
                  // back arrow and two icon buttons together exceed the bar,
                  // and the wordmark is the element that can give.
                  Flexible(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: AppType.wordmark.copyWith(fontSize: 20),
                        children: const [
                          TextSpan(text: 'Insta'),
                          TextSpan(
                            text: 'Style',
                            style: TextStyle(color: AppPalette.accent),
                          ),
                          TextSpan(
                            text: ' Thrift',
                            style: TextStyle(color: AppPalette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Scoped to the badge so a wishlist change repaints the
                  // icon rather than the whole bar.
                  ListenableBuilder(
                    listenable: WishlistService.instance,
                    builder: (context, _) => AppCountBadge(
                      count: WishlistService.instance.count,
                      child: AppIconButton(
                        icon: Icons.favorite_border,
                        tooltip: 'Wishlist',
                        onPressed: onWishlist,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  AppIconButton(
                    icon: Icons.notifications_none,
                    tooltip: 'Notifications',
                    onPressed: onNotifications,
                  ),
                ],
              ),
            ),
          ),

          // ── Location ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, AppSpacing.xs),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Change city, currently $city',
                  child: GestureDetector(
                    onTap: onCityTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppPalette.accent,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          city,
                          style: AppType.titleSmall.copyWith(
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.expand_more,
                          size: 15,
                          color: AppPalette.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Pre-loved Fashion" hero card: warm wash, serif headline, ink CTA pill
/// and photography bleeding off the trailing edge.
class _PreLovedBanner extends StatelessWidget {
  final VoidCallback onExplore;

  const _PreLovedBanner({required this.onExplore});

  static const _imageUrl =
      'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=600&q=90';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pre-loved fashion. Verified pieces, second lives.',
      child: GestureDetector(
        onTap: onExplore,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: AppPalette.bannerWash,
            borderRadius: AppRadii.card,
            border: Border.all(color: AppPalette.lineWarm),
          ),
          // The copy column drives the height; the photograph stretches to
          // match it, so the two panels stay flush at any text scale.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRE-LOVED\nFASHION',
                          style: AppType.displayMedium
                              .responsive(context)
                              .copyWith(letterSpacing: 0.4),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Verified pieces. Second lives.',
                          style: AppType.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _InkPill(
                          label: 'Explore',
                          icon: Icons.arrow_forward,
                          onTap: onExplore,
                        ),
                      ],
                    ),
                  ),
                ),
                const Expanded(
                  flex: 4,
                  child: AppImage(url: _imageUrl, cacheWidth: 400),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ink CTA pill shared by the banner and the Style Circle card.
class _InkPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _InkPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppPalette.ink,
        borderRadius: AppRadii.field,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.field,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The pill sits beside flowing copy in the Style Circle card,
                // so its own width is not guaranteed — the label gives before
                // the row can overflow.
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.button.copyWith(
                      fontSize: 11,
                      color: AppPalette.textOnInk,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(icon, size: 13, color: AppPalette.textOnInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The eight-tile department grid — four across, two rows.
class _CategoryGrid extends StatelessWidget {
  final List<_ThriftCategory> categories;
  final ValueChanged<_ThriftCategory> onSelected;

  const _CategoryGrid({required this.categories, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Lives inside the page's own ListView, so it must not scroll or take
      // an unbounded height of its own.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.sm,
        // Tile is a 54pt well plus a label line — taller than it is wide.
        childAspectRatio: 0.86,
      ),
      itemBuilder: (context, i) => _CategoryTile(
        category: categories[i],
        onTap: () => onSelected(categories[i]),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final _ThriftCategory category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: AppPalette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                size: 23,
                color: AppPalette.accentDeep,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppType.bodySmall.copyWith(
                  fontSize: 10.5,
                  color: AppPalette.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card in the Trending Now rail.
class _TrendingCard extends StatelessWidget {
  final ParentProduct product;
  final String heroTag;
  final VoidCallback onTap;

  const _TrendingCard({
    required this.product,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final original = product.originalPriceFormatted;

    return SizedBox(
      width: 148,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: heroTag,
                child: AppImage(
                  url: product.defaultImageUrl,
                  cacheWidth: 320,
                  borderRadius: AppRadii.image,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              product.brand.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.eyebrow.copyWith(
                fontSize: 9,
                letterSpacing: 1.2,
                color: AppPalette.textTertiary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.titleSmall.copyWith(fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                // Both prices flex: a five-figure price beside a struck-out
                // original is wider than the card at large text scales.
                Flexible(
                  child: Text(
                    product.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.price.copyWith(fontSize: 12),
                  ),
                ),
                if (original != null) ...[
                  const SizedBox(width: AppSpacing.xxs + 2),
                  Flexible(
                    child: Text(
                      original,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.priceStrike.copyWith(fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The sell-your-wardrobe prompt under the Style Circle header.
class _StyleCircleBanner extends StatelessWidget {
  final VoidCallback onScan;

  const _StyleCircleBanner({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.surfaceWarm,
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
                  'Ready to clear your wardrobe?',
                  style: AppType.titleSmall.copyWith(fontSize: 13),
                  maxLines: 2,
                ),
                const SizedBox(height: 3),
                Text(
                  'Sell with us and earn Circular Credits.',
                  style: AppType.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _InkPill(
            label: 'Scan item',
            icon: Icons.photo_camera_outlined,
            onTap: onScan,
          ),
        ],
      ),
    );
  }
}

/// The thrift ecosystem's own bottom navigation: four flat destinations around
/// a raised "Sell" action.
///
/// Screen-local rather than an [AppBottomNav] variant — the raised centre
/// action is specific to this subtree, and folding it into the shared
/// component would put a second layout mode into every other screen's nav.
class _ThriftBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ThriftBottomNav({required this.currentIndex, required this.onTap});

  static const _items = <({IconData icon, IconData activeIcon, String label})>[
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    (icon: Icons.search, activeIcon: Icons.search, label: 'Browse'),
    // Index 2 is the raised Sell action; it has no flat destination.
    (
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Orders',
    ),
    (
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  /// Maps a position in [_items] onto the destination index the screen uses,
  /// stepping over the Sell slot in the middle.
  int _destinationFor(int slot) => slot < 2 ? slot : slot + 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(top: BorderSide(color: AppPalette.line)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 64,
        child: Stack(
          // The Sell button rises above the bar's top edge.
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                for (var slot = 0; slot < 2; slot++)
                  Expanded(
                    child: _NavDestination(
                      item: _items[slot],
                      selected: currentIndex == _destinationFor(slot),
                      onTap: () => onTap(_destinationFor(slot)),
                    ),
                  ),
                // Reserves the centre column, and keeps the area beneath the
                // raised button tappable — hit tests do not reach the part of
                // the circle that overhangs the bar.
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(2),
                    child: const SizedBox.expand(),
                  ),
                ),
                for (var slot = 2; slot < _items.length; slot++)
                  Expanded(
                    child: _NavDestination(
                      item: _items[slot],
                      selected: currentIndex == _destinationFor(slot),
                      onTap: () => onTap(_destinationFor(slot)),
                    ),
                  ),
              ],
            ),
            Positioned(
              top: -16,
              left: 0,
              right: 0,
              child: Center(child: _SellAction(onTap: () => onTap(2))),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellAction extends StatelessWidget {
  final VoidCallback onTap;

  const _SellAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sell an item',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppPalette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.canvas, width: 3),
                boxShadow: AppShadows.card,
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 23,
                color: AppPalette.textOnDark,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'SELL',
              style: AppType.badge.copyWith(
                fontSize: 8,
                letterSpacing: 0.8,
                color: AppPalette.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  final ({IconData icon, IconData activeIcon, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.accent : AppPalette.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              height: 2,
              width: selected ? 18 : 0,
              decoration: const BoxDecoration(
                color: AppPalette.accent,
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Icon(selected ? item.activeIcon : item.icon, size: 21, color: color),
            const SizedBox(height: AppSpacing.xxs + 1),
            Text(
              item.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.badge.copyWith(
                fontSize: 8,
                letterSpacing: 0.8,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
