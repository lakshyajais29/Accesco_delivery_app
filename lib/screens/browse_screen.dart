import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../services/catalog_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/ds/ds.dart';
import 'product_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BROWSE — the search interface, from Figma node 490:567.
//
//  Structure: serif "Browse" title, search field with voice + camera affordances,
//  a row of filter dropdowns (Size · Condition · Distance · Price) with an
//  overflow filter button, a result count paired with a sort control, then the
//  graded product grid.
//
//  Search and filtering run entirely against CatalogService — the same
//  in-memory catalogue every other screen reads — so nothing here depends on a
//  backend that doesn't exist yet.
// ─────────────────────────────────────────────────────────────────────────────

/// The filter dimensions the design exposes.
enum _FilterKind { size, condition, distance, price }

extension _FilterKindLabel on _FilterKind {
  String get label => switch (this) {
        _FilterKind.size => 'Size',
        _FilterKind.condition => 'Condition',
        _FilterKind.distance => 'Distance',
        _FilterKind.price => 'Price',
      };

  /// Options per dimension. Sizes are resolved from the live catalogue at
  /// build time; the rest are fixed bands.
  List<String> get options => switch (this) {
        _FilterKind.size => const ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
        _FilterKind.condition => const [
            'Like New',
            'Gently Used',
            'Vintage Find',
          ],
        _FilterKind.distance => const [
            'Within 2 km',
            'Within 5 km',
            'Within 10 km',
            'Any distance',
          ],
        _FilterKind.price => const [
            'Under ₹1,000',
            '₹1,000 – ₹3,000',
            '₹3,000 – ₹6,000',
            'Over ₹6,000',
          ],
      };
}

enum _BrowseSort { newest, priceLowToHigh, priceHighToLow, nearest }

extension _BrowseSortLabel on _BrowseSort {
  String get label => switch (this) {
        _BrowseSort.newest => 'Newest',
        _BrowseSort.priceLowToHigh => 'Price: Low to High',
        _BrowseSort.priceHighToLow => 'Price: High to Low',
        _BrowseSort.nearest => 'Nearest',
      };

  String get shortLabel => switch (this) {
        _BrowseSort.newest => 'Newest',
        _BrowseSort.priceLowToHigh => 'Price ↑',
        _BrowseSort.priceHighToLow => 'Price ↓',
        _BrowseSort.nearest => 'Nearest',
      };
}

class BrowseScreen extends StatefulWidget {
  /// Pre-seeds the query — lets the home search bar hand off a term.
  final String? initialQuery;

  const BrowseScreen({super.key, this.initialQuery});

  static Route<void> route({String? initialQuery}) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => BrowseScreen(initialQuery: initialQuery),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late final TextEditingController _searchController;

  String _query = '';
  _BrowseSort _sort = _BrowseSort.newest;
  final Map<_FilterKind, String> _activeFilters = {};

  List<ParentProduct> _results = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _query = widget.initialQuery ?? '';
    _recompute();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount => _activeFilters.length;

  /// Applies query, filters and sort in one pass and caches the result, so
  /// scrolling the grid never re-runs the search.
  void _recompute() {
    final query = _query.trim().toLowerCase();

    var items = CatalogService.getAll().where((product) {
      if (query.isNotEmpty) {
        final haystack = '${product.name} ${product.brand} ${product.category}'
            .toLowerCase();
        if (!haystack.contains(query)) return false;
      }

      final size = _activeFilters[_FilterKind.size];
      if (size != null && !product.sizes.contains(size)) return false;

      final condition = _activeFilters[_FilterKind.condition];
      if (condition != null && product.conditionLabel != condition) {
        return false;
      }

      final price = _activeFilters[_FilterKind.price];
      if (price != null && !_matchesPriceBand(product, price)) return false;

      return true;
    }).toList();

    switch (_sort) {
      case _BrowseSort.newest:
        items.sort((a, b) {
          final aAge = a.droppedMinsAgo == 0 ? 1 << 30 : a.droppedMinsAgo;
          final bAge = b.droppedMinsAgo == 0 ? 1 << 30 : b.droppedMinsAgo;
          return aAge.compareTo(bAge);
        });
      case _BrowseSort.priceLowToHigh:
        items.sort((a, b) => _lowestPaise(a).compareTo(_lowestPaise(b)));
      case _BrowseSort.priceHighToLow:
        items.sort((a, b) => _lowestPaise(b).compareTo(_lowestPaise(a)));
      case _BrowseSort.nearest:
        // No per-product coordinate in the catalogue yet, so "nearest" falls
        // back to city rank — the closest proxy the data supports. Swap for a
        // real distance once listings carry a store location.
        items.sort((a, b) {
          final aRank = a.cityRank == 0 ? 1 << 30 : a.cityRank;
          final bRank = b.cityRank == 0 ? 1 << 30 : b.cityRank;
          return aRank.compareTo(bRank);
        });
    }

    _results = items;
  }

  bool _matchesPriceBand(ParentProduct product, String band) {
    final rupees = _lowestPaise(product) ~/ 100;
    return switch (band) {
      'Under ₹1,000' => rupees < 1000,
      '₹1,000 – ₹3,000' => rupees >= 1000 && rupees <= 3000,
      '₹3,000 – ₹6,000' => rupees > 3000 && rupees <= 6000,
      'Over ₹6,000' => rupees > 6000,
      _ => true,
    };
  }

  int _lowestPaise(ParentProduct product) {
    if (product.variantMap.isEmpty) return 1 << 30;
    return product.variantMap.values
        .map((v) => v.priceInPaise)
        .reduce((a, b) => a < b ? a : b);
  }

  Future<void> _openFilterSheet(_FilterKind kind) async {
    final selected = await showAppSheet<String>(
      context,
      child: AppSheet(
        title: kind.label,
        subtitle: 'Narrow results by ${kind.label.toLowerCase()}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in kind.options)
              ListTile(
                onTap: () => Navigator.of(context).pop(option),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.page(context),
                ),
                title: Text(
                  option,
                  style: AppType.bodyLarge.copyWith(
                    color: AppPalette.textPrimary,
                    fontWeight: _activeFilters[kind] == option
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                trailing: _activeFilters[kind] == option
                    ? const Icon(
                        Icons.check,
                        size: 19,
                        color: AppPalette.accent,
                      )
                    : null,
              ),
            // Explicit clear — tapping the active option again would be a
            // hidden affordance.
            if (_activeFilters.containsKey(kind))
              ListTile(
                onTap: () => Navigator.of(context).pop('__clear__'),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.page(context),
                ),
                leading: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppPalette.danger,
                ),
                title: Text(
                  'Clear ${kind.label.toLowerCase()}',
                  style: AppType.bodyLarge.copyWith(color: AppPalette.danger),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() {
      if (selected == '__clear__') {
        _activeFilters.remove(kind);
      } else {
        _activeFilters[kind] = selected;
      }
      _recompute();
    });
  }

  Future<void> _openSortSheet() async {
    final selected = await showAppSheet<_BrowseSort>(
      context,
      child: AppSheet(
        title: 'Sort By',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in _BrowseSort.values)
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
      _recompute();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _activeFilters.clear();
      _recompute();
    });
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
            const AppTopBar(title: 'Browse', serif: true),

            // ── Search ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                inset,
                AppSpacing.xs,
                inset,
                AppSpacing.sm,
              ),
              child: AppSearchBar(
                controller: _searchController,
                hint: 'Search products, brands, styles…',
                autofocus: widget.initialQuery == null,
                onChanged: (value) => setState(() {
                  _query = value;
                  _recompute();
                }),
                onClear: _query.isEmpty
                    ? null
                    : () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _recompute();
                        });
                      },
                trailing: [
                  AppIconButton(
                    icon: Icons.mic_none_outlined,
                    size: 18,
                    tooltip: 'Voice search',
                    onPressed: () => AppSnack.show(
                      context,
                      'Voice search is coming soon',
                      icon: Icons.mic_none_outlined,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.camera_alt_outlined,
                    size: 18,
                    tooltip: 'Search by photo',
                    onPressed: () => AppSnack.show(
                      context,
                      'Photo search is coming soon',
                      icon: Icons.camera_alt_outlined,
                    ),
                  ),
                ],
              ),
            ),

            // ── Filter dropdowns ──────────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: inset),
                children: [
                  for (final kind in _FilterKind.values) ...[
                    _FilterDropdown(
                      label: _activeFilters[kind] ?? kind.label,
                      isActive: _activeFilters.containsKey(kind),
                      onTap: () => _openFilterSheet(kind),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  if (_activeFilterCount > 0)
                    AppIconButton(
                      icon: Icons.filter_alt_off_outlined,
                      size: 18,
                      tooltip: 'Clear all filters',
                      onPressed: _clearAllFilters,
                    ),
                ],
              ),
            ),

            // ── Count + sort ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                inset,
                AppSpacing.md,
                inset,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_results.length} '
                      '${_results.length == 1 ? 'item' : 'items'}',
                      style: AppType.bodyMedium.copyWith(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openSortSheet,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sort by: ',
                          style: AppType.bodySmall.copyWith(fontSize: 12),
                        ),
                        Text(
                          _sort.shortLabel,
                          style: AppType.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.expand_more,
                          size: 16,
                          color: AppPalette.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Results ───────────────────────────────────────────────
            Expanded(child: _buildResults(inset)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(double inset) {
    if (_results.isEmpty) {
      return AppStateView.empty(
        icon: Icons.search_off_outlined,
        title: 'No matches',
        message: _query.isEmpty
            ? 'No pieces fit those filters. Try widening them.'
            : 'Nothing matches "$_query". Try a different term or fewer '
                'filters.',
        actionLabel: _activeFilterCount > 0 ? 'Clear Filters' : null,
        onAction: _activeFilterCount > 0 ? _clearAllFilters : null,
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        inset,
        0,
        inset,
        AppSpacing.safeBottom(context, extra: AppSpacing.xl),
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: AppProductGridDelegate.of(context),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final product = _results[i];
        final heroTag = 'browse-${product.id}-$i';
        return ListenableBuilder(
          listenable: WishlistService.instance,
          builder: (context, _) => AppProductCard(
            name: product.name,
            subtitle: product.brand,
            imageUrl: product.defaultImageUrl,
            price: product.price,
            originalPrice: product.originalPriceFormatted,
            heroTag: heroTag,
            soldOut: product.stock <= 0,
            // The design stamps a condition grade on every browse card.
            badge: product.conditionGrade == null
                ? null
                : AppBadge(
                    product.conditionGrade!,
                    tone: AppBadgeTone.neutral,
                  ),
            isWishlisted: WishlistService.instance.containsId(product.id),
            onWishlistToggle: () =>
                WishlistService.instance.toggle(product),
            onTap: () => Navigator.push(
              context,
              ProductDetailScreen.route(product, heroTag: heroTag),
            ),
          ),
        );
      },
    );
  }
}

/// A pill dropdown from the design's filter row. Fills with the brand tint
/// once a value is chosen so active filters are obvious at a glance.
class _FilterDropdown extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterDropdown({
    required this.label,
    required this.isActive,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppPalette.accentSoft : AppPalette.surface,
          borderRadius: AppRadii.chip,
          border: Border.all(
            color: isActive ? AppPalette.accent : AppPalette.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppType.label.copyWith(
                fontSize: 12,
                color: isActive
                    ? AppPalette.accentDeep
                    : AppPalette.textPrimary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more,
              size: 15,
              color:
                  isActive ? AppPalette.accentDeep : AppPalette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
