import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sku_catalog.dart'; // ── SKU ── catalogue + CartPayload
import 'package:instastyle/services/cart_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SKU INTEGRATION (additive — NO UI/UX change)
// Resolves a catalogue parentId to a concrete child-variant CartPayload using
// the first in-stock variant as the silent default selection (no picker shown,
// so the swipe flow is untouched). The card's own displayed price is kept as
// the unit price so nothing visible changes. Falls back to a synthesized
// payload when the parent isn't in SkuCatalog yet (e.g. FSR-MK lehenga).
// ═══════════════════════════════════════════════════════════════════════════
CartPayload _skuPayloadFor({
  required String? parentId,
  required String name,
  required String brand,
  required int unitPriceInPaise, // price shown on THIS card — kept as-is
  required String imageUrl,
  int quantity = 1,
}) {
  String variantSku       = '${parentId ?? 'SKU'}-DEFAULT';
  String size             = 'One Size';
  String colorName        = '—';
  String colorHex         = '#888888';
  String resolvedParentId = parentId ?? name;

  if (parentId != null) {
    final parent = SkuCatalog.get(parentId);
    if (parent != null && parent.variantMap.isNotEmpty) {
      ProductVariant variant = parent.variantMap.values.first;
      for (final v in parent.variantMap.values) {
        if (v.inStock) { variant = v; break; }
      }
      variantSku       = variant.sku;
      size             = variant.size;
      colorName        = variant.colorName;
      colorHex         = variant.colorHex;
      resolvedParentId = parent.id;
    }
  }

  return CartPayload(
    parentId         : resolvedParentId,
    variantSku       : variantSku,
    productName      : name,
    brand            : brand,
    size             : size,
    colorName        : colorName,
    colorHex         : colorHex,
    quantity         : quantity,
    unitPriceInPaise : unitPriceInPaise,
    imageUrl         : imageUrl,
  );
}

// ─── DESIGN TOKENS ────────────────────────────────────────────────────────────
class _C {
  static const white       = Color(0xFFFFFFFF);
  static const bg          = Color(0xFFFFFFFF);
  static const cardBg      = Color(0xFFF2F2F2);
  static const grey100     = Color(0xFFF5F5F5);
  static const grey150     = Color(0xFFEEEEEE);
  static const grey300     = Color(0xFFCCCCCC);
  static const grey500     = Color(0xFF999999);
  static const grey700     = Color(0xFF555555);
  static const dark        = Color(0xFF0D0D0D);
  static const magenta     = Color(0xFFE91E8C);
  static const sale        = Color(0xFFE53935);
  static const amber       = Color(0xFFFF6F00);
  static const ivory       = Color(0xFFF5F0E8);
  static const brown       = Color(0xFF8B6914);
  static const brownDark   = Color(0xFF3A2E00);
  static const greenBudget = Color(0xFF2E7D32);
  static const navBg       = Color(0xFF111111);

  // ── FOMO palette (Ch. 15) ──────────────────────────────────────────────
  static const fomoRed     = Color(0xFFC0392B); // Stock Counter, Price Scarcity
  static const brandTan    = Color(0xFFC4913A); // Recency Signal, Trending Badge
}

class _T {
  static TextStyle display(double size,
          {Color color = _C.dark, double spacing = 0}) =>
      GoogleFonts.bebasNeue(
          fontSize: size, color: color, letterSpacing: spacing);

  static TextStyle label(double size,
          {Color color = _C.dark,
          FontWeight fw = FontWeight.w600,
          double spacing = 0.5}) =>
      GoogleFonts.jost(
          fontSize: size, fontWeight: fw, color: color, letterSpacing: spacing);

  static TextStyle body(double size,
          {Color color = _C.grey700, FontWeight fw = FontWeight.w400}) =>
      GoogleFonts.jost(fontSize: size, fontWeight: fw, color: color);

  static TextStyle brandName(double size, {Color color = _C.ivory}) =>
      GoogleFonts.cormorantGaramond(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5);
}

// ─── MODEL ────────────────────────────────────────────────────────────────────
class _Outfit {
  final String brand, style, price, imageUrl, vibeTag;
  final String? originalPrice;
  final List<String> occasions;
  final bool withinBudget;
  final int xpenseOver;

  // ── SKU ── links this outfit to SkuCatalog (optional). Null → fallback SKU.
  final String? parentId;

  // ── FOMO fields (Ch. 15 FOMO Design System) ───────────────────────────
  // Max 2 active signals per card; priority: stock > social > recency > newDrop > trending
  final int?   stockLeft;       // < 5 → Stock Counter (Roboto Mono, fomoRed, 2s pulse)
  final int?   viewersNow;      // → Social Proof (Montserrat Black, muted, static)
  final int?   ordersToday;     // → Recency Signal (Jost, brandTan, no animation)
  final bool   isNewDrop;       // → New Drop Alert (shimmer sweep + NEW badge glow)
  final int?   droppedMinsAgo;  // copy for new drop
  final String? trendingFor;   // → Trending Badge (crown icon, brandTan, static pill)

  const _Outfit({
    required this.brand,
    required this.style,
    required this.price,
    required this.imageUrl,
    required this.vibeTag,
    this.originalPrice,
    required this.occasions,
    this.withinBudget = true,
    this.xpenseOver = 0,
    this.parentId, // ── SKU ──
    // FOMO
    this.stockLeft,
    this.viewersNow,
    this.ordersToday,
    this.isNewDrop = false,
    this.droppedMinsAgo,
    this.trendingFor,
  });
}

// ─── DATA ─────────────────────────────────────────────────────────────────────
const _outfits = [
  _Outfit(
    brand: 'MAISON KAIRA',
    style: 'Festive Embroidered Lehenga',
    price: '₹18,500',
    imageUrl: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=800&q=90',
    occasions: ['FESTIVE', 'WEDDING'],
    withinBudget: true,
    vibeTag: 'Luxe Ethnic',
    parentId: 'FSR-MK', // ── SKU ── (not yet in catalog → synthesized fallback)
    // FOMO: Trending + Social Proof
    trendingFor: '#1 in Wedding Looks',
    viewersNow: 18,
  ),
  _Outfit(
    brand: 'ATELIER SUR',
    style: 'Power Structured Blazer',
    price: '₹8,400',
    originalPrice: '₹12,000',
    imageUrl: 'https://images.unsplash.com/photo-1551803091-e20673f15770?w=800&q=90',
    occasions: ['WORK', 'FORMAL'],
    withinBudget: true,
    vibeTag: 'Boss Energy',
    parentId: 'PBL-AS', // ── SKU ──
    // FOMO: Stock Counter + Recency
    stockLeft: 3,
    ordersToday: 31,
  ),
  _Outfit(
    brand: 'DECO NOIR',
    style: 'Street Oversized Jacket',
    price: '₹14,200',
    originalPrice: '₹9,999',
    imageUrl: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=800&q=90',
    occasions: ['CASUAL', 'STREET'],
    withinBudget: false,
    xpenseOver: 340,
    vibeTag: 'Dark Street',
    parentId: 'STJ-DN', // ── SKU ──
    // FOMO: New Drop + Social Proof
    isNewDrop: true,
    droppedMinsAgo: 23,
    viewersNow: 7,
  ),
  _Outfit(
    brand: 'INDIRA & CO',
    style: 'Ethnic Silk Kurta Set',
    price: '₹9,750',
    imageUrl: 'https://images.unsplash.com/photo-1566206091558-7f218b696731?w=800&q=90',
    occasions: ['CASUAL', 'FESTIVE'],
    withinBudget: true,
    vibeTag: 'Soft Ethnic',
    parentId: 'VKT-IC', // ── SKU ──
    // FOMO: Recency + Trending
    ordersToday: 47,
    trendingFor: '#1 in Ethnic Today',
  ),
  _Outfit(
    brand: 'CASA MODAS',
    style: 'Printed Coord Two-Piece',
    price: '₹7,500',
    imageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=800&q=90',
    occasions: ['BRUNCH', 'CASUAL'],
    withinBudget: true,
    vibeTag: 'Chill Glam',
    parentId: 'COS-CM', // ── SKU ──
    // FOMO: Stock Counter + Social Proof
    stockLeft: 2,
    viewersNow: 12,
  ),
  _Outfit(
    brand: 'RAW & REFINED',
    style: 'Distressed Denim Jacket',
    price: '₹5,999',
    imageUrl: 'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=800&q=90',
    occasions: ['STREET', 'CASUAL'],
    withinBudget: false,
    xpenseOver: 200,
    vibeTag: 'Raw Edge',
    parentId: 'DJK-RR', // ── SKU ──
    // FOMO: New Drop only
    isNewDrop: true,
    droppedMinsAgo: 54,
  ),
];

enum _SwipeDir { left, right, up }

// ─── SWIPE STYLE SCREEN ───────────────────────────────────────────────────────
class SwipeStyleScreen extends StatefulWidget {
  const SwipeStyleScreen({super.key});
  @override
  State<SwipeStyleScreen> createState() => _SwipeStyleScreenState();
}

class _SwipeStyleScreenState extends State<SwipeStyleScreen>
    with TickerProviderStateMixin {

  int _topIndex = 0;
  bool _warmMode = true;
  int _cartCount = 0;

  // Drag
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0;
  bool _isDragging = false;

  // Hints
  double _rightHint = 0, _leftHint = 0, _upHint = 0;

  // Try-on
  double _tryOnOpacity = 0;
  Timer? _tryOnTimer;

  // Cart
  bool _cartExpanded = false;
  final List<_Outfit> _cartItems = [];

  // ── SKU cart (additive) — resolved CartPayloads for each right-swipe ───────
  // Runs parallel to _cartItems; no widget/layout/animation impact.
  final List<CartPayload> _skuCart = [];

  // Heart burst
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale, _heartFade;
  bool _showHeart = false;

  // Drawer
  bool _drawerOpen = false;
  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;

  // Swipe-out
  late AnimationController _swipeCtrl;
  late Animation<Offset> _swipeAnim;
  _SwipeDir? _swipeDir;

  // Card appear
  late AnimationController _appearCtrl;
  late Animation<double> _appearAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _heartScale = Tween<double>(begin: 0.4, end: 1.8).animate(
        CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut));
    _heartFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _heartCtrl,
            curve: const Interval(0.55, 1.0, curve: Curves.easeOut)));

    _drawerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360));
    _drawerAnim =
        CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOutCubic);

   _swipeCtrl = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 300),
);
    _swipeAnim =
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_swipeCtrl);

    _appearCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _appearAnim =
        CurvedAnimation(parent: _appearCtrl, curve: Curves.easeOutCubic);
    _appearCtrl.forward();

    _startTryOnTimer();
  }

  void _startTryOnTimer() {
    _tryOnTimer?.cancel();
    setState(() => _tryOnOpacity = 0);
    _tryOnTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _tryOnOpacity = 1.0);
    });
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _drawerCtrl.dispose();
    _swipeCtrl.dispose();
    _appearCtrl.dispose();
    _tryOnTimer?.cancel();
    super.dispose();
  }

  // ── SKU ── Parse a display price string like '₹18,500' → paise (1850000) ───
  int _priceToPaise(String price) {
    final n = int.tryParse(price.replaceAll(RegExp(r'[₹,\s]'), '')) ?? 0;
    return n * 100;
  }

  // ── Drag handlers ─────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails _) =>
      setState(() { _isDragging = true; _dragOffset = Offset.zero; });

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _dragOffset += d.delta;
      _dragRotation = _dragOffset.dx * 0.0012;
      final dx = _dragOffset.dx, dy = _dragOffset.dy;
      if (_dragOffset.distance < 12) {
        _rightHint = _leftHint = _upHint = 0;
      } else if (dy < -30 && dy.abs() > dx.abs()) {
        _upHint = ((-dy - 30) / 70).clamp(0.0, 1.0);
        _rightHint = _leftHint = 0;
      } else if (dx > 0) {
        _rightHint = ((dx - 20) / 70).clamp(0.0, 1.0);
        _leftHint = _upHint = 0;
      } else {
        _leftHint = ((-dx - 20) / 70).clamp(0.0, 1.0);
        _rightHint = _upHint = 0;
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    final dx = _dragOffset.dx, dy = _dragOffset.dy;
    if (dy < -90 && dy.abs() > dx.abs()) _triggerSwipe(_SwipeDir.up);
    else if (dx > 80) _triggerSwipe(_SwipeDir.right);
    else if (dx < -80) _triggerSwipe(_SwipeDir.left);
    else {
      setState(() {
        _dragOffset = Offset.zero;
        _dragRotation = 0;
        _isDragging = false;
        _rightHint = _leftHint = _upHint = 0;
      });
    }
  }

  void _triggerSwipe(_SwipeDir dir) {
    _swipeDir = dir;
    final end = dir == _SwipeDir.right
        ? const Offset(700, 80)
        : dir == _SwipeDir.left
            ? const Offset(-700, 80)
            : const Offset(0, -800);

    _swipeAnim = Tween<Offset>(begin: _dragOffset, end: end).animate(
        CurvedAnimation(parent: _swipeCtrl, curve: _swipeDir == _SwipeDir.left
    ? const Cubic(0.25, 0.46, 0.45, 0.94)
    : const Cubic(0.34, 1.56, 0.64, 1)));

    _swipeCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      if (dir == _SwipeDir.right) {
        final o = _outfits[_topIndex % _outfits.length];
        _cartItems.add(o);
        _cartCount++;
        // ── SKU ── resolve this liked outfit into a SKU-bearing CartPayload.
        _skuCart.add(_skuPayloadFor(
          parentId         : o.parentId,
          name             : o.style,
          brand            : o.brand,
          unitPriceInPaise : _priceToPaise(o.price),
          imageUrl         : o.imageUrl,
        ));
        final payload = _skuCart.last;
        debugPrint('🧾 SwipeStyle LOVE → SKU ${payload.variantSku}  '
            '${payload.size}/${payload.colorName}');
        CartService.instance.addItem(payload).catchError((e) {
          debugPrint('⚠️  CartService.addItem error: $e');
        });
      }
      setState(() {
        _topIndex++;
        _dragOffset = Offset.zero;
        _dragRotation = 0;
        _isDragging = false;
        _rightHint = _leftHint = _upHint = 0;
        _swipeDir = null;
      });
      _swipeCtrl.reset();
      _appearCtrl.forward(from: 0);
      _startTryOnTimer();
    });
  }

  void _handleDoubleTap() {
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0)
        .then((_) { if (mounted) setState(() => _showHeart = false); });
  }

  void _handleLongPress() {
    setState(() => _drawerOpen = true);
    _drawerCtrl.forward();
  }

  void _closeDrawer() =>
      _drawerCtrl.reverse()
          .then((_) { if (mounted) setState(() => _drawerOpen = false); });

  // ── SKU ── Finalize the resolved SKU cart (SEND TO MAIN CART). Backend only.
  Future<void> _sendSkuCartToMain() async {
  if (_skuCart.isEmpty) return;
  try {
    await CartService.instance.addItems(_skuCart);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_skuCart.length} item${_skuCart.length > 1 ? 's' : ''} sent to cart!',
          style: _T.label(13, color: _C.white),
        ),
        backgroundColor: _C.magenta,
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() => _cartExpanded = false);
  } catch (e) {
    debugPrint('⚠️  CartService.addItems error: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to sync cart. Try again.',
            style: _T.label(13, color: _C.white)),
        backgroundColor: _C.sale,
      ),
    );
  }
}

  // ─────────────────────────────────────────────────────────────────────────
  @override
Widget build(BuildContext context) {

  final mq = MediaQuery.of(context);

  const double actionBarH = 100.0;
  const double cartStripH = 40.0;

  final double safeBot = mq.padding.bottom;

  final double bottomBarH =
      actionBarH + cartStripH + safeBot;

  final double topBarH =
      mq.padding.top + 56.0;

  return AnimatedContainer(

    duration: const Duration(milliseconds: 500),

    curve: Curves.easeInOut,

    decoration: BoxDecoration(

      gradient: LinearGradient(

        begin: Alignment.topLeft,
        end: Alignment.bottomRight,

        colors: _warmMode
            ? [
                const Color(0x22FFB74D),
                Colors.transparent,
              ]
            : [
                const Color(0x221E88E5),
                Colors.transparent,
              ],
      ),
    ),

    child: Scaffold(

      backgroundColor: Colors.transparent,

      body: Stack(

        children: [

          _buildStackCards(topBarH, bottomBarH),

          _buildMainCard(topBarH, bottomBarH),

          _buildHints(mq),

          _buildTopBar(mq),

          _buildTryOnBtn(bottomBarH),

          _buildBottomBar(mq, safeBot),

          if (_showHeart) _buildHeartBurst(),

          if (_showHeart) _buildSparkBurst(),

          if (_drawerOpen) _buildDrawer(mq),

          if (_cartExpanded)
            _buildCartPanel(bottomBarH),
        ],
      ),
    ),
  );
}

  // ─── 1. STACK DEPTH CARDS ─────────────────────────────────────────────────
  Widget _buildStackCards(double topH, double botH) {
    Widget card(int offset, double scale, double topExtra, double hzPad) {
      final idx = (_topIndex + offset) % _outfits.length;
      return Positioned(
        top: topH + topExtra,
        left: hzPad,
        right: hzPad,
        bottom: botH + topExtra * 0.5,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(_outfits[idx].imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );
    }
    return Stack(children: [
      card(2, 0.88, 16, 18),
      card(1, 0.94, 9,  10),
    ]);
  }

  // ─── 2. MAIN CARD ─────────────────────────────────────────────────────────
  Widget _buildMainCard(double topH, double botH) {

  final outfit =
      _outfits[_topIndex % _outfits.length];

  return Positioned(

    top: topH,
    left: 0,
    right: 0,
    bottom: botH,

    child: AnimatedBuilder(

      animation:
          Listenable.merge([_swipeCtrl, _appearCtrl]),

      builder: (_, __) {

        final offset = _swipeCtrl.isAnimating
            ? _swipeAnim.value
            : (_isDragging
                ? _dragOffset
                : Offset.zero);

        final rot = _swipeCtrl.isAnimating
            ? (_swipeDir == _SwipeDir.right
                ? 0.12
                : _swipeDir == _SwipeDir.left
                    ? -0.12
                    : 0.0)
            : _dragRotation;

        return Transform(

          transform: Matrix4.identity()
            ..translate(offset.dx, offset.dy)
            ..rotateZ(rot),

          alignment: Alignment.bottomCenter,

          child: FadeTransition(

            opacity: _appearAnim,

            child: GestureDetector(

              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onDoubleTap: _handleDoubleTap,
              onLongPress: _handleLongPress,

              child: Stack(

                fit: StackFit.expand,

                children: [

                  // FABRIC TRAIL WAVE
                  if (_swipeDir == _SwipeDir.left &&
                      _swipeCtrl.isAnimating)

                    AnimatedBuilder(

                      animation: _swipeCtrl,

                      builder: (_, __) {

                        return Positioned.fill(

                          child: Opacity(

                            opacity:
                                (1 - _swipeCtrl.value) * 0.22,

                            child: Transform.translate(

                              offset: Offset(
                                -40 * _swipeCtrl.value,
                                0,
                              ),

                              child: Container(

                                decoration: BoxDecoration(

                                  gradient: LinearGradient(

                                    colors: [
                                      Colors.white
                                          .withOpacity(0.10),

                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // MAIN CARD
                  _OutfitCard(outfit: outfit),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  // ─── 3. HINT STAMPS ───────────────────────────────────────────────────────
  Widget _buildHints(MediaQueryData mq) {
    final top = mq.padding.top + 80.0;
    return Stack(children: [
      Positioned(
        top: top, left: 16,
        child: Opacity(
          opacity: _rightHint,
          child: Transform.rotate(angle: -0.25,
            child: _HintStamp(label: 'LOVE IT', color: _C.magenta)),
        ),
      ),
      Positioned(
        top: top, right: 16,
        child: Opacity(
          opacity: _leftHint,
          child: Transform.rotate(angle: 0.25,
            child: _HintStamp(label: 'PASS', color: _C.grey300)),
        ),
      ),
      Positioned(
        top: top, left: 0, right: 0,
        child: Opacity(
          opacity: _upHint,
          child: Center(child: _HintStamp(label: 'VIBE CHECK', color: _C.amber)),
        ),
      ),
    ]);
  }

  // ─── 4. TOP BAR ───────────────────────────────────────────────────────────
  Widget _buildTopBar(MediaQueryData mq) {
    final current = _topIndex % _outfits.length + 1;
    final total   = _outfits.length;
    final vibe    = _outfits[_topIndex % _outfits.length].vibeTag.toUpperCase();

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xD0000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          top: mq.padding.top + 10,
          bottom: 14, left: 16, right: 16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.arrow_back_ios_new,
                    color: _C.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text('SWIPESTYLE',
                  style: _T.display(22, color: _C.white, spacing: 2)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _cartExpanded = !_cartExpanded),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _C.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined,
                        color: _C.white, size: 22),
                  ),
                  if (_cartCount > 0)
                    Positioned(
                      top: -5, right: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                            color: _C.magenta, shape: BoxShape.circle),
                        child: Center(
                          child: Text('$_cartCount',
                              style: _T.label(9, color: _C.white, spacing: 0)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$current / $total',
                      style: _T.label(11, color: _C.white, spacing: 0.5)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  color: _C.magenta,
                  child: Text(vibe,
                      style: _T.label(8, color: _C.white, spacing: 1.2)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 5. VIRTUAL TRY-ON BUTTON ─────────────────────────────────────────────
  Widget _buildTryOnBtn(double bottomBarH) {

  return Positioned(

    bottom: bottomBarH + 12,
    left: 0,
    right: 0,

    child: AnimatedOpacity(

      opacity: _tryOnOpacity,

      duration: const Duration(milliseconds: 500),

      child: Center(

        child: GestureDetector(

          onTap: () {

            ScaffoldMessenger.of(context).showSnackBar(

              SnackBar(

                content: Text(
                  'Virtual Try-On coming soon!',

                  style: _T.label(
                    13,
                    color: _C.white,
                  ),
                ),

                backgroundColor: _C.dark,

                duration: const Duration(seconds: 2),
              ),
            );
          },

          child: Stack(

            alignment: Alignment.center,

            children: [

              // TIMER RING
              TweenAnimationBuilder(

                tween: Tween(begin: 1.0, end: 0.0),

                duration: const Duration(minutes: 15),

                builder: (_, value, __) {

                  return SizedBox(

                    width: 72,
                    height: 72,

                    child: CircularProgressIndicator(

                      value: value,

                      strokeWidth: 2,

                      backgroundColor: Colors.white12,

                      valueColor: AlwaysStoppedAnimation(

                        value < 0.13
                            ? Colors.red
                            : value < 0.33
                                ? Colors.amber
                                : _C.brandTan,
                      ),
                    ),
                  );
                },
              ),

              // BUTTON
              Container(

                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 9,
                ),

                decoration: BoxDecoration(

                  color: _C.white.withOpacity(0.10),

                  borderRadius: BorderRadius.circular(2),

                  border: Border.all(
                    color: _C.white.withOpacity(0.28),
                    width: 1,
                  ),
                ),

                child: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Icon(
                      Icons.view_in_ar_outlined,

                      size: 14,

                      color: _C.white.withOpacity(0.85),
                    ),

                    const SizedBox(width: 8),

                    Text(

                      'VIRTUAL TRY-ON',

                      style: _T.label(

                        11,

                        color:
                            _C.white.withOpacity(0.85),

                        spacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ─── 6. BOTTOM BAR ────────────────────────────────────────────────────────
  Widget _buildBottomBar(MediaQueryData mq, double safeBot) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 100,
            color: _C.navBg,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionBtn(
                  icon: Icons.close_rounded,
                  color: _C.grey300,
                  iconSize: 26, containerSize: 50,
                  label: 'PASS',
                  onTap: () => _triggerSwipe(_SwipeDir.left),
                ),
                _ActionBtn(
                  icon: Icons.bolt,
                  color: _C.amber,
                  iconSize: 22, containerSize: 46,
                  label: 'VIBE',
                  onTap: () => _triggerSwipe(_SwipeDir.up),
                ),
                _ActionBtn(
                  icon: Icons.favorite_rounded,
                  color: _C.white,
                  iconSize: 32, containerSize: 64,
                  label: 'LOVE IT',
                  primary: true,
                  onTap: () => _triggerSwipe(_SwipeDir.right),
                ),
                _ActionBtn(
                  icon: Icons.bookmark_border_rounded,
                  color: _C.grey300,
                  iconSize: 22, containerSize: 46,
                  label: 'SAVE',
                  onTap: _handleDoubleTap,
                ),
                _ActionBtn(
                  icon: Icons.tune,
                  color: _C.grey300,
                  iconSize: 22, containerSize: 46,
                  label: 'BUILD',
                  onTap: _handleLongPress,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _cartExpanded = !_cartExpanded),
            onVerticalDragUpdate: (d) {
              if (d.delta.dy < -6) setState(() => _cartExpanded = true);
              if (d.delta.dy > 6)  setState(() => _cartExpanded = false);
            },
            child: Container(
              color: _C.brownDark,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 4, color: _C.brown),
                  SizedBox(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28, height: 3,
                          decoration: BoxDecoration(
                              color: _C.brown,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 14),
                        Text('SWIPESTYLE CART',
                            style: _T.label(11,
                                color: _C.ivory, spacing: 1.8)),
                        if (_cartCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 22, height: 22,
                            decoration: const BoxDecoration(
                                color: _C.magenta, shape: BoxShape.circle),
                            child: Center(
                              child: Text('$_cartCount',
                                  style: _T.label(10,
                                      color: _C.white, spacing: 0)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: safeBot),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 7. HEART BURST ───────────────────────────────────────────────────────
  Widget _buildHeartBurst() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _heartCtrl,
            builder: (_, __) => Opacity(
              opacity: _heartFade.value,
              child: Transform.scale(
                scale: _heartScale.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(
                          18 * _heartCtrl.value, -18 * _heartCtrl.value),
                      child: Opacity(
                        opacity: _heartFade.value * 0.55,
                        child: const Icon(Icons.favorite_rounded,
                            color: _C.magenta, size: 55),
                      ),
                    ),
                    const Icon(Icons.favorite_rounded,
                        color: _C.magenta, size: 78),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

  }

  Widget _buildSparkBurst() {

  return Positioned.fill(

    child: IgnorePointer(

      child: AnimatedBuilder(

        animation: _heartCtrl,

        builder: (_, __) {

          return Stack(

            children: List.generate(6, (i) {

              final angle = (pi / 3) * i;

              final dist = 80 * _heartCtrl.value;

              return Positioned(

                left:
                    MediaQuery.of(context).size.width / 2 +
                    cos(angle) * dist,

                top:
                    MediaQuery.of(context).size.height / 2 +
                    sin(angle) * dist,

                child: Opacity(

                  opacity: 1 - _heartCtrl.value,

                  child: Container(

                    width: 6,
                    height: 6,

                    decoration: const BoxDecoration(
                      color: _C.magenta,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    ),
  );
}

  // ─── 8. OUTFIT BUILDER DRAWER ─────────────────────────────────────────────
  Widget _buildDrawer(MediaQueryData mq) {
    final outfit = _outfits[_topIndex % _outfits.length];
    final pieces = [
      ('Hero Piece', outfit.style,           outfit.price, true),
      ('Bottom',     'Wide-leg Trousers',    '₹3,200',    false),
      ('Shoes',      'Strappy Block Heels',  '₹4,500',    false),
      ('Bag',        'Mini Structured Clutch','₹2,800',   false),
    ];
    return GestureDetector(
      onTap: _closeDrawer,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 1), end: Offset.zero)
                  .animate(_drawerAnim),
              child: Container(
                color: _C.dark,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      width: 36, height: 3,
                      decoration: BoxDecoration(
                          color: _C.grey700,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Row(
                        children: [
                          Text('INSTANT OUTFIT BUILDER',
                              style: _T.display(20,
                                  color: _C.white, spacing: 1)),
                          const Spacer(),
                          GestureDetector(
                            onTap: _closeDrawer,
                            child: const Icon(Icons.close,
                                color: _C.grey500, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: _C.grey700, height: 1),
                    ...pieces.asMap().entries.map((entry) {

  final index = entry.key;
  final p = entry.value;

  return TweenAnimationBuilder(
    duration: Duration(milliseconds: 360 + (index * 80)),
    tween: Tween(begin: 30.0, end: 0.0),
    curve: const Cubic(0.34, 1.56, 0.64, 1),

    builder: (_, value, child) {
      return Transform.translate(
        offset: Offset(0, value),

        child: Opacity(
          opacity: 1 - (value / 30),

          child: child,
        ),
      );
    },

    child: ListTile(
      dense: true,

      leading: Container(
        width: 7,
        height: 7,

        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.$4 ? _C.magenta : _C.grey700,
        ),
      ),

      title: Text(
        p.$2,

        style: _T.label(
          13,
          color: _C.white,
          spacing: 0,
        ),
      ),

      subtitle: Text(
        p.$1,

        style: _T.body(
          11,
          color: _C.grey500,
        ),
      ),

      trailing: Text(
        p.$3,

        style: _T.label(
          12,
          color: p.$4 ? _C.magenta : _C.grey300,
          spacing: 0,
        ),
      ),
    ),
  );

}).toList(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _closeDrawer,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                    border: Border.all(color: _C.grey700)),
                                child: Center(
                                    child: Text('ADD PIECES',
                                        style: _T.label(12,
                                            color: _C.white, spacing: 1.2))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _closeDrawer();
                                _triggerSwipe(_SwipeDir.right);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                color: _C.magenta,
                                child: Center(
                                    child: Text('ADD FULL SET',
                                        style: _T.label(12,
                                            color: _C.white, spacing: 1.2))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: mq.padding.bottom),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 9. CART PANEL ────────────────────────────────────────────────────────
  Widget _buildCartPanel(double bottomBarH) {
    return Positioned(
      bottom: bottomBarH,
      left: 0, right: 0,
      child: Container(
        color: _C.dark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text('SWIPED RIGHT',
                      style: _T.display(18, color: _C.white, spacing: 1)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _cartExpanded = false),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: _C.grey500, size: 22),
                  ),
                ],
              ),
            ),
            if (_cartItems.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Text('Swipe right on an outfit to add it here!',
                    style: _T.body(13, color: _C.grey500)),
              )
            else
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: _cartItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => AspectRatio(
                    aspectRatio: 0.75,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(_cartItems[i].imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: _C.grey700)),
                    ),
                  ),
                ),
              ),
            if (_cartItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: GestureDetector(
                  // ── SKU ── was `() {}` — now finalizes the resolved SKU cart.
                  // No visible change: button looks/behaves identically.
                  onTap: _sendSkuCartToMain,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: _C.magenta,
                    child: Center(
                        child: Text('SEND TO MAIN CART',
                            style: _T.label(13,
                                color: _C.white, spacing: 1.5))),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── OUTFIT CARD ──────────────────────────────────────────────────────────────
// Converted to StatefulWidget to support New Drop shimmer sweep animation
class _OutfitCard extends StatefulWidget {
  final _Outfit outfit;
  const _OutfitCard({required this.outfit, super.key});
  @override
  State<_OutfitCard> createState() => _OutfitCardState();
}

class _OutfitCardState extends State<_OutfitCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    // Shimmer sweep: plays once 300ms after card appears — only for New Drops
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    if (widget.outfit.isNewDrop) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _shimmerCtrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outfit = widget.outfit;
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Full-bleed image ────────────────────────────────────────────
        Image.network(
          outfit.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, p) =>
              p == null ? child : Container(color: _C.grey150),
          errorBuilder: (_, __, ___) => Container(
            color: _C.grey150,
            child: Center(child: Icon(Icons.image_outlined,
                color: _C.grey300, size: 48)),
          ),
        ),

        // ── Bottom gradient overlay ─────────────────────────────────────
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xF2000000)],
              stops: [0.40, 1.0],
            ),
          ),
        ),

        // ── NEW DROP shimmer sweep ──────────────────────────────────────
        // Spec: "Shimmer sweep on card" — single diagonal white sheen on appear
        if (outfit.isNewDrop)
          AnimatedBuilder(
            animation: _shimmer,
            builder: (_, __) {
              if (!_shimmerCtrl.isAnimating && _shimmerCtrl.value == 0) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(_shimmer.value - 0.6, -0.5),
                        end:   Alignment(_shimmer.value + 0.6,  0.5),
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.13),
                          Colors.white.withOpacity(0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        // ── Text overlay (bottom-left) ──────────────────────────────────
        Positioned(
          left: 16, right: 16, bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brand
              Text(outfit.brand, style: _T.brandName(26, color: _C.ivory)),
              const SizedBox(height: 2),
              Text(outfit.style,
                  style: _T.body(13, color: _C.ivory.withOpacity(0.80)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),

              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(outfit.price,
                      style: GoogleFonts.montserrat(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: _C.ivory)),
                  if (outfit.originalPrice != null) ...[
                    const SizedBox(width: 10),
                    Text(outfit.originalPrice!,
                        style: GoogleFonts.robotoMono(
                            fontSize: 13,
                            color: _C.grey500,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: _C.grey500)),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Occasion tags
              Wrap(
                spacing: 6, runSpacing: 4,
                children: outfit.occasions.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.white.withOpacity(0.12),
                    border: Border.all(
                        color: _C.white.withOpacity(0.22), width: 1),
                  ),
                  child: Text(tag,
                      style: GoogleFonts.montserrat(
                          fontSize: 9, fontWeight: FontWeight.w900,
                          color: _C.ivory, letterSpacing: 1.2)),
                )).toList(),
              ),
              const SizedBox(height: 10),

              // ── FOMO SIGNAL ROW ────────────────────────────────────────
              // Ch. 15: max 2 active signals per card, editorial not panic
              _FomoSignalRow(outfit: outfit),
              const SizedBox(height: 12),

              // Xpense Meter
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 30),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── FOMO SIGNAL ROW ──────────────────────────────────────────────────────────
// Ch. 15: "FOMO signals must never feel desperate. They are editorial callouts
// — factual urgency, not panic design."
// Priority: stock > social > recency > newDrop > trending  |  max 2 per card
class _FomoSignalRow extends StatefulWidget {
  final _Outfit outfit;
  const _FomoSignalRow({required this.outfit, super.key});
  @override
  State<_FomoSignalRow> createState() => _FomoSignalRowState();
}

class _FomoSignalRowState extends State<_FomoSignalRow>
    with SingleTickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    // 2s pulse for Stock Counter (spec: "2s pulse animation")
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outfit;
    final signals = <Widget>[];

    // 1 — Stock Counter (Roboto Mono · fomoRed · 2s pulse)
    if (o.stockLeft != null && o.stockLeft! < 5 && signals.length < 2) {
      signals.add(_stockSignal(o.stockLeft!));
    }
    // 2 — Social Proof (Montserrat Black · muted · static)
    if (o.viewersNow != null && signals.length < 2) {
      signals.add(_socialProof(o.viewersNow!));
    }
    // 3 — Recency Signal (Jost · brandTan · no animation)
    if (o.ordersToday != null && signals.length < 2) {
      signals.add(_recencySignal(o.ordersToday!));
    }
    // 4 — New Drop Alert (Roboto Mono · shimmer on card · NEW badge glow)
    if (o.isNewDrop && o.droppedMinsAgo != null && signals.length < 2) {
      signals.add(_newDropSignal(o.droppedMinsAgo!));
    }
    // 5 — Trending Badge (crown icon · brandTan · static pill)
    if (o.trendingFor != null && signals.length < 2) {
      signals.add(_trendingSignal(o.trendingFor!));
    }

    if (signals.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 5, children: signals);
  }

  // ── 1. Stock Counter ──────────────────────────────────────────────────────
  Widget _stockSignal(int stock) => AnimatedBuilder(
    animation: _pulse,
    builder: (_, __) => Opacity(
      opacity: _pulse.value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        color: _C.fomoRed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 10, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              'Only $stock left in your size',
              style: GoogleFonts.robotoMono(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── 2. Social Proof ───────────────────────────────────────────────────────
  Widget _socialProof(int viewers) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    color: Colors.white.withOpacity(0.09),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.remove_red_eye_outlined, size: 10, color: _C.grey300),
        const SizedBox(width: 5),
        Text(
          '$viewers people viewing this now',
          style: GoogleFonts.montserrat(
            fontSize: 9, fontWeight: FontWeight.w900,
            color: _C.grey300, letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );

  // ── 3. Recency Signal ─────────────────────────────────────────────────────
  Widget _recencySignal(int orders) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    color: _C.brandTan.withOpacity(0.18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department_outlined,
            size: 10, color: _C.brandTan),
        const SizedBox(width: 5),
        Text(
          'Ordered $orders times today',
          style: GoogleFonts.jost(
            fontSize: 9, fontWeight: FontWeight.w600,
            color: _C.brandTan, letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );

  // ── 4. New Drop Alert ─────────────────────────────────────────────────────
  Widget _newDropSignal(int minsAgo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withOpacity(0.10),
          blurRadius: 10, spreadRadius: 0,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // NEW badge with glow (spec)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          color: Colors.white,
          child: Text(
            'NEW',
            style: GoogleFonts.montserrat(
              fontSize: 7.5, fontWeight: FontWeight.w900,
              color: _C.dark, letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'Dropped $minsAgo min ago',
          style: GoogleFonts.robotoMono(
            fontSize: 9, color: _C.ivory, letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );

  // ── 5. Trending Badge ─────────────────────────────────────────────────────
  Widget _trendingSignal(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _C.brandTan.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.brandTan.withOpacity(0.40), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.workspace_premium_rounded,
            size: 11, color: _C.brandTan),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 9, fontWeight: FontWeight.w900,
            color: _C.brandTan, letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

// ─── HINT STAMP ───────────────────────────────────────────────────────────────
class _HintStamp extends StatelessWidget {
  final String label;
  final Color color;
  const _HintStamp({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(border: Border.all(color: color, width: 3)),
    child: Text(label,
        style: GoogleFonts.bebasNeue(
            fontSize: 34, color: color, letterSpacing: 1)),
  );
}

// ─── ACTION BUTTON ────────────────────────────────────────────────────────────
class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double iconSize, containerSize;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.iconSize,
    required this.containerSize,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp:   (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.containerSize,
                height: widget.containerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.primary
                      ? _C.magenta
                      : _C.white.withOpacity(0.07),
                  border: widget.primary
                      ? null
                      : Border.all(
                          color: _C.white.withOpacity(0.14), width: 1.5),
                  boxShadow: widget.primary
                      ? [BoxShadow(
                          color: _C.magenta.withOpacity(0.50),
                          blurRadius: 22, spreadRadius: 2)]
                      : null,
                ),
                child: Icon(widget.icon,
                    color: widget.primary ? _C.white : widget.color,
                    size: widget.iconSize),
              ),
              const SizedBox(height: 5),
              Text(widget.label,
                  style: _T.label(8,
                      color: widget.primary ? _C.magenta : _C.grey500,
                      spacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}