import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/ds/ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  STYLE PREFERENCES — the one thing we ask a new user before letting them in.
//
//  Replaces the phone/OTP gate. No account to create, no code to wait for —
//  two taps and they're shopping. Answers are written locally (which is what
//  decides routing on the next launch) and mirrored to Firestore so they
//  survive a reinstall.
//
//  Field names match the ones the old profile-setup screen wrote —
//  `preferredSizes`, `profileComplete` — so anything already querying
//  `users/{uid}` keeps working unchanged.
// ─────────────────────────────────────────────────────────────────────────────

class StylePreferencesScreen extends StatefulWidget {
  /// Invoked once setup is saved. The caller decides where to go next, which
  /// keeps this screen usable both at first run and from a "redo setup"
  /// affordance later.
  final VoidCallback onComplete;

  const StylePreferencesScreen({super.key, required this.onComplete});

  static Route<void> route({required VoidCallback onComplete}) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            StylePreferencesScreen(onComplete: onComplete),
        transitionDuration: AppMotion.slow,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<StylePreferencesScreen> createState() => _StylePreferencesScreenState();
}

class _StylePreferencesScreenState extends State<StylePreferencesScreen>
    with SingleTickerProviderStateMixin {
  static const _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  /// Style directions, each with the icon that reads it fastest.
  static const _styles = <({String label, IconData icon})>[
    (label: 'Minimal', icon: Icons.crop_square_outlined),
    (label: 'Streetwear', icon: Icons.skateboarding_outlined),
    (label: 'Classic', icon: Icons.workspace_premium_outlined),
    (label: 'Ethnic', icon: Icons.temple_hindu_outlined),
    (label: 'Bold', icon: Icons.local_fire_department_outlined),
    (label: 'Athleisure', icon: Icons.directions_run_outlined),
    (label: 'Vintage', icon: Icons.history_toggle_off_outlined),
    (label: 'Formal', icon: Icons.business_center_outlined),
  ];

  final Set<String> _selectedSizes = {};
  final Set<String> _selectedStyles = {};

  bool _isSaving = false;
  String _error = '';

  late final AnimationController _entranceCtrl;

  bool get _canContinue =>
      _selectedSizes.isNotEmpty && _selectedStyles.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isSaving) return;

    if (!_canContinue) {
      setState(
        () => _error = _selectedSizes.isEmpty
            ? 'Pick at least one size so we can fit you properly.'
            : 'Pick a style or two so we know what to show you.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = '';
    });

    final sizes = _selectedSizes.toList()
      ..sort((a, b) => _sizes.indexOf(a).compareTo(_sizes.indexOf(b)));
    final styles = _selectedStyles.toList()..sort();

    // Local first: this is what routing reads on the next launch, and it must
    // not depend on the network succeeding.
    await AppPreferences.instance.completeStyleSetup(
      sizes: sizes,
      styles: styles,
    );

    // Then mirror to Firestore, best-effort. A failure here costs the user
    // nothing today — the answers are already on the device.
    final uid = AuthService.instance.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'preferredSizes': sizes,
          'preferredStyles': styles,
          'profileComplete': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (error) {
        debugPrint('Style preferences did not sync: $error');
      }
    }

    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: SafeArea(
          child: FadeTransition(
            opacity: _entranceCtrl.drive(
              CurveTween(curve: AppMotion.enter),
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      AppSpacing.xxl,
                      inset,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Masthead ──────────────────────────────────
                        Text(
                          'Welcome to InstaStyle'.toUpperCase(),
                          style: AppType.eyebrow.copyWith(
                            color: AppPalette.accent,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Let\'s find\nyour fit.',
                          style: AppType.displayLarge.responsive(context),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Two quick answers and every screen after this is '
                          'tuned to you. No account needed.',
                          style: AppType.bodyLarge,
                        ),

                        // ── Sizes ─────────────────────────────────────
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionLabel(
                          title: 'Your Sizes',
                          hint: 'Pick every size you wear',
                          count: _selectedSizes.length,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final size in _sizes)
                              AppChip(
                                label: size,
                                selected: _selectedSizes.contains(size),
                                onTap: () => setState(() {
                                  if (!_selectedSizes.remove(size)) {
                                    _selectedSizes.add(size);
                                  }
                                  _error = '';
                                }),
                              ),
                          ],
                        ),

                        // ── Styles ────────────────────────────────────
                        const SizedBox(height: AppSpacing.xl),
                        _SectionLabel(
                          title: 'Your Styles',
                          hint: 'Choose the directions you lean towards',
                          count: _selectedStyles.length,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final style in _styles)
                              AppChip(
                                label: style.label,
                                icon: style.icon,
                                selected:
                                    _selectedStyles.contains(style.label),
                                onTap: () => setState(() {
                                  if (!_selectedStyles.remove(style.label)) {
                                    _selectedStyles.add(style.label);
                                  }
                                  _error = '';
                                }),
                              ),
                          ],
                        ),

                        if (_canContinue) ...[
                          const SizedBox(height: AppSpacing.xl),
                          AppCard(
                            color: AppPalette.accentSoft,
                            bordered: false,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: AppPalette.accentDeep,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    'We\'ll prioritise '
                                    '${_selectedSizes.length} '
                                    '${_selectedSizes.length == 1 ? 'size' : 'sizes'}'
                                    ' across ${_selectedStyles.length} '
                                    '${_selectedStyles.length == 1 ? 'style' : 'styles'}.',
                                    style: AppType.bodyMedium.copyWith(
                                      color: AppPalette.accentDeep,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Footer ────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    AppSpacing.sm,
                    inset,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 15,
                              color: AppPalette.danger,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _error,
                                style: AppType.bodySmall.copyWith(
                                  color: AppPalette.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AppButton(
                        label: 'Continue to InstaStyle',
                        icon: Icons.arrow_forward,
                        trailingIcon: true,
                        isLoading: _isSaving,
                        // Kept enabled so tapping explains what's missing.
                        // A dead button leaves the user guessing.
                        onPressed: _continue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String hint;
  final int count;

  const _SectionLabel({
    required this.title,
    required this.hint,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppType.displaySmall),
              const SizedBox(height: 1),
              Text(hint, style: AppType.bodySmall),
            ],
          ),
        ),
        if (count > 0)
          AppBadge('$count selected', tone: AppBadgeTone.accent, soft: true),
      ],
    );
  }
}
