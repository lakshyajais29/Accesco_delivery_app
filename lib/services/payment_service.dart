// lib/services/payment_service.dart
//
// Everything the checkout pipeline needs from the network and from Firestore,
// with none of the Razorpay SDK's widget lifecycle. CheckoutScreen owns the
// Razorpay instance and its three callbacks; this service owns the two backend
// calls that bracket them and the order record that outlives them.
//
// The backend contract (FastAPI — see backend/trial_backend/routes/payments.py):
//   POST /api/v1/payments/orders   -> { order_id, amount, currency, key_id }
//   POST /api/v1/payments/verify   -> { verified, payment_id, order_id }
//
// The key_id comes back from the server rather than being compiled in, so
// rotating keys or moving from rzp_test_ to rzp_live_ does not need an app
// release.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/checkout_draft.dart';

// ─── Config ──────────────────────────────────────────────────────────────────
// Injected with --dart-define in CI. The defaults are the Android emulator's
// loopback alias and the dev key, matching TrialApiService.
const String _kBaseUrl = String.fromEnvironment(
  'PAYMENTS_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8001',
);
const String _kApiKey = String.fromEnvironment(
  'PAYMENTS_API_KEY',
  defaultValue: 'dev-key-change-me',
);

/// Every backend call in this file is bounded by this.
///
/// Without it an unreachable-but-not-refusing backend (a laptop that went to
/// sleep, a load balancer holding the socket open) leaves the Pay button
/// spinning with no way back — `http` has no default timeout of its own.
const Duration _kTimeout = Duration(seconds: 15);

// ─── Errors ──────────────────────────────────────────────────────────────────

/// Why a payment step failed, in a form the UI can branch on.
enum PaymentFailure {
  /// The backend did not answer inside [_kTimeout].
  timeout,

  /// No route to the backend at all — airplane mode, DNS, refused socket.
  network,

  /// The backend answered, but with an error status or an unusable body.
  backend,

  /// Razorpay rejected the payment, or the shopper dismissed the sheet.
  gateway,

  /// The signature did not match. Money may have moved; the order must not
  /// be treated as paid on this evidence.
  verification,

  /// Firestore refused the order write.
  persistence,

  /// A precondition this app controls — no signed-in user, empty draft.
  precondition,
}

/// Typed failure for the whole payment surface.
///
/// Callers catch this one type and read [failure] to decide between "retry",
/// "check your connection" and "contact support"; the raw [cause] is kept for
/// the log but never shown to a shopper.
class PaymentException implements Exception {
  final PaymentFailure failure;

  /// Shopper-facing, already written for a Snackbar.
  final String message;

  /// The original error, if this wraps one.
  final Object? cause;

  const PaymentException(this.failure, this.message, [this.cause]);

  /// True when trying the same thing again could plausibly work.
  bool get isRetryable =>
      failure == PaymentFailure.timeout ||
      failure == PaymentFailure.network ||
      failure == PaymentFailure.backend;

  @override
  String toString() =>
      'PaymentException(${failure.name}): $message'
      '${cause == null ? '' : ' <- $cause'}';
}

// ─── Wire models ─────────────────────────────────────────────────────────────

/// The Razorpay order the backend created on our behalf.
///
/// The amount is echoed back from the server and is the one handed to the
/// checkout sheet — never the locally computed total. If the two ever
/// disagree, the server's figure is the one that was actually authorised.
class RazorpayOrder {
  final String orderId;
  final int amountInPaise;
  final String currency;
  final String keyId;

  const RazorpayOrder({
    required this.orderId,
    required this.amountInPaise,
    required this.currency,
    required this.keyId,
  });

  factory RazorpayOrder.fromJson(Map<String, dynamic> j) => RazorpayOrder(
        orderId: j['order_id'] as String,
        amountInPaise: (j['amount'] as num).toInt(),
        currency: (j['currency'] as String?) ?? 'INR',
        keyId: j['key_id'] as String,
      );
}

/// Outcome of the server-side signature check.
class PaymentVerification {
  final bool verified;

  /// True when we could not reach the server to ask.
  ///
  /// Distinct from `verified == false`: an unreachable verifier is not
  /// evidence of fraud, and the shopper has already been charged by the time
  /// we get here. Orders in this state are written as `pending_verification`
  /// and reconciled server-side by the Razorpay webhook.
  final bool inconclusive;

  const PaymentVerification.verified()
      : verified = true,
        inconclusive = false;

  const PaymentVerification.rejected()
      : verified = false,
        inconclusive = false;

  const PaymentVerification.unreachable()
      : verified = false,
        inconclusive = true;

  /// What to store on the order document.
  String get orderStatus => verified
      ? 'paid'
      : inconclusive
          ? 'pending_verification'
          : 'verification_failed';
}

// ─── Service ─────────────────────────────────────────────────────────────────

class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  // Lazy, not field initializers. These `.instance` calls throw synchronously
  // when Firebase.initializeApp() has not run or has failed, and a throw from
  // a field initializer escapes the *constructor* — before any method's
  // try/catch can see it. Behind a getter the same throw lands inside the
  // guarded block of whichever method touched it.
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'X-API-Key': _kApiKey,
      };

  String get _requireUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const PaymentException(
        PaymentFailure.precondition,
        'Please sign in before paying.',
      );
    }
    return uid;
  }

  // ── 1. Create the Razorpay order ──────────────────────────────────────
  //
  // Razorpay will not accept a checkout without an order created server-side
  // under the secret key. That is also the only place the amount can be fixed
  // beyond the client's reach, so this call is what makes the total
  // tamper-proof.
  Future<RazorpayOrder> createOrder({
    required CheckoutDraft draft,
    String? receipt,
  }) async {
    if (draft.isEmpty) {
      throw const PaymentException(
        PaymentFailure.precondition,
        'There is nothing in this order.',
      );
    }

    final uid = _requireUid;
    final uri = Uri.parse('$_kBaseUrl/api/v1/payments/orders');

    // Razorpay caps receipts at 40 characters and rejects anything longer.
    final rawReceipt = receipt ?? 'rcpt_${uid}_${_stamp()}';
    final safeReceipt = rawReceipt.length <= 40
        ? rawReceipt
        : rawReceipt.substring(rawReceipt.length - 40);

    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'amount_in_paise': draft.totalInPaise,
              'currency': 'INR',
              'receipt': safeReceipt,
              'notes': {
                'uid': uid,
                'source': draft.source.wireName,
                'item_count': '${draft.itemCount}',
              },
            }),
          )
          // The guard the whole flow hangs on. Without it the Pay button
          // spins forever against a slow backend and the shopper's only way
          // out is to kill the app.
          .timeout(_kTimeout);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw PaymentException(
          PaymentFailure.backend,
          'We could not start this payment. Please try again.',
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final order = RazorpayOrder.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      // A server that quotes a different amount than we displayed means the
      // shopper is about to be charged something they never agreed to.
      // Refuse rather than open the sheet.
      if (order.amountInPaise != draft.totalInPaise) {
        throw PaymentException(
          PaymentFailure.backend,
          'The order total changed. Please review your bag and try again.',
          'expected ${draft.totalInPaise}p, server said ${order.amountInPaise}p',
        );
      }

      return order;
    } on PaymentException {
      rethrow;
    } on TimeoutException catch (error) {
      throw PaymentException(
        PaymentFailure.timeout,
        'Our payment service is taking too long. Please try again.',
        error,
      );
    } on SocketException catch (error) {
      throw PaymentException(
        PaymentFailure.network,
        'No connection. Check your network and try again.',
        error,
      );
    } on http.ClientException catch (error) {
      throw PaymentException(
        PaymentFailure.network,
        'No connection. Check your network and try again.',
        error,
      );
    } on FormatException catch (error) {
      // Malformed JSON, or a field the contract promised and did not send.
      throw PaymentException(
        PaymentFailure.backend,
        'We could not start this payment. Please try again.',
        error,
      );
    } catch (error) {
      throw PaymentException(
        PaymentFailure.backend,
        'We could not start this payment. Please try again.',
        error,
      );
    }
  }

  // ── 2. Verify the signature server-side ───────────────────────────────
  //
  // The success callback from the Razorpay SDK is client-side evidence and
  // nothing more. Only an HMAC check against the key secret — which never
  // leaves the backend — proves the payment is real.
  //
  // Never throws. A shopper whose card has already been charged must not be
  // shown an exception; all three outcomes are representable in the result.
  Future<PaymentVerification> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/v1/payments/verify');

    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'razorpay_order_id': razorpayOrderId,
              'razorpay_payment_id': razorpayPaymentId,
              'razorpay_signature': razorpaySignature,
            }),
          )
          .timeout(_kTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (body['verified'] as bool? ?? false)
            ? const PaymentVerification.verified()
            : const PaymentVerification.rejected();
      }

      // 400 is the backend's "signature mismatch" — a real rejection.
      if (response.statusCode == 400) {
        debugPrint('PaymentService.verify rejected: ${response.body}');
        return const PaymentVerification.rejected();
      }

      // 5xx is the backend's problem, not the payment's.
      debugPrint(
        'PaymentService.verify inconclusive '
        '(${response.statusCode}): ${response.body}',
      );
      return const PaymentVerification.unreachable();
    } catch (error) {
      debugPrint('PaymentService.verify could not reach backend — $error');
      return const PaymentVerification.unreachable();
    }
  }

  // ── 3. Persist the order ──────────────────────────────────────────────
  //
  // One write path for every payment method, so `orders` has a single shape
  // whatever the shopper chose. Prepaid orders are written under the Razorpay
  // payment id as the document id, which makes the write idempotent: a retry
  // after a flaky network updates the same document instead of growing a
  // duplicate in the shopper's order history. Pay-later orders have no such
  // handle yet and take a generated id.
  Future<String> recordOrder({
    required CheckoutDraft draft,
    required String deliveryAddress,
    required String deliverySlot,
    required String paymentMethod,
    RazorpayOrder? order,
    String? paymentId,
    PaymentVerification? verification,
  }) async {
    final uid = _requireUid;

    try {
      final collection = _db.collection('orders');
      final ref =
          paymentId == null ? collection.doc() : collection.doc(paymentId);

      await ref.set({
        'uid': uid,
        // No verification means nothing was charged yet — the rider collects.
        'status': verification?.orderStatus ?? 'awaiting_payment',
        'fulfilmentStatus': 'placed',
        'source': draft.source.wireName,

        // Money, in paise. The gateway's figure wins when there is one: that
        // is the amount actually authorised.
        'subtotalInPaise': draft.subtotalInPaise,
        'deliveryInPaise': draft.deliveryInPaise,
        'totalInPaise': order?.amountInPaise ?? draft.totalInPaise,
        'currency': order?.currency ?? 'INR',

        // Razorpay handles, absent on pay-later orders.
        'razorpayOrderId': order?.orderId,
        'razorpayPaymentId': paymentId,
        'paymentMethod': paymentMethod,

        // Fulfilment.
        'items': draft.lineItemsJson,
        'itemCount': draft.itemCount,
        'deliveryAddress': deliveryAddress,
        'deliverySlot': deliverySlot,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return ref.id;
    } catch (error) {
      // For a prepaid order the money is already taken by this point, so this
      // failure is loud in the log but must never read to the shopper as
      // "payment failed" — that is what makes people pay a second time.
      debugPrint(
        'PaymentService.recordOrder failed for ${paymentId ?? 'unpaid order'}'
        ' — $error',
      );
      throw PaymentException(
        PaymentFailure.persistence,
        paymentId == null
            ? 'We could not place your order. Nothing has been charged — '
                'please try again.'
            : 'Your payment went through, but we could not save the order. '
                'Please contact support rather than paying again.',
        error,
      );
    }
  }

  // ── 4. Record a failure, locally ──────────────────────────────────────
  //
  // Deliberately not a Firestore write: a failed payment leaves the shopper on
  // a screen that still has to work, and a second network round trip is the
  // last thing that path needs. Razorpay's own dashboard is the record of
  // truth for attempts; this exists so the local log explains what the shopper
  // saw when a bug report arrives.
  void logFailure({
    required CheckoutDraft draft,
    required Object error,
    String? razorpayOrderId,
    int? code,
  }) {
    debugPrint(
      'Payment failed — source=${draft.source.wireName} '
      'amount=${draft.totalInPaise}p '
      'order=${razorpayOrderId ?? '-'} '
      'code=${code ?? '-'} :: $error',
    );
  }

  /// A collision-resistant, sortable suffix for receipts.
  String _stamp() => DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  /// This shopper's past orders, newest first.
  ///
  /// Kept here so the `orders` collection has exactly one reader and one
  /// writer. Needs the composite index on (uid, createdAt desc).
  Stream<List<Map<String, dynamic>>> streamOrders() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return _db
        .collection('orders')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList(growable: false),
        );
  }
}
