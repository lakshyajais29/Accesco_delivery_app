import 'dart:math';
import 'package:flutter/material.dart';

/// Film Grain Overlay (Chapter 02)
/// Animated grain texture at 4–8% opacity on all dark backgrounds. Moves at 24fps.
/// "Feels like cinema. Makes the screen feel physical, like fabric."
class FilmGrainOverlay extends StatefulWidget {
  final Widget child;
  final double opacity;

  const FilmGrainOverlay({
    super.key,
    required this.child,
    this.opacity = 0.06, // mid-range of 4–8%
  });

  @override
  State<FilmGrainOverlay> createState() => _FilmGrainOverlayState();
}

class _FilmGrainOverlayState extends State<FilmGrainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 24fps cadence — frame advance every ~41ms
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // Quantize to 24fps so the grain has authentic film flicker.
                final frame = (_controller.value * 120).floor();
                return CustomPaint(
                  painter: _GrainPainter(
                    seed: frame,
                    opacity: widget.opacity,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  final int seed;
  final double opacity;

  _GrainPainter({required this.seed, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final paint = Paint()..style = PaintingStyle.fill;
    // density tuned to feel like 35mm grain without tanking perf
    final pointCount = (size.width * size.height / 60).toInt();

    for (int i = 0; i < pointCount; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final intensity = random.nextDouble();
      // mix of light & dark specks for realism
      paint.color = (intensity > 0.5 ? Colors.white : Colors.black)
          .withOpacity(opacity * intensity);
      canvas.drawCircle(Offset(dx, dy), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => oldDelegate.seed != seed;
}