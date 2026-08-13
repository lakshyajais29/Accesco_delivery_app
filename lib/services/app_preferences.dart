import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, device-scoped preferences.
///
/// Owns the first-run flag that decides where the splash screen sends the user,
/// plus the style answers collected on first launch. Everything here is a
/// local cache — the same fields are mirrored to Firestore under
/// `users/{uid}` so they survive a reinstall, but routing must not wait on a
/// network call, so the flag is read from disk.
///
/// [load] is called once during startup; every getter after that is
/// synchronous, which is what lets the splash screen decide its destination
/// without an async gap.
class AppPreferences {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  static const _kHasCompletedSetup = 'has_completed_style_setup';
  static const _kPreferredSizes = 'preferred_sizes';
  static const _kPreferredStyles = 'preferred_styles';

  SharedPreferences? _prefs;

  /// Reads preferences into memory. Safe to call more than once.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// True until the user finishes the style-preferences step.
  ///
  /// Defaults to true when the key is absent — a fresh install and a
  /// never-answered install are the same thing, and the failure mode of
  /// showing setup once too often is far gentler than skipping it entirely.
  bool get isFirstTimeUser =>
      !(_prefs?.getBool(_kHasCompletedSetup) ?? false);

  List<String> get preferredSizes =>
      _prefs?.getStringList(_kPreferredSizes) ?? const [];

  List<String> get preferredStyles =>
      _prefs?.getStringList(_kPreferredStyles) ?? const [];

  /// Records the answers and closes out first-run.
  ///
  /// The flag is written *last*: if the process dies mid-write, the user sees
  /// the setup screen again rather than landing on a home screen with no
  /// preferences behind it.
  Future<void> completeStyleSetup({
    required List<String> sizes,
    required List<String> styles,
  }) async {
    await load();
    await _prefs!.setStringList(_kPreferredSizes, sizes);
    await _prefs!.setStringList(_kPreferredStyles, styles);
    await _prefs!.setBool(_kHasCompletedSetup, true);
  }

  /// Clears local state. Useful for a "reset app" affordance and for testing
  /// the first-run path without reinstalling.
  Future<void> reset() async {
    await load();
    await _prefs!.remove(_kHasCompletedSetup);
    await _prefs!.remove(_kPreferredSizes);
    await _prefs!.remove(_kPreferredStyles);
    debugPrint('AppPreferences reset — next launch will show style setup.');
  }
}
