import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Glassmorphism Card (Chapter 02)
/// backdrop-filter: blur(24px) · background: rgba(20,18,16,0.7) ·
/// border: 1px rgba(196,168,130,0.15)
/// "Depth. Translucency. The outfit feels like it exists behind frosted glass."
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(20, 18, 16, 0.7),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AppColors.separator,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}