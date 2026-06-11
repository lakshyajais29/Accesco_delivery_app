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
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

// ─── CONFIG ──────────────────────────────────────────────────────────────────
class VibeCheckApiConfig {
  static const String httpBase = 'https://tattered-yo-yo-duvet.ngrok-free.dev';
  static const String wsBase   = 'wss://tattered-yo-yo-duvet.ngrok-free.dev';
  static const Duration reconnectDelay      = Duration(seconds: 3);
  static const int     maxReconnectAttempts = 10;
}

// ─── SHARED HEADERS ──────────────────────────────────────────────────────────
const Map<String, String> _kJsonHeaders = {
  'Content-Type'              : 'application/json',
  'ngrok-skip-browser-warning': 'true',
};

const Map<String, String> _kGetHeaders = {
  'ngrok-skip-browser-warning': 'true',
};

// ─── SERVICE ─────────────────────────────────────────────────────────────────
class VibeCheckService {
  final _auth = FirebaseAuth.instance;

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
  String get _uid => _auth.currentUser!.uid;

  Uri _httpUri(String path) =>
      Uri.parse('${VibeCheckApiConfig.httpBase}$path');

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
    // Use Firebase Auth display name — no Firestore needed.
    final creatorName =
        _auth.currentUser?.displayName ??
        _auth.currentUser?.email?.split('@').first ??
        'Someone';

    final res = await http.post(
      _httpUri('/api/v1/vibe-checks'),
      headers: _kJsonHeaders,
      body: jsonEncode({
        'product_id'         : productId,
        'product_name'       : productName,
        'product_category'   : productCategory,
        'product_price'      : productPrice,
        'product_image'      : productImage,
        'product_stock'      : productStock,
        'creator_id'         : _uid,
        'creator_name'       : creatorName,
        'selected_friend_ids': friendUserIds,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(
          'createVibeCheck failed: ${res.statusCode} — ${res.body}');
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
    final token = voterToken ?? _uid;
    final res = await http.post(
      _httpUri('/api/v1/vibe-checks/$vibeCheckId/react'),
      headers: _kJsonHeaders,
      body: jsonEncode({'voter_token': token, 'reaction': reaction}),
    );
    if (res.statusCode == 409) throw StateError('already_reacted');
    if (res.statusCode != 200) {
      throw Exception(
          'sendReaction failed: ${res.statusCode} — ${res.body}');
    }
  }

  // ── GET VIBE CHECK (friend landing) ───────────────────────────────────────
  Future<Map<String, dynamic>> getVibeCheck(String pollId) async {
    final res = await http.get(
      _httpUri('/api/v1/vibe-checks/$pollId'),
      headers: _kGetHeaders,
    );
    if (res.statusCode == 404) throw StateError('not_found_or_expired');
    if (res.statusCode != 200) {
      throw Exception(
          'getVibeCheck failed: ${res.statusCode} — ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── ORDER PRODUCT (checkout, triggers FOMO stock broadcast) ──────────────
  Future<int> orderProduct(String productId) async {
    final res = await http.post(
      _httpUri('/api/v1/products/$productId/order'),
      headers: _kJsonHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception(
          'orderProduct failed: ${res.statusCode} — ${res.body}');
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