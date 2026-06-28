import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/catalog_service.dart';
import 'swipe_style_screen.dart';
import 'instant_outfit_builder_screen.dart';
import 'trial_at_doorstep_screen.dart';
import 'vibe_check_screen.dart';
import 'thrift_marketplace_screen.dart';
import 'style_profile_screen.dart';

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
}

class _T {
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.stockGrn.withOpacity(0.5 + 0.5 * _ctrl.value),
          ),
        ),
        const SizedBox(width: 5),
        Text('Only ${widget.stock} left', style: _T.mono(9, color: _C.stockGrn)),
      ]),
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.timer_outlined, size: 10, color: _C.sale),
      const SizedBox(width: 4),
      Text(_f, style: _T.mono(9, color: _C.sale)),
    ]);
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.local_shipping_outlined, size: 10, color: _C.amber),
      const SizedBox(width: 4),
      Expanded(
        child: Text('Order in ${m}m → ${widget.cutoff}',
            style: _T.mono(9, color: _C.amber), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ]);
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
  final Set<String> _wishlist = {};

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late Timer _bannerTimer;

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
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _banner = (_banner + 1) % _banners.length);
    });
  }

  @override
  void dispose() {
    _bannerTimer.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data helpers ──────────────────────────────────────────────────────────
  ProductGender? get _genderArg {
    switch (_filter) {
      case _CatalogFilter.men:    return ProductGender.men;
      case _CatalogFilter.women:  return ProductGender.women;
      case _CatalogFilter.unisex: return ProductGender.unisex;
      default:                    return null;
    }
  }

  List<ParentProduct> get _justDropped {
    if (_filter == _CatalogFilter.latestDrops) return CatalogService.getJustDropped();
    return CatalogService.getJustDropped(gender: _genderArg);
  }

  List<ParentProduct> get _almostGone =>
      CatalogService.getAlmostGone(gender: _genderArg);

  List<ParentProduct> get _trending =>
      CatalogService.getTrending(gender: _genderArg);

  List<ParentProduct> get _vibeCheck =>
      CatalogService.getVibeCheck(gender: _genderArg);

  List<ParentProduct> get _reorders => CatalogService.getReorders();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildTopSection(),
            _buildFilterChips(),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHero()),
                  if (_justDropped.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _RailHeader(label: 'JUST DROPPED', accentColor: _C.magenta)),
                    SliverToBoxAdapter(
                      child: _JustDroppedRail(
                        products: _justDropped,
                        wishlist: _wishlist,
                        onWish: (id) => setState(() =>
                            _wishlist.contains(id) ? _wishlist.remove(id) : _wishlist.add(id)),
                      ),
                    ),
                  ],
                  if (_almostGone.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _RailHeader(label: 'ALMOST GONE', accentColor: _C.sale)),
                    SliverToBoxAdapter(
                      child: _AlmostGoneRail(
                        products: _almostGone,
                        wishlist: _wishlist,
                        onWish: (id) => setState(() =>
                            _wishlist.contains(id) ? _wishlist.remove(id) : _wishlist.add(id)),
                      ),
                    ),
                  ],
                  if (_trending.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _RailHeader(label: 'TRENDING IN HYDERABAD', accentColor: _C.amber)),
                    SliverToBoxAdapter(
                      child: _TrendingRail(
                        products: _trending,
                        wishlist: _wishlist,
                        onWish: (id) => setState(() =>
                            _wishlist.contains(id) ? _wishlist.remove(id) : _wishlist.add(id)),
                      ),
                    ),
                  ],
                  if (_vibeCheck.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _RailHeader(label: 'VIBE CHECK', accentColor: const Color(0xFF7C3AED))),
                    SliverToBoxAdapter(
                      child: _VibeCheckRail(
                        products: _vibeCheck,
                        wishlist: _wishlist,
                        onWish: (id) => setState(() =>
                            _wishlist.contains(id) ? _wishlist.remove(id) : _wishlist.add(id)),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(child: _buildQuickReorder()),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────
  Widget _buildTopSection() {
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
                  errorBuilder: (_, __, ___) => Container(width: 30, height: 30, color: _C.magenta),
                ),
              ),
              const SizedBox(width: 8),
              Text('INSTASTYLE', style: _T.display(22, spacing: 2)),
              const Spacer(),
              _topIcon(Icons.notifications_none_outlined, badge: 2),
              const SizedBox(width: 18),
              _topIcon(Icons.favorite_border),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StyleProfileScreen())),
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
                Icon(Icons.search, color: _C.grey500, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Search outfits, sarees, sneakers...',
                      style: _T.body(13, color: _C.grey500)),
                ),
                Icon(Icons.mic_none_outlined, color: _C.grey700, size: 19),
                const SizedBox(width: 12),
                Icon(Icons.camera_alt_outlined, color: _C.grey700, size: 19),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topIcon(IconData icon, {int? badge}) {
    return Stack(clipBehavior: Clip.none, children: [
      Icon(icon, size: 22, color: _C.dark),
      if (badge != null)
        Positioned(
          top: -4, right: -5,
          child: Container(
            width: 15, height: 15,
            decoration: const BoxDecoration(color: _C.magenta, shape: BoxShape.circle),
            child: Center(child: Text('$badge', style: _T.label(8, color: _C.white, spacing: 0))),
          ),
        ),
    ]);
  }

  // ── GENDER / CATEGORY FILTER CHIPS ────────────────────────────────────────
  Widget _buildFilterChips() {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _CatalogFilter.values.map((f) {
            final selected = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
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
                        style: _T.label(12,
                            color: selected ? _C.white : _C.grey700,
                            fw: selected ? FontWeight.w700 : FontWeight.w500,
                            spacing: 0.3),
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
            Image.network(
              b.imageUrl, fit: BoxFit.cover,
              loadingBuilder: (_, child, p) => p == null ? child : Container(color: _C.grey150),
              errorBuilder: (_, __, ___) => Container(
                  color: _C.grey150,
                  child: Center(child: Icon(Icons.image_outlined, color: _C.grey300, size: 48))),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
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
                  Text(b.sub, style: _T.body(13, color: const Color(0xCCFFFFFF))),
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
                      color: active ? _C.magenta : _C.white.withOpacity(0.45),
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
    final reorders = _reorders;
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
                            child: Image.network(p.defaultImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: _C.grey700)),
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

  // ── BOTTOM NAV ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      (Icons.home_outlined, Icons.home),
      (Icons.style_outlined, Icons.style),
      (Icons.grid_view_outlined, Icons.grid_view),
      (Icons.favorite_border, Icons.favorite),
      (Icons.shopping_bag_outlined, Icons.shopping_bag),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        border: Border(top: BorderSide(color: _C.grey150, width: 0.8)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((e) {
          final active = e.key == _tab;
          return GestureDetector(
            onTap: () {
              if (e.key == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SwipeStyleScreen()));
              } else if (e.key == 2) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const InstantOutfitBuilderScreen()));
              } else if (e.key == 3) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ThriftMarketplaceScreen()));
              } else if (e.key == 4) {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TrialAtDoorstepScreen(orderId: 'ORDER123', riderId: 'RIDER456')));
              } else {
                setState(() => _tab = e.key);
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
                          child: Center(child: Text('2', style: _T.label(8, color: _C.white, spacing: 0))),
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
const double _kImgH  = 155.0;
const double _kInfoH = 72.0;
const double _kCardH = _kImgH + _kInfoH;
const double _kCardW = 148.0;

class _ProductCard extends StatelessWidget {
  final ParentProduct product;
  final bool wished;
  final VoidCallback onWish;
  final VoidCallback onTap;
  final Widget? badge;
  final Widget? fomoSignal;

  const _ProductCard({
    required this.product, required this.wished,
    required this.onWish, required this.onTap,
    this.badge, this.fomoSignal,
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
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  child: Image.network(p.defaultImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: _C.cardBg)),
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
                      style: _T.label(7, color: _C.white, spacing: 0.5),
                    ),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: onWish,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        wished ? Icons.favorite : Icons.favorite_border,
                        size: 16, color: wished ? _C.magenta : _C.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                      ),
                    ),
                    child: p.salePrice != null
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(p.price, style: _T.label(11, color: _C.white, spacing: 0)),
                            const SizedBox(width: 5),
                            Text(p.originalPriceFormatted!,
                                style: _T.body(10, color: const Color(0xAAFFFFFF))
                                    .copyWith(decoration: TextDecoration.lineThrough)),
                          ])
                        : Text(p.price, style: _T.label(11, color: _C.white, spacing: 0)),
                  ),
                ),
              ]),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: _kInfoH),
              color: _C.surface,
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.name,
                        style: _T.label(11, color: _C.dark, spacing: 0),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(p.category, style: _T.body(10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (fomoSignal != null) ...[
                      const SizedBox(height: 6),
                      Flexible(child: SizedBox(width: double.infinity, child: fomoSignal!)),
                    ],
                  ],
                ),
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
  _ShimmerBarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: const [Colors.transparent, Color(0xFFE91E8C), Colors.white, Color(0xFFE91E8C), Colors.transparent],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH((progress - 0.5) * size.width * 2, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerBarPainter old) => old.progress != progress;
}

// ─── RAIL 1: JUST DROPPED ─────────────────────────────────────────────────────
class _JustDroppedRail extends StatefulWidget {
  final List<ParentProduct> products;
  final Set<String> wishlist;
  final void Function(String) onWish;
  const _JustDroppedRail({required this.products, required this.wishlist, required this.onWish});
  @override
  State<_JustDroppedRail> createState() => _JustDroppedRailState();
}

class _JustDroppedRailState extends State<_JustDroppedRail> with SingleTickerProviderStateMixin {
  late final AnimationController _shimCtrl;
  @override void initState() {
    super.initState();
    _shimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }
  @override void dispose() { _shimCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kCardH + 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = widget.products[i];
          final wished = widget.wishlist.contains(p.id);

          Widget fomoSignal;
          if (p.droppedMinsAgo > 0) {
            final label = p.droppedMinsAgo < 60
                ? 'Dropped ${p.droppedMinsAgo}m ago'
                : 'Dropped ${p.droppedMinsAgo ~/ 60}h ago';
            fomoSignal = Row(mainAxisSize: MainAxisSize.max, children: [
              const Icon(Icons.bolt, size: 10, color: _C.magenta),
              const SizedBox(width: 3),
              Text(label, style: _T.body(9, color: _C.magenta)),
            ]);
          } else if (p.saleEndsAt != null) {
            fomoSignal = _SaleTimer(endsAt: p.saleEndsAt!);
          } else {
            fomoSignal = const SizedBox.shrink();
          }

          final badge = Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _shimCtrl,
                builder: (_, __) {
                  final pulse = (sin(_shimCtrl.value * 2 * pi) + 1) / 2;
                  return Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.magenta.withOpacity(0.2 * pulse),
                    ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: _C.magenta,
                child: Text('NEW', style: _T.label(8, color: _C.white, spacing: 0.8)),
              ),
            ],
          );

          return Stack(children: [
            _ProductCard(
              product: p, wished: wished,
              onWish: () => widget.onWish(p.id), onTap: () {},
              badge: badge, fomoSignal: fomoSignal,
            ),
            Positioned(
              top: 0, left: 0, right: 0, height: 3,
              child: AnimatedBuilder(
                animation: _shimCtrl,
                builder: (_, __) => CustomPaint(painter: _ShimmerBarPainter(_shimCtrl.value)),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ─── RAIL 2: ALMOST GONE ─────────────────────────────────────────────────────
class _AlmostGoneRail extends StatelessWidget {
  final List<ParentProduct> products;
  final Set<String> wishlist;
  final void Function(String) onWish;
  const _AlmostGoneRail({required this.products, required this.wishlist, required this.onWish});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kCardH + 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = products[i];
          final wished = wishlist.contains(p.id);

          Widget fomoSignal;
          if (p.deliveryCutoff != null && p.deliveryMinsLeft > 0 && p.deliveryMinsLeft <= 10) {
            fomoSignal = _DeliveryTag(cutoff: p.deliveryCutoff!, minsLeft: p.deliveryMinsLeft);
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
                  child: Text('SALE', style: _T.label(8, color: _C.white, spacing: 0.8)),
                )
              : null;

          return _ProductCard(
            product: p, wished: wished,
            onWish: () => onWish(p.id), onTap: () {},
            badge: badge, fomoSignal: fomoSignal,
          );
        },
      ),
    );
  }
}

// ─── RAIL 3: TRENDING ────────────────────────────────────────────────────────
class _TrendingRail extends StatelessWidget {
  final List<ParentProduct> products;
  final Set<String> wishlist;
  final void Function(String) onWish;
  const _TrendingRail({required this.products, required this.wishlist, required this.onWish});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kCardH + 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = products[i];
          final wished = wishlist.contains(p.id);

          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            color: _C.dark.withOpacity(0.7),
            child: Text('#${p.cityRank}', style: _T.label(10, color: _C.white, spacing: 0)),
          );

          final fomoSignal = p.orderedToday > 0
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.trending_up, size: 10, color: _C.amber),
                  const SizedBox(width: 4),
                  Text('${p.orderedToday} ordered today', style: _T.body(9, color: _C.amber)),
                ])
              : const SizedBox.shrink();

          return _ProductCard(
            product: p, wished: wished,
            onWish: () => onWish(p.id), onTap: () {},
            badge: badge, fomoSignal: fomoSignal,
          );
        },
      ),
    );
  }
}

// ─── RAIL 4: VIBE CHECK ───────────────────────────────────────────────────────
class _VibeCheckRail extends StatelessWidget {
  final List<ParentProduct> products;
  final Set<String> wishlist;
  final void Function(String) onWish;
  const _VibeCheckRail({required this.products, required this.wishlist, required this.onWish});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kCardH + 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = products[i];
          final wished = wishlist.contains(p.id);
          final isUrgent = p.stock <= 1;

          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.thumb_up, size: 9, color: _C.white),
              const SizedBox(width: 3),
              Text('${p.friendVotes}', style: _T.label(9, color: _C.white, spacing: 0)),
            ]),
          );

          final avatarCount = min(3, (p.friendVotes / 8).ceil());
          final fomoSignal = Row(mainAxisSize: MainAxisSize.min, children: [
            ...List.generate(avatarCount, (d) =>
                Transform.translate(
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
                        style: _T.label(6, color: _C.white, spacing: 0),
                      ),
                    ),
                  ),
                )),
            SizedBox(width: (avatarCount * 4.0) + 4),
            Text('${p.friendVotes} voted YES', style: _T.body(9, color: _C.grey700)),
          ]);

          return SizedBox(
            width: _kCardW,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ProductCard(
                product: p, wished: wished,
                onWish: () => onWish(p.id),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const VibeCheckScreen())),
                badge: badge, fomoSignal: fomoSignal,
              ),
              if (isUrgent) _UrgentStripWidget(votes: p.friendVotes),
            ]),
          );
        },
      ),
    );
  }
}

class _UrgentStripWidget extends StatefulWidget {
  final int votes;
  const _UrgentStripWidget({required this.votes});
  @override
  State<_UrgentStripWidget> createState() => _UrgentStripWidgetState();
}
class _UrgentStripWidgetState extends State<_UrgentStripWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _C.sale.withOpacity(0.85 + 0.15 * _ctrl.value),
        child: Text(
          '${widget.votes} friends love it · 1 left',
          style: _T.label(8, color: _C.white, spacing: 0.2),
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
