// Checkout pricing.
//
// Every purchase path in the app — the Cart tab, Buy Now, an ordered outfit —
// now prices itself through CheckoutDraft, and the figure it produces is the
// one handed to Razorpay. That makes this arithmetic the single most
// consequential pure-Dart logic in the app, so it is pinned here rather than
// exercised only through a screen that needs Firebase to build.

import 'package:flutter_test/flutter_test.dart';

import 'package:instastyle/models/checkout_draft.dart';
import 'package:instastyle/models/product_model.dart';

CartPayload _item({
  String sku = 'SKU-1',
  int unitPriceInPaise = 100000,
  int quantity = 1,
}) {
  return CartPayload(
    parentId: 'P1',
    variantSku: sku,
    productName: 'Linen Shirt',
    brand: 'InstaStyle',
    size: 'M',
    colorName: 'Ecru',
    colorHex: '#EFE7DC',
    quantity: quantity,
    unitPriceInPaise: unitPriceInPaise,
    imageUrl: 'https://example.test/shirt.jpg',
  );
}

void main() {
  group('CheckoutDraft pricing', () {
    test('charges delivery below the free threshold', () {
      // ₹1,000 — under the ₹1,499 line.
      final draft = CheckoutDraft.fromCart([_item(unitPriceInPaise: 100000)]);

      expect(draft.subtotalInPaise, 100000);
      expect(draft.deliveryInPaise, CheckoutDraft.deliveryFeeInPaise);
      expect(draft.totalInPaise, 104900);
    });

    test('delivery is free at the threshold, not just above it', () {
      final draft = CheckoutDraft.fromCart([
        _item(unitPriceInPaise: CheckoutDraft.freeDeliveryThresholdInPaise),
      ]);

      expect(draft.deliveryInPaise, 0);
      expect(
        draft.totalInPaise,
        CheckoutDraft.freeDeliveryThresholdInPaise,
      );
    });

    test('quantity multiplies into the subtotal', () {
      final draft = CheckoutDraft.fromCart([
        _item(unitPriceInPaise: 50000, quantity: 3),
      ]);

      expect(draft.subtotalInPaise, 150000);
      expect(draft.itemCount, 3);
      // 1,500 > 1,499, so this crosses into free delivery.
      expect(draft.deliveryInPaise, 0);
    });

    test('Buy Now prices identically to the same item in the cart', () {
      // The regression this whole refactor exists to prevent: pricing used to
      // live in cart_screen, so a direct purchase skipped the delivery rule.
      final item = _item(unitPriceInPaise: 79900);

      final viaCart = CheckoutDraft.fromCart([item]);
      final viaBuyNow = CheckoutDraft.buyNow(item);

      expect(viaBuyNow.subtotalInPaise, viaCart.subtotalInPaise);
      expect(viaBuyNow.deliveryInPaise, viaCart.deliveryInPaise);
      expect(viaBuyNow.totalInPaise, viaCart.totalInPaise);
    });

    test('reports the gap to free delivery, and never a negative one', () {
      final under = CheckoutDraft.fromCart([_item(unitPriceInPaise: 100000)]);
      expect(under.toFreeDeliveryInPaise, 49900);

      final over = CheckoutDraft.fromCart([_item(unitPriceInPaise: 200000)]);
      expect(over.toFreeDeliveryInPaise, 0);
    });
  });

  group('CheckoutDraft cart clearing', () {
    test('clears exactly the SKUs that were bought', () {
      final draft = CheckoutDraft.fromCart([
        _item(sku: 'SKU-A'),
        _item(sku: 'SKU-B'),
      ]);

      // Not a blanket wipe: anything added elsewhere while the payment sheet
      // was open is not part of this order and must survive it.
      expect(draft.skusToClear, ['SKU-A', 'SKU-B']);
    });

    test('a Buy Now clears only its own SKU', () {
      final draft = CheckoutDraft.buyNow(_item(sku: 'SKU-C'));
      expect(draft.skusToClear, ['SKU-C']);
    });
  });

  group('CheckoutDraft source', () {
    test('records where the purchase started, for the funnel', () {
      expect(CheckoutDraft.fromCart([_item()]).source.wireName, 'cart');
      expect(CheckoutDraft.buyNow(_item()).source.wireName, 'buy_now');
      expect(CheckoutDraft.outfit([_item()]).source.wireName, 'outfit');
    });

    test('describes a single item by name and a bundle by count', () {
      expect(
        CheckoutDraft.buyNow(_item()).paymentDescription,
        'InstaStyle Linen Shirt',
      );
      expect(
        CheckoutDraft.fromCart([
          _item(sku: 'SKU-A'),
          _item(sku: 'SKU-B'),
        ]).paymentDescription,
        '2 pieces · InstaStyle',
      );
    });
  });
}
