import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One destination in [GlassBottomNav]. [icon] is the outline (inactive)
/// glyph; [activeIcon] is the filled (selected) glyph.
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// A floating "liquid glass" bottom navigation bar: a frosted, translucent
/// pill that hovers above the content (which shows through a real
/// [BackdropFilter] blur), with a soft green highlight that *slides*
/// between tabs.
///
/// The highlight tracks [pageListenable] — the host's continuous PageView
/// scroll offset (e.g. 1.4 while dragging from Produk toward Mutasi) — so
/// it glides under the finger. Crucially, only the thin pill+labels layer
/// rebuilds per frame (via [ValueListenableBuilder]); the expensive frosted
/// [BackdropFilter] shell is built once and left alone, so dragging doesn't
/// rebuild the blur every frame.
///
/// Requires the host [Scaffold] to set `extendBody: true` so page content
/// scrolls *behind* this bar. Because of that, Flutter reports this bar's
/// full height as each page's `MediaQuery.padding.bottom`; a page clears the
/// bar by padding its scroll view's bottom with that value plus [contentGap]
/// (never a separately hand-computed bar height, which would double it).
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.pageListenable,
    required this.onTap,
  });

  final List<GlassNavItem> items;
  final ValueChanged<int> onTap;

  /// Continuous scroll position from the host's PageController (0.0 = first
  /// tab, 1.5 = halfway to the third). Drives the sliding pill and the
  /// icon/label color fade.
  final ValueListenable<double> pageListenable;

  /// Small breathing room a page should add *on top of* its
  /// `MediaQuery.padding.bottom` so its last item sits just above the bar's
  /// top edge — not touching it, not far from it.
  ///
  /// Because the host Scaffold sets `extendBody: true`, Flutter already
  /// reports this floating bar's full height (bar + float gap + device
  /// safe-area inset) as each page's `MediaQuery.padding.bottom`. So a page
  /// clears the bar with exactly `MediaQuery.of(context).padding.bottom +
  /// contentGap` — do NOT also add a hand-computed bar height on top, or the
  /// clearance doubles.
  static const double contentGap = 8;

  static const double _barHeight = 60;
  static const double _bottomGap = 12;
  static const double _sideMargin = 16;
  static const double _radius = 26;
  static const double _innerPad = 7;
  static const double _pillRadius = 18;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _sideMargin,
          0,
          _sideMargin,
          _bottomGap + bottomInset,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            // Deliberately a small blur radius: BackdropFilter cost scales
            // with the blur sigma, and on budget GPUs (e.g. Oppo F11 /
            // Helio P70) a large sigma janks every scroll/swipe frame. 6 is
            // enough to still read as frosted glass without that cost.
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              height: _barHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                // Translucent white so the blurred content tints it.
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE6FFFFFF), Color(0xBFFFFFFF)],
                ),
                border: Border.all(color: const Color(0x99FFFFFF), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(_innerPad),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabWidth = constraints.maxWidth / items.length;
                    // Only this subtree rebuilds as the page offset changes.
                    return ValueListenableBuilder<double>(
                      valueListenable: pageListenable,
                      builder: (context, rawPosition, _) {
                        final position = rawPosition.clamp(
                          0.0,
                          (items.length - 1).toDouble(),
                        );
                        return Stack(
                          children: [
                            // The single sliding highlight pill, positioned
                            // by the continuous page offset so a drag drags
                            // it too.
                            Positioned(
                              left: position * tabWidth,
                              top: 0,
                              bottom: 0,
                              width: tabWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(_pillRadius),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x2900AA0D),
                                      Color(0x1400AA0D),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                for (var i = 0; i < items.length; i++)
                                  Expanded(
                                    child: _GlassNavTab(
                                      item: items[i],
                                      // 1 at the pill's center, fading to 0
                                      // one tab away — drives the icon/label
                                      // color as the pill passes.
                                      selectedT: (1 - (position - i).abs())
                                          .clamp(0.0, 1.0),
                                      onTap: () => onTap(i),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavTab extends StatelessWidget {
  const _GlassNavTab({
    required this.item,
    required this.selectedT,
    required this.onTap,
  });

  final GlassNavItem item;

  /// 0 = fully inactive, 1 = fully on this tab. Interpolated so color
  /// transitions track the sliding pill.
  final double selectedT;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(AppColors.gray700, AppColors.primary, selectedT)!;
    // Swap to the filled glyph once the pill is more than halfway onto it.
    final filled = selectedT >= 0.5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(filled ? item.activeIcon : item.icon, size: 23, color: color),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
