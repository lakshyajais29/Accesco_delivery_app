import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ProfileSetupScreen — New User Onboarding (Personal Details)
//
//  Shown ONLY for first-time users after Phone Auth.
//  Collects: Name · Date of Birth · Gender · Body Type · Preferred Sizes
//  Saves to Firestore: users/{uid}/profile
//  Design: Dark cinematic bg · glassmorphism stepped form · warm brown CTAs
// ─────────────────────────────────────────────────────────────────────────────

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  // ── Firebase ────────────────────────────────────────────────────────────
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Step state ──────────────────────────────────────────────────────────
  int _currentStep = 0;
  static const int _totalSteps = 3;

  // ── Form data ──────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  DateTime? _dob;
  String? _selectedGender;
  String? _selectedBodyType;
  final Set<String> _selectedSizes = {};

  bool _isSaving = false;
  String _errorMessage = '';

  // ── Animations ──────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeT;
  late final AnimationController _atmosCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _stepCtrl;
  late final Animation<double> _stepT;

  // ── Data ────────────────────────────────────────────────────────────────
  static const _genders = ['Male', 'Female', 'Non-Binary', 'Prefer Not to Say'];
  static const _bodyTypes = ['Slim', 'Athletic', 'Average', 'Curvy', 'Plus Size'];
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

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeT = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );

    _atmosCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _stepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _stepT = CurvedAnimation(
      parent: _stepCtrl,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeCtrl.forward();
        _stepCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _fadeCtrl.dispose();
    _atmosCtrl.dispose();
    _pulseCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────
  void _nextStep() {
    // Validate current step
    if (!_validateCurrentStep()) return;

    if (_currentStep < _totalSteps - 1) {
      _stepCtrl.reset();
      setState(() {
        _currentStep++;
        _errorMessage = '';
      });
      _stepCtrl.forward();
    } else {
      _saveProfile();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _stepCtrl.reset();
      setState(() {
        _currentStep--;
        _errorMessage = '';
      });
      _stepCtrl.forward();
    }
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

  // ── Save to Firestore ───────────────────────────────────────────────────
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 22, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 13, now.month, now.day), // Min 13 yrs
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandWarmBrown,
              onPrimary: AppColors.surfaceCardLight,
              surface: AppColors.surfaceCardLight,
              onSurface: AppColors.textDark,
            ),
            dialogBackgroundColor: AppColors.surfaceCardLight,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _dob = picked;
        _errorMessage = '';
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ──────────────────────────────────────────────────
          _AnimatedBackground(atmosCtrl: _atmosCtrl),
          const _DarkOverlay(),
          _GoldParticles(atmosCtrl: _atmosCtrl),

          // ── Content ─────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _fadeT,
            builder: (context, child) => Opacity(
              opacity: _fadeT.value,
              child: child,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // ── Progress Bar ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _StepProgress(
                      currentStep: _currentStep,
                      totalSteps: _totalSteps,
                      pulseCtrl: _pulseCtrl,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Step Label ─────────────────────────────────────────
                  Text(
                    _stepLabels[_currentStep],
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      color: AppColors.brandTan.withOpacity(0.6),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Headline ───────────────────────────────────────────
                  Text(
                    _stepHeadlines[_currentStep],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                      letterSpacing: -0.5,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _stepSubtexts[_currentStep],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Form Area ──────────────────────────────────────────
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _stepT,
                      builder: (context, child) => Opacity(
                        opacity: _stepT.value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - _stepT.value) * 20),
                          child: child,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildCurrentStep(),
                      ),
                    ),
                  ),

                  // ── Error ──────────────────────────────────────────────
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 14, color: AppColors.fomoRed),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.fomoRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Bottom Navigation ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            flex: 1,
                            child: _GhostButton(
                              label: '← BACK',
                              onPressed: _prevStep,
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _WarmBrownCTA(
                            label: _currentStep == _totalSteps - 1
                                ? (_isSaving ? 'SAVING...' : 'COMPLETE SETUP  →')
                                : 'CONTINUE  →',
                            onPressed: _isSaving ? null : _nextStep,
                            isLoading: _isSaving,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step data ───────────────────────────────────────────────────────────
  static const _stepLabels = [
    'STEP 01   ABOUT YOU',
    'STEP 02   IDENTITY',
    'STEP 03   FIT PREFERENCES',
  ];

  static const _stepHeadlines = [
    'Let\'s Get\nAcquainted',
    'Express\nYourself',
    'Your Perfect\nFit',
  ];

  static const _stepSubtexts = [
    'A few details so we can personalize your experience.',
    'Help us curate styles that resonate with you.',
    'Select your sizes for spot-on recommendations.',
  ];

  // ── Step builders ───────────────────────────────────────────────────────
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildNameDobStep();
      case 1:
        return _buildGenderBodyStep();
      case 2:
        return _buildSizeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Name & Date of Birth ────────────────────────────────────────
  Widget _buildNameDobStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: _GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(text: 'FULL NAME'),
            const SizedBox(height: 10),
            _StyledTextField(
              controller: _nameController,
              focusNode: _nameFocus,
              hintText: 'e.g. Arjun Sharma',
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.person_outline_rounded,
            ),

            const SizedBox(height: 28),

            _SectionLabel(text: 'DATE OF BIRTH'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.separator),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: _dob != null
                          ? AppColors.brandTan
                          : AppColors.mutedText.withOpacity(0.4),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _dob != null
                          ? '${_dob!.day.toString().padLeft(2, '0')} / ${_dob!.month.toString().padLeft(2, '0')} / ${_dob!.year}'
                          : 'DD / MM / YYYY',
                      style: GoogleFonts.robotoMono(
                        fontSize: 16,
                        fontWeight:
                            _dob != null ? FontWeight.w700 : FontWeight.w400,
                        letterSpacing: 1.5,
                        color: _dob != null
                            ? AppColors.ivoryWhite
                            : AppColors.mutedText.withOpacity(0.4),
                      ),
                    ),
                    const Spacer(),
                    if (_dob != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brandWarmBrown.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_calculateAge(_dob!)} yrs',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandTan,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Gender & Body Type ──────────────────────────────────────────
  Widget _buildGenderBodyStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gender
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(text: 'GENDER'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _genders.map((g) {
                    final selected = _selectedGender == g;
                    return _SelectionChip(
                      label: g,
                      icon: _genderIcons[g]!,
                      selected: selected,
                      onTap: () => setState(() {
                        _selectedGender = g;
                        _errorMessage = '';
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Body type (optional)
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SectionLabel(text: 'BODY TYPE'),
                    const Spacer(),
                    Text(
                      'OPTIONAL',
                      style: GoogleFonts.montserrat(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: AppColors.mutedText.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _bodyTypes.map((bt) {
                    final selected = _selectedBodyType == bt;
                    return _SelectionChip(
                      label: bt,
                      icon: _bodyTypeIcons[bt]!,
                      selected: selected,
                      onTap: () => setState(() {
                        _selectedBodyType =
                            _selectedBodyType == bt ? null : bt;
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Preferred Sizes ─────────────────────────────────────────────
  Widget _buildSizeStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(text: 'YOUR USUAL SIZES'),
            const SizedBox(height: 6),
            Text(
              'Select all that apply across brands.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 20),

            // Size grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: _sizeOptions.length,
              itemBuilder: (context, index) {
                final size = _sizeOptions[index];
                final selected = _selectedSizes.contains(size);
                return _SizeTile(
                  label: size,
                  selected: selected,
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedSizes.remove(size);
                    } else {
                      _selectedSizes.add(size);
                    }
                    _errorMessage = '';
                  }),
                );
              },
            ),

            if (_selectedSizes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.brandWarmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.brandWarmBrown.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.brandTan),
                    const SizedBox(width: 8),
                    Text(
                      'Selected: ${_selectedSizes.join(', ')}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.brandTan,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step Progress Bar
// ─────────────────────────────────────────────────────────────────────────────
class _StepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final AnimationController pulseCtrl;

  const _StepProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentStep;
        final isCompleted = i < currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isCompleted || isActive
                    ? const LinearGradient(
                        colors: [AppColors.brandWarmBrown, AppColors.brandTan],
                      )
                    : null,
                color: isCompleted || isActive
                    ? null
                    : AppColors.separatorLight,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Glass Card container
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.separatorLight,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            color: AppColors.brandTan,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Selection Chip (gender, body type)
// ─────────────────────────────────────────────────────────────────────────────
class _SelectionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.surfaceCardLight
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.brandWarmBrown
                : AppColors.separatorLight,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.brandWarmBrown : AppColors.textMutedLight,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
                color: selected ? AppColors.brandWarmBrown : AppColors.textMutedLight,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_rounded,
                  size: 14, color: AppColors.brandWarmBrown),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Size Tile (grid item)
// ─────────────────────────────────────────────────────────────────────────────
class _SizeTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SizeTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceCardLight : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.brandWarmBrown
                : AppColors.separatorLight,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.brandWarmBrown.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: selected ? AppColors.brandWarmBrown : AppColors.textMutedLight,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Styled Text Field
// ─────────────────────────────────────────────────────────────────────────────
class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;

  const _StyledTextField({
    required this.controller,
    this.focusNode,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      ),
      cursorColor: AppColors.brandTan,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textMutedLight.withOpacity(0.4),
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: AppColors.textMutedLight)
            : null,
        filled: true,
        fillColor: AppColors.backgroundLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.separatorLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.brandWarmBrown,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Warm Brown CTA
// ─────────────────────────────────────────────────────────────────────────────
class _WarmBrownCTA extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _WarmBrownCTA({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_WarmBrownCTA> createState() => _WarmBrownCTAState();
}

class _WarmBrownCTAState extends State<_WarmBrownCTA> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _pressed
                ? [AppColors.brandDeepBrown, AppColors.brandWarmBrown]
                : [AppColors.brandWarmBrown, AppColors.brandTan],
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: AppColors.brandWarmBrown.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 1,
                color: AppColors.brandTan.withOpacity(0.35),
              ),
            ),
            if (widget.isLoading)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ivoryWhite,
                ),
              )
            else
              Text(
                widget.label,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  color: AppColors.ivoryWhite,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ghost Button (back)
// ─────────────────────────────────────────────────────────────────────────────
class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GhostButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.separatorLight, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.brandTan,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Background Layers (reused pattern from LoginScreen)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedBackground extends StatelessWidget {
  final AnimationController atmosCtrl;
  const _AnimatedBackground({required this.atmosCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: atmosCtrl,
      builder: (context, child) {
        final t = atmosCtrl.value * 2 * math.pi;
        return Transform.scale(
          scale: 1.06,
          child: Transform.translate(
            offset: Offset(math.sin(t * 0.5) * 3, math.cos(t * 0.4) * 2),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.4, 0.7, 1.0],
            colors: [
              Color(0xFFF0EBE1),
              AppColors.backgroundLight,
              Color(0xFFEBE5D9),
              AppColors.backgroundLight,
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkOverlay extends StatelessWidget {
  const _DarkOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [
              AppColors.brandWarmBrown.withOpacity(0.06),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldParticles extends StatelessWidget {
  final AnimationController atmosCtrl;
  const _GoldParticles({required this.atmosCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: atmosCtrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlePainter(
            time: atmosCtrl.value * 20,
            color: AppColors.brandTan,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double time;
  final Color color;
  _ParticlePainter({required this.time, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(77);
    for (int i = 0; i < 12; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.2 + rng.nextDouble() * 0.5;
      final phase = rng.nextDouble() * math.pi * 2;
      final x = baseX + math.sin(time * speed + phase) * 15;
      final y = baseY - (time * speed * 6) % size.height;
      final wrappedY = y < 0 ? y + size.height : y;
      final opacity = 0.04 + rng.nextDouble() * 0.08;
      final radius = 0.8 + rng.nextDouble() * 1.2;

      canvas.drawCircle(
        Offset(x, wrappedY),
        radius,
        Paint()..color = color.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.time != time;
}
