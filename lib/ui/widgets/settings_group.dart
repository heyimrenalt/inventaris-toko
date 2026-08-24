import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// WhatsApp-style settings section: a small green [title] above a white
/// rounded card containing [children], with a thin hairline divider
/// (indented past the leading-icon column) between rows and none after the
/// last row.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
            ),
          ),
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 48),
                      child: Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row inside a [SettingsGroup]: a leading icon, a title (with an
/// optional wrapping [description]/[subtitle]), and an optional trailing
/// widget (chevron, value, etc.), tappable via [onTap].
///
/// Set [topAlign] for rows whose description is long enough to wrap to
/// multiple lines — the icon and trailing widget then align to the top of
/// the row instead of drifting to its vertical center.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    this.description,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.topAlign = false,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;

  /// Long, wrapping explanatory text under the title (e.g. the Prioritas
  /// Kulakan rows).
  final String? description;

  /// Short single-line text under the title (e.g. last-backup timestamp).
  final String? subtitle;

  final Widget? trailing;
  final VoidCallback? onTap;
  final bool topAlign;

  @override
  Widget build(BuildContext context) {
    final crossAxis = topAlign ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        child: Row(
          crossAxisAlignment: crossAxis,
          children: [
            if (icon != null)
              SizedBox(
                width: 32,
                child: Icon(icon, size: 20, color: iconColor ?? AppColors.gray700),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, color: titleColor)),
                  if (description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(description!, style: const TextStyle(fontSize: 13, color: AppColors.gray700)),
                    ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.gray700)),
                    ),
                ],
              ),
            ),
            if (trailing != null) Padding(padding: const EdgeInsets.only(left: AppSpacing.sm), child: trailing!),
          ],
        ),
      ),
    );
  }
}
