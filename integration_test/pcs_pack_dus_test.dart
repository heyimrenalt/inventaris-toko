import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/app_settings.dart';
import 'package:inventaris_toko/data/models/category.dart';
import 'package:inventaris_toko/data/models/cost_price_adjustment.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/restock_list.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/beranda/prioritas_kulakan_screen.dart';
import 'package:inventaris_toko/ui/screens/mutasi/catat_mutasi_screen.dart';
import 'package:inventaris_toko/ui/screens/produk/product_detail_screen.dart';
import 'package:inventaris_toko/ui/screens/produk/product_form_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

/// End-to-end verification of the pcs/pack/dus feature (product form
/// summary box, detail page Kemasan section, Mutasi unit selector,
/// Prioritas Kulakan dus support) against a real device, a real Isar
/// database, and real platform channels — unlike the widget-test suite
/// under test/, which runs against a fake in-memory-backed Isar with no
/// real device rendering.
///
/// Opens its own throwaway Isar instance in a fresh temp subdirectory
/// (never the app's real getApplicationDocumentsDirectory() data) so a
/// run never touches — or is affected by — whatever's already installed
/// on the device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late ProductRepository productRepository;
  late StockMutationRepository stockMutationRepository;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory(
      '${(await getTemporaryDirectory()).path}/pcs_pack_dus_itest_'
      '${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);

    isar = await Isar.open(
      [
        CategorySchema,
        ProductSchema,
        StockMutationSchema,
        AppSettingsSchema,
        CostPriceAdjustmentSchema,
        RestockListSchema,
      ],
      directory: tempDir.path,
      name: 'itest_${DateTime.now().microsecondsSinceEpoch}',
    );
    stockMutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      stockMutationRepository,
      AppSettingsRepository(isar),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Pumps [screen] as a fresh `MaterialApp(home: screen)`. Pumps an
  /// unrelated placeholder widget first so the *previous* MaterialApp's
  /// element tree (and its Navigator) is fully torn down rather than
  /// "updated" in place — without that, repeatedly pumping a brand-new
  /// MaterialApp mid-test trips a `_history.isNotEmpty` framework
  /// assertion inside Navigator, since both trees share the same
  /// implicit GlobalObjectKey<NavigatorState>.
  Future<void> openScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  /// Re-opens the detail page fresh and returns the rendered "Stok saat
  /// ini" text — the actual thing being verified after a mutation, not a
  /// SnackBar or a direct repository read.
  Future<String> readStockLineFromDetailPage(WidgetTester tester, int productId) async {
    await openScreen(
      tester,
      ProductDetailScreen(isar: isar, productId: productId),
    );
    final textWidget = tester.widget<Text>(
      find.textContaining('Stok saat ini:').first,
    );
    return textWidget.data!;
  }

  testWidgets(
    'pcs/pack/dus end-to-end: form summary box, detail page Kemasan, Mutasi unit selector, '
    'Prioritas Kulakan dus support',
    (tester) async {
      // --- Setup: a plain pcs-only product with zero stock. ---
      final product = await productRepository.create(
        name: 'Indomie Goreng E2E',
        sellPrice: 3000,
        unit: 'pcs',
      );

      // === 1. Edit the product: set pack=6, dus=6, watch the live
      // "Ringkasan kemasan" summary box. ===
      final existing = (await productRepository.getById(product.id))!;
      await openScreen(tester, ProductFormScreen(isar: isar, existing: existing));

      expect(find.byKey(const Key('product_form_kemasan_summary')), findsNothing);

      await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '6');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('product_form_kemasan_summary')), findsOneWidget);
      expect(find.text('1 pack = 6 pcs'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('product_form_units_per_dus')), '6');
      await tester.pumpAndSettle();

      expect(find.text('1 dus = 6 pack = 36 pcs'), findsOneWidget);
      // currentStock is 0 at this point — the summary's stock section
      // must still render, showing 0 as a valid whole conversion.
      expect(find.text('Stok saat ini: 0 pcs'), findsOneWidget);
      expect(find.text('= 0 pack = 0 dus'), findsOneWidget);

      final submitFinder = find.byKey(const Key('product_form_submit'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // === 2. Detail page: Kemasan section + stock conversion line. ===
      await openScreen(tester, ProductDetailScreen(isar: isar, productId: product.id));

      expect(find.byKey(const Key('product_detail_kemasan_section')), findsOneWidget);
      expect(find.text('1 pack = 6 pcs'), findsOneWidget);
      expect(find.text('1 dus = 6 pack = 36 pcs'), findsOneWidget);
      expect(find.byKey(const Key('product_detail_stock_conversion')), findsOneWidget);
      expect(find.text('= 0 pack = 0 dus'), findsOneWidget);

      // === 3. Stok Masuk: switch to pack, type 2 -> preview "2 pack = 12
      // pcs" -> submit -> currentStock read back via the detail page. ===
      final withPackDus = (await productRepository.getById(product.id))!;
      await openScreen(
        tester,
        CatatMutasiScreen(isar: isar, product: withPackDus, initialType: StockMutationType.stockIn),
      );

      final packToggle = find.descendant(
        of: find.byKey(Key('unit_qty_toggle_${product.id}')),
        matching: find.text('pack'),
      );
      await tester.ensureVisible(packToggle);
      await tester.tap(packToggle);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '2');
      await tester.pumpAndSettle();

      expect(find.text('2 pack (12 pcs)'), findsOneWidget);

      final stokMasukSubmit = find.byKey(const Key('catat_mutasi_submit'));
      await tester.ensureVisible(stokMasukSubmit);
      await tester.tap(stokMasukSubmit);
      await tester.pumpAndSettle();

      final stockLineAfterMasuk = await readStockLineFromDetailPage(tester, product.id);
      expect(stockLineAfterMasuk, contains('Stok saat ini: 12 pcs'));
      expect(find.text('= 2 pack'), findsOneWidget);
      // 12 isn't divisible by 36, so no dus figure should be shown.
      expect(find.text('= 2 pack = 0 dus'), findsNothing);

      // === 5 (verified before 4, since it needs the low stock left by
      // step 3): Stok Keluar of 1 dus (36 pcs) against a currentStock of
      // only 12 pcs must be rejected, quoting the pcs-converted amount. ===
      final afterMasuk = (await productRepository.getById(product.id))!;
      await openScreen(
        tester,
        CatatMutasiScreen(isar: isar, product: afterMasuk, initialType: StockMutationType.stockOut),
      );

      final dusToggle1 = find.descendant(
        of: find.byKey(Key('unit_qty_toggle_${product.id}')),
        matching: find.text('dus'),
      );
      await tester.ensureVisible(dusToggle1);
      await tester.tap(dusToggle1);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '1');
      await tester.pumpAndSettle();

      expect(find.text('1 dus (6 pack, 36 pcs)'), findsOneWidget);

      final rejectedSubmit = find.byKey(const Key('catat_mutasi_submit'));
      await tester.ensureVisible(rejectedSubmit);
      await tester.tap(rejectedSubmit);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Stok tidak mencukupi. Stok saat ini: 12 pcs, jumlah yang dimasukkan: 36 pcs.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      final stockLineAfterRejection = await readStockLineFromDetailPage(tester, product.id);
      expect(stockLineAfterRejection, contains('Stok saat ini: 12 pcs'));

      // Top up enough stock (via a plain pcs Stok Masuk) so the dus-based
      // Stok Keluar in step 4 can actually succeed against real stock.
      final beforeTopUp = (await productRepository.getById(product.id))!;
      await openScreen(
        tester,
        CatatMutasiScreen(isar: isar, product: beforeTopUp, initialType: StockMutationType.stockIn),
      );
      await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '60');
      await tester.pumpAndSettle();
      final topUpSubmit = find.byKey(const Key('catat_mutasi_submit'));
      await tester.ensureVisible(topUpSubmit);
      await tester.tap(topUpSubmit);
      await tester.pumpAndSettle();

      final stockLineAfterTopUp = await readStockLineFromDetailPage(tester, product.id);
      expect(stockLineAfterTopUp, contains('Stok saat ini: 72 pcs'));

      // === 4. Stok Keluar: switch to dus, type 1 -> preview "1 dus = 6
      // pack = 36 pcs" -> submit -> currentStock read back via the detail
      // page. ===
      final withStock = (await productRepository.getById(product.id))!;
      await openScreen(
        tester,
        CatatMutasiScreen(isar: isar, product: withStock, initialType: StockMutationType.stockOut),
      );

      final dusToggle2 = find.descendant(
        of: find.byKey(Key('unit_qty_toggle_${product.id}')),
        matching: find.text('dus'),
      );
      await tester.ensureVisible(dusToggle2);
      await tester.tap(dusToggle2);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Key('unit_qty_field_${product.id}')), '1');
      await tester.pumpAndSettle();

      expect(find.text('1 dus (6 pack, 36 pcs)'), findsOneWidget);

      final stokKeluarSubmit = find.byKey(const Key('catat_mutasi_submit'));
      await tester.ensureVisible(stokKeluarSubmit);
      await tester.tap(stokKeluarSubmit);
      await tester.pumpAndSettle();

      final stockLineAfterKeluar = await readStockLineFromDetailPage(tester, product.id);
      // 72 (after top-up) - 36 (1 dus) = 36 pcs.
      expect(stockLineAfterKeluar, contains('Stok saat ini: 36 pcs'));
      expect(find.text('= 6 pack = 1 dus'), findsOneWidget);

      // === 6. Prioritas Kulakan: the qty field's unit toggle offers
      // pcs/pack/dus, and the read-only card shows the pack/dus stock
      // conversion. ===
      await openScreen(tester, PrioritasKulakanScreen(isar: isar));

      final kulakanToggle = find.byKey(Key('kulakan_qty_unit_toggle_${product.id}'));
      expect(kulakanToggle, findsOneWidget);
      expect(find.descendant(of: kulakanToggle, matching: find.text('pcs')), findsOneWidget);
      expect(find.descendant(of: kulakanToggle, matching: find.text('pack')), findsOneWidget);
      expect(find.descendant(of: kulakanToggle, matching: find.text('dus')), findsOneWidget);

      final priorityCard = find.byKey(Key('priority_card_${product.id}'));
      expect(priorityCard, findsOneWidget);
      expect(
        find.descendant(of: priorityCard, matching: find.text('= 6 pack = 1 dus')),
        findsOneWidget,
      );
    },
  );
}
