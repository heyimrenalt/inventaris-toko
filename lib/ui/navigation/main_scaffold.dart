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

  @override
  Widget build(BuildContext context) {
    final screens = [
      const BerandaScreen(),
      const ProdukScreen(),
      const MutasiScreen(),
      PengaturanScreen(isar: widget.isar),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        onTap: (index) => setState(() => _selectedIndex = index),
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
