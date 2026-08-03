import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/ds/ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE SETUP — three steps, then straight into the app.
//
//  Step 1  Name + date of birth
//  Step 2  Gender + body type
//  Step 3  Preferred sizes
//
//  The Firestore write is unchanged: the same document at `users/{uid}`, the
//  same field names, still merged rather than overwritten, still setting
//  `profileComplete: true` — which is exactly what the login screen reads to
//  decide where to route.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // ── Firebase ──────────────────────────────────────────────────────────
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Step state ────────────────────────────────────────────────────────
  int _currentStep = 0;
  static const int _totalSteps = 3;

  // ── Form data ─────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  DateTime? _dob;
  String? _selectedGender;
  String? _selectedBodyType;
  final Set<String> _selectedSizes = {};

  bool _isSaving = false;
  String _errorMessage = '';

  // ── Options ───────────────────────────────────────────────────────────
  static const _genders = [
    'Male',
    'Female',
    'Non-Binary',
    'Prefer Not to Say',
  ];
  static const _bodyTypes = [
    'Slim',
    'Athletic',
    'Average',
    'Curvy',
    'Plus Size',
  ];
  static const _sizeOptions = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  static const _genderIcons = {
    'Male': Icons.male_rounded,
    'Female': Icons.female_rounded,
    'Non-Binary': Icons.transgender_rounded,
    'Prefer Not to Say': Icons.person_outline_rounded,
  };

  static const _bodyTypeIcons = {
    'Slim': Icons.accessibility_new_rounded,
    'Athletic': Icons.fitness_center_rounded,
    'Average': Icons.person_rounded,
    'Curvy': Icons.self_improvement_rounded,
    'Plus Size': Icons.sentiment_satisfied_alt_rounded,
  };

  static const _stepTitles = [
    (title: 'Let\'s start\nwith you', eyebrow: 'The Introduction'),
    (title: 'How you\nlike to dress', eyebrow: 'Your Silhouette'),
    (title: 'Your sizes,\nremembered', eyebrow: 'The Fit'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────
  void _nextStep() {
    if (!_validateCurrentStep()) return;

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _errorMessage = '';
      });
    } else {
      _saveProfile();
    }
  }

  void _prevStep() {
    if (_currentStep == 0) return;
    setState(() {
      _currentStep--;
      _errorMessage = '';
    });
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your name.');
          return false;
        }
        if (_dob == null) {
          setState(() => _errorMessage = 'Please select your date of birth.');
          return false;
        }
        return true;
      case 1:
        if (_selectedGender == null) {
          setState(() => _errorMessage = 'Please select your gender.');
          return false;
        }
        return true;
      case 2:
        if (_selectedSizes.isEmpty) {
          setState(() => _errorMessage = 'Please select at least one size.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // ── Save to Firestore ─────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_validateCurrentStep()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final uid = _auth.currentUser!.uid;
      await _db.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'dateOfBirth': _dob!.toIso8601String(),
        'age': _calculateAge(_dob!),
        'gender': _selectedGender,
        'bodyType': _selectedBodyType,
        'preferredSizes': _selectedSizes.toList(),
        'phone': _auth.currentUser!.phoneNumber,
        'profileComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 24),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 12),
      helpText: 'Select your date of birth',
      builder: (context, child) => Theme(
        data: AppTheme.light.copyWith(
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: AppPalette.surface,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _dob = picked;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final step = _stepTitles[_currentStep];
    final isLastStep = _currentStep == _totalSteps - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        // The keyboard is handled by the scroll view; letting the Scaffold
        // resize as well would double-shift the layout.
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              // ── Progress ─────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  AppSpacing.md,
                  inset,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      AppIconButton(
                        icon: Icons.arrow_back,
                        onPressed: _isSaving ? null : _prevStep,
                      )
                    else
                      const SizedBox(width: AppSpacing.xxl),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Row(
                        children: [
                          for (var i = 0; i < _totalSteps; i++) ...[
                            Expanded(
                              child: AnimatedContainer(
                                duration: AppMotion.normal,
                                curve: AppMotion.standard,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: i <= _currentStep
                                      ? AppPalette.accent
                                      : AppPalette.line,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            if (i < _totalSteps - 1)
                              const SizedBox(width: AppSpacing.xxs),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${_currentStep + 1}/$_totalSteps',
                      style: AppType.mono,
                    ),
                  ],
                ),
              ),

              // ── Step content ─────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(inset, 0, inset, AppSpacing.xl),
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    switchInCurve: AppMotion.enter,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(_currentStep),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.eyebrow.toUpperCase(),
                          style: AppType.eyebrow.copyWith(
                            color: AppPalette.accent,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          step.title,
                          style: AppType.displayLarge.responsive(context),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildStepBody(),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Footer ───────────────────────────────────────────────
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
                    if (_errorMessage.isNotEmpty) ...[
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
                              _errorMessage,
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
                      label: isLastStep ? 'Finish Setup' : 'Continue',
                      icon: isLastStep ? Icons.check : Icons.arrow_forward,
                      trailingIcon: true,
                      isLoading: _isSaving,
                      onPressed: _nextStep,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    return switch (_currentStep) {
      0 => _buildIdentityStep(),
      1 => _buildStyleStep(),
      _ => _buildSizeStep(),
    };
  }

  Widget _buildIdentityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Full Name',
          hint: 'How should we address you?',
          controller: _nameController,
          focusNode: _nameFocus,
          textInputAction: TextInputAction.done,
          enabled: !_isSaving,
          prefixIcon: Icons.person_outline,
          onChanged: (_) {
            if (_errorMessage.isNotEmpty) {
              setState(() => _errorMessage = '');
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSelectField(
          label: 'Date of Birth',
          icon: Icons.cake_outlined,
          placeholder: 'Select your date of birth',
          value: _dob == null
              ? null
              : '${_dob!.day.toString().padLeft(2, '0')}'
                  ' / ${_dob!.month.toString().padLeft(2, '0')}'
                  ' / ${_dob!.year}',
          onTap: _isSaving ? () {} : _pickDateOfBirth,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We use your age only to recommend age-appropriate pieces.',
          style: AppType.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStyleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        _OptionGrid(
          options: _genders,
          icons: _genderIcons,
          selected: _selectedGender == null ? const {} : {_selectedGender!},
          onTap: (value) => setState(() {
            _selectedGender = value;
            _errorMessage = '';
          }),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Text('Body Type'.toUpperCase(), style: AppType.eyebrow),
            const SizedBox(width: AppSpacing.xs),
            Text('Optional', style: AppType.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _OptionGrid(
          options: _bodyTypes,
          icons: _bodyTypeIcons,
          selected:
              _selectedBodyType == null ? const {} : {_selectedBodyType!},
          onTap: (value) => setState(
            // Tapping the selected type again clears it, since it's optional.
            () => _selectedBodyType =
                _selectedBodyType == value ? null : value,
          ),
        ),
      ],
    );
  }

  Widget _buildSizeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick every size you wear — we\'ll never wrong-size you again.',
          style: AppType.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Preferred Sizes'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final size in _sizeOptions)
              AppChip(
                label: size,
                selected: _selectedSizes.contains(size),
                onTap: () => setState(() {
                  if (!_selectedSizes.remove(size)) _selectedSizes.add(size);
                  _errorMessage = '';
                }),
              ),
          ],
        ),
        if (_selectedSizes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
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
                    '${_selectedSizes.length} '
                    '${_selectedSizes.length == 1 ? 'size' : 'sizes'} saved to '
                    'your profile',
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
    );
  }
}

/// A wrap of icon + label option tiles. Used for both gender and body type so
/// the two selections read as the same kind of choice.
class _OptionGrid extends StatelessWidget {
  final List<String> options;
  final Map<String, IconData> icons;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  const _OptionGrid({
    required this.options,
    required this.icons,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final option in options)
          _OptionTile(
            label: option,
            icon: icons[option] ?? Icons.circle_outlined,
            selected: selected.contains(option),
            onTap: () => onTap(option),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppPalette.accentSoft : AppPalette.surface,
            borderRadius: AppRadii.field,
            border: Border.all(
              color: selected ? AppPalette.accent : AppPalette.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppPalette.accentDeep
                    : AppPalette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppType.label.copyWith(
                  color: selected
                      ? AppPalette.accentDeep
                      : AppPalette.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
