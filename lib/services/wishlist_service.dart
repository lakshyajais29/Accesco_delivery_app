import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import 'catalog_service.dart';

/// The wishlist, held in memory and mirrored to Firestore.
///
/// Previously this was a plain in-memory list with no change notification, so
/// each screen kept its own copy of "what is hearted" — the home rails, the
/// product page and the wishlist screen could all disagree, and everything was
/// lost on restart. It is now a [ChangeNotifier]: widgets listen to this one
/// instance and every heart in the app updates together.
///
/// Persistence stores only product *ids* under
/// `users/{uid}/wishlist/{productId}`, resolved back through [CatalogService]
/// on load. That keeps the document tiny, avoids duplicating catalogue data
/// that can go stale, and means the stored shape never has to change when the
/// product model gains fields.
///
/// The original API — `instance`, `items`, `contains`, `toggle` — is preserved
/// exactly, so existing callers keep working unchanged.
class WishlistService extends ChangeNotifier {
  static final WishlistService instance = WishlistService._internal();
  WishlistService._internal();

  final List<ParentProduct> _items = [];
  final Set<String> _ids = <String>{};

  bool _isSyncing = false;
  bool _hasLoaded = false;

  /// Unmodifiable view — the UI must go through [toggle] to mutate.
  List<ParentProduct> get items => List.unmodifiable(_items);

  /// Ids only. Cheaper than [items] for "is this hearted?" checks in list
  /// builders, which run for every card on every scroll frame.
  Set<String> get ids => Set.unmodifiable(_ids);

  int get count => _items.length;

  bool get isEmpty => _items.isEmpty;

  /// True while a Firestore round-trip is in flight, for progress affordances.
  bool get isSyncing => _isSyncing;

  bool contains(ParentProduct product) => _ids.contains(product.id);

  /// Id-based membership check for widgets that only have an id to hand.
  bool containsId(String productId) => _ids.contains(productId);

  /// Adds or removes [product] and notifies listeners immediately, then writes
  /// through to Firestore in the background.
  ///
  /// The local state is updated first so the heart animates instantly rather
  /// than waiting on the network. A failed write is rolled back so the UI can
  /// never claim something was saved when it wasn't.
  void toggle(ParentProduct product) {
    final wasWishlisted = _ids.contains(product.id);

    if (wasWishlisted) {
      _ids.remove(product.id);
      _items.removeWhere((item) => item.id == product.id);
    } else {
      _ids.add(product.id);
      _items.add(product);
    }
    notifyListeners();

    unawaited(_persistToggle(product, added: !wasWishlisted));
  }

  /// Loads the signed-in user's wishlist. Safe to call more than once; the
  /// network fetch only happens on the first call unless [force] is set.
  Future<void> load({bool force = false}) async {
    if (_hasLoaded && !force) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('wishlist')
          .get();

      _items.clear();
      _ids.clear();
      for (final doc in snapshot.docs) {
        final product = CatalogService.getById(doc.id);
        // A stored id with no catalogue entry means the product was retired.
        // Skip it rather than surfacing a broken card.
        if (product == null) continue;
        _items.add(product);
        _ids.add(product.id);
      }
      _hasLoaded = true;
    } catch (error, stack) {
      // Persistence is best-effort: an offline user still gets a working
      // in-memory wishlist for the session.
      debugPrint('WishlistService.load failed: $error\n$stack');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Clears local state on sign-out so the next user doesn't inherit it.
  void clear() {
    _items.clear();
    _ids.clear();
    _hasLoaded = false;
    notifyListeners();
  }

  Future<void> _persistToggle(
    ParentProduct product, {
    required bool added,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // Guest session — in-memory only.

    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .doc(product.id);

    try {
      if (added) {
        await doc.set({
          'productId': product.id,
          'addedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await doc.delete();
      }
    } catch (error) {
      debugPrint('WishlistService sync failed for ${product.id}: $error');
      // Roll back so the heart reflects what is actually stored.
      if (added) {
        _ids.remove(product.id);
        _items.removeWhere((item) => item.id == product.id);
      } else {
        _ids.add(product.id);
        _items.add(product);
      }
      notifyListeners();
    }
  }
}
