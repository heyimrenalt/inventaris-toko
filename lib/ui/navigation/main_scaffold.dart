import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../screens/beranda/beranda_screen.dart';
import '../screens/mutasi/mutasi_screen.dart';
import '../screens/pengaturan/pengaturan_screen.dart';
import '../screens/produk/produk_screen.dart';
import '../widgets/glass_bottom_nav.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.isar});

  final Isar isar;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // Drives the swipeable page transition. Its live scroll offset also
  // positions the nav bar's sliding highlight pill (via [_pageNotifier]) so
  // the pill glides under the finger during a drag instead of snapping.
  final PageController _pageController = PageController();

  // Continuous page offset (0.0..3.0) mirrored from [_pageController].
  // Deliberately a ValueNotifier rather than setState: only the nav bar's
  // thin pill layer listens to it, so a drag repositions the pill every
  // frame WITHOUT rebuilding this whole scaffold (PageView + BackdropFilter)
  // — that per-frame full rebuild was the source of the scroll jank.
  final ValueNotifier<double> _pageNotifier = ValueNotifier<double>(0);

  // Pengaturan (index 3) is a short settings page with nothing to scroll,
  // so it deliberately has no entry here — re-tapping it just does the
  // normal tab switch (a no-op since it's already selected).
  final ScrollController _berandaScrollController = ScrollController();
  final ScrollController _produkScrollController = ScrollController();
  final ScrollController _mutasiScrollController = ScrollController();

  // Tracks which tab indices currently have a scroll-to-top animation in
  // flight, so a rapid repeated tap on the same nav item can't stack a
  // second animateTo() on top of one still running.
  final Set<int> _scrollAnimationInFlight = {};

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_syncPage);
  }

  void _syncPage() {
    final page = _pageController.page;
    if (page != null) _pageNotifier.value = page;
  }

  @override
  void dispose() {
    _pageController.removeListener(_syncPage);
    _pageController.dispose();
    _pageNotifier.dispose();
    _berandaScrollController.dispose();
    _produkScrollController.dispose();
    _mutasiScrollController.dispose();
    super.dispose();
  }

  ScrollController? _scrollControllerFor(int index) {
    switch (index) {
      case 0:
        return _berandaScrollController;
      case 1:
        return _produkScrollController;
      case 2:
        return _mutasiScrollController;
      default:
        return null;
    }
  }

  Future<void> _scrollToTop(int index) async {
    final controller = _scrollControllerFor(index);
    if (controller == null || !controller.hasClients) return;
    if (_scrollAnimationInFlight.contains(index)) return;
    // Already at the top: a no-op, not a zero-distance animation.
    if (controller.offset <= 0) return;

    _scrollAnimationInFlight.add(index);
    try {
      await controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } finally {
      _scrollAnimationInFlight.remove(index);
    }
  }

  void _onNavTap(int index) {
    // Leaving a tab dismisses any open keyboard — a search field on the
    // tab we're leaving shouldn't keep the keyboard up over the tab we
    // land on. Covers swipes too via [onPageChanged].
    FocusScope.of(context).unfocus();
    if (index == _selectedIndex) {
      _scrollToTop(index);
      return;
    }
    // A tab *tap* switches instantly (matching iOS WhatsApp/Telegram, where
    // the smooth slide is the *swipe* gesture, not the tap). onPageChanged
    // then updates _selectedIndex. The buttery cross-tab glide — and the
    // pill sliding under the finger — comes from dragging the PageView.
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      BerandaScreen(isar: widget.isar, scrollController: _berandaScrollController),
      ProdukScreen(isar: widget.isar, scrollController: _produkScrollController),
      MutasiScreen(isar: widget.isar, scrollController: _mutasiScrollController),
      PengaturanScreen(
        isar: widget.isar,
        onDataReset: () {
          setState(() => _selectedIndex = 0);
          _pageController.jumpToPage(0);
        },
      ),
    ];

    return Scaffold(
      // Lets page content scroll *behind* the floating glass nav bar so its
      // BackdropFilter has something to blur.
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          FocusScope.of(context).unfocus();
          setState(() => _selectedIndex = index);
        },
        // Every tab stays alive across swipes (via _KeepAlivePage) so the
        // old IndexedStack guarantees still hold: each screen's initState /
        // watchLazy subscription runs once and survives tab changes.
        children: [for (final screen in screens) _KeepAlivePage(child: screen)],
      ),
      bottomNavigationBar: GlassBottomNav(
        pageListenable: _pageNotifier,
        onTap: _onNavTap,
        items: const [
          GlassNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Beranda',
          ),
          GlassNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2,
            label: 'Produk',
          ),
          GlassNavItem(
            icon: Icons.swap_horiz,
            activeIcon: Icons.swap_horiz,
            label: 'Mutasi',
          ),
          GlassNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

/// Keeps a PageView child mounted even while it's off-screen, so swiping
/// away from a tab and back doesn't tear down and re-run its state — the
/// behavior the previous IndexedStack gave for free.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
