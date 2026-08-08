import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';

/// A blocking overlay shown while a long operation runs.
///
/// Two jobs: tell the user what is happening, and make it impossible to
/// trigger the operation twice. The [AbsorbPointer] is the second half —
/// without it a seller can tap "Publish" repeatedly during an upload and
/// create duplicate listings.
///
/// This is the one place in the app that uses a backdrop blur. Every surface
/// in the design system is flat cream, but a transient overlay is not a
/// surface: blurring the page behind it pushes it back visually and makes the
/// modal state unmistakable. It is deliberately soft — 6px, not a frosted
/// glass panel.
class AppProgressOverlay extends StatelessWidget {
  /// The content this overlay covers.
  final Widget child;

  /// Whether the overlay is showing.
  final bool isVisible;

  /// Headline, e.g. "Uploading photos".
  final String title;

  /// Supporting line, e.g. "2 of 5 · 40%".
  final String? message;

  /// 0.0–1.0 for a determinate bar. Null shows an indeterminate spinner —
  /// use it when the work has no measurable total.
  final double? progress;

  const AppProgressOverlay({
    super.key,
    required this.child,
    required this.isVisible,
    required this.title,
    this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // AnimatedSwitcher rather than a bare `if`: the overlay fades in
        // instead of snapping, which reads as far less jarring mid-tap.
        AnimatedSwitcher(
          duration: AppMotion.normal,
          switchInCurve: AppMotion.enter,
          child: isVisible
              ? _Scrim(
                  key: const ValueKey('progress-overlay'),
                  title: title,
                  message: message,
                  progress: progress,
                )
              : const SizedBox.shrink(key: ValueKey('idle')),
        ),
      ],
    );
  }
}

class _Scrim extends StatelessWidget {
  final String title;
  final String? message;
  final double? progress;

  const _Scrim({
    super.key,
    required this.title,
    this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: ColoredBox(
            color: AppPalette.scrim,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.page(context),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: AppRadii.dialog,
                      boxShadow: AppShadows.raised,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            // A determinate value when we have one, so the
                            // ring tracks the bar rather than spinning
                            // independently of it.
                            value: progress,
                            color: AppPalette.accent,
                            backgroundColor: AppPalette.surfaceMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppType.displaySmall.responsive(context),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: AppType.bodySmall,
                          ),
                        ],
                        if (progress != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: AppPalette.surfaceMuted,
                              color: AppPalette.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
