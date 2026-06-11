// lib/services/trial_api_service.dart
//
// Connects the Flutter TrialAtDoorstepScreen to the FastAPI backend.
//
// Usage in trial_at_doorstep_screen.dart:
//   Replace the existing _confirmAndPay() body with a call to
//   TrialApiService.confirmAndPay(...)
//
// The two backend calls this file makes:
//   1. POST /api/v1/trials/{order_id}/start    (called on rider arrival)
//   2. POST /api/v1/trials/{order_id}/keep     (called on CONFIRM & PAY tap)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Config ──────────────────────────────────────────────────────────────────
// In production: inject via --dart-define or a config file, never hardcode.
const String _kBaseUrl    = String.fromEnvironment(
  'TRIAL_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8001',   // Android emulator → localhost
);
const String _kApiKey     = String.fromEnvironment(
  'TRIAL_API_KEY',
  defaultValue: 'dev-key-change-me',
);
const Duration _kTimeout  = Duration(seconds: 15);

// ─── Response models ──────────────────────────────────────────────────────────
class StartTrialResult {
  final bool   sessionStarted;
  final String orderId;
  final int    durationSeconds;
  final String startTime;
  final String message;

  const StartTrialResult({
    required this.sessionStarted,
    required this.orderId,
    required this.durationSeconds,
    required this.startTime,
    required this.message,
  });

  factory StartTrialResult.fromJson(Map<String, dynamic> j) => StartTrialResult(
    sessionStarted:  j['session_started'] as bool,
    orderId:         j['order_id']         as String,
    durationSeconds: j['duration_seconds'] as int,
    startTime:       j['start_time']       as String,
    message:         j['message']          as String,
  );
}

class KeepOutfitResult {
  final bool   success;
  final String orderId;
  final int    keptCount;
  final int    returnedCount;
  final double totalChargedInr;
  final String paymentStatus;
  final String message;

  const KeepOutfitResult({
    required this.success,
    required this.orderId,
    required this.keptCount,
    required this.returnedCount,
    required this.totalChargedInr,
    required this.paymentStatus,
    required this.message,
  });

  factory KeepOutfitResult.fromJson(Map<String, dynamic> j) => KeepOutfitResult(
    success:          j['success']            as bool,
    orderId:          j['order_id']           as String,
    keptCount:        j['kept_count']         as int,
    returnedCount:    j['returned_count']     as int,
    totalChargedInr:  (j['total_charged_inr'] as num).toDouble(),
    paymentStatus:    j['payment_status']     as String,
    message:          j['message']            as String,
  );
}

// ─── Service ─────────────────────────────────────────────────────────────────
class TrialApiService {
  TrialApiService._();

  static final _headers = {
    'Content-Type': 'application/json',
    'X-API-Key':    _kApiKey,
  };

  // ── Call on rider arrival ──────────────────────────────────────────────────
  // orderId  : your OMS order ID
  // riderId  : from the dispatch payload
  // items    : [{variant_sku, product_name, unit_price_inr}]
  static Future<StartTrialResult> startSession({
    required String orderId,
    required String riderId,
    required List<Map<String, dynamic>> items,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/v1/trials/$orderId/start');

    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'rider_id': riderId, 'items': items}),
        )
        .timeout(_kTimeout);

    if (response.statusCode == 200) {
      return StartTrialResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw _apiError('startSession', response);
  }

  // ── Called by _confirmAndPay() in TrialAtDoorstepScreen ───────────────────
  // keptSkus         : variant_sku list the customer is keeping
  // paymentMethodId  : Razorpay payment_id from checkout widget (null if all returned)
  static Future<KeepOutfitResult> confirmAndPay({
    required String        orderId,
    required List<String>  keptSkus,
    String?                paymentMethodId,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/v1/trials/$orderId/keep');

    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'kept_skus':          keptSkus,
            if (paymentMethodId != null)
              'payment_method_id': paymentMethodId,
          }),
        )
        .timeout(_kTimeout);

    if (response.statusCode == 200) {
      return KeepOutfitResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    // 402 = payment failed, 422 = business rule violation
    throw _apiError('confirmAndPay', response);
  }

  // ── Poll session status (fallback if push notification missed) ─────────────
  static Future<Map<String, dynamic>> pollStatus(String orderId) async {
    final uri = Uri.parse('$_kBaseUrl/api/v1/trials/$orderId/status');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _apiError('pollStatus', response);
  }

  static Exception _apiError(String method, http.Response r) {
    debugPrint('⚠️  TrialApiService.$method → ${r.statusCode}: ${r.body}');
    Map<String, dynamic> body = {};
    try { body = jsonDecode(r.body) as Map<String, dynamic>; } catch (_) {}
    final detail = body['detail'] ?? r.body;
    return Exception('TrialApiService.$method failed (${r.statusCode}): $detail');
  }
}