import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

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

/// Raised when a friends operation cannot complete.
///
/// The message is already phrased for display, so the UI never has to
/// interpret a Firestore error code.
class FriendsException implements Exception {
  final String message;

  const FriendsException(this.message);

  @override
  String toString() => 'FriendsException: $message';
}

class FriendsService {
  // Lazy, not a field initializer. `FirebaseFirestore.instance` throws
  // synchronously when Firebase.initializeApp() has not run or has failed —
  // and a throw from a field initializer escapes the *constructor*, before any
  // method's try/catch can see it. Behind a getter the same throw lands inside
  // the guarded block of whichever method touched it.
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// The signed-in uid, or null when signed out *or* when Firebase itself is
  /// unavailable. Never throws.
  String? get _uid {
    try {
      return _auth.currentUser?.uid;
    } catch (error) {
      debugPrint('FriendsService: auth unavailable — $error');
      return null;
    }
  }

  // ── FETCH friends who have the app ───────────────────────────────────────
  // Strategy: read device contacts → normalize phones → query Firestore users
  //
  // Returns an empty list rather than throwing for the two *expected* empty
  // states — signed out, and contacts permission declined. Both are ordinary
  // conditions the UI renders as "no friends yet", not errors worth a dialog.
  // A genuine backend failure still throws, because silently showing zero
  // friends when the query broke would be a lie.
  Future<List<AppFriend>> getFriendsOnApp() async {
    final myUid = _uid;
    if (myUid == null) return const [];

    try {
      // 1. Request contacts permission
      if (!await FlutterContacts.requestPermission()) return const [];

      // 2. Get device contacts with phone numbers
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final phones = contacts
          .expand((c) => c.phones)
          .map((p) => _normalizePhone(p.number))
          .where((p) => p != null)
          .map((p) => p!)
          .toSet()
          .toList();

      if (phones.isEmpty) return const [];

      // 3. Batch query Firestore — max 30 per 'whereIn'
      final List<AppFriend> result = [];

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
    } on FirebaseException catch (error) {
      debugPrint('FriendsService.getFriendsOnApp failed (${error.code}): '
          '${error.message}');
      throw const FriendsException(
        'Could not load your friends right now. Please try again.',
      );
    } catch (error, stack) {
      debugPrint('FriendsService.getFriendsOnApp failed: $error\n$stack');
      throw const FriendsException(
        'Could not load your friends right now. Please try again.',
      );
    }
  }

  // ── REGISTER current user ────────────────────────────────────────────────
  //
  // Throws rather than returning quietly: a caller that believes it registered
  // the user when it did not will hand out a profile no friend can ever match
  // against. That failure has to be visible.
  Future<void> registerUser({
    required String name,
    required String phone,
    required int avatarColor,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw const FriendsException(
        'You need to be signed in before your profile can be saved.',
      );
    }

    try {
      await _db.collection('users').doc(uid).set({
        'name': name,
        'phone': _normalizePhone(phone) ?? phone,
        'avatarColor': avatarColor,
        'initial': name.isNotEmpty ? name[0].toUpperCase() : '?',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      debugPrint('FriendsService.registerUser failed (${error.code}): '
          '${error.message}');
      throw const FriendsException(
        'Could not save your profile. Check your connection and try again.',
      );
    } catch (error) {
      debugPrint('FriendsService.registerUser failed: $error');
      throw const FriendsException(
        'Could not save your profile. Check your connection and try again.',
      );
    }
  }

  // Normalize to E.164 (+91XXXXXXXXXX for India)
  String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length == 13 && digits.startsWith('091')) {
      return '+${digits.substring(1)}';
    }
    return null;
  }
}
