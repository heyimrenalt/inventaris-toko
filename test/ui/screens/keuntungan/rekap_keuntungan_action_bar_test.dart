import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/keuntungan/rekap_keuntungan_screen.dart';
import 'package:inventaris_toko/ui/widgets/primary_button.dart';
import 'package:inventaris_toko/ui/widgets/secondary_button.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';

/// The Rekap Keuntungan action bar, after it moved off hand-rolled
/// [ElevatedButton]s onto the shared [SecondaryButton]/[PrimaryButton]
/// pair. The buttons carry the app's disabled styling themselves, so what
/// is worth pinning here is that both still render and that Salin still
/// reaches the clipboard.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late Isar isar;

  StockMutation sale(DateTime createdAt) => StockMutation()
    ..productId = 1
    ..type = StockMutationType.stockOut
    ..quantity = 1
    ..stockAfter = 0
    ..sellPriceSnapshot = 5000
    ..costPriceSnapshot = 3000
    ..createdAt = createdAt;

  /// See the sibling detail-screen test: every Isar call in a widget test
  /// has to run on the real event loop, which `testWidgets`' fake-async
  /// zone otherwise never drives.
  Future<void> openWith(WidgetTester tester, List<StockMutation> mutations) async {
    await tester.runAsync(() async {
      isar = await openTestIsar();
      if (mutations.isNotEmpty) {
        await isar.writeTxn(() => isar.stockMutations.putAll(mutations));
      }
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.idle();
      await tester.pump();
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RekapKeuntunganScreen(
          isar: isar,
          mutationRepository: StockMutationRepository(isar),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => closeTestIsar(isar));
  }

  testWidgets('renders Salin and Bagikan as the shared button widgets',
      (tester) async {
    await openWith(tester, [sale(DateTime(2026, 5, 5, 10))]);
    await pumpScreen(tester);

    expect(find.widgetWithText(SecondaryButton, 'Salin'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Bagikan'), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('tapping Salin writes the recap to the clipboard',
      (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await openWith(tester, [sale(DateTime(2026, 5, 5, 10))]);
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(SecondaryButton, 'Salin'));
    await settle(tester);

    expect(copied, hasLength(1));
    expect(copied.single, contains('REKAP KEUNTUNGAN'));

    await teardown(tester);
  });
}
