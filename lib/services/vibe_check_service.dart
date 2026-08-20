// vibe_check_api_service.dart
//
// Drop-in replacement for the Firestore-based VibeCheckService.
// Talks to FastAPI + Redis + WebSocket backend.
//
// pubspec.yaml additions:
//   http: ^1.2.0
//   web_socket_channel: ^3.0.0
//   firebase_auth: ^...  (kept, for logged-in user id)

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

// ─── CONFIG ──────────────────────────────────────────────────────────────────
class VibeCheckApiConfig {
  static const String httpBase = 'https://tattered-yo-yo-duvet.ngrok-free.dev';
  static const String wsBase   = 'wss://tattered-yo-yo-duvet.ngrok-free.dev';
  static const Duration reconnectDelay      = Duration(seconds: 3);
  static const int     maxReconnectAttempts = 10;

  /// Ceiling on every HTTP call.
  ///
  /// The backend sits behind an ngrok tunnel that can vanish without closing
  /// the socket. A bare `http.post` against a dead tunnel hangs until the OS
  /// gives up — minutes later, with a spinner still on screen. Fifteen seconds
  /// is well past a healthy round trip.
  static const Duration requestTimeout      = Duration(seconds: 15);
}

// ─── SHARED HEADERS ──────────────────────────────────────────────────────────
const Map<String, String> _kJsonHeaders = {
  'Content-Type'              : 'application/json',
  'ngrok-skip-browser-warning': 'true',
};

const Map<String, String> _kGetHeaders = {
  'ngrok-skip-browser-warning': 'true',
};

// ─── EXCEPTION ───────────────────────────────────────────────────────────────
/// Raised when a Vibe Check call cannot complete. The message is already
/// phrased for display, so the UI never interprets a status code.
///
/// The two [StateError] sentinels thrown below — `already_reacted` and
/// `not_found_or_expired` — are deliberately *not* folded into this type. They
/// are control flow a caller branches on, not errors it shows.
class VibeCheckException implements Exception {
  final String message;
  final int? statusCode;

  const VibeCheckException(this.message, {this.statusCode});

  @override
  String toString() => 'VibeCheckException($statusCode): $message';
}

// ─── SERVICE ─────────────────────────────────────────────────────────────────
class VibeCheckService {
  // Lazy, not a field initializer. `FirebaseAuth.instance` throws
  // synchronously when Firebase has not initialised, and a throw from a field
  // initializer escapes the *constructor* — so `VibeCheckService()` declared at
  // a screen's field level would take the whole screen down before build()
  // ever ran, with no try/catch able to reach it.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // ── WebSocket state ───────────────────────────────────────────────────────
  WebSocketChannel?   _channel;
  String?             _connectedPollId;
  StreamSubscription? _socketSub;
  Timer?              _reconnectTimer;
  int                 _reconnectAttempts = 0;
  bool                _disposed          = false;

  // ── Broadcast stream controllers ──────────────────────────────────────────
  final _reactionsCtrl = StreamController<Map<String, String>>.broadcast();
  final _stockCtrl     = StreamController<int>.broadcast();

  // ── Helpers ───────────────────────────────────────────────────────────────
  /// The signed-in user, or null when signed out *or* when Firebase itself is
  /// unavailable. Never throws.
  User? get _currentUser {
    try {
      return _auth.currentUser;
    } catch (error) {
      debugPrint('VibeCheckService: auth unavailable — $error');
      return null;
    }
  }

  /// The uid, or a display-ready throw.
  ///
  /// Used only where the backend genuinely has to attribute the call to an
  /// account. Replaces the old `currentUser!.uid`, which crashed the caller
  /// outright for a guest.
  String _requireUid() {
    final uid = _currentUser?.uid;
    if (uid == null) {
      throw const VibeCheckException('Please sign in to start a Vibe Check.');
    }
    return uid;
  }

  Uri _httpUri(String path) =>
      Uri.parse('${VibeCheckApiConfig.httpBase}$path');

  /// Runs one HTTP call under [VibeCheckApiConfig.requestTimeout], turning
  /// every transport failure into a [VibeCheckException].
  ///
  /// Status codes are left to the caller — each endpoint reads them
  /// differently (409 is "already voted", 404 is "expired").
  Future<http.Response> _send(
    String action,
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(VibeCheckApiConfig.requestTimeout);
    } on TimeoutException {
      throw VibeCheckException(
        '$action timed out. Check your connection and try again.',
      );
    } catch (error) {
      debugPrint('VibeCheckService — $action failed: $error');
      throw const VibeCheckException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  // ── CREATE ────────────────────────────────────────────────────────────────
  Future<String> createVibeCheck({
    required String       productId,
    required String       productName,
    required String       productCategory,
    required String       productPrice,
    required String       productImage,
    required int          productStock,
    required List<String> friendUserIds,
  }) async {
    // Resolved before the request so a signed-out user fails fast with a
    // message, rather than posting a null creator the backend would reject.
    final creatorId = _requireUid();

    // Use Firebase Auth display name — no Firestore needed.
    final user = _currentUser;
    final creatorName = user?.displayName ??
        user?.email?.split('@').first ??
        'Someone';

    final res = await _send('Creating the Vibe Check', () => http.post(
      _httpUri('/api/v1/vibe-checks'),
      headers: _kJsonHeaders,
      body: jsonEncode({
        'product_id'         : productId,
        'product_name'       : productName,
        'product_category'   : productCategory,
        'product_price'      : productPrice,
        'product_image'      : productImage,
        'product_stock'      : productStock,
        'creator_id'         : creatorId,
        'creator_name'       : creatorName,
        'selected_friend_ids': friendUserIds,
      }),
    ));

    if (res.statusCode != 200) {
      debugPrint('createVibeCheck failed: ${res.statusCode} — ${res.body}');
      throw VibeCheckException(
        'Could not start the Vibe Check. Please try again.',
        statusCode: res.statusCode,
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['poll_id'] as String;   // Redis poll_id — goes into share link
  }

  // ── REACTIONS STREAM (creator side) ───────────────────────────────────────
  Stream<Map<String, String>> reactionsStream(String vibeCheckId) {
    _ensureSocket(vibeCheckId);
    return _reactionsCtrl.stream;
  }

  // ── STOCK STREAM (creator side) ───────────────────────────────────────────
  Stream<int> stockStream(String productId) {
    if (_connectedPollId != null) _ensureSocket(_connectedPollId!);
    return _stockCtrl.stream;
  }

  // ── SEND REACTION (friend / in-app side) ──────────────────────────────────
  Future<void> sendReaction({
    required String vibeCheckId,
    required String reaction,
    String?         voterToken,
  }) async {
    // A friend voting from a share link is not signed in and carries their own
    // token — only fall back to the uid when no token was supplied.
    final token = voterToken ?? _requireUid();

    final res = await _send('Sending your reaction', () => http.post(
      _httpUri('/api/v1/vibe-checks/$vibeCheckId/react'),
      headers: _kJsonHeaders,
      body: jsonEncode({'voter_token': token, 'reaction': reaction}),
    ));

    if (res.statusCode == 409) throw StateError('already_reacted');
    if (res.statusCode != 200) {
      debugPrint('sendReaction failed: ${res.statusCode} — ${res.body}');
      throw VibeCheckException(
        'Could not send your reaction. Please try again.',
        statusCode: res.statusCode,
      );
    }
  }

  // ── GET VIBE CHECK (friend landing) ───────────────────────────────────────
  Future<Map<String, dynamic>> getVibeCheck(String pollId) async {
    final res = await _send('Loading the Vibe Check', () => http.get(
      _httpUri('/api/v1/vibe-checks/$pollId'),
      headers: _kGetHeaders,
    ));

    if (res.statusCode == 404) throw StateError('not_found_or_expired');
    if (res.statusCode != 200) {
      debugPrint('getVibeCheck failed: ${res.statusCode} — ${res.body}');
      throw VibeCheckException(
        'Could not load this Vibe Check. Please try again.',
        statusCode: res.statusCode,
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── ORDER PRODUCT (checkout, triggers FOMO stock broadcast) ──────────────
  Future<int> orderProduct(String productId) async {
    final res = await _send('Placing the order', () => http.post(
      _httpUri('/api/v1/products/$productId/order'),
      headers: _kJsonHeaders,
    ));

    if (res.statusCode != 200) {
      debugPrint('orderProduct failed: ${res.statusCode} — ${res.body}');
      throw VibeCheckException(
        'Could not place the order. Please try again.',
        statusCode: res.statusCode,
      );
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['stock'] as int;
  }

  // ── SOCKET PLUMBING ───────────────────────────────────────────────────────
  void _ensureSocket(String pollId) {
    if (_disposed) return;
    if (_connectedPollId == pollId && _channel != null) return;
    _tearDownSocket();
    _connectedPollId   = pollId;
    _reconnectAttempts = 0;
    _openSocket(pollId);
  }

  void _openSocket(String pollId) {
    if (_disposed) return;
    final uri = Uri.parse(
        '${VibeCheckApiConfig.wsBase}/ws/vibe-checks/$pollId');
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _socketSub = channel.stream.listen(
        _onSocketMessage,
        onError: (_) => _scheduleReconnect(pollId),
        onDone : ()  => _scheduleReconnect(pollId),
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect(pollId);
    }
  }

  void _onSocketMessage(dynamic event) {
    if (_disposed) return;
    try {
      final msg = jsonDecode(event as String) as Map<String, dynamic>;
      switch (msg['type'] as String?) {
        case 'reactions':
          final raw = (msg['reactions'] as Map?) ?? {};
          if (!_reactionsCtrl.isClosed) {
            _reactionsCtrl.add(
              raw.map((k, v) => MapEntry(k.toString(), v.toString())),
            );
          }
          break;
        case 'stock':
          if (!_stockCtrl.isClosed) {
            _stockCtrl.add((msg['stock'] as num).toInt());
          }
          break;
        case 'error':
          final errMsg = msg['message'] as String? ?? 'server_error';
          if (!_reactionsCtrl.isClosed) {
            _reactionsCtrl.addError(StateError(errMsg));
          }
          break;
      }
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  void _scheduleReconnect(String pollId) {
    if (_disposed) return;
    if (_connectedPollId != pollId) return;
    final max = VibeCheckApiConfig.maxReconnectAttempts;
    if (max > 0 && _reconnectAttempts >= max) return;
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(VibeCheckApiConfig.reconnectDelay, () {
      if (!_disposed && _connectedPollId == pollId) {
        _tearDownSocket(keepPollId: true);
        _openSocket(pollId);
      }
    });
  }

  void _tearDownSocket({bool keepPollId = false}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socketSub?.cancel();
    _socketSub = null;
    _channel?.sink.close();
    _channel = null;
    if (!keepPollId) _connectedPollId = null;
  }

  // ── DISPOSE ───────────────────────────────────────────────────────────────
  void dispose() {
    _disposed = true;
    _tearDownSocket();
    if (!_reactionsCtrl.isClosed) _reactionsCtrl.close();
    if (!_stockCtrl.isClosed) _stockCtrl.close();
  }
}
