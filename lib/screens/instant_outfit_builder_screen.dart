import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sku_catalog.dart'; // ── SKU ── catalogue + CartPayload
import 'package:instastyle/services/cart_service.dart';
import 'sku_variant_picker.dart';
// ═══════════════════════════════════════════════════════════════════════════
// SKU INTEGRATION (additive — NO UI/UX change)
// Resolves a catalogue parentId to a concrete child-variant CartPayload using
// the first in-stock variant as the silent default selection (no picker shown,
// so the existing flow is untouched). The screen's own displayed price is kept
// as the unit price so nothing visible changes. Falls back to a synthesized
// payload when the parent isn't in SkuCatalog yet.
// ═══════════════════════════════════════════════════════════════════════════
CartPayload _skuPayloadFor({
  required String? parentId,
  required String name,
  required String brand,
  required int unitPriceInPaise,
  required String imageUrl,
  int quantity = 1,
}) {
  // ── Try to resolve from real catalog ──────────────────────────────────────
  if (parentId != null) {
    final parent = SkuCatalog.get(parentId);
    if (parent != null && parent.variantMap.isNotEmpty) {

      // Pick first in-stock variant; fall back to very first if all OOS
      ProductVariant? picked;
      for (final v in parent.variantMap.values) {
        if (v.inStock) { picked = v; break; }
      }
      picked ??= parent.variantMap.values.first; // graceful OOS fallback

      return SkuCatalog.buildCartPayload(
        parent  : parent,
        variant : picked,
        quantity: quantity,
      );
      // NOTE: unitPriceInPaise from the screen is intentionally ignored here
      // because the variant carries its own authoritative priceInPaise.
      // The displayed price on screen is cosmetic; backend always uses variant price.
    }
  }

  // ── Fallback: parentId missing or not in catalog yet ──────────────────────
  // Synthesizes a CartPayload so the screen never crashes during development.
  return CartPayload(
    parentId         : parentId ?? name,
    variantSku       : '${parentId ?? 'SKU'}-DEFAULT',
    productName      : name,
    brand            : brand,
    size             : 'One Size',
    colorName        : '—',
    colorHex         : '#888888',
    quantity         : quantity,
    unitPriceInPaise : unitPriceInPaise,
    imageUrl         : imageUrl,
  );
}
// ─── DESIGN TOKENS ────────────────────────────────────────────────────────────
class _C {
  static const white   = Color(0xFFFFFFFF);
  static const bg      = Color(0xFFFFFFFF);
  static const cardBg  = Color(0xFFF2F2F2);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey150 = Color(0xFFEEEEEE);
  static const grey300 = Color(0xFFCCCCCC);
  static const grey500 = Color(0xFF999999);
  static const grey700 = Color(0xFF555555);
  static const dark    = Color(0xFF0D0D0D);
  static const magenta = Color(0xFFE91E8C);
  static const sale    = Color(0xFFE53935);
  static const green   = Color(0xFF4CAF50);
  static const fomoFlash = Color(0xFFC0392B); // FOMO price flash colour
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
          fontSize: size,
          fontWeight: fw,
          color: color,
          letterSpacing: spacing);

  static TextStyle body(double size,
          {Color color = _C.grey700, FontWeight fw = FontWeight.w400}) =>
      GoogleFonts.jost(fontSize: size, fontWeight: fw, color: color);

  static TextStyle mono(double size,
          {Color color = _C.dark, FontWeight fw = FontWeight.w500}) =>
      GoogleFonts.robotoMono(fontSize: size, fontWeight: fw, color: color);
}

// ─── CUBIC BEZIER CURVES (from spec) ─────────────────────────────────────────
// Outfit Builder Reveal spring: cubic-bezier(0.34, 1.56, 0.64, 1)
class _Curves {
  static const springBounce = Cubic(0.34, 1.56, 0.64, 1);
  // Page transitions / swap carousel: cubic-bezier(0.25, 0.46, 0.45, 0.94) — fabric ease
  static const fabricEase   = Cubic(0.25, 0.46, 0.45, 0.94);
  // Logo loading wave: cubic-bezier(0.37, 0, 0.63, 1) — S-curve
  static const sCurve       = Cubic(0.37, 0.0, 0.63, 1.0);
  // Add to Cart / CTA arc: cubic-bezier(0.34, 1.56, 0.64, 1) same spring
  static const cartArc      = Cubic(0.34, 1.56, 0.64, 1);
}

// ─── ENUMS & MODELS ───────────────────────────────────────────────────────────
enum _Phase { occasion, persona, loading, reveal }

class _Occasion {
  final String label;
  final IconData icon;
  final Color tint;
  const _Occasion(this.label, this.icon, this.tint);
}

class _Persona {
  final String label;
  final String sub;
  final String imageUrl;
  const _Persona(this.label, this.sub, this.imageUrl);
}

class _OutfitItem {
  final String slot;
  final String name;
  final String brand;
  final String price;
  final int priceInt;
  final String imageUrl;
  final List<_AltItem> alternatives;
  final String? parentId; // ── SKU ── links this slot to SkuCatalog (optional)
  const _OutfitItem({
    required this.slot,
    required this.name,
    required this.brand,
    required this.price,
    required this.priceInt,
    required this.imageUrl,
    required this.alternatives,
    this.parentId, // ── SKU ──
  });
}

class _AltItem {
  final String name;
  final String price;
  final String imageUrl;
  const _AltItem(this.name, this.price, this.imageUrl);
}

// ─── DATA ─────────────────────────────────────────────────────────────────────
const _occasions = [
  _Occasion('WEDDING\nGUEST', Icons.celebration_outlined, Color(0xFFAD1457)),
  _Occasion('FIRST\nDATE',    Icons.favorite_outline,     Color(0xFFE91E8C)),
  _Occasion('OFFICE',         Icons.work_outline,          Color(0xFF37474F)),
  _Occasion('NIGHT\nOUT',    Icons.nightlife_outlined,    Color(0xFF4A148C)),
  _Occasion('FESTIVAL',       Icons.music_note_outlined,   Color(0xFFFF6F00)),
  _Occasion('CASUAL',         Icons.wb_sunny_outlined,     Color(0xFF00838F)),
];

const _personas = [
  _Persona(
    'CLASSIC',
    'Timeless & refined',
    'https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=600&q=85',
  ),
  _Persona(
    'BOLD',
    'Make a statement',
    'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=600&q=85',
  ),
  _Persona(
    'MINIMAL',
    'Clean & effortless',
    'https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=600&q=85',
  ),
];

final _outfitItems = [
  _OutfitItem(
    slot: 'TOP',
    name: 'Silk Wrap Blouse',
    brand: 'ATELIER SUR',
    price: '₹4,200',
    priceInt: 4200,
    parentId: 'PBL-AS', // ── SKU ──
    imageUrl:
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=300&q=85',
    alternatives: const [
      _AltItem('Elegant Lace Gown',   '₹4,800',
          'https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=300&q=85'),
      _AltItem('Royal Evening Dress', '₹5,600',
          'https://images.unsplash.com/photo-1618244972963-dbee1a7edc95?w=300&q=85'),
      _AltItem('Classic Purple Maxi', '₹3,900',
          'https://images.unsplash.com/photo-1554568218-0f1715e72254?w=300&q=85'),
    ],
  ),
  _OutfitItem(
    slot: 'BOTTOM',
    name: 'High-waist Palazzo',
    brand: 'INDIRA & CO',
    price: '₹3,800',
    priceInt: 3800,
    parentId: 'VKT-IC', // ── SKU ──
    imageUrl:
        'https://images.unsplash.com/photo-1506629082955-511b1aa562c8?w=400&q=85',
    alternatives: const [
      _AltItem('Midi Skirt',      '₹2,999',
          'https://images.unsplash.com/photo-1583496661160-fb5886a0aaaa?w=300&q=85'),
      _AltItem('Flared Jeans',    '₹3,200',
          'https://images.unsplash.com/photo-1604176354204-9268737828e4?w=300&q=85'),
      _AltItem('Cigarette Pants', '₹2,700',
          'https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?w=300&q=85'),
    ],
  ),
  _OutfitItem(
    slot: 'SHOES',
    name: 'Block Heel Mules',
    brand: 'CASA MODAS',
    price: '₹6,500',
    priceInt: 6500,
    parentId: 'COS-CM', // ── SKU ──
    imageUrl:
        'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400&q=85',
    alternatives: const [
      _AltItem('Strappy Sandals', '₹4,200',
          'https://images.unsplash.com/photo-1603487742131-4160ec999306?w=300&q=85'),
      _AltItem('White Sneakers',  '₹3,500',
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=300&q=85'),
      _AltItem('Ballet Flats',    '₹2,800',
          'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=300&q=85'),
    ],
  ),
  _OutfitItem(
    slot: 'ACCESSORY',
    name: 'Structured Mini Bag',
    brand: 'DECO NOIR',
    price: '₹8,900',
    priceInt: 8900,
    parentId: 'STJ-DN', // ── SKU ──
    imageUrl:
        'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&q=85',
    alternatives: const [
      _AltItem('Canvas Tote',  '₹3,999',
          'https://images.unsplash.com/photo-1591561954557-26941169b49e?w=300&q=85'),
      _AltItem('Clutch Purse', '₹5,200',
          'https://images.unsplash.com/photo-1566150905458-1bf1fc113f0d?w=300&q=85'),
      _AltItem('Crossbody',    '₹4,700',
          'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=300&q=85'),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class InstantOutfitBuilderScreen extends StatefulWidget {
  const InstantOutfitBuilderScreen({super.key});
  @override
  State<InstantOutfitBuilderScreen> createState() =>
      _InstantOutfitBuilderScreenState();
}

class _InstantOutfitBuilderScreenState
    extends State<InstantOutfitBuilderScreen> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.occasion;
  int _selectedOccasion = -1;
  int _selectedPersona  = -1;
  int? _swappingIndex;
  List<_OutfitItem> _items = [];

  // ── SKU cart (additive) — resolved CartPayloads for the complete look ──────
  // Populated when ORDER COMPLETE LOOK is tapped. No widget/layout impact.
  final List<CartPayload> _skuCart = [];

  // FOMO price flash state
  bool _priceFlashing = false;
  Color _priceColor = _C.dark;

  // CTA button pressed scale
  bool _ctaPressed = false;

  // ── Controllers ────────────────────────────────────────────────────────────

  // Loading: fabric wave — S-curve (1.8 s per spec)
  late final AnimationController _waveCtrl;
  // Loading: grain pulse
  late final AnimationController _grainCtrl;

  // Reveal: 4 staggered slide-up — springBounce, 360ms, 80ms stagger
  late final List<AnimationController> _revealCtrls;
  late final List<Animation<Offset>>   _revealSlides;
  late final List<Animation<double>>   _revealFades;

  // Price counter (FOMO: ease-in-out, 200ms scale)
  late final AnimationController _priceCtrl;
  late final AnimationController _priceScaleCtrl; // 200ms ease-in-out scale

  // ETA Pulse — 2s interval, 400ms per pulse, ease-in-out
  late final AnimationController _dotCtrl;

  // Swap carousel — fabricEase 320ms (page transition spec)
  late final AnimationController _swapCtrl;

  

  // CTA button — Add to Cart spec: 240ms scale 1→1.04→1, springBounce
  late final AnimationController _ctaScaleCtrl;
  late final Animation<double>   _ctaScale;

  @override
void initState() {
  super.initState();

  _items = List.from(_outfitItems);

  // Loading wave
  _waveCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  // Grain pulse
  _grainCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  // Reveal animations
  _revealCtrls = List.generate(
    4,
    (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    ),
  );

  _revealSlides = _revealCtrls.map(
    (c) {
      return Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: c,
          curve: _Curves.springBounce,
        ),
      );
    },
  ).toList();

  _revealFades = _revealCtrls.map(
    (c) {
      return CurvedAnimation(
        parent: c,
        curve: Curves.easeOut,
      );
    },
  ).toList();

  // Price animation
  _priceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  _priceScaleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _priceScaleCtrl.reverse();
      }
    });

  // ETA pulse
  _dotCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..addStatusListener((s) async {

      if (s == AnimationStatus.completed) {

        await Future.delayed(
          const Duration(milliseconds: 1600),
        );

        if (mounted) {
          _dotCtrl.reverse();
        }

      } else if (s == AnimationStatus.dismissed) {

        await Future.delayed(
          const Duration(milliseconds: 1600),
        );

        if (mounted) {
          _dotCtrl.forward();
        }
      }
    });

  _dotCtrl.forward();

  // Swap animation
  _swapCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  // CTA scale
  _ctaScaleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..addStatusListener((s) {

      if (s == AnimationStatus.completed) {
        _ctaScaleCtrl.reverse();

        setState(() {
          _ctaPressed = false;
        });
      }
    });

  _ctaScale = Tween<double>(
    begin: 1.0,
    end: 1.04,
  ).animate(
    CurvedAnimation(
      parent: _ctaScaleCtrl,
      curve: _Curves.cartArc,
    ),
  );
}

  @override
void dispose() {

  _waveCtrl.dispose();
  _grainCtrl.dispose();

  for (final c in _revealCtrls) {
    c.dispose();
  }

  _priceCtrl.dispose();
  _priceScaleCtrl.dispose();

  _dotCtrl.dispose();

  _swapCtrl.dispose();

  _ctaScaleCtrl.dispose();

  super.dispose();
}

  // ── SKU ── Build the resolved SKU cart for the complete look ───────────────
  // Called by the (previously placeholder) ORDER COMPLETE LOOK action. Backend
  // only — no widget, layout, animation, or navigation changes.
  Future<void> _orderCompleteLook() async {
  _skuCart
    ..clear()
    ..addAll(_items.map((it) => _skuPayloadFor(
          parentId         : it.parentId,
          name             : it.name,
          brand            : it.brand,
          unitPriceInPaise : it.priceInt * 100,
          imageUrl         : it.imageUrl,
        )));

  for (final p in _skuCart) {
    debugPrint('🧾 Outfit order → SKU ${p.variantSku}  '
        '${p.size}/${p.colorName}  qty ${p.quantity}');
  }

  try {
    await CartService.instance.addItems(_skuCart);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_skuCart.length} items added to cart!',
          style: _T.label(13, color: _C.white),
        ),
        backgroundColor: _C.magenta,
        duration: const Duration(seconds: 2),
      ),
    );
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

  // ── Navigation Helpers ─────────────────────────────────────────────────────
  void _selectOccasion(int i) {
    setState(() => _selectedOccasion = i);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.persona);
      
    });
  }

  Future<void> _selectPersona(int i) async {
    setState(() {
      _selectedPersona = i;
      _phase = _Phase.loading;
    });
    

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    setState(() => _phase = _Phase.reveal);
    

    // Staggered reveal — 80ms between cards, 360ms springBounce (spec)
    for (int j = 0; j < 4; j++) {
      if (j > 0) await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) _revealCtrls[j].forward();
    }

    // Price build + FOMO flash after full reveal
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      _priceCtrl.forward();
      _triggerPriceFlash();
    }
  }

  /// FOMO Stock Update spec: 150ms flash (#C0392B), 200ms scale ease-in-out
  Future<void> _triggerPriceFlash() async {
    setState(() {
      _priceFlashing = true;
      _priceColor = _C.fomoFlash;
    });
    _priceScaleCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      setState(() {
        _priceFlashing = false;
        _priceColor = _C.magenta; // active during build
      });
    }
    // After price fully built, switch to dark
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => _priceColor = _C.dark);
    }
  }

  void _handleBack() {
    if (_swappingIndex != null) {
      setState(() => _swappingIndex = null);
      _swapCtrl.reverse();
      return;
    }
    switch (_phase) {
      case _Phase.persona:
        setState(() => _phase = _Phase.occasion);
       
      case _Phase.reveal:
        setState(() {
          _phase = _Phase.occasion;
          _selectedOccasion = -1;
          _selectedPersona  = -1;
          _swappingIndex    = null;
          _items = List.from(_outfitItems);
          for (final c in _revealCtrls) c.reset();
          _priceCtrl.reset();
          _priceScaleCtrl.reset();
        });
      
      default:
        Navigator.pop(context);
    }
  }

  void _tapItem(int index) {
    if (_swappingIndex == index) {
      setState(() => _swappingIndex = null);
      _swapCtrl.reverse();
    } else {
      setState(() => _swappingIndex = index);
      _swapCtrl.forward(from: 0);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_phase == _Phase.loading) _buildLoadingOverlay(),
          if (_phase == _Phase.reveal)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildStickyBottom(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final titles = {
      _Phase.occasion: 'SELECT AN OCCASION',
      _Phase.persona:  'YOUR STYLE PERSONA',
      _Phase.loading:  'BUILDING YOUR LOOK',
      _Phase.reveal:   'YOUR COMPLETE LOOK',
    };
    final subs = {
      _Phase.occasion: 'InstaStyle builds the complete look. Delivered in minutes.',
      _Phase.persona:  'Full-bleed picks — choose your vibe.',
      _Phase.loading:  'AI curation in progress...',
      _Phase.reveal:   'Tap any item to swap. Delivered in minutes.',
    };

    return Container(
      color: _C.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _handleBack,
                child: Container(
                  width: 36, height: 36,
                  color: _C.grey100,
                  child: const Icon(Icons.arrow_back, size: 20, color: _C.dark),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titles[_phase]!, style: _T.display(22, spacing: 1.5)),
                    Text(subs[_phase]!,   style: _T.body(11, color: _C.grey500)),
                  ],
                ),
              ),
              if (_phase != _Phase.loading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: _phase == _Phase.reveal ? _C.magenta : _C.grey100,
                  child: Text(
                    _phase == _Phase.occasion
                        ? 'STEP 1'
                        : _phase == _Phase.persona
                            ? 'STEP 2'
                            : 'READY',
                    style: _T.label(10,
                        color: _phase == _Phase.reveal ? _C.white : _C.grey700,
                        spacing: 1),
                  ),
                ),
            ],
          ),
          if (_phase != _Phase.loading) ...[
            const SizedBox(height: 12),
            Row(
              children: List.generate(2, (i) {
                final done = _phase == _Phase.reveal ||
                    (_phase == _Phase.persona && i == 0);
                final active = (_phase == _Phase.occasion && i == 0) ||
                    (_phase == _Phase.persona && i == 1) ||
                    (_phase == _Phase.reveal && i <= 1);
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 0 ? 4 : 0),
                    height: 2,
                    color: active || done ? _C.magenta : _C.grey150,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BODY DISPATCHER — wrapped in page slide transition
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBody() {

  switch (_phase) {

    case _Phase.occasion:
      return _buildOccasionSelector();

    case _Phase.persona:
      return _buildPersonaSelector();

    case _Phase.loading:
      return const SizedBox.expand();

    case _Phase.reveal:
      return _buildOutfitReveal();
  }
}

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — OCCASION SELECTOR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOccasionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _occasions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final occ    = _occasions[i];
              final active = _selectedOccasion == i;
              return GestureDetector(
                onTap: () => _selectOccasion(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: active ? _C.magenta : _C.grey100,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                        color: active ? _C.magenta : _C.grey150, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(occ.icon,
                          size: 16,
                          color: active ? _C.white : _C.grey700),
                      const SizedBox(width: 8),
                      Text(
                        occ.label.replaceAll('\n', ' '),
                        style: _T.label(11,
                            color: active ? _C.white : _C.dark, spacing: 0.5),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.99,
            ),
            itemCount: _occasions.length,
            itemBuilder: (_, i) {
              final occ    = _occasions[i];
              final active = _selectedOccasion == i;
              return GestureDetector(
                onTap: () => _selectOccasion(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  transform: Matrix4.identity()
                    ..scale(active ? 0.97 : 1.0),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? _C.dark : _C.grey100,
                    border: Border.all(
                        color: active ? _C.magenta : _C.grey150,
                        width: active ? 2 : 1),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GridPatternPainter(
                            color: active
                                ? _C.magenta.withOpacity(0.08)
                                : occ.tint.withOpacity(0.06),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(occ.icon,
                                size: 26,
                                color: active ? _C.magenta : occ.tint),
                            Text(occ.label,
                                style: _T.display(18,
                                    color: active ? _C.white : _C.dark,
                                    spacing: 0.5)),
                          ],
                        ),
                      ),
                      if (active)
                        Positioned(
                          top: 10, right: 10,
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                                color: _C.magenta, shape: BoxShape.circle),
                            child: const Icon(Icons.check,
                                size: 12, color: _C.white),
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — STYLE PERSONA
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPersonaSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: List.generate(_personas.length, (i) {
          final p      = _personas[i];
          final active = _selectedPersona == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectPersona(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                transform: Matrix4.identity()..scale(active ? 1.02 : 1.0),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: active ? _C.magenta : Colors.transparent,
                      width: 3),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(p.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: _C.grey150)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.78),
                          ],
                          stops: const [0.35, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 14, left: 0, right: 0,
                      child: Column(
                        children: [
                          Text(p.label,
                              style: _T.display(20,
                                  color: _C.white, spacing: 1),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(p.sub,
                                style: _T.body(9,
                                    color: const Color(0xBBFFFFFF)),
                                textAlign: TextAlign.center,
                                maxLines: 2),
                          ),
                        ],
                      ),
                    ),
                    if (active)
                      Positioned(
                        top: 10, right: 10,
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                              color: _C.magenta, shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              size: 13, color: _C.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — AI CURATION LOADING
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: _C.dark,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Grain overlay — pulsing (S-curve)
            AnimatedBuilder(
              animation: _grainCtrl,
              builder: (_, __) => CustomPaint(
                painter: _GrainPainter(_grainCtrl.value),
              ),
            ),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fabric wave — S-curve, 1.8 s (Logo Loading State spec)
                  AnimatedBuilder(
                    animation: _waveCtrl,
                    builder: (_, __) => SizedBox(
                      width: 160, height: 90,
                      child: CustomPaint(
                        painter: _FabricWavePainter(
                          _waveCtrl.value,
                          curve: _Curves.sCurve,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text('INSTASTYLE',
                      style: _T.display(38, color: _C.white, spacing: 5)),
                  const SizedBox(height: 10),
                  Text('is building your look…',
                      style: _T.body(15, color: _C.grey500)),
                  const SizedBox(height: 28),

                  // Animated pills (S-curve easing for expand)
                  AnimatedBuilder(
                    animation: _waveCtrl,
                    builder: (_, __) {
                      final active = (_waveCtrl.value * 3).floor() % 3;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (j) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: active == j ? 22 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: active == j
                                  ? _C.magenta
                                  : const Color(0xFF444444),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 4 — OUTFIT SET REVEAL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOutfitReveal() {
    final total = _items.fold<int>(0, (s, item) => s + item.priceInt);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 148),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORDER SUMMARY',
                          style: _T.display(26, spacing: 1)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _chipTag(
                            _occasions[_selectedOccasion < 0
                                    ? 0
                                    : _selectedOccasion]
                                .label
                                .replaceAll('\n', ' '),
                            _C.grey100, _C.grey700,
                          ),
                          const SizedBox(width: 6),
                          _chipTag(
                            _personas[_selectedPersona < 0
                                    ? 0
                                    : _selectedPersona]
                                .label,
                            _C.magenta.withOpacity(0.1), _C.magenta,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── FOMO price counter: scale 1→1.15→1, 200ms, ease-in-out ──
                AnimatedBuilder(
                  animation: Listenable.merge([_priceCtrl, _priceScaleCtrl]),
                  builder: (_, __) {
                    final live = (total * _priceCtrl.value).toInt();
                    // Scale: 1→1.15 via ease-in-out 200ms
                    final scaleVal = 1.0 +
                        0.15 *
                            CurvedAnimation(
                                    parent: _priceScaleCtrl,
                                    curve: Curves.easeInOut)
                                .value;
                    return Transform.scale(
                      scale: scaleVal,
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('TOTAL',
                              style:
                                  _T.label(9, color: _C.grey500, spacing: 1)),
                          Text(
                            '₹${_formatPrice(live)}',
                            style: _T.display(26,
                                color: _priceFlashing
                                    ? _C.fomoFlash
                                    : _priceColor,
                                spacing: 0),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 4 cards: springBounce, 360ms, 80ms stagger ────────────────────
          ...List.generate(_items.length, (i) {
            return SlideTransition(
              position: _revealSlides[i],
              child: FadeTransition(
                opacity: _revealFades[i],
                child: _buildItemCard(i),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chipTag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: bg,
      child: Text(label, style: _T.label(10, color: fg, spacing: 0.5)),
    );
  }

  String _formatPrice(int v) {
    final s = v.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 5 — INDIVIDUAL SWAP CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildItemCard(int index) {
  final item     = _items[index];
  final swapping = _swappingIndex == index;

  return Column(
    children: [
      // ── Card ──────────────────────────────────────────────────────────────
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        transform: Matrix4.identity()..scale(swapping ? 1.04 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: _C.white,
          border: Border.all(
              color: swapping ? _C.magenta : _C.grey150,
              width: swapping ? 2 : 1),
          boxShadow: swapping
              ? [BoxShadow(
                  color: _C.magenta.withOpacity(0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )]
              : [],
        ),
        child: Row(
          children: [
            // ── LEFT: image + text — tap to toggle swap carousel ────────────
            GestureDetector(
              onTap: () => _tapItem(index),
              child: Row(
                children: [
                  SizedBox(
                    width: 92, height: 108,
                    child: Image.network(item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: _C.grey150)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            color: _C.grey100,
                            child: Text(item.slot,
                                style: _T.label(9,
                                    color: _C.grey700, spacing: 1.5)),
                          ),
                          const SizedBox(height: 6),
                          Text(item.brand,
                              style: _T.label(10,
                                  color: _C.grey500, spacing: 1)),
                          const SizedBox(height: 2),
                          Text(item.name,
                              style: _T.label(13,
                                  color: _C.dark, spacing: 0),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text(item.price,
                              style: _T.display(20,
                                  color: _C.dark, spacing: 0)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── RIGHT: SWAP + SIZE buttons — independent taps ────────────────
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // SWAP
                  GestureDetector(
                    onTap: () => _tapItem(index),
                    child: Column(
                      children: [
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: swapping ? 0.5 : 0,
                          child: Icon(Icons.swap_vert,
                              size: 20,
                              color: swapping ? _C.magenta : _C.grey300),
                        ),
                        const SizedBox(height: 2),
                        Text('SWAP',
                            style: _T.label(8,
                                color: swapping ? _C.magenta : _C.grey300,
                                spacing: 1)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // SIZE
                  GestureDetector(
                    onTap: () {
                      final parent = SkuCatalog.get(item.parentId ?? '');
                      if (parent == null) return;
                      VariantPickerSheet.show(
                        context,
                        parent: parent,
                        onAddToCart: (CartPayload payload) async {
                          try {
                            await CartService.instance.addItem(payload);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                '${payload.productName} · ${payload.size} added!',
                                style: _T.label(13, color: _C.white),
                              ),
                              backgroundColor: _C.magenta,
                              duration: const Duration(seconds: 2),
                            ));
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed to add to cart',
                                  style: _T.label(13, color: _C.white)),
                              backgroundColor: _C.sale,
                            ));
                          }
                        },
                      );
                    },
                    child: Column(
                      children: [
                        Icon(Icons.straighten_outlined,
                            size: 18,
                            color: item.parentId != null
                                ? _C.magenta
                                : _C.grey300),
                        const SizedBox(height: 2),
                        Text('SIZE',
                            style: _T.label(8,
                                color: item.parentId != null
                                    ? _C.magenta
                                    : _C.grey300,
                                spacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Alternatives carousel ─────────────────────────────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: _Curves.fabricEase,
        child: swapping
            ? _buildAlternativesCarousel(index)
            : const SizedBox.shrink(),
      ),
    ],
  );
}

  Widget _buildAlternativesCarousel(int itemIndex) {
    final alts = _items[itemIndex].alternatives;
    return SlideTransition(
      // fabricEase 320ms — Page Transitions spec
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
          CurvedAnimation(parent: _swapCtrl, curve: _Curves.fabricEase)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.grey100,
          border: Border.all(color: _C.grey150),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('3 ALTERNATIVES',
                    style: _T.label(10, color: _C.grey500, spacing: 1.5)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _swappingIndex = null);
                    _swapCtrl.reverse();
                  },
                  child: const Icon(Icons.close, size: 16, color: _C.grey500),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: alts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final alt = alts[i];
                  return GestureDetector(
                    onTap: () {
                      final updated = _OutfitItem(
                        slot: _items[itemIndex].slot,
                        name: alt.name,
                        brand: _items[itemIndex].brand,
                        price: alt.price,
                        priceInt: int.parse(
                            alt.price.replaceAll(RegExp(r'[₹,]'), '')),
                        imageUrl: alt.imageUrl,
                        alternatives: _items[itemIndex].alternatives,
                        parentId: _items[itemIndex].parentId, // ── SKU ── carry parent through swap
                      );
                      setState(() {
                        _items[itemIndex] = updated;
                        _swappingIndex = null;
                      });
                      _swapCtrl.reverse();
                      // Rebuild price + FOMO flash
                      _priceCtrl.reset();
                      _priceCtrl.forward();
                      _triggerPriceFlash();
                    },
                    child: SizedBox(
                      width: 105,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(alt.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: _C.grey150)),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    color: _C.dark.withOpacity(0.85),
                                    child: Center(
                                      child: Text('SELECT',
                                          style: _T.label(8,
                                              color: _C.white, spacing: 1)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(alt.name,
                              style: _T.label(9,
                                  color: _C.dark, spacing: 0),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(alt.price,
                              style: _T.label(10,
                                  color: _C.magenta, spacing: 0)),
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

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 6 — DELIVERY PROMISE + STEP 7 — ORDER CTA
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStickyBottom() {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        border: Border(
            top: BorderSide(color: _C.grey150.withOpacity(0.8), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 10,
        left: 16, right: 16, top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── ETA Pulse: 2s interval, 400ms pulse, ease-in-out ─────────────
          Row(
            children: [
              AnimatedBuilder(
                animation: _dotCtrl,
                builder: (_, __) {
                  // ease-in-out pulse per spec
                  final t = CurvedAnimation(
                          parent: _dotCtrl, curve: Curves.easeInOut)
                      .value;
                  return Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                          _C.green, _C.green.withOpacity(0.25), t),
                      boxShadow: [
                        BoxShadow(
                          color: _C.green.withOpacity(0.4 * (1 - t)),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text('Complete outfit in 18 min',
                  style: _T.mono(12, color: _C.dark)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                color: const Color(0xFFE8F5E9),
                child: Text('LIVE',
                    style: _T.label(9, color: _C.green, spacing: 1)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── CTA: Add to Cart spec — 240ms scale 1→1.04→1, springBounce ───
          GestureDetector(
            onTapDown: (_) {
              setState(() => _ctaPressed = true);
              _ctaScaleCtrl.forward(from: 0);
            },
            onTapCancel: () {
              setState(() => _ctaPressed = false);
              _ctaScaleCtrl.reverse();
            },
            onTap: () async {
              await _orderCompleteLook();
            },
            child: ScaleTransition(
              scale: _ctaScale,
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
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(painter: _GrainPainter(0.42)),
                    ),
                    Positioned(
                      left: 0, top: 0, bottom: 0, width: 4,
                      child: Container(color: _C.magenta),
                    ),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ORDER COMPLETE LOOK',
                              style: _T.display(21,
                                  color: _C.white, spacing: 2.5)),
                          const SizedBox(width: 14),
                          const Icon(Icons.arrow_forward,
                              size: 18, color: _C.magenta),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _GridPatternPainter extends CustomPainter {
  final Color color;
  const _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.8;
    const spacing = 16.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPatternPainter old) => old.color != color;
}

/// Fabric wave — now accepts a Curve so the loading screen uses S-curve
/// per Logo Loading State spec: cubic-bezier(0.37, 0, 0.63, 1)
class _FabricWavePainter extends CustomPainter {
  final double progress; // raw 0–1 from AnimationController
  final Curve curve;
  _FabricWavePainter(this.progress, {this.curve = Curves.linear});

  @override
  void paint(Canvas canvas, Size size) {
    // Apply S-curve to smooth out the wave phase advance
    final easedProgress = curve.transform(progress);

    for (int row = 0; row < 5; row++) {
      final frac    = row / 4;
      final baseY   = size.height * frac + size.height / 10;
      final amp     = 10.0 - row * 1.5;
      final phase   = easedProgress * 2 * pi + row * pi / 3;
      final opacity = 1.0 - row * 0.15;

      final paint = Paint()
        ..color = const Color(0xFFE91E8C).withOpacity(opacity)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(0, baseY);
      for (double x = 0; x <= size.width; x++) {
        final y = baseY + sin((x / size.width * 2 * pi) + phase) * amp;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FabricWavePainter old) =>
      old.progress != progress || old.curve != curve;
}

class _GrainPainter extends CustomPainter {
  final double seed;
  const _GrainPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = Random((seed * 1000).toInt());
    final paint = Paint()..color = Colors.white.withOpacity(0.028);
    for (int i = 0; i < 300; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width,
            rng.nextDouble() * size.height),
        0.9,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.seed != seed;
}