import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// One app-wide clock driving every shimmer on screen.
///
/// A loading grid of 20 skeleton cards would otherwise mean 20 independent
/// `AnimationController`s ticking every frame. Instead all [AppShimmer]s read
/// this single ref-counted [Ticker]: the cost is constant regardless of how
/// many skeletons are mounted, they stay perfectly in phase with each other,
/// and the ticker stops the moment the last shimmer leaves the tree.
class _ShimmerClock {
  _ShimmerClock._();

  static const int _periodMs = 1400;

  /// Normalised 0→1 sweep position. Shimmers rebuild off this.
  static final ValueNotifier<double> progress = ValueNotifier<double>(0);

  static Ticker? _ticker;
  static int _subscribers = 0;

  static void subscribe() {
    _subscribers++;
    _ticker ??= Ticker(_onTick)..start();
  }

  static void unsubscribe() {
    _subscribers--;
    if (_subscribers > 0) return;
    _subscribers = 0;
    _ticker?.dispose();
    _ticker = null;
  }

  static void _onTick(Duration elapsed) {
    progress.value = (elapsed.inMilliseconds % _periodMs) / _periodMs;
  }
}

/// Sweeping gradient placeholder shown while content loads.
///
/// Wrap a fixed-size box — `AppShimmer(width: 120, height: 16)` — or pass a
/// [child] to shimmer an arbitrary silhouette.
class AppShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Widget? child;

  const AppShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppRadii.badge,
    this.child,
  });

  /// A shimmering circle — avatars, icon wells.
  const AppShimmer.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(AppRadii.pill)),
        child = null;

  /// A shimmering line standing in for a run of text.
  const AppShimmer.text({super.key, this.width, this.height = 12})
      : borderRadius = const BorderRadius.all(Radius.circular(4)),
        child = null;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> {
  @override
  void initState() {
    super.initState();
    _ShimmerClock.subscribe();
  }

  @override
  void dispose() {
    _ShimmerClock.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary keeps the per-frame sweep from dirtying ancestors.
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _ShimmerClock.progress,
        child: widget.child ??
            SizedBox(width: widget.width, height: widget.height),
        builder: (_, t, child) {
          final x = t * 2.4 - 0.7;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              gradient: LinearGradient(
                begin: Alignment(x - 0.6, -0.2),
                end: Alignment(x + 0.6, 0.2),
                colors: AppPalette.shimmerSweep.colors,
                stops: AppPalette.shimmerSweep.stops,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }
}
