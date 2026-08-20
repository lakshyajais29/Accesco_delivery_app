import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../services/cart_service.dart';
import '../services/catalog_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/ds/ds.dart';
import 'cart_screen.dart';
import 'instant_outfit_builder_screen.dart';
import 'product_detail_screen.dart';
import 'thrift/thrift_home_screen.dart';
import 'trial_at_doorstep_screen.dart';
import 'vibe_check_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SWIPESTYLE — the deck.
//
//  Structure, top to bottom:
//    1. Header        — back, wordmark, bag with a live count
//    2. Filter row    — Filters · Sort · Brand · Price · More, all live
//    3. Status pill   — how many pieces are left in the current deck
//    4. Card stack    — three deep; the top card is draggable
//    5. Console       — Pass · Undo · Add to Bag
//    6. Cart nudge    — floating pill with thumbnails of what you kept
//    7. Bottom nav    — the app's own five-tab bar, untouched
//
//  The deck is built from [CatalogService], the same in-memory catalogue the
//  rest of the app reads, so the brand/price/category filters operate on real
//  inventory and the card can show a true discount.
//
//  Swipe semantics:
//    ← left   pass
//    → right  keep — adds the piece to the bag via [CartService]
//    ↑ up     vibe check — asks friends, opens [VibeCheckScreen]
//  Every one of them is undoable; see [_undo].
// ─────────────────────────────────────────────────────────────────────────────

enum _SwipeDir { pass, like, vibe }

/// Ordering for the deck. Mirrors the home screen's options so the two
/// surfaces speak the same language.
enum _SortOption { newest, priceLowToHigh, priceHighToLow, trending }

extension _SortLabel on _SortOption {
  String get label => switch (this) {
    _SortOption.newest => 'Newest',
    _SortOption.priceLowToHigh => 'Price: Low to High',
    _SortOption.priceHighToLow => 'Price: High to Low',
    _SortOption.trending => 'Trending',
  };

  /// Compact form for the filter pill, which has room for about one word.
  String get shortLabel => switch (this) {
    _SortOption.newest => 'Sort',
    _SortOption.priceLowToHigh => 'Price ↑',
    _SortOption.priceHighToLow => 'Price ↓',
    _SortOption.trending => 'Trending',
  };
}

/// A price bracket for the Price pill. Bounds are in paise, inclusive of
/// [minPaise] and exclusive of [maxPaise].
class _PriceBand {
  final String label;
  final int minPaise;
  final int maxPaise;

  const _PriceBand(this.label, this.minPaise, this.maxPaise);
}

const _priceBands = <_PriceBand>[
  _PriceBand('Under ₹5,000', 0, 500000),
  _PriceBand('₹5,000 – ₹10,000', 500000, 1000000),
  _PriceBand('₹10,000 – ₹20,000', 1000000, 2000000),
  _PriceBand('Over ₹20,000', 2000000, 1 << 40),
];

/// Actions offered by the overflow ("More") sheet.
enum _MoreAction { toggleStock, clearAll }

/// One resolved swipe, kept so [_undo] can put it back exactly as it was.
///
/// [payload] is set only for a keep: it carries the concrete variant SKU that
/// went to the cart, which is what an undo has to delete.
class _SwipeRecord {
  final ParentProduct product;
  final _SwipeDir direction;
  final CartPayload? payload;

  const _SwipeRecord(this.product, this.direction, {this.payload});
}

class SwipeStyleScreen extends StatefulWidget {
  const SwipeStyleScreen({super.key});

  /// Fade route matching the app's page transition.
  static Route<void> route() => PageRouteBuilder(
    pageBuilder: (_, __, ___) => const SwipeStyleScreen(),
    transitionDuration: AppMotion.slow,
    reverseTransitionDuration: AppMotion.normal,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
      child: child,
    ),
  );

  @override
  State<SwipeStyleScreen> createState() => _SwipeStyleScreenState();
}

class _SwipeStyleScreenState extends State<SwipeStyleScreen>
    with TickerProviderStateMixin {
  // ── Filter state ────────────────────────────────────────────────────────
  _SortOption _sort = _SortOption.newest;
  final Set<String> _brands = <String>{};
  final Set<String> _categories = <String>{};
  _PriceBand? _band;
  bool _inStockOnly = false;

  // ── Deck ────────────────────────────────────────────────────────────────
  List<ParentProduct> _deck = const [];
  int _topIndex = 0;

  /// Everything swiped so far, newest last. Drives Undo.
  final List<_SwipeRecord> _history = [];

  /// Pieces kept this session — the thumbnails on the cart nudge.
  final List<ParentProduct> _bag = [];

  // ── Drag ────────────────────────────────────────────────────────────────
  Offset _drag = Offset.zero;
  double _rotation = 0;
  bool _isDragging = false;
  double _likeHint = 0;
  double _passHint = 0;
  double _vibeHint = 0;

  // ── Motion ──────────────────────────────────────────────────────────────
  late final AnimationController _swipeCtrl;
  late final AnimationController _appearCtrl;
  Animation<Offset> _swipeAnim = const AlwaysStoppedAnimation(Offset.zero);
  _SwipeDir? _swipeDir;

  @override
  void initState() {
    super.initState();

    _swipeCtrl = AnimationController(vsync: this, duration: AppMotion.normal);
    _appearCtrl = AnimationController(vsync: this, duration: AppMotion.normal)
      ..forward();

    _applyFilters();

    // Hydrate the wishlist so the heart on the first card is truthful rather
    // than popping in a beat later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fireAndForget('wishlist load', WishlistService.instance.load);
    });
  }

  @override
  void dispose() {
    _swipeCtrl.dispose();
    _appearCtrl.dispose();
    super.dispose();
  }

  // ── Deck construction ───────────────────────────────────────────────────

  ParentProduct? get _current =>
      _topIndex < _deck.length ? _deck[_topIndex] : null;

  bool get _canUndo => _history.isNotEmpty;

  /// Cheapest variant price in paise; products with no variants sort last.
  int _lowestPaise(ParentProduct product) {
    if (product.variantMap.isEmpty) return 1 << 40;
    return product.variantMap.values
        .map((v) => v.priceInPaise)
        .reduce((a, b) => a < b ? a : b);
  }

  /// Rebuilds the deck from the catalogue and resets it to the first card.
  ///
  /// Mutates state directly — callers outside [initState] wrap it in
  /// `setState`. History is cleared because an undo across a filter change
  /// would put back a card the new filter excludes.
  void _applyFilters() {
    final items = CatalogService.getAll().where((product) {
      if (_brands.isNotEmpty && !_brands.contains(product.brand)) return false;
      if (_categories.isNotEmpty && !_categories.contains(product.category)) {
        return false;
      }
      if (_inStockOnly && product.stock <= 0) return false;
      final band = _band;
      if (band != null) {
        final paise = _lowestPaise(product);
        if (paise < band.minPaise || paise >= band.maxPaise) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _SortOption.newest:
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
        items.sort((a, b) {
          final aRank = a.cityRank == 0 ? 1 << 30 : a.cityRank;
          final bRank = b.cityRank == 0 ? 1 << 30 : b.cityRank;
          return aRank.compareTo(bRank);
        });
    }

    _deck = items;
    _topIndex = 0;
    _history.clear();
    _resetDrag();
  }

  void _clearFilters() {
    setState(() {
      _brands.clear();
      _categories.clear();
      _band = null;
      _inStockOnly = false;
      _sort = _SortOption.newest;
      _applyFilters();
    });
    _appearCtrl.forward(from: 0);
  }

  void _resetDrag() {
    _drag = Offset.zero;
    _rotation = 0;
    _isDragging = false;
    _likeHint = _passHint = _vibeHint = 0;
  }

  // ── Swipe mechanics ─────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails _) {
    if (_swipeCtrl.isAnimating) return;
    setState(() {
      _isDragging = true;
      _drag = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_swipeCtrl.isAnimating) return;
    setState(() {
      _drag += details.delta;
      _rotation = _drag.dx * 0.0011;

      final dx = _drag.dx;
      final dy = _drag.dy;
      if (_drag.distance < 12) {
        _likeHint = _passHint = _vibeHint = 0;
      } else if (dy < -30 && dy.abs() > dx.abs()) {
        _vibeHint = ((-dy - 30) / 70).clamp(0.0, 1.0);
        _likeHint = _passHint = 0;
      } else if (dx > 0) {
        _likeHint = ((dx - 20) / 70).clamp(0.0, 1.0);
        _passHint = _vibeHint = 0;
      } else {
        _passHint = ((-dx - 20) / 70).clamp(0.0, 1.0);
        _likeHint = _vibeHint = 0;
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    final dx = _drag.dx;
    final dy = _drag.dy;
    if (dy < -90 && dy.abs() > dx.abs()) {
      _triggerSwipe(_SwipeDir.vibe);
    } else if (dx > 90) {
      _triggerSwipe(_SwipeDir.like);
    } else if (dx < -90) {
      _triggerSwipe(_SwipeDir.pass);
    } else {
      setState(_resetDrag);
    }
  }

  /// Flings the top card away, then resolves the swipe.
  void _triggerSwipe(_SwipeDir dir) {
    if (_current == null || _swipeCtrl.isAnimating) return;
    HapticFeedback.selectionClick();

    _swipeDir = dir;
    final end = switch (dir) {
      _SwipeDir.like => const Offset(560, 80),
      _SwipeDir.pass => const Offset(-560, 80),
      _SwipeDir.vibe => const Offset(0, -680),
    };

    _swipeAnim = Tween<Offset>(
      begin: _drag,
      end: end,
    ).animate(CurvedAnimation(parent: _swipeCtrl, curve: AppMotion.exit));

    _swipeCtrl.forward(from: 0).then((_) {
      if (mounted) _completeSwipe(dir);
    });
  }

  void _completeSwipe(_SwipeDir dir) {
    final product = _deck[_topIndex];
    final payload = dir == _SwipeDir.like ? _addToBag(product) : null;

    setState(() {
      _history.add(_SwipeRecord(product, dir, payload: payload));
      _topIndex++;
      _swipeDir = null;
      _resetDrag();
    });

    _swipeCtrl.reset();
    _appearCtrl.forward(from: 0);

    if (dir == _SwipeDir.vibe) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VibeCheckScreen()),
      );
    }
  }

  /// Runs a backend call without ever letting it reach the deck.
  ///
  /// Both failure modes have to be caught, and a bare `catchError` only
  /// handles one of them: reaching `CartService.instance` builds its Firebase
  /// handles *synchronously*, so an unconfigured or signed-out app throws
  /// before there is a future to attach to. `WishlistService.load` has the
  /// same shape — it reads `FirebaseAuth.instance` outside its own try.
  ///
  /// The deck is a browsing surface: it keeps working whether or not the
  /// backend is reachable, and the cart screen re-reads the server when it
  /// opens.
  void _fireAndForget(String label, Future<void> Function() call) {
    try {
      call().catchError((Object error) {
        debugPrint('SwipeStyle: $label failed — $error');
      });
    } catch (error) {
      debugPrint('SwipeStyle: $label unavailable — $error');
    }
  }

  /// First in-stock variant, or null when the piece can't be bought.
  ProductVariant? _firstAvailableVariant(ParentProduct product) {
    for (final variant in product.variantMap.values) {
      if (variant.inStock) return variant;
    }
    return null;
  }

  /// Adds a kept piece to the bag and syncs it to the cart.
  ///
  /// The local bag updates immediately and the network call is fire-and-
  /// forget: a swipe deck that stalled on a round-trip would be unusable, and
  /// the cart screen re-reads the source of truth when it opens.
  CartPayload? _addToBag(ParentProduct product) {
    final variant = _firstAvailableVariant(product);
    if (variant == null) {
      AppSnack.show(
        context,
        '${product.name} is out of stock',
        icon: Icons.info_outline,
      );
      return null;
    }

    final payload = CatalogService.buildCartPayload(
      parent: product,
      variant: variant,
    );
    _bag.add(product);
    _fireAndForget('cart add', () => CartService.instance.addItem(payload));

    return payload;
  }

  /// Puts the last swiped card back on the deck, undoing its side effects.
  void _undo() {
    if (!_canUndo || _swipeCtrl.isAnimating) return;
    HapticFeedback.selectionClick();

    final record = _history.removeLast();
    if (record.direction == _SwipeDir.like) {
      _bag.remove(record.product);
      final payload = record.payload;
      if (payload != null) {
        _fireAndForget(
          'cart remove',
          () => CartService.instance.removeItem(payload.variantSku),
        );
      }
    }

    setState(() {
      _topIndex = (_topIndex - 1).clamp(0, _deck.length);
      _resetDrag();
    });
    _appearCtrl.forward(from: 0);

    AppSnack.show(
      context,
      'Back to ${record.product.name}',
      icon: Icons.replay_rounded,
    );
  }

  // ── Filter sheets ───────────────────────────────────────────────────────

  Future<void> _openSortSheet() async {
    final selected = await showAppSheet<_SortOption>(
      context,
      child: AppSheet(
        title: 'Sort By',
        subtitle: 'Choose the order of the deck',
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
                    ? const Icon(Icons.check, size: 19, color: AppPalette.accent)
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
      _applyFilters();
    });
    _appearCtrl.forward(from: 0);
  }

  Future<void> _openBrandSheet() => _openMultiSelectSheet(
    title: 'Brand',
    subtitle: 'Narrow the deck to the labels you wear',
    options:
        (CatalogService.getAll().map((p) => p.brand).toSet().toList()..sort()),
    selection: _brands,
  );

  Future<void> _openCategorySheet() => _openMultiSelectSheet(
    title: 'Filters',
    subtitle: 'Pick the categories you want to see',
    options:
        (CatalogService.getAll().map((p) => p.category).toSet().toList()
          ..sort()),
    selection: _categories,
  );

  /// Shared chip-grid sheet for the two multi-select filters.
  ///
  /// Edits a draft copy so dismissing the sheet leaves the deck alone; only
  /// Apply writes back.
  Future<void> _openMultiSelectSheet({
    required String title,
    required String subtitle,
    required List<String> options,
    required Set<String> selection,
  }) async {
    final draft = Set<String>.of(selection);

    final result = await showAppSheet<Set<String>>(
      context,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => AppSheet(
          title: title,
          subtitle: subtitle,
          footer: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.page(sheetContext),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'Clear',
                    onPressed: () => setSheetState(draft.clear),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Apply',
                    onPressed: () => Navigator.of(sheetContext).pop(draft),
                  ),
                ),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page(sheetContext),
              0,
              AppSpacing.page(sheetContext),
              AppSpacing.md,
            ),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in options)
                  AppChip(
                    label: option,
                    selected: draft.contains(option),
                    onTap: () => setSheetState(() {
                      if (draft.contains(option)) {
                        draft.remove(option);
                      } else {
                        draft.add(option);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      selection
        ..clear()
        ..addAll(result);
      _applyFilters();
    });
    _appearCtrl.forward(from: 0);
  }

  Future<void> _openPriceSheet() async {
    // Distinguishes "dismissed" from "chose Any price": the sheet pops a
    // one-element list for a real choice and null when it is waved away.
    final choice = await showAppSheet<List<_PriceBand?>>(
      context,
      child: AppSheet(
        title: 'Price',
        subtitle: 'Only show pieces in this range',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final band in _priceBands)
              ListTile(
                onTap: () => Navigator.of(context).pop([band]),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.page(context),
                ),
                title: Text(
                  band.label,
                  style: AppType.bodyLarge.copyWith(
                    color: AppPalette.textPrimary,
                    fontWeight: band == _band
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                trailing: band == _band
                    ? const Icon(Icons.check, size: 19, color: AppPalette.accent)
                    : null,
              ),
            if (_band != null)
              ListTile(
                onTap: () => Navigator.of(context).pop(const [null]),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.page(context),
                ),
                title: Text(
                  'Any price',
                  style: AppType.bodyLarge.copyWith(color: AppPalette.accent),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;
    setState(() {
      _band = choice.first;
      _applyFilters();
    });
    _appearCtrl.forward(from: 0);
  }

  Future<void> _openMoreSheet() async {
    final action = await showAppSheet<_MoreAction>(
      context,
      child: AppSheet(
        title: 'More',
        subtitle: 'Everything else that shapes the deck',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: () => Navigator.of(context).pop(_MoreAction.toggleStock),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.page(context),
              ),
              title: Text(
                'Only show in stock',
                style: AppType.bodyLarge.copyWith(
                  color: AppPalette.textPrimary,
                ),
              ),
              trailing: Icon(
                _inStockOnly
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 19,
                color: _inStockOnly
                    ? AppPalette.accent
                    : AppPalette.textTertiary,
              ),
            ),
            ListTile(
              onTap: () => Navigator.of(context).pop(_MoreAction.clearAll),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.page(context),
              ),
              title: Text(
                'Clear all filters',
                style: AppType.bodyLarge.copyWith(color: AppPalette.accent),
              ),
              trailing: const Icon(
                Icons.refresh,
                size: 19,
                color: AppPalette.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;
    switch (action) {
      case _MoreAction.toggleStock:
        setState(() {
          _inStockOnly = !_inStockOnly;
          _applyFilters();
        });
        _appearCtrl.forward(from: 0);
      case _MoreAction.clearAll:
        _clearFilters();
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _openCart() => Navigator.push(context, CartScreen.route());

  void _openProduct(ParentProduct product) => Navigator.push(
    context,
    ProductDetailScreen.route(product, heroTag: 'swipe-${product.id}'),
  );

  /// Mirrors the home screen's handler so the bar behaves identically
  /// wherever it appears. Tapping Home pops back rather than stacking a
  /// second copy of it.
  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).maybePop();
      case 2:
        Navigator.push(context, InstantOutfitBuilderScreen.route());
      case 3:
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
        break;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildFilterRow(),
              const SizedBox(height: AppSpacing.sm),
              _buildRemainingPill(),
              Expanded(child: _buildDeck()),
              _buildConsole(),
              const SizedBox(height: AppSpacing.xs),
              _buildSwipeHint(),
              _buildCartNudge(),
            ],
          ),
        ),
        bottomNavigationBar: RepaintBoundary(
          child: AppBottomNav(
            currentIndex: 1,
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
      ),
    );
  }

  // ── 1. Header ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final inset = AppSpacing.page(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset - AppSpacing.xs,
        AppSpacing.xxs,
        inset - AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            AppIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: AppSpacing.xs),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: AppType.wordmark,
                children: const [
                  TextSpan(text: 'Swipe'),
                  TextSpan(
                    text: 'Style',
                    style: TextStyle(color: AppPalette.accent),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          AppCountBadge(
            count: _bag.length,
            child: AppIconButton(
              icon: Icons.shopping_bag_outlined,
              tooltip: 'Bag',
              onPressed: _openCart,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Filter row ───────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    final brandLabel = switch (_brands.length) {
      0 => 'Brand',
      1 => _brands.first,
      _ => '${_brands.length} Brands',
    };

    final pills = <Widget>[
      _FilterPill(
        label: 'Filters',
        icon: Icons.tune,
        active: _categories.isNotEmpty,
        onTap: _openCategorySheet,
      ),
      _FilterPill(
        label: _sort.shortLabel,
        icon: Icons.swap_vert,
        active: _sort != _SortOption.newest,
        onTap: _openSortSheet,
      ),
      _FilterPill(
        label: brandLabel,
        active: _brands.isNotEmpty,
        onTap: _openBrandSheet,
      ),
      _FilterPill(
        label: _band?.label ?? 'Price',
        active: _band != null,
        onTap: _openPriceSheet,
      ),
      _FilterPill(label: 'More', active: _inStockOnly, onTap: _openMoreSheet),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) => pills[i],
      ),
    );
  }

  // ── 3. Status pill ──────────────────────────────────────────────────────
  Widget _buildRemainingPill() {
    final remaining = (_deck.length - _topIndex).clamp(0, _deck.length);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs + 2,
        ),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: AppRadii.chip,
          border: Border.all(color: AppPalette.line),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: AppPalette.accent,
            ),
            const SizedBox(width: AppSpacing.xxs + 2),
            Text(
              '$remaining remaining',
              style: AppType.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. Card stack ───────────────────────────────────────────────────────
  Widget _buildDeck() {
    if (_deck.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
        child: AppStateView.empty(
          icon: Icons.search_off_outlined,
          title: 'Nothing matches',
          message:
              'No pieces fit those filters right now. Loosen them and the '
              'deck fills back up.',
          actionLabel: 'Clear Filters',
          onAction: _clearFilters,
        ),
      );
    }

    if (_current == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
        child: AppStateView.empty(
          icon: Icons.check_circle_outline,
          title: 'That\'s the whole edit',
          message: _bag.isEmpty
              ? 'You\'ve seen every piece in this selection.'
              : 'You\'ve seen everything, and kept ${_bag.length} '
                    '${_bag.length == 1 ? 'piece' : 'pieces'}.',
          actionLabel: 'Start Over',
          onAction: () {
            setState(() {
              _topIndex = 0;
              _history.clear();
              _resetDrag();
            });
            _appearCtrl.forward(from: 0);
          },
        ),
      );
    }

    final cards = <Widget>[];
    // Back to front, so the top card is painted last.
    for (var depth = 2; depth >= 1; depth--) {
      final index = _topIndex + depth;
      if (index >= _deck.length) continue;
      cards.add(_buildStackedCard(_deck[index], depth));
    }
    cards.add(_buildTopCard(_deck[_topIndex]));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page(context),
        AppSpacing.md,
        AppSpacing.page(context),
        AppSpacing.md,
      ),
      child: Stack(children: cards),
    );
  }

  /// A peeking card behind the top one. Inert — it never handles a gesture.
  Widget _buildStackedCard(ParentProduct product, int depth) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(0, -10.0 * depth),
          child: Transform.scale(
            scale: 1 - 0.045 * depth,
            child: Opacity(
              opacity: depth == 1 ? 0.9 : 0.65,
              child: _SwipeCard(product: product, isWishlisted: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard(ParentProduct product) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_swipeCtrl, _appearCtrl]),
        builder: (context, child) {
          final offset = _swipeCtrl.isAnimating
              ? _swipeAnim.value
              : (_isDragging ? _drag : Offset.zero);
          final rotation = _swipeCtrl.isAnimating
              ? switch (_swipeDir) {
                  _SwipeDir.like => 0.12,
                  _SwipeDir.pass => -0.12,
                  _ => 0.0,
                }
              : _rotation;

          return Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: rotation,
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: _appearCtrl.value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          );
        },
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTap: () => _openProduct(product),
          onDoubleTap: () {
            WishlistService.instance.toggle(product);
            HapticFeedback.selectionClick();
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: WishlistService.instance,
                  builder: (context, _) => _SwipeCard(
                    product: product,
                    isWishlisted: WishlistService.instance.containsId(
                      product.id,
                    ),
                    onWishlist: () {
                      WishlistService.instance.toggle(product);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
              ),
              // Directional stamps, revealed as the card is dragged.
              Positioned(
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                child: _SwipeStamp(
                  label: 'Keep',
                  color: AppPalette.success,
                  opacity: _likeHint,
                ),
              ),
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _SwipeStamp(
                  label: 'Pass',
                  color: AppPalette.textSecondary,
                  opacity: _passHint,
                ),
              ),
              Positioned(
                top: AppSpacing.lg,
                left: 0,
                right: 0,
                child: Center(
                  child: _SwipeStamp(
                    label: 'Vibe Check',
                    color: AppPalette.warning,
                    opacity: _vibeHint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5. Console ──────────────────────────────────────────────────────────
  Widget _buildConsole() {
    final live = _current != null;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: AppRadii.chip,
          border: Border.all(color: AppPalette.line),
          boxShadow: AppShadows.raised,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConsoleButton(
              icon: Icons.close_rounded,
              tooltip: 'Pass',
              diameter: 54,
              onTap: live ? () => _triggerSwipe(_SwipeDir.pass) : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            _ConsoleButton(
              icon: Icons.replay_rounded,
              tooltip: 'Undo',
              diameter: 46,
              onTap: _canUndo ? _undo : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            _ConsoleButton(
              icon: Icons.check_rounded,
              tooltip: 'Add to bag',
              diameter: 54,
              emphasised: true,
              onTap: live ? () => _triggerSwipe(_SwipeDir.like) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. Hint + cart nudge ────────────────────────────────────────────────
  Widget _buildSwipeHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.swipe_outlined,
          size: 13,
          color: AppPalette.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xxs + 2),
        Flexible(
          child: Text(
            'Swipe to discover more styles',
            style: AppType.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCartNudge() {
    if (_bag.isEmpty) return const SizedBox(height: AppSpacing.md);

    final thumbs = _bag.reversed.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Center(
        child: GestureDetector(
          onTap: _openCart,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: AppRadii.chip,
              border: Border.all(color: AppPalette.line),
              boxShadow: AppShadows.raised,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThumbStack(products: thumbs),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('View Cart', style: AppType.titleSmall),
                    Text(
                      '${_bag.length} ${_bag.length == 1 ? 'item' : 'items'}',
                      style: AppType.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppPalette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

/// One pill in the filter row. Fills with the soft accent when its filter is
/// carrying a value, so an active filter is visible without opening it.
class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppPalette.accentDeep : AppPalette.textPrimary;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: active ? AppPalette.accentSoft : AppPalette.surface,
            borderRadius: AppRadii.chip,
            border: Border.all(
              color: active ? AppPalette.accent : AppPalette.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: AppSpacing.xxs + 2),
              ],
              Text(
                label,
                style: AppType.label.copyWith(
                  fontSize: 12,
                  color: foreground,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 15, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// The swipe card: photograph above, the commercial facts below.
class _SwipeCard extends StatelessWidget {
  final ParentProduct product;
  final bool isWishlisted;
  final VoidCallback? onWishlist;

  const _SwipeCard({
    required this.product,
    required this.isWishlisted,
    this.onWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final discount = product.discountPercent;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppPalette.line),
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(url: product.defaultImageUrl, cacheWidth: 800),
                if (product.isNew)
                  const Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: AppBadge('New', tone: AppBadgeTone.accent),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.brand.toUpperCase(),
                        style: AppType.eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    GestureDetector(
                      onTap: onWishlist,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isWishlisted
                            ? AppPalette.accent
                            : AppPalette.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  product.name,
                  style: AppType.displaySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(product.price, style: AppType.priceLarge),
                    if (product.originalPriceFormatted != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          product.originalPriceFormatted!,
                          style: AppType.priceStrike,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (discount != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '$discount% OFF',
                        style: AppType.label.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.success,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceMuted,
                    borderRadius: AppRadii.badge,
                  ),
                  child: Text(
                    product.category.toUpperCase(),
                    style: AppType.badge.copyWith(
                      color: AppPalette.textSecondary,
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

/// The directional stamp revealed while dragging — "Keep" / "Pass" / "Vibe
/// Check". Outlined rather than filled so it reads as editorial, not arcade.
class _SwipeStamp extends StatelessWidget {
  final String label;
  final Color color;
  final double opacity;

  const _SwipeStamp({
    required this.label,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs + 2,
        ),
        decoration: BoxDecoration(
          color: AppPalette.surfaceA92,
          borderRadius: AppRadii.chip,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppType.overline.copyWith(color: color),
        ),
      ),
    );
  }
}

/// A circular action in the console. Passing a null [onTap] renders the
/// disabled state, which is how Undo reads before the first swipe.
class _ConsoleButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final double diameter;
  final bool emphasised;
  final VoidCallback? onTap;

  const _ConsoleButton({
    required this.icon,
    required this.tooltip,
    required this.diameter,
    this.emphasised = false,
    this.onTap,
  });

  @override
  State<_ConsoleButton> createState() => _ConsoleButtonState();
}

class _ConsoleButtonState extends State<_ConsoleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final background = !enabled
        ? AppPalette.surfaceSunken
        : widget.emphasised
        ? AppPalette.accentSoft
        : AppPalette.surfaceMuted;
    final foreground = !enabled
        ? AppPalette.textTertiary
        : widget.emphasised
        ? AppPalette.accentDeep
        : AppPalette.textPrimary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onTap!();
                }
              : null,
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1.0,
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            child: Container(
              width: widget.diameter,
              height: widget.diameter,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: widget.diameter * 0.42,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlapping thumbnails of the last few kept pieces.
class _ThumbStack extends StatelessWidget {
  final List<ParentProduct> products;

  const _ThumbStack({required this.products});

  static const double _size = 32;
  static const double _overlap = 11;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final width = _size + (products.length - 1) * (_size - _overlap);

    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        children: [
          for (var i = products.length - 1; i >= 0; i--)
            Positioned(
              left: i * (_size - _overlap),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppPalette.surface, width: 2),
                ),
                child: ClipOval(
                  child: AppImage(
                    url: products[i].defaultImageUrl,
                    cacheWidth: 80,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
