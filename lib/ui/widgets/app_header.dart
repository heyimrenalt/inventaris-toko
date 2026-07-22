import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;

  const AppHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  factory AppHeader.withBack({
    required String title,
    VoidCallback? onBack,
    Widget? trailing,
  }) {
    return AppHeader(
      title: title,
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.darkText),
          onPressed: onBack ?? () => Navigator.maybePop(context),
        ),
      ),
      trailing: trailing,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      centerTitle: true,
      leading: leading,
      title: Text(
        title,
        style: AppTextStyles.heading.copyWith(color: AppColors.darkText),
      ),
      actions: trailing != null
          ? [trailing!, const SizedBox(width: 4)]
          : null,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
}
