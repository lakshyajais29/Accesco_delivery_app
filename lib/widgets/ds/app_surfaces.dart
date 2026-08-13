import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import 'app_image.dart';

/// The base card surface — white, softly rounded, hairline-bordered.
/// Prefer this over hand-rolled `Container(decoration: BoxDecoration(...))`.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius borderRadius;
  final bool bordered;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.borderRadius = AppRadii.card,
    this.bordered = true,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppPalette.surface,
        borderRadius: borderRadius,
        border: bordered ? Border.all(color: AppPalette.line) : null,
        boxShadow: elevated ? AppShadows.card : null,
      ),
      child: child,
    );

    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: surface,
      ),
    );
  }
}

/// The editorial hero banner: a tracked-out kicker, a serif headline, a line of
/// supporting copy and a quiet call to action, set against a warm wash with
/// photography bleeding off the trailing edge.
///
/// This is the signature component of the design language — the first thing on
/// the home screen and reused for campaign and category headers.
///
/// Sizing contract: the banner has a *minimum* height, never a fixed one. The
/// copy column measures itself and the box grows to fit, so a two-line serif
/// headline can never be clipped and the CTA can never be pushed out. An
/// earlier revision locked the height and let the text flex, which traded a
/// visible overflow stripe for silent mid-glyph clipping — a worse failure,
/// because nothing warns you it happened.
class AppEditorialBanner extends StatelessWidget {
  final String eyebrow;
  final String headline;
  final String? body;
  final String? ctaLabel;
  final VoidCallback? onTap;
  final String? imageUrl;

  /// Floor for the banner's height. Content taller than this wins.
  final double minHeight;

  const AppEditorialBanner({
    super.key,
    required this.eyebrow,
    required this.headline,
    this.body,
    this.ctaLabel,
    this.onTap,
    this.imageUrl,
    this.minHeight = 190,
  });

  /// Proportion of the banner given to copy; the rest carries the photograph.
  static const int _copyFlex = 6;
  static const int _imageFlex = 4;

  /// Screen width below which the headline starts stepping down, and the
  /// width at which it reaches full size.
  static const double _narrowScreen = 320;
  static const double _comfortableScreen = 390;

  /// The headline never shrinks below this — past it the editorial voice is
  /// lost and wrapping is the better trade.
  static const double _minHeadlineSize = 24;

  /// Display size for the current screen.
  ///
  /// Derived from [MediaQuery] rather than a [LayoutBuilder]: this subtree
  /// sits under an [IntrinsicHeight], which has to query its children's
  /// intrinsic dimensions, and a LayoutBuilder cannot answer that — the
  /// combination throws during layout.
  double _headlineSize(BuildContext context, double fullSize) {
    final width = MediaQuery.sizeOf(context).width;
    final t = ((width - _narrowScreen) /
            (_comfortableScreen - _narrowScreen))
        .clamp(0.0, 1.0);
    return _minHeadlineSize + (fullSize - _minHeadlineSize) * t;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTablet(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // A floor, not a fixed height — see the sizing contract above.
        constraints: BoxConstraints(
          minHeight: isWide ? minHeight + 40 : minHeight,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: AppPalette.bannerWash,
          borderRadius: AppRadii.card,
        ),
        // IntrinsicHeight lets the copy column drive the height while the
        // photograph stretches to match it, so the two panels stay flush
        // whatever the copy length. Cheap here: one row, two children.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: _copyFlex, child: _buildCopy(context)),
              Expanded(
                flex: _imageFlex,
                child: imageUrl == null || imageUrl!.isEmpty
                    ? const ColoredBox(color: AppPalette.surfaceMuted)
                    // BoxFit.cover fills the panel without distorting the
                    // photograph — it crops rather than stretches.
                    : AppImage(url: imageUrl!, cacheWidth: 400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopy(BuildContext context) {
    final base = AppType.displayLarge.responsive(context);
    final fullSize = base.fontSize ?? 34;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AppType.eyebrow.copyWith(color: AppPalette.accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Deliberately not wrapped in Flexible: the headline is the one
          // element that must always render in full. The box grows for it.
          Text(
            headline,
            style: base.copyWith(
              fontSize: _headlineSize(context, fullSize),
            ),
          ),

          if (body != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              body!,
              style: AppType.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (ctaLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ctaLabel!.toUpperCase(),
                  style: AppType.eyebrow.copyWith(
                    color: AppPalette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs + 2),
                const Icon(
                  Icons.arrow_forward,
                  size: 12,
                  color: AppPalette.textPrimary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A section title with an optional trailing action — "JUST DROPPED · SEE ALL".
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Use the serif voice instead of tracked caps. For feature sections that
  /// want more editorial weight.
  final bool serif;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.serif = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page(context),
        AppSpacing.xl,
        AppSpacing.page(context),
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  serif ? title : title.toUpperCase(),
                  style: serif
                      ? AppType.displayMedium.responsive(context)
                      : AppType.overline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: AppType.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Text(
                  actionLabel!.toUpperCase(),
                  style: AppType.eyebrow.copyWith(
                    color: AppPalette.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The split refine / sort control from the reference screens: a filter action
/// on the left, the active sort on the right, divided by a hairline.
class AppRefineBar extends StatelessWidget {
  final String refineLabel;
  final String sortLabel;
  final VoidCallback onRefine;
  final VoidCallback onSort;

  /// Number of active filters, shown as a count beside the refine label.
  final int activeFilterCount;

  const AppRefineBar({
    super.key,
    this.refineLabel = 'Refine',
    required this.sortLabel,
    required this.onRefine,
    required this.onSort,
    this.activeFilterCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadii.field,
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BarAction(
              icon: Icons.tune,
              label: activeFilterCount > 0
                  ? '$refineLabel ($activeFilterCount)'
                  : refineLabel,
              onTap: onRefine,
              emphasised: activeFilterCount > 0,
            ),
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            indent: AppSpacing.sm,
            endIndent: AppSpacing.sm,
            color: AppPalette.line,
          ),
          Expanded(
            child: _BarAction(
              icon: Icons.expand_more,
              label: sortLabel,
              onTap: onSort,
              trailingIcon: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool trailingIcon;
  final bool emphasised;

  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingIcon = false,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        emphasised ? AppPalette.accent : AppPalette.textPrimary;
    final iconWidget = Icon(icon, size: 15, color: color);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.field,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!trailingIcon) ...[
            iconWidget,
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.overline.copyWith(color: color),
            ),
          ),
          if (trailingIcon) ...[
            const SizedBox(width: AppSpacing.xxs),
            iconWidget,
          ],
        ],
      ),
    );
  }
}

/// The "80 Items Found" result counter that sits above a grid.
class AppResultCount extends StatelessWidget {
  final int count;
  final String noun;

  const AppResultCount({super.key, required this.count, this.noun = 'Item'});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count ${count == 1 ? noun : '${noun}s'} Found',
      style: AppType.bodySmall.copyWith(
        color: AppPalette.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
