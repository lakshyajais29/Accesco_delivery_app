import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Identity for the app.
///
/// Phone/OTP sign-in was removed in favour of a frictionless entry flow, but
/// the app still needs a stable user id: the cart, wishlist, thrift listings,
/// vibe checks and Storage security rules are all keyed on `uid`. Anonymous
/// authentication provides exactly that — a real Firebase user with a durable
/// uid, created silently, with no screen in the way.
///
/// The account persists across launches on the same device and can later be
/// upgraded to a phone or email login with [linkPhoneCredential], which
/// preserves everything already saved against the anonymous uid. Signing in
/// with a fresh credential instead of linking would strand that data.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  String? get uid => _auth.currentUser?.uid;

  bool get isSignedIn => _auth.currentUser != null;

  /// True when the session is anonymous rather than a linked account.
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Ensures a signed-in user exists, creating an anonymous one if needed.
  ///
  /// Called during startup. Returns null when sign-in fails — the app still
  /// launches in that case, because a user who cannot reach Firebase should
  /// still be able to browse the catalogue. Features that genuinely need a uid
  /// already guard for its absence.
  Future<User?> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;

    try {
      final credential = await _auth.signInAnonymously();
      debugPrint('Signed in anonymously as ${credential.user?.uid}');
      return credential.user;
    } on FirebaseAuthException catch (error) {
      // 'operation-not-allowed' means anonymous auth is switched off in the
      // Firebase console — the single most likely misconfiguration here.
      debugPrint(
        'Anonymous sign-in failed (${error.code}): ${error.message}. '
        'Check that Anonymous auth is enabled in the Firebase console.',
      );
      return null;
    } catch (error) {
      debugPrint('Anonymous sign-in failed: $error');
      return null;
    }
  }

  /// Upgrades the current anonymous account to a permanent phone login,
  /// keeping the same uid and all data attached to it.
  ///
  /// Not wired to any screen yet — this is the seam a future "save your
  /// account" flow plugs into.
  Future<UserCredential?> linkPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      debugPrint('Account link failed (${error.code}): ${error.message}');
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();
}
