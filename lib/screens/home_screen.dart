import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../services/catalog_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/ds/ds.dart';
import '../widgets/thrift_marketplace_section.dart';
import 'browse_screen.dart';
import 'instant_outfit_builder_screen.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import 'style_circle_screen.dart';
import 'profile_screen.dart';
import 'thrift/thrift_home_screen.dart';
import 'swipe_style_screen.dart';
import 'trial_at_doorstep_screen.dart';
import 'virtual_try_on_screen.dart';
import 'wishlist_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HOME — the editorial storefront.
//
//  Structure, top to bottom:
//    1. Brand bar          — wordmark + wishlist/bag actions
//    2. Search bar         — free-text search + visual search camera
//    3. Category avatars   — circular photographic department tiles
//    4. Editorial banner   — rotating campaign card, keyed to the category
//    5. Curated rails      — Just Dropped / Almost Gone / Trending / Vibe Check
//    6. Thrift Marketplace — promotional banner into the resale ecosystem
//    7. The Edit           — refine + sort bar, result count, product grid
//    8. Quick reorder      — recent purchases, one tap away
//
//  All catalogue queries, filter semantics and navigation targets are the
//  originals; only the presentation layer changed.
// ─────────────────────────────────────────────────────────────────────────────

/// Catalogue filters. Unchanged from the original implementation.
///
/// The icon row that used to drive these is gone; the department avatars at
/// the top of the page and the Refine sheet now set them, and they still cut
/// every rail and the grid exactly as before.
enum _CatalogFilter { all, men, women, unisex, latestDrops }

extension _FilterPresentation on _CatalogFilter {
  String get label => switch (this) {
    _CatalogFilter.all => 'Everyday',
    _CatalogFilter.men => 'Men',
    _CatalogFilter.women => 'Women',
    _CatalogFilter.unisex => 'Unisex',
    _CatalogFilter.latestDrops => 'New In',
  };

  ProductGender? get gender => switch (this) {
    _CatalogFilter.men => ProductGender.men,
    _CatalogFilter.women => ProductGender.women,
    _CatalogFilter.unisex => ProductGender.unisex,
    _ => null,
  };
}

/// Ordering options for the grid. Presentation-only — it sorts the list the
/// catalogue already returned rather than changing any query.
enum _SortOption { newest, priceLowToHigh, priceHighToLow, trending }

extension _SortLabel on _SortOption {
  String get label => switch (this) {
    _SortOption.newest => 'Newest',
    _SortOption.priceLowToHigh => 'Price: Low to High',
    _SortOption.priceHighToLow => 'Price: High to Low',
    _SortOption.trending => 'Trending',
  };

  /// Compact form for the sort bar, which has room for roughly one word.
  String get shortLabel => switch (this) {
    _SortOption.newest => 'Newest',
    _SortOption.priceLowToHigh => 'Price ↑',
    _SortOption.priceHighToLow => 'Price ↓',
    _SortOption.trending => 'Trending',
  };
}

/// Campaign banners. Each carries the editorial kicker + serif headline pair
/// that defines the brand's voice.
class _Campaign {
  final String eyebrow;
  final String headline;
  final String body;
  final String cta;
  final String imageUrl;

  const _Campaign({
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.cta,
    required this.imageUrl,
  });
}

const _campaigns = <_Campaign>[
  _Campaign(
    eyebrow: 'The Studio',
    headline: 'Fashion,\nRefined',
    body: 'A curated selection of considered pieces, delivered in minutes.',
    cta: 'Explore',
    imageUrl:
        'https://images.unsplash.com/photo-1441984904996-e0b6ba687e04?w=800&q=90',
  ),
  _Campaign(
    eyebrow: 'The Curation',
    headline: 'Shop\nthe Edit',
    body: 'Everything our stylists are reaching for this season.',
    cta: 'View Edit',
    imageUrl:
        'https://images.unsplash.com/photo-1489987707025-afc232f7ea0f?w=800&q=90',
  ),
  _Campaign(
    eyebrow: 'The Collection',
    headline: 'Everyday\nLuxe',
    body: 'Elevated basics that carry you from morning to evening.',
    cta: 'Discover',
    imageUrl:
        'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=800&q=90',
  ),
];

/// A photographic department tile in the circular avatar row under the search
/// bar.
///
/// Two behaviours, one row. Departments the catalogue already models map onto
/// a [_CatalogFilter] and re-cut the page in place — the same semantics as the
/// icon taxonomy row further down, so the two controls never disagree.
/// Departments the catalogue has no gender for (Kids, Beauty, Home) hand their
/// label to [BrowseScreen] as a search term instead of pretending to filter.
class _Department {
  final String label;
  final String imageUrl;

  /// Non-null when this department maps onto an existing catalogue filter.
  final _CatalogFilter? filter;

  const _Department({
    required this.label,
    required this.imageUrl,
    this.filter,
  });
}

const _departments = <_Department>[
  _Department(
    label: 'Women',
    filter: _CatalogFilter.women,
    imageUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80',
  ),
  _Department(
    label: 'Men',
    filter: _CatalogFilter.men,
    imageUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&q=80',
  ),
  _Department(
    label: 'Kids',
    imageUrl:
        'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?w=200&q=80',
  ),
  _Department(
    label: 'Beauty',
    imageUrl:
        'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=200&q=80',
  ),
  _Department(
    label: 'Home',
    imageUrl:
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=200&q=80',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  _CatalogFilter _filter = _CatalogFilter.all;
  _SortOption _sort = _SortOption.newest;
  int _campaignIndex = 0;
  int _navIndex = 0;

  Timer? _campaignTimer;
  late final AnimationController _entranceCtrl;

  // ── Search ────────────────────────────────────────────────────────────
  // The bar is a live field rather than a read-only tap target: typing keeps
  // the clear affordance honest, and submitting hands the term to
  // [BrowseScreen], which owns the actual search + filter UI.
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // ── Location ──────────────────────────────────────────────────────────
  // Drives the Thrift Marketplace's nearby-store rail. Stays null until a fix
  // is available; the section renders its banner regardless, so a user who
  // has declined location permission still sees the feature.
  double? _latitude;
  double? _longitude;

  // ── Memoised catalogue slices ─────────────────────────────────────────
  // The catalogue queries filter and sort the full list on every call, so
  // running them inside build() would re-sort five lists on every frame that
  // a heart toggles. They are recomputed only when the filter actually
  // changes.
  _CatalogFilter? _cachedFor;
  List<ParentProduct> _justDropped = const [];
  List<ParentProduct> _almostGone = const [];
  List<ParentProduct> _trending = const [];
  List<ParentProduct> _vibeCheck = const [];
  List<ParentProduct> _reorders = const [];
  List<ParentProduct> _gridItems = const [];

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(vsync: this, duration: AppMotion.slow)
      ..forward();

    _rebuildCatalogue();

    _campaignTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() => _campaignIndex = (_campaignIndex + 1) % _campaigns.length);
    });

    // Hydrate the wishlist so hearts are correct on first paint rather than
    // popping in after the user has already scrolled past them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WishlistService.instance.load();
      _resolveLocation();
      for (final campaign in _campaigns) {
        precacheImage(NetworkImage(campaign.imageUrl), context);
      }
    });
  }

  @override
  void dispose() {
    _campaignTimer?.cancel();
    _entranceCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _rebuildCatalogue({bool force = false}) {
    if (_cachedFor == _filter && !force) return;
    _cachedFor = _filter;

    final gender = _filter.gender;

    _justDropped = _filter == _CatalogFilter.latestDrops
        ? CatalogService.getJustDropped()
        : CatalogService.getJustDropped(gender: gender);
    _almostGone = CatalogService.getAlmostGone(gender: gender);
    _trending = CatalogService.getTrending(gender: gender);
    _vibeCheck = CatalogService.getVibeCheck(gender: gender);
    _reorders = CatalogService.getReorders();

    _gridItems = _applySort(
      _filter == _CatalogFilter.latestDrops
          ? CatalogService.getJustDropped()
          : gender == null
          ? CatalogService.getAll()
          : CatalogService.getForTab(gender),
    );
  }

  List<ParentProduct> _applySort(List<ParentProduct> source) {
    final items = List<ParentProduct>.of(source);
    switch (_sort) {
      case _SortOption.newest:
        // Freshest drops first; anything without a drop time sorts last.
        items.sort((a, b) {
          final aAge = a.droppedMinsAgo == 0 ? 1 << 30 : a.droppedMinsAgo;
          final bAge = b.droppedMinsAgo == 0 ? 1 << 30 : b.droppedMinsAgo;
          return aAge.compareTo(bAge);
        });
      case _SortOption.priceLowToHigh:
        items.sort((a, b) => _lowestPaise(a).compareTo(_lowestPaise(b)));
      case _SortOption.priceHighToLow:
        items.sort((a, b) => _lowestPaise(b).compareTo(_lowestPaise(a)));
      case _SortOption.trending:
        // cityRank is 1-based, 0 meaning "unranked" — push those to the end.
        items.sort((a, b) {
          final aRank = a.cityRank == 0 ? 1 << 30 : a.cityRank;
          final bRank = b.cityRank == 0 ? 1 << 30 : b.cityRank;
          return aRank.compareTo(bRank);
        });
    }
    return items;
  }

  /// Cheapest variant price in paise. Products with no variants sort last
  /// rather than throwing on `reduce` over an empty collection.
  int _lowestPaise(ParentProduct product) {
    if (product.variantMap.isEmpty) return 1 << 30;
    return product.variantMap.values
        .map((v) => v.priceInPaise)
        .reduce((a, b) => a < b ? a : b);
  }

  Future<void> _handleRefresh() async {
    await WishlistService.instance.load(force: true);
    if (!mounted) return;
    setState(() => _rebuildCatalogue(force: true));
  }

  void _selectFilter(_CatalogFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _rebuildCatalogue();
    });
  }

  Future<void> _openSortSheet() async {
    final selected = await showAppSheet<_SortOption>(
      context,
      child: AppSheet(
        title: 'Sort By',
        subtitle: 'Choose how the edit is ordered',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in _SortOption.values)
              ListTile(
                onTap: () => Navigator.of(context).pop(option),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.page(context),
                ),
                title: Text(
                  option.label,
                  style: AppType.bodyLarge.copyWith(
                    color: AppPalette.textPrimary,
                    fontWeight: option == _sort
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                trailing: option == _sort
                    ? const Icon(
                        Icons.check,
                        size: 19,
                        color: AppPalette.accent,
                      )
                    : null,
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (selected == null || selected == _sort || !mounted) return;
    setState(() {
      _sort = selected;
      _gridItems = _applySort(_gridItems);
    });
  }

  Future<void> _openRefineSheet() async {
    final selected = await showAppSheet<_CatalogFilter>(
      context,
      child: AppSheet(
        title: 'Refine',
        subtitle: 'Narrow the edit to what you\'re after',
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page(context),
            AppSpacing.md,
            AppSpacing.page(context),
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Category'.toUpperCase(), style: AppType.eyebrow),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final filter in _CatalogFilter.values)
                    AppChip(
                      label: filter.label,
                      selected: filter == _filter,
                      onTap: () => Navigator.of(context).pop(filter),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    _selectFilter(selected);
  }

  /// Supplies the coordinate the thrift rail queries against.
  ///
  /// Currently falls back to InstaStyle's operating city so the rail has data
  /// to show. Wire this to a real device fix (`permission_handler` plus a
  /// location plugin) when that flow is built — the section already handles a
  /// null coordinate by rendering the banner alone.
  void _resolveLocation() {
    if (!mounted) return;
    setState(() {
      _latitude = 17.4065; // Hyderabad — matches the "Trending in" rail.
      _longitude = 78.4772;
    });
  }

  // ── Search ──────────────────────────────────────────────────────────────
  /// Hands the typed term to the search screen. Empty input is a no-op rather
  /// than a push onto an unfiltered grid.
  void _submitSearch(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    _searchFocus.unfocus();
    Navigator.push(context, BrowseScreen.route(initialQuery: query));
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {}); // Drops the clear affordance.
  }

  /// The camera in the search bar — search by picture rather than by word.
  void _openVisualSearch() {
    _searchFocus.unfocus();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const VirtualTryOnScreen(),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      ),
    );
  }

  /// A department tile in the avatar row. See [_Department] for why the two
  /// branches differ.
  void _openDepartment(_Department department) {
    final filter = department.filter;
    if (filter != null) {
      _selectFilter(filter);
      return;
    }
    Navigator.push(
      context,
      BrowseScreen.route(initialQuery: department.label),
    );
  }

  /// Enters the nested thrift ecosystem.
  ///
  /// Everything resale — browsing, listing, seller tools — lives inside
  /// [ThriftHomeScreen] rather than on the main navigation, so this is the
  /// single door into that subtree. [ThriftHomeScreen.route] is the app's
  /// standard fade transition.
  void _openThriftMarketplace({String? storeId}) {
    Navigator.push(context, ThriftHomeScreen.route());
  }

  void _openProduct(ParentProduct product, String heroTag) {
    Navigator.push(
      context,
      ProductDetailScreen.route(product, heroTag: heroTag),
    );
  }

  void _handleNavTap(int index) {
    // Destinations 1–4 push feature screens; the home tab stays put. This
    // mirrors the original navigation exactly.
    switch (index) {
      case 1:
        Navigator.push(context, SwipeStyleScreen.route());
      case 2:
        Navigator.push(context, InstantOutfitBuilderScreen.route());
      case 3:
        // The Thrift tab opens the nested ecosystem hub, not the listing grid
        // directly — buying and selling both live behind it.
        Navigator.push(context, ThriftHomeScreen.route());
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TrialAtDoorstepScreen(orderId: 'ORDER123', riderId: 'RIDER456'),
          ),
        );
      default:
        setState(() => _navIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final campaign = _campaigns[_campaignIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: Column(
          children: [
            RepaintBoundary(
              child: AppBrandBar(
                actions: [
                  // Listens to the wishlist so the count on the heart stays
                  // truthful without rebuilding the whole screen.
                  ListenableBuilder(
                    listenable: WishlistService.instance,
                    builder: (context, _) => AppCountBadge(
                      count: WishlistService.instance.count,
                      child: AppIconButton(
                        icon: Icons.favorite_border,
                        tooltip: 'Wishlist',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WishlistScreen(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  AppIconButton(
                    icon: Icons.shopping_bag_outlined,
                    tooltip: 'Bag',
                    onPressed: () =>
                        Navigator.push(context, CartScreen.route()),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  AppIconButton(
                    icon: Icons.person_outline,
                    tooltip: 'Profile',
                    onPressed: () =>
                        Navigator.push(context, ProfileScreen.route()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FadeTransition(
                opacity: _entranceCtrl.drive(
                  CurveTween(curve: AppMotion.enter),
                ),
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppPalette.accent,
                  backgroundColor: AppPalette.surface,
                  strokeWidth: 2,
                  child: CustomScrollView(
                    key: const PageStorageKey<String>('home_scroll'),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // ── 1. Search ──────────────────────────────────────
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          inset,
                          AppSpacing.sm,
                          inset,
                          AppSpacing.md,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: AppSearchBar(
                            hint: 'Search for products, brands & more',
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            fillColor: AppPalette.surfaceMuted,
                            borderColor: Colors.transparent,
                            onChanged: (value) {
                              // Only rebuild on the empty↔non-empty edge —
                              // the clear icon is the sole thing that
                              // depends on the text.
                              if (value.isEmpty || value.length == 1) {
                                setState(() {});
                              }
                            },
                            onSubmitted: _submitSearch,
                            onClear:
                                _searchCtrl.text.isEmpty ? null : _clearSearch,
                            trailing: [
                              _SearchCameraButton(onTap: _openVisualSearch),
                            ],
                          ),
                        ),
                      ),

                      // ── 2. Department avatars ──────────────────────────
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: _DepartmentRow(
                            departments: _departments,
                            activeFilter: _filter,
                            onSelected: _openDepartment,
                          ),
                        ),
                      ),

                      // ── 3. Campaign banner ─────────────────────────────
                      // No bottom inset: the section header that follows
                      // brings its own top padding, which is the same rhythm
                      // every other section break uses.
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          inset,
                          AppSpacing.md,
                          inset,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: AnimatedSwitcher(
                            duration: AppMotion.slow,
                            switchInCurve: AppMotion.enter,
                            child: AppEditorialBanner(
                              key: ValueKey(_campaignIndex),
                              eyebrow: campaign.eyebrow,
                              headline: campaign.headline,
                              body: campaign.body,
                              ctaLabel: campaign.cta,
                              imageUrl: campaign.imageUrl,
                              onTap: () =>
                                  _selectFilter(_CatalogFilter.latestDrops),
                            ),
                          ),
                        ),
                      ),

                      // ── 4. Curated rails ───────────────────────────────
                      ..._buildRail(
                        title: 'Just Dropped',
                        subtitle: 'Fresh in, minutes ago',
                        products: _justDropped,
                        railKey: 'justDropped',
                        badgeFor: (p) =>
                            const AppBadge('New', tone: AppBadgeTone.accent),
                        signalFor: (p) => p.droppedMinsAgo > 0
                            ? AppSignalTag(
                                icon: Icons.bolt,
                                color: AppPalette.accent,
                                label: p.droppedMinsAgo < 60
                                    ? 'Dropped ${p.droppedMinsAgo}m ago'
                                    : 'Dropped ${p.droppedMinsAgo ~/ 60}h ago',
                              )
                            : null,
                      ),
                      ..._buildRail(
                        title: 'Almost Gone',
                        subtitle: 'Low stock — move quickly',
                        products: _almostGone,
                        railKey: 'almostGone',
                        badgeFor: (p) => p.originalPriceFormatted != null
                            ? const AppBadge('Sale', tone: AppBadgeTone.danger)
                            : null,
                        signalFor: (p) => p.stock > 0
                            ? AppSignalTag(
                                icon: Icons.local_fire_department_outlined,
                                color: AppPalette.danger,
                                label: 'Only ${p.stock} left',
                              )
                            : null,
                      ),
                      ..._buildRail(
                        title: 'Trending in Hyderabad',
                        subtitle: 'What your city is wearing',
                        products: _trending,
                        railKey: 'trending',
                        badgeFor: (p) => p.cityRank > 0
                            ? AppBadge(
                                '#${p.cityRank}',
                                tone: AppBadgeTone.inverse,
                              )
                            : null,
                        signalFor: (p) => p.orderedToday > 0
                            ? AppSignalTag(
                                icon: Icons.trending_up,
                                color: AppPalette.warning,
                                label: '${p.orderedToday} ordered today',
                              )
                            : null,
                      ),
                      ..._buildRail(
                        title: 'Vibe Check',
                        subtitle: 'Your friends weighed in',
                        products: _vibeCheck,
                        railKey: 'vibeCheck',
                        badgeFor: (p) => AppBadge(
                          '${p.friendVotes}',
                          icon: Icons.thumb_up,
                          tone: AppBadgeTone.inverse,
                        ),
                        signalFor: (p) => AppSignalTag(
                          icon: Icons.people_outline,
                          color: AppPalette.textSecondary,
                          label: '${p.friendVotes} voted yes',
                        ),
                      ),

                      // ── 6. Style Circle ────────────────────────────────
                      // The community feed sits after the curated rails: it
                      // is discovery by people rather than by merchandising.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            inset,
                            AppSpacing.xl,
                            inset,
                            0,
                          ),
                          child: _StyleCircleTeaser(
                            onTap: () => Navigator.push(
                              context,
                              StyleCircleScreen.route(),
                            ),
                          ),
                        ),
                      ),

                      // ── 7. Thrift Marketplace ──────────────────────────
                      // Sits after the discovery rails and before the main
                      // grid: browsing intent is already warm here, but the
                      // user hasn't committed to the catalogue yet.
                      SliverToBoxAdapter(
                        child: ThriftMarketplaceSection(
                          latitude: _latitude,
                          longitude: _longitude,
                          onExplore: _openThriftMarketplace,
                          onStoreTap: (store) =>
                              _openThriftMarketplace(storeId: store.id),
                        ),
                      ),

                      // ── 8. The Edit — refine, count, grid ──────────────
                      const SliverToBoxAdapter(
                        child: AppSectionHeader(
                          title: 'The Edit',
                          subtitle: 'Everything in your selection',
                          serif: true,
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          inset,
                          AppSpacing.xxs,
                          inset,
                          AppSpacing.sm,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: AppRefineBar(
                            sortLabel: _sort.shortLabel,
                            onRefine: _openRefineSheet,
                            onSort: _openSortSheet,
                            activeFilterCount: _filter == _CatalogFilter.all
                                ? 0
                                : 1,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          inset,
                          AppSpacing.xxs,
                          inset,
                          AppSpacing.md,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: AppResultCount(count: _gridItems.length),
                        ),
                      ),
                      _buildGrid(inset),

                      // ── 9. Quick reorder ───────────────────────────────
                      SliverToBoxAdapter(child: _buildQuickReorder()),
                      SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xxl),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            RepaintBoundary(
              child: AppBottomNav(
                currentIndex: _navIndex,
                onTap: _handleNavTap,
                items: const [
                  AppNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Home',
                  ),
                  AppNavItem(
                    icon: Icons.style_outlined,
                    activeIcon: Icons.style,
                    label: 'Swipe',
                  ),
                  AppNavItem(
                    icon: Icons.grid_view_outlined,
                    activeIcon: Icons.grid_view,
                    label: 'Build',
                  ),
                  AppNavItem(
                    icon: Icons.storefront_outlined,
                    activeIcon: Icons.storefront,
                    label: 'Thrift',
                  ),
                  AppNavItem(
                    icon: Icons.local_shipping_outlined,
                    activeIcon: Icons.local_shipping,
                    label: 'Trial',
                    badgeCount: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rails ───────────────────────────────────────────────────────────────
  /// Builds a section header + horizontal rail pair, or nothing at all when
  /// the slice is empty. Returns slivers so the caller can spread them
  /// straight into the scroll view.
  List<Widget> _buildRail({
    required String title,
    required String subtitle,
    required List<ParentProduct> products,
    required String railKey,
    Widget? Function(ParentProduct)? badgeFor,
    Widget? Function(ParentProduct)? signalFor,
  }) {
    if (products.isEmpty) return const [];

    final cardWidth = AppProductGridDelegate.railCardWidth(context);
    final railHeight = AppProductGridDelegate.railHeight(
      context,
      extra: AppSpacing.md,
    );

    // Stable keys are essential here, not cosmetic. These slivers are
    // conditionally present — a rail returns [] when its slice is empty — and
    // every entry is the same SliverToBoxAdapter type. Without keys, Flutter
    // matches children positionally, so when one rail disappears it hands the
    // next rail's ListView the previous rail's State. Any GlobalKey inside
    // (Hero, Scrollable) then gets reparented into a mismatched slot.
    return [
      SliverToBoxAdapter(
        key: ValueKey('rail-header-$railKey'),
        child: AppSectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: 'See All',
          onAction: () => _selectFilter(_filter),
        ),
      ),
      SliverToBoxAdapter(
        key: ValueKey('rail-body-$railKey'),
        child: RepaintBoundary(
          child: SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.page(context),
              ),
              physics: const BouncingScrollPhysics(),
              addAutomaticKeepAlives: false,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) {
                final product = products[i];
                final heroTag = '$railKey-${product.id}-$i';
                return SizedBox(
                  width: cardWidth,
                  child: _WishlistAwareCard(
                    product: product,
                    heroTag: heroTag,
                    badge: badgeFor?.call(product),
                    signal: signalFor?.call(product),
                    onTap: () => _openProduct(product, heroTag),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ];
  }

  // ── Grid ────────────────────────────────────────────────────────────────
  Widget _buildGrid(double inset) {
    if (_gridItems.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: AppStateView.empty(
            icon: Icons.search_off_outlined,
            title: 'Nothing in this edit',
            message:
                'We haven\'t got anything matching that selection right now. '
                'Try a different category.',
            actionLabel: 'Show Everything',
            onAction: () => _selectFilter(_CatalogFilter.all),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      sliver: SliverGrid(
        gridDelegate: AppProductGridDelegate.of(context),
        delegate: SliverChildBuilderDelegate((context, i) {
          final product = _gridItems[i];
          final heroTag = 'grid-${product.id}-$i';
          return _WishlistAwareCard(
            product: product,
            heroTag: heroTag,
            badge: product.isNew
                ? const AppBadge('New', tone: AppBadgeTone.accent)
                : product.originalPriceFormatted != null
                ? const AppBadge('Sale', tone: AppBadgeTone.danger)
                : null,
            signal: product.stock < 4
                ? AppSignalTag(
                    icon: Icons.local_fire_department_outlined,
                    color: AppPalette.danger,
                    label: 'Only ${product.stock} left',
                  )
                : null,
            onTap: () => _openProduct(product, heroTag),
          );
        }, childCount: _gridItems.length),
      ),
    );
  }

  // ── Quick reorder ───────────────────────────────────────────────────────
  Widget _buildQuickReorder() {
    if (_reorders.isEmpty) return const SizedBox.shrink();
    final inset = AppSpacing.page(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, AppSpacing.xxl, inset, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppPalette.ink,
          borderRadius: AppRadii.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.replay, size: 15, color: AppPalette.gold),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Quick Reorder'.toUpperCase(),
                    style: AppType.overline.copyWith(
                      color: AppPalette.textOnDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Your recent orders — one tap away',
              style: AppType.bodySmall.copyWith(
                color: AppPalette.textOnDark.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                addAutomaticKeepAlives: false,
                physics: const BouncingScrollPhysics(),
                itemCount: _reorders.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final product = _reorders[i];
                  return SizedBox(
                    width: 92,
                    child: GestureDetector(
                      onTap: () =>
                          _openProduct(product, 'reorder-${product.id}-$i'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppImage(
                              url: product.defaultImageUrl,
                              cacheWidth: 200,
                              borderRadius: AppRadii.image,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodySmall.copyWith(
                              color: AppPalette.textOnDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The camera at the trailing edge of the search bar — visual search.
class _SearchCameraButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchCameraButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search by photo',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          // Generous horizontal padding so the 20pt glyph still clears the
          // 44pt minimum tap target inside a 46pt-tall bar.
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Icon(
            Icons.photo_camera_outlined,
            size: 20,
            color: AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// The horizontally scrolling row of circular department avatars that sits
/// under the search bar.
class _DepartmentRow extends StatelessWidget {
  final List<_Department> departments;
  final _CatalogFilter activeFilter;
  final ValueChanged<_Department> onSelected;

  const _DepartmentRow({
    required this.departments,
    required this.activeFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
        itemCount: departments.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final department = departments[i];
          return _DepartmentAvatar(
            department: department,
            // Only filter-backed departments can read as selected; the
            // Browse-backed ones navigate away, so they have no resting
            // state to show.
            selected: department.filter != null &&
                department.filter == activeFilter,
            onTap: () => onSelected(department),
          );
        },
      ),
    );
  }
}

class _DepartmentAvatar extends StatelessWidget {
  final _Department department;
  final bool selected;
  final VoidCallback onTap;

  const _DepartmentAvatar({
    required this.department,
    required this.selected,
    required this.onTap,
  });

  static const double _diameter = 62;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: department.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppPalette.accent : AppPalette.line,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: ClipOval(
                  child: AppImage(
                    url: department.imageUrl,
                    width: _diameter,
                    height: _diameter,
                    cacheWidth: 140,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                department.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppType.bodySmall.copyWith(
                  fontSize: 11.5,
                  color: selected
                      ? AppPalette.textPrimary
                      : AppPalette.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A product card bound to [WishlistService].
///
/// Scoping the listener to the individual card means toggling a heart repaints
/// that one card rather than the entire home screen — which matters on a page
/// holding four rails plus a full grid.
class _WishlistAwareCard extends StatelessWidget {
  final ParentProduct product;
  final String heroTag;
  final VoidCallback onTap;
  final Widget? badge;
  final Widget? signal;

  const _WishlistAwareCard({
    required this.product,
    required this.heroTag,
    required this.onTap,
    this.badge,
    this.signal,
  });

  @override
  Widget build(BuildContext context) {
    // The listener is handed to the card so it can scope it to the heart.
    // Wrapping the whole card here would rebuild its Hero on every wishlist
    // change — including mid-flight, which corrupts Hero's internal GlobalKey.
    final wishlisted = WishlistService.instance.containsId(product.id);
    return AppProductCard(
      name: product.name,
      subtitle: product.brand,
      imageUrl: product.defaultImageUrl,
      price: product.price,
      originalPrice: product.originalPriceFormatted,
      heroTag: heroTag,
      badge: badge,
      signal: signal,
      soldOut: product.stock <= 0,
      isWishlisted: wishlisted,
      wishlistListenable: WishlistService.instance,
      wishlistResolver: () => WishlistService.instance.containsId(product.id),
      onWishlistToggle: () {
        WishlistService.instance.toggle(product);
        AppSnack.show(
          context,
          wishlisted
              ? '${product.name} removed from wishlist'
              : '${product.name} added to wishlist',
          icon: wishlisted ? Icons.heart_broken_outlined : Icons.favorite,
        );
      },
      onTap: onTap,
    );
  }
}

/// Entry point to the Style Circle community feed.
///
/// A compact banner rather than an inline rail: the feed has its own filters
/// and staggered layout, and duplicating a slice of it here would compete with
/// the merchandised rails directly above.
class _StyleCircleTeaser extends StatelessWidget {
  final VoidCallback onTap;

  const _StyleCircleTeaser({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                    'The Community'.toUpperCase(),
                    style: AppType.eyebrow.copyWith(color: AppPalette.accent),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Style Circle',
                    style: AppType.displayMedium.responsive(context),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Real people. Real styles. Real inspiration.',
                    style: AppType.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppPalette.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 24,
                color: AppPalette.accentDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
