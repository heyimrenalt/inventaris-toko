/// Spacing scale distilled from Beranda's real layout values (screen/card
/// padding, inter-section gaps). Colors/shape/text already have dedicated
/// token files ([AppColors]/[AppDimensions]/[AppTextStyles]) in this
/// directory — this fills the missing spacing piece.
///
/// Additive only: nothing in the app imports this yet, so adding it changes
/// no UI. A handful of observed values (6, 10, 14) don't fit this scale and
/// are deliberately left out rather than forced — see the audit report for
/// where they occur.
abstract final class AppSpacing {
  /// 2px — extra-extra-small. Use sparingly, only for tight nested spacing
  /// (e.g. between an icon and its own label). Prefer [xs] (4) when in doubt.
  static const xxs = 2.0;

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}
