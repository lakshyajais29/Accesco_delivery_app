enum ProductGender { men, women, unisex }

class VariantColor {
  final String name;
  final String hex;
  const VariantColor(this.name, this.hex);
}

class ProductVariant {
  final String sku;
  final String parentId;
  final String size;
  final String colorName;
  final String colorHex;
  final int    stock;
  final int    priceInPaise;
  final String? imageUrl;

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

  String get formattedPrice {
    final rupees = priceInPaise ~/ 100;
    final s = rupees.toString();
    if (s.length <= 3) return '₹$s';
    return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  static String key(String size, String colorHex) => '${size}__$colorHex';
  String get mapKey => key(size, colorHex);
}

class ParentProduct {
  final String id;
  final String name;
  final String brand;
  final String category;
  final ProductGender gender;
  final String defaultImageUrl;
  final String description;
  final String? originalPriceFormatted;
  final List<String> sizes;
  final List<VariantColor> colors;
  final Map<String, ProductVariant> variantMap;

  // Feed / FOMO metadata — simulates what FastAPI would return
  final bool   isNew;
  final int    stock;
  final int    cityRank;
  final int    friendVotes;
  final int    viewersNow;
  final int    orderedToday;
  final String? saleEndsAt;
  final int    droppedMinsAgo;
  final String? deliveryCutoff;
  final int    deliveryMinsLeft;

  // ── Resale attributes (Figma node 490:944 "Item") ─────────────────────────
  // The product detail design surfaces marketplace provenance: a condition
  // grade, a verification mark, and the seller behind the listing. All are
  // optional with inert defaults, so every existing `const ParentProduct(...)`
  // in catalog_service.dart keeps compiling untouched and simply renders
  // without these rows.
  final String? conditionGrade;   // 'Grade A' | 'Grade B' | ...
  final String? conditionLabel;   // 'Like New' | 'Gently Used' | ...
  final bool    isVerifiedItem;
  final String? sellerName;
  final double? sellerRating;
  final int     sellerReviewCount;
  final bool    isVerifiedSeller;
  final String? deliveryEta;      // '2 hours'
  final String? deliveryNote;     // 'Express delivery in Gurgaon'
  final String? returnWindow;     // '30 min window'
  final String? returnNote;       // 'Easy return if it doesn't fit'

  const ParentProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.gender,
    required this.defaultImageUrl,
    required this.description,
    required this.sizes,
    required this.colors,
    required this.variantMap,
    this.originalPriceFormatted,
    this.isNew          = false,
    this.stock          = 10,
    this.cityRank       = 0,
    this.friendVotes    = 0,
    this.viewersNow     = 0,
    this.orderedToday   = 0,
    this.saleEndsAt,
    this.droppedMinsAgo = 0,
    this.deliveryCutoff,
    this.deliveryMinsLeft = 0,
    this.conditionGrade,
    this.conditionLabel,
    this.isVerifiedItem = false,
    this.sellerName,
    this.sellerRating,
    this.sellerReviewCount = 0,
    this.isVerifiedSeller = false,
    this.deliveryEta,
    this.deliveryNote,
    this.returnWindow,
    this.returnNote,
  });

  /// Whole-percent saving versus the struck-through original price.
  ///
  /// Returns null when there is no original price, or when the stored values
  /// wouldn't produce a sensible discount — the PDP hides the badge rather
  /// than printing "0% off" or a negative.
  int? get discountPercent {
    final original = originalPriceFormatted;
    if (original == null || variantMap.isEmpty) return null;

    final originalPaise = _paiseFromFormatted(original);
    if (originalPaise == null) return null;

    final currentPaise = variantMap.values
        .map((v) => v.priceInPaise)
        .reduce((a, b) => a < b ? a : b);

    if (originalPaise <= currentPaise) return null;
    return (((originalPaise - currentPaise) / originalPaise) * 100).round();
  }

  /// Parses '₹2,499' back into paise. The catalogue stores the original price
  /// pre-formatted, so the percentage has to be recovered from the string.
  static int? _paiseFromFormatted(String formatted) {
    final digits = formatted.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.parse(digits) * 100;
  }

  ProductVariant? resolve(String size, String colorHex) =>
      variantMap[ProductVariant.key(size, colorHex)];

  List<ProductVariant> variantsForSize(String size) =>
      variantMap.values.where((v) => v.size == size).toList();

  List<ProductVariant> variantsForColor(String colorHex) =>
      variantMap.values.where((v) => v.colorHex == colorHex).toList();

  bool sizeHasStock(String size) =>
      variantsForSize(size).any((v) => v.inStock);

  bool colorHasStock(String colorHex) =>
      variantsForColor(colorHex).any((v) => v.inStock);

  String get lowestPrice {
    if (variantMap.isEmpty) return '—';
    final min = variantMap.values
        .map((v) => v.priceInPaise)
        .reduce((a, b) => a < b ? a : b);
    final s = (min ~/ 100).toString();
    if (s.length <= 3) return '₹$s';
    return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  String get price => lowestPrice;
  String? get salePrice => originalPriceFormatted != null ? lowestPrice : null;
  String get imageUrl => defaultImageUrl;
}

class CartPayload {
  final String parentId;
  final String variantSku;
  final String productName;
  final String brand;
  final String size;
  final String colorName;
  final String colorHex;
  final int    quantity;
  final int    unitPriceInPaise;
  final String imageUrl;

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

// Convenience alias used by catalog_service API surface
typedef ProductModel = ParentProduct;
