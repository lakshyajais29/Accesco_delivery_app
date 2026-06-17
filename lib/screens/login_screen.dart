import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LoginScreen — Phone Auth / OTP  (Cinematic Dark Glassmorphism)
//
//  Flow:  Enter Phone → Receive OTP → Verify → Navigate /home
//  Design: Full-bleed editorial background · dark gradient overlay ·
//          glassmorphism form card · warm brown CTA · gold accents
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── Firebase ────────────────────────────────────────────────────────────
  final _auth = FirebaseAuth.instance;

  // ── Controllers ─────────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  // ── State ───────────────────────────────────────────────────────────────
  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;
  String _errorMessage = '';
  String _countryCode = '+91'; // India default for rapid-delivery

  // ── Animations ──────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeT;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideT;
  late final AnimationController _pulseCtrl;

  // ── Parallax atmosphere ─────────────────────────────────────────────────
  late final AnimationController _atmosCtrl;

  @override
  void initState() {
    super.initState();

    // Content fade-in
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeT = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );

    // Card slide-up
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideT = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    ));

    // Gold shimmer pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Atmospheric drift
    _atmosCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Kick off entrance
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeCtrl.forward();
        _slideCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _atmosCtrl.dispose();
    super.dispose();
  }

  // ── Firebase Phone Auth ─────────────────────────────────────────────────
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
        // Auto-verify on Android (instant verification / auto-retrieval)
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
        // Auto-focus OTP field
        Future.delayed(const Duration(milliseconds: 300), () {
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

      // Check if user has completed profile setup
      final uid = userCred.user!.uid;
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      final hasProfile = profileDoc.exists &&
          profileDoc.data()?['profileComplete'] == true;

      if (hasProfile) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/profile-setup');
      }
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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Cinematic Background ────────────────────────────────
          _CinematicBackground(atmosCtrl: _atmosCtrl),

          // ── Layer 2: Dark Gradient Overlay ───────────────────────────────
          const _DarkOverlay(),

          // ── Layer 3: Atmospheric Particles ───────────────────────────────
          _FloatingParticles(atmosCtrl: _atmosCtrl),

          // ── Layer 4: Content ─────────────────────────────────────────────
          AnimatedBuilder(
            animation: _fadeT,
            builder: (context, child) => Opacity(
              opacity: _fadeT.value,
              child: child,
            ),
            child: SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomPad * 0.5),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // ── Brand Mark ────────────────────────────────────────
                    _BrandMark(pulseCtrl: _pulseCtrl),

                    const SizedBox(height: 12),

                    // ── Headline ──────────────────────────────────────────
                    Text(
                      'Welcome to\nInstaStyle',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: -0.8,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '15-MINUTE FASHION DELIVERY',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                        color: AppColors.brandTan.withOpacity(0.7),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // ── Glassmorphism Form Card ───────────────────────────
                    SlideTransition(
                      position: _slideT,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _GlassFormCard(
                          otpSent: _otpSent,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          phoneController: _phoneController,
                          otpController: _otpController,
                          phoneFocus: _phoneFocus,
                          otpFocus: _otpFocus,
                          countryCode: _countryCode,
                          onCountryCodeChanged: (v) =>
                              setState(() => _countryCode = v),
                          onSendOtp: _sendOtp,
                          onVerifyOtp: _verifyOtp,
                          onGoBack: _goBackToPhone,
                          pulseCtrl: _pulseCtrl,
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // ── Terms ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'By continuing, you agree to InstaStyle\'s Terms of Service & Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cinematic Background — editorial full-bleed image with subtle parallax
// ─────────────────────────────────────────────────────────────────────────────
class _CinematicBackground extends StatelessWidget {
  final AnimationController atmosCtrl;
  const _CinematicBackground({required this.atmosCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: atmosCtrl,
      builder: (context, child) {
        final t = atmosCtrl.value * 2 * math.pi;
        return Transform.scale(
          scale: 1.08,
          child: Transform.translate(
            offset: Offset(
              math.sin(t * 0.7) * 4,
              math.cos(t * 0.5) * 3,
            ),
            child: child,
          ),
        );
      },
      child: Image.asset(
        'assets/images/onboarding/01_twirl.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF0EBE1),
                AppColors.backgroundLight,
                Color(0xFFEBE5D9),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dark Gradient Overlay — three-stop gradient for text legibility
// ─────────────────────────────────────────────────────────────────────────────
class _DarkOverlay extends StatelessWidget {
  const _DarkOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.35, 0.65, 1.0],
            colors: [
              AppColors.backgroundLight.withOpacity(0.10),
              AppColors.backgroundLight.withOpacity(0.40),
              AppColors.backgroundLight.withOpacity(0.80),
              AppColors.backgroundLight.withOpacity(1.0),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Floating Particles — warm gold dust drifting slowly
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingParticles extends StatelessWidget {
  final AnimationController atmosCtrl;
  const _FloatingParticles({required this.atmosCtrl});

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
    final rng = math.Random(42);
    for (int i = 0; i < 18; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble() * math.pi * 2;

      final x = baseX + math.sin(time * speed + phase) * 20;
      final y = baseY - (time * speed * 8) % size.height;
      final wrappedY = y < 0 ? y + size.height : y;
      final opacity = 0.06 + rng.nextDouble() * 0.12;
      final radius = 1.0 + rng.nextDouble() * 1.5;

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

// ─────────────────────────────────────────────────────────────────────────────
//  Brand Mark — gold line + INSTASTYLE + gold line
// ─────────────────────────────────────────────────────────────────────────────
class _BrandMark extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _BrandMark({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, child) {
        final opacity = 0.4 + pulseCtrl.value * 0.3;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 1,
              color: AppColors.brandTan.withOpacity(opacity),
            ),
            const SizedBox(width: 14),
            Text(
              'INSTASTYLE',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 5.0,
                color: AppColors.brandTan.withOpacity(opacity + 0.15),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 32,
              height: 1,
              color: AppColors.brandTan.withOpacity(opacity),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Glass Form Card — glassmorphism container with Phone/OTP form
// ─────────────────────────────────────────────────────────────────────────────
class _GlassFormCard extends StatelessWidget {
  final bool otpSent;
  final bool isLoading;
  final String errorMessage;
  final TextEditingController phoneController;
  final TextEditingController otpController;
  final FocusNode phoneFocus;
  final FocusNode otpFocus;
  final String countryCode;
  final ValueChanged<String> onCountryCodeChanged;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onGoBack;
  final AnimationController pulseCtrl;

  const _GlassFormCard({
    required this.otpSent,
    required this.isLoading,
    required this.errorMessage,
    required this.phoneController,
    required this.otpController,
    required this.phoneFocus,
    required this.otpFocus,
    required this.countryCode,
    required this.onCountryCodeChanged,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onGoBack,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.separatorLight,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 40,
                spreadRadius: -8,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: const Cubic(0.16, 1.0, 0.3, 1.0),
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: otpSent
                ? _OtpForm(
                    key: const ValueKey('otp'),
                    otpController: otpController,
                    otpFocus: otpFocus,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    onVerify: onVerifyOtp,
                    onGoBack: onGoBack,
                    pulseCtrl: pulseCtrl,
                  )
                : _PhoneForm(
                    key: const ValueKey('phone'),
                    phoneController: phoneController,
                    phoneFocus: phoneFocus,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    countryCode: countryCode,
                    onCountryCodeChanged: onCountryCodeChanged,
                    onSendOtp: onSendOtp,
                    pulseCtrl: pulseCtrl,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Phone Number Form
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneForm extends StatelessWidget {
  final TextEditingController phoneController;
  final FocusNode phoneFocus;
  final bool isLoading;
  final String errorMessage;
  final String countryCode;
  final ValueChanged<String> onCountryCodeChanged;
  final VoidCallback onSendOtp;
  final AnimationController pulseCtrl;

  const _PhoneForm({
    super.key,
    required this.phoneController,
    required this.phoneFocus,
    required this.isLoading,
    required this.errorMessage,
    required this.countryCode,
    required this.onCountryCodeChanged,
    required this.onSendOtp,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Row(
          children: [
            Text(
              'SIGN IN',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                color: AppColors.brandTan,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Text(
          'Your phone number',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: AppColors.textDark,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'We\'ll send a verification code via SMS.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppColors.textMutedLight,
          ),
        ),

        const SizedBox(height: 20),

        // Phone input row
        Row(
          children: [
            // Country code selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.separatorLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: countryCode,
                  isDense: true,
                  dropdownColor: AppColors.surfaceCardLight,
                  style: GoogleFonts.robotoMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textMutedLight,
                  ),
                  items: const [
                    DropdownMenuItem(value: '+91', child: Text('+91')),
                    DropdownMenuItem(value: '+1', child: Text('+1')),
                    DropdownMenuItem(value: '+44', child: Text('+44')),
                    DropdownMenuItem(value: '+971', child: Text('+971')),
                    DropdownMenuItem(value: '+65', child: Text('+65')),
                  ],
                  onChanged: (v) {
                    if (v != null) onCountryCodeChanged(v);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Phone number input
            Expanded(
              child: _StyledTextField(
                controller: phoneController,
                focusNode: phoneFocus,
                hintText: '98765 43210',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onSubmitted: (_) => onSendOtp(),
              ),
            ),
          ],
        ),

        // Error message
        if (errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 14, color: AppColors.fomoRed),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorMessage,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.fomoRed,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Send OTP button
        _WarmBrownCTA(
          label: isLoading ? 'SENDING...' : 'SEND CODE',
          onPressed: isLoading ? null : onSendOtp,
          isLoading: isLoading,
          pulseCtrl: pulseCtrl,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OTP Verification Form
// ─────────────────────────────────────────────────────────────────────────────
class _OtpForm extends StatelessWidget {
  final TextEditingController otpController;
  final FocusNode otpFocus;
  final bool isLoading;
  final String errorMessage;
  final VoidCallback onVerify;
  final VoidCallback onGoBack;
  final AnimationController pulseCtrl;

  const _OtpForm({
    super.key,
    required this.otpController,
    required this.otpFocus,
    required this.isLoading,
    required this.errorMessage,
    required this.onVerify,
    required this.onGoBack,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button + label
        Row(
          children: [
            GestureDetector(
              onTap: onGoBack,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCardLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.separatorLight),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: AppColors.brandTan,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'VERIFY',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                color: AppColors.brandTan,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Text(
          'Enter verification code',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: AppColors.textDark,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'A 6-digit code was sent to your phone.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppColors.textMutedLight,
          ),
        ),

        const SizedBox(height: 20),

        // OTP input
        _StyledTextField(
          controller: otpController,
          focusNode: otpFocus,
          hintText: '● ● ● ● ● ●',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          letterSpacing: 10,
          fontSize: 22,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => onVerify(),
        ),

        // Error message
        if (errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 14, color: AppColors.fomoRed),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorMessage,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.fomoRed,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Verify button
        _WarmBrownCTA(
          label: isLoading ? 'VERIFYING...' : 'VERIFY  →',
          onPressed: isLoading ? null : onVerify,
          isLoading: isLoading,
          pulseCtrl: pulseCtrl,
        ),

        const SizedBox(height: 12),

        // Resend link
        Center(
          child: GestureDetector(
            onTap: onGoBack,
            child: Text(
              'Didn\'t receive the code? Resend',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.brandTan.withOpacity(0.7),
                decoration: TextDecoration.underline,
                decorationColor: AppColors.brandTan.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Styled Text Field — dark luxury input
// ─────────────────────────────────────────────────────────────────────────────
class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final double letterSpacing;
  final double fontSize;

  const _StyledTextField({
    required this.controller,
    this.focusNode,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.letterSpacing = 1.5,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      textAlign: textAlign,
      style: GoogleFonts.robotoMono(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
        color: AppColors.textDark,
      ),
      cursorColor: AppColors.brandTan,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.robotoMono(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          letterSpacing: letterSpacing,
          color: AppColors.textMutedLight.withOpacity(0.4),
        ),
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
//  Warm Brown CTA — AppColors.brandWarmBrown gradient, sharp authority
// ─────────────────────────────────────────────────────────────────────────────
class _WarmBrownCTA extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AnimationController pulseCtrl;

  const _WarmBrownCTA({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.pulseCtrl,
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
        curve: Curves.easeOut,
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero, // Sharp — authority per spec
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
                    color: AppColors.brandWarmBrown.withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top sheen
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: AppColors.brandTan.withOpacity(0.35),
              ),
            ),
            if (widget.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
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
                  letterSpacing: 2.8,
                  color: AppColors.ivoryWhite,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
