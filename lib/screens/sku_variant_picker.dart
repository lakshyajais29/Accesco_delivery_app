import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/ds/ds.dart';
import 'sku_catalog.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VARIANT PICKER — size / colour / quantity selection before adding to bag.
//
//  The availability rules are the originals: choosing a colour narrows which
//  sizes are in stock and vice versa, unavailable options stay visible but
//  struck through, and the CTA only enables once the pair resolves to a real
//  in-stock SKU.
// ─────────────────────────────────────────────────────────────────────────────

/// What the resolved SKU is wanted for. Only changes the CTA wording — the
/// selection rules and the payload it produces are identical, which is what
/// lets Buy Now and Add to Bag share this sheet instead of forking it.
enum VariantPickerIntent { addToBag, buyNow }

/// Public entry point. [onAddToCart] is still the only required callback, so
/// existing callers keep working unchanged.
class VariantPickerSheet {
  const VariantPickerSheet._();

  static void show(
    BuildContext context, {
    required ParentProduct parent,
    required void Function(CartPayload) onAddToCart,
    VariantPickerIntent intent = VariantPickerIntent.addToBag,
  }) {
    showAppSheet<void>(
      context,
      child: _PickerSheet(
        parent: parent,
        onAddToCart: onAddToCart,
        intent: intent,
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final ParentProduct parent;
  final void Function(CartPayload) onAddToCart;
  final VariantPickerIntent intent;

  const _PickerSheet({
    required this.parent,
    required this.onAddToCart,
    required this.intent,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String? _selectedSize;
  String? _selectedColorHex;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    // Pre-select the first colour that has stock, so the sheet opens on a
    // usable option rather than an empty state.
    if (widget.parent.colors.isNotEmpty) {
      _selectedColorHex = widget.parent.colors
          .firstWhere(
            (c) => widget.parent.colorHasStock(c.hex),
            orElse: () => widget.parent.colors.first,
          )
          .hex;
    }
  }

  // ── Derived state ─────────────────────────────────────────────────────
  ProductVariant? get _variant {
    if (_selectedSize == null || _selectedColorHex == null) return null;
    return widget.parent.resolve(_selectedSize!, _selectedColorHex!);
  }

  bool get _canAdd => _variant != null && _variant!.inStock;

  bool _sizeAvailable(String size) {
    if (_selectedColorHex == null) return widget.parent.sizeHasStock(size);
    final variant = widget.parent.resolve(size, _selectedColorHex!);
    return variant != null && variant.inStock;
  }

  bool _colorAvailable(String hex) {
    if (_selectedSize == null) return widget.parent.colorHasStock(hex);
    final variant = widget.parent.resolve(_selectedSize!, hex);
    return variant != null && variant.inStock;
  }

  String get _priceLabel =>
      _variant?.formattedPrice ?? widget.parent.lowestPrice;

  void _addToCart() {
    final variant = _variant;
    if (variant == null || !variant.inStock) return;
    HapticFeedback.mediumImpact();

    final payload = SkuCatalog.buildCartPayload(
      parent: widget.parent,
      variant: variant,
      quantity: _qty,
    );

    // Dismiss before handing off, not after. A Buy Now callback pushes the
    // checkout route synchronously, and popping afterwards would take that
    // new route straight back off the stack.
    Navigator.pop(context);
    widget.onAddToCart(payload);
  }

  String get _ctaVerb => switch (widget.intent) {
        VariantPickerIntent.addToBag => 'Add to Bag',
        VariantPickerIntent.buyNow => 'Buy Now',
      };

  /// Prompt shown on the disabled CTA, naming whichever choice is still
  /// outstanding rather than a generic "unavailable".
  String get _ctaLabel {
    if (_canAdd) return '$_ctaVerb · $_priceLabel';
    if (_selectedColorHex == null) return 'Select a Colour';
    if (_selectedSize == null) return 'Select a Size';
    return 'Unavailable';
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final parent = widget.parent;
    final variant = _variant;

    return AppSheet(
      title: parent.name,
      subtitle: parent.brand,
      footer: AppButton(
        label: _ctaLabel,
        icon: widget.intent == VariantPickerIntent.buyNow
            ? Icons.bolt_outlined
            : Icons.shopping_bag_outlined,
        onPressed: _canAdd ? _addToCart : null,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            inset,
            AppSpacing.md,
            inset,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Preview ───────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppImage(
                    url: variant?.imageUrl ?? parent.defaultImageUrl,
                    width: 76,
                    height: 92,
                    borderRadius: AppRadii.image,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(_priceLabel, style: AppType.priceLarge),
                            if (parent.originalPriceFormatted != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                parent.originalPriceFormatted!,
                                style: AppType.priceStrike,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (variant != null)
                          _StockLine(stock: variant.stock)
                        else
                          Text(
                            'Choose a size and colour to see availability',
                            style: AppType.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Colour ────────────────────────────────────────────────
              if (parent.colors.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel(
                  label: 'Colour',
                  value: parent.colors
                      .where((c) => c.hex == _selectedColorHex)
                      .map((c) => c.name)
                      .firstOrNull,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final color in parent.colors)
                      AppColorSwatch(
                        color: _parseHex(color.hex),
                        selected: color.hex == _selectedColorHex,
                        available: _colorAvailable(color.hex),
                        onTap: () => setState(
                          () => _selectedColorHex = color.hex,
                        ),
                      ),
                  ],
                ),
              ],

              // ── Size ──────────────────────────────────────────────────
              if (parent.sizes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel(label: 'Size', value: _selectedSize),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final size in parent.sizes)
                      AppChip(
                        label: size,
                        selected: size == _selectedSize,
                        disabled: !_sizeAvailable(size),
                        onTap: () => setState(() => _selectedSize = size),
                      ),
                  ],
                ),
              ],

              // ── Quantity ──────────────────────────────────────────────
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: _SectionLabel(label: 'Quantity')),
                  _QuantityStepper(
                    value: _qty,
                    // Never let the user pick more than is actually in stock.
                    max: variant?.stock ?? 1,
                    onChanged: (value) => setState(() => _qty = value),
                  ),
                ],
              ),

              // ── SKU ───────────────────────────────────────────────────
              if (variant != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('SKU · ${variant.sku}', style: AppType.mono),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Parses a `#RRGGBB` / `RRGGBB` swatch value, falling back to the muted
/// surface rather than throwing if catalogue data is malformed.
Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return AppPalette.surfaceMuted;
  return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? value;

  const _SectionLabel({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: AppType.eyebrow),
        if (value != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              value!,
              style: AppType.label.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _StockLine extends StatelessWidget {
  final int stock;

  const _StockLine({required this.stock});

  @override
  Widget build(BuildContext context) {
    if (stock <= 0) {
      return const AppSignalTag(
        icon: Icons.remove_circle_outline,
        label: 'Out of stock',
        color: AppPalette.danger,
      );
    }
    if (stock < 4) {
      return AppSignalTag(
        icon: Icons.local_fire_department_outlined,
        label: 'Only $stock left',
        color: AppPalette.danger,
      );
    }
    return const AppSignalTag(
      icon: Icons.check_circle_outline,
      label: 'In stock',
      color: AppPalette.success,
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > 1;
    final canIncrease = value < max;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.chip,
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconButton(
            icon: Icons.remove,
            size: 17,
            onPressed: canDecrease ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppType.titleMedium,
            ),
          ),
          AppIconButton(
            icon: Icons.add,
            size: 17,
            onPressed: canIncrease ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
