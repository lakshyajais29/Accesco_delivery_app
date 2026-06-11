// sku_variant_picker.dart
// Professional product variant picker — Amazon / Myntra / Adidas style
// Dark theme matching ThriftMarketplace

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sku_catalog.dart';

// ─── THEME ───────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF1A130A);   // dark warm
  static const sheet     = Color(0xFF231A0E);   // card bg
  static const surface   = Color(0xFF2E2212);   // elevated surface
  static const divider   = Color(0xFF3A2E20);
  static const tan       = Color(0xFFC4913A);
  static const tanLight  = Color(0xFFDDB96A);
  static const offWhite  = Color(0xFFF2E9D6);
  static const grey400   = Color(0xFF9E8E78);
  static const grey500   = Color(0xFF7A6A56);
  static const grey600   = Color(0xFF5A4A38);
  static const green     = Color(0xFF4CAF50);
  static const red       = Color(0xFFC0392B);
  static const amber     = Color(0xFFFF8F00);
  static const skuText   = Color(0xFF5A4A38);
}

TextStyle _dsp(double s, {Color c = _C.offWhite, double sp = 0}) =>
    GoogleFonts.bebasNeue(fontSize: s, color: c, letterSpacing: sp);
TextStyle _lbl(double s, {Color c = _C.offWhite, FontWeight fw = FontWeight.w600, double sp = 0.3}) =>
    GoogleFonts.jost(fontSize: s, color: c, fontWeight: fw, letterSpacing: sp);
TextStyle _bod(double s, {Color c = _C.grey400}) =>
    GoogleFonts.jost(fontSize: s, color: c, fontWeight: FontWeight.w400);
TextStyle _mon(double s, {Color c = _C.skuText}) =>
    GoogleFonts.robotoMono(fontSize: s, color: c, fontWeight: FontWeight.w400, letterSpacing: 0.3);

// ─── PUBLIC API ───────────────────────────────────────────────────────────────
class VariantPickerSheet {
  static void show(
    BuildContext context, {
    required ParentProduct parent,
    required void Function(CartPayload) onAddToCart,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PickerSheet(parent: parent, onAddToCart: onAddToCart),
    );
  }
}

// ─── PICKER SHEET ─────────────────────────────────────────────────────────────
class _PickerSheet extends StatefulWidget {
  final ParentProduct parent;
  final void Function(CartPayload) onAddToCart;
  const _PickerSheet({required this.parent, required this.onAddToCart});
  @override State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedSize;
  String? _selectedColorHex;
  int     _qty = 1;

  late final AnimationController _ctaCtrl;
  late final Animation<double>   _ctaScale;

  @override
  void initState() {
    super.initState();
    // Auto-select first in-stock color
    _selectedColorHex = widget.parent.colors
        .firstWhere(
          (c) => widget.parent.colorHasStock(c.hex),
          orElse: () => widget.parent.colors.first,
        )
        .hex;
    _ctaCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _ctaScale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctaCtrl, curve: Curves.easeIn));
  }

  @override void dispose() { _ctaCtrl.dispose(); super.dispose(); }

  // ── Derived ────────────────────────────────────────────────────────────────
  ProductVariant? get _variant {
    if (_selectedSize == null || _selectedColorHex == null) return null;
    return widget.parent.resolve(_selectedSize!, _selectedColorHex!);
  }

  bool get _canAdd => _variant != null && _variant!.inStock;

  bool _sizeAvail(String size) {
    if (_selectedColorHex == null) return widget.parent.sizeHasStock(size);
    final v = widget.parent.resolve(size, _selectedColorHex!);
    return v != null && v.inStock;
  }

  bool _colorAvail(String hex) {
    if (_selectedSize == null) return widget.parent.colorHasStock(hex);
    final v = widget.parent.resolve(_selectedSize!, hex);
    return v != null && v.inStock;
  }

  String get _priceStr {
    final v = _variant;
    if (v != null) return v.formattedPrice;
    return widget.parent.lowestPrice;
  }

  void _addToCart() {
    final v = _variant;
    if (v == null || !v.inStock) return;
    HapticFeedback.mediumImpact();
    final payload = SkuCatalog.buildCartPayload(
      parent: widget.parent, variant: v, quantity: _qty);
    widget.onAddToCart(payload);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
      decoration: const BoxDecoration(
        color: _C.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Drag handle ──────────────────────────────────────────────────────
        Center(child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36, height: 3,
          decoration: BoxDecoration(color: _C.grey600, borderRadius: BorderRadius.circular(2)),
        )),

        // ── Scrollable content ───────────────────────────────────────────────
        Flexible(child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: mq.padding.bottom + 100),
          physics: const BouncingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeader(),
            _buildDivider(),
            _buildColorSection(),
            _buildDivider(),
            _buildSizeSection(),
            _buildDivider(),
            _buildQtyRow(),
            _buildSkuRow(),
          ]),
        )),

        // ── Sticky CTA ───────────────────────────────────────────────────────
        _buildCTA(mq),
      ]),
    );
  }

  // ── HEADER — product image + name + price ──────────────────────────────────
  Widget _buildHeader() {
    final v = _variant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            v?.imageUrl ?? widget.parent.defaultImageUrl,
            width: 80, height: 88, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(width: 80, height: 88, color: _C.surface),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Brand
          Text(widget.parent.brand,
              style: _bod(10, c: _C.grey400), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          // Product name
          Text(widget.parent.name,
              style: _lbl(14, c: _C.offWhite, sp: 0),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          // Price — updates live when variant resolves
          Text(_priceStr,
              style: GoogleFonts.bebasNeue(fontSize: 26, color: _C.tan, letterSpacing: 0.5)),
          // Stock badge when variant resolved
          if (_variant != null) ...[
            const SizedBox(height: 6),
            _StockBadge(variant: _variant!),
          ],
        ])),
        // Close button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.close, size: 16, color: _C.grey400),
          ),
        ),
      ]),
    );
  }

  // ── COLOUR SECTION ────────────────────────────────────────────────────────
  Widget _buildColorSection() {
    final colors = widget.parent.colors;
    final selected = colors.firstWhere(
      (c) => c.hex == _selectedColorHex,
      orElse: () => colors.first,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label row — "COLOUR  Black"
        Row(children: [
          Text('COLOUR', style: _lbl(11, c: _C.grey400, sp: 1.2)),
          const SizedBox(width: 8),
          Text(selected.name, style: _lbl(11, c: _C.offWhite, sp: 0)),
        ]),
        const SizedBox(height: 14),
        // Colour swatches
        Wrap(spacing: 10, runSpacing: 10, children: colors.map((col) {
          final isSelected = _selectedColorHex == col.hex;
          final avail = _colorAvail(col.hex);
          final hexColor = _hexToColor(col.hex);

          return GestureDetector(
            onTap: avail ? () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedColorHex = col.hex;
                // Clear size if no longer valid for new colour
                if (_selectedSize != null) {
                  final v = widget.parent.resolve(_selectedSize!, col.hex);
                  if (v == null || !v.inStock) _selectedSize = null;
                }
              });
            } : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hexColor,
                border: isSelected
                    ? Border.all(color: _C.tan, width: 2.5)
                    : Border.all(color: _C.grey600, width: 1),
                boxShadow: isSelected ? [
                  BoxShadow(color: _C.tan.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                ] : null,
              ),
              child: avail
                  ? (isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null)
                  : CustomPaint(painter: _CrossPainter()),
            ),
          );
        }).toList()),
      ]),
    );
  }

  // ── SIZE SECTION — Myntra-style chips ─────────────────────────────────────
  Widget _buildSizeSection() {
    final sizes = widget.parent.sizes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label row
        Row(children: [
          Text('SIZE', style: _lbl(11, c: _C.grey400, sp: 1.2)),
          if (_selectedSize != null) ...[
            const SizedBox(width: 8),
            Text(_selectedSize!, style: _lbl(11, c: _C.offWhite, sp: 0)),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: Row(children: [
              const Icon(Icons.straighten_outlined, size: 13, color: _C.tan),
              const SizedBox(width: 4),
              Text('Size guide', style: _lbl(10, c: _C.tan, sp: 0)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        // Size chips
        Wrap(spacing: 8, runSpacing: 8, children: sizes.map((size) {
          final isSelected = _selectedSize == size;
          final avail = _sizeAvail(size);
          return GestureDetector(
            onTap: avail ? () {
              HapticFeedback.selectionClick();
              setState(() => _selectedSize = size);
            } : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minWidth: 48),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? _C.tan : _C.surface,
                border: Border.all(
                  color: isSelected ? _C.tan : (avail ? _C.grey600 : _C.grey600),
                  width: isSelected ? 0 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: Stack(alignment: Alignment.center, children: [
                Text(size,
                  style: _lbl(13,
                    c: isSelected ? _C.bg : (avail ? _C.offWhite : _C.grey500),
                    sp: 0),
                ),
                // Strikethrough line for sold-out sizes
                if (!avail)
                  Positioned.fill(child: CustomPaint(painter: _StrikethroughPainter())),
              ])),
            ),
          );
        }).toList()),
      ]),
    );
  }

  // ── QTY ROW ───────────────────────────────────────────────────────────────
  Widget _buildQtyRow() {
    final maxQty = _variant?.stock ?? 10;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(children: [
        Text('QTY', style: _lbl(11, c: _C.grey400, sp: 1.2)),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _C.grey600),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _qtyBtn(Icons.remove, () { if (_qty > 1) setState(() => _qty--); }),
            Container(
              width: 40, height: 36,
              alignment: Alignment.center,
              child: Text('$_qty', style: _lbl(14, c: _C.offWhite, sp: 0)),
            ),
            _qtyBtn(Icons.add, () { if (_qty < maxQty) setState(() => _qty++); }),
          ]),
        ),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      color: _C.surface,
      child: Icon(icon, size: 16, color: _C.offWhite),
    ),
  );

  // ── SKU ROW — visible only when variant resolved ───────────────────────────
  Widget _buildSkuRow() {
    final v = _variant;
    if (v == null) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Clipboard.setData(ClipboardData(text: v.sku));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('SKU ${v.sku} copied',
                style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white)),
            backgroundColor: _C.bg,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ));
        },
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.qr_code, size: 10, color: _C.skuText),
          const SizedBox(width: 5),
          Text(v.sku, style: _mon(8.5)),
          const SizedBox(width: 5),
          const Icon(Icons.copy_outlined, size: 9, color: _C.skuText),
        ]),
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(height: 1, thickness: 0.5, color: _C.divider);

  // ── STICKY ADD TO CART CTA ────────────────────────────────────────────────
  Widget _buildCTA(MediaQueryData mq) {
    return Container(
      decoration: BoxDecoration(
        color: _C.sheet,
        border: Border(top: BorderSide(color: _C.divider, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, mq.padding.bottom + 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Prompt line when incomplete
        if (!_canAdd && _selectedColorHex != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 13, color: _C.amber),
              const SizedBox(width: 6),
              Text(
                _selectedSize == null ? 'Select a size to continue' : 'This combination is sold out',
                style: _bod(12, c: _C.amber),
              ),
            ]),
          ),
        // CTA button
        GestureDetector(
          onTapDown: _canAdd ? (_) => _ctaCtrl.forward() : null,
          onTapUp: _canAdd ? (_) { _ctaCtrl.reverse(); _addToCart(); } : null,
          onTapCancel: () => _ctaCtrl.reverse(),
          child: ScaleTransition(
            scale: _ctaScale,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: _canAdd ? _C.tan : _C.grey600,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _canAdd ? Icons.shopping_bag_outlined : Icons.block,
                  size: 18, color: _canAdd ? _C.bg : _C.grey400,
                ),
                const SizedBox(width: 10),
                Text(
                  _canAdd ? 'ADD TO CART' : 'SELECT SIZE',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    color: _canAdd ? _C.bg : _C.grey400,
                    letterSpacing: 2,
                  ),
                ),
              ])),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── STOCK BADGE ──────────────────────────────────────────────────────────────
class _StockBadge extends StatelessWidget {
  final ProductVariant variant;
  const _StockBadge({required this.variant});

  @override
  Widget build(BuildContext context) {
    if (!variant.inStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF2A0A08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _C.red.withOpacity(0.4), width: 0.5),
        ),
        child: Text('SOLD OUT',
            style: GoogleFonts.jost(fontSize: 10, fontWeight: FontWeight.w700,
                color: _C.red, letterSpacing: 0.5)),
      );
    }
    if (variant.stock <= 3) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
          decoration: const BoxDecoration(color: _C.amber, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('Only ${variant.stock} left',
            style: GoogleFonts.jost(fontSize: 11, fontWeight: FontWeight.w600,
                color: _C.amber)),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
        decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('In stock',
          style: GoogleFonts.jost(fontSize: 11, fontWeight: FontWeight.w600,
              color: _C.green)),
    ]);
  }
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────
Color _hexToColor(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

// Diagonal cross for sold-out colour swatches
class _CrossPainter extends CustomPainter {
  @override void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white.withOpacity(0.55)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    c.drawLine(Offset(s.width * 0.22, s.height * 0.22), Offset(s.width * 0.78, s.height * 0.78), p);
    c.drawLine(Offset(s.width * 0.78, s.height * 0.22), Offset(s.width * 0.22, s.height * 0.78), p);
  }
  @override bool shouldRepaint(_) => false;
}

// Horizontal strikethrough line for sold-out size chips
class _StrikethroughPainter extends CustomPainter {
  @override void paint(Canvas c, Size s) {
    c.drawLine(Offset(4, s.height / 2), Offset(s.width - 4, s.height / 2),
      Paint()..color = _C.grey500..strokeWidth = 1.0..style = PaintingStyle.stroke);
  }
  @override bool shouldRepaint(_) => false;
}