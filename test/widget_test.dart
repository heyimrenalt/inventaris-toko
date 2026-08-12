import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/ui/navigation/main_scaffold.dart';
import 'package:inventaris_toko/ui/widgets/glass_bottom_nav.dart';
import 'package:isar_community/isar.dart';

import 'data/repositories/test_isar.dart';
import 'ui/widget_test_helpers.dart';

void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  // MainScaffold uses a swipeable PageView; each tab's label in the
  // GlassBottomNav is stable regardless of its selected/unselected icon, so
  // we tap tabs by that label rather than by icon.
  Future<void> tapTab(WidgetTester tester, String label) {
    return tester.tap(
      find.descendant(of: find.byType(GlassBottomNav), matching: find.text(label)),
    );
  }

  testWidgets('all 4 tabs render and can be switched without crashing', (tester) async {
    await tester.runAsync(() async {
      // Otherwise the one-time OEM battery-optimization dialog (auto-shown
      // by PengaturanScreen, which IndexedStack builds eagerly alongside
      // Beranda) covers the screen and swallows every tab tap below.
      await AppSettingsRepository(isar).dismissBatteryOptimizationDialog();
      await tester.pumpWidget(MaterialApp(home: MainScaffold(isar: isar)));
      await settleAfterAsyncWork(tester);

      // 'Beranda' now appears twice (bottom nav label + the tab's own
      // AppBar title), unlike the other still-placeholder/simple tabs.
      expect(find.text('Beranda'), findsNWidgets(2));
      expect(find.text('Mutasi'), findsOneWidget);
      expect(find.text('Total Produk'), findsOneWidget);

      await tapTab(tester, 'Produk');
      await settleAfterAsyncWork(tester);
      expect(
        find.text('Belum ada produk. Tambahkan produk pertama untuk mulai.'),
        findsOneWidget,
      );

      await tapTab(tester, 'Mutasi');
      await settleAfterAsyncWork(tester);
      expect(find.text('Belum ada riwayat mutasi stok.'), findsOneWidget);

      await tapTab(tester, 'Pengaturan');
      await settleAfterAsyncWork(tester);
      expect(find.text('Kelola kategori'), findsOneWidget);
    });
  });
}
