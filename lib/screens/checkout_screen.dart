import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../services/cart_service.dart';
import '../widgets/ds/ds.dart';
import 'trial_at_doorstep_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CHECKOUT — address, slot, payment, confirm.
//
//  Composed from the design system rather than translated from a Figma node:
//  the Checkout frame on Page 2 (490:1187) is a layout stub, and the populated
//  Cart/Checkout screens there belong to the grocery product, not InstaStyle.
//
//  The flow ends on [OrderPlacedScreen], which hands off to the existing
//  Trial-at-Doorstep tracker — that is what InstaStyle's 15-minute delivery
//  promise actually leads to, so checkout should not dead-end in a receipt.
// ─────────────────────────────────────────────────────────────────────────────

/// How the order will be paid for.
enum PaymentMethod { payOnTrial, upi, card, cash }

extension _PaymentPresentation on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.payOnTrial => 'Pay After Trial',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.card => 'Card',
        PaymentMethod.cash => 'Cash on Delivery',
      };

  String get description => switch (this) {
        PaymentMethod.payOnTrial =>
          'Try everything at your door. Pay only for what you keep.',
        PaymentMethod.upi => 'GPay, PhonePe, Paytm or any UPI app',
        PaymentMethod.card => 'Credit or debit card',
        PaymentMethod.cash => 'Pay the rider in cash',
      };

  IconData get icon => switch (this) {
        PaymentMethod.payOnTrial => Icons.checkroom_outlined,
        PaymentMethod.upi => Icons.account_balance_outlined,
        PaymentMethod.card => Icons.credit_card,
        PaymentMethod.cash => Icons.payments_outlined,
      };
}

class CheckoutScreen extends StatefulWidget {
  final List<CartPayload> items;
  final int totalInPaise;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.totalInPaise,
  });

  static Route<void> route({
    required List<CartPayload> items,
    required int totalInPaise,
  }) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            CheckoutScreen(items: items, totalInPaise: totalInPaise),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController(
    text: 'Flat 402, Rosewood Apartments, Jubilee Hills, Hyderabad 500033',
  );

  PaymentMethod _payment = PaymentMethod.payOnTrial;
  int _slotIndex = 0;
  bool _isPlacing = false;
  String _error = '';

  /// Delivery windows. "Express" is the product's headline promise, so it
  /// leads.
  static const _slots = [
    (label: 'Express', detail: 'Within 15 minutes'),
    (label: 'This evening', detail: '6:00 – 8:00 PM'),
    (label: 'Tomorrow', detail: '10:00 AM – 12:00 PM'),
  ];

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.trim().length < 10) {
      setState(() => _error = 'Please enter a complete delivery address.');
      return;
    }

    setState(() {
      _isPlacing = true;
      _error = '';
    });

    try {
      // There is no orders endpoint yet. The bag is cleared so the app's state
      // stays truthful after an order is placed — leaving items behind would
      // imply the order never happened.
      for (final item in widget.items) {
        await CartService.instance.removeItem(item.variantSku);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        OrderPlacedScreen.route(
          itemCount: widget.items.fold<int>(0, (s, i) => s + i.quantity),
          totalInPaise: widget.totalInPaise,
          payment: _payment,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPlacing = false;
        _error = 'Could not place your order. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: Column(
          children: [
            const AppTopBar(title: 'Checkout', serif: true),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  inset,
                  AppSpacing.xs,
                  inset,
                  AppSpacing.xl,
                ),
                children: [
                  // ── Address ────────────────────────────────────────
                  Text('Deliver To'.toUpperCase(), style: AppType.eyebrow),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextField(
                    controller: _addressController,
                    hint: 'Flat, building, area, city, PIN',
                    maxLines: 3,
                    prefixIcon: Icons.location_on_outlined,
                    onChanged: (_) {
                      if (_error.isNotEmpty) setState(() => _error = '');
                    },
                  ),

                  // ── Slot ───────────────────────────────────────────
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Delivery Window'.toUpperCase(),
                    style: AppType.eyebrow,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (var i = 0; i < _slots.length; i++) ...[
                    _SelectableRow(
                      icon: i == 0
                          ? Icons.bolt_outlined
                          : Icons.schedule_outlined,
                      title: _slots[i].label,
                      subtitle: _slots[i].detail,
                      selected: i == _slotIndex,
                      onTap: () => setState(() => _slotIndex = i),
                    ),
                    if (i < _slots.length - 1)
                      const SizedBox(height: AppSpacing.xs),
                  ],

                  // ── Payment ────────────────────────────────────────
                  const SizedBox(height: AppSpacing.xl),
                  Text('Payment'.toUpperCase(), style: AppType.eyebrow),
                  const SizedBox(height: AppSpacing.sm),
                  for (var i = 0; i < PaymentMethod.values.length; i++) ...[
                    _SelectableRow(
                      icon: PaymentMethod.values[i].icon,
                      title: PaymentMethod.values[i].label,
                      subtitle: PaymentMethod.values[i].description,
                      selected: PaymentMethod.values[i] == _payment,
                      onTap: () => setState(
                        () => _payment = PaymentMethod.values[i],
                      ),
                    ),
                    if (i < PaymentMethod.values.length - 1)
                      const SizedBox(height: AppSpacing.xs),
                  ],

                  // ── Order recap ────────────────────────────────────
                  const SizedBox(height: AppSpacing.xl),
                  Text('Your Order'.toUpperCase(), style: AppType.eyebrow),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    color: AppPalette.surfaceWarm,
                    bordered: false,
                    child: Column(
                      children: [
                        for (final item in widget.items) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.productName} · ${item.size}'
                                  '${item.quantity > 1 ? ' ×${item.quantity}' : ''}',
                                  style: AppType.bodyMedium.copyWith(
                                    color: AppPalette.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                _formatPaise(item.totalInPaise),
                                style: AppType.price,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        const AppDivider(),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'To pay',
                                style: AppType.titleMedium,
                              ),
                            ),
                            Text(
                              _formatPaise(widget.totalInPaise),
                              style: AppType.priceLarge.copyWith(fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Place order ──────────────────────────────────────────
            Container(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 15,
                          color: AppPalette.danger,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _error,
                            style: AppType.bodySmall.copyWith(
                              color: AppPalette.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppButton(
                    label: _payment == PaymentMethod.payOnTrial
                        ? 'Place Order · Pay Later'
                        : 'Pay ${_formatPaise(widget.totalInPaise)}',
                    isLoading: _isPlacing,
                    onPressed: _placeOrder,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A radio-style row used for both delivery slots and payment methods.
class _SelectableRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppPalette.accentSoft : AppPalette.surface,
            borderRadius: AppRadii.field,
            border: Border.all(
              color: selected ? AppPalette.accent : AppPalette.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? AppPalette.accentDeep
                    : AppPalette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppType.titleSmall.copyWith(
                        color: selected
                            ? AppPalette.accentDeep
                            : AppPalette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppType.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color:
                    selected ? AppPalette.accent : AppPalette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Order confirmation. Leads into the live trial tracker rather than ending
/// on a receipt.
class OrderPlacedScreen extends StatelessWidget {
  final int itemCount;
  final int totalInPaise;
  final PaymentMethod payment;

  const OrderPlacedScreen({
    super.key,
    required this.itemCount,
    required this.totalInPaise,
    required this.payment,
  });

  static Route<void> route({
    required int itemCount,
    required int totalInPaise,
    required PaymentMethod payment,
  }) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => OrderPlacedScreen(
          itemCount: itemCount,
          totalInPaise: totalInPaise,
          payment: payment,
        ),
        transitionDuration: AppMotion.slow,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final payLater = payment == PaymentMethod.payOnTrial;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: SafeArea(
          child: AppStateView.success(
            title: 'Order placed',
            message: payLater
                ? '$itemCount ${itemCount == 1 ? 'piece is' : 'pieces are'} on '
                    'the way. Try everything at your door and pay only for '
                    'what you keep.'
                : '$itemCount ${itemCount == 1 ? 'piece is' : 'pieces are'} on '
                    'the way. ${_formatPaise(totalInPaise)} paid via '
                    '${payment.label}.',
            actionLabel: 'Track Delivery',
            onAction: () => Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => TrialAtDoorstepScreen(
                  orderId: 'ORDER123',
                  riderId: 'RIDER456',
                ),
                transitionDuration: AppMotion.normal,
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
              ),
            ),
            secondaryActionLabel: 'Back to Home',
            onSecondaryAction: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
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
