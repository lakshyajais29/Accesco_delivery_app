import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OnboardingScreen — 4 Screens of Desire  (LIGHT THEME / Montserrat)
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  // ── Light Brand Palette ───────────────────────────────────────────────────
  static const Color _bgCream      = Color(0xFFF5F0EA); // warm off-white bg
  static const Color _brandGold    = Color(0xFFB8892A); // gold accent
  static const Color _brandBrown   = Color(0xFF7B4A2D); // CTA button
  static const Color _darkBrown    = Color(0xFF4A2E1A); // button gradient end
  static const Color _textDark     = Color(0xFF1A1208); // headlines
  static const Color _textMuted    = Color(0xFF8C7B6B); // subtext
  static const Color _divider      = Color(0xFFDDD5C8); // stripe inactive

  // ── Page state ─────────────────────────────────────────────────────────────
  late final PageController _pageController;
  int _currentPage = 0;
  static const int _totalPages = 4;

  // ── Progress stripe controller ────────────────────────────────────────────
  late final AnimationController _stripeCtrl;
  late final Animation<double>   _stripeT;

  // ── Content reveal ────────────────────────────────────────────────────────
  late final AnimationController _contentCtrl;
  late final Animation<double>   _contentT;

  // ── Atmosphere drift (parallax) ───────────────────────────────────────────
  late final Ticker _atmosTicker;
  double _atmosTime = 0.0;

  static const List<_PageData> _pages = [
    _PageData(
      headline:   '15 Minutes.\nThe Whole Look.',
      subtext:    'Your complete outfit. Dark store to doorstep. Before the moment passes.',
      ctaLabel:   'ENTER INSTASTYLE',
      visualMotif: _VisualMotif.midTwirl,
      imagePath:  'assets/images/onboarding/01_twirl.png',
    ),
    _PageData(
      headline:   'Try First.\nPay for What Stays.',
      subtext:    'Your rider waits. Your mirror decides. Zero commitment until you\u2019re certain.',
      ctaLabel:   'CONTINUE',
      visualMotif: _VisualMotif.riderAtDoor,
      imagePath:  'assets/images/onboarding/02_rider.png',
    ),
    _PageData(
      headline:   'Swipe Your Story.',
      subtext:    'Swipe right. Build your cart. Let InstaStyle learn your taste in real-time.',
      ctaLabel:   'CONTINUE',
      visualMotif: _VisualMotif.swipingHand,
      imagePath:  'assets/images/onboarding/03_swipe.png',
    ),
    _PageData(
      headline:   'Your Size.\nRemembered.\nForever.',
      subtext:    'Set your measurements once. InstaStyle never wrong-sizes you again.',
      ctaLabel:   'START  \u2192',
      visualMotif: _VisualMotif.measuringTape,
      imagePath:  'assets/images/onboarding/04_tape.png',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    _stripeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _stripeT = CurvedAnimation(parent: _stripeCtrl, curve: Curves.easeInOut);

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _contentT = CurvedAnimation(
      parent: _contentCtrl,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );

    _atmosTicker = createTicker((elapsed) {
      if (mounted) {
        setState(() => _atmosTime = elapsed.inMilliseconds / 1000.0);
      }
    })..start();

    _stripeCtrl.forward();
    _contentCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stripeCtrl.dispose();
    _contentCtrl.dispose();
    _atmosTicker.dispose();
    super.dispose();
  }

  void _onCtaPressed() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 520),
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _stripeCtrl..reset()..forward();
    _contentCtrl..reset()..forward();
  }

  @override
  Widget build(BuildContext context) {
    // Light status bar icons on image, dark on content — we set dark globally
    // and the image area handles its own overlay.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: _bgCream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── PageView ──────────────────────────────────────────────────────
          PageView.builder(
            controller:    _pageController,
            itemCount:     _totalPages,
            onPageChanged: _onPageChanged,
            itemBuilder:   (context, index) => _OnboardingPage(
              data:       _pages[index],
              contentT:   _contentT,
              atmosTime:  _atmosTime,
              bgCream:    _bgCream,
              brandGold:  _brandGold,
              brandBrown: _brandBrown,
              darkBrown:  _darkBrown,
              textDark:   _textDark,
              textMuted:  _textMuted,
            ),
          ),

          // ── Progress stripes — top, light status bar area ─────────────────
          Positioned(
            top:   MediaQuery.of(context).padding.top + 20,
            left:  24,
            right: 24,
            child: _ProgressStripes(
              total:         _totalPages,
              currentIndex:  _currentPage,
              fillT:         _stripeT,
              activeColor:   _brandGold,
              activeColor2:  _brandBrown,
              inactiveColor: _divider,
            ),
          ),

          // ── Bottom CTA ────────────────────────────────────────────────────
          Positioned(
            left:   0,
            right:  0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: _CtaButton(
                  label:      _pages[_currentPage].ctaLabel,
                  onPressed:  _onCtaPressed,
                  brandBrown: _brandBrown,
                  darkBrown:  _darkBrown,
                  brandGold:  _brandGold,
                  bgCream:    _bgCream,
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
//  Per-page layout
//  Image: top 54% — unchanged dark cinematic treatment
//  Content: below image on light cream bg
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingPage extends StatelessWidget {
  final _PageData         data;
  final Animation<double> contentT;
  final double            atmosTime;
  final Color bgCream, brandGold, brandBrown, darkBrown, textDark, textMuted;

  const _OnboardingPage({
    required this.data,
    required this.contentT,
    required this.atmosTime,
    required this.bgCream,
    required this.brandGold,
    required this.brandBrown,
    required this.darkBrown,
    required this.textDark,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    final size        = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final visualH     = size.height * 0.54;

    return Column(
      children: [
        // ── Cinematic image (dark treatment — unchanged per spec) ──────────
        SizedBox(
          height: visualH,
          width:  double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _EditorialVisual(
                motif:      data.visualMotif,
                imagePath:  data.imagePath,
                atmosTime:  atmosTime,
                brandBrown: brandBrown,
                darkBrown:  darkBrown,
                brandGold:  brandGold,
                bgCream:    bgCream,
              ),

              // Fade bottom of image into cream
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: 45,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin:  Alignment.bottomCenter,
                      end:    Alignment.topCenter,
                      colors: [bgCream.withOpacity(0.65), bgCream.withOpacity(0.0)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Light content area ─────────────────────────────────────────────
        Expanded(
          child: AnimatedBuilder(
            animation: contentT,
            builder: (context, child) => Opacity(
              opacity: contentT.value,
              child: Transform.translate(
                offset: Offset(0, (1 - contentT.value) * 16),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chapter label
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'CHAPTER ${_chapterNum(data.visualMotif)}   INSTASTYLE',
                        style: GoogleFonts.montserrat(
                          fontSize:      12,
                          fontWeight:    FontWeight.w600,
                          letterSpacing: 2.2,
                          color:         brandGold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Headline
                  Text(
                    data.headline,
                    style: GoogleFonts.montserrat(
                      fontSize:      30,
                      fontWeight:    FontWeight.w800,
                      height:        1.18,
                      letterSpacing: -0.4,
                      color:         textDark,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtext
                  Text(
                    data.subtext,
                    style: GoogleFonts.montserrat(
                      fontSize:      15,
                      fontWeight:    FontWeight.w400,
                      fontStyle:     FontStyle.italic,
                      height:        1.65,
                      letterSpacing: 0.1,
                      color:         textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _chapterNum(_VisualMotif m) {
    switch (m) {
      case _VisualMotif.midTwirl:      return '01';
      case _VisualMotif.riderAtDoor:   return '02';
      case _VisualMotif.swipingHand:   return '03';
      case _VisualMotif.measuringTape: return '04';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Editorial Visual — dark cinematic image treatment (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
enum _VisualMotif { midTwirl, riderAtDoor, swipingHand, measuringTape }

class _EditorialVisual extends StatelessWidget {
  final _VisualMotif motif;
  final String       imagePath;
  final double       atmosTime;
  final Color brandBrown, darkBrown, brandGold, bgCream;

  const _EditorialVisual({
    required this.motif,
    required this.imagePath,
    required this.atmosTime,
    required this.brandBrown,
    required this.darkBrown,
    required this.brandGold,
    required this.bgCream,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo with subtle parallax
        Image.asset(
          imagePath,
          fit: BoxFit.cover,
          alignment: Alignment(
            math.sin(atmosTime * 0.25) * 0.04,
            math.cos(atmosTime * 0.20) * 0.03,
          ),
          errorBuilder: (_, __, ___) => _MissingImageFallback(
            imagePath:  imagePath,
            brandBrown: brandBrown,
            darkBrown:  darkBrown,
            bgCream:    bgCream,
          ),
        ),

        // Subtle light vignette
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  bgCream.withOpacity(0.0),
                  bgCream.withOpacity(0.1),
                  bgCream.withOpacity(0.4),
                ],
                stops: const [0.50, 0.82, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MissingImageFallback extends StatelessWidget {
  final String imagePath;
  final Color  brandBrown, darkBrown, bgCream;

  const _MissingImageFallback({
    required this.imagePath,
    required this.brandBrown,
    required this.darkBrown,
    required this.bgCream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [bgCream, bgCream.withOpacity(0.9), bgCream.withOpacity(0.8)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'IMAGE NOT FOUND',
              style: GoogleFonts.montserrat(
                fontWeight:    FontWeight.w900,
                fontSize:      11,
                letterSpacing: 3.0,
                color:         bgCream.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                imagePath,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color:    bgCream.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BloomOverlayPainter extends CustomPainter {
  final _VisualMotif motif;
  final double       atmosTime;
  final Color bgCream, brandGold;

  _BloomOverlayPainter({
    required this.motif,
    required this.atmosTime,
    required this.bgCream,
    required this.brandGold,
  });

  Offset _focalPoint(Size s) {
    final wobble = math.sin(atmosTime * 0.4) * 8;
    switch (motif) {
      case _VisualMotif.midTwirl:      return Offset(s.width * 0.55 + wobble, s.height * 0.42);
      case _VisualMotif.riderAtDoor:   return Offset(s.width * 0.68 + wobble, s.height * 0.55);
      case _VisualMotif.swipingHand:   return Offset(s.width * 0.62 + wobble, s.height * 0.50);
      case _VisualMotif.measuringTape: return Offset(s.width * 0.50 + wobble, s.height * 0.58);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final focal = _focalPoint(size);
    final r     = size.shortestSide * 0.22;
    canvas.drawCircle(
      focal, r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            bgCream.withOpacity(0.16),
            brandGold.withOpacity(0.06),
            bgCream.withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: focal, radius: r))
        ..blendMode = BlendMode.screen,
    );
  }

  @override
  bool shouldRepaint(_BloomOverlayPainter old) => old.atmosTime != atmosTime;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Progress Stripes
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressStripes extends StatelessWidget {
  final int               total;
  final int               currentIndex;
  final Animation<double> fillT;
  final Color             activeColor;
  final Color             activeColor2;
  final Color             inactiveColor;

  const _ProgressStripes({
    required this.total,
    required this.currentIndex,
    required this.fillT,
    required this.activeColor,
    required this.activeColor2,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive    = i == currentIndex;
        final isCompleted = i <  currentIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 5.0),
            child: AnimatedBuilder(
              animation: fillT,
              builder: (_, __) {
                final fillFrac = isCompleted
                    ? 1.0
                    : isActive
                        ? fillT.value
                        : 0.0;
                return CustomPaint(
                  size: const Size(double.infinity, 3),
                  painter: _StripePainter(
                    fillFrac:      fillFrac,
                    activeColor:   activeColor,
                    activeColor2:  activeColor2,
                    inactiveColor: inactiveColor,
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

class _StripePainter extends CustomPainter {
  final double fillFrac;
  final Color  activeColor, activeColor2, inactiveColor;

  _StripePainter({
    required this.fillFrac,
    required this.activeColor,
    required this.activeColor2,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Track
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)),
      Paint()..color = inactiveColor,
    );
    // Fill
    if (fillFrac > 0) {
      final fillRect = Rect.fromLTWH(0, 0, size.width * fillFrac, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            colors: [activeColor, activeColor2],
          ).createShader(fillRect),
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.fillFrac != fillFrac;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CTA Button — warm brown, Montserrat Black, sharp corners per spec
// ─────────────────────────────────────────────────────────────────────────────
class _CtaButton extends StatefulWidget {
  final String       label;
  final VoidCallback onPressed;
  final Color brandBrown, darkBrown, brandGold, bgCream;

  const _CtaButton({
    required this.label,
    required this.onPressed,
    required this.brandBrown,
    required this.darkBrown,
    required this.brandGold,
    required this.bgCream,
  });

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _isPressed = true),
      onTapUp:     (_) => setState(() => _isPressed = false),
      onTapCancel: ()  => setState(() => _isPressed = false),
      onTap:       widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve:    Curves.easeOut,
        height:   54,
        width:    double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: _isPressed
                ? [widget.darkBrown,  widget.brandBrown]
                : [widget.brandBrown, widget.darkBrown],
          ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color:        widget.brandBrown.withOpacity(0.30),
                    blurRadius:   16,
                    spreadRadius: -2,
                    offset:       const Offset(0, 6),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top sheen line
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  color: widget.brandGold.withOpacity(0.4),
                ),
              ),
            ),
            Text(
              widget.label,
              style: GoogleFonts.montserrat(
                fontSize:      13,
                fontWeight:    FontWeight.w900,
                letterSpacing: 2.6,
                color:         widget.bgCream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Page data model
// ─────────────────────────────────────────────────────────────────────────────
class _PageData {
  final String       headline;
  final String       subtext;
  final String       ctaLabel;
  final _VisualMotif visualMotif;
  final String       imagePath;

  const _PageData({
    required this.headline,
    required this.subtext,
    required this.ctaLabel,
    required this.visualMotif,
    required this.imagePath,
  });
}