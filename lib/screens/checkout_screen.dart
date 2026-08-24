import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../models/checkout_draft.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';
import '../widgets/ds/ds.dart';
import 'order_success_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CHECKOUT — the single payment pipeline.
//
//  Every purchase in the app arrives here: the Cart tab's Checkout button, a
//  product page's Buy Now, an ordered outfit. They differ only in the
//  [CheckoutDraft] they build; from this screen down, one code path takes the
//  money, writes the order and clears the bag. That is deliberate — the
//  expensive bugs in a payments flow are the ones that live in the *second*
//  implementation of it.
//
//  Lifecycle notes, because Razorpay is unusually easy to leak:
//    • The Razorpay instance is created once in initState and cleared in
//      dispose. `clear()` removes the three registered handlers; without it
//      the SDK holds this State alive and a second visit to checkout gets
//      duplicate callbacks — one paid order, two Firestore writes.
//    • Its callbacks arrive from a platform channel and can land after the
//      route is gone, so every one of them re-checks `mounted` before it
//      touches state or the Navigator.
//    • The post-payment work (verify, write, clear cart) runs behind a
//      blocking overlay and a re-entrancy guard. The window between "Razorpay
//      said yes" and "the order exists" is the one place a double tap costs
//      real money.
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

  /// Whether this method opens the Razorpay sheet.
  bool get isPrepaid =>
      this == PaymentMethod.upi || this == PaymentMethod.card;

  /// Value stored on the order document.
  String get wireName => switch (this) {
        PaymentMethod.payOnTrial => 'pay_after_trial',
        PaymentMethod.upi => 'razorpay_upi',
        PaymentMethod.card => 'razorpay_card',
        PaymentMethod.cash => 'cod',
      };

  /// Razorpay's own name for the method, used to open the sheet on the right
  /// tab instead of the generic list.
  String? get razorpayMethod => switch (this) {
        PaymentMethod.upi => 'upi',
        PaymentMethod.card => 'card',
        _ => null,
      };
}

/// What the screen is currently doing. Drives the button, the overlay and
/// every re-entrancy guard, so there is one answer rather than four booleans
/// that can disagree.
enum _Stage {
  /// Waiting on the shopper.
  idle,

  /// Asking our backend for a Razorpay order id.
  creatingOrder,

  /// The Razorpay sheet is up. We are a spectator until a callback fires.
  awaitingGateway,

  /// Verifying, writing the order, clearing the bag.
  finalising,
}

class CheckoutScreen extends StatefulWidget {
  final CheckoutDraft draft;

  const CheckoutScreen({super.key, required this.draft});

  static Route<void> route({required CheckoutDraft draft}) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => CheckoutScreen(draft: draft),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  /// Convenience entry points, so a caller never has to remember which
  /// [CheckoutDraft] constructor pairs with which screen.
  static Route<void> fromCart(List<CartPayload> items) =>
      route(draft: CheckoutDraft.fromCart(items));

  static Route<void> buyNow(CartPayload item) =>
      route(draft: CheckoutDraft.buyNow(item));

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController(
    text: 'Flat 402, Rosewood Apartments, Jubilee Hills, Hyderabad 500033',
  );

  /// Created in initState, cleared in dispose. Never re-created: a second
  /// instance would register a second set of handlers on the same channel.
  late final Razorpay _razorpay;

  PaymentMethod _payment = PaymentMethod.payOnTrial;
  int _slotIndex = 0;
  _Stage _stage = _Stage.idle;
  String _error = '';

  /// The order currently open at the gateway. Held so the success callback —
  /// which only carries ids — can be reconciled against what we asked for.
  RazorpayOrder? _pendingOrder;

  CheckoutDraft get _draft => widget.draft;

  bool get _isBusy => _stage != _Stage.idle;

  /// Delivery windows. "Express" is the product's headline promise, so it
  /// leads.
  static const _slots = [
    (label: 'Express', detail: 'Within 15 minutes'),
    (label: 'This evening', detail: '6:00 – 8:00 PM'),
    (label: 'Tomorrow', detail: '10:00 AM – 12:00 PM'),
  ];

  String get _selectedSlot =>
      '${_slots[_slotIndex].label} · ${_slots[_slotIndex].detail}';

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    // Non-negotiable. `clear()` unregisters the three handlers above; skipping
    // it keeps this State reachable from the plugin's channel for the life of
    // the process, and the next checkout fires every handler twice.
    _razorpay.clear();
    _addressController.dispose();
    super.dispose();
  }

  // ── Placing the order ─────────────────────────────────────────────────

  Future<void> _submit() async {
    // A tap that arrives while the gateway is open or the order is being
    // written is always a mistake — drop it rather than queue it.
    if (_isBusy) return;

    final address = _addressController.text.trim();
    if (address.length < 10) {
      setState(() => _error = 'Please enter a complete delivery address.');
      return;
    }

    if (_draft.isEmpty) {
      setState(() => _error = 'There is nothing in this order.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _error = '');

    if (_payment.isPrepaid) {
      await _startRazorpay();
    } else {
      await _placePayLaterOrder();
    }
  }

  /// Opens the Razorpay sheet for the current draft.
  ///
  /// The amount is never invented here: the backend creates the order under
  /// the key secret and echoes the amount back, and that figure is what the
  /// sheet charges.
  Future<void> _startRazorpay() async {
    setState(() => _stage = _Stage.creatingOrder);

    try {
      final order = await PaymentService.instance.createOrder(draft: _draft);
      if (!mounted) return;

      _pendingOrder = order;

      // `open` returns immediately; the outcome arrives on one of the three
      // handlers registered in initState.
      _razorpay.open(_razorpayOptions(order));
      setState(() => _stage = _Stage.awaitingGateway);
    } on PaymentException catch (error) {
      PaymentService.instance.logFailure(draft: _draft, error: error);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.idle;
        _error = error.message;
      });
      AppSnack.error(context, error.message);
    } catch (error) {
      // The SDK can throw synchronously on a malformed options map. Catching
      // it here keeps a configuration mistake from taking the screen down.
      PaymentService.instance.logFailure(draft: _draft, error: error);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.idle;
        _error = 'We could not open the payment screen. Please try again.';
      });
    }
  }

  /// The options payload handed to the Razorpay sheet.
  ///
  /// Prefill values come from the signed-in user, which on this app is
  /// usually an anonymous account with neither email nor phone. Razorpay
  /// rejects an empty-string contact, so absent fields are omitted entirely
  /// rather than sent blank — the sheet then asks for them itself.
  Map<String, dynamic> _razorpayOptions(RazorpayOrder order) {
    final user = AuthService.instance.currentUser;
    final email = user?.email;
    final phone = user?.phoneNumber;

    final prefill = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'contact': phone,
      if (_payment.razorpayMethod != null) 'method': _payment.razorpayMethod,
    };

    return {
      'key': order.keyId,
      'order_id': order.orderId,
      'amount': order.amountInPaise,
      'currency': order.currency,
      'name': 'InstaStyle',
      'description': _draft.paymentDescription,
      if (prefill.isNotEmpty) 'prefill': prefill,
      'notes': {
        'source': _draft.source.wireName,
        'slot': _selectedSlot,
      },
      'theme': {'color': _accentHex},
      // How long the sheet waits before giving up on the shopper. Distinct
      // from the 15s backend guard in PaymentService — this one is the human
      // in front of the phone.
      'timeout': 300,
      'retry': {'enabled': true, 'max_count': 1},
      'external': {
        'wallets': ['paytm'],
      },
    };
  }

  /// Pay-after-trial and cash. No gateway, but the same order record and the
  /// same exit screen — the point of the unified pipeline.
  Future<void> _placePayLaterOrder() async {
    setState(() => _stage = _Stage.finalising);

    try {
      final orderId = await PaymentService.instance.recordOrder(
        draft: _draft,
        deliveryAddress: _addressController.text.trim(),
        deliverySlot: _selectedSlot,
        paymentMethod: _payment.wireName,
      );

      await _clearPurchasedItems();
      if (!mounted) return;

      _goToSuccess(
        orderId: orderId,
        settlement: OrderSettlement.payAfterTrial,
      );
    } on PaymentException catch (error) {
      PaymentService.instance.logFailure(draft: _draft, error: error);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.idle;
        _error = error.message;
      });
      AppSnack.error(context, error.message);
    }
  }

  // ── Razorpay callbacks ────────────────────────────────────────────────

  /// Razorpay says the payment went through.
  ///
  /// That claim is client-side, so it is checked against the backend before
  /// the order is written. What is *not* in doubt is that the shopper has been
  /// charged — so from here on nothing may surface as "payment failed", and
  /// the bag is only cleared once the order document exists.
  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    // Re-entrancy guard. The SDK will not normally fire twice, but this is the
    // one handler where a duplicate run means a duplicate order.
    if (_stage == _Stage.finalising) return;
    if (!mounted) return;

    setState(() => _stage = _Stage.finalising);

    final order = _pendingOrder;
    final paymentId = response.paymentId;

    // Neither should ever be null on a success callback. If they are, we
    // cannot tie the money to an order — bail loudly rather than write a
    // record that cannot be reconciled.
    if (order == null || paymentId == null) {
      PaymentService.instance.logFailure(
        draft: _draft,
        error: 'success callback missing order/payment id',
      );
      _failGracefully(
        'We could not confirm that payment. If money left your account, '
        'it will be refunded automatically.',
      );
      return;
    }

    try {
      final verification = await PaymentService.instance.verifyPayment(
        razorpayOrderId: response.orderId ?? order.orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: response.signature ?? '',
      );

      // A signature that is present and wrong is the one case where a
      // success callback must not become an order.
      if (!verification.verified && !verification.inconclusive) {
        PaymentService.instance.logFailure(
          draft: _draft,
          error: 'signature verification rejected',
          razorpayOrderId: order.orderId,
        );
        _failGracefully(
          'We could not verify that payment. Nothing will be charged — '
          'please try again.',
        );
        return;
      }

      final orderId = await PaymentService.instance.recordOrder(
        draft: _draft,
        order: order,
        paymentId: paymentId,
        verification: verification,
        deliveryAddress: _addressController.text.trim(),
        deliverySlot: _selectedSlot,
        paymentMethod: _payment.wireName,
      );

      // Only now, with the order safely written, does the bag change.
      await _clearPurchasedItems();

      // Courtesy only — never awaited into the critical path, and it
      // swallows its own failures.
      unawaited(
        NotificationService.instance.showOrderConfirmation(
          orderId: orderId,
          itemCount: _draft.itemCount,
          amountLabel: formatPaise(order.amountInPaise),
        ),
      );

      if (!mounted) return;
      _goToSuccess(
        orderId: orderId,
        paymentId: paymentId,
        settlement: verification.verified
            ? OrderSettlement.paid
            : OrderSettlement.pendingVerification,
      );
    } on PaymentException catch (error) {
      PaymentService.instance.logFailure(
        draft: _draft,
        error: error,
        razorpayOrderId: order.orderId,
      );
      _failGracefully(error.message);
    } catch (error) {
      PaymentService.instance.logFailure(
        draft: _draft,
        error: error,
        razorpayOrderId: order.orderId,
      );
      _failGracefully(
        'Your payment went through, but we could not finish the order. '
        'Please contact support rather than paying again.',
      );
    }
  }

  /// Razorpay rejected the payment, or the shopper backed out of the sheet.
  ///
  /// Nothing has been charged, and — critically — nothing has been removed
  /// from the bag. The shopper lands back on a checkout screen with their
  /// items intact and can simply tap Pay again.
  void _onPaymentError(PaymentFailureResponse response) {
    PaymentService.instance.logFailure(
      draft: _draft,
      error: response.message ?? 'unknown gateway error',
      razorpayOrderId: _pendingOrder?.orderId,
      code: response.code,
    );

    _pendingOrder = null;
    if (!mounted) return;

    final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    final message = switch (response.code) {
      Razorpay.PAYMENT_CANCELLED => 'Payment cancelled. Your bag is still here.',
      Razorpay.NETWORK_ERROR =>
        'The payment could not reach your bank. Check your connection and '
            'try again.',
      _ => 'That payment did not go through. Nothing has been charged.',
    };

    setState(() {
      _stage = _Stage.idle;
      // A deliberate cancellation is not an error worth pinning under the
      // button; a real failure is.
      _error = cancelled ? '' : message;
    });

    if (cancelled) {
      AppSnack.show(context, message, icon: Icons.info_outline);
    } else {
      AppSnack.error(context, message);
    }
  }

  /// The shopper chose an external wallet (Paytm et al).
  ///
  /// Informational only: the wallet app takes over and the real outcome still
  /// arrives on the success or error handler, so the screen stays in
  /// [_Stage.awaitingGateway] rather than resolving here.
  void _onExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay external wallet selected: ${response.walletName}');
    if (!mounted) return;
    AppSnack.show(
      context,
      'Opening ${response.walletName ?? 'your wallet'}…',
      icon: Icons.account_balance_wallet_outlined,
    );
  }

  // ── Shared tails ──────────────────────────────────────────────────────

  /// Retires exactly the SKUs that were bought.
  ///
  /// Never allowed to fail the order: the shopper has paid, and a cart row
  /// that outlives its purchase is a far smaller problem than an error screen
  /// after a successful payment. The stale row is logged and cleaned up on
  /// the next cart read.
  Future<void> _clearPurchasedItems() async {
    try {
      await CartService.instance.removeItems(_draft.skusToClear);
    } catch (error) {
      debugPrint('Checkout: could not clear purchased items — $error');
    }
  }

  void _goToSuccess({
    required String orderId,
    required OrderSettlement settlement,
    String? paymentId,
  }) {
    // pushReplacement, not push: this checkout is paid for and must not be
    // reachable with the back gesture.
    Navigator.of(context).pushReplacement(
      OrderSuccessScreen.route(
        orderId: orderId,
        itemCount: _draft.itemCount,
        totalInPaise: _draft.totalInPaise,
        settlement: settlement,
        paymentId: paymentId,
      ),
    );
  }

  /// Returns the screen to a usable state with a message, without losing the
  /// draft. Used for every post-gateway failure.
  void _failGracefully(String message) {
    _pendingOrder = null;
    if (!mounted) return;
    setState(() {
      _stage = _Stage.idle;
      _error = message;
    });
    AppSnack.error(context, message);
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);

    // Leaving mid-payment would orphan an order that is halfway through being
    // paid for, so the system back gesture and the top bar's arrow are both
    // sealed while the gateway or the order write is in flight. Blocking here
    // rather than on the button covers the hardware back key too.
    return PopScope(
      canPop: !_isBusy,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        // Blocks the whole screen while the gateway or the order write is in
        // flight, so there is no second tap to guard against in the first
        // place.
        body: AppProgressOverlay(
          isVisible: _stage == _Stage.creatingOrder ||
              _stage == _Stage.finalising,
          title: _stage == _Stage.finalising
              ? 'Confirming your order'
              : 'Preparing payment',
          message: _stage == _Stage.finalising
              ? 'Do not close the app'
              : null,
          child: Column(
            children: [
              // The arrow routes through Navigator.maybePop, so the PopScope
              // above disables it for free while a payment is in flight.
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
                      enabled: !_isBusy,
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
                        onTap: _isBusy
                            ? null
                            : () => setState(() => _slotIndex = i),
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
                        onTap: _isBusy
                            ? null
                            : () => setState(() {
                                  _payment = PaymentMethod.values[i];
                                  _error = '';
                                }),
                      ),
                      if (i < PaymentMethod.values.length - 1)
                        const SizedBox(height: AppSpacing.xs),
                    ],

                    // ── Order recap ────────────────────────────────────
                    const SizedBox(height: AppSpacing.xl),
                    Text('Your Order'.toUpperCase(), style: AppType.eyebrow),
                    const SizedBox(height: AppSpacing.sm),
                    _OrderRecap(draft: _draft),
                  ],
                ),
              ),

              _PayBar(
                draft: _draft,
                payment: _payment,
                error: _error,
                isBusy: _isBusy,
                onPay: _submit,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// Razorpay wants the sheet accent as a `#rrggbb` string.
  static String get _accentHex =>
      '#${(AppPalette.accentDeep.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

/// The lines being bought, plus the arithmetic that produced the total.
///
/// Shown in full rather than as a bare total: the delivery fee is decided by
/// the pipeline, not by the screen the shopper came from, so it has to be
/// visible before they pay.
class _OrderRecap extends StatelessWidget {
  final CheckoutDraft draft;

  const _OrderRecap({required this.draft});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppPalette.surfaceWarm,
      bordered: false,
      child: Column(
        children: [
          for (final item in draft.items) ...[
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
                Text(formatPaise(item.totalInPaise), style: AppType.price),
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
                  'Delivery',
                  style: AppType.bodyMedium.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
              Text(
                draft.deliveryInPaise == 0
                    ? 'FREE'
                    : formatPaise(draft.deliveryInPaise),
                style: AppType.price.copyWith(
                  color: draft.deliveryInPaise == 0
                      ? AppPalette.success
                      : AppPalette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: Text('To pay', style: AppType.titleMedium)),
              Text(
                formatPaise(draft.totalInPaise),
                style: AppType.priceLarge.copyWith(fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The sticky footer: any error, then the one button that starts the payment.
class _PayBar extends StatelessWidget {
  final CheckoutDraft draft;
  final PaymentMethod payment;
  final String error;
  final bool isBusy;
  final VoidCallback onPay;

  const _PayBar({
    required this.draft,
    required this.payment,
    required this.error,
    required this.isBusy,
    required this.onPay,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 15,
                    color: AppPalette.danger,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    error,
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
            label: payment == PaymentMethod.payOnTrial
                ? 'Place Order · Pay Later'
                : 'Pay ${formatPaise(draft.totalInPaise)}',
            icon: payment.isPrepaid ? Icons.lock_outline : null,
            isLoading: isBusy,
            onPressed: isBusy ? null : onPay,
          ),
        ],
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

  /// Null while the screen is busy — the row greys out and stops responding
  /// rather than changing the order under an open payment sheet.
  final VoidCallback? onTap;

  const _SelectableRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: GestureDetector(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
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
                  color: selected ? AppPalette.accent : AppPalette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
