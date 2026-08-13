import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cart_service.dart';
import '../widgets/ds/ds.dart';
import 'sku_catalog.dart'; // ── SKU ── catalogue + CartPayload

// ─────────────────────────────────────────────────────────────────────────────
//  INSTANT OUTFIT BUILDER — the "Build" tab.
//
//  Three steps, then a live canvas:
//    1. Occasion   — where are you going
//    2. Persona    — how do you want to read
//    3. Building   — curation beat
//    4. The Look   — an editable look board
//
//  The look board carries the three interactions this feature is built around:
//    • Layered stacking — the pieces compose into one overlapping board, with
//      z-order driven by the slot list.
//    • Drag and drop    — dragging a slot reorders that layering.
//    • Selectable grid  — tapping a slot opens its alternatives to swap.
//
//  Provenance: Page 2 of the Figma file contains no Instant Outfit Builder
//  design — the only keyword matches there belong to other products. This is
//  therefore composed entirely from the design system: cream canvas, flat
//  surfaces, Playfair display over Inter, hairline rules.
//
//  The SKU → CartPayload resolution and the CartService.addItems call are the
//  originals, unchanged: this screen still puts real, variant-resolved items
//  in the bag.
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════
// SKU INTEGRATION (unchanged)
// Resolves a catalogue parentId to a concrete child-variant CartPayload using
// the first in-stock variant as the silent default selection. Falls back to a
// synthesized payload when the parent isn't in SkuCatalog yet.
// ═══════════════════════════════════════════════════════════════════════════
CartPayload _skuPayloadFor({
  required String? parentId,
  required String name,
  required String brand,
  required int unitPriceInPaise,
  required String imageUrl,
  int quantity = 1,
}) {
  if (parentId != null) {
    final parent = SkuCatalog.get(parentId);
    if (parent != null && parent.variantMap.isNotEmpty) {
      ProductVariant? picked;
      for (final v in parent.variantMap.values) {
        if (v.inStock) {
          picked = v;
          break;
        }
      }
      picked ??= parent.variantMap.values.first; // graceful OOS fallback

      return SkuCatalog.buildCartPayload(
        parent: parent,
        variant: picked,
        quantity: quantity,
      );
      // The variant carries its own authoritative priceInPaise; the price
      // shown on screen is cosmetic.
    }
  }

  // Fallback: parentId missing or not in the catalogue yet.
  return CartPayload(
    parentId: parentId ?? name,
    variantSku: '${parentId ?? 'SKU'}-DEFAULT',
    productName: name,
    brand: brand,
    size: 'One Size',
    colorName: '—',
    colorHex: '#888888',
    quantity: quantity,
    unitPriceInPaise: unitPriceInPaise,
    imageUrl: imageUrl,
  );
}

// ─── Phases ──────────────────────────────────────────────────────────────────
enum _Phase { occasion, persona, building, look }

extension _PhasePresentation on _Phase {
  String get title => switch (this) {
        _Phase.occasion => 'Where to?',
        _Phase.persona => 'Your persona',
        _Phase.building => 'Building your look',
        _Phase.look => 'Your complete look',
      };

  String get subtitle => switch (this) {
        _Phase.occasion =>
          'InstaStyle assembles the whole outfit — delivered in minutes.',
        _Phase.persona => 'Pick the register you want to read in.',
        _Phase.building => 'Matching pieces to your sizes and taste.',
        _Phase.look =>
          'Drag to relayer. Tap any piece to swap it for another.',
      };

  /// Step index for the progress rail. The building beat shares the persona
  /// step — it is a transition, not a decision.
  int get step => switch (this) {
        _Phase.occasion => 0,
        _Phase.persona || _Phase.building => 1,
        _Phase.look => 2,
      };
}

// ─── Models ──────────────────────────────────────────────────────────────────
class _Occasion {
  final String label;
  final IconData icon;

  const _Occasion(this.label, this.icon);
}

class _Persona {
  final String label;
  final String sub;
  final String imageUrl;

  const _Persona(this.label, this.sub, this.imageUrl);
}

class _OutfitItem {
  final String slot;
  final String name;
  final String brand;
  final String price;
  final int priceInt;
  final String imageUrl;
  final List<_AltItem> alternatives;

  /// Links this slot to SkuCatalog. Survives a swap — the alternatives are
  /// styling variations of the same catalogue parent.
  final String? parentId;

  const _OutfitItem({
    required this.slot,
    required this.name,
    required this.brand,
    required this.price,
    required this.priceInt,
    required this.imageUrl,
    required this.alternatives,
    this.parentId,
  });

  _OutfitItem withPick(_AltItem alt) => _OutfitItem(
        slot: slot,
        name: alt.name,
        brand: brand,
        price: alt.price,
        priceInt: _rupeesFrom(alt.price),
        imageUrl: alt.imageUrl,
        alternatives: alternatives,
        parentId: parentId,
      );
}

class _AltItem {
  final String name;
  final String price;
  final String imageUrl;

  const _AltItem(this.name, this.price, this.imageUrl);
}

/// '₹4,800' → 4800. Alternatives carry only a formatted price, so the integer
/// the cart needs has to be recovered from it.
int _rupeesFrom(String formatted) =>
    int.tryParse(formatted.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Formats rupees with Indian digit grouping.
String _formatRupees(int rupees) {
  final digits = rupees.toString();
  if (digits.length <= 3) return '₹$digits';
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

// ─── Data ────────────────────────────────────────────────────────────────────
const _occasions = <_Occasion>[
  _Occasion('Wedding Guest', Icons.celebration_outlined),
  _Occasion('First Date', Icons.favorite_outline),
  _Occasion('Office', Icons.work_outline),
  _Occasion('Night Out', Icons.nightlife_outlined),
  _Occasion('Festival', Icons.music_note_outlined),
  _Occasion('Casual', Icons.wb_sunny_outlined),
];

const _personas = <_Persona>[
  _Persona(
    'Classic',
    'Timeless & refined',
    'https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=600&q=85',
  ),
  _Persona(
    'Bold',
    'Make a statement',
    'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=600&q=85',
  ),
  _Persona(
    'Minimal',
    'Clean & effortless',
    'https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=600&q=85',
  ),
];

const _seedOutfit = <_OutfitItem>[
  _OutfitItem(
    slot: 'Top',
    name: 'Silk Wrap Blouse',
    brand: 'ATELIER SUR',
    price: '₹4,200',
    priceInt: 4200,
    parentId: 'PBL-AS',
    imageUrl:
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400&q=85',
    alternatives: [
      _AltItem('Elegant Lace Gown', '₹4,800',
          'https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=400&q=85'),
      _AltItem('Royal Evening Dress', '₹5,600',
          'https://images.unsplash.com/photo-1618244972963-dbee1a7edc95?w=400&q=85'),
      _AltItem('Classic Purple Maxi', '₹3,900',
          'https://images.unsplash.com/photo-1554568218-0f1715e72254?w=400&q=85'),
    ],
  ),
  _OutfitItem(
    slot: 'Bottom',
    name: 'High-waist Palazzo',
    brand: 'INDIRA & CO',
    price: '₹3,800',
    priceInt: 3800,
    parentId: 'VKT-IC',
    imageUrl:
        'https://images.unsplash.com/photo-1506629082955-511b1aa562c8?w=400&q=85',
    alternatives: [
      _AltItem('Midi Skirt', '₹2,999',
          'https://images.unsplash.com/photo-1583496661160-fb5886a0aaaa?w=400&q=85'),
      _AltItem('Flared Jeans', '₹3,200',
          'https://images.unsplash.com/photo-1604176354204-9268737828e4?w=400&q=85'),
      _AltItem('Cigarette Pants', '₹2,700',
          'https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?w=400&q=85'),
    ],
  ),
  _OutfitItem(
    slot: 'Shoes',
    name: 'Block Heel Mules',
    brand: 'CASA MODAS',
    price: '₹6,500',
    priceInt: 6500,
    parentId: 'COS-CM',
    imageUrl:
        'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400&q=85',
    alternatives: [
      _AltItem('Strappy Sandals', '₹4,200',
          'https://images.unsplash.com/photo-1603487742131-4160ec999306?w=400&q=85'),
      _AltItem('White Sneakers', '₹3,500',
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&q=85'),
      _AltItem('Ballet Flats', '₹2,800',
          'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&q=85'),
    ],
  ),
  _OutfitItem(
    slot: 'Accessory',
    name: 'Structured Mini Bag',
    brand: 'DECO NOIR',
    price: '₹8,900',
    priceInt: 8900,
    parentId: 'STJ-DN',
    imageUrl:
        'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&q=85',
    alternatives: [
      _AltItem('Canvas Tote', '₹3,999',
          'https://images.unsplash.com/photo-1591561954557-26941169b49e?w=400&q=85'),
      _AltItem('Clutch Purse', '₹5,200',
          'https://images.unsplash.com/photo-1566150905458-1bf1fc113f0d?w=400&q=85'),
      _AltItem('Crossbody', '₹4,700',
          'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=400&q=85'),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class InstantOutfitBuilderScreen extends StatefulWidget {
  const InstantOutfitBuilderScreen({super.key});

  static Route<void> route() => PageRouteBuilder(
        pageBuilder: (_, __, ___) => const InstantOutfitBuilderScreen(),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<InstantOutfitBuilderScreen> createState() =>
      _InstantOutfitBuilderScreenState();
}

class _InstantOutfitBuilderScreenState
    extends State<InstantOutfitBuilderScreen> {
  _Phase _phase = _Phase.occasion;

  int? _occasionIndex;
  int? _personaIndex;

  /// The working look. Order is both the display order and the z-order on the
  /// board, which is what makes dragging meaningful.
  List<_OutfitItem> _items = List<_OutfitItem>.of(_seedOutfit);

  /// Slot currently expanded to show its alternatives, by index.
  int? _expandedSlot;

  bool _isAddingToBag = false;

  int get _total => _items.fold<int>(0, (sum, item) => sum + item.priceInt);

  // ── Flow ──────────────────────────────────────────────────────────────
  void _selectOccasion(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _occasionIndex = index;
      _phase = _Phase.persona;
    });
  }

  Future<void> _selectPersona(int index) async {
    HapticFeedback.selectionClick();
    setState(() {
      _personaIndex = index;
      _phase = _Phase.building;
    });

    // A deliberate beat so the curation reads as considered rather than
    // instant. No network call sits behind this yet.
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    setState(() {
      _items = List<_OutfitItem>.of(_seedOutfit);
      _expandedSlot = null;
      _phase = _Phase.look;
    });
  }

  void _handleBack() {
    switch (_phase) {
      case _Phase.occasion:
        Navigator.of(context).maybePop();
      case _Phase.persona:
        setState(() => _phase = _Phase.occasion);
      case _Phase.building:
        break; // Not interruptible — it resolves on its own.
      case _Phase.look:
        setState(() {
          _phase = _Phase.persona;
          _expandedSlot = null;
        });
    }
  }

  void _restart() {
    setState(() {
      _phase = _Phase.occasion;
      _occasionIndex = null;
      _personaIndex = null;
      _items = List<_OutfitItem>.of(_seedOutfit);
      _expandedSlot = null;
    });
  }

  // ── Board interactions ────────────────────────────────────────────────
  void _toggleSlot(int index) {
    HapticFeedback.selectionClick();
    setState(() => _expandedSlot = _expandedSlot == index ? null : index);
  }

  void _swap(int index, _AltItem alt) {
    HapticFeedback.lightImpact();
    setState(() {
      _items[index] = _items[index].withPick(alt);
      _expandedSlot = null;
    });
  }

  /// Reorders the layering. The list order *is* the z-order on the board, so
  /// this is the drag-and-drop interaction rather than cosmetic sorting.
  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      // ReorderableListView reports the target as if the dragged row were
      // still occupying its old position.
      final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final moved = _items.removeAt(oldIndex);
      _items.insert(target, moved);
      _expandedSlot = null;
    });
    HapticFeedback.mediumImpact();
  }

  // ── Bag ───────────────────────────────────────────────────────────────
  Future<void> _addLookToBag() async {
    if (_isAddingToBag) return;
    setState(() => _isAddingToBag = true);

    final payloads = _items
        .map(
          (item) => _skuPayloadFor(
            parentId: item.parentId,
            name: item.name,
            brand: item.brand,
            unitPriceInPaise: item.priceInt * 100,
            imageUrl: item.imageUrl,
          ),
        )
        .toList();

    try {
      await CartService.instance.addItems(payloads);
      if (!mounted) return;
      AppSnack.success(context, '${payloads.length} pieces added to your bag');
    } catch (error) {
      debugPrint('CartService.addItems failed: $error');
      if (!mounted) return;
      // Most often the "not signed in" StateError from CartService.
      AppSnack.error(context, 'Could not add the look. Please try again.');
    } finally {
      if (mounted) setState(() => _isAddingToBag = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.normal,
                  switchInCurve: AppMotion.enter,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_phase),
                    child: switch (_phase) {
                      _Phase.occasion => _buildOccasionStep(),
                      _Phase.persona => _buildPersonaStep(),
                      _Phase.building => const _BuildingStep(),
                      _Phase.look => _buildLookStep(),
                    },
                  ),
                ),
              ),
              if (_phase == _Phase.look) _buildBagBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final inset = AppSpacing.page(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset - AppSpacing.xs,
        AppSpacing.xs,
        inset,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconButton(
                icon: Icons.arrow_back,
                onPressed: _phase == _Phase.building ? null : _handleBack,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Outfit Builder',
                  style: AppType.displaySmall.copyWith(fontSize: 20),
                ),
              ),
              if (_phase == _Phase.look)
                AppIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Start over',
                  onPressed: _restart,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress rail — three decisions, one bar.
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: AppMotion.normal,
                      curve: AppMotion.standard,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= _phase.step
                            ? AppPalette.accent
                            : AppPalette.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: AppSpacing.xxs),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _phase.title,
                  style: AppType.displayLarge.responsive(context).copyWith(
                        fontSize: 30,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(_phase.subtitle, style: AppType.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1 — occasion ─────────────────────────────────────────────────
  Widget _buildOccasionStep() {
    final inset = AppSpacing.page(context);

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        inset,
        AppSpacing.xs,
        inset,
        AppSpacing.safeBottom(context, extra: AppSpacing.xl),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppBreakpoints.isTablet(context) ? 3 : 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.15,
      ),
      itemCount: _occasions.length,
      itemBuilder: (context, i) {
        final occasion = _occasions[i];
        final selected = _occasionIndex == i;

        return GestureDetector(
          onTap: () => _selectOccasion(i),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? AppPalette.accentSoft : AppPalette.surface,
              borderRadius: AppRadii.card,
              border: Border.all(
                color: selected ? AppPalette.accent : AppPalette.line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppPalette.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    occasion.icon,
                    size: 18,
                    color: AppPalette.accentDeep,
                  ),
                ),
                Text(
                  occasion.label,
                  style: AppType.displaySmall.copyWith(fontSize: 17),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Step 2 — persona ──────────────────────────────────────────────────
  Widget _buildPersonaStep() {
    final inset = AppSpacing.page(context);

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        inset,
        AppSpacing.xs,
        inset,
        AppSpacing.safeBottom(context, extra: AppSpacing.xl),
      ),
      itemCount: _personas.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final persona = _personas[i];

        return GestureDetector(
          onTap: () => _selectPersona(i),
          child: ClipRRect(
            borderRadius: AppRadii.card,
            child: SizedBox(
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(url: persona.imageUrl, cacheWidth: 700),
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppPalette.photoScrim),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          persona.label,
                          style: AppType.displayMedium.copyWith(
                            color: AppPalette.textOnDark,
                          ),
                        ),
                        Text(
                          persona.sub,
                          style: AppType.bodySmall.copyWith(
                            color: AppPalette.textOnDark.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Step 4 — the look ─────────────────────────────────────────────────
  Widget _buildLookStep() {
    final inset = AppSpacing.page(context);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(inset, AppSpacing.xs, inset, AppSpacing.lg),
      children: [
        // Reminds the user what this look was built for, and doubles as a way
        // back into either decision without losing the board.
        Row(
          children: [
            if (_occasionIndex != null)
              AppChip(
                label: _occasions[_occasionIndex!].label,
                icon: _occasions[_occasionIndex!].icon,
                onTap: () => setState(() => _phase = _Phase.occasion),
              ),
            if (_personaIndex != null) ...[
              const SizedBox(width: AppSpacing.xs),
              AppChip(
                label: _personas[_personaIndex!].label,
                onTap: () => setState(() => _phase = _Phase.persona),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _LookBoard(items: _items),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: Text('The Pieces'.toUpperCase(), style: AppType.eyebrow),
            ),
            const Icon(
              Icons.drag_indicator,
              size: 14,
              color: AppPalette.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text('Drag to relayer', style: AppType.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // ReorderableListView inside a ListView needs to size itself; it also
        // provides the drag handles that drive the board's z-order.
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _items.length,
          onReorder: _reorder,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (context, i) {
            final item = _items[i];
            return Padding(
              key: ValueKey('${item.slot}-${item.name}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SlotCard(
                item: item,
                index: i,
                layer: _items.length - i,
                isExpanded: _expandedSlot == i,
                onTap: () => _toggleSlot(i),
                onSwap: (alt) => _swap(i, alt),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBagBar() {
    final inset = AppSpacing.page(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        inset,
        AppSpacing.sm,
        inset,
        AppSpacing.safeBottom(context, extra: AppSpacing.sm),
      ),
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(top: BorderSide(color: AppPalette.line)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_items.length} pieces',
                style: AppType.bodySmall,
              ),
              // Animates so a swap visibly moves the total rather than
              // silently changing it.
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: _total, end: _total),
                duration: AppMotion.normal,
                builder: (context, value, _) => Text(
                  _formatRupees(value),
                  style: AppType.priceLarge.copyWith(fontSize: 19),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppButton(
              label: 'Add Look to Bag',
              icon: Icons.shopping_bag_outlined,
              isLoading: _isAddingToBag,
              onPressed: _addLookToBag,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOOK BOARD — the layered composition.
//
//  Pieces are laid out as an overlapping fan. The first item in the list sits
//  on top, so reordering the list below visibly restacks the board. Offsets
//  are computed from the index rather than hard-coded, so the board holds its
//  composition at any item count.
// ─────────────────────────────────────────────────────────────────────────────
class _LookBoard extends StatelessWidget {
  final List<_OutfitItem> items;

  const _LookBoard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: AppPalette.bannerWash,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppPalette.lineWarm),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = items.length;
          if (count == 0) return const SizedBox.shrink();

          final cardWidth = constraints.maxWidth * 0.38;
          final cardHeight = cardWidth * 1.3;

          // Spread the fan across the available width, keeping it centred
          // whatever the count.
          final span = constraints.maxWidth - cardWidth - AppSpacing.xxl;
          final step = count > 1 ? span / (count - 1) : 0.0;
          final startX = AppSpacing.lg;

          return Stack(
            children: [
              // Painted back-to-front: the last list item is drawn first so
              // the first ends up on top.
              for (var i = count - 1; i >= 0; i--)
                Positioned(
                  left: startX + (step * i),
                  top: (constraints.maxHeight - cardHeight) / 2 +
                      // Slight vertical drift gives the fan its diagonal.
                      (i.isEven ? -AppSpacing.sm : AppSpacing.sm),
                  child: _BoardCard(
                    item: items[i],
                    width: cardWidth,
                    height: cardHeight,
                    isTop: i == 0,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final _OutfitItem item;
  final double width;
  final double height;
  final bool isTop;

  const _BoardCard({
    required this.item,
    required this.width,
    required this.height,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadii.image,
        border: Border.all(
          color: isTop ? AppPalette.accent : AppPalette.line,
          width: isTop ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(url: item.imageUrl, cacheWidth: 300),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              color: AppPalette.inkA70,
              child: Text(
                item.slot.toUpperCase(),
                style: AppType.badge.copyWith(color: AppPalette.textOnDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SLOT CARD — one piece, with its alternatives grid.
// ─────────────────────────────────────────────────────────────────────────────
class _SlotCard extends StatelessWidget {
  final _OutfitItem item;
  final int index;
  final int layer;
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<_AltItem> onSwap;

  const _SlotCard({
    required this.item,
    required this.index,
    required this.layer,
    required this.isExpanded,
    required this.onTap,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadii.card,
        border: Border.all(
          color: isExpanded ? AppPalette.accent : AppPalette.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  // The drag handle is explicit rather than long-press: the
                  // rest of the row already has a tap action, and a hidden
                  // long-press would collide with it.
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: AppPalette.textTertiary,
                      ),
                    ),
                  ),
                  AppImage(
                    url: item.imageUrl,
                    width: 52,
                    height: 62,
                    cacheWidth: 140,
                    borderRadius: AppRadii.image,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.slot.toUpperCase(),
                              style: AppType.eyebrow.copyWith(
                                color: AppPalette.accent,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            AppBadge(
                              'Layer $layer',
                              tone: AppBadgeTone.neutral,
                              soft: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.name,
                          style: AppType.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.brand,
                          style: AppType.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.price, style: AppType.price),
                      const SizedBox(height: AppSpacing.xxs),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: AppMotion.fast,
                        child: const Icon(
                          Icons.expand_more,
                          size: 18,
                          color: AppPalette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Alternatives grid ──────────────────────────────────────
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    children: [
                      const AppDivider(),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Swap for'.toUpperCase(),
                              style: AppType.eyebrow,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            SizedBox(
                              height: 128,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: item.alternatives.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: AppSpacing.xs),
                                itemBuilder: (context, i) => _AlternativeTile(
                                  alt: item.alternatives[i],
                                  onTap: () => onSwap(item.alternatives[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AlternativeTile extends StatelessWidget {
  final _AltItem alt;
  final VoidCallback onTap;

  const _AlternativeTile({required this.alt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppImage(
              url: alt.imageUrl,
              width: 84,
              height: 84,
              cacheWidth: 200,
              borderRadius: AppRadii.image,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              alt.name,
              style: AppType.bodySmall.copyWith(
                color: AppPalette.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(alt.price, style: AppType.price.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BUILDING — the curation beat.
// ─────────────────────────────────────────────────────────────────────────────
class _BuildingStep extends StatelessWidget {
  const _BuildingStep();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppPalette.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Assembling your look',
              style: AppType.displaySmall.responsive(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Matching pieces to your sizes, your persona and what\'s in '
              'stock near you.',
              style: AppType.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
