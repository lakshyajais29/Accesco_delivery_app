import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../widgets/ds/ds.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const SplashScreen({super.key, this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Hide status bar for full immersive splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.asset('assets/videos/splash_video.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.setLooping(false);
        _controller.setVolume(1.0); // muted — splash screens are silent
        _controller.play();
      });

    // Navigate when video ends
    _controller.addListener(_onVideoProgress);
  }

  void _onVideoProgress() {
    if (!mounted) return;
    final val = _controller.value;
    if (val.isInitialized &&
        !val.isPlaying &&
        val.position >= val.duration &&
        val.duration > Duration.zero) {
      _controller.removeListener(_onVideoProgress);
      _navigateNext();
    }
  }

  void _navigateNext() {
    // Restore system UI before navigating
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoProgress);
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.ink,
      body: AnimatedSwitcher(
        duration: AppMotion.normal,
        child: _initialized
            ? SizedBox.expand(
                key: const ValueKey('video'),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            // Branded hold rather than a black frame: if the asset is slow to
            // decode — or missing entirely — the first thing a user sees is
            // still the wordmark, not a void.
            : const _SplashBrandMark(key: ValueKey('brand')),
      ),
    );
  }
}

class _SplashBrandMark extends StatelessWidget {
  const _SplashBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: AppType.wordmark.copyWith(
                fontSize: 34,
                color: AppPalette.textOnDark,
              ),
              children: const [
                TextSpan(text: 'Insta'),
                TextSpan(
                  text: 'Style',
                  style: TextStyle(color: AppPalette.gold),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '15-Minute Fashion Delivery'.toUpperCase(),
            style: AppType.eyebrow.copyWith(color: AppPalette.gold),
          ),
        ],
      ),
    );
  }
}