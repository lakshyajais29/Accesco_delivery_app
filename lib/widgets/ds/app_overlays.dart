import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';

/// The drag handle every bottom sheet opens with.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppPalette.lineStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Standard chrome for a modal sheet: handle, title row with a close button,
/// hairline, then the caller's content. Pass this as the sheet body so every
/// sheet in the app opens the same way.
class AppSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  /// Pinned to the bottom above the safe area — usually a confirm button.
  final Widget? footer;

  /// Let the sheet grow to the height of its content rather than filling the
  /// available space. True for short confirmations, false for long lists.
  final bool shrinkWrap;

  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.shrinkWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const Center(child: AppSheetHandle()),
          Padding(
            padding: EdgeInsets.fromLTRB(inset, AppSpacing.xxs, inset,
                AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppType.displaySmall.responsive(context),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppType.bodySmall),
                      ],
                    ],
                  ),
                ),
                AppIconButton(
                  icon: Icons.close,
                  size: 20,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const AppDivider(),
          if (shrinkWrap)
            Flexible(child: child)
          else
            Expanded(child: child),
          if (footer != null) ...[
            const AppDivider(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                inset,
                AppSpacing.sm,
                inset,
                AppSpacing.sm,
              ),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Presents [child] as a modal sheet with the app's scrim, radius and motion.
///
/// Always prefer this over calling `showModalBottomSheet` directly so sheets
/// can't drift apart visually. Returns the value the sheet was popped with.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,

  /// Allow the sheet to be dragged up to full height. Use for long lists.
  bool expand = false,

  /// Initial height as a fraction of the screen when [expand] is true.
  double initialSize = 0.6,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: AppPalette.surface,
    barrierColor: AppPalette.scrim,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.bottomSheet),
    clipBehavior: Clip.antiAlias,
    builder: (_) => expand
        ? DraggableScrollableSheet(
            initialChildSize: initialSize,
            minChildSize: 0.3,
            maxChildSize: 0.94,
            expand: false,
            builder: (_, controller) => PrimaryScrollController(
              controller: controller,
              child: child,
            ),
          )
        : Padding(
            // Lifts the sheet clear of the keyboard when it contains inputs.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: child,
          ),
  );
}

/// A confirmation dialog in the app's voice.
///
/// Returns true when the user confirms, false or null otherwise.
Future<bool?> showAppDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',

  /// Styles the confirm button as destructive.
  bool destructive = false,
  IconData? icon,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: AppPalette.scrim,
    builder: (context) => Dialog(
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.dialog),
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: destructive
                        ? AppPalette.dangerSoft
                        : AppPalette.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color:
                        destructive ? AppPalette.danger : AppPalette.accent,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.displaySmall.responsive(context),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppType.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: confirmLabel,
              variant: destructive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary,
              size: AppButtonSize.medium,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton.secondary(
              label: cancelLabel,
              size: AppButtonSize.medium,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Toast messaging. Replaces the hand-styled `SnackBar` blocks that were
/// repeated across screens, each with slightly different padding and colour.
class AppSnack {
  AppSnack._();

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Color? accent,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: accent ?? AppPalette.gold),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  message,
                  style: AppType.bodyMedium.copyWith(
                    color: AppPalette.textOnDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppPalette.ink,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.field),
          action: actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel.toUpperCase(),
                  textColor: AppPalette.gold,
                  onPressed: onAction,
                )
              : null,
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message,
          icon: Icons.check_circle_outline, accent: AppPalette.success);

  static void error(BuildContext context, String message) => show(
        context,
        message,
        icon: Icons.error_outline,
        accent: AppPalette.danger,
      );
}
