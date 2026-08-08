/// Models for the Thrift Marketplace.
///
/// These mirror the Pydantic schemas served by the FastAPI thrift service
/// (`backend/instant_outfit_backend/routers/thrift.py`) field-for-field, so a
/// change on either side shows up as a decode failure rather than a silently
/// missing value.
library;

/// Condition grading for a pre-loved piece. Mirrors the backend enum, and
/// matches the grades the existing thrift marketplace screen already uses.
enum ThriftCondition {
  likeNew,
  gentlyUsed,
  vintageFind;

  /// Parses the wire value, defaulting to [gentlyUsed] for anything
  /// unrecognised so a new backend grade can never crash an older client.
  static ThriftCondition fromJson(String? value) => switch (value) {
        'likeNew' || 'like_new' => ThriftCondition.likeNew,
        'vintageFind' || 'vintage_find' => ThriftCondition.vintageFind,
        _ => ThriftCondition.gentlyUsed,
      };

  /// The exact string the backend expects for this grade.
  String get wireValue => switch (this) {
        ThriftCondition.likeNew => 'likeNew',
        ThriftCondition.gentlyUsed => 'gentlyUsed',
        ThriftCondition.vintageFind => 'vintageFind',
      };

  String get label => switch (this) {
        ThriftCondition.likeNew => 'Like New',
        ThriftCondition.gentlyUsed => 'Gently Used',
        ThriftCondition.vintageFind => 'Vintage Find',
      };
}

/// A single pre-loved item held by a [ThriftStore].
class ThriftItem {
  final String id;
  final String name;
  final String brand;
  final String category;
  final String imageUrl;
  final int priceInPaise;
  final int? originalPriceInPaise;
  final ThriftCondition condition;
  final String size;

  /// Kilograms of CO₂ avoided by buying this piece second-hand.
  final double co2SavedKg;

  const ThriftItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.imageUrl,
    required this.priceInPaise,
    required this.condition,
    required this.size,
    this.originalPriceInPaise,
    this.co2SavedKg = 0,
  });

  factory ThriftItem.fromJson(Map<String, dynamic> json) => ThriftItem(
        id: json['id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String? ?? '',
        category: json['category'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        priceInPaise: (json['price_in_paise'] as num).toInt(),
        originalPriceInPaise:
            (json['original_price_in_paise'] as num?)?.toInt(),
        condition: ThriftCondition.fromJson(json['condition'] as String?),
        size: json['size'] as String? ?? 'One Size',
        co2SavedKg: (json['co2_saved_kg'] as num?)?.toDouble() ?? 0,
      );

  String get formattedPrice => _formatPaise(priceInPaise);

  String? get formattedOriginalPrice => originalPriceInPaise == null
      ? null
      : _formatPaise(originalPriceInPaise!);

  /// Whole-percent saving versus the original retail price, or null when the
  /// item never carried one.
  int? get discountPercent {
    final original = originalPriceInPaise;
    if (original == null || original <= 0 || original <= priceInPaise) {
      return null;
    }
    return (((original - priceInPaise) / original) * 100).round();
  }
}

/// A nearby store surfaced by `/api/v1/thrift/nearby`.
class ThriftStore {
  final String id;
  final String name;
  final String area;
  final String imageUrl;
  final double latitude;
  final double longitude;

  /// Straight-line distance from the requesting user, computed server-side.
  final double distanceKm;

  final double rating;
  final int itemCount;
  final bool isVerified;

  /// A short preview of the store's catalogue — enough to render a rail
  /// without a second round-trip per store.
  final List<ThriftItem> previewItems;

  const ThriftStore({
    required this.id,
    required this.name,
    required this.area,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.rating,
    required this.itemCount,
    this.isVerified = false,
    this.previewItems = const [],
  });

  factory ThriftStore.fromJson(Map<String, dynamic> json) => ThriftStore(
        id: json['id'] as String,
        name: json['name'] as String,
        area: json['area'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        isVerified: json['is_verified'] as bool? ?? false,
        previewItems: (json['preview_items'] as List<dynamic>? ?? [])
            .map((e) => ThriftItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Distance rendered the way a delivery app should: metres under a
  /// kilometre, one decimal above it.
  String get formattedDistance => distanceKm < 1
      ? '${(distanceKm * 1000).round()} m'
      : '${distanceKm.toStringAsFixed(1)} km';
}

String _formatPaise(int paise) {
  final rupees = paise ~/ 100;
  final digits = rupees.toString();
  if (digits.length <= 3) return '₹$digits';
  // Indian digit grouping: last three, then pairs (₹1,23,456).
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '₹${groups.join(',')},$last3';
}

/// Moderation state of a seller submission. Mirrors the backend's status
/// column; unknown values fall back to [pending] so a new server-side state
/// can never crash an older client.
enum ThriftListingStatus {
  pending,
  live,
  sold,
  rejected;

  static ThriftListingStatus fromJson(String? value) => switch (value) {
        'live' => ThriftListingStatus.live,
        'sold' => ThriftListingStatus.sold,
        'rejected' => ThriftListingStatus.rejected,
        _ => ThriftListingStatus.pending,
      };

  String get label => switch (this) {
        ThriftListingStatus.pending => 'In Review',
        ThriftListingStatus.live => 'Live',
        ThriftListingStatus.sold => 'Sold',
        ThriftListingStatus.rejected => 'Rejected',
      };
}

/// What the client sends to `POST /api/v1/thrift/listings`.
///
/// Separate from [ThriftListing] on purpose: a draft has no id, no status and
/// no view counts, because the server owns all three. Sharing one class would
/// invite a client to try setting them.
class ThriftListingDraft {
  final String sellerId;
  final String? sellerName;
  final String title;
  final String? brand;
  final String? category;
  final String? description;
  final String size;
  final ThriftCondition condition;
  final int priceInPaise;
  final int? originalPriceInPaise;
  final List<String> imageUrls;

  const ThriftListingDraft({
    required this.sellerId,
    required this.title,
    required this.priceInPaise,
    this.sellerName,
    this.brand,
    this.category,
    this.description,
    this.size = 'One Size',
    this.condition = ThriftCondition.gentlyUsed,
    this.originalPriceInPaise,
    this.imageUrls = const [],
  });

  Map<String, dynamic> toJson() => {
        'seller_id': sellerId,
        if (sellerName != null) 'seller_name': sellerName,
        'title': title,
        if (brand != null && brand!.isNotEmpty) 'brand': brand,
        if (category != null) 'category': category,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'size': size,
        'condition': condition.wireValue,
        'price_in_paise': priceInPaise,
        if (originalPriceInPaise != null)
          'original_price_in_paise': originalPriceInPaise,
        'image_urls': imageUrls,
      };
}

/// A persisted listing as returned by the server.
class ThriftListing {
  final String id;
  final String sellerId;
  final String? sellerName;
  final String title;
  final String? brand;
  final String? category;
  final String? description;
  final String? size;
  final ThriftCondition condition;
  final int priceInPaise;
  final int? originalPriceInPaise;
  final List<String> imageUrls;
  final ThriftListingStatus status;
  final String? rejectionReason;
  final int views;
  final int likes;

  const ThriftListing({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.priceInPaise,
    required this.condition,
    required this.status,
    this.sellerName,
    this.brand,
    this.category,
    this.description,
    this.size,
    this.originalPriceInPaise,
    this.imageUrls = const [],
    this.rejectionReason,
    this.views = 0,
    this.likes = 0,
  });

  factory ThriftListing.fromJson(Map<String, dynamic> json) => ThriftListing(
        id: json['id'] as String,
        sellerId: json['seller_id'] as String,
        sellerName: json['seller_name'] as String?,
        title: json['title'] as String,
        brand: json['brand'] as String?,
        category: json['category'] as String?,
        description: json['description'] as String?,
        size: json['size'] as String?,
        condition: ThriftCondition.fromJson(json['condition'] as String?),
        priceInPaise: (json['price_in_paise'] as num).toInt(),
        originalPriceInPaise:
            (json['original_price_in_paise'] as num?)?.toInt(),
        imageUrls: (json['image_urls'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        status: ThriftListingStatus.fromJson(json['status'] as String?),
        rejectionReason: json['rejection_reason'] as String?,
        views: (json['views'] as num?)?.toInt() ?? 0,
        likes: (json['likes'] as num?)?.toInt() ?? 0,
      );

  String get formattedPrice => _formatPaise(priceInPaise);
}
