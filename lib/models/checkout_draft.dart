import 'product_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CHECKOUT DRAFT — the single input to the checkout pipeline.
//
//  Every path that can start a purchase (the Cart tab's Checkout button, a
//  product page's Buy Now, an outfit builder "order the look") builds one of
//  these and hands it to CheckoutScreen. Nothing else varies between those
//  paths: the screen, the pricing, the Razorpay call and the order write are
//  identical downstream.
//
//  Pricing lives here rather than in the calling screen. When it lived in
//  cart_screen the delivery-fee rule only applied to the cart path, so a
//  Buy Now would have silently charged a different total for the same goods.
// ─────────────────────────────────────────────────────────────────────────────

/// Where the purchase was started from. Recorded on the order so the funnel
/// is answerable later; it never changes how the payment is taken.
enum CheckoutSource { cart, buyNow, outfit, trial }

extension CheckoutSourceLabel on CheckoutSource {
  String get wireName => switch (this) {
        CheckoutSource.cart => 'cart',
        CheckoutSource.buyNow => 'buy_now',
        CheckoutSource.outfit => 'outfit',
        CheckoutSource.trial => 'trial',
      };
}

class CheckoutDraft {
  /// The lines being bought. Never empty — [CheckoutDraft.fromCart] is the
  /// only constructor that can receive an empty list and it is guarded at the
  /// call site by the cart's own empty state.
  final List<CartPayload> items;

  final CheckoutSource source;

  const CheckoutDraft._({required this.items, required this.source});

  /// The whole bag. Everything checked out here leaves the cart on success.
  factory CheckoutDraft.fromCart(List<CartPayload> items) =>
      CheckoutDraft._(items: List.unmodifiable(items), source: CheckoutSource.cart);

  /// One item, bought directly from a product page. The item may or may not
  /// also be sitting in the cart; [skusToClear] handles both cases.
  factory CheckoutDraft.buyNow(CartPayload item) =>
      CheckoutDraft._(items: List.unmodifiable([item]), source: CheckoutSource.buyNow);

  /// A composed look ordered as a unit.
  factory CheckoutDraft.outfit(List<CartPayload> items) =>
      CheckoutDraft._(items: List.unmodifiable(items), source: CheckoutSource.outfit);

  // ── Pricing, in paise throughout ───────────────────────────────────────
  //
  // Rupees are produced only at the point of display, so no rounding ever
  // enters the arithmetic that Razorpay is asked to charge.

  /// Free delivery above this. Mirrors the threshold the trial flow quotes.
  static const int freeDeliveryThresholdInPaise = 149900;

  /// Flat fee below the threshold.
  static const int deliveryFeeInPaise = 4900;

  int get subtotalInPaise =>
      items.fold<int>(0, (sum, i) => sum + i.totalInPaise);

  int get deliveryInPaise =>
      subtotalInPaise >= freeDeliveryThresholdInPaise ? 0 : deliveryFeeInPaise;

  int get totalInPaise => subtotalInPaise + deliveryInPaise;

  /// How much more the shopper needs to spend for free delivery, or 0 when
  /// they are already over the line.
  int get toFreeDeliveryInPaise {
    final gap = freeDeliveryThresholdInPaise - subtotalInPaise;
    return gap > 0 ? gap : 0;
  }

  /// Units, not lines — "3 items" counts a quantity-3 line as three.
  int get itemCount => items.fold<int>(0, (sum, i) => sum + i.quantity);

  bool get isEmpty => items.isEmpty;

  /// The cart rows to delete once payment succeeds.
  ///
  /// Deliberately the checked-out SKUs rather than a blanket wipe: if the
  /// shopper added something on another device while the Razorpay sheet was
  /// open, that item is not part of this order and must survive it.
  List<String> get skusToClear =>
      items.map((i) => i.variantSku).toList(growable: false);

  /// The order lines as written to Firestore and sent to the backend.
  List<Map<String, dynamic>> get lineItemsJson =>
      items.map((i) => i.toJson()).toList(growable: false);

  /// A short human-readable description for the Razorpay sheet.
  String get paymentDescription {
    if (items.length == 1) {
      final only = items.first;
      return '${only.brand} ${only.productName}'.trim();
    }
    return '$itemCount ${itemCount == 1 ? 'piece' : 'pieces'} · InstaStyle';
  }
}
