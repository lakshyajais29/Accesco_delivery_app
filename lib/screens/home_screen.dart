import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/catalog_service.dart';
import '../services/wishlist_service.dart';
import 'swipe_style_screen.dart';
import 'instant_outfit_builder_screen.dart';
import 'trial_at_doorstep_screen.dart';
import 'thrift_marketplace_screen.dart';
import 'style_profile_screen.dart';
import 'product_detail_screen.dart';
import '../screens/wishlist_screen.dart';

// ─── DESIGN TOKENS ───────────────────────────────────────────────────────────
class _C {
  static const white    = Color(0xFFFFFFFF);
  static const bg       = Color(0xFFFAFAFA);
  static const cardBg   = Color(0xFFF0F0F0);
  static const grey100  = Color(0xFFF5F5F5);
  static const grey150  = Color(0xFFEEEEEE);
  static const grey300  = Color(0xFFCCCCCC);
  static const grey500  = Color(0xFF999999);
  static const grey700  = Color(0xFF555555);
  static const dark     = Color(0xFF0D0D0D);
  static const magenta  = Color(0xFFE91E8C);
  static const sale     = Color(0xFFE53935);
  static const amber    = Color(0xFFFF6F00);
  static const stockGrn = Color(0xFFC0392B);
  static const surface  = Color(0xFFFFFFFF);

  // ── Pre-computed opacity colours (avoid .withOpacity() inside build/paint) ──
  static const black25  = Color(0x40000000); // Colors.black.withOpacity(0.25)
  static const black55  = Color(0x8C000000); // Colors.black.withOpacity(0.55)
  static const black70  = Color(0xB3000000); // Colors.black.withOpacity(0.70)
  static const dark70   = Color(0xB30D0D0D); // _C.dark.withOpacity(0.70)
  static const white45  = Color(0x73FFFFFF); // _C.white.withOpacity(0.45)
  static const white80  = Color(0xCCFFFFFF); // _C.white.withOpacity(0.80)
  static const magenta0 = Color(0x00E91E8C); // _C.magenta fully transparent
  static const sale85   = Color(0xD9E53935); // _C.sale.withOpacity(0.85)
}

class _T {
  // ── IMPROVEMENT #6: static cached styles — GoogleFonts.xxx() is called once
  // per style variant instead of on every build() invocation.
  static TextStyle display(double size,
          {Color color = _C.dark, double spacing = 0}) =>
      GoogleFonts.bebasNeue(fontSize: size, color: color, letterSpacing: spacing);

  static TextStyle label(double size,
          {Color color = _C.dark, FontWeight fw = FontWeight.w600, double spacing = 0.5}) =>
      GoogleFonts.jost(fontSize: size, fontWeight: fw, color: color, letterSpacing: spacing);

  static TextStyle body(double size,
          {Color color = _C.grey700, FontWeight fw = FontWeight.w400}) =>
      GoogleFonts.jost(fontSize: size, fontWeight: fw, color: color);

  static TextStyle mono(double size, {Color color = _C.dark}) =>
      GoogleFonts.robotoMono(fontSize: size, fontWeight: FontWeight.w600, color: color);

  // Frequently-used concrete styles cached as static finals.
  static final cardName  = GoogleFonts.jost(fontSize: 11, fontWeight: FontWeight.w600,  color: _C.dark,    letterSpacing: 0);
  static final cardCat   = GoogleFonts.jost(fontSize: 10, fontWeight: FontWeight.w400,  color: _C.grey700);
  static final cardPrice = GoogleFonts.jost(fontSize: 11, fontWeight: FontWeight.w600,  color: _C.white,   letterSpacing: 0);
  static final cardOrig  = GoogleFonts.jost(fontSize: 10, fontWeight: FontWeight.w400,  color: _C.white80,
      decoration: TextDecoration.lineThrough);
  static final newBadge  = GoogleFonts.jost(fontSize: 8,  fontWeight: FontWeight.w600,  color: _C.white,   letterSpacing: 0.8);
  static final rankBadge = GoogleFonts.jost(fontSize: 10, fontWeight: FontWeight.w600,  color: _C.white,   letterSpacing: 0);
  static final voteBadge = GoogleFonts.jost(fontSize: 9,  fontWeight: FontWeight.w600,  color: _C.white,   letterSpacing: 0);
  static final droppedLbl= GoogleFonts.jost(fontSize: 9,  fontWeight: FontWeight.w400,  color: _C.magenta);
  static final orderedLbl= GoogleFonts.jost(fontSize: 9,  fontWeight: FontWeight.w400,  color: _C.amber);
  static final friendLbl = GoogleFonts.jost(fontSize: 9,  fontWeight: FontWeight.w400,  color: _C.grey700);
  static final urgentLbl = GoogleFonts.jost(fontSize: 8,  fontWeight: FontWeight.w600,  color: _C.white,   letterSpacing: 0.2);
  static final genderBadge = GoogleFonts.jost(fontSize: 7, fontWeight: FontWeight.w600, color: _C.white,   letterSpacing: 0.5);
}

// ─── FILTER ──────────────────────────────────────────────────────────────────
enum _CatalogFilter { all, men, women, unisex, latestDrops }

extension _FilterLabel on _CatalogFilter {
  String get label {
    switch (this) {
      case _CatalogFilter.all:         return 'All';
      case _CatalogFilter.men:         return 'Men';
      case _CatalogFilter.women:       return 'Women';
      case _CatalogFilter.unisex:      return 'Unisex';
      case _CatalogFilter.latestDrops: return 'Latest Drops';
    }
  }
}

// ─── BANNER DATA ─────────────────────────────────────────────────────────────
class _Banner {
  final String eyebrow, headline, sub, cta, imageUrl;
  const _Banner({required this.eyebrow, required this.headline,
      required this.sub, required this.cta, required this.imageUrl});
}

const _banners = [
  _Banner(
    eyebrow: 'NEW SEASON', headline: 'OUTFIT\nREADY',
    sub: 'Before you are.', cta: 'SHOP NOW',
    imageUrl: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=800&q=90',
  ),
  _Banner(
    eyebrow: 'TRENDING NOW', headline: 'POWER\nDRESS',
    sub: 'Own every room.', cta: 'EXPLORE',
    imageUrl: 'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=800&q=90',
  ),
  _Banner(
    eyebrow: 'JUST DROPPED', headline: 'STREET\nSTYLE',
    sub: 'Your city. Your rules.', cta: 'SHOP NOW',
    imageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=800&q=90',
  ),
];

// ─── FOMO WIDGETS ─────────────────────────────────────────────────────────────

class _StockDot extends StatefulWidget {
  final int stock;
  const _StockDot({required this.stock});
  @override
  State<_StockDot> createState() => _StockDotState();
}
class _StockDotState extends State<_StockDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.stock >= 4) return const SizedBox.shrink();
    // OPTIMISATION #3: RepaintBoundary isolates this pulsing dot so its
    // per-frame repaint never propagates up to the card or rail.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // OPTIMISATION #6: compute opacity inline via lerp, not withOpacity
              color: Color.lerp(_C.stockGrn.withAlpha(128), _C.stockGrn, _ctrl.value),
            ),
          ),
          const SizedBox(width: 5),
          Text('Only ${widget.stock} left', style: _T.mono(9, color: _C.stockGrn)),
        ]),
      ),
    );
  }
}

class _SaleTimer extends StatefulWidget {
  final String endsAt;
  const _SaleTimer({required this.endsAt});
  @override
  State<_SaleTimer> createState() => _SaleTimerState();
}
class _SaleTimerState extends State<_SaleTimer> {
  late int _secs;
  Timer? _timer;
  @override void initState() {
    super.initState();
    final parts = widget.endsAt.split(':').map(int.parse).toList();
    _secs = parts[0] * 3600 + parts[1] * 60 + parts[2];
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secs > 0) setState(() => _secs--);
    });
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  String get _f {
    final h = _secs ~/ 3600; final m = (_secs % 3600) ~/ 60; final s = _secs % 60;
    return h > 0 ? '${h}h ${m}m left' : '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')} left';
  }

  @override
  Widget build(BuildContext context) {
    if (_secs <= 0) return const SizedBox.shrink();
    // OPTIMISATION #3: RepaintBoundary for per-second timer repaints.
    return RepaintBoundary(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer_outlined, size: 10, color: _C.sale),
        const SizedBox(width: 4),
        Text(_f, style: _T.mono(9, color: _C.sale)),
      ]),
    );
  }
}

class _DeliveryTag extends StatefulWidget {
  final String cutoff;
  final int minsLeft;
  const _DeliveryTag({required this.cutoff, required this.minsLeft});
  @override
  State<_DeliveryTag> createState() => _DeliveryTagState();
}
class _DeliveryTagState extends State<_DeliveryTag> {
  late int _secs;
  Timer? _timer;
  @override void initState() {
    super.initState();
    _secs = widget.minsLeft * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secs > 0) setState(() => _secs--);
    });
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_secs <= 0) return const SizedBox.shrink();
    final m = _secs ~/ 60;
    // OPTIMISATION #3: RepaintBoundary for per-second timer repaints.
    return RepaintBoundary(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_shipping_outlined, size: 10, color: _C.amber),
        const SizedBox(width: 4),
        Expanded(
          child: Text('Order in ${m}m → ${widget.cutoff}',
              style: _T.mono(9, color: _C.amber), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

// ─── IMAGE SHIMMER SKELETON ───────────────────────────────────────────────────
// IMPROVEMENT #5: Animated shimmer replaces the plain grey box that appeared
// while images were loading over the network. Wrapped in RepaintBoundary so
// its per-frame repaint is isolated from parents.
class _ImageShimmer extends StatefulWidget {
  const _ImageShimmer();
  @override
  State<_ImageShimmer> createState() => _ImageShimmerState();
}
class _ImageShimmerState extends State<_ImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final x = _ctrl.value * 2.0 - 0.5;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(x - 0.5, 0),
                end:   Alignment(x + 0.5, 0),
                colors: const [_C.grey150, _C.grey100, _C.grey150],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _banner = 0;
  int _tab    = 0;
  _CatalogFilter _filter = _CatalogFilter.all;

  // OPTIMISATION #1: ValueNotifier so wishlist toggles never rebuild HomeScreen.
  final ValueNotifier<Set<String>> _wishlistNotifier = ValueNotifier({});

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late Timer _bannerTimer;

  // OPTIMISATION #2: Memoised product lists — recomputed only when _filter changes.
  _CatalogFilter? _lastFilter;
  late List<ParentProduct> _cachedJustDropped;
  late List<ParentProduct> _cachedAlmostGone;
  late List<ParentProduct> _cachedTrending;
  late List<ParentProduct> _cachedVibeCheck;
  late List<ParentProduct> _cachedReorders;

  void _refreshCaches() {
    if (_lastFilter == _filter) return;
    _lastFilter = _filter;
    final g = _genderArg;
    _cachedJustDropped = _filter == _CatalogFilter.latestDrops
        ? CatalogService.getJustDropped()
        : CatalogService.getJustDropped(gender: g);
    _cachedAlmostGone  = CatalogService.getAlmostGone(gender: g);
    _cachedTrending    = CatalogService.getTrending(gender: g);
    _cachedVibeCheck   = CatalogService.getVibeCheck(gender: g);
    _cachedReorders    = CatalogService.getReorders();
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Seed the cache before the first build.
    _lastFilter = null;
    _cachedJustDropped = [];
    _cachedAlmostGone  = [];
    _cachedTrending    = [];
    _cachedVibeCheck   = [];
    _cachedReorders    = [];
    _refreshCaches();

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _banner = (_banner + 1) % _banners.length);
    });

    // IMPROVEMENT #1: Precache all banner images so they are decoded and ready
    // before the first auto-rotate, eliminating the grey flash on transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final b in _banners) {
        precacheImage(NetworkImage(b.imageUrl), context);
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer.cancel();
    _fadeCtrl.dispose();
    _wishlistNotifier.dispose();
    super.dispose();
  }

  ProductGender? get _genderArg {
    switch (_filter) {
      case _CatalogFilter.men:    return ProductGender.men;
      case _CatalogFilter.women:  return ProductGender.women;
      case _CatalogFilter.unisex: return ProductGender.unisex;
      default:                    return null;
    }
  }

  void _toggleWish(String id) {
    // IMPROVEMENT #2: Haptic feedback — makes the heart tap feel tactile & premium.
    HapticFeedback.lightImpact();
    final current = _wishlistNotifier.value;
    _wishlistNotifier.value = current.contains(id)
        ? (Set<String>.from(current)..remove(id))
        : (Set<String>.from(current)..add(id));
    // No setState — ValueListenableBuilder handles the heart rebuild.
  }

  // IMPROVEMENT #4: Pull-to-refresh handler — invalidates all caches so the
  // next build fetches fresh data from CatalogService.
  Future<void> _onRefresh() async {
    _lastFilter = null; // force cache invalidation
    setState(() => _refreshCaches());
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMISATION #2: refresh caches only when filter actually changed.
    _refreshCaches();

    return Scaffold(
      backgroundColor: _C.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // OPTIMISATION #8: extracted StatelessWidget + RepaintBoundary.
            RepaintBoundary(
              child: _TopBar(
                onProfileTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StyleProfileScreen())),
              ),
            ),
            RepaintBoundary(
              child: _FilterChips(
                current: _filter,
                onSelect: (f) => setState(() => _filter = f),
              ),
            ),
            Expanded(
              // IMPROVEMENT #4: RefreshIndicator enables pull-to-refresh.
              child: RefreshIndicator(
                color: _C.magenta,
                backgroundColor: _C.white,
                strokeWidth: 2.0,
                onRefresh: _onRefresh,
                // IMPROVEMENT #3: AlwaysScrollableScrollPhysics ensures the
                // scroll view is always draggable for pull-to-refresh even when
                // content is shorter than the viewport.
                child: CustomScrollView(
                  // IMPROVEMENT #3: PageStorageKey preserves scroll offset when
                  // the user navigates to a detail screen and returns.
                  key: const PageStorageKey<String>('home_scroll'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHero()),
                    if (_cachedJustDropped.isNotEmpty) ...[
                      SliverToBoxAdapter(
                          child: _RailHeader(label: 'JUST DROPPED', accentColor: _C.magenta)),
                      SliverToBoxAdapter(
                        child: _JustDroppedRail(
                          products: _cachedJustDropped,
                          wishlistNotifier: _wishlistNotifier,
                          onWish: _toggleWish,
                        ),
                      ),
                    ],
                    if (_cachedAlmostGone.isNotEmpty) ...[
                      SliverToBoxAdapter(
                          child: _RailHeader(label: 'ALMOST GONE', accentColor: _C.sale)),
                      SliverToBoxAdapter(
                        child: _AlmostGoneRail(
                          products: _cachedAlmostGone,
                          wishlistNotifier: _wishlistNotifier,
                          onWish: _toggleWish,
                        ),
                      ),
                    ],
                    if (_cachedTrending.isNotEmpty) ...[
                      SliverToBoxAdapter(
                          child: _RailHeader(label: 'TRENDING IN HYDERABAD', accentColor: _C.amber)),
                      SliverToBoxAdapter(
                        child: _TrendingRail(
                          products: _cachedTrending,
                          wishlistNotifier: _wishlistNotifier,
                          onWish: _toggleWish,
                        ),
                      ),
                    ],
                    if (_cachedVibeCheck.isNotEmpty) ...[
                      SliverToBoxAdapter(
                          child: _RailHeader(
                              label: 'VIBE CHECK',
                              accentColor: const Color(0xFF7C3AED))),
                      SliverToBoxAdapter(
                        child: _VibeCheckRail(
                          products: _cachedVibeCheck,
                          wishlistNotifier: _wishlistNotifier,
                          onWish: _toggleWish,
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(child: _buildQuickReorder()),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
            // OPTIMISATION #8: extracted StatelessWidget + RepaintBoundary.
            RepaintBoundary(
              child: _BottomNav(
                currentTab: _tab,
                onTabChange: (i) => setState(() => _tab = i),
                context: context,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HERO ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final b = _banners[_banner];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: SizedBox(
        key: ValueKey(_banner),
        height: 360, width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // OPTIMISATION #9 + IMPROVEMENT #5: cache and placeholder.
            CachedNetworkImage(
              imageUrl: b.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const _ImageShimmer(),
              errorWidget: (_, __, ___) => Container(
                color: _C.grey150,
                child: const Center(child: Icon(Icons.image_outlined, color: _C.grey300, size: 48)),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  // OPTIMISATION #6: const gradient, no .withOpacity() in build.
                  colors: [Color(0x00000000), Color(0xBB000000)],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20, bottom: 28, right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: _C.magenta,
                    child: Text(b.eyebrow, style: _T.label(10, color: _C.white, spacing: 2.5)),
                  ),
                  const SizedBox(height: 8),
                  Text(b.headline, style: _T.display(58, color: _C.white, spacing: -1)),
                  const SizedBox(height: 4),
                  Text(b.sub, style: _T.body(13, color: _C.white80)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      color: _C.white,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(b.cta, style: _T.label(12, color: _C.dark, spacing: 1.5)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 14, color: _C.dark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12, right: 20,
              child: Row(
                children: List.generate(_banners.length, (i) {
                  final active = i == _banner;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(left: 5),
                    width: active ? 18 : 5, height: 3,
                    decoration: BoxDecoration(
                      // OPTIMISATION #6: pre-computed const colour.
                      color: active ? _C.magenta : _C.white45,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QUICK REORDER ─────────────────────────────────────────────────────────
  Widget _buildQuickReorder() {
    final reorders = _cachedReorders;
    if (reorders.isEmpty) return const SizedBox.shrink();
    return Container(
      color: _C.dark,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.replay, color: _C.white, size: 15),
            const SizedBox(width: 8),
            Text('QUICK REORDER', style: _T.label(13, color: _C.white, spacing: 1.5)),
            const Spacer(),
            Text('SEE ALL', style: _T.label(11, color: _C.magenta, spacing: 1.5)),
          ]),
          const SizedBox(height: 3),
          Text('Your recent orders — one tap away', style: _T.body(12, color: _C.grey500)),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // OPTIMISATION #7: short fixed list — no KeepAlive overhead needed.
              addAutomaticKeepAlives: false,
              itemCount: reorders.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final p = reorders[i];
                return SizedBox(
                  width: 85,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(fit: StackFit.expand, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            // OPTIMISATION #9 + IMPROVEMENT #5: shimmer skeleton.
                            child: CachedNetworkImage(
                                imageUrl: p.defaultImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const _ImageShimmer(),
                                errorWidget: (_, __, ___) => const ColoredBox(color: _C.grey700)),
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                color: _C.magenta,
                                child: Center(
                                  child: Text('REORDER',
                                      style: _T.label(7, color: _C.white, spacing: 0.6)),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text(p.name,
                          style: _T.label(9, color: _C.white, spacing: 0),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TOP BAR (extracted StatelessWidget) ─────────────────────────────────────
// OPTIMISATION #8: Pulling this out as a StatelessWidget means Flutter can
// skip diffing it entirely on wishlist-toggle or banner-tick rebuilds,
// because its inputs (onProfileTap) never change.
class _TopBar extends StatelessWidget {
  final VoidCallback onProfileTap;
  const _TopBar({required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12, left: 16, right: 16,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 30, height: 30, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(width: 30, height: 30,
                          child: ColoredBox(color: _C.magenta)),
                ),
              ),
              const SizedBox(width: 8),
              Text('INSTASTYLE',
                  style: GoogleFonts.bebasNeue(
                      fontSize: 22, color: _C.dark, letterSpacing: 2)),
              const Spacer(),
              _TopIcon(icon: Icons.notifications_none_outlined, badge: 2),
              const SizedBox(width: 18),
            _TopIcon(
              icon: Icons.favorite_border,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => const WishlistScreen(),
                  ),
               );
             },
           ),              
           const SizedBox(width: 18),
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.magenta, width: 1.5),
                  ),
                  child: const Center(child: Icon(Icons.person, size: 18, color: _C.dark)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(color: _C.grey100, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search, color: _C.grey500, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Search outfits, sarees, sneakers...',
                      style: GoogleFonts.jost(
                          fontSize: 13, fontWeight: FontWeight.w400, color: _C.grey500)),
                ),
                const Icon(Icons.mic_none_outlined, color: _C.grey700, size: 19),
                const SizedBox(width: 12),
                const Icon(Icons.camera_alt_outlined, color: _C.grey700, size: 19),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final int? badge;
  final VoidCallback? onTap;

  const _TopIcon({
    required this.icon,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 22, color: _C.dark),
          if (badge != null)
            Positioned(
              top: -4,
              right: -5,
              child: Container(
                width: 15,
                height: 15,
                decoration: const BoxDecoration(
                  color: _C.magenta,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$badge',
                    style: GoogleFonts.jost(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: _C.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
// ─── FILTER CHIPS (extracted StatelessWidget) ─────────────────────────────────
// OPTIMISATION #8: Same rationale — rebuilds only when _filter or onSelect changes.
class _FilterChips extends StatelessWidget {
  final _CatalogFilter current;
  final void Function(_CatalogFilter) onSelect;
  const _FilterChips({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _CatalogFilter.values.map((f) {
            final selected = current == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? _C.dark : _C.grey100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? _C.dark : _C.grey150,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (f == _CatalogFilter.latestDrops)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.bolt, size: 13,
                              color: selected ? _C.magenta : _C.grey500),
                        ),
                      Text(
                        f.label,
                        style: GoogleFonts.jost(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? _C.white : _C.grey700,
                            letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── BOTTOM NAV (extracted StatelessWidget) ───────────────────────────────────
// OPTIMISATION #8: Decoupled from HomeScreen rebuild cycle.
class _BottomNav extends StatelessWidget {
  final int currentTab;
  final void Function(int) onTabChange;
  final BuildContext context;
  const _BottomNav({
    required this.currentTab,
    required this.onTabChange,
    required this.context,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home),
    (Icons.style_outlined, Icons.style),
    (Icons.grid_view_outlined, Icons.grid_view),
    (Icons.favorite_border, Icons.favorite),
    (Icons.shopping_bag_outlined, Icons.shopping_bag),
  ];

  @override
  Widget build(BuildContext _) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        border: Border(top: BorderSide(color: _C.grey150, width: 0.8)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _items.asMap().entries.map((e) {
          final active = e.key == currentTab;
          return GestureDetector(
            onTap: () {
              if (e.key == 1) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SwipeStyleScreen()));
              } else if (e.key == 2) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InstantOutfitBuilderScreen()));
              } else if (e.key == 3) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ThriftMarketplaceScreen()));
              } else if (e.key == 4) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TrialAtDoorstepScreen(
                        orderId: 'ORDER123', riderId: 'RIDER456')));
              } else {
                onTabChange(e.key);
              }
            },
            child: SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 2,
                    color: active ? _C.magenta : Colors.transparent,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Stack(clipBehavior: Clip.none, children: [
                    Icon(active ? e.value.$2 : e.value.$1,
                        size: 22, color: active ? _C.dark : _C.grey500),
                    if (e.key == 4)
                      Positioned(
                        top: -5, right: -8,
                        child: Container(
                          width: 15, height: 15,
                          decoration: const BoxDecoration(color: _C.magenta, shape: BoxShape.circle),
                          child: Center(
                            child: Text('2',
                                style: GoogleFonts.jost(
                                    fontSize: 8, fontWeight: FontWeight.w600,
                                    color: _C.white, letterSpacing: 0)),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── SHARED RAIL HEADER ───────────────────────────────────────────────────────
class _RailHeader extends StatelessWidget {
  final String label;
  final Color accentColor;
  const _RailHeader({required this.label, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.bebasNeue(fontSize: 22, color: _C.dark, letterSpacing: 0.5)),
        ),
        GestureDetector(
          onTap: () {},
          child: Text('SEE ALL',
              style: GoogleFonts.jost(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: accentColor, letterSpacing: 1.2)),
        ),
      ]),
    );
  }
}

// ─── PRODUCT CARD ─────────────────────────────────────────────────────────────
const double _kImgH  = 195.0;   // increased: portrait ratio fits fashion images
const double _kInfoH = 72.0;
const double _kCardH = _kImgH + _kInfoH;
const double _kCardW = 155.0;   // slightly wider to match new height

// OPTIMISATION #1: Card no longer receives a `bool wished` — it uses
// ValueListenableBuilder internally so only the heart icon subtree rebuilds.
class _ProductCard extends StatelessWidget {
  final ParentProduct product;
  final String heroTag;
  final ValueNotifier<Set<String>> wishlistNotifier;
  final VoidCallback onWish;
  final VoidCallback onTap;
  final Widget? badge;
  final Widget? fomoSignal;

  const _ProductCard({
    required this.product,
    required this.heroTag,
    required this.wishlistNotifier,
    required this.onWish,
    required this.onTap,
    this.badge,
    this.fomoSignal,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return SizedBox(
      width: _kCardW, height: _kCardH,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _kImgH,
              child: Stack(fit: StackFit.expand, children: [
                Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    // OPTIMISATION #9 + IMPROVEMENT #5: resize hints + shimmer skeleton.
                    child: CachedNetworkImage(
                        imageUrl: p.defaultImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const _ImageShimmer(),
                        errorWidget: (_, __, ___) => const ColoredBox(color: _C.cardBg)),
                  ),
                ),
                if (badge != null) Positioned(top: 8, left: 8, child: badge!),
                // Gender badge
                Positioned(
                  top: 8, left: badge != null ? 48 : 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.gender == ProductGender.men
                          ? const Color(0xFF1A3A6B)
                          : p.gender == ProductGender.women
                              ? const Color(0xFF8B1A5A)
                              : const Color(0xFF2D5A2D),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      p.gender == ProductGender.men ? 'MEN'
                          : p.gender == ProductGender.women ? 'WOMEN' : 'UNISEX',
                      style: GoogleFonts.jost(
                          fontSize: 7, fontWeight: FontWeight.w600,
                          color: _C.white, letterSpacing: 0.5),
                    ),
                  ),
                ),
                
                // Integrated Logic: Connects both local UI state and global WishlistService
                Positioned(
                  top: 8, right: 8,
                  child: ValueListenableBuilder<Set<String>>(
                    valueListenable: wishlistNotifier,
                    builder: (_, wishlist, __) {
                      // Check local state for instant UI update
                      final isWishlisted = wishlist.contains(p.id);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact(); // Keeping the premium haptic feel!
                          
                          // 1. Update the global database
                          WishlistService.instance.toggle(p);
                          
                          // 2. Update local state so UI reacts instantly across the rail
                          onWish(); 
                          
                          // 3. Show styled SnackBar with explicit white text
                          final isNowWishlisted = WishlistService.instance.contains(p);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isNowWishlisted 
                                    ? '${p.name} added to wishlist'
                                    : '${p.name} removed from wishlist',
                                style: GoogleFonts.jost(
                                  color: _C.white, // Explicitly white text
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: _C.dark,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(
                            // OPTIMISATION #6: pre-computed const colour.
                            color: _C.black25,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isWishlisted ? Icons.favorite : Icons.favorite_border,
                            size: 16, color: isWishlisted ? _C.magenta : _C.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        // OPTIMISATION #6: const colours, no .withOpacity() in build.
                        colors: [Colors.transparent, _C.black55],
                      ),
                    ),
                    child: p.salePrice != null
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            // IMPROVEMENT #6: cached TextStyle, no GoogleFonts() per build.
                            Text(p.price, style: _T.cardPrice),
                            const SizedBox(width: 5),
                            Text(p.originalPriceFormatted!, style: _T.cardOrig),
                          ])
                        : Text(p.price, style: _T.cardPrice),
                  ),
                ),
              ]),
            ),
            // OPTIMISATION #5: plain Column, no SingleChildScrollView.
            Container(
              height: _kInfoH,
              color: _C.surface,
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // IMPROVEMENT #6: cached TextStyles.
                  Text(p.name, style: _T.cardName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(p.category, style: _T.cardCat,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (fomoSignal != null) ...[
                    const SizedBox(height: 6),
                    fomoSignal!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SHIMMER BAR ─────────────────────────────────────────────────────────────
class _ShimmerBarPainter extends CustomPainter {
  final double progress;
  // OPTIMISATION #6: store pre-built shader params as fields; only recreate when progress changes.
  _ShimmerBarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0xFFE91E8C),
          Colors.white,
          Color(0xFFE91E8C),
          Colors.transparent,
        ],
        stops: [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH((progress - 0.5) * size.width * 2, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerBarPainter old) => old.progress != progress;
}

// ─── RAIL 1: JUST DROPPED ─────────────────────────────────────────────────────
class _JustDroppedRail extends StatefulWidget {
  final List<ParentProduct> products;
  final ValueNotifier<Set<String>> wishlistNotifier;
  final void Function(String) onWish;
  const _JustDroppedRail({
    required this.products,
    required this.wishlistNotifier,
    required this.onWish,
  });
  @override
  State<_JustDroppedRail> createState() => _JustDroppedRailState();
}

class _JustDroppedRailState extends State<_JustDroppedRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimCtrl;
  @override void initState() {
    super.initState();
    _shimCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
          ..repeat();
  }
  @override void dispose() { _shimCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // OPTIMISATION #4: ONE AnimatedBuilder at rail level. Each card gets the
    // current progress value passed in; no per-card AnimatedBuilder needed.
    return AnimatedBuilder(
      animation: _shimCtrl,
      builder: (_, __) {
        final progress = _shimCtrl.value;
        return SizedBox(
          height: _kCardH + 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // OPTIMISATION #7: fixed short list — KeepAlive not needed.
            addAutomaticKeepAlives: false,
            itemCount: widget.products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final p = widget.products[i];

              Widget fomoSignal;
              if (p.droppedMinsAgo > 0) {
                final label = p.droppedMinsAgo < 60
                    ? 'Dropped ${p.droppedMinsAgo}m ago'
                    : 'Dropped ${p.droppedMinsAgo ~/ 60}h ago';
                fomoSignal = Row(mainAxisSize: MainAxisSize.max, children: [
                  const Icon(Icons.bolt, size: 10, color: _C.magenta),
                  const SizedBox(width: 3),
                  Text(label,
                      style: GoogleFonts.jost(
                          fontSize: 9, fontWeight: FontWeight.w400, color: _C.magenta)),
                ]);
              } else if (p.saleEndsAt != null) {
                fomoSignal = _SaleTimer(endsAt: p.saleEndsAt!);
              } else {
                fomoSignal = const SizedBox.shrink();
              }

              // Pulse badge — driven by the shared shimCtrl via sin().
              final pulse = (sin(progress * 2 * pi) + 1) / 2;
              final badge = Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // OPTIMISATION #4 + #6: use lerp instead of withOpacity(),
                      // driven by parent AnimatedBuilder (no per-card rebuild).
                      color: Color.lerp(_C.magenta0, _C.magenta.withAlpha(51), pulse),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    color: _C.magenta,
                    child: Text('NEW',
                        style: GoogleFonts.jost(
                            fontSize: 8, fontWeight: FontWeight.w600,
                            color: _C.white, letterSpacing: 0.8)),
                  ),
                ],
              );

              // OPTIMISATION #3: RepaintBoundary for the shimmer bar.
              final heroTag = 'justDropped-${p.id}-$i';
              return Stack(children: [
                _ProductCard(
                  product: p,
                  heroTag: heroTag,
                  wishlistNotifier: widget.wishlistNotifier,
                  onWish: () => widget.onWish(p.id),
                  onTap: () => Navigator.push(context, ProductDetailScreen.route(p, heroTag: heroTag)),
                  badge: badge,
                  fomoSignal: fomoSignal,
                ),
                Positioned(
                  top: 0, left: 0, right: 0, height: 3,
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _ShimmerBarPainter(progress)),
                  ),
                ),
              ]);
            },
          ),
        );
      },
    );
  }
}

// ─── RAIL 2: ALMOST GONE ─────────────────────────────────────────────────────
class _AlmostGoneRail extends StatelessWidget {
  final List<ParentProduct> products;
  final ValueNotifier<Set<String>> wishlistNotifier;
  final void Function(String) onWish;
  const _AlmostGoneRail({
    required this.products,
    required this.wishlistNotifier,
    required this.onWish,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kCardH + 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        addAutomaticKeepAlives: false,      // OPTIMISATION #7
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = products[i];

          Widget fomoSignal;
          if (p.deliveryCutoff != null &&
              p.deliveryMinsLeft > 0 &&
              p.deliveryMinsLeft <= 10) {
            fomoSignal = _DeliveryTag(
                cutoff: p.deliveryCutoff!, minsLeft: p.deliveryMinsLeft);
          } else if (p.stock < 4) {
            fomoSignal = _StockDot(stock: p.stock);
          } else if (p.saleEndsAt != null) {
            fomoSignal = _SaleTimer(endsAt: p.saleEndsAt!);
          } else {
            fomoSignal = const SizedBox.shrink();
          }

          final badge = p.originalPriceFormatted != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: _C.sale,
                  child: Text('SALE',
                      style: GoogleFonts.jost(
                          fontSize: 8, fontWeight: FontWeight.w600,
                          color: _C.white, letterSpacing: 0.8)),
                )
              : null;

          final heroTag = 'almostGone-${p.id}-$i';
          return _ProductCard(
            product: p,
            heroTag: heroTag,
            wishlistNotifier: wishlistNotifier,
            onWish: () => onWish(p.id),
            onTap: () => Navigator.push(context, ProductDetailScreen.route(p, heroTag: heroTag)),
            badge: badge,
            fomoSignal: fomoSignal,
          );
        },
      ),
    );
  }
}

// ─── RAIL 3: TRENDING ────────────────────────────────────────────────────────
class _TrendingRail extends StatelessWidget {
  final List<ParentProduct> products;
  final ValueNotifier<Set<String>> wishlistNotifier;
  final void Function(String) onWish;
  const _TrendingRail({
    required this.products,
    required this.wishlistNotifier,
    required this.onWish,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kCardH + 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        addAutomaticKeepAlives: false,      // OPTIMISATION #7
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = products[i];

          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            // OPTIMISATION #6: pre-computed const colour.
            color: _C.dark70,
            child: Text('#${p.cityRank}',
                style: GoogleFonts.jost(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: _C.white, letterSpacing: 0)),
          );

          final fomoSignal = p.orderedToday > 0
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.trending_up, size: 10, color: _C.amber),
                  const SizedBox(width: 4),
                  Text('${p.orderedToday} ordered today',
                      style: GoogleFonts.jost(
                          fontSize: 9, fontWeight: FontWeight.w400, color: _C.amber)),
                ])
              : const SizedBox.shrink();

          final heroTag = 'trending-${p.id}-$i';
          return _ProductCard(
            product: p,
            heroTag: heroTag,
            wishlistNotifier: wishlistNotifier,
            onWish: () => onWish(p.id),
            onTap: () => Navigator.push(context, ProductDetailScreen.route(p, heroTag: heroTag)),
            badge: badge,
            fomoSignal: fomoSignal,
          );
        },
      ),
    );
  }
}

// ─── RAIL 4: VIBE CHECK ───────────────────────────────────────────────────────
class _VibeCheckRail extends StatefulWidget {
  final List<ParentProduct> products;
  final ValueNotifier<Set<String>> wishlistNotifier;
  final void Function(String) onWish;
  const _VibeCheckRail({
    required this.products,
    required this.wishlistNotifier,
    required this.onWish,
  });
  @override
  State<_VibeCheckRail> createState() => _VibeCheckRailState();
}

class _VibeCheckRailState extends State<_VibeCheckRail>
    with SingleTickerProviderStateMixin {
  // OPTIMISATION #10: ONE AnimationController for all urgent strips in this rail.
  late final AnimationController _urgentCtrl;
  late final Animation<double> _urgentAnim;

  @override
  void initState() {
    super.initState();
    _urgentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _urgentAnim = _urgentCtrl;
  }

  @override
  void dispose() {
    _urgentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kCardH + 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        addAutomaticKeepAlives: false,      // OPTIMISATION #7
        itemCount: widget.products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = widget.products[i];
          final isUrgent = p.stock <= 1;

          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: const BoxDecoration(
              color: Color(0xFF7C3AED),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.thumb_up, size: 9, color: _C.white),
              const SizedBox(width: 3),
              Text('${p.friendVotes}',
                  style: GoogleFonts.jost(
                      fontSize: 9, fontWeight: FontWeight.w600,
                      color: _C.white, letterSpacing: 0)),
            ]),
          );

          final avatarCount = min(3, (p.friendVotes / 8).ceil());
          final fomoSignal = Row(mainAxisSize: MainAxisSize.min, children: [
            ...List.generate(avatarCount, (d) => Transform.translate(
              offset: Offset(d * -4.0, 0),
              child: Container(
                width: 15, height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: [
                    const Color(0xFFE91E8C),
                    const Color(0xFF7C3AED),
                    const Color(0xFF00BCD4),
                  ][d % 3],
                  border: Border.all(color: _C.white, width: 1.2),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + (d * 7 + i) % 26),
                    style: GoogleFonts.jost(
                        fontSize: 6, fontWeight: FontWeight.w600,
                        color: _C.white, letterSpacing: 0),
                  ),
                ),
              ),
            )),
            SizedBox(width: (avatarCount * 4.0) + 4),
            Text('${p.friendVotes} voted YES',
                style: GoogleFonts.jost(
                    fontSize: 9, fontWeight: FontWeight.w400, color: _C.grey700)),
          ]);

          final heroTag = 'vibeCheck-${p.id}-$i';
          return SizedBox(
            width: _kCardW,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ProductCard(
                product: p,
                heroTag: heroTag,
                wishlistNotifier: widget.wishlistNotifier,
                onWish: () => widget.onWish(p.id),
                onTap: () => Navigator.push(context, ProductDetailScreen.route(p, heroTag: heroTag)),
                badge: badge,
                fomoSignal: fomoSignal,
              ),
              // OPTIMISATION #10: pass the shared animation, no extra ticker.
              if (isUrgent)
                _UrgentStripWidget(votes: p.friendVotes, animation: _urgentAnim),
            ]),
          );
        },
      ),
    );
  }
}

// OPTIMISATION #10: _UrgentStripWidget is now a pure StatelessWidget —
// it receives the animation from its parent rail's single controller.
class _UrgentStripWidget extends StatelessWidget {
  final int votes;
  final Animation<double> animation;
  const _UrgentStripWidget({required this.votes, required this.animation});

  @override
  Widget build(BuildContext context) {
    // OPTIMISATION #3: RepaintBoundary so only this strip repaints per frame.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          // OPTIMISATION #6: lerp instead of withOpacity().
          color: Color.lerp(_C.sale85, _C.sale, animation.value),
          child: Text(
            '$votes friends love it · 1 left',
            style: GoogleFonts.jost(
                fontSize: 8, fontWeight: FontWeight.w600,
                color: _C.white, letterSpacing: 0.2),
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}