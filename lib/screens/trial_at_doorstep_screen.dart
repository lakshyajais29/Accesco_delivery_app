import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/tracking_service.dart';
import '../theme/map_style.dart';
import 'sku_catalog.dart'; // ── SKU ── catalogue + CartPayload
import 'package:instastyle/services/cart_service.dart';
import 'package:instastyle/services/trial_api_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SKU INTEGRATION (additive — NO UI/UX change)
// Resolves a catalogue parentId to a concrete child-variant CartPayload using
// the first in-stock variant as the silent default selection (no picker shown,
// so the existing flow is untouched). The screen's own displayed price is kept
// as the unit price so nothing visible changes. Falls back to a synthesized
// payload when the parent isn't in SkuCatalog yet (e.g. FSR-MK).
// ═══════════════════════════════════════════════════════════════════════════
CartPayload _skuPayloadFor({
  required String? parentId,
  required String name,
  required String brand,
  required int unitPriceInPaise, // price shown on THIS screen — kept as-is
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

// ─── DESIGN TOKENS (exact match HomeScreen) ──────────────────────────────────
class _C {
  static const white   = Color(0xFFFFFFFF);
  static const bg      = Color(0xFFFFFFFF);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey150 = Color(0xFFEEEEEE);
  static const grey300 = Color(0xFFCCCCCC);
  static const grey500 = Color(0xFF999999);
  static const grey700 = Color(0xFF555555);
  static const dark    = Color(0xFF0D0D0D);
  static const magenta = Color(0xFFE91E8C);
  static const amber   = Color(0xFFFF8F00);
  static const sale    = Color(0xFFE53935);
  static const green   = Color(0xFF4CAF50);
  static const brandBrown = Color(0xFF8B7536);
  static const brandTan   = Color(0xFFC8A97E);
  static const fomoFlash  = Color(0xFFC0392B);
  // Map palette
  static const mapBg   = Color(0xFF12122A);
  static const mapRoad = Color(0xFF8B7536);
  static const mapGrid = Color(0xFF1E1E3A);
}

// ─── CUBIC BEZIER CURVES matching spec ───────────────────────────────────────
// "fabric-like" cubic-bezier(0.25, 0.46, 0.45, 0.94)
const Curve _kFabric     = Cubic(0.25, 0.46, 0.45, 0.94);
// "spring arc"  cubic-bezier(0.34, 1.56, 0.64, 1)
const Curve _kSpringArc  = Cubic(0.34, 1.56, 0.64, 1);
// "trailing opacity" cubic-bezier(0.25, 0.46, 0.45, 0.94)
const Curve _kTrail      = Cubic(0.25, 0.46, 0.45, 0.94);
// S-curve for logo wave cubic-bezier(0.37, 0.0, 0.63, 1)
const Curve _kSCurve     = Cubic(0.37, 0.0, 0.63, 1);

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

  static TextStyle mono(double size,
          {Color color = _C.dark, FontWeight fw = FontWeight.w700}) =>
      GoogleFonts.robotoMono(fontSize: size, fontWeight: fw, color: color);

  static TextStyle serif(double size,
          {Color color = _C.white, FontWeight fw = FontWeight.w600}) =>
      GoogleFonts.cormorantGaramond(
          fontSize: size, fontWeight: fw, color: color, height: 1.1);
}

// ─── PHASE ───────────────────────────────────────────────────────────────────
enum _Phase { preOrder, liveTracking, trialTimer }

// ─── MODELS ──────────────────────────────────────────────────────────────────
class _TrialItem {
  final String name;
  final String brand;
  final String price;
  final int    priceInt;
  final String imageUrl;
  final String? parentId; // ── SKU ── links this item to SkuCatalog (optional)
  bool? kept;
  bool  wishListed = false;

  _TrialItem({
    required this.name,
    required this.brand,
    required this.price,
    required this.priceInt,
    required this.imageUrl,
    this.parentId, // ── SKU ──
  });
}

// ─── DATA ────────────────────────────────────────────────────────────────────
List<_TrialItem> _buildItems() => [
  _TrialItem(name: 'Silk Wrap Blouse',    brand: 'ATELIER SUR',  price: '₹4,200', priceInt: 4200,
      imageUrl: 'https://images.unsplash.com/photo-1551803091-e20673f15770?w=300&q=80',
      parentId: 'PBL-AS'), // ── SKU ──
  _TrialItem(name: 'High-waist Palazzo',  brand: 'INDIRA & CO',  price: '₹3,800', priceInt: 3800,
      imageUrl: 'https://images.unsplash.com/photo-1566206091558-7f218b696731?w=300&q=80',
      parentId: 'VKT-IC'), // ── SKU ──
  _TrialItem(name: 'Block Heel Mules',    brand: 'CASA MODAS',   price: '₹6,500', priceInt: 6500,
      imageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=300&q=80',
      parentId: 'COS-CM'), // ── SKU ──
  _TrialItem(name: 'Structured Mini Bag', brand: 'DECO NOIR',    price: '₹8,900', priceInt: 8900,
      imageUrl: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=300&q=80',
      parentId: 'STJ-DN'), // ── SKU ──
];

// ─── SWIPE STATE ─────────────────────────────────────────────────────────────
enum _SwipeDir { none, left, right }

// ─────────────────────────────────────────────────────────────────────────────
// HEART PARTICLE — used by Double Tap Wishlist
// ─────────────────────────────────────────────────────────────────────────────
class _Heart {
  final Offset origin;
  final double dx;
  final double delay;
  final Color  color;
  _Heart({required this.origin, required this.dx, required this.delay, required this.color});
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class TrialAtDoorstepScreen extends StatefulWidget {
  final String orderId;
  final String riderId;
  const TrialAtDoorstepScreen({
    super.key,
    required this.orderId,
    required this.riderId,
  });
  @override
  State<TrialAtDoorstepScreen> createState() => _TrialAtDoorstepScreenState();
}

class _TrialAtDoorstepScreenState extends State<TrialAtDoorstepScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ── Phase ──────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.preOrder;

  // ── Live tracking state ────────────────────────────────────────────────────
  int _etaSecs = 4 * 60;
  Timer? _etaTimer;
  bool _checklistVisible = false;
  final List<bool> _checkTicked = [false, false, false];

  GoogleMapController? _mapController;
  final TrackingService _trackingService = TrackingService();
  StreamSubscription<TrackingData>? _trackingSub;
  LatLng _riderPosition = const LatLng(0, 0);
  String _etaText = 'Calculating...';

  // ── Trial timer state ──────────────────────────────────────────────────────
  int _trialSecs = 15 * 60;
  Timer? _trialTimer;
  final List<_TrialItem> _items = _buildItems();

  // ── SKU cart (additive) — resolved CartPayloads for the kept items ─────────
  // Populated on CONFIRM & PAY. Does not affect any widget or layout.
  final List<CartPayload> _skuCart = [];

  // ── Swipe card state (for add-to-cart and swipe gestures) ─────────────────
  int _activeSwipeIndex = -1;
  _SwipeDir _swipeDir   = _SwipeDir.none;
  double _swipeDx       = 0;
  bool _swipeAnimating  = false;
  String? _razorpayPaymentId;
  // ── FOMO flash state ───────────────────────────────────────────────────────
  final List<bool> _fomoFlashing = [false, false, false, false];
  final List<double> _fomoScales = [1.0, 1.0, 1.0, 1.0];

  // ── Wishlist hearts state ──────────────────────────────────────────────────
  final List<List<_Heart>> _heartsPerItem = [[], [], [], []];
  final List<AnimationController?> _heartCtrlPerItem = [null, null, null, null];

  // ── Add-to-cart ghost scale ────────────────────────────────────────────────
  final List<double> _cartScales = [1.0, 1.0, 1.0, 1.0];
  final List<bool> _cartBouncing = [false, false, false, false];

  // ── Page transition ────────────────────────────────────────────────────────
  late final AnimationController _pageTransCtrl;
  late final Animation<Offset>   _pageSlideAnim;

  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _heroFadeCtrl;
  late final AnimationController _dotPulseCtrl;   // ETA pulse — 2s interval per spec
  late final AnimationController _riderMoveCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _logoWaveCtrl;   // S-curve fabric wave
  late final AnimationController _cartIconBounceCtrl;

  // ── Outfit builder reveal (stagger spring) ─────────────────────────────────
  final List<AnimationController?> _revealCtrls = [null, null, null, null];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);  // ← ADD THIS LINE

    _heroFadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();

    // ETA Pulse — spec: 2s interval, 400ms per pulse, ease-in-out, green dot 1→1.4→1
    _dotPulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..repeat(reverse: true);

    _riderMoveCtrl = AnimationController(
        vsync: this, duration: const Duration(minutes: 4))
      ..forward();

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    // Logo/fabric wave — S-curve, 1.8s cycle, infinite
    _logoWaveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();

    // Cart icon bounce controller
    _cartIconBounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _cartIconBounceCtrl.reverse();
        }
      });

    // Page slide transition — fabric-like cubic-bezier(0.25,0.46,0.45,0.94), 320ms
    _pageTransCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _pageSlideAnim = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageTransCtrl, curve: _kFabric));
    _pageTransCtrl.value = 1.0;
    
    // Init outfit reveal controllers (spring bounce per spec)
    for (int i = 0; i < 4; i++) {
      _revealCtrls[i] = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 360 + i * 80),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);  // ← ADD THIS LINE

    _trackingSub?.cancel();
    _trackingService.disconnect();
    _mapController?.dispose();
    _etaTimer?.cancel();
    _trialTimer?.cancel();
    _heroFadeCtrl.dispose();
    _dotPulseCtrl.dispose();
    _riderMoveCtrl.dispose();
    _glowCtrl.dispose();
    _logoWaveCtrl.dispose();
    _cartIconBounceCtrl.dispose();
    _pageTransCtrl.dispose();
    for (final c in _revealCtrls) c?.dispose();
    for (final c in _heartCtrlPerItem) c?.dispose();
    super.dispose();
  }
  @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed &&
      _phase == _Phase.trialTimer) {
    _syncTimerWithServer();
  }
}

Future<void> _syncTimerWithServer() async {
  try {
    final status = await TrialApiService.pollStatus(widget.orderId);
    final remaining = (status['remaining_seconds'] as int?) ?? 0;
    if (!mounted) return;
    if (remaining == 0) {
      _trialTimer?.cancel();
      setState(() => _trialSecs = 0);
    } else {
      setState(() => _trialSecs = remaining);
    }
  } catch (_) {
    // Non-fatal — local timer continues if poll fails
  }
}

  // ── Phase transitions with page slide ─────────────────────────────────────
  void _goToLiveTracking() async {
    _pageTransCtrl.reset();
    setState(() => _phase = _Phase.liveTracking);
    await _pageTransCtrl.forward();

    _trackingSub = _trackingService.connectToTracking(widget.orderId).listen((data) {
      if (!mounted) return;
      setState(() {
        _riderPosition = data.position;
        _etaText = data.etaText;
        
        if (data.etaText.contains('min') && !_checklistVisible) {
           final minsStr = data.etaText.split(' ').first;
           final mins = int.tryParse(minsStr);
           if (mins != null && mins <= 2) {
             _checklistVisible = true;
             _triggerChecklistStagger();
           }
        }
        if (data.etaText == 'Arrived' || data.etaText == '0 min') {
           _trackingSub?.cancel();
           _goToTrialTimer();
        }
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_riderPosition));
    });
  }

  void _triggerChecklistStagger() async {
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: i == 0 ? 0 : 200));
      if (mounted) setState(() => _checkTicked[i] = true);
    }
  }

  void _goToTrialTimer() async {
    _pageTransCtrl.reset();
    setState(() => _phase = _Phase.trialTimer);
    await _pageTransCtrl.forward();
    await _notifyBackendRiderArrived();

    // Outfit builder reveal — stagger 80ms, spring-bounce per spec
    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) {
          _revealCtrls[i]?.forward(from: 0);
        }
      });
    }

    _trialTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_trialSecs > 0) _trialSecs--;
        else _trialTimer?.cancel();
      });
    });
  }
  Future<void> _openRazorpayThenConfirm() async {
  // If nothing kept, skip payment entirely
  if (_items.every((e) => e.kept != true)) {
    await _confirmAndPay();
    return;
  }

  // TODO: integrate razorpay_flutter package
  // Add to pubspec.yaml: razorpay_flutter: ^1.3.6
  // Then replace the block below with real Razorpay checkout:
  //
  // _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
  //   setState(() => _razorpayPaymentId = r.paymentId);
  //   _confirmAndPay();
  // });
  // _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(content: Text('Payment cancelled'), backgroundColor: _C.sale),
  //   );
  // });
  // _razorpay.open({
  //   'key': '<YOUR_RAZORPAY_KEY_ID>',
  //   'amount': _keepTotal * 100,
  //   'name': 'InstaStyle Trial',
  //   'description': 'Trial at Doorstep – ${_items.where((e)=>e.kept==true).length} item(s)',
  //   'prefill': {'contact': '', 'email': ''},
  // });

  // TEMPORARY until Razorpay is wired — remove this line after integration:
  await _confirmAndPay();
}
  // ── SKU ── Build the resolved SKU cart from the KEPT trial items ───────────
  // Called by the (previously empty) CONFIRM & PAY action. Purely backend —
  // no widget, layout, animation, or navigation changes.
  Future<void> _confirmAndPay() async {
    // ── 1. Build local SKU cart (existing logic — unchanged) ─────────────────
    _skuCart
      ..clear()
      ..addAll(_items.where((e) => e.kept == true).map((e) => _skuPayloadFor(
            parentId         : e.parentId,
            name             : e.name,
            brand            : e.brand,
            unitPriceInPaise : e.priceInt * 100,
            imageUrl         : e.imageUrl,
          )));
 
    for (final p in _skuCart) {
      debugPrint('🧾 Trial KEEP → SKU ${p.variantSku}  '
          '${p.size}/${p.colorName}  qty ${p.quantity}');
    }
 
    // ── 2. Sync kept items to CartService (existing) ──────────────────────────
    if (_skuCart.isEmpty) {
      // All returned — still call backend to release the rider
      await _callKeepOutfitBackend(keptSkus: [], paymentMethodId: null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No items kept — rider released!',
              style: _T.label(13, color: _C.white)),
          backgroundColor: _C.grey700,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
 
    try {
      await CartService.instance.addItems(_skuCart);
    } catch (e) {
      debugPrint('⚠️  CartService.addItems error: $e');
    }
 
    // ── 3. Call backend CONFIRM & PAY ─────────────────────────────────────────
    final keptSkus = _skuCart.map((p) => p.variantSku).toList();
    await _callKeepOutfitBackend(
      keptSkus:         keptSkus,
      paymentMethodId:  _razorpayPaymentId,   // set by Razorpay checkout callback
    );
  }
 
  // ── Backend call (separated so it's easy to test) ─────────────────────────
  Future<void> _callKeepOutfitBackend({
    required List<String> keptSkus,
    required String?      paymentMethodId,
  }) async {
    // orderId comes from your navigation arguments or a widget property.
    // Replace 'widget.orderId' with however you pass the order ID to this screen.
    // Example: add `final String orderId;` to TrialAtDoorstepScreen constructor.
    final orderId = widget.orderId;
 
    try {
      final result = await TrialApiService.confirmAndPay(
        orderId:          orderId,
        keptSkus:         keptSkus,
        paymentMethodId:  paymentMethodId,
      );
 
      if (!mounted) return;
 
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              keptSkus.isEmpty
                ? 'All returned — no charge!'
                : '${result.keptCount} item${result.keptCount > 1 ? 's' : ''} '
                  'confirmed · ₹${result.totalChargedInr.toStringAsFixed(0)}',
              style: _T.label(13, color: _C.white),
            ),
            backgroundColor: _C.magenta,
            duration: const Duration(seconds: 3),
          ),
        );
        // Navigate to order confirmation screen
        // Navigator.pushReplacementNamed(context, '/order-confirmation',
        //     arguments: {'order_id': orderId});
      }
    } on Exception catch (e) {
      debugPrint('⚠️  TrialApiService.confirmAndPay error: $e');
      if (!mounted) return;
      final isExpired = e.toString().contains('422') ||
          e.toString().contains('expired') ||
          e.toString().contains('not active');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExpired
                ? 'Session expired — please place a new order.'
                : 'Payment failed. Please try again.',
            style: _T.label(13, color: _C.white),
          ),
          backgroundColor: _C.sale,
          action: isExpired
              ? null
              : SnackBarAction(
                  label: 'Retry',
                  textColor: _C.white,
                  onPressed: _confirmAndPay,
                ),
        ),
      );
    }
  }
 
// ════════════════════════════════════════════════════════════════════════════
// Also add this method to your state class for calling start session
// when the rider arrives (replaces _goToTrialTimer or called just before it):
// ════════════════════════════════════════════════════════════════════════════
 
  Future<void> _notifyBackendRiderArrived() async {
        final orderId = widget.orderId;
        final riderId = widget.riderId;  // TODO: replace with widget.riderId
 
    try {
      await TrialApiService.startSession(
        orderId: orderId,
        riderId: riderId,
        items: _items.map((item) => {
          'variant_sku':    item.parentId ?? item.name,
          'product_name':   item.name,
          'unit_price_inr': item.priceInt,
        }).toList(),
      );
      debugPrint('✅ Trial backend session started for $orderId');
    } on Exception catch (e) {
      // Non-fatal — UI flow continues even if backend call fails
      debugPrint('⚠️  startSession backend call failed: $e');
    }
  }
 

  // ── Add to Cart animation: scale 1→1.04→1 (240ms), then cart icon bounce ──
  void _triggerAddToCart(int index) async {
    if (_cartBouncing[index]) return;
    setState(() {
      _cartBouncing[index] = true;
      _cartScales[index]   = 1.04;
    });
    // 240ms scale up
    await Future.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    setState(() => _cartScales[index] = 1.0);
    // 400ms arc (visual) then bounce cart icon
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    _cartIconBounceCtrl.forward(from: 0);
    // Trigger FOMO flash on that item after receipt
    _triggerFomoFlash(index);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _cartBouncing[index] = false);
  }

  // ── FOMO Stock Update: #C0392B 150ms flash, scale 1→1.15→1 (200ms) ────────
  void _triggerFomoFlash(int index) async {
    setState(() => _fomoFlashing[index] = true);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() {
      _fomoFlashing[index] = false;
      _fomoScales[index]   = 1.15;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _fomoScales[index] = 1.0);
  }

  // ── Double Tap Wishlist: 2 hearts rise+fade, 400ms each, 80ms stagger ─────
  void _triggerWishlist(int index) async {
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _heartCtrlPerItem[index]?.dispose();
    _heartCtrlPerItem[index] = ctrl;

    final rng    = Random();
    final ox     = 40.0 + rng.nextDouble() * 40;
    final hearts = [
      _Heart(origin: Offset(ox, 0), dx: -12, delay: 0,   color: _C.brandBrown),
      _Heart(origin: Offset(ox + 20, 0), dx: 8,  delay: 80,  color: _C.brandTan),
    ];

    setState(() {
      _items[index].wishListed = true;
      _heartsPerItem[index]    = hearts;
    });

    ctrl.forward();
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _heartsPerItem[index] = []);
      }
    });
  }

  // ── Swipe helpers ──────────────────────────────────────────────────────────
  void _onSwipeUpdate(DragUpdateDetails d, int index) {
    if (_swipeAnimating) return;
    setState(() {
      _activeSwipeIndex = index;
      _swipeDx = _swipeDx + d.delta.dx;
      _swipeDir = _swipeDx > 0 ? _SwipeDir.right : _SwipeDir.left;
    });
  }

  void _onSwipeEnd(DragEndDetails d, int index) async {
    if (_swipeAnimating) return;
    final threshold = 100.0;
    if (_swipeDx.abs() < threshold) {
      // Snap back
      setState(() { _swipeDx = 0; _swipeDir = _SwipeDir.none; _activeSwipeIndex = -1; });
      return;
    }
    _swipeAnimating = true;
    final dir = _swipeDx > 0 ? _SwipeDir.right : _SwipeDir.left;
    // Animate off-screen (300ms swipe + spring per spec)
    final targetDx = dir == _SwipeDir.right ? 500.0 : -500.0;
    final spring = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 180, damping: 20),
        _swipeDx, targetDx, d.velocity.pixelsPerSecond.dx / 1000);

    final ctrl = AnimationController.unbounded(vsync: this);
    ctrl.animateWith(spring).then((_) {
      if (!mounted) return;
      setState(() {
        _items[index].kept = dir == _SwipeDir.right ? true : false;
        _swipeDx = 0;
        _swipeDir = _SwipeDir.none;
        _activeSwipeIndex = -1;
        _swipeAnimating = false;
      });
      ctrl.dispose();
      if (dir == _SwipeDir.right) _triggerWishlist(index);
    });

    ctrl.addListener(() {
      if (mounted) setState(() => _swipeDx = ctrl.value);
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _allDecided => _items.every((e) => e.kept != null);
  int  get _keepTotal  => _items
      .where((e) => e.kept == true)
      .fold(0, (s, e) => s + e.priceInt);

  String _fmt(int v) {
    final s = v.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  Color get _ringColor {
    if (_trialSecs <= 2 * 60) return _C.sale;
    if (_trialSecs <= 5 * 60) return _C.amber;
    return _C.magenta;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final body = switch (_phase) {
      _Phase.preOrder     => _buildPreOrder(),
      _Phase.liveTracking => _buildLiveTracking(),
      _Phase.trialTimer   => _buildTrialTimer(),
    };

    // Wrap every phase in the page slide transition
    return Scaffold(
      backgroundColor: _C.bg,
      body: SlideTransition(
        position: _pageSlideAnim,
        child: body,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN 1 — PRE-ORDER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPreOrder() {
    return Column(
      children: [
        Expanded(
          flex: 75,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _heroFadeCtrl, curve: Curves.easeOut),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A0A0A), Color(0xFF180800), Color(0xFF250F00)],
                    ),
                  ),
                ),

                // Warm door-light glow (animated)
                AnimatedBuilder(
                  animation: _glowCtrl,
                  builder: (_, __) => Positioned(
                    right: -20, top: 0, bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.65,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, 0.1),
                          radius: 1.0,
                          colors: [
                            const Color(0xFFFF8C00)
                                .withOpacity(0.22 + _glowCtrl.value * 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Rider image
                Positioned.fill(
                  top: 70,
                  child: Image.asset(
                    'assets/images/trial.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),

                // Logo fabric-wave loading indicator at top
                Positioned(
                  top: MediaQuery.of(context).padding.top + 48,
                  right: 16,
                  child: _FabricWaveIndicator(controller: _logoWaveCtrl),
                ),

                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36, color: Colors.black54,
                      child: const Icon(Icons.arrow_back, size: 20, color: _C.white),
                    ),
                  ),
                ),

                Positioned(
                  top: MediaQuery.of(context).padding.top + 14,
                  left: 64,
                  child: Text('TRIAL AT DOORSTEP',
                      style: _T.display(18, color: _C.white, spacing: 2)),
                ),
              ],
            ),
          ),
        ),

        // ── Trust icons + CTA ──────────────────────────────────────────────
        Expanded(
          flex: 45,
          child: Container(
            color: _C.white,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _trustTile(Icons.access_time_rounded, 'Rider waits\n15 min'),
                    Container(width: 1, height: 44, color: _C.grey150),
                    _trustTile(Icons.payments_outlined, 'Pay only\nfor keeps'),
                    Container(width: 1, height: 44, color: _C.grey150),
                    _trustTile(Icons.sentiment_satisfied_alt_outlined, 'Zero\npressure'),
                  ],
                ),

                const SizedBox(height: 22),

                // Outfit preview strip — cart bounce icon in corner
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      Text('YOUR TRIAL PACK:', style: _T.label(10, color: _C.grey500, spacing: 1)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => GestureDetector(
                            // Add-to-cart: scale 1→1.04→1 (240ms), ghost arc, cart bounce
                            onTap: () => _triggerAddToCart(i),
                            child: AnimatedScale(
                              scale: _cartScales[i],
                              duration: const Duration(milliseconds: 240),
                              curve: _kSpringArc,
                              child: Stack(
                                children: [
                                  SizedBox(
                                    width: 48,
                                    child: Image.network(
                                      _items[i].imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: _C.grey150),
                                    ),
                                  ),
                                  // FOMO flash overlay
                                  if (_fomoFlashing[i])
                                    Positioned.fill(
                                      child: Container(
                                        color: _C.fomoFlash.withOpacity(0.45),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Cart icon with bounce (spec: 300ms scale spring on receipt)
                      
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // SELECT TRIAL ITEMS CTA
                GestureDetector(
                  onTap: _goToLiveTracking,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1C1C1E), Color(0xFF0D0D0D)],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(child: CustomPaint(painter: _GrainPainter(0.3))),
                        Positioned(left: 0, top: 0, bottom: 0, width: 4,
                            child: Container(color: _C.magenta)),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('SELECT TRIAL ITEMS',
                                  style: _T.display(20, color: _C.white, spacing: 2.5)),
                              const SizedBox(width: 12),
                              const Icon(Icons.arrow_forward, size: 18, color: _C.magenta),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Text('Opens outfit selection from checkout',
                    style: _T.body(11, color: _C.grey500),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _trustTile(IconData icon, String label) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: _C.magenta),
          const SizedBox(height: 6),
          Text(label, style: _T.body(11, color: _C.dark), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN 2 — LIVE TRACKING
  // ETA Pulse: 2s interval, 400ms per pulse, green dot 1→1.4→1, ease-in-out
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLiveTracking() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _riderPosition.latitude == 0 && _riderPosition.longitude == 0 
                      ? const LatLng(12.9352, 77.6245) // Bangalore dummy location
                      : _riderPosition,
                  zoom: 16,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _mapController?.setMapStyle(MapStyle.premiumSilverCream);
                  if (_riderPosition.latitude != 0) {
                    _mapController?.animateCamera(CameraUpdate.newLatLng(_riderPosition));
                  }
                },
                markers: {
                  if (_riderPosition.latitude != 0 && _riderPosition.longitude != 0)
                    Marker(
                      markerId: const MarkerId('rider'),
                      position: _riderPosition,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                    ),
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
              ),

              // Header overlay
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16, right: 16,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _etaTimer?.cancel();
                        _trackingSub?.cancel();
                        _pageTransCtrl.reset();
                        setState(() {
                          _phase = _Phase.preOrder;
                          _etaSecs = 4 * 60;
                          _checklistVisible = false;
                          for (int i = 0; i < 3; i++) _checkTicked[i] = false;
                        });
                        _pageTransCtrl.forward();
                      },
                      child: Container(
                        width: 36, height: 36, color: Colors.black54,
                        child: const Icon(Icons.arrow_back, size: 20, color: _C.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('LIVE TRACKING', style: _T.display(18, color: _C.white, spacing: 2)),
                    const Spacer(),
                    // ETA Pulse dot — spec: green dot 1→1.4→1, 400ms, ease-in-out, 2s interval
                    _EtaPulseDot(pulseCtrl: _dotPulseCtrl),
                    const SizedBox(width: 6),
                    Text('LIVE', style: _T.label(10, color: _C.white, spacing: 1)),
                  ],
                ),
              ),

              // ETA countdown bubble — Roboto Mono Bold
              Positioned(
                top: 0, bottom: 0, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    color: Colors.black87,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Rider arrives in',
                            style: _T.mono(11, color: _C.grey500, fw: FontWeight.w400)),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                  begin: const Offset(0, 0.3), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: anim, curve: _kFabric)),
                              child: child,
                            ),
                          ),
                          child: Text(_etaText,
                              key: ValueKey(_etaText),
                              style: _T.mono(32, color: _C.white)),
                        ),
                        const SizedBox(height: 4),
                        Text('Live updates',
                            style: _T.mono(9, color: _C.grey700, fw: FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
              ),

              // Simulate arrival shortcut
              Positioned(
                bottom: 14, right: 14,
                child: GestureDetector(
                  onTap: () {
                    _etaTimer?.cancel();
                    _trackingSub?.cancel();
                    _goToTrialTimer();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    color: _C.magenta,
                    child: Text('RIDER ARRIVED →',
                        style: _T.label(10, color: _C.white, spacing: 1)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Bottom panel ───────────────────────────────────────────────────
        Container(
          color: _C.dark,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 14,
            top: 16, left: 16, right: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Getting ready to try:', style: _T.label(12, color: _C.white, spacing: 0.3)),
              const SizedBox(height: 10),

              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return SizedBox(
                      width: 58,
                      child: Column(
                        children: [
                          Expanded(
                            child: Image.network(
                              item.imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: _C.grey700),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(item.brand,
                              style: _T.label(7, color: _C.grey500, spacing: 0),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Checklist at T-2 min
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: _checklistVisible
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          Container(height: 1, color: const Color(0xFF2E2E2E)),
                          const SizedBox(height: 12),
                          Text('Get ready:', style: _T.label(11, color: _C.grey500, spacing: 0.5)),
                          const SizedBox(height: 8),
                          ..._buildChecklist(),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChecklist() {
    final labels = ['Good lighting', 'Mirror nearby', 'Decide fast'];
    return List.generate(3, (i) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _checkTicked[i] ? 1.0 : 0.0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: _kFabric,
          offset: _checkTicked[i] ? Offset.zero : const Offset(-0.1, 0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: _C.magenta),
                const SizedBox(width: 10),
                Text(labels[i], style: _T.body(13, color: _C.white)),
                const SizedBox(width: 6),
                Text('✓', style: _T.label(13, color: _C.magenta, spacing: 0)),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN 3 — TRIAL TIMER
  // Outfit Builder Reveal: 80ms stagger, 360ms per card, spring-bounce
  // Double Tap Wishlist: 2 hearts rise+fade, brand brown + tan
  // KEEP/RETURN with spring-arc cubic-bezier(0.34,1.56,0.64,1)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTrialTimer() {
    final minutes  = _trialSecs ~/ 60;
    final seconds  = _trialSecs % 60;
    final progress = _trialSecs / (15 * 60);
    final rc       = _ringColor;
    final keepAmt  = _keepTotal;

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          color: _C.white,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 14, left: 16, right: 16,
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36, color: _C.grey100,
                child: const Icon(Icons.door_front_door_outlined, size: 20, color: _C.dark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RIDER AT DOOR', style: _T.display(22, spacing: 1.5)),
                    Text('Try on. Keep what you love.',
                        style: _T.body(11, color: _C.grey500)),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: rc.withOpacity(0.12),
                child: Text(
                  _trialSecs <= 2 * 60 ? 'URGENT!' :
                  _trialSecs <= 5 * 60 ? 'HURRY UP' : 'ACTIVE',
                  style: _T.label(9, color: rc, spacing: 1),
                ),
              ),
            ],
          ),
        ),

        // ── Body ───────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 140),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Circular countdown ring — Linear depletion per spec
                SizedBox(
                  width: 230, height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_trialSecs <= 2 * 60)
                        Container(
                          width: 230, height: 230,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _C.sale.withOpacity(0.18),
                                blurRadius: 30, spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),

                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CountdownRingPainter(progress: progress, ringColor: rc),
                        ),
                      ),

                      // Tick marks on ring (15 minute markers)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RingTickPainter(progress: progress, ringColor: rc),
                        ),
                      ),

                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 400),
                            style: _T.mono(48, color: rc),
                            child: Text(
                              '${minutes.toString().padLeft(2, '0')}:'
                              '${seconds.toString().padLeft(2, '0')}',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('remaining', style: _T.body(12, color: _C.grey500)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    key: ValueKey(_trialSecs ~/ 60),
                    _trialSecs <= 2 * 60
                        ? '⚡ Time almost up — decide now!'
                        : _trialSecs <= 5 * 60
                            ? 'Rider is waiting — wrap it up'
                            : 'Try everything on. Take your time.',
                    style: _T.body(13,
                        color: _trialSecs <= 2 * 60 ? _C.sale
                            : _trialSecs <= 5 * 60 ? _C.amber
                            : _C.grey700),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Item cards — Outfit Builder Reveal stagger + spring ────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('YOUR TRIAL ITEMS', style: _T.display(22, spacing: 1)),
                          const Spacer(),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: Text(
                              keepAmt > 0 ? '₹${_fmt(keepAmt)}' : '—',
                              key: ValueKey(keepAmt),
                              style: _T.display(22,
                                  color: keepAmt > 0 ? _C.magenta : _C.grey300, spacing: 0),
                            ),
                          ),
                        ],
                      ),
                      Text('Keep or return — total updates live',
                          style: _T.body(11, color: _C.grey500)),
                      const SizedBox(height: 14),

                      ...List.generate(_items.length, (i) {
                        final ctrl = _revealCtrls[i];
                        if (ctrl == null) return _buildItemCard(i);
                        // Spring-bounce reveal: slide up from below + fade
                        return AnimatedBuilder(
                          animation: ctrl,
                          builder: (_, child) {
                            final t = CurvedAnimation(parent: ctrl, curve: _kSpringArc).value;
                            return Transform.translate(
                              offset: Offset(0, 40 * (1 - t)),
                              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                            );
                          },
                          child: _buildItemCard(i),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── CONFIRM & PAY ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: _C.white,
            border: Border(top: BorderSide(color: _C.grey150.withOpacity(0.8))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20, offset: const Offset(0, -5),
              )
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 16, right: 16, top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_allDecided) ...[
                Row(
                  children: [
                    Text(
                      '${_items.where((e) => e.kept == true).length} kept'
                      ' · ${_items.where((e) => e.kept == false).length} returned',
                      style: _T.label(12, color: _C.grey700, spacing: 0),
                    ),
                    const Spacer(),
                    Text('₹${_fmt(_keepTotal)}',
                        style: _T.display(20, color: _C.magenta, spacing: 0)),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              GestureDetector(
                // ── SKU ── was `() {}` — now assembles the resolved SKU cart.
                // No visible change: button looks/behaves identically.
                onTap: _allDecided ? _openRazorpayThenConfirm : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: _kFabric,
                  width: double.infinity, height: 54,
                  decoration: BoxDecoration(
                    color: _allDecided ? _C.dark : _C.grey150,
                  ),
                  child: Stack(
                    children: [
                      if (_allDecided) ...[
                        Positioned.fill(child: CustomPaint(painter: _GrainPainter(0.42))),
                        Positioned(left: 0, top: 0, bottom: 0, width: 4,
                            child: Container(color: _C.magenta)),
                      ],
                      Center(
                        child: Text(
                          _allDecided ? 'CONFIRM & PAY' : 'MARK ALL ITEMS FIRST',
                          style: _T.display(20,
                              color: _allDecided ? _C.white : _C.grey500, spacing: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!_allDecided) ...[
                const SizedBox(height: 8),
                Text(
                  '${_items.where((e) => e.kept == null).length} items still undecided',
                  style: _T.body(11, color: _C.grey500),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── ITEM KEEP / RETURN CARD ──────────────────────────────────────────────
  // Swipe Right (Love): translate+rotate 8deg, heart burst — 300ms spring
  // Swipe Left (Pass): fabric curl, opacity 0 at 60% travel — 280ms
  // Double Tap Wishlist: 2 hearts rise+fade, brand brown/tan, 400ms, 80ms stagger
  Widget _buildItemCard(int index) {
    final item = _items[index];

    Color borderColor = _C.grey150;
    if (item.kept == true)  borderColor = _C.magenta;
    if (item.kept == false) borderColor = _C.grey300;

    final isActive = _activeSwipeIndex == index;
    final dx       = isActive ? _swipeDx : 0.0;
    final rotation = isActive ? (dx / 400.0) * (8 * pi / 180) : 0.0;
    final opacity  = isActive && _swipeDir == _SwipeDir.left
        ? (1.0 - (dx.abs() / 300.0) * 0.4).clamp(0.4, 1.0)
        : 1.0;

    return GestureDetector(
      onHorizontalDragUpdate: item.kept == null
          ? (d) => _onSwipeUpdate(d, index) : null,
      onHorizontalDragEnd: item.kept == null
          ? (d) => _onSwipeEnd(d, index) : null,
      onDoubleTap: () => _triggerWishlist(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Card with swipe transform
          Transform(
            transform: Matrix4.identity()
              ..translate(dx)
              ..rotateZ(rotation),
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: opacity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _C.white,
                  border: Border.all(
                      color: borderColor, width: item.kept != null ? 2 : 1),
                  boxShadow: item.kept == true
                      ? [BoxShadow(
                          color: _C.magenta.withOpacity(0.12),
                          blurRadius: 12, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    // Product image
                    Stack(
                      children: [
                        SizedBox(
                          width: 76, height: 92,
                          child: Image.network(
                            item.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: _C.grey150),
                          ),
                        ),
                        // FOMO flash on image
                        if (_fomoFlashing[index])
                          Positioned.fill(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              color: _C.fomoFlash.withOpacity(0.4),
                            ),
                          ),
                        // Wishlist heart icon
                        if (item.wishListed)
                          const Positioned(
                            top: 4, right: 4,
                            child: Icon(Icons.favorite, size: 14, color: _C.magenta),
                          ),
                      ],
                    ),

                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.brand, style: _T.label(9, color: _C.grey500, spacing: 1)),
                            const SizedBox(height: 2),
                            Text(item.name, style: _T.label(12, color: _C.dark, spacing: 0)),
                            const SizedBox(height: 6),
                            // FOMO scale on price
                            AnimatedScale(
                              scale: _fomoScales[index],
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: Text(item.price,
                                  style: _T.display(18, color: _C.dark, spacing: 0)),
                            ),
                            if (item.kept != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item.kept! ? '✓ Keeping this' : '↩ Returning',
                                  style: _T.label(9,
                                      color: item.kept! ? _C.magenta : _C.grey500,
                                      spacing: 0),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // KEEP / RETURN buttons (spring-arc scale on selection)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          _decisionBtn('KEEP', true, index),
                          const SizedBox(height: 6),
                          _decisionBtn('RETURN', false, index),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Swipe direction hint labels
          if (isActive && dx > 30)
            Positioned(
              top: 10, left: 10,
              child: Opacity(
                opacity: (dx / 120.0).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: _C.magenta,
                  child: Text('KEEP ♥', style: _T.label(10, color: _C.white, spacing: 1)),
                ),
              ),
            ),
          if (isActive && dx < -30)
            Positioned(
              top: 10, right: 10,
              child: Opacity(
                opacity: (dx.abs() / 120.0).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: _C.dark,
                  child: Text('RETURN', style: _T.label(10, color: _C.white, spacing: 1)),
                ),
              ),
            ),

          // Double-tap wishlist hearts — brand brown + tan, rise+fade
          if (_heartsPerItem[index].isNotEmpty)
            ..._heartsPerItem[index].map((h) {
              final ctrl = _heartCtrlPerItem[index];
              if (ctrl == null) return const SizedBox.shrink();
              return AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) {
                  final t = CurvedAnimation(
                    parent: ctrl,
                    curve: Interval(
                      h.delay / 480.0, 1.0,
                      curve: Curves.easeOut,
                    ),
                  ).value;
                  return Positioned(
                    right: 20 + h.dx,
                    bottom: 20 + 60 * t,
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Icon(Icons.favorite, size: 22 + t * 8, color: h.color),
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }

  Widget _decisionBtn(String label, bool keepVal, int index) {
    final selected = _items[index].kept == keepVal;
    return GestureDetector(
      onTap: () => setState(() {
        _items[index].kept = keepVal;
        if (keepVal) _triggerWishlist(index);
      }),
      child: AnimatedScale(
        scale: selected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: _kSpringArc,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: _kSpringArc,
          width: 72, height: 32,
          color: selected ? (keepVal ? _C.magenta : _C.dark) : _C.grey100,
          child: Center(
            child: Text(label,
                style: _T.label(9, color: selected ? _C.white : _C.grey700, spacing: 1)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ETA PULSE DOT
// Spec: green dot scales 1→1.4→1 every 2 seconds, 400ms per pulse, ease-in-out
// ─────────────────────────────────────────────────────────────────────────────
class _EtaPulseDot extends StatefulWidget {
  final AnimationController pulseCtrl;
  const _EtaPulseDot({required this.pulseCtrl});
  @override
  State<_EtaPulseDot> createState() => _EtaPulseDotState();
}

class _EtaPulseDotState extends State<_EtaPulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _intervalCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // 2s interval, 400ms pulse per spec
    _intervalCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
        CurvedAnimation(parent: _intervalCtrl, curve: Curves.easeInOut));

    // Fire every 2 seconds
    Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _intervalCtrl.forward(from: 0).then((_) {
          if (mounted) _intervalCtrl.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _intervalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, __) => Transform.scale(
        scale: _scaleAnim.value,
        child: Container(
          width: 9, height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.green,
            boxShadow: [
              BoxShadow(
                color: _C.green.withOpacity(0.5 * (_scaleAnim.value - 1.0) / 0.4),
                blurRadius: 8, spreadRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FABRIC WAVE INDICATOR  (Logo Loading State)
// Spec: billowing S-curve wave, 1.8s cycle, cubic-bezier(0.37,0,0.63,1), never mechanical
// ─────────────────────────────────────────────────────────────────────────────
class _FabricWaveIndicator extends StatelessWidget {
  final AnimationController controller;
  const _FabricWaveIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        size: const Size(32, 14),
        painter: _FabricWavePainter(
          progress: CurvedAnimation(parent: controller, curve: _kSCurve).value,
        ),
      ),
    );
  }
}

class _FabricWavePainter extends CustomPainter {
  final double progress;
  const _FabricWavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.white.withOpacity(0.65)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const segments = 40;
    for (int i = 0; i <= segments; i++) {
      final t  = i / segments;
      final x  = size.width * t;
      // S-curve wave: sin with phase shift
      final y  = size.height / 2 +
          sin((t * 2 * pi) + (progress * 2 * pi)) * size.height * 0.4 +
          sin((t * 4 * pi) + (progress * 4 * pi)) * size.height * 0.15;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FabricWavePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// DARK MAP PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _DarkMapPainter extends CustomPainter {
  final double riderProgress;
  final double dotPulse;
  const _DarkMapPainter({required this.riderProgress, required this.dotPulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _C.mapBg);

    final grid = Paint()..color = _C.mapGrid..strokeWidth = 1.2;
    for (double x = 0; x <= w; x += 38) canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    for (double y = 0; y <= h; y += 38) canvas.drawLine(Offset(0, y), Offset(w, y), grid);

    final road = Paint()..color = _C.mapRoad.withOpacity(0.55)..strokeWidth = 7;
    canvas.drawLine(Offset(0, h * 0.38), Offset(w, h * 0.38), road);
    canvas.drawLine(Offset(w * 0.48, 0), Offset(w * 0.48, h), road);
    canvas.drawLine(Offset(0, h * 0.66), Offset(w * 0.72, h * 0.66), road);
    canvas.drawLine(Offset(w * 0.22, 0), Offset(w * 0.22, h * 0.66), road);

    const destX = 0.72, destY = 0.30;
    final pin = Paint()..color = const Color(0xFF8B4513);
    canvas.drawCircle(Offset(w * destX, h * destY), 12, pin);
    canvas.drawCircle(Offset(w * destX, h * destY), 7,
        Paint()..color = const Color(0xFFFFE0B2));
    final pinPath = Path()
      ..moveTo(w * destX - 6, h * destY + 8)
      ..lineTo(w * destX,     h * destY + 20)
      ..lineTo(w * destX + 6, h * destY + 8)
      ..close();
    canvas.drawPath(pinPath, pin);

    canvas.drawCircle(Offset(w * 0.12, h * 0.74), 8, Paint()..color = _C.magenta);
    canvas.drawCircle(Offset(w * 0.12, h * 0.74), 4, Paint()..color = _C.white);

    final t  = (riderProgress * 0.4).clamp(0.0, 1.0) / 0.4;
    final rx = w * 0.12 + (w * 0.72 - w * 0.12) * t * 0.7;
    final ry = h * 0.74 + (h * 0.30 - h * 0.74) * t * 0.7;

    // Pulse ring (ETA pulse spec: scale effect)
    canvas.drawCircle(Offset(rx, ry), 16 + dotPulse * 6,
        Paint()..color = _C.magenta.withOpacity(0.22 * (1 - dotPulse)));
    canvas.drawCircle(Offset(rx, ry), 10, Paint()..color = _C.magenta);
    canvas.drawCircle(Offset(rx, ry), 5,  Paint()..color = _C.white);

    final routePaint = Paint()
      ..color = _C.magenta.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final routePath = Path()
      ..moveTo(w * 0.12, h * 0.74)
      ..lineTo(w * 0.48, h * 0.74)
      ..lineTo(w * 0.48, h * 0.38)
      ..lineTo(w * 0.72, h * 0.38)
      ..lineTo(w * 0.72, h * 0.30);

    for (final metric in routePath.computeMetrics()) {
      final fullLen = metric.length;
      for (double start = 0; start < fullLen; start += 12) {
        final seg = metric.extractPath(start, min(start + 6, fullLen));
        canvas.drawPath(seg, routePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_DarkMapPainter old) =>
      old.riderProgress != riderProgress || old.dotPulse != dotPulse;
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTDOWN RING  — Linear depletion per spec (no easing on this one)
// ─────────────────────────────────────────────────────────────────────────────
class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final Color  ringColor;
  const _CountdownRingPainter({required this.progress, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    // Track
    canvas.drawCircle(center, radius,
        Paint()
          ..color = _C.grey150
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14);

    // Depleting arc — clockwise, LINEAR (no easing per spec)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// RING TICK MARKS (separate so they don't obscure the arc)
// ─────────────────────────────────────────────────────────────────────────────
class _RingTickPainter extends CustomPainter {
  final double progress;
  final Color  ringColor;
  const _RingTickPainter({required this.progress, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    final tickPaint = Paint()
      ..color = _C.grey300
      ..strokeWidth = 1.5;
    for (int i = 0; i < 15; i++) {
      final angle = -pi / 2 + (2 * pi * i / 15);
      final inner = center + Offset(cos(angle), sin(angle)) * (radius - 10);
      final outer = center + Offset(cos(angle), sin(angle)) * (radius + 10);
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_RingTickPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// GRAIN PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _GrainPainter extends CustomPainter {
  final double seed;
  const _GrainPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = Random((seed * 1000).toInt());
    final paint = Paint()..color = Colors.white.withOpacity(0.025);
    for (int i = 0; i < 280; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.85, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter _) => false;
}