import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_config.dart';
import '../widgets/ds/ds.dart';
import 'trial_at_doorstep_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER SUCCESS — the one exit from the checkout pipeline.
//
//  Reached only after the money has moved and the order document exists, so
//  everything on it can be stated as fact. It hands off to the live trial
//  tracker rather than ending on a receipt: a 15-minute delivery promise
//  should not dead-end on a screen with nothing happening.
//
//  There is no back route out of here. The checkout screen it replaces is
//  gone from the stack by the time this builds — returning to a paid-for
//  checkout form is the classic way a shopper pays twice.
// ─────────────────────────────────────────────────────────────────────────────

/// How the order was settled, for the confirmation copy.
enum OrderSettlement {
  /// Paid in full through Razorpay.
  paid,

  /// Paid, but our server could not confirm the signature in time. The
  /// backend webhook reconciles it; the shopper is told it is being
  /// confirmed rather than being shown a scary failure for money that left
  /// their account.
  pendingVerification,

  /// Nothing charged yet — the shopper pays the rider after trying.
  payAfterTrial,
}

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final int itemCount;
  final int totalInPaise;
  final OrderSettlement settlement;

  /// Present for online payments, absent for pay-after-trial.
  final String? paymentId;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.itemCount,
    required this.totalInPaise,
    required this.settlement,
    this.paymentId,
  });

  static Route<void> route({
    required String orderId,
    required int itemCount,
    required int totalInPaise,
    required OrderSettlement settlement,
    String? paymentId,
  }) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => OrderSuccessScreen(
          orderId: orderId,
          itemCount: itemCount,
          totalInPaise: totalInPaise,
          settlement: settlement,
          paymentId: paymentId,
        ),
        transitionDuration: AppMotion.slow,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  String get _pieces =>
      '$itemCount ${itemCount == 1 ? 'piece is' : 'pieces are'} on the way.';

  String get _message => switch (settlement) {
        OrderSettlement.paid =>
          '$_pieces ${formatPaise(totalInPaise)} paid — you will get a '
              'notification the moment your rider sets off.',
        OrderSettlement.pendingVerification =>
          '$_pieces ${formatPaise(totalInPaise)} has left your account and we '
              'are confirming it with your bank. Nothing more to do — this '
              'usually settles within a minute.',
        OrderSettlement.payAfterTrial =>
          '$_pieces Try everything at your door and pay only for what you keep.',
      };

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final pending = settlement == OrderSettlement.pendingVerification;

    // Nothing on this screen may pop back into a paid checkout.
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.lightOverlay,
        child: Scaffold(
          backgroundColor: AppPalette.canvas,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: AppStateView.success(
                    icon: pending
                        ? Icons.hourglass_bottom_rounded
                        : Icons.check_rounded,
                    title: pending ? 'Payment received' : 'Order confirmed',
                    message: _message,
                    actionLabel: 'Track Delivery',
                    onAction: () => Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => TrialAtDoorstepScreen(
                          orderId: orderId,
                          riderId: 'RIDER456',
                        ),
                        transitionDuration: AppMotion.normal,
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                      ),
                    ),
                    secondaryActionLabel: 'Back to Home',
                    onSecondaryAction: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                  ),
                ),

                // ── Receipt strip ──────────────────────────────────────
                //
                // The two ids a support conversation always starts with,
                // long-press-copyable so nobody has to transcribe them.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    0,
                    inset,
                    AppSpacing.safeBottom(context, extra: AppSpacing.sm),
                  ),
                  child: AppCard(
                    color: AppPalette.surfaceWarm,
                    bordered: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ReceiptRow(label: 'Order', value: orderId),
                        if (paymentId != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _ReceiptRow(label: 'Payment', value: paymentId!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppType.eyebrow,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: value));
              HapticFeedback.selectionClick();
              AppSnack.show(context, '$label id copied');
            },
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodySmall.copyWith(
                color: AppPalette.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Formats paise with Indian digit grouping (₹1,23,456).
///
/// Public because checkout, the cart bar and this screen must all render the
/// same number the same way — three private copies is how they drift.
String formatPaise(int paise) {
  final rupees = paise ~/ 100;
  final digits = rupees.toString();
  if (digits.length <= 3) return '${AppConfig.currencySymbol}$digits';

  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${AppConfig.currencySymbol}${groups.join(',')},$last3';
}
