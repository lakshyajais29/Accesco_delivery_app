import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/ds/ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ONBOARDING — four screens of intent, then into sign-in.
//
//  Each page pairs a full-bleed editorial photograph with a serif promise and
//  a line of supporting copy. Navigation is unchanged: the final page calls
//  [OnboardingScreen.onComplete] when supplied, otherwise routes to /login.
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingPage {
  final String eyebrow;
  final String headline;
  final String body;
  final String ctaLabel;
  final String imagePath;

  const _OnboardingPage({
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.ctaLabel,
    required this.imagePath,
  });
}

const _pages = <_OnboardingPage>[
  _OnboardingPage(
    eyebrow: 'Fifteen Minutes',
    headline: '15 Minutes.\nThe Whole Look.',
    body: 'Your complete outfit. Dark store to doorstep. Before the moment '
        'passes.',
    ctaLabel: 'Enter InstaStyle',
    imagePath: 'assets/images/onboarding/01_twirl.png',
  ),
  _OnboardingPage(
    eyebrow: 'Try at Home',
    headline: 'Try First.\nPay for What Stays.',
    body: 'Your rider waits. Your mirror decides. Zero commitment until '
        'you’re certain.',
    ctaLabel: 'Continue',
    imagePath: 'assets/images/onboarding/02_rider.png',
  ),
  _OnboardingPage(
    eyebrow: 'Made for You',
    headline: 'Swipe\nYour Story.',
    body: 'Swipe right. Build your cart. Let InstaStyle learn your taste in '
        'real time.',
    ctaLabel: 'Continue',
    imagePath: 'assets/images/onboarding/03_swipe.png',
  ),
  _OnboardingPage(
    eyebrow: 'Perfect Fit',
    headline: 'Your Size.\nRemembered.',
    body: 'Set your measurements once. InstaStyle never wrong-sizes you again.',
    ctaLabel: 'Get Started',
    imagePath: 'assets/images/onboarding/04_tape.png',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onCtaPressed() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: AppMotion.normal,
        curve: AppMotion.enter,
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

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final page = _pages[_currentPage];
    final isLastPage = _currentPage == _pages.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: Stack(
          children: [
            // ── Paged photography + copy ─────────────────────────────────
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) =>
                  _OnboardingPageView(page: _pages[i]),
            ),

            // ── Skip ─────────────────────────────────────────────────────
            if (!isLastPage)
              Positioned(
                top: 0,
                right: inset,
                child: SafeArea(
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'Skip'.toUpperCase(),
                      style: AppType.eyebrow.copyWith(
                        color: AppPalette.textOnDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Progress + CTA ───────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    0,
                    inset,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _pages.length; i++)
                            AnimatedContainer(
                              duration: AppMotion.normal,
                              curve: AppMotion.standard,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              height: 3,
                              width: i == _currentPage ? 22 : 8,
                              decoration: BoxDecoration(
                                color: i == _currentPage
                                    ? AppPalette.accent
                                    : AppPalette.lineStrong,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: page.ctaLabel,
                        icon: Icons.arrow_forward,
                        trailingIcon: true,
                        onPressed: _onCtaPressed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One onboarding page: photography up top, copy on the ivory panel below.
class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final visualHeight = MediaQuery.sizeOf(context).height * 0.52;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: visualHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                page.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppPalette.bannerWash),
                ),
              ),
              // Fades the photograph into the ivory panel so the seam between
              // image and copy never reads as a hard edge.
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppPalette.canvas, Color(0x00FBF9F6)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(inset, AppSpacing.xs, inset, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.eyebrow.toUpperCase(),
                  style: AppType.eyebrow.copyWith(color: AppPalette.accent),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  page.headline,
                  style: AppType.displayLarge.responsive(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(page.body, style: AppType.bodyLarge),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
