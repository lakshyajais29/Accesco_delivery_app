import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppFriend {
  final String userId;
  final String name;
  final String initial;
  final int colorValue;
  final String? phone;

  const AppFriend({
    required this.userId,
    required this.name,
    required this.initial,
    required this.colorValue,
    this.phone,
  });
}

class FriendsService {
  final _db = FirebaseFirestore.instance;

  // ── FETCH friends who have the app ───────────────────────────────────────
  // Strategy: read device contacts → normalize phones → query Firestore users
  Future<List<AppFriend>> getFriendsOnApp() async {
    // 1. Request contacts permission
    if (!await FlutterContacts.requestPermission()) return [];

    // 2. Get device contacts with phone numbers
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final phones = contacts
        .expand((c) => c.phones)
        .map((p) => _normalizePhone(p.number))
        .where((p) => p != null)
        .map((p) => p!)
        .toSet()
        .toList();

    if (phones.isEmpty) return [];

    // 3. Batch query Firestore — max 30 per 'whereIn'
    final List<AppFriend> result = [];
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    for (int i = 0; i < phones.length; i += 30) {
      final batch = phones.sublist(i, (i + 30).clamp(0, phones.length));
      final snap = await _db
          .collection('users')
          .where('phone', whereIn: batch)
          .get();

      for (final doc in snap.docs) {
        if (doc.id == myUid) continue; // exclude self
        final data = doc.data();
        final name = data['name'] as String? ?? 'Friend';
        result.add(AppFriend(
          userId: doc.id,
          name: name,
          initial: name.isNotEmpty ? name[0].toUpperCase() : '?',
          colorValue: data['avatarColor'] as int? ?? 0xFFE91E8C,
          phone: data['phone'] as String?,
        ));
      }
    }

    return result;
  }

  // ── REGISTER current user ────────────────────────────────────────────────
  Future<void> registerUser({
    required String name,
    required String phone,
    required int avatarColor,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db.collection('users').doc(uid).set({
      'name': name,
      'phone': _normalizePhone(phone) ?? phone,
      'avatarColor': avatarColor,
      'initial': name.isNotEmpty ? name[0].toUpperCase() : '?',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Normalize to E.164 (+91XXXXXXXXXX for India)
  String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length == 13 && digits.startsWith('091')) return '+${digits.substring(1)}';
    return null;
  }
}