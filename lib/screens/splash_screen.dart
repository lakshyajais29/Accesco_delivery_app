import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../widgets/ds/ds.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  /// Guards against handing control onward twice — the video-ended listener
  /// and the failsafe timer can otherwise both fire.
  bool _handedOff = false;

  Timer? _failsafe;

  /// Hard ceiling on how long the splash may hold the app.
  ///
  /// The video is the happy path, but a missing asset, a decoder failure or a
  /// stream that never reports completion would otherwise strand the user on
  /// the splash forever. Anything past this and we move on regardless.
  static const _maxSplashDuration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();

    // Hide status bar for full immersive splash.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _failsafe = Timer(_maxSplashDuration, _navigateNext);

    _controller = VideoPlayerController.asset('assets/videos/splash_video.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.setLooping(false);
        _controller.setVolume(1.0);
        _controller.play();
      }).catchError((Object error) {
        // Asset missing or undecodable — skip straight through rather than
        // holding on a branded still until the failsafe fires.
        debugPrint('Splash video failed to initialise: $error');
        _navigateNext();
      });

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

  /// Hands control to the entry flow.
  ///
  /// The splash no longer chooses a destination itself — where a user lands
  /// depends on whether they've completed style setup, and that decision lives
  /// in one place (`main.dart`). [onComplete] is therefore required; a splash
  /// with nowhere to go is a bug, not a state to paper over with a default.
  void _navigateNext() {
    if (_handedOff) return;
    _handedOff = true;
    _failsafe?.cancel();

    // Restore system UI before navigating.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onComplete();
  }

  @override
  void dispose() {
    _failsafe?.cancel();
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