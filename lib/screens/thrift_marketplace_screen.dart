// thrift_marketplace_screen.dart  —  SKU variation system integrated
//
// WHAT CHANGED vs the original:
// 1. _ThriftProduct now carries parentId  (links to SkuCatalog)
// 2. Tapping any card calls _openVariantPicker(parentId)
//    which opens VariantPickerSheet → user picks Size × Color
//    → CartPayload with the child-variant SKU is stored in _cartItems
// 3. A cart FAB / badge is shown when items exist
// 4. The existing SKU string display is KEPT (the Firestore sku field is still
//    shown as the "listing SKU" inside the card — different from the
//    child-variant SKU that travels to checkout)
//
// FILE PLACEMENT — see README below in this file.

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sku_catalog.dart';
import 'sku_variant_picker.dart';

// ─── THRIFT DESIGN TOKENS ────────────────────────────────────────────────────
class _TC {
  static const bg          = Color(0xFF141008);
  static const surface     = Color(0xFF1E170E);
  static const cardBg      = Color(0xFF231A0E);
  static const tan         = Color(0xFFC4913A);
  static const tanLight    = Color(0xFFDDB96A);
  static const tanDim      = Color(0xFF7A5828);
  static const white       = Color(0xFFFFFFFF);
  static const offWhite    = Color(0xFFF2E9D6);
  static const grey400     = Color(0xFF9E8E78);
  static const grey600     = Color(0xFF5A4A38);
  static const co2Bg       = Color(0xFF162416);
  static const co2Text     = Color(0xFF6DBF6D);
  static const impactBg    = Color(0xFF1A1208);
  static const impactText  = Color(0xFFCCA84E);
  static const likeNewBg   = Color(0xFF162416);
  static const likeNewTxt  = Color(0xFF7FC97F);
  static const usedBg      = Color(0xFF2E2610);
  static const usedTxt     = Color(0xFFCFAD4A);
  static const vintageBg   = Color(0xFF301A08);
  static const vintageTxt  = Color(0xFFCF8044);
  static const fomoRed     = Color(0xFFC0392B);
  static const fomoRedBg   = Color(0xFF2A0A08);
  static const newDropBg   = Color(0xFF2A1A04);
  static const newDropText = Color(0xFFFFB347);
  // SKU colours (dark-theme variant — consistent with SwipeStyle dark overlay)
  static const skuText     = Color(0xFF888888);
  static const skuBorder   = Color(0xFF3A2E00);
  static const skuBg       = Color(0xFF1E170E);
}

// ─── TEXT STYLES ─────────────────────────────────────────────────────────────
TextStyle _display(double size,
        {Color color = _TC.offWhite, double spacing = 0}) =>
    GoogleFonts.bebasNeue(fontSize: size, color: color, letterSpacing: spacing);

TextStyle _label(double size,
        {Color color = _TC.offWhite,
        FontWeight fw = FontWeight.w600,
        double spacing = 0.5}) =>
    GoogleFonts.jost(fontSize: size, fontWeight: fw, color: color, letterSpacing: spacing);

TextStyle _body(double size,
        {Color color = _TC.grey400, FontWeight fw = FontWeight.w400}) =>
    GoogleFonts.jost(fontSize: size, fontWeight: fw, color: color);

TextStyle _mono(double size,
        {Color color = _TC.grey400,
        TextDecoration? decoration,
        FontWeight fw = FontWeight.w400}) =>
    GoogleFonts.robotoMono(
        fontSize: size, color: color, fontWeight: fw, decoration: decoration);

TextStyle _skuMono(double size) =>
    GoogleFonts.robotoMono(
        fontSize: size,
        color: _TC.skuText,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4);

TextStyle _conditionText(double size, {required Color color}) =>
    GoogleFonts.montserrat(fontSize: size, fontWeight: FontWeight.w900, color: color);

// ─── MODELS ──────────────────────────────────────────────────────────────────
enum _Condition { likeNew, gentlyUsed, vintageFind }

_Condition _conditionFromString(String? value) {
  switch (value) {
    case 'likeNew':     return _Condition.likeNew;
    case 'gentlyUsed':  return _Condition.gentlyUsed;
    case 'vintageFind': return _Condition.vintageFind;
    default:            return _Condition.gentlyUsed;
  }
}

class _ThriftProduct {
  final String   productId;
  final String   name;
  final String   brand;
  final String   category;
  final String   originalPrice;
  final String   thriftPrice;
  final String   imageUrl;
  final _Condition condition;
  final double   co2Saved;
  final String   sellerName;
  final double   sellerRating;
  final bool     sellerVerified;
  final bool     tall;

  // The Firestore listing SKU (shown on card, different from child variant SKU)
  final String   listingSku;

  // parentId links this Firestore listing to SkuCatalog for variant selection
  // If null, the product has no variant catalog entry (e.g. one-off thrift item)
  final String?  parentId;

  // FOMO fields
  final int?     stockLeft;
  final int?     orderedToday;
  final bool     isNewDrop;
  final String?  trendingCategory;

  const _ThriftProduct({
    required this.productId,
    required this.name,
    required this.brand,
    required this.category,
    required this.originalPrice,
    required this.thriftPrice,
    required this.imageUrl,
    required this.condition,
    required this.co2Saved,
    required this.sellerName,
    required this.sellerRating,
    required this.listingSku,
    this.parentId,
    this.sellerVerified = false,
    this.tall = false,
    this.stockLeft,
    this.orderedToday,
    this.isNewDrop = false,
    this.trendingCategory,
  });
}

// ─── STATIC SAMPLE PRODUCTS ──────────────────────────────────────────────────
// These are the same listings shown in the original ThriftMarketplace screen.
// Firestore is used ONLY for the cart (see _CartService below).
// Products are static so the screen always shows items — no empty state.
// In production: swap this list with a real Firestore/REST fetch.
final _sampleProducts = [
  _ThriftProduct(
    productId: 'prod-001', name: 'SILK WRAP DRESS', brand: 'MAISON KAIRA',
    category: 'Dresses', originalPrice: '₹12,000', thriftPrice: '₹3,499',
    imageUrl: 'https://images.unsplash.com/photo-1539008835657-9e8e9680c956?w=600&q=85',
    condition: _Condition.likeNew, co2Saved: 3.2,
    sellerName: 'Priya S.', sellerRating: 4.9, sellerVerified: true,
    tall: true, listingSku: 'SWD-MK-IVR-M-101', parentId: 'FSR-MK',
    stockLeft: 2, isNewDrop: false, trendingCategory: 'Date Night',
  ),
  _ThriftProduct(
    productId: 'prod-002', name: 'POWER BLAZER', brand: 'ATELIER SUR',
    category: 'Blazers', originalPrice: '₹15,000', thriftPrice: '₹5,200',
    imageUrl: 'https://images.unsplash.com/photo-1551803091-e20673f15770?w=600&q=85',
    condition: _Condition.gentlyUsed, co2Saved: 4.1,
    sellerName: 'Ananya M.', sellerRating: 4.7, sellerVerified: true,
    tall: false, listingSku: 'PBL-AS-BLK-L-201', parentId: 'PBL-AS',
    orderedToday: 34, isNewDrop: false,
  ),
  _ThriftProduct(
    productId: 'prod-003', name: 'VINTAGE KURTA', brand: 'INDIRA & CO',
    category: 'Ethnic', originalPrice: '₹8,500', thriftPrice: '₹2,100',
    imageUrl: 'https://images.unsplash.com/photo-1566206091558-7f218b696731?w=600&q=85',
    condition: _Condition.vintageFind, co2Saved: 2.8,
    sellerName: 'Kavitha R.', sellerRating: 4.5, sellerVerified: false,
    tall: true, listingSku: 'VKT-IC-EMB-S-301', parentId: 'VKT-IC',
    isNewDrop: true,
  ),
  _ThriftProduct(
    productId: 'prod-004', name: 'DENIM JACKET', brand: 'RAW & REFINED',
    category: 'Jackets', originalPrice: '₹9,000', thriftPrice: '₹2,800',
    imageUrl: 'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=600&q=85',
    condition: _Condition.likeNew, co2Saved: 3.6,
    sellerName: 'Sneha P.', sellerRating: 4.8, sellerVerified: true,
    tall: false, listingSku: 'DJK-RR-BLU-L-401', parentId: 'DJK-RR',
    stockLeft: 1, orderedToday: 22, isNewDrop: false,
  ),
  _ThriftProduct(
    productId: 'prod-005', name: 'COORD SET', brand: 'CASA MODAS',
    category: 'Co-ords', originalPrice: '₹7,500', thriftPrice: '₹2,200',
    imageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&q=85',
    condition: _Condition.gentlyUsed, co2Saved: 2.5,
    sellerName: 'Ritu K.', sellerRating: 4.6, sellerVerified: false,
    tall: true, listingSku: 'COS-CM-BEG-M-501', parentId: 'COS-CM',
    isNewDrop: false, trendingCategory: 'Casual Outfits',
  ),
 
  _ThriftProduct(
    productId: 'prod-007', name: 'STREET JACKET', brand: 'DECO NOIR',
    category: 'Outerwear', originalPrice: '₹14,200', thriftPrice: '₹4,400',
    imageUrl: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600&q=85',
    condition: _Condition.likeNew, co2Saved: 4.8,
    sellerName: 'Meera J.', sellerRating: 4.7, sellerVerified: true,
    tall: true, listingSku: 'STJ-DN-BLK-L-701', parentId: 'STJ-DN',
    stockLeft: 3, isNewDrop: false, trendingCategory: 'Street Style',
  ),
  _ThriftProduct(
    productId: 'prod-008', name: 'PRINTED MAXI', brand: 'CASA MODAS',
    category: 'Dresses', originalPrice: '₹6,800', thriftPrice: '₹1,950',
    imageUrl: 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=600&q=85',
    condition: _Condition.gentlyUsed, co2Saved: 2.1,
    sellerName: 'Tanya B.', sellerRating: 4.4, sellerVerified: false,
    tall: false, listingSku: 'PMX-CM-FLR-S-801', parentId: 'COS-CM',
    isNewDrop: true,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// FIRESTORE SEEDER
// Call once: await ThriftFirestoreSeeder.uploadSampleProducts();
// New field added: parentId — connects each listing to SkuCatalog
// ─────────────────────────────────────────────────────────────────────────────
class ThriftFirestoreSeeder {
  static Future<void> uploadSampleProducts() async {
    final col = FirebaseFirestore.instance.collection('products');
    final samples = [
      {
        'name': 'SILK WRAP DRESS',       'brand': 'MAISON KAIRA',
        'sku': 'SWD-MK-IVR-M-101',      'parentId': 'FSR-MK',
        'category': 'Dresses',           'originalPrice': '₹12,000',
        'thriftPrice': '₹3,499',
        'imageUrl': 'https://images.unsplash.com/photo-1539008835657-9e8e9680c956?w=600&q=85',
        'condition': 'likeNew',          'co2Saved': 3.2,
        'sellerName': 'Priya S.',        'sellerRating': 4.9,
        'sellerVerified': true,          'tall': true,
        'stock': 2, 'isNewDrop': false,  'trendingCategory': 'Date Night',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'POWER BLAZER',          'brand': 'ATELIER SUR',
        'sku': 'PBL-AS-BLK-L-201',      'parentId': 'PBL-AS',
        'category': 'Blazers',           'originalPrice': '₹15,000',
        'thriftPrice': '₹5,200',
        'imageUrl': 'https://images.unsplash.com/photo-1551803091-e20673f15770?w=600&q=85',
        'condition': 'gentlyUsed',       'co2Saved': 4.1,
        'sellerName': 'Ananya M.',       'sellerRating': 4.7,
        'sellerVerified': true,          'tall': false,
        'stock': 10, 'orderedToday': 34, 'isNewDrop': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'VINTAGE KURTA',         'brand': 'INDIRA & CO',
        'sku': 'VKT-IC-EMB-S-301',      'parentId': 'VKT-IC',
        'category': 'Ethnic',            'originalPrice': '₹8,500',
        'thriftPrice': '₹2,100',
        'imageUrl': 'https://images.unsplash.com/photo-1566206091558-7f218b696731?w=600&q=85',
        'condition': 'vintageFind',      'co2Saved': 2.8,
        'sellerName': 'Kavitha R.',      'sellerRating': 4.5,
        'sellerVerified': false,         'tall': true,
        'stock': 8, 'isNewDrop': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'DENIM JACKET',          'brand': 'RAW & REFINED',
        'sku': 'DJK-RR-BLU-L-401',      'parentId': 'DJK-RR',
        'category': 'Jackets',           'originalPrice': '₹9,000',
        'thriftPrice': '₹2,800',
        'imageUrl': 'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=600&q=85',
        'condition': 'likeNew',          'co2Saved': 3.6,
        'sellerName': 'Sneha P.',        'sellerRating': 4.8,
        'sellerVerified': true,          'tall': false,
        'stock': 1, 'orderedToday': 22,  'isNewDrop': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'COORD SET',             'brand': 'CASA MODAS',
        'sku': 'COS-CM-BEG-M-501',      'parentId': 'COS-CM',
        'category': 'Co-ords',           'originalPrice': '₹7,500',
        'thriftPrice': '₹2,200',
        'imageUrl': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&q=85',
        'condition': 'gentlyUsed',       'co2Saved': 2.5,
        'sellerName': 'Ritu K.',         'sellerRating': 4.6,
        'sellerVerified': false,         'tall': true,
        'stock': 12, 'isNewDrop': false, 'trendingCategory': 'Casual Outfits',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'FESTIVE SAREE',         'brand': 'MAISON KAIRA',
        'sku': 'FSR-MK-RED-F-601',      'parentId': 'FSR-MK',
        'category': 'Sarees',            'originalPrice': '₹18,500',
        'thriftPrice': '₹5,999',
        'imageUrl': 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=600&q=85',
        'condition': 'vintageFind',      'co2Saved': 5.1,
        'sellerName': 'Deepa V.',        'sellerRating': 5.0,
        'sellerVerified': true,          'tall': false,
        'stock': 6, 'orderedToday': 58,  'isNewDrop': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'STREET JACKET',         'brand': 'DECO NOIR',
        'sku': 'STJ-DN-BLK-L-701',      'parentId': 'STJ-DN',
        'category': 'Outerwear',         'originalPrice': '₹14,200',
        'thriftPrice': '₹4,400',
        'imageUrl': 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600&q=85',
        'condition': 'likeNew',          'co2Saved': 4.8,
        'sellerName': 'Meera J.',        'sellerRating': 4.7,
        'sellerVerified': true,          'tall': true,
        'stock': 3, 'isNewDrop': false,  'trendingCategory': 'Street Style',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'PRINTED MAXI',          'brand': 'CASA MODAS',
        'sku': 'PMX-CM-FLR-S-801',      'parentId': 'COS-CM',
        'category': 'Dresses',           'originalPrice': '₹6,800',
        'thriftPrice': '₹1,950',
        'imageUrl': 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=600&q=85',
        'condition': 'gentlyUsed',       'co2Saved': 2.1,
        'sellerName': 'Tanya B.',        'sellerRating': 4.4,
        'sellerVerified': false,         'tall': false,
        'stock': 7, 'isNewDrop': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];
    for (final p in samples) await col.add(p);
    debugPrint('✅ ThriftFirestoreSeeder: ${samples.length} products uploaded.');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART SERVICE
//
// Firestore collection: "cart"
// Each document = one CartPayload added by the user.
// Documents are written ONLY when the user explicitly taps "ADD TO CART".
// The screen reads them back on open so the cart persists across sessions.
//
// Document schema mirrors CartPayload.toJson():
//   parentId, variantSku, productName, brand, size,
//   colorName, colorHex, quantity, unitPriceInPaise, totalInPaise,
//   imageUrl, addedAt (server timestamp)
//
// In production: scope the collection to the authenticated user, e.g.:
//   "users/{uid}/cart"
// ─────────────────────────────────────────────────────────────────────────────
class _CartService {
  static final _col = FirebaseFirestore.instance.collection('cart');

  // Read all cart items (called once when screen opens)
  static Future<List<_CartEntry>> loadCart() async {
    final snap = await _col.orderBy('addedAt', descending: false).get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return _CartEntry(
        localId: doc.id,  // reuse docId as localId for persisted entries
        docId  : doc.id,
        payload: CartPayload(
          parentId        : d['parentId']         as String? ?? '',
          variantSku      : d['variantSku']        as String? ?? '',
          productName     : d['productName']       as String? ?? '',
          brand           : d['brand']             as String? ?? '',
          size            : d['size']              as String? ?? '',
          colorName       : d['colorName']         as String? ?? '',
          colorHex        : d['colorHex']          as String? ?? '#888888',
          quantity        : (d['quantity']         as num?)?.toInt() ?? 1,
          unitPriceInPaise: (d['unitPriceInPaise'] as num?)?.toInt() ?? 0,
          imageUrl        : d['imageUrl']          as String? ?? '',
        ),
      );
    }).toList();
  }

  // Write one cart item to Firestore
  // Uses explicit field map — same pattern as ThriftFirestoreSeeder.uploadSampleProducts()
  static Future<String> addItem(CartPayload payload) async {
    final doc = await _col.add({
      'parentId'         : payload.parentId,
      'variantSku'       : payload.variantSku,
      'productName'      : payload.productName,
      'brand'            : payload.brand,
      'size'             : payload.size,
      'colorName'        : payload.colorName,
      'colorHex'         : payload.colorHex,
      'quantity'         : payload.quantity,
      'unitPriceInPaise' : payload.unitPriceInPaise,
      'totalInPaise'     : payload.totalInPaise,
      'imageUrl'         : payload.imageUrl,
      'addedAt'          : FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Cart written to Firestore  docId=${doc.id}  sku=${payload.variantSku}');
    return doc.id;
  }

  // Delete one cart item from Firestore
  static Future<void> removeItem(String docId) => _col.doc(docId).delete();

  // Clear entire cart (called after successful checkout)
  static Future<void> clearCart(List<String> docIds) =>
      Future.wait(docIds.map(_col.doc).map((r) => r.delete()));
}

// Pairs a Firestore doc ID with its CartPayload so we can delete precisely
class _CartEntry {
  // A local temporary id so we can find this entry in the list
  // before the Firestore docId comes back
  final String      localId;
  final String      docId;
  final CartPayload payload;

  _CartEntry({required this.localId, required this.docId, required this.payload});

  // Copy with a real Firestore docId once the write completes
  _CartEntry withDocId(String id) =>
      _CartEntry(localId: localId, docId: id, payload: payload);
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────
class ThriftMarketplaceScreen extends StatefulWidget {
  const ThriftMarketplaceScreen({super.key});
  @override State<ThriftMarketplaceScreen> createState() => _ThriftMarketplaceScreenState();
}

class _ThriftMarketplaceScreenState extends State<ThriftMarketplaceScreen>
    with SingleTickerProviderStateMixin {

  final Set<int>               _wishlist   = {};

  // Cart is now a list of _CartEntry — each has a Firestore docId for deletion
  final List<_CartEntry>       _cartEntries = [];
  bool                         _cartLoading = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    // ⚠️  DO NOT call ThriftFirestoreSeeder here.
    // Run the seeder exactly once from a one-time admin screen or DevTools.
    // Calling it in initState() re-uploads all sample products every time
    // this screen is opened, creating duplicate Firestore documents.
    //
    // To seed your database for the first time, call manually:
    //   await ThriftFirestoreSeeder.uploadSampleProducts();
    _loadCart();   // ← instead, load this user's existing cart from Firestore
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  // ── Load cart from Firestore on screen open ───────────────────────────────
  // Only the user's previously added-to-cart items come back.
  // Products browsed but not added are never stored here.
  Future<void> _loadCart() async {
    try {
      final entries = await _CartService.loadCart();
      if (!mounted) return;
      setState(() {
        _cartEntries
          ..clear()
          ..addAll(entries);
        _cartLoading = false;
      });
    } catch (e) {
      debugPrint('Cart load error: $e');
      if (mounted) setState(() => _cartLoading = false);
    }
  }

  void _toggleWish(int i) => setState(() =>
      _wishlist.contains(i) ? _wishlist.remove(i) : _wishlist.add(i));

  // ── Open VariantPickerSheet ────────────────────────────────────────────────
  void _openVariantPicker(_ThriftProduct product) {
    if (product.parentId == null) {
      _addOneOffToCart(product);
      return;
    }
    final parent = SkuCatalog.get(product.parentId!);
    if (parent == null) {
      _addOneOffToCart(product);
      return;
    }

    VariantPickerSheet.show(
      context,
      parent: parent,
      onAddToCart: (CartPayload payload) {
        // Generate a unique local id for this entry so we can find it later
        final localId = '${DateTime.now().microsecondsSinceEpoch}';
        final tempEntry = _CartEntry(localId: localId, docId: '', payload: payload);

        // 1. Add locally — UI updates instantly, no Firestore dependency
        setState(() => _cartEntries.add(tempEntry));

        // 2. Snackbar while context is still valid
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${payload.productName}  •  ${payload.size} / ${payload.colorName}',
            style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white),
          ),
          backgroundColor: _TC.cardBg,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(),
        ));

        // 3. Write to Firestore in background — swap empty docId with real one
        _CartService.addItem(payload).then((docId) {
          if (!mounted) return;
          final idx = _cartEntries.indexWhere((e) => e.localId == localId);
          if (idx != -1) {
            setState(() => _cartEntries[idx] = tempEntry.withDocId(docId));
          }
          debugPrint('✅ Cart item saved to Firestore: $docId  SKU: ${payload.variantSku}');
        }).catchError((Object e) {
          // Log the REAL error so you can see exactly what Firestore rejected
          debugPrint('❌ Firestore cart write FAILED: $e');
          // Item stays in local list — user experience is unaffected
        });
      },
    );
  }

  // ── One-off thrift item (no variant catalog) ─────────────────────────────
  void _addOneOffToCart(_ThriftProduct product) {
    final price = int.tryParse(
            product.thriftPrice.replaceAll(RegExp(r'[₹,]'), '')) ?? 0;
    final payload = CartPayload(
      parentId        : product.productId,
      variantSku      : product.listingSku,
      productName     : product.name,
      brand           : product.brand,
      size            : 'One Size',
      colorName       : '—',
      colorHex        : '#888888',
      quantity        : 1,
      unitPriceInPaise: price * 100,
      imageUrl        : product.imageUrl,
    );

    final localId = '${DateTime.now().microsecondsSinceEpoch}';
    final tempEntry = _CartEntry(localId: localId, docId: '', payload: payload);

    setState(() => _cartEntries.add(tempEntry));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${product.name} added  •  SKU: ${product.listingSku}',
          style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white)),
      backgroundColor: _TC.cardBg,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));

    _CartService.addItem(payload).then((docId) {
      if (!mounted) return;
      final idx = _cartEntries.indexWhere((e) => e.localId == localId);
      if (idx != -1) {
        setState(() => _cartEntries[idx] = tempEntry.withDocId(docId));
      }
      debugPrint('✅ Cart item saved to Firestore: $docId  SKU: ${payload.variantSku}');
    }).catchError((Object e) {
      debugPrint('❌ Firestore cart write FAILED (one-off): $e');
    });
  }

  Future<void> _removeCartItem(int index) async {
    final entry = _cartEntries[index];
    setState(() => _cartEntries.removeAt(index));
    if (entry.docId.isEmpty) return;   // Firestore write still pending
    try {
      await _CartService.removeItem(entry.docId);
    } catch (e) {
      debugPrint('❌ Firestore cart remove FAILED: $e');
      if (mounted) setState(() => _cartEntries.insert(index, entry));
    }
  }

  // ── Checkout — clears cart locally and from Firestore ────────────────────
  Future<void> _checkout() async {
    final docIds = _cartEntries
        .map((e) => e.docId)
        .where((id) => id.isNotEmpty)
        .toList();
    setState(() => _cartEntries.clear());
    Navigator.pop(context);
    if (docIds.isNotEmpty) {
      await _CartService.clearCart(docIds).catchError(
          (e) => debugPrint('Checkout clear error: $e'));
    }
    // TODO: call your order placement API here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _TC.bg,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: SizedBox(
        width: 56, height: 56,
        child: FloatingActionButton(
          heroTag: 'sell_fab',
          onPressed: () {},
          backgroundColor: _TC.tan,
          elevation: 6,
          shape: const CircleBorder(),
          child: Text('SELL\nNOW',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                  fontSize: 9, fontWeight: FontWeight.w900,
                  color: _TC.bg, height: 1.3, letterSpacing: 0.5)),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          _buildTopBar(),
          _buildCommunityImpactBar(),
          Expanded(child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildMasonryGrid(_sampleProducts)),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          )),
        ]),
      ),
    );
  }

  // ─── CART BOTTOM SHEET ───────────────────────────────────────────────────
  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _TC.cardBg,
      isScrollControlled: true,
      builder: (_) => _CartSheet(
        entries: _cartEntries,
        onRemove: (i) => _removeCartItem(i),   // Firestore delete
        onCheckout: _checkout,                 // Firestore clear + order
      ),
    );
  }

  // ─── TOP BAR ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Container(
    color: _TC.bg,
    padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14, left: 16, right: 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: _TC.offWhite, size: 22)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('THRIFT MARKETPLACE', style: _display(22, spacing: 1.2)),
        Text('Circular fashion. Curated pre-owned.', style: _body(11)),
      ])),
      // Cart badge in top bar — reflects Firestore-persisted items
      if (_cartEntries.isNotEmpty)
        GestureDetector(
          onTap: _showCartSheet,
          child: Stack(clipBehavior: Clip.none, children: [
            const Icon(Icons.shopping_bag_outlined, color: _TC.offWhite, size: 22),
            Positioned(top: -5, right: -6,
              child: Container(
                width: 15, height: 15,
                decoration: const BoxDecoration(color: Color(0xFFE91E8C), shape: BoxShape.circle),
                child: Center(child: Text('${_cartEntries.length}',
                    style: GoogleFonts.jost(fontSize: 8, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0))),
              )),
          ]),
        )
      else
        const Icon(Icons.search, color: _TC.offWhite, size: 22),
      const SizedBox(width: 18),
      const Icon(Icons.tune_rounded, color: _TC.offWhite, size: 22),
    ]),
  );

  // ─── COMMUNITY IMPACT BAR ────────────────────────────────────────────────
  Widget _buildCommunityImpactBar() => Container(
    width: double.infinity, color: _TC.impactBg,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      const Icon(Icons.eco_outlined, color: _TC.co2Text, size: 15),
      const SizedBox(width: 8),
      Expanded(child: RichText(text: TextSpan(children: [
        TextSpan(text: 'Community Impact:  ', style: _label(11, color: _TC.impactText, spacing: 0.4)),
        TextSpan(text: '1,240 items rescued this month', style: _body(11, color: _TC.impactText)),
      ]))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: _TC.co2Bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.trending_up, size: 11, color: _TC.co2Text),
          const SizedBox(width: 3),
          Text('18%', style: _label(9, color: _TC.co2Text, spacing: 0)),
        ]),
      ),
    ]),
  );

  // ─── MASONRY GRID ────────────────────────────────────────────────────────
  Widget _buildMasonryGrid(List<_ThriftProduct> products) {
    final left  = <(int, _ThriftProduct)>[];
    final right = <(int, _ThriftProduct)>[];
    for (int i = 0; i < products.length; i++) {
      if (i % 2 == 0) left.add((i, products[i]));
      else             right.add((i, products[i]));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: left.map((t) => _ThriftCard(
            index: t.$1, product: t.$2,
            wished: _wishlist.contains(t.$1),
            onWish: () => _toggleWish(t.$1),
            onTap: () => _openVariantPicker(t.$2))).toList())),
        const SizedBox(width: 10),
        Expanded(child: Column(children: [
          const SizedBox(height: 44),
          ...right.map((t) => _ThriftCard(
              index: t.$1, product: t.$2,
              wished: _wishlist.contains(t.$1),
              onWish: () => _toggleWish(t.$1),
              onTap: () => _openVariantPicker(t.$2))),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART BOTTOM SHEET
// Receives List<_CartEntry> — each entry has a Firestore docId + CartPayload.
// ─────────────────────────────────────────────────────────────────────────────
class _CartSheet extends StatelessWidget {
  final List<_CartEntry>  entries;
  final void Function(int) onRemove;   // index in entries list
  final VoidCallback       onCheckout;

  const _CartSheet({
    required this.entries,
    required this.onRemove,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      color: _TC.cardBg,
      padding: EdgeInsets.only(bottom: mq.padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 3,
            decoration: BoxDecoration(
                color: _TC.tanDim, borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: [
          Text('THRIFT CART', style: _display(22, color: _TC.offWhite, spacing: 1)),
          const Spacer(),
          Text('${entries.length} item${entries.length == 1 ? '' : 's'}',
              style: _body(11, color: _TC.grey400)),
        ])),
        const Divider(color: _TC.surface, height: 1),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Text('Your cart is empty', style: _body(13, color: _TC.grey400)),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.45),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(color: _TC.surface, height: 1),
              itemBuilder: (_, i) {
                final item = entries[i].payload;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(item.imageUrl,
                        width: 52, height: 60, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(width: 52, height: 60, color: _TC.surface)),
                  ),
                  title: Text(item.productName,
                      style: _label(12, color: _TC.offWhite, spacing: 0),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${item.size}  ·  ${item.colorName}',
                        style: _body(10, color: _TC.grey400)),
                    const SizedBox(height: 2),
                    // Child variant SKU — tap to copy
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Clipboard.setData(ClipboardData(text: item.variantSku));
                      },
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.qr_code, size: 9, color: _TC.skuText),
                        const SizedBox(width: 3),
                        Text(item.variantSku, style: _skuMono(8)),
                        const SizedBox(width: 5),
                        const Icon(Icons.copy, size: 8, color: _TC.skuText),
                      ]),
                    ),
                  ]),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_fmtPrice(item.unitPriceInPaise),
                        style: GoogleFonts.jost(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _TC.tan)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      // onRemove calls _removeCartItem(i) → Firestore delete
                      onTap: () => onRemove(i),
                      child: const Icon(Icons.close, size: 16, color: _TC.grey400),
                    ),
                  ]),
                );
              },
            ),
          ),
        const Divider(color: _TC.surface, height: 1),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
          Text('TOTAL', style: _label(11, color: _TC.grey400, spacing: 1)),
          const Spacer(),
          Text(_formatTotal(entries),
              style: GoogleFonts.bebasNeue(
                  fontSize: 22, color: _TC.tanLight, letterSpacing: 1)),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: GestureDetector(
          onTap: entries.isEmpty ? null : onCheckout,
          child: Container(
            width: double.infinity, height: 52,
            color: entries.isEmpty ? _TC.grey600 : _TC.tan,
            child: Center(child: Text(
              entries.isEmpty
                  ? 'CART IS EMPTY'
                  : 'CHECKOUT  —  ${entries.length} ITEM${entries.length == 1 ? '' : 'S'}',
              style: GoogleFonts.bebasNeue(
                  fontSize: 18, color: _TC.bg, letterSpacing: 2))),
          ),
        )),
      ]),
    );
  }

  static String _fmtPrice(int paise) {
    final r = paise ~/ 100;
    final s = r.toString();
    if (s.length <= 3) return '₹$s';
    return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  static String _formatTotal(List<_CartEntry> entries) {
    final total = entries.fold<int>(0, (s, e) => s + e.payload.totalInPaise);
    return _fmtPrice(total);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THRIFT CARD — tap now opens VariantPickerSheet
// ─────────────────────────────────────────────────────────────────────────────
class _ThriftCard extends StatefulWidget {
  final int            index;
  final _ThriftProduct product;
  final bool           wished;
  final VoidCallback   onWish;
  final VoidCallback   onTap;   // ← new: opens variant picker

  const _ThriftCard({
    required this.index,
    required this.product,
    required this.wished,
    required this.onWish,
    required this.onTap,
  });

  @override State<_ThriftCard> createState() => _ThriftCardState();
}

class _ThriftCardState extends State<_ThriftCard> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  late final AnimationController _shimmerCtrl;
  late final Animation<double>   _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    if ((widget.product.stockLeft ?? 99) < 5) _pulseCtrl.repeat(reverse: true);

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
    if (widget.product.isNewDrop) _shimmerCtrl.repeat(period: const Duration(milliseconds: 2400));
  }

  @override void dispose() { _pulseCtrl.dispose(); _shimmerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p           = widget.product;
    final imageHeight = p.tall ? 210.0 : 160.0;
    final hasVariants = p.parentId != null && SkuCatalog.get(p.parentId!) != null;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _TC.cardBg,
          borderRadius: BorderRadius.circular(6),
          // Subtle new-drop glow border — kept because it's editorial, not clutter
          border: p.isNewDrop
              ? Border.all(color: _TC.newDropText.withOpacity(0.35), width: 1.0)
              : Border.all(color: _TC.surface, width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── PHOTO ──────────────────────────────────────────────────────────
          Stack(children: [
            SizedBox(
              height: imageHeight, width: double.infinity,
              child: Image.network(p.imageUrl, fit: BoxFit.cover,
                  loadingBuilder: (_, child, prog) =>
                      prog == null ? child : Container(height: imageHeight, color: _TC.surface),
                  errorBuilder: (_, __, ___) => Container(
                      height: imageHeight, color: _TC.surface,
                      child: Center(child: Icon(Icons.image_outlined, color: _TC.grey600, size: 32))))),

            // ── Wishlist — top right ──
            Positioned(top: 8, right: 8,
              child: GestureDetector(onTap: widget.onWish,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                  child: Center(child: Icon(
                      widget.wished ? Icons.favorite : Icons.favorite_border,
                      size: 16, color: widget.wished ? _TC.tan : _TC.white))))),

            // ── NEW DROP badge — top left, only when isNewDrop ──
            if (p.isNewDrop)
              Positioned(top: 8, left: 8,
                  child: _NewDropBadge(shimmerAnim: _shimmerAnim)),

            // ── Bottom gradient ──
            Positioned(bottom: 0, left: 0, right: 0, height: 52,
              child: Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xAA000000)])))),

           
            // ── Variant colour dots — bottom right ──
            if (hasVariants)
              Positioned(bottom: 8, right: 8,
                  child: _ThriftVariantCue(parentId: p.parentId!)),
          ]),

          // ── INFO BLOCK ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Text(
        p.name,
        style: _label(12, color: _TC.offWhite, spacing: 0),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),

    const SizedBox(width: 6),

    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star_rounded,
          size: 12,
          color: _TC.tan,
        ),
        const SizedBox(width: 2),
        Text(
          p.sellerRating.toStringAsFixed(1),
          style: _label(
            10,
            color: _TC.tanLight,
            spacing: 0,
          ),
        ),
      ],
    ),
  ],
),

const SizedBox(height: 6),

              // Price row — thrift price + strikethrough original
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Thrift price — give it fixed flex so it never causes overflow
                  Expanded(
                    flex: 3,
                    child: Text(p.thriftPrice,
                        style: GoogleFonts.jost(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _TC.tan),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 5),
                  // Original price — smaller flex
                  Expanded(
                    flex: 2,
                    child: Text(p.originalPrice,
                        style: _mono(9,
                            color: _TC.grey400,
                            decoration: TextDecoration.lineThrough),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),

              // Stock FOMO — only when scarce
              if ((p.stockLeft ?? 99) < 5 && p.stockLeft != null) ...[
                const SizedBox(height: 5),
                _StockCounter(stockLeft: p.stockLeft!, pulseAnim: _pulseAnim),
              ],

              // Recency — ordered today
              if (p.orderedToday != null && p.orderedToday! > 0) ...[
                const SizedBox(height: 4),
                _RecencySignal(count: p.orderedToday!),
              ],

              const SizedBox(height: 7),

              // ── Bottom row: CO2 chip  +  star rating bottom-right ─────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // CO2 chip
                  _CO2Chip(saved: p.co2Saved),
                  
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── VARIANT CUE (dark theme) ─────────────────────────────────────────────────
class _ThriftVariantCue extends StatelessWidget {
  final String parentId;
  const _ThriftVariantCue({required this.parentId});

  @override
  Widget build(BuildContext context) {
    final parent = SkuCatalog.get(parentId);
    if (parent == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ...parent.colors.take(3).map((c) {
          final hex = c.hex.replaceFirst('#', '');
          return Container(
            width: 10, height: 10, margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(int.parse('FF$hex', radix: 16)),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.5),
            ),
          );
        }),
        Text('+${parent.sizes.length}', style: GoogleFonts.jost(fontSize: 7, color: _TC.offWhite, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── FOMO WIDGET 1 — STOCK COUNTER ───────────────────────────────────────────
class _StockCounter extends StatelessWidget {
  final int stockLeft; final Animation<double> pulseAnim;
  const _StockCounter({required this.stockLeft, required this.pulseAnim});
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulseAnim,
    builder: (_, __) => Opacity(opacity: pulseAnim.value, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: _TC.fomoRedBg, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _TC.fomoRed.withOpacity(0.5), width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: const BoxDecoration(color: _TC.fomoRed, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('Only $stockLeft left! ',
            style: _mono(9, color: _TC.fomoRed, fw: FontWeight.w600)),
      ]),
    )),
  );
}

// ─── FOMO WIDGET 2 — RECENCY SIGNAL ──────────────────────────────────────────
class _RecencySignal extends StatelessWidget {
  final int count; const _RecencySignal({required this.count});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.local_fire_department_rounded, size: 10, color: _TC.tan),
    const SizedBox(width: 4),
    Text('Ordered $count times today',
        style: _label(9, color: _TC.tanLight, spacing: 0, fw: FontWeight.w500)),
  ]);
}

// ─── FOMO WIDGET 3 — NEW DROP BADGE ──────────────────────────────────────────
class _NewDropBadge extends StatelessWidget {
  final Animation<double> shimmerAnim; const _NewDropBadge({required this.shimmerAnim});
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: shimmerAnim,
    builder: (_, __) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: _TC.newDropBg, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _TC.newDropText.withOpacity(0.6), width: 0.8),
          boxShadow: [BoxShadow(color: _TC.newDropText.withOpacity(0.25), blurRadius: 6)]),
      child: Stack(children: [
        Text('NEW', style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w900,
            color: _TC.newDropText, letterSpacing: 1.0)),
        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(4),
          child: Transform.translate(offset: Offset(shimmerAnim.value * 30, 0),
            child: Container(width: 12, decoration: BoxDecoration(gradient: LinearGradient(
                colors: [Colors.transparent, _TC.newDropText.withOpacity(0.4), Colors.transparent])))))),
      ]),
    ),
  );
}

// ─── FOMO WIDGET 4 — TRENDING BADGE ──────────────────────────────────────────
class _TrendingBadge extends StatelessWidget {
  final String category; const _TrendingBadge({required this.category});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _TC.tan.withOpacity(0.5), width: 0.8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('👑', style: TextStyle(fontSize: 9)),
      const SizedBox(width: 4),
      Text('#1 in $category', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w700,
          color: _TC.tanLight, letterSpacing: 0.3)),
    ]),
  );
}

// ─── CO2 CHIP ─────────────────────────────────────────────────────────────────
class _CO2Chip extends StatelessWidget {
  final double saved; const _CO2Chip({required this.saved});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(color: _TC.co2Bg, borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _TC.co2Text.withOpacity(0.25), width: 0.5)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.eco, size: 11, color: _TC.co2Text),
      const SizedBox(width: 4),
      Text('Saves ${saved}kg CO₂', style: _label(8.5, color: _TC.co2Text, spacing: 0)),
    ]),
  );
}