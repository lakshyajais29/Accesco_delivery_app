import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/checkout_draft.dart';
import '../models/product_model.dart';
import '../services/cart_service.dart';
import '../widgets/ds/ds.dart';
import 'checkout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CART — the bag, before checkout.
//
//  Reads [CartService.streamItems], so the list stays live against Firestore
//  and reflects an add made on any other screen without a manual refresh.
//
//  Provenance: Figma's Cart frame (538:874) belongs to the grocery product on
//  Page 2 — milk, atta, reusable-packaging returns — not to InstaStyle. This
//  is therefore composed from the design system rather than translated from
//  that node, which would have imported the wrong product's layout and its
//  green palette.
// ─────────────────────────────────────────────────────────────────────────────

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static Route<void> route() => PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CartScreen(),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: Column(
          children: [
            const AppTopBar(title: 'My Bag', serif: true),
            Expanded(
              child: StreamBuilder<List<CartPayload>>(
                stream: CartService.instance.streamItems(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoader(message: 'Loading your bag');
                  }

                  if (snapshot.hasError) {
                    // Most often the "not signed in" StateError CartService
                    // throws when there is no authenticated user.
                    return AppStateView.error(
                      title: 'Can\'t load your bag',
                      message: 'Please sign in to see the items you\'ve '
                          'added.',
                      onAction: () => Navigator.of(context).maybePop(),
                      actionLabel: 'Go Back',
                    );
                  }

                  final items = snapshot.data ?? const <CartPayload>[];
                  if (items.isEmpty) {
                    return AppStateView.empty(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Your bag is empty',
                      message: 'Pieces you add will collect here, ready to '
                          'try at your door.',
                      actionLabel: 'Start Browsing',
                      onAction: () => Navigator.of(context).maybePop(),
                    );
                  }

                  return _CartBody(items: items);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBody extends StatelessWidget {
  final List<CartPayload> items;

  const _CartBody({required this.items});

  /// The bag as the checkout pipeline sees it.
  ///
  /// The arithmetic used to live here, which meant the delivery-fee rule
  /// only applied to purchases that started in the cart. It belongs to the
  /// draft now, so every entry point quotes the same total the gateway is
  /// asked to charge.
  CheckoutDraft get _draft => CheckoutDraft.fromCart(items);

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final draft = _draft;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              inset,
              AppSpacing.xs,
              inset,
              AppSpacing.lg,
            ),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              if (i == items.length) return _OrderSummary(draft: draft);
              return _CartRow(item: items[i]);
            },
          ),
        ),
        _CheckoutBar(
          totalInPaise: draft.totalInPaise,
          itemCount: draft.itemCount,
          onCheckout: () => Navigator.push(
            context,
            CheckoutScreen.route(draft: draft),
          ),
        ),
      ],
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartPayload item;

  const _CartRow({required this.item});

  Future<void> _remove(BuildContext context) async {
    final confirmed = await showAppDialog(
      context,
      icon: Icons.delete_outline,
      title: 'Remove from bag?',
      message: '${item.productName} will be taken out of your bag.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await CartService.instance.removeItem(item.variantSku);
      if (context.mounted) {
        AppSnack.show(context, '${item.productName} removed');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnack.error(context, 'Could not remove that item.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            url: item.imageUrl,
            width: 64,
            height: 78,
            cacheWidth: 160,
            borderRadius: AppRadii.image,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: AppType.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.close,
                      size: 16,
                      tooltip: 'Remove',
                      onPressed: () => _remove(context),
                    ),
                  ],
                ),
                Text(
                  item.brand,
                  style: AppType.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _Attribute(label: item.size),
                    const SizedBox(width: AppSpacing.xs),
                    _Attribute(label: item.colorName),
                    const SizedBox(width: AppSpacing.xs),
                    _Attribute(label: '×${item.quantity}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatPaise(item.totalInPaise),
                  style: AppType.price.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small neutral pill for size / colour / quantity.
class _Attribute extends StatelessWidget {
  final String label;

  const _Attribute({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted,
        borderRadius: AppRadii.badge,
      ),
      child: Text(
        label,
        style: AppType.badge.copyWith(
          color: AppPalette.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final CheckoutDraft draft;

  const _OrderSummary({required this.draft});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        color: AppPalette.surfaceWarm,
        bordered: false,
        child: Column(
          children: [
            _SummaryRow(
              label: 'Item total',
              value: _formatPaise(draft.subtotalInPaise),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: 'Delivery',
              value: draft.deliveryInPaise == 0
                  ? 'FREE'
                  : _formatPaise(draft.deliveryInPaise),
              highlight: draft.deliveryInPaise == 0,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: AppDivider(),
            ),
            _SummaryRow(
              label: 'To pay',
              value: _formatPaise(draft.totalInPaise),
              emphasised: true,
            ),
            if (draft.deliveryInPaise > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 13,
                    color: AppPalette.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      'Add ${_formatPaise(draft.toFreeDeliveryInPaise)} more '
                      'for free delivery',
                      style: AppType.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasised;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasised = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasised
                ? AppType.titleMedium
                : AppType.bodyMedium.copyWith(
                    color: AppPalette.textSecondary,
                  ),
          ),
        ),
        Text(
          value,
          style: emphasised
              ? AppType.priceLarge.copyWith(fontSize: 18)
              : AppType.price.copyWith(
                  color: highlight
                      ? AppPalette.success
                      : AppPalette.textPrimary,
                ),
        ),
      ],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final int totalInPaise;
  final int itemCount;
  final VoidCallback onCheckout;

  const _CheckoutBar({
    required this.totalInPaise,
    required this.itemCount,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
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
                '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                style: AppType.bodySmall,
              ),
              Text(
                _formatPaise(totalInPaise),
                style: AppType.priceLarge.copyWith(fontSize: 19),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppButton(
              label: 'Checkout',
              icon: Icons.arrow_forward,
              trailingIcon: true,
              onPressed: onCheckout,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats paise with Indian digit grouping (₹1,23,456).
String _formatPaise(int paise) {
  final rupees = paise ~/ 100;
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
