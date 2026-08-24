import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:instastyle/screens/sku_catalog.dart'; // ← your actual path

class CartService {
  CartService._();
  static final CartService instance = CartService._();

  // Lazy, not a field initializer. These `.instance` calls throw
  // synchronously when Firebase.initializeApp() has not run or has failed,
  // and a throw from a field initializer escapes the *constructor* — before
  // any method's try/catch can see it. Behind a getter the same throw lands
  // inside the guarded block of whichever method touched it.
  FirebaseFirestore get _db   => FirebaseFirestore.instance;
  FirebaseAuth      get _auth => FirebaseAuth.instance;

  Future<String> get _uid async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        'CartService requires an authenticated user. '
        'Please sign in via Phone Auth before accessing the cart.',
      );
    }
    return user.uid;
  }

  Future<CollectionReference> get _itemsCol async {
    final uid = await _uid;
    return _db
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc('swipestyle')
        .collection('items');
  }

  Future<void> addItem(CartPayload p) async {
    final col = await _itemsCol;
    final ref = col.doc(p.variantSku);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.update(ref, {
          'quantity':  FieldValue.increment(p.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, _toMap(p));
      }
    });
  }

  Future<void> addItems(List<CartPayload> payloads) async {
    if (payloads.isEmpty) return;
    final col   = await _itemsCol;
    final batch = _db.batch();
    for (final p in payloads) {
      batch.set(col.doc(p.variantSku), _toMap(p), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> removeItem(String variantSku) async {
    final col = await _itemsCol;
    await col.doc(variantSku).delete();
  }

  /// Removes several rows in one round trip.
  ///
  /// Used by checkout to retire exactly the SKUs that were paid for. A
  /// batch rather than a loop of deletes so the bag empties in a single
  /// snapshot — a loop makes the cart UI repaint once per item, which reads
  /// as a stutter on a full bag.
  ///
  /// Deleting a document that is not there is a no-op in Firestore, so a
  /// Buy Now for something never added to the cart passes through harmlessly.
  Future<void> removeItems(Iterable<String> variantSkus) async {
    final skus = variantSkus.toList(growable: false);
    if (skus.isEmpty) return;

    final col = await _itemsCol;
    final batch = _db.batch();
    for (final sku in skus) {
      batch.delete(col.doc(sku));
    }
    await batch.commit();
  }

  Future<List<CartPayload>> fetchItems() async {
    final snap = await (await _itemsCol).get();
    return snap.docs.map((d) => _fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Stream<List<CartPayload>> streamItems() async* {
    final col = await _itemsCol;
    yield* col.snapshots().map(
      (snap) => snap.docs
          .map((d) => _fromMap(d.data() as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _toMap(CartPayload p) => {
    'parentId':         p.parentId,
    'variantSku':       p.variantSku,
    'productName':      p.productName,
    'brand':            p.brand,
    'size':             p.size,
    'colorName':        p.colorName,
    'colorHex':         p.colorHex,
    'quantity':         p.quantity,
    'unitPriceInPaise': p.unitPriceInPaise,
    'imageUrl':         p.imageUrl,
    'source':           'swipestyle',
    'addedAt':          FieldValue.serverTimestamp(),
    'updatedAt':        FieldValue.serverTimestamp(),
  };

  CartPayload _fromMap(Map<String, dynamic> m) => CartPayload(
    parentId:          m['parentId']         as String,
    variantSku:        m['variantSku']        as String,
    productName:       m['productName']       as String,
    brand:             m['brand']             as String,
    size:              m['size']              as String,
    colorName:         m['colorName']         as String,
    colorHex:          m['colorHex']          as String,
    quantity:          (m['quantity']         as num).toInt(),
    unitPriceInPaise:  (m['unitPriceInPaise'] as num).toInt(),
    imageUrl:          m['imageUrl']          as String,
  );
}