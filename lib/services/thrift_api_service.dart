// lib/services/thrift_api_service.dart
//
// Connects the Thrift Marketplace section to the FastAPI thrift service.
//
// Endpoints consumed:
//   1. GET /api/v1/thrift/nearby?lat=&lng=&radius_km=&limit=
//   2. GET /api/v1/thrift/stores/{store_id}/items
//
// Base URL and timeout follow the same --dart-define pattern as
// TrialApiService so all backend hosts are configured the same way.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/thrift_model.dart';

// ─── Config ──────────────────────────────────────────────────────────────────
// In production: inject via --dart-define, never hardcode.
const String _kBaseUrl = String.fromEnvironment(
  'THRIFT_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8001', // Android emulator → localhost:8001
);
const Duration _kTimeout = Duration(seconds: 15);

/// Raised when the thrift service is unreachable or returns a non-200.
///
/// Carries a message already phrased for display, so the UI layer never has to
/// interpret a status code.
class ThriftApiException implements Exception {
  final String message;
  final int? statusCode;

  const ThriftApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ThriftApiException($statusCode): $message';
}

class ThriftApiService {
  ThriftApiService._();

  static final ThriftApiService instance = ThriftApiService._();

  /// Overridable for tests — inject a mock client without touching callers.
  @visibleForTesting
  http.Client client = http.Client();

  /// Stores near a coordinate, nearest first.
  ///
  /// [radiusKm] bounds the search server-side; [limit] caps how many come
  /// back so the home-screen rail never has to page.
  Future<List<ThriftStore>> fetchNearbyStores({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 10,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/v1/thrift/nearby').replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius_km': radiusKm.toString(),
        'limit': limit.toString(),
      },
    );

    return _getList(uri, ThriftStore.fromJson);
  }

  /// The full catalogue for one store, optionally narrowed by category.
  Future<List<ThriftItem>> fetchStoreItems(
    String storeId, {
    String? category,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/v1/thrift/stores/$storeId/items')
        .replace(
      queryParameters: {
        if (category != null) 'category': category,
        'limit': limit.toString(),
      },
    );

    return _getList(uri, ThriftItem.fromJson);
  }

  /// Submits a new listing for moderation.
  ///
  /// Returns the persisted listing, whose status is always "pending" — the
  /// server sets it, so a client cannot publish straight to live.
  Future<ThriftListing> createListing(ThriftListingDraft draft) async {
    final uri = Uri.parse('$_kBaseUrl/api/v1/thrift/listings');

    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(draft.toJson()),
          )
          .timeout(_kTimeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ThriftListing.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }

      // FastAPI returns 422 with a per-field detail list on validation
      // failure. Surfacing that verbatim is more useful than a generic error.
      if (response.statusCode == 422) {
        throw ThriftApiException(
          _readableValidationError(response.body),
          statusCode: 422,
        );
      }

      throw ThriftApiException(
        'Could not publish your listing. Please try again.',
        statusCode: response.statusCode,
      );
    } on ThriftApiException {
      rethrow;
    } on TimeoutException {
      throw const ThriftApiException('The request timed out. Please retry.');
    } catch (error) {
      debugPrint('ThriftApiService.createListing failed: $error');
      throw const ThriftApiException(
        'Could not reach the thrift service. Check your connection.',
      );
    }
  }

  /// A seller's own listings, newest first.
  Future<List<ThriftListing>> fetchSellerListings(
    String sellerId, {
    String? status,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/api/v1/thrift/listings').replace(
      queryParameters: {
        'seller_id': sellerId,
        if (status != null) 'status': status,
      },
    );
    return _getList(uri, ThriftListing.fromJson);
  }

  /// Pulls the first human-readable message out of FastAPI's 422 body.
  String _readableValidationError(String body) {
    try {
      final decoded = jsonDecode(body);
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return (first['msg'] as String).replaceFirst('Value error, ', '');
        }
      }
    } catch (_) {
      // Fall through to the generic message below.
    }
    return 'Some details need fixing before this can be published.';
  }

  /// Shared GET + decode path.
  ///
  /// Every failure mode — no network, timeout, bad status, malformed body —
  /// surfaces as a [ThriftApiException] with a human-readable message, so the
  /// widget layer has exactly one error type to handle.
  Future<List<T>> _getList<T>(
    Uri uri,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(_kTimeout);

      if (response.statusCode != 200) {
        throw ThriftApiException(
          'The thrift service is unavailable right now.',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const ThriftApiException('Unexpected response from the server.');
      }

      return decoded
          .cast<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false);
    } on ThriftApiException {
      rethrow;
    } on TimeoutException {
      throw const ThriftApiException('The request timed out. Please retry.');
    } catch (error) {
      debugPrint('ThriftApiService GET $uri failed: $error');
      throw const ThriftApiException(
        'Could not reach the thrift service. Check your connection.',
      );
    }
  }
}
