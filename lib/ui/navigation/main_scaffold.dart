import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../screens/beranda/beranda_screen.dart';
import '../screens/mutasi/mutasi_screen.dart';
import '../screens/pengaturan/pengaturan_screen.dart';
import '../screens/produk/produk_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.isar});

  final Isar isar;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

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
  void dispose() {
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
    if (index == _selectedIndex) {
      _scrollToTop(index);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      BerandaScreen(isar: widget.isar, scrollController: _berandaScrollController),
      ProdukScreen(isar: widget.isar, scrollController: _produkScrollController),
      MutasiScreen(isar: widget.isar, scrollController: _mutasiScrollController),
      PengaturanScreen(
        isar: widget.isar,
        onDataReset: () => setState(() => _selectedIndex = 0),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Produk'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Mutasi'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Pengaturan'),
        ],
      ),
    );
  }
}
