import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:instastyle/screens/sku_catalog.dart'; // ← your actual path

class CartService {
  CartService._();
  static final CartService instance = CartService._();

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<String> get _uid async {
    User? user = _auth.currentUser;
    if (user == null) {
      final cred = await _auth.signInAnonymously();
      user = cred.user!;
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