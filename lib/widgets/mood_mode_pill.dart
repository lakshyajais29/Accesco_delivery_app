import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// MOOD MODE PILL — persistent floating pill above the bottom nav.
/// Tapping opens a full-screen bottom sheet with 6 mood tiles.
class MoodModePill extends StatelessWidget {
  const MoodModePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _openMoodSheet(context),
        child: Container(
          // ── Reduced from horizontal: 28, vertical: 14 ──
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: const Color.fromARGB(193, 131, 98, 74),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(183, 142, 104, 76).withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon: 16 → 13 ──
              Icon(Icons.auto_awesome, color: AppColors.ivoryWhite, size: 16),
              SizedBox(width: 8),
              // ── Text: 13 → 10.5, letterSpacing 1.8 → 1.4 ──
              Text(
                'SET YOUR MOOD',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  color: AppColors.ivoryWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMoodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _MoodSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOOD SHEET
// ─────────────────────────────────────────────────────────────
class _MoodSheet extends StatelessWidget {
  const _MoodSheet();

  static const _moods = <_MoodOption>[
    _MoodOption(
      label: 'FESTIVE',
      description: 'Warm amber. For when you want to be seen.',
      icon: Icons.celebration_outlined,
      tint: AppColors.amberAlert,
    ),
    _MoodOption(
      label: 'BOLD',
      description: 'Saturated reds. Statements only.',
      icon: Icons.bolt_rounded,
      tint: AppColors.fomoRed,
    ),
    _MoodOption(
      label: 'MINIMAL',
      description: 'Neutrals. Clean lines. Quiet luxury.',
      icon: Icons.remove,
      tint: AppColors.brandTan,
    ),
    _MoodOption(
      label: 'ROMANTIC',
      description: 'Soft tones. Flowing silhouettes.',
      icon: Icons.favorite_border_rounded,
      tint: Color(0xFFE8B4B8),
    ),
    _MoodOption(
      label: 'PRO',
      description: 'Cool blue-grey. Boardroom-ready.',
      icon: Icons.work_outline_rounded,
      tint: Color(0xFF6B7B8C),
    ),
    _MoodOption(
      label: 'CASUAL',
      description: 'Easy fits. Lived-in pieces.',
      icon: Icons.weekend_outlined,
      tint: Color(0xFF8B9A7E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      height: size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mutedText.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title block
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How do you\nfeel today?',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w700,
                    fontSize: 38,
                    height: 1.05,
                    color: AppColors.ivoryWhite,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Selecting a mood re-curates your entire feed.',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: AppColors.mutedText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Mood grid — Expanded + scrollable so it can never overflow
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.92,
                ),
                itemCount: _moods.length,
                itemBuilder: (context, i) => _MoodTile(option: _moods[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOOD TILE
// ─────────────────────────────────────────────────────────────
class _MoodTile extends StatelessWidget {
  final _MoodOption option;
  const _MoodTile({required this.option});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, option.label),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.separator,
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: option.tint.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option.icon,
                  color: option.tint,
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.6,
                  color: AppColors.ivoryWhite,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w400,
                  fontSize: 11.5,
                  color: AppColors.mutedText,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodOption {
  final String label;
  final String description;
  final IconData icon;
  final Color tint;
  const _MoodOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.tint,
  });
}