import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/ds/ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  STYLE CIRCLE — the community feed (Figma node 578:6716).
//
//  Structure follows the design: serif title with a camera action, a strapline
//  strip, a scrolling filter rail, then a two-column staggered grid of posts.
//  Each tile is a photograph with the poster's handle overlaid top-left and the
//  caption plus like count over a bottom scrim.
//
//  Provenance note: this was built from the design's rendered screenshot, not
//  an extracted node tree — the Figma MCP call budget was exhausted before the
//  spec could be pulled. Structure, hierarchy and content are faithful; exact
//  paddings come from the design system rather than measured values. Worth
//  re-checking against the node when budget allows.
//
//  The design's own bottom navigation is intentionally omitted — this is a
//  pushed route, and the app's five-tab bar stays as it is.
// ─────────────────────────────────────────────────────────────────────────────

/// Feed filters from the design's chip rail.
enum StyleCircleFilter { forYou, following, trending, newest, nearby }

extension _FilterLabel on StyleCircleFilter {
  String get label => switch (this) {
        StyleCircleFilter.forYou => 'For You',
        StyleCircleFilter.following => 'Following',
        StyleCircleFilter.trending => 'Trending',
        StyleCircleFilter.newest => 'New',
        StyleCircleFilter.nearby => 'Nearby',
      };
}

/// A community post.
class StyleCirclePost {
  final String id;
  final String handle;
  final String caption;
  final String subtitle;
  final String imageUrl;
  final int likes;
  final bool isLiked;

  /// Relative tile height, so the grid staggers the way the design does
  /// rather than rendering a uniform brick wall.
  final double aspectRatio;

  const StyleCirclePost({
    required this.id,
    required this.handle,
    required this.caption,
    required this.subtitle,
    required this.imageUrl,
    required this.likes,
    this.isLiked = false,
    this.aspectRatio = 3 / 4,
  });

  StyleCirclePost copyWith({int? likes, bool? isLiked}) => StyleCirclePost(
        id: id,
        handle: handle,
        caption: caption,
        subtitle: subtitle,
        imageUrl: imageUrl,
        likes: likes ?? this.likes,
        isLiked: isLiked ?? this.isLiked,
        aspectRatio: aspectRatio,
      );
}

/// Seed content. There is no community API yet; when one exists this list is
/// the single thing that gets replaced.
const _seedPosts = <StyleCirclePost>[
  StyleCirclePost(
    id: 'sc-1',
    handle: '@thaboshostyle',
    caption: 'Thrifted linen shirt',
    subtitle: 'Summer staple',
    imageUrl:
        'https://images.unsplash.com/photo-1485462537746-965f33f7f6a7?w=600&q=85',
    likes: 1500,
    aspectRatio: 3 / 4,
  ),
  StyleCirclePost(
    id: 'sc-2',
    handle: '@mensfits',
    caption: '90s jacket find',
    subtitle: 'Love this vibe',
    imageUrl:
        'https://images.unsplash.com/photo-1520975954732-35dd22299614?w=600&q=85',
    likes: 899,
    aspectRatio: 4 / 5,
  ),
  StyleCirclePost(
    id: 'sc-3',
    handle: '@quietluxe',
    caption: 'Simple fits',
    subtitle: 'Everyday tailoring',
    imageUrl:
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=600&q=85',
    likes: 642,
    aspectRatio: 4 / 5,
  ),
  StyleCirclePost(
    id: 'sc-4',
    handle: '@studiowear',
    caption: 'Bold in yellow',
    subtitle: 'Statement piece',
    imageUrl:
        'https://images.unsplash.com/photo-1487222477894-8943e31ef7b2?w=600&q=85',
    likes: 2100,
    aspectRatio: 3 / 4,
  ),
  StyleCirclePost(
    id: 'sc-5',
    handle: '@archivepieces',
    caption: 'Wool blend layers',
    subtitle: 'Second-hand find',
    imageUrl:
        'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=600&q=85',
    likes: 431,
    aspectRatio: 4 / 5,
  ),
  StyleCirclePost(
    id: 'sc-6',
    handle: '@slowcloset',
    caption: 'Pre-loved denim',
    subtitle: 'Ten years old',
    imageUrl:
        'https://images.unsplash.com/photo-1475178626620-a4d074967452?w=600&q=85',
    likes: 1180,
    aspectRatio: 3 / 4,
  ),
];

class StyleCircleScreen extends StatefulWidget {
  const StyleCircleScreen({super.key});

  static Route<void> route() => PageRouteBuilder(
        pageBuilder: (_, __, ___) => const StyleCircleScreen(),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  @override
  State<StyleCircleScreen> createState() => _StyleCircleScreenState();
}

class _StyleCircleScreenState extends State<StyleCircleScreen> {
  StyleCircleFilter _filter = StyleCircleFilter.forYou;
  late List<StyleCirclePost> _posts;

  @override
  void initState() {
    super.initState();
    _posts = List<StyleCirclePost>.of(_seedPosts);
  }

  /// Optimistic like toggle — the heart responds on tap, no round-trip.
  void _toggleLike(String postId) {
    HapticFeedback.lightImpact();
    setState(() {
      _posts = _posts.map((post) {
        if (post.id != postId) return post;
        final liked = !post.isLiked;
        return post.copyWith(
          isLiked: liked,
          likes: post.likes + (liked ? 1 : -1),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final columns = AppBreakpoints.isTablet(context) ? 3 : 2;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        body: Column(
          children: [
            AppTopBar(
              title: 'Style Circle',
              serif: true,
              actions: [
                AppIconButton(
                  icon: Icons.photo_camera_outlined,
                  tooltip: 'Share a look',
                  onPressed: () => AppSnack.show(
                    context,
                    'Posting to Style Circle is coming soon',
                    icon: Icons.photo_camera_outlined,
                  ),
                ),
              ],
            ),

            // ── Strapline strip ───────────────────────────────────────
            Container(
              width: double.infinity,
              color: AppPalette.surfaceWarm,
              padding: EdgeInsets.symmetric(
                horizontal: inset,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                'Real people. Real styles. Real inspiration.',
                textAlign: TextAlign.center,
                style: AppType.bodySmall.copyWith(
                  color: AppPalette.textSecondary,
                ),
              ),
            ),

            // ── Filter rail ───────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: inset,
                  vertical: AppSpacing.xs,
                ),
                itemCount: StyleCircleFilter.values.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final filter = StyleCircleFilter.values[i];
                  return AppChip(
                    label: filter.label,
                    selected: filter == _filter,
                    onTap: () => setState(() => _filter = filter),
                  );
                },
              ),
            ),

            // ── Feed ──────────────────────────────────────────────────
            Expanded(
              child: _posts.isEmpty
                  ? AppStateView.empty(
                      icon: Icons.people_outline,
                      title: 'Nothing here yet',
                      message: 'Follow a few people and their looks will '
                          'show up here.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        // No feed API yet; the gesture is wired so the screen
                        // behaves correctly once one exists.
                        await Future<void>.delayed(AppMotion.slow);
                      },
                      color: AppPalette.accent,
                      backgroundColor: AppPalette.surface,
                      child: _StaggeredFeed(
                        posts: _posts,
                        columns: columns,
                        inset: inset,
                        onLike: _toggleLike,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple column-balanced staggered grid.
///
/// Flutter has no built-in staggered grid, and pulling a package in for one
/// screen isn't worth it. Posts are dealt into the shortest column by running
/// height, which produces the uneven, magazine-like rhythm the design shows
/// without any layout passes.
class _StaggeredFeed extends StatelessWidget {
  final List<StyleCirclePost> posts;
  final int columns;
  final double inset;
  final ValueChanged<String> onLike;

  const _StaggeredFeed({
    required this.posts,
    required this.columns,
    required this.inset,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final buckets = List.generate(columns, (_) => <StyleCirclePost>[]);
    final heights = List<double>.filled(columns, 0);

    for (final post in posts) {
      var shortest = 0;
      for (var c = 1; c < columns; c++) {
        if (heights[c] < heights[shortest]) shortest = c;
      }
      buckets[shortest].add(post);
      // Relative height only — the actual pixel width cancels out when
      // comparing columns.
      heights[shortest] += 1 / post.aspectRatio;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        inset,
        AppSpacing.xs,
        inset,
        AppSpacing.safeBottom(context, extra: AppSpacing.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++) ...[
            Expanded(
              child: Column(
                children: [
                  for (final post in buckets[c])
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _PostTile(
                        post: post,
                        onLike: () => onLike(post.id),
                      ),
                    ),
                ],
              ),
            ),
            if (c < columns - 1) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final StyleCirclePost post;
  final VoidCallback onLike;

  const _PostTile({required this.post, required this.onLike});

  /// 1500 → "1.5K". Keeps the like count to a fixed width on the tile.
  String get _likeLabel {
    if (post.likes < 1000) return '${post.likes}';
    final thousands = post.likes / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.image,
      child: AspectRatio(
        aspectRatio: post.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(url: post.imageUrl, cacheWidth: 500),

            // Bottom scrim keeps the caption legible over any photograph.
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppPalette.photoScrim),
            ),

            // Handle
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppPalette.surfaceA92,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 11,
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(
                      post.handle,
                      style: AppType.badge.copyWith(
                        color: AppPalette.textOnDark,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Caption + like
            Positioned(
              left: AppSpacing.xs,
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    post.caption,
                    style: AppType.titleSmall.copyWith(
                      color: AppPalette.textOnDark,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    post.subtitle,
                    style: AppType.bodySmall.copyWith(
                      color: AppPalette.textOnDark.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  GestureDetector(
                    onTap: onLike,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: AppMotion.fast,
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            post.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            key: ValueKey(post.isLiked),
                            size: 13,
                            color: post.isLiked
                                ? AppPalette.danger
                                : AppPalette.textOnDark,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          _likeLabel,
                          style: AppType.badge.copyWith(
                            color: AppPalette.textOnDark,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
