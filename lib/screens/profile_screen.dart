import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/ds/ds.dart';
import 'style_profile_screen.dart';
import 'thrift/thrift_home_screen.dart';
import 'trial_at_doorstep_screen.dart';
import 'wishlist_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE / "MORE" — a translation of Figma node 490:835.
//
//  Account hub: identity header, a primary action group, a secondary group,
//  and sign-out. Distinct from [StyleProfileScreen], which is the *style* /
//  fit profile — the design links to it via "View Profile" under the name.
//
//  The design's own bottom navigation (Home · Browse · Sell · Orders ·
//  Profile) is deliberately NOT reproduced here. This app keeps its own
//  five-tab nav, and this screen is a pushed route rather than a tab, so
//  rendering a second, conflicting nav bar would be wrong.
// ─────────────────────────────────────────────────────────────────────────────

/// Figma measurements for this screen.
class _Spec {
  const _Spec._();

  static const double cardRadius = 5;
  static const double rowHeight = 43.5;
  static const double iconSize = 15;
  static const double avatarSize = 42;
  static const double creditPillRadius = 20;
}

/// Figma palette for this screen.
class _Ink {
  const _Ink._();

  /// Grouped-card fill. Figma `#fcf9f7`.
  static const Color cardFill = Color(0xFFFCF9F7);

  /// Card hairline and muted labels. Figma `#726767`.
  static const Color cardBorder = Color(0xFF726767);

  /// Brand brown for active marks and the credits figure. Figma `#5c3a21`.
  static const Color brand = AppPalette.accentDeep;

  /// Sign-out text. Figma `#e6645b`.
  static const Color signOut = Color(0xFFE6645B);
}

/// A single navigable row inside a grouped card.
class _MenuEntry {
  final String assetIcon;
  final String label;
  final String? trailingValue;
  final VoidCallback onTap;

  const _MenuEntry({
    required this.assetIcon,
    required this.label,
    required this.onTap,
    this.trailingValue,
  });
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Fade route, matching the transition used elsewhere in the app.
  static Route<void> route() => PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ProfileScreen(),
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      );

  void _push(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: AppMotion.normal,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      ),
    );
  }

  /// Rows whose destination screen doesn't exist yet get a consistent,
  /// honest response rather than a dead tap.
  void _notYetBuilt(BuildContext context, String label) {
    AppSnack.show(context, '$label is coming soon', icon: Icons.schedule);
  }

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);

    final primary = <_MenuEntry>[
      _MenuEntry(
        assetIcon: 'assets/icons/package.svg',
        label: 'My Orders',
        onTap: () => _notYetBuilt(context, 'My Orders'),
      ),
      _MenuEntry(
        assetIcon: 'assets/icons/tags.svg',
        label: 'My Listings',
        onTap: () => _push(
          context,
          const ThriftHomeScreen(initialTab: ThriftHomeTab.listings),
        ),
      ),
      _MenuEntry(
        assetIcon: 'assets/icons/shield.svg',
        label: 'Try & Return',
        onTap: () => _push(
          context,
          TrialAtDoorstepScreen(orderId: 'ORDER123', riderId: 'RIDER456'),
        ),
      ),
      _MenuEntry(
        assetIcon: 'assets/icons/recycle.svg',
        label: 'Circular Credits',
        trailingValue: '120',
        onTap: () => _notYetBuilt(context, 'Circular Credits'),
      ),
    ];

    final secondary = <_MenuEntry>[
      _MenuEntry(
        assetIcon: 'assets/icons/bookmark.svg',
        label: 'Saved Items',
        onTap: () => _push(context, const WishlistScreen()),
      ),
      _MenuEntry(
        assetIcon: 'assets/icons/help_circle.svg',
        label: 'Help & Support',
        onTap: () => _notYetBuilt(context, 'Help & Support'),
      ),
      _MenuEntry(
        assetIcon: 'assets/icons/settings.svg',
        label: 'Settings',
        onTap: () => _notYetBuilt(context, 'Settings'),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              inset,
              0,
              inset,
              AppSpacing.safeBottom(context, extra: AppSpacing.xl),
            ),
            children: [
              _buildHeader(context),
              const SizedBox(height: AppSpacing.xxl),
              _buildIdentity(context),
              const SizedBox(height: AppSpacing.xxl),
              _MenuCard(entries: primary),
              const SizedBox(height: AppSpacing.lg),
              _MenuCard(entries: secondary),
              const SizedBox(height: AppSpacing.xxl),
              _buildSignOut(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Back arrow + centred serif title (nodes 490:866, 490:898).
  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppIconButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Text(
            'More',
            style: AppType.displaySmall.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar, name, "View Profile" (nodes 490:863, 490:867, 490:897).
  Widget _buildIdentity(BuildContext context) {
    return GestureDetector(
      onTap: () => _push(context, const StyleProfileScreen()),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: _Spec.avatarSize,
            height: _Spec.avatarSize,
            decoration: const BoxDecoration(
              color: AppPalette.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 22,
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Priya Sharma',
                  style: AppType.titleLarge.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'View Profile',
                  style: AppType.bodySmall.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: _Ink.cardBorder,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppPalette.textTertiary,
          ),
        ],
      ),
    );
  }

  /// Sign-out card (nodes 490:862, 490:864).
  Widget _buildSignOut(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final confirmed = await showAppDialog(
          context,
          icon: Icons.logout,
          title: 'Sign out?',
          message: 'You\'ll need to verify your number again to sign back in.',
          confirmLabel: 'Log Out',
          destructive: true,
        );
        if (confirmed != true || !context.mounted) return;
        _notYetBuilt(context, 'Sign out');
      },
      child: Container(
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _Ink.cardFill,
          borderRadius: BorderRadius.circular(_Spec.cardRadius),
          border: Border.all(color: _Ink.cardBorder, width: 0.5),
        ),
        child: Text(
          'Log Out',
          style: AppType.titleLarge.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
            color: _Ink.signOut,
          ),
        ),
      ),
    );
  }
}

/// A grouped card of menu rows, hairline-separated (nodes 490:868, 490:875).
class _MenuCard extends StatelessWidget {
  final List<_MenuEntry> entries;

  const _MenuCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Ink.cardFill,
        borderRadius: BorderRadius.circular(_Spec.cardRadius),
        border: Border.all(color: _Ink.cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _MenuRow(entry: entries[i]),
            if (i < entries.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: AppDivider(color: _Ink.cardBorder),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuEntry entry;

  const _MenuRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: entry.label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          entry.onTap();
        },
        child: SizedBox(
          height: _Spec.rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                SvgPicture.asset(
                  entry.assetIcon,
                  width: _Spec.iconSize,
                  height: _Spec.iconSize,
                  colorFilter: const ColorFilter.mode(
                    AppPalette.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    entry.label,
                    style: AppType.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.trailingValue != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.textOnInk,
                      borderRadius:
                          BorderRadius.circular(_Spec.creditPillRadius),
                    ),
                    child: Text(
                      entry.trailingValue!,
                      style: AppType.label.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                        color: _Ink.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                const Icon(
                  Icons.chevron_right,
                  size: 15,
                  color: AppPalette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
