import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import 'app_shimmer.dart';

/// The one way the app draws remote imagery.
///
/// Bundles the three things every product photo needs and that were previously
/// re-implemented per screen: disk caching, a shimmering placeholder, and a
/// graceful error tile. It also passes decode-size hints so a 1200px source
/// image isn't decoded at full resolution into a 160pt card — the single
/// biggest memory win in an image-dense catalogue.
class AppImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Multiplied by device pixel ratio to size the decode. Leave null to decode
  /// at natural size (only right for full-bleed hero imagery).
  final int? cacheWidth;

  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memWidth = cacheWidth != null
        ? (cacheWidth! * dpr).round()
        : (width != null && width!.isFinite ? (width! * dpr).round() : null);

    Widget image = url.isEmpty
        ? const _ImageFallback()
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: memWidth,
            fadeInDuration: AppMotion.fast,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => const AppShimmer(
              borderRadius: BorderRadius.zero,
            ),
            errorWidget: (_, __, ___) => const _ImageFallback(),
          );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

/// Shown when a URL is empty or fails to load. Reads as an intentional part of
/// the design rather than a broken image.
class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppPalette.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.checkroom_outlined,
          color: AppPalette.textTertiary,
          size: 28,
        ),
      ),
    );
  }
}
