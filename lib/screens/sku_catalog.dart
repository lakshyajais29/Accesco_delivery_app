// Re-exports the canonical models and catalog service.
// Import this file wherever you previously used sku_catalog.dart.
export '../models/product_model.dart';
export '../services/catalog_service.dart';

// Legacy alias kept for sku_variant_picker.dart compatibility
// SkuCatalog now delegates to CatalogService.
import '../models/product_model.dart';
import '../services/catalog_service.dart';

class SkuCatalog {
  SkuCatalog._();

  static ParentProduct? get(String id) => CatalogService.getById(id);
  static List<ParentProduct> get all => CatalogService.getAll();

  static CartPayload buildCartPayload({
    required ParentProduct parent,
    required ProductVariant variant,
    int quantity = 1,
  }) => CatalogService.buildCartPayload(
        parent: parent, variant: variant, quantity: quantity);
}
