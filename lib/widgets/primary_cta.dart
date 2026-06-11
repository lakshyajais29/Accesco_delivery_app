import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Primary CTA (Chapter 02 + 04)
/// - Sharp corners (0px) — signals authority
/// - Micro-emboss: box-shadow inset 0 1px 0 rgba(196,168,130,0.3),
///   inset 0 -1px 0 rgba(0,0,0,0.4) → "Buttons feel physically pressable.
///   Haptic trust before the tap."
/// - CTA Gradient on idle, Deep Brown on pressed.
class PrimaryCTA extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool fullWidth;
  final Widget? trailingIcon;

  const PrimaryCTA({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.trailingIcon,
  });

  @override
  State<PrimaryCTA> createState() => _PrimaryCTAState();
}

class _PrimaryCTAState extends State<PrimaryCTA> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        decoration: BoxDecoration(
          gradient: _pressed
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandDeepBrown, AppColors.brandWarmBrown],
                )
              : AppColors.ctaGradient,
          // Sharp CTAs signal authority — 0px radius per spec.
          borderRadius: BorderRadius.zero,
          boxShadow: const [
            // Micro-emboss top highlight
            BoxShadow(
              color: Color.fromRGBO(196, 168, 130, 0.3),
              offset: Offset(0, 1),
              spreadRadius: -1,
              blurRadius: 0,
            ),
            // Micro-emboss bottom shadow
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.4),
              offset: Offset(0, -1),
              spreadRadius: -1,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: widget.fullWidth
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: AppText.featureLabel(size: 12),
            ),
            if (widget.trailingIcon != null) ...[
              const SizedBox(width: 10),
              widget.trailingIcon!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Ghost / secondary CTA — text-only with arrow. "Sends outfit to friends for
/// group vote." (per Hero Outfit Card spec).
class GhostCTA extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const GhostCTA({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: AppText.featureLabel(
                size: 11,
                color: AppColors.brandTan,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward,
              size: 14,
              color: AppColors.brandTan,
            ),
          ],
        ),
      ),
    );
  }
}