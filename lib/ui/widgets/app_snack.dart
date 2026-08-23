import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Single entry point for transient feedback SnackBars.
///
/// Every variant inherits the floating pill shape from `snackBarTheme`
/// (see `AppTheme.light`) and only overrides the background colour, so
/// the colour alone carries the meaning: green = it worked, red = it
/// failed, neutral = just telling you something.
///
/// Blocking confirmations stay on `showDialog` — this is feedback only.
///
/// The `*On` variants take a [ScaffoldMessengerState] resolved earlier
/// instead of a [BuildContext], for the screens that show feedback right
/// before (or after) popping themselves off the navigator.
abstract final class AppSnack {
  /// Neutral background, also used as the default for [action].
  static const _neutralBackground = AppColors.darkText;

  /// Something completed as intended ("Produk ditambahkan").
  static void success(BuildContext context, String message, {Key? key}) =>
      successOn(ScaffoldMessenger.of(context), message, key: key);

  /// Something went wrong ("Gagal mencadangkan data").
  static void error(BuildContext context, String message, {Key? key}) =>
      errorOn(ScaffoldMessenger.of(context), message, key: key);

  /// Plain information, no success/failure connotation ("Mutasi dibatalkan").
  static void info(BuildContext context, String message, {Key? key}) =>
      infoOn(ScaffoldMessenger.of(context), message, key: key);

  /// Feedback carrying a single action, used for the undo flows.
  ///
  /// Neutral by design: the message is not "done, forget it" — the user
  /// is still expected to look at it and decide whether to undo.
  static void action(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    actionOn(
      ScaffoldMessenger.of(context),
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void successOn(
    ScaffoldMessengerState messenger,
    String message, {
    Key? key,
  }) => _show(messenger, message, AppColors.successPrimary, key);

  static void errorOn(
    ScaffoldMessengerState messenger,
    String message, {
    Key? key,
  }) => _show(messenger, message, AppColors.redPrimary, key);

  static void infoOn(
    ScaffoldMessengerState messenger,
    String message, {
    Key? key,
  }) => _show(messenger, message, _neutralBackground, key);

  static void actionOn(
    ScaffoldMessengerState messenger, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _neutralBackground,
        duration: duration,
        // SnackBar.persist defaults to true whenever action is non-null
        // (see SnackBar's own doc comment on `persist`), which makes
        // `duration` a no-op — the SnackBar would otherwise sit there
        // until manually swiped away instead of auto-dismissing.
        persist: false,
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }

  static void _show(
    ScaffoldMessengerState messenger,
    String message,
    Color background,
    Key? key,
  ) {
    messenger.showSnackBar(
      SnackBar(key: key, content: Text(message), backgroundColor: background),
    );
  }
}
