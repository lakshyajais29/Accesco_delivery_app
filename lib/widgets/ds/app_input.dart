import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';

/// A labelled text field. The label sits above the box rather than floating
/// inside it — steadier for forms with many fields, and it leaves room for the
/// helper/error line without the field jumping.
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!.toUpperCase(), style: AppType.eyebrow),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          obscureText: obscureText,
          enabled: enabled,
          autofocus: autofocus,
          maxLines: maxLines,
          maxLength: maxLength,
          cursorColor: AppPalette.accent,
          style: AppType.bodyLarge.copyWith(color: AppPalette.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helper,
            counterText: '',
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 19, color: AppPalette.textTertiary),
            suffixIcon: suffix,
            fillColor:
                enabled ? AppPalette.surface : AppPalette.surfaceSunken,
          ),
        ),
      ],
    );
  }
}

/// The search affordance. Tapping it can either focus in place (pass
/// [onChanged]) or navigate to a dedicated search screen (pass [onTap] and
/// leave [readOnly] true, which is how the home screen uses it).
class AppSearchBar extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final VoidCallback? onClear;
  final List<Widget> trailing;

  const AppSearchBar({
    super.key,
    this.hint = 'Search for pieces, brands, looks…',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.onClear,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadii.chip,
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          const Icon(Icons.search, size: 19, color: AppPalette.textTertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTap: onTap,
              readOnly: readOnly,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              cursorColor: AppPalette.accent,
              style: AppType.bodyMedium.copyWith(
                color: AppPalette.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: AppType.bodyMedium.copyWith(
                  color: AppPalette.textTertiary,
                ),
              ),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Icon(
                  Icons.close,
                  size: 17,
                  color: AppPalette.textTertiary,
                ),
              ),
            ),
          ...trailing,
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// A labelled row that opens a picker — used in profile setup and checkout
/// where a field is a selection rather than free text.
class AppSelectField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final IconData? icon;

  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Select',
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: AppRadii.field,
              border: Border.all(color: AppPalette.line),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppPalette.textTertiary),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    hasValue ? value! : placeholder,
                    style: AppType.bodyMedium.copyWith(
                      color: hasValue
                          ? AppPalette.textPrimary
                          : AppPalette.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.expand_more,
                  size: 19,
                  color: AppPalette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
