import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// TOP NAV BAR — Always visible, sticky over hero.
/// Transparent while hovering over the hero image.
/// Once user scrolls past the hero, a subtle backdrop blur +
/// solid dark base appears so rail content NEVER bleeds through.
class TopNavBar extends StatelessWidget {
  final int etaMinutes;
  final int vibeCheckCount;
  final double scrollOffset;
  final double topNavHeight;

  const TopNavBar({
    super.key,
    required this.etaMinutes,
    required this.vibeCheckCount,
    this.scrollOffset = 0,
    this.topNavHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    // Fade the background in over the first 120px of scroll.
    final double bgOpacity = (scrollOffset / 120).clamp(0.0, 1.0);
    final double blurSigma = 18.0 * bgOpacity;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundBase.withOpacity(0.85 * bgOpacity),
            border: bgOpacity > 0.5
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.separator,
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          child: Row(
            children: [
              // ── LEFT: App icon + INSTASTYLE wordmark ─────
              const _AppIconLogo(),

              const Spacer(),

              // ── CENTRE: Live delivery ETA pill ──────────
              _EtaPill(etaMinutes: etaMinutes),

              const Spacer(),

              // ── RIGHT: Profile avatar w/ vibe check badge
              _ProfileAvatar(badgeCount: vibeCheckCount),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// APP ICON + WORDMARK
// ─────────────────────────────────────────────────────────────
class _AppIconLogo extends StatelessWidget {
  const _AppIconLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App icon — uses asset from assets/images/app_icon.png
        SizedBox(
          width: 28,
          height: 28,
          child: Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.diamond_outlined,
              color: AppColors.ivoryWhite,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'INSTASTYLE',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.8,
            color: AppColors.ivoryWhite,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ETA PILL — warm brown bg, pulsing green dot
// ─────────────────────────────────────────────────────────────
class _EtaPill extends StatefulWidget {
  final int etaMinutes;
  const _EtaPill({required this.etaMinutes});

  @override
  State<_EtaPill> createState() => _EtaPillState();
}

class _EtaPillState extends State<_EtaPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandWarmBrown.withOpacity(0.85),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing green dot
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80)
                          .withOpacity(0.4 + 0.4 * _controller.value),
                      blurRadius: 6 + 4 * _controller.value,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.etaMinutes} MIN TO YOU',
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontWeight: FontWeight.w500,
              fontSize: 11,
              letterSpacing: 1.0,
              color: AppColors.ivoryWhite,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROFILE AVATAR — warm brown ring, badge for vibe checks
// ─────────────────────────────────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  final int badgeCount;
  const _ProfileAvatar({required this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.brandWarmBrown.withOpacity(0.7),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandWarmBrown.withOpacity(0.3),
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.ivoryWhite,
                size: 20,
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: AppColors.fomoRed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.backgroundBase,
                  width: 1.5,
                ),
              ),
              child: Text(
                '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  color: AppColors.ivoryWhite,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}