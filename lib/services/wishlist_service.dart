import '../models/product_model.dart';

class WishlistService {
  // Singleton pattern initialization
  static final WishlistService instance = WishlistService._internal();
  WishlistService._internal();

  final List<ParentProduct> _items = [];

  // Expose an unmodifiable list to prevent accidental overwrites from the UI
  List<ParentProduct> get items => List.unmodifiable(_items);

  bool contains(ParentProduct product) {
    return _items.any((item) => item.id == product.id);
  }

  void toggle(ParentProduct product) {
    if (contains(product)) {
      _items.removeWhere((item) => item.id == product.id);
    } else {
      _items.add(product);
    }
  }
}