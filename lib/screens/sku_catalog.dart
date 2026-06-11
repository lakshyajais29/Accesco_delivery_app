// ─────────────────────────────────────────────────────────────────────────────
// sku_catalog.dart
//
// ARCHITECTURE
// ┌─────────────────────┐
// │   ProductVariant     │  ← one leaf node: one Size × one Color
// │   (child SKU)        │     has its own sku, price, stock, imageUrl
// └─────────────────────┘
//        ▲  many
// ┌─────────────────────┐
// │   ParentProduct      │  ← catalogue entry; groups all variants
// │   (parent SKU)       │     owns sizes[], colors[], variantMap
// └─────────────────────┘
//
// KEY DESIGN DECISIONS
// • variantMap key  = "${size}__${colorHex}"   e.g. "M__#E91E8C"
// • Every Add-to-Cart operation resolves to ONE ProductVariant
//   and passes CartPayload to the checkout backend.
// • Stock/price shown in UI comes LIVE from the resolved variant,
//   not from any denormalized parent field.
// • A variant with stock = 0 is "sold out" — UI disables selection.
// ─────────────────────────────────────────────────────────────────────────────

// ─── VARIANT (child) ─────────────────────────────────────────────────────────
class ProductVariant {
  final String sku;           // e.g. "PBL-AS-BLK-M-102"
  final String parentId;      // links back to ParentProduct.id
  final String size;          // "XS" | "S" | "M" | "L" | "XL" | "XXL" | "Free"
  final String colorName;     // "Black" | "Rose" | …
  final String colorHex;      // "#000000"
  final int    stock;         // live units available
  final int    priceInPaise;  // price in smallest currency unit
  final String? imageUrl;     // variant-specific image (optional override)

  const ProductVariant({
    required this.sku,
    required this.parentId,
    required this.size,
    required this.colorName,
    required this.colorHex,
    required this.stock,
    required this.priceInPaise,
    this.imageUrl,
  });

  bool get inStock => stock > 0;

  /// Formatted price string  ₹4,200
  String get formattedPrice {
    final rupees = priceInPaise ~/ 100;
    final s = rupees.toString();
    if (s.length <= 3) return '₹$s';
    return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  /// Map key used as the lookup key inside ParentProduct.variantMap
  static String key(String size, String colorHex) => '${size}__$colorHex';
  String get mapKey => key(size, colorHex);
}

// ─── PARENT PRODUCT ──────────────────────────────────────────────────────────
class ParentProduct {
  final String id;            // e.g. "PBL-AS"
  final String name;
  final String brand;
  final String category;
  final String defaultImageUrl;
  final String? originalPriceFormatted; // strikethrough price if on sale

  // Axis lists — used to build the size/colour selector grids
  final List<String> sizes;   // ordered e.g. ["XS","S","M","L","XL"]
  final List<VariantColor> colors;

  // The actual variant lookup table
  // key = ProductVariant.key(size, colorHex)
  final Map<String, ProductVariant> variantMap;

  const ParentProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.defaultImageUrl,
    required this.sizes,
    required this.colors,
    required this.variantMap,
    this.originalPriceFormatted,
  });

  // ── Convenience resolvers ─────────────────────────────────────────────────

  /// Resolve a specific variant — returns null if combo doesn't exist
  ProductVariant? resolve(String size, String colorHex) =>
      variantMap[ProductVariant.key(size, colorHex)];

  /// All variants for a given size (across all colours)
  List<ProductVariant> variantsForSize(String size) => variantMap.values
      .where((v) => v.size == size)
      .toList();

  /// All variants for a given colour
  List<ProductVariant> variantsForColor(String colorHex) => variantMap.values
      .where((v) => v.colorHex == colorHex)
      .toList();

  /// Is at least one variant for this size available?
  bool sizeHasStock(String size) =>
      variantsForSize(size).any((v) => v.inStock);

  /// Is at least one variant for this colour available?
  bool colorHasStock(String colorHex) =>
      variantsForColor(colorHex).any((v) => v.inStock);

  /// Lowest price across all variants (used when no variant is selected yet)
  String get lowestPrice {
    if (variantMap.isEmpty) return '—';
    final min = variantMap.values
        .map((v) => v.priceInPaise)
        .reduce((a, b) => a < b ? a : b);
    final s = (min ~/ 100).toString();
    if (s.length <= 3) return '₹$s';
    return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
}

// ─── COLOUR DESCRIPTOR ───────────────────────────────────────────────────────
class VariantColor {
  final String name;
  final String hex;
  const VariantColor(this.name, this.hex);
}

// ─── CART PAYLOAD ─────────────────────────────────────────────────────────────
/// This is what gets sent to the checkout / order backend.
/// It contains the fully-resolved variant SKU so there is zero ambiguity.
class CartPayload {
  final String  parentId;
  final String  variantSku;     // the specific Size × Color SKU
  final String  productName;
  final String  brand;
  final String  size;
  final String  colorName;
  final String  colorHex;
  final int     quantity;
  final int     unitPriceInPaise;
  final String  imageUrl;

  const CartPayload({
    required this.parentId,
    required this.variantSku,
    required this.productName,
    required this.brand,
    required this.size,
    required this.colorName,
    required this.colorHex,
    required this.quantity,
    required this.unitPriceInPaise,
    required this.imageUrl,
  });

  int get totalInPaise => unitPriceInPaise * quantity;

  Map<String, dynamic> toJson() => {
    'parentId'         : parentId,
    'variantSku'       : variantSku,
    'productName'      : productName,
    'brand'            : brand,
    'size'             : size,
    'colorName'        : colorName,
    'colorHex'         : colorHex,
    'quantity'         : quantity,
    'unitPriceInPaise' : unitPriceInPaise,
    'totalInPaise'     : totalInPaise,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// MASTER CATALOG
// Replace these static entries with Firestore / REST API reads in production.
// Naming convention:  TYPE-BRAND-CLR-SZ-SEQ
//   TYPE  = 3-letter item code   (PBL=blazer, FSR=saree, DJK=denim jacket …)
//   BRAND = 2-letter brand abbr  (AS=Atelier Sur, MK=Maison Kaira …)
//   CLR   = 3-letter colour code (BLK=black, RED=red, IVR=ivory …)
//   SZ    = size code            (XS/S/M/L/XL/F=free size)
//   SEQ   = 3-digit sequential   (unique across entire catalogue)
// ─────────────────────────────────────────────────────────────────────────────
class SkuCatalog {
  SkuCatalog._();

  static final Map<String, ParentProduct> _catalog = {

    // ── 1. POWER BLAZER — ATELIER SUR ──────────────────────────────────────
    'PBL-AS': ParentProduct(
      id: 'PBL-AS',
      name: 'Power Structured Blazer',
      brand: 'ATELIER SUR',
      category: 'Blazers',
      defaultImageUrl:
          'https://images.unsplash.com/photo-1551803091-e20673f15770?w=600&q=85',
      originalPriceFormatted: '₹12,000',
      sizes:  ['S', 'M', 'L', 'XL'],
      colors: const [
        VariantColor('Black',  '#1A1A1A'),
        VariantColor('Ivory',  '#F5F0E8'),
        VariantColor('Blush',  '#E8A0A0'),
      ],
      variantMap: {
        // Black
        'S__#1A1A1A' : ProductVariant(sku:'PBL-AS-BLK-S-101',  parentId:'PBL-AS', size:'S',  colorName:'Black', colorHex:'#1A1A1A', stock:6,  priceInPaise:840000),
        'M__#1A1A1A' : ProductVariant(sku:'PBL-AS-BLK-M-102',  parentId:'PBL-AS', size:'M',  colorName:'Black', colorHex:'#1A1A1A', stock:3,  priceInPaise:840000),
        'L__#1A1A1A' : ProductVariant(sku:'PBL-AS-BLK-L-103',  parentId:'PBL-AS', size:'L',  colorName:'Black', colorHex:'#1A1A1A', stock:0,  priceInPaise:840000),
        'XL__#1A1A1A': ProductVariant(sku:'PBL-AS-BLK-XL-104', parentId:'PBL-AS', size:'XL', colorName:'Black', colorHex:'#1A1A1A', stock:2,  priceInPaise:840000),
        // Ivory
        'S__#F5F0E8' : ProductVariant(sku:'PBL-AS-IVR-S-111',  parentId:'PBL-AS', size:'S',  colorName:'Ivory', colorHex:'#F5F0E8', stock:4,  priceInPaise:870000),
        'M__#F5F0E8' : ProductVariant(sku:'PBL-AS-IVR-M-112',  parentId:'PBL-AS', size:'M',  colorName:'Ivory', colorHex:'#F5F0E8', stock:7,  priceInPaise:870000),
        'L__#F5F0E8' : ProductVariant(sku:'PBL-AS-IVR-L-113',  parentId:'PBL-AS', size:'L',  colorName:'Ivory', colorHex:'#F5F0E8', stock:1,  priceInPaise:870000),
        'XL__#F5F0E8': ProductVariant(sku:'PBL-AS-IVR-XL-114', parentId:'PBL-AS', size:'XL', colorName:'Ivory', colorHex:'#F5F0E8', stock:0,  priceInPaise:870000),
        // Blush
        'S__#E8A0A0' : ProductVariant(sku:'PBL-AS-BLS-S-121',  parentId:'PBL-AS', size:'S',  colorName:'Blush', colorHex:'#E8A0A0', stock:2,  priceInPaise:855000),
        'M__#E8A0A0' : ProductVariant(sku:'PBL-AS-BLS-M-122',  parentId:'PBL-AS', size:'M',  colorName:'Blush', colorHex:'#E8A0A0', stock:0,  priceInPaise:855000),
        'L__#E8A0A0' : ProductVariant(sku:'PBL-AS-BLS-L-123',  parentId:'PBL-AS', size:'L',  colorName:'Blush', colorHex:'#E8A0A0', stock:5,  priceInPaise:855000),
        'XL__#E8A0A0': ProductVariant(sku:'PBL-AS-BLS-XL-124', parentId:'PBL-AS', size:'XL', colorName:'Blush', colorHex:'#E8A0A0', stock:3,  priceInPaise:855000),
      },
    ),

    // ── 2. FESTIVE SAREE — MAISON KAIRA ────────────────────────────────────
    

    // ── 3. DENIM JACKET — RAW & REFINED ────────────────────────────────────
    'DJK-RR': ParentProduct(
      id: 'DJK-RR',
      name: 'Distressed Denim Jacket',
      brand: 'RAW & REFINED',
      category: 'Jackets',
      defaultImageUrl:
          'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=600&q=85',
      sizes:  ['XS', 'S', 'M', 'L', 'XL'],
      colors: const [
        VariantColor('Blue Wash',  '#4A90D9'),
        VariantColor('Black',      '#1A1A1A'),
        VariantColor('White',      '#F5F5F5'),
      ],
      variantMap: {
        // Blue Wash
        'XS__#4A90D9': ProductVariant(sku:'DJK-RR-BLU-XS-301', parentId:'DJK-RR', size:'XS', colorName:'Blue Wash', colorHex:'#4A90D9', stock:3,  priceInPaise:599900),
        'S__#4A90D9' : ProductVariant(sku:'DJK-RR-BLU-S-302',  parentId:'DJK-RR', size:'S',  colorName:'Blue Wash', colorHex:'#4A90D9', stock:1,  priceInPaise:599900),
        'M__#4A90D9' : ProductVariant(sku:'DJK-RR-BLU-M-303',  parentId:'DJK-RR', size:'M',  colorName:'Blue Wash', colorHex:'#4A90D9', stock:0,  priceInPaise:599900),
        'L__#4A90D9' : ProductVariant(sku:'DJK-RR-BLU-L-304',  parentId:'DJK-RR', size:'L',  colorName:'Blue Wash', colorHex:'#4A90D9', stock:4,  priceInPaise:599900),
        'XL__#4A90D9': ProductVariant(sku:'DJK-RR-BLU-XL-305', parentId:'DJK-RR', size:'XL', colorName:'Blue Wash', colorHex:'#4A90D9', stock:2,  priceInPaise:599900),
        // Black
        'XS__#1A1A1A': ProductVariant(sku:'DJK-RR-BLK-XS-311', parentId:'DJK-RR', size:'XS', colorName:'Black', colorHex:'#1A1A1A', stock:5,  priceInPaise:629900),
        'S__#1A1A1A' : ProductVariant(sku:'DJK-RR-BLK-S-312',  parentId:'DJK-RR', size:'S',  colorName:'Black', colorHex:'#1A1A1A', stock:2,  priceInPaise:629900),
        'M__#1A1A1A' : ProductVariant(sku:'DJK-RR-BLK-M-313',  parentId:'DJK-RR', size:'M',  colorName:'Black', colorHex:'#1A1A1A', stock:7,  priceInPaise:629900),
        'L__#1A1A1A' : ProductVariant(sku:'DJK-RR-BLK-L-314',  parentId:'DJK-RR', size:'L',  colorName:'Black', colorHex:'#1A1A1A', stock:0,  priceInPaise:629900),
        'XL__#1A1A1A': ProductVariant(sku:'DJK-RR-BLK-XL-315', parentId:'DJK-RR', size:'XL', colorName:'Black', colorHex:'#1A1A1A', stock:3,  priceInPaise:629900),
        // White
        'XS__#F5F5F5': ProductVariant(sku:'DJK-RR-WHT-XS-321', parentId:'DJK-RR', size:'XS', colorName:'White', colorHex:'#F5F5F5', stock:0,  priceInPaise:579900),
        'S__#F5F5F5' : ProductVariant(sku:'DJK-RR-WHT-S-322',  parentId:'DJK-RR', size:'S',  colorName:'White', colorHex:'#F5F5F5', stock:4,  priceInPaise:579900),
        'M__#F5F5F5' : ProductVariant(sku:'DJK-RR-WHT-M-323',  parentId:'DJK-RR', size:'M',  colorName:'White', colorHex:'#F5F5F5', stock:6,  priceInPaise:579900),
        'L__#F5F5F5' : ProductVariant(sku:'DJK-RR-WHT-L-324',  parentId:'DJK-RR', size:'L',  colorName:'White', colorHex:'#F5F5F5', stock:1,  priceInPaise:579900),
        'XL__#F5F5F5': ProductVariant(sku:'DJK-RR-WHT-XL-325', parentId:'DJK-RR', size:'XL', colorName:'White', colorHex:'#F5F5F5', stock:2,  priceInPaise:579900),
      },
    ),

    // ── 4. ETHNIC KURTA SET — INDIRA & CO ──────────────────────────────────
    'VKT-IC': ParentProduct(
      id: 'VKT-IC',
      name: 'Ethnic Silk Kurta Set',
      brand: 'INDIRA & CO',
      category: 'Ethnic',
      defaultImageUrl:
          'https://images.unsplash.com/photo-1566206091558-7f218b696731?w=600&q=85',
      sizes:  ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
      colors: const [
        VariantColor('Saffron', '#FF6F00'),
        VariantColor('Teal',    '#006064'),
        VariantColor('Wine',    '#880E4F'),
      ],
      variantMap: {
        'XS__#FF6F00' : ProductVariant(sku:'VKT-IC-SAF-XS-401', parentId:'VKT-IC', size:'XS',  colorName:'Saffron', colorHex:'#FF6F00', stock:2,  priceInPaise:975000),
        'S__#FF6F00'  : ProductVariant(sku:'VKT-IC-SAF-S-402',  parentId:'VKT-IC', size:'S',   colorName:'Saffron', colorHex:'#FF6F00', stock:5,  priceInPaise:975000),
        'M__#FF6F00'  : ProductVariant(sku:'VKT-IC-SAF-M-403',  parentId:'VKT-IC', size:'M',   colorName:'Saffron', colorHex:'#FF6F00', stock:8,  priceInPaise:975000),
        'L__#FF6F00'  : ProductVariant(sku:'VKT-IC-SAF-L-404',  parentId:'VKT-IC', size:'L',   colorName:'Saffron', colorHex:'#FF6F00', stock:3,  priceInPaise:975000),
        'XL__#FF6F00' : ProductVariant(sku:'VKT-IC-SAF-XL-405', parentId:'VKT-IC', size:'XL',  colorName:'Saffron', colorHex:'#FF6F00', stock:0,  priceInPaise:975000),
        'XXL__#FF6F00': ProductVariant(sku:'VKT-IC-SAF-XXL-406',parentId:'VKT-IC', size:'XXL', colorName:'Saffron', colorHex:'#FF6F00', stock:1,  priceInPaise:975000),
        'XS__#006064' : ProductVariant(sku:'VKT-IC-TEL-XS-411', parentId:'VKT-IC', size:'XS',  colorName:'Teal',    colorHex:'#006064', stock:4,  priceInPaise:975000),
        'S__#006064'  : ProductVariant(sku:'VKT-IC-TEL-S-412',  parentId:'VKT-IC', size:'S',   colorName:'Teal',    colorHex:'#006064', stock:0,  priceInPaise:975000),
        'M__#006064'  : ProductVariant(sku:'VKT-IC-TEL-M-413',  parentId:'VKT-IC', size:'M',   colorName:'Teal',    colorHex:'#006064', stock:6,  priceInPaise:975000),
        'L__#006064'  : ProductVariant(sku:'VKT-IC-TEL-L-414',  parentId:'VKT-IC', size:'L',   colorName:'Teal',    colorHex:'#006064', stock:2,  priceInPaise:975000),
        'XL__#006064' : ProductVariant(sku:'VKT-IC-TEL-XL-415', parentId:'VKT-IC', size:'XL',  colorName:'Teal',    colorHex:'#006064', stock:3,  priceInPaise:975000),
        'XXL__#006064': ProductVariant(sku:'VKT-IC-TEL-XXL-416',parentId:'VKT-IC', size:'XXL', colorName:'Teal',    colorHex:'#006064', stock:0,  priceInPaise:975000),
        'XS__#880E4F' : ProductVariant(sku:'VKT-IC-WIN-XS-421', parentId:'VKT-IC', size:'XS',  colorName:'Wine',    colorHex:'#880E4F', stock:1,  priceInPaise:1020000),
        'S__#880E4F'  : ProductVariant(sku:'VKT-IC-WIN-S-422',  parentId:'VKT-IC', size:'S',   colorName:'Wine',    colorHex:'#880E4F', stock:3,  priceInPaise:1020000),
        'M__#880E4F'  : ProductVariant(sku:'VKT-IC-WIN-M-423',  parentId:'VKT-IC', size:'M',   colorName:'Wine',    colorHex:'#880E4F', stock:0,  priceInPaise:1020000),
        'L__#880E4F'  : ProductVariant(sku:'VKT-IC-WIN-L-424',  parentId:'VKT-IC', size:'L',   colorName:'Wine',    colorHex:'#880E4F', stock:5,  priceInPaise:1020000),
        'XL__#880E4F' : ProductVariant(sku:'VKT-IC-WIN-XL-425', parentId:'VKT-IC', size:'XL',  colorName:'Wine',    colorHex:'#880E4F', stock:2,  priceInPaise:1020000),
        'XXL__#880E4F': ProductVariant(sku:'VKT-IC-WIN-XXL-426',parentId:'VKT-IC', size:'XXL', colorName:'Wine',    colorHex:'#880E4F', stock:4,  priceInPaise:1020000),
      },
    ),

    // ── 5. PRINTED COORD SET — CASA MODAS ──────────────────────────────────
    'COS-CM': ParentProduct(
      id: 'COS-CM',
      name: 'Printed Coord Two-Piece',
      brand: 'CASA MODAS',
      category: 'Co-ords',
      defaultImageUrl:
          'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&q=85',
      sizes:  ['XS', 'S', 'M', 'L', 'XL'],
      colors: const [
        VariantColor('Beige Print',  '#C8B89A'),
        VariantColor('Coral',        '#E8735A'),
        VariantColor('Sage',         '#8FAF88'),
      ],
      variantMap: {
        'XS__#C8B89A': ProductVariant(sku:'COS-CM-BEG-XS-501', parentId:'COS-CM', size:'XS', colorName:'Beige Print', colorHex:'#C8B89A', stock:4,  priceInPaise:750000),
        'S__#C8B89A' : ProductVariant(sku:'COS-CM-BEG-S-502',  parentId:'COS-CM', size:'S',  colorName:'Beige Print', colorHex:'#C8B89A', stock:2,  priceInPaise:750000),
        'M__#C8B89A' : ProductVariant(sku:'COS-CM-BEG-M-503',  parentId:'COS-CM', size:'M',  colorName:'Beige Print', colorHex:'#C8B89A', stock:0,  priceInPaise:750000),
        'L__#C8B89A' : ProductVariant(sku:'COS-CM-BEG-L-504',  parentId:'COS-CM', size:'L',  colorName:'Beige Print', colorHex:'#C8B89A', stock:1,  priceInPaise:750000),
        'XL__#C8B89A': ProductVariant(sku:'COS-CM-BEG-XL-505', parentId:'COS-CM', size:'XL', colorName:'Beige Print', colorHex:'#C8B89A', stock:3,  priceInPaise:750000),
        'XS__#E8735A': ProductVariant(sku:'COS-CM-CRL-XS-511', parentId:'COS-CM', size:'XS', colorName:'Coral',       colorHex:'#E8735A', stock:6,  priceInPaise:750000),
        'S__#E8735A' : ProductVariant(sku:'COS-CM-CRL-S-512',  parentId:'COS-CM', size:'S',  colorName:'Coral',       colorHex:'#E8735A', stock:0,  priceInPaise:750000),
        'M__#E8735A' : ProductVariant(sku:'COS-CM-CRL-M-513',  parentId:'COS-CM', size:'M',  colorName:'Coral',       colorHex:'#E8735A', stock:5,  priceInPaise:750000),
        'L__#E8735A' : ProductVariant(sku:'COS-CM-CRL-L-514',  parentId:'COS-CM', size:'L',  colorName:'Coral',       colorHex:'#E8735A', stock:3,  priceInPaise:750000),
        'XL__#E8735A': ProductVariant(sku:'COS-CM-CRL-XL-515', parentId:'COS-CM', size:'XL', colorName:'Coral',       colorHex:'#E8735A', stock:1,  priceInPaise:750000),
        'XS__#8FAF88': ProductVariant(sku:'COS-CM-SAG-XS-521', parentId:'COS-CM', size:'XS', colorName:'Sage',        colorHex:'#8FAF88', stock:2,  priceInPaise:790000),
        'S__#8FAF88' : ProductVariant(sku:'COS-CM-SAG-S-522',  parentId:'COS-CM', size:'S',  colorName:'Sage',        colorHex:'#8FAF88', stock:4,  priceInPaise:790000),
        'M__#8FAF88' : ProductVariant(sku:'COS-CM-SAG-M-523',  parentId:'COS-CM', size:'M',  colorName:'Sage',        colorHex:'#8FAF88', stock:0,  priceInPaise:790000),
        'L__#8FAF88' : ProductVariant(sku:'COS-CM-SAG-L-524',  parentId:'COS-CM', size:'L',  colorName:'Sage',        colorHex:'#8FAF88', stock:7,  priceInPaise:790000),
        'XL__#8FAF88': ProductVariant(sku:'COS-CM-SAG-XL-525', parentId:'COS-CM', size:'XL', colorName:'Sage',        colorHex:'#8FAF88', stock:3,  priceInPaise:790000),
      },
    ),

    // ── 6. STREET JACKET — DECO NOIR ───────────────────────────────────────
    'STJ-DN': ParentProduct(
      id: 'STJ-DN',
      name: 'Street Oversized Jacket',
      brand: 'DECO NOIR',
      category: 'Outerwear',
      defaultImageUrl:
          'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600&q=85',
      originalPriceFormatted: '₹14,200',
      sizes:  ['S', 'M', 'L', 'XL', 'XXL'],
      colors: const [
        VariantColor('Onyx',   '#1A1A1A'),
        VariantColor('Forest', '#2E4A2E'),
        VariantColor('Stone',  '#9E9E9E'),
      ],
      variantMap: {
        'S__#1A1A1A'  : ProductVariant(sku:'STJ-DN-ONX-S-601',  parentId:'STJ-DN', size:'S',   colorName:'Onyx',   colorHex:'#1A1A1A', stock:3,  priceInPaise:999900),
        'M__#1A1A1A'  : ProductVariant(sku:'STJ-DN-ONX-M-602',  parentId:'STJ-DN', size:'M',   colorName:'Onyx',   colorHex:'#1A1A1A', stock:0,  priceInPaise:999900),
        'L__#1A1A1A'  : ProductVariant(sku:'STJ-DN-ONX-L-603',  parentId:'STJ-DN', size:'L',   colorName:'Onyx',   colorHex:'#1A1A1A', stock:5,  priceInPaise:999900),
        'XL__#1A1A1A' : ProductVariant(sku:'STJ-DN-ONX-XL-604', parentId:'STJ-DN', size:'XL',  colorName:'Onyx',   colorHex:'#1A1A1A', stock:2,  priceInPaise:999900),
        'XXL__#1A1A1A': ProductVariant(sku:'STJ-DN-ONX-XXL-605',parentId:'STJ-DN', size:'XXL', colorName:'Onyx',   colorHex:'#1A1A1A', stock:1,  priceInPaise:999900),
        'S__#2E4A2E'  : ProductVariant(sku:'STJ-DN-FOR-S-611',  parentId:'STJ-DN', size:'S',   colorName:'Forest', colorHex:'#2E4A2E', stock:4,  priceInPaise:999900),
        'M__#2E4A2E'  : ProductVariant(sku:'STJ-DN-FOR-M-612',  parentId:'STJ-DN', size:'M',   colorName:'Forest', colorHex:'#2E4A2E', stock:6,  priceInPaise:999900),
        'L__#2E4A2E'  : ProductVariant(sku:'STJ-DN-FOR-L-613',  parentId:'STJ-DN', size:'L',   colorName:'Forest', colorHex:'#2E4A2E', stock:0,  priceInPaise:999900),
        'XL__#2E4A2E' : ProductVariant(sku:'STJ-DN-FOR-XL-614', parentId:'STJ-DN', size:'XL',  colorName:'Forest', colorHex:'#2E4A2E', stock:3,  priceInPaise:999900),
        'XXL__#2E4A2E': ProductVariant(sku:'STJ-DN-FOR-XXL-615',parentId:'STJ-DN', size:'XXL', colorName:'Forest', colorHex:'#2E4A2E', stock:2,  priceInPaise:999900),
        'S__#9E9E9E'  : ProductVariant(sku:'STJ-DN-STN-S-621',  parentId:'STJ-DN', size:'S',   colorName:'Stone',  colorHex:'#9E9E9E', stock:2,  priceInPaise:979900),
        'M__#9E9E9E'  : ProductVariant(sku:'STJ-DN-STN-M-622',  parentId:'STJ-DN', size:'M',   colorName:'Stone',  colorHex:'#9E9E9E', stock:4,  priceInPaise:979900),
        'L__#9E9E9E'  : ProductVariant(sku:'STJ-DN-STN-L-623',  parentId:'STJ-DN', size:'L',   colorName:'Stone',  colorHex:'#9E9E9E', stock:1,  priceInPaise:979900),
        'XL__#9E9E9E' : ProductVariant(sku:'STJ-DN-STN-XL-624', parentId:'STJ-DN', size:'XL',  colorName:'Stone',  colorHex:'#9E9E9E', stock:0,  priceInPaise:979900),
        'XXL__#9E9E9E': ProductVariant(sku:'STJ-DN-STN-XXL-625',parentId:'STJ-DN', size:'XXL', colorName:'Stone',  colorHex:'#9E9E9E', stock:3,  priceInPaise:979900),
      },
    ),
  };

  /// Fetch a parent product by its id
  static ParentProduct? get(String id) => _catalog[id];

  /// All products
  static List<ParentProduct> get all => _catalog.values.toList();

  /// Build a CartPayload from a fully resolved variant
  static CartPayload buildCartPayload({
    required ParentProduct parent,
    required ProductVariant variant,
    int quantity = 1,
  }) {
    return CartPayload(
      parentId         : parent.id,
      variantSku       : variant.sku,
      productName      : parent.name,
      brand            : parent.brand,
      size             : variant.size,
      colorName        : variant.colorName,
      colorHex         : variant.colorHex,
      quantity         : quantity,
      unitPriceInPaise : variant.priceInPaise,
      imageUrl         : variant.imageUrl ?? parent.defaultImageUrl,
    );
  }
}