import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/navigation/main_scaffold.dart';
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

  // MainScaffold uses IndexedStack, so all 4 tab bodies (including
  // ProdukScreen, which now does a real Isar load on mount) are built
  // immediately on the first pump, not lazily on tab selection.
  Future<void> tapTab(WidgetTester tester, String label) {
    return tester.tap(
      find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label)),
    );
  }

  testWidgets('all 4 tabs render and can be switched without crashing', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: MainScaffold(isar: isar)));
      await settleAfterAsyncWork(tester);

      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Mutasi'), findsOneWidget);
      expect(find.text('Beranda — belum diimplementasikan'), findsOneWidget);

      await tapTab(tester, 'Produk');
      await settleAfterAsyncWork(tester);
      expect(
        find.text('Belum ada produk. Tambahkan produk pertama untuk mulai.'),
        findsOneWidget,
      );

      await tapTab(tester, 'Mutasi');
      await settleAfterAsyncWork(tester);
      expect(find.text('Mutasi — belum diimplementasikan'), findsOneWidget);

      await tapTab(tester, 'Pengaturan');
      await settleAfterAsyncWork(tester);
      expect(find.text('Kelola kategori'), findsOneWidget);
    });
  });
}
