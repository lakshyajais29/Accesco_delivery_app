import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/ds/ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LOGIN — Firebase phone auth / OTP.
//
//  Flow (unchanged): enter phone → receive OTP → verify → route to /home when
//  the profile is complete, otherwise /profile-setup.
//
//  The presentation is rebuilt on the design system: an editorial photo header
//  over an ivory canvas, with the form on a lifted card. The two steps share
//  one card that cross-fades between them, so the layout never jumps.
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Firebase ──────────────────────────────────────────────────────────
  final _auth = FirebaseAuth.instance;

  // ── Controllers ───────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────
  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;
  String _errorMessage = '';
  String _countryCode = '+91'; // India default for rapid delivery

  late final AnimationController _entranceCtrl;

  static const _countryCodes = ['+91', '+1', '+44', '+61', '+971'];

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
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Firebase phone auth ───────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final fullNumber = '$_countryCode$phone';

    await _auth.verifyPhoneNumber(
      phoneNumber: fullNumber,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verify on Android (instant verification / auto-retrieval).
        await _signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = e.message ?? 'Verification failed. Please try again.';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _otpSent = true;
          _verificationId = verificationId;
          _resendToken = resendToken;
        });
        Future.delayed(AppMotion.normal, () {
          if (mounted) _otpFocus.requestFocus();
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Invalid code. Try again.';
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCred = await _auth.signInWithCredential(credential);
      if (!mounted) return;

      // Route on whether profile setup has been completed.
      final uid = userCred.user!.uid;
      final profileDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!mounted) return;

      final hasProfile =
          profileDoc.exists && profileDoc.data()?['profileComplete'] == true;

      Navigator.of(context).pushReplacementNamed(
        hasProfile ? '/home' : '/profile-setup',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Sign in failed.';
      });
    }
  }

  void _goBackToPhone() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _errorMessage = '';
    });
    Future.delayed(AppMotion.fast, () {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  Future<void> _pickCountryCode() async {
    final picked = await showAppSheet<String>(
      context,
      child: AppSheet(
        title: 'Country Code',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in _countryCodes)
              ListTile(
                onTap: () => Navigator.of(context).pop(code),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.page(context),
                ),
                title: Text(
                  code,
                  style: AppType.bodyLarge.copyWith(
                    color: AppPalette.textPrimary,
                  ),
                ),
                trailing: code == _countryCode
                    ? const Icon(
                        Icons.check,
                        size: 19,
                        color: AppPalette.accent,
                      )
                    : null,
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _countryCode = picked);
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final size = MediaQuery.sizeOf(context);
    final headerHeight = (size.height * 0.32).clamp(200.0, 320.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: FadeTransition(
          opacity: _entranceCtrl.drive(CurveTween(curve: AppMotion.enter)),
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // ── Editorial header ───────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: headerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/onboarding/01_twirl.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppPalette.bannerWash,
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppPalette.photoScrim,
                        ),
                      ),
                      Positioned(
                        left: inset,
                        right: inset,
                        bottom: AppSpacing.xl,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '15-Minute Fashion Delivery'.toUpperCase(),
                              style: AppType.eyebrow.copyWith(
                                color: AppPalette.gold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Welcome to\nInstaStyle',
                              style: AppType.displayLarge
                                  .responsive(context)
                                  .copyWith(
                                    color: AppPalette.textOnDark,
                                    fontSize: 38,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Form ───────────────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  AppSpacing.xl,
                  inset,
                  AppSpacing.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: AppMotion.normal,
                    curve: AppMotion.standard,
                    alignment: Alignment.topCenter,
                    child: AppCard(
                      elevated: true,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _otpSent ? _buildOtpStep() : _buildPhoneStep(),
                    ),
                  ),
                ),
              ),

              // ── Terms ──────────────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  inset + AppSpacing.md,
                  0,
                  inset + AppSpacing.md,
                  AppSpacing.xl,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'By continuing, you agree to InstaStyle\'s Terms of '
                    'Service & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: AppType.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey('phone-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sign In', style: AppType.displaySmall.responsive(context)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'We\'ll text you a six-digit code to confirm it\'s you.',
          style: AppType.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Phone Number'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code selector.
            GestureDetector(
              onTap: _isLoading ? null : _pickCountryCode,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: AppRadii.field,
                  border: Border.all(color: AppPalette.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _countryCode,
                      style: AppType.bodyLarge.copyWith(
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    const Icon(
                      Icons.expand_more,
                      size: 17,
                      color: AppPalette.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AppTextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                hint: '98765 43210',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                enabled: !_isLoading,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) {
                  if (_errorMessage.isNotEmpty) {
                    setState(() => _errorMessage = '');
                  }
                },
                onSubmitted: (_) => _sendOtp(),
              ),
            ),
          ],
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ErrorLine(message: _errorMessage),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Send Code',
          icon: Icons.arrow_forward,
          trailingIcon: true,
          isLoading: _isLoading,
          onPressed: _sendOtp,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Verify',
                style: AppType.displaySmall.responsive(context),
              ),
            ),
            AppIconButton(
              icon: Icons.edit_outlined,
              size: 18,
              tooltip: 'Change number',
              onPressed: _isLoading ? null : _goBackToPhone,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text.rich(
          TextSpan(
            style: AppType.bodyMedium,
            children: [
              const TextSpan(text: 'Enter the code we sent to '),
              TextSpan(
                text: '$_countryCode ${_phoneController.text.trim()}',
                style: AppType.bodyMedium.copyWith(
                  color: AppPalette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Verification Code',
          controller: _otpController,
          focusNode: _otpFocus,
          hint: '••••••',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          enabled: !_isLoading,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            if (_errorMessage.isNotEmpty) {
              setState(() => _errorMessage = '');
            }
            // Submit as soon as the final digit lands — one less tap.
            if (value.length == 6) _verifyOtp();
          },
          onSubmitted: (_) => _verifyOtp(),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ErrorLine(message: _errorMessage),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Verify & Continue',
          isLoading: _isLoading,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton.ghost(
          label: 'Resend Code',
          fullWidth: true,
          trailingIcon: false,
          onPressed: _isLoading ? null : _sendOtp,
        ),
      ],
    );
  }
}

/// Inline validation message under a field group.
class _ErrorLine extends StatelessWidget {
  final String message;

  const _ErrorLine({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppPalette.dangerSoft,
        borderRadius: AppRadii.badge,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 15,
            color: AppPalette.danger,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppType.bodySmall.copyWith(color: AppPalette.danger),
            ),
          ),
        ],
      ),
    );
  }
}
