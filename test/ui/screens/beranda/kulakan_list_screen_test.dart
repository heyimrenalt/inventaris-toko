import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/category.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/restock_list.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/restock_list_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/beranda/kulakan_list_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

void main() {
  late Isar isar;
  late ProductRepository productRepository;
  late RestockListRepository restockListRepository;
  late CategoryRepository categoryRepository;
  late int categoryId;

  setUp(() async {
    isar = await openTestIsar();
    productRepository = ProductRepository(
      isar,
      StockMutationRepository(isar),
      AppSettingsRepository(isar),
    );
    restockListRepository = RestockListRepository(isar);
    categoryRepository = CategoryRepository(isar);
    categoryId = (await categoryRepository.create('Umum')).id;

    // This Flutter SDK's TestWidgetsFlutterBinding doesn't mock
    // SystemChannels.platform's Clipboard.setData/getData by default, so
    // _copyToClipboard's real Clipboard.setData call would otherwise hit
    // a missing platform channel — mock it in-memory here instead.
    String? clipboardText;
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> pumpScreen(WidgetTester tester, int restockListId) async {
    await tester.pumpWidget(MaterialApp(
      home: KulakanListScreen(isar: isar, restockListId: restockListId),
    ));
    await settleAfterAsyncWork(tester);
  }

  testWidgets('shows product name, current stock, and prefilled qty for a pcs-only product',
      (tester) async {
    await tester.runAsync(() async {
      final product = await productRepository.create(
        name: 'Gula Pasir',
        categoryId: categoryId,
        sellPrice: 15000,
        unit: 'pcs',
        initialStock: 4,
      );
      final list = await restockListRepository.create(
        items: [
          RestockListItemInput(
            productId: product.id,
            productName: product.name,
            qtyInPcs: 10,
            inputUnitWasPack: false,
          ),
        ],
      );

      await pumpScreen(tester, list.id);

      expect(find.text('Gula Pasir'), findsOneWidget);
      expect(find.text('Stok: 4 pcs'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(Key('kulakan_qty_field_${product.id}')))
            .controller!
            .text,
        '10',
      );
    });
  });

  testWidgets('a pack-configured product shows the pack/pcs toggle and dual-unit caption',
      (tester) async {
    await tester.runAsync(() async {
      final product = await productRepository.create(
        name: 'Indomie',
        categoryId: categoryId,
        sellPrice: 3000,
        unit: 'pcs',
        unitsPerPack: 12,
      );
      final list = await restockListRepository.create(
        items: [
          RestockListItemInput(
            productId: product.id,
            productName: product.name,
            qtyInPcs: 24,
            inputUnitWasPack: true,
          ),
        ],
      );

      await pumpScreen(tester, list.id);

      expect(find.byKey(Key('kulakan_qty_unit_toggle_${product.id}')), findsOneWidget);
      expect(find.text('2 pack (24 pcs)'), findsOneWidget);
    });
  });

  testWidgets('typing a pack quantity converts to pcs and updates the caption', (tester) async {
    await tester.runAsync(() async {
      final product = await productRepository.create(
        name: 'Indomie',
        categoryId: categoryId,
        sellPrice: 3000,
        unit: 'pcs',
        unitsPerPack: 12,
      );
      final list = await restockListRepository.create(
        items: [
          RestockListItemInput(
            productId: product.id,
            productName: product.name,
            qtyInPcs: 12,
            inputUnitWasPack: true,
          ),
        ],
      );

      await pumpScreen(tester, list.id);

      await tester.enterText(find.byKey(Key('kulakan_qty_field_${product.id}')), '3');
      await settleAfterAsyncWork(tester);

      expect(find.text('3 pack (36 pcs)'), findsOneWidget);

      final reloaded = await restockListRepository.getById(list.id);
      expect(reloaded!.items.first.qtyInPcs, 36);
    });
  });

  testWidgets('editing supplierName persists it to the RestockList', (tester) async {
    await tester.runAsync(() async {
      final list = await restockListRepository.create(items: []);
      await pumpScreen(tester, list.id);

      await tester.enterText(
        find.byKey(const Key('kulakan_list_supplier_field')),
        'Toko Pak Adi',
      );
      await settleAfterAsyncWork(tester);

      final reloaded = await restockListRepository.getById(list.id);
      expect(reloaded!.supplierName, 'Toko Pak Adi');
    });
  });

  testWidgets('a whitespace-only supplierName is stored as null', (tester) async {
    await tester.runAsync(() async {
      final list = await restockListRepository.create(items: []);
      await pumpScreen(tester, list.id);

      await tester.enterText(find.byKey(const Key('kulakan_list_supplier_field')), '   ');
      await settleAfterAsyncWork(tester);

      final reloaded = await restockListRepository.getById(list.id);
      expect(reloaded!.supplierName, isNull);
    });
  });

  testWidgets('a very long product name is ellipsized, not overflowed', (tester) async {
    await tester.runAsync(() async {
      final product = await productRepository.create(
        name: 'Minyak Goreng Kemasan Botol Ukuran Besar Merek Premium Spesial Edisi Terbatas',
        categoryId: categoryId,
        sellPrice: 20000,
        unit: 'pcs',
      );
      final list = await restockListRepository.create(
        items: [
          RestockListItemInput(
            productId: product.id,
            productName: product.name,
            qtyInPcs: 5,
            inputUnitWasPack: false,
          ),
        ],
      );

      await pumpScreen(tester, list.id);

      final nameText = tester.widget<Text>(find.text(product.name));
      expect(nameText.maxLines, 1);
      expect(nameText.overflow, TextOverflow.ellipsis);
    });
  });

  group('prefill', () {
    testWidgets('prefill equals lastRestockQty when present', (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 15000,
          unit: 'pcs',
        );
        await isar.writeTxn(() async {
          final p = (await isar.products.get(product.id))!;
          p.lastRestockQty = 30;
          await isar.products.put(p);
        });

        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 30,
              inputUnitWasPack: false,
            ),
          ],
        );

        await pumpScreen(tester, list.id);

        expect(
          tester
              .widget<TextField>(find.byKey(Key('kulakan_qty_field_${product.id}')))
              .controller!
              .text,
          '30',
        );
      });
    });
  });

  group('Selesai / lastRestockQty writeback', () {
    testWidgets('checking an item and tapping Selesai writes qtyInPcs into Product.lastRestockQty',
        (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 15000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 10,
              inputUnitWasPack: false,
            ),
          ],
        );

        await pumpScreen(tester, list.id);

        await tester.tap(find.byKey(Key('kulakan_list_checkbox_${product.id}')));
        await settleAfterAsyncWork(tester);
        await tester.tap(find.byKey(const Key('kulakan_list_complete_button')));
        await settleAfterAsyncWork(tester);

        final updated = await productRepository.getById(product.id);
        expect(updated!.lastRestockQty, 10);
        expect(updated.currentStock, 0);
      });
    });

    testWidgets(
      'lastRestockQty written on completion is qtyInPcs, not the pack figure, when input was in packs',
      (tester) async {
        await tester.runAsync(() async {
          final product = await productRepository.create(
            name: 'Indomie',
            categoryId: categoryId,
            sellPrice: 3000,
            unit: 'pcs',
            unitsPerPack: 12,
          );
          final list = await restockListRepository.create(
            items: [
              RestockListItemInput(
                productId: product.id,
                productName: product.name,
                qtyInPcs: 24,
                inputUnitWasPack: true,
              ),
            ],
          );

          await pumpScreen(tester, list.id);

          await tester.tap(find.byKey(Key('kulakan_list_checkbox_${product.id}')));
          await settleAfterAsyncWork(tester);
          await tester.tap(find.byKey(const Key('kulakan_list_complete_button')));
          await settleAfterAsyncWork(tester);

          final updated = await productRepository.getById(product.id);
          expect(updated!.lastRestockQty, 24);
        });
      },
    );

    testWidgets('an unchecked item does not write Product.lastRestockQty on Selesai', (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 15000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 10,
              inputUnitWasPack: false,
            ),
          ],
        );

        await pumpScreen(tester, list.id);
        await tester.tap(find.byKey(const Key('kulakan_list_complete_button')));
        await settleAfterAsyncWork(tester);

        final updated = await productRepository.getById(product.id);
        expect(updated!.lastRestockQty, isNull);
      });
    });
  });

  testWidgets(
    'unitsPerPack changed after lastRestockQty was saved: lastRestockQty stays in pcs, '
    'and the pack display recomputes',
    (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Indomie',
          categoryId: categoryId,
          sellPrice: 3000,
          unit: 'pcs',
          unitsPerPack: 12,
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 24,
              inputUnitWasPack: true,
            ),
          ],
        );
        await restockListRepository.toggleChecked(list.id, product.id);
        await restockListRepository.complete(list.id);

        var updated = await productRepository.getById(product.id);
        expect(updated!.lastRestockQty, 24);

        // The product's unitsPerPack changes after the fact (12 -> 10).
        await productRepository.update(id: product.id, unitsPerPack: 10);
        updated = await productRepository.getById(product.id);
        expect(updated!.lastRestockQty, 24, reason: 'lastRestockQty must stay untouched in pcs');

        // A fresh list prefilled from lastRestockQty now displays the
        // pack conversion against the *new* unitsPerPack.
        final newList = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: updated.lastRestockQty!,
              inputUnitWasPack: true,
            ),
          ],
        );

        await pumpScreen(tester, newList.id);

        expect(find.text('2.4 pack (24 pcs)'), findsOneWidget);
      });
    },
  );

  group('deleted/archived products in a saved list', () {
    testWidgets('a hard-deleted product shows the snapshotted name with a "(dihapus)" marker, '
        'does not crash, and its checkbox is disabled', (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Produk Lama',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 5,
              inputUnitWasPack: false,
            ),
          ],
        );
        await productRepository.delete(product.id);

        await pumpScreen(tester, list.id);

        expect(find.text('Produk Lama (dihapus)'), findsOneWidget);
        final checkbox =
            tester.widget<Checkbox>(find.byKey(Key('kulakan_list_checkbox_${product.id}')));
        expect(checkbox.onChanged, isNull);
      });
    });

    testWidgets('an archived product shows a "(diarsipkan)" marker and stays editable',
        (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Produk Musiman',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 5,
              inputUnitWasPack: false,
            ),
          ],
        );
        await productRepository.archive(product.id);

        await pumpScreen(tester, list.id);

        expect(find.text('Produk Musiman (diarsipkan)'), findsOneWidget);
        expect(find.byKey(Key('kulakan_qty_field_${product.id}')), findsOneWidget);
      });
    });
  });

  group('checkbox toggling on Daftar Kulakan', () {
    testWidgets('unchecking an item that arrived checked unchecks it and disables copy/share once '
        'it was the only one', (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 5,
              inputUnitWasPack: false,
              isChecked: true,
            ),
          ],
        );

        await pumpScreen(tester, list.id);
        expect(
          tester.widget<Checkbox>(find.byKey(Key('kulakan_list_checkbox_${product.id}'))).value,
          isTrue,
        );

        await tester.tap(find.byKey(Key('kulakan_list_checkbox_${product.id}')));
        await settleAfterAsyncWork(tester);

        expect(
          tester.widget<Checkbox>(find.byKey(Key('kulakan_list_checkbox_${product.id}'))).value,
          isFalse,
        );
        final copyButton =
            tester.widget<IconButton>(find.byKey(const Key('kulakan_list_copy_button')));
        expect(copyButton.onPressed, isNull);
      });
    });

    testWidgets('checking an item that was NOT in the original selection works and enables copy/share',
        (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 5,
              inputUnitWasPack: false,
              isChecked: false,
            ),
          ],
        );

        await pumpScreen(tester, list.id);
        expect(
          tester.widget<Checkbox>(find.byKey(Key('kulakan_list_checkbox_${product.id}'))).value,
          isFalse,
        );

        await tester.tap(find.byKey(Key('kulakan_list_checkbox_${product.id}')));
        await settleAfterAsyncWork(tester);

        expect(
          tester.widget<Checkbox>(find.byKey(Key('kulakan_list_checkbox_${product.id}'))).value,
          isTrue,
        );
        final copyButton =
            tester.widget<IconButton>(find.byKey(const Key('kulakan_list_copy_button')));
        expect(copyButton.onPressed, isNotNull);
      });
    });
  });

  group('share button state', () {
    testWidgets('disabled and hints "Centang minimal 1 barang" when nothing is checked',
        (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 5,
              inputUnitWasPack: false,
            ),
          ],
        );

        await pumpScreen(tester, list.id);

        final button =
            tester.widget<IconButton>(find.byKey(const Key('kulakan_list_whatsapp_button')));
        expect(button.onPressed, isNull);
        expect(find.text('Centang minimal 1 barang'), findsOneWidget);
      });
    });

    testWidgets('enabled once at least one item is checked', (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 5,
              inputUnitWasPack: false,
            ),
          ],
        );

        await pumpScreen(tester, list.id);
        await tester.tap(find.byKey(Key('kulakan_list_checkbox_${product.id}')));
        await settleAfterAsyncWork(tester);

        final button =
            tester.widget<IconButton>(find.byKey(const Key('kulakan_list_whatsapp_button')));
        expect(button.onPressed, isNotNull);
        expect(find.text('Centang minimal 1 barang'), findsNothing);
      });
    });
  });

  group('copy button', () {
    testWidgets('disabled and hints "Centang minimal 1 barang" when nothing is checked',
        (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 5,
              inputUnitWasPack: false,
            ),
          ],
        );

        await pumpScreen(tester, list.id);

        final button = tester.widget<IconButton>(find.byKey(const Key('kulakan_list_copy_button')));
        expect(button.onPressed, isNull);
        expect(find.text('Centang minimal 1 barang'), findsOneWidget);
      });
    });

    testWidgets('2 items checked, 1 not: tapping copy puts exactly the 2 checked items on the clipboard',
        (tester) async {
      await tester.runAsync(() async {
        final a = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final b = await productRepository.create(
          name: 'Telur',
          categoryId: categoryId,
          sellPrice: 2000,
          unit: 'pcs',
        );
        final c = await productRepository.create(
          name: 'Minyak Goreng',
          categoryId: categoryId,
          sellPrice: 3000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(productId: a.id, productName: a.name, qtyInPcs: 5, inputUnitWasPack: false),
            RestockListItemInput(productId: b.id, productName: b.name, qtyInPcs: 2, inputUnitWasPack: false),
            RestockListItemInput(productId: c.id, productName: c.name, qtyInPcs: 1, inputUnitWasPack: false),
          ],
        );

        await pumpScreen(tester, list.id);
        await tester.tap(find.byKey(Key('kulakan_list_checkbox_${a.id}')));
        await settleAfterAsyncWork(tester);
        await tester.tap(find.byKey(Key('kulakan_list_checkbox_${b.id}')));
        await settleAfterAsyncWork(tester);

        await tester.tap(find.byKey(const Key('kulakan_list_copy_button')));
        await settleAfterAsyncWork(tester);

        final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
        expect(clipboard!.text, contains('Gula Pasir'));
        expect(clipboard.text, contains('Telur'));
        expect(clipboard.text, isNot(contains('Minyak Goreng')));
        expect(clipboard.text, contains('Total: 2 item'));
        expect(find.text('Daftar kulakan disalin ke clipboard'), findsOneWidget);
      });
    });

    testWidgets('rapid double-tap does not crash and shows the SnackBar', (tester) async {
      await tester.runAsync(() async {
        final product = await productRepository.create(
          name: 'Gula Pasir',
          categoryId: categoryId,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final list = await restockListRepository.create(
          items: [
            RestockListItemInput(
              productId: product.id,
              productName: product.name,
              qtyInPcs: 5,
              inputUnitWasPack: false,
            ),
          ],
        );

        await pumpScreen(tester, list.id);
        await tester.tap(find.byKey(Key('kulakan_list_checkbox_${product.id}')));
        await settleAfterAsyncWork(tester);

        await tester.tap(find.byKey(const Key('kulakan_list_copy_button')));
        await tester.tap(find.byKey(const Key('kulakan_list_copy_button')));
        await settleAfterAsyncWork(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Daftar kulakan disalin ke clipboard'), findsOneWidget);
      });
    });
  });

  group('buildKulakanListShareText', () {
    Product buildProduct({
      required int id,
      required String name,
      int? categoryId,
      int? unitsPerPack,
      bool isArchived = false,
    }) {
      final now = DateTime(2026, 7, 16);
      return Product()
        ..id = id
        ..name = name
        ..categoryId = categoryId
        ..sellPrice = 1000
        ..unit = 'pcs'
        ..currentStock = 0
        ..minStockThreshold = 5
        ..unitsPerPack = unitsPerPack
        ..isArchived = isArchived
        ..createdAt = now
        ..updatedAt = now;
    }

    RestockListItem buildItem({
      required int productId,
      required double qtyInPcs,
      bool inputUnitWasPack = false,
      bool isChecked = true,
    }) {
      return RestockListItem()
        ..productId = productId
        ..qtyInPcs = qtyInPcs
        ..inputUnitWasPack = inputUnitWasPack
        ..isChecked = isChecked;
    }

    test('qty display: plain pcs when inputUnitWasPack is false, dual pack(pcs) when true', () {
      final gula = buildProduct(id: 1, name: 'Gula Pasir 1kg');
      final indomie = buildProduct(id: 2, name: 'Indomie Goreng', unitsPerPack: 12);

      final list = RestockList()
        ..id = 1
        ..supplierName = 'Toko Pak Adi'
        ..createdAt = DateTime(2026, 7, 16)
        ..items = [
          buildItem(productId: 1, qtyInPcs: 10),
          buildItem(productId: 2, qtyInPcs: 24, inputUnitWasPack: true),
        ];

      final text = buildKulakanListShareText(
        list: list,
        productsById: {1: gula, 2: indomie},
        categoriesById: {},
        now: DateTime(2026, 7, 16),
      );

      expect(text, contains('Daftar Kulakan - Toko Pak Adi'));
      expect(text, contains('16 Juli 2026'));
      expect(text, contains('Gula Pasir 1kg - 10 pcs'));
      expect(text, contains('Indomie Goreng - 2 pack (24 pcs)'));
      expect(text, contains('Total: 2 item'));
    });

    test('only checked items are included', () {
      final gula = buildProduct(id: 1, name: 'Gula Pasir');
      final kopi = buildProduct(id: 2, name: 'Kopi Kapal Api');

      final list = RestockList()
        ..id = 1
        ..createdAt = DateTime(2026, 7, 16)
        ..items = [
          buildItem(productId: 1, qtyInPcs: 10),
          buildItem(productId: 2, qtyInPcs: 5, isChecked: false),
        ];

      final text = buildKulakanListShareText(
        list: list,
        productsById: {1: gula, 2: kopi},
        categoriesById: {},
        now: DateTime(2026, 7, 16),
      );

      expect(text, contains('Gula Pasir'));
      expect(text, isNot(contains('Kopi Kapal Api')));
      expect(text, contains('Total: 1 item'));
    });

    test('a hard-deleted product (missing from productsById) is excluded, no crash', () {
      final list = RestockList()
        ..id = 1
        ..createdAt = DateTime(2026, 7, 16)
        ..items = [buildItem(productId: 99, qtyInPcs: 10)];

      final text = buildKulakanListShareText(
        list: list,
        productsById: {},
        categoriesById: {},
        now: DateTime(2026, 7, 16),
      );

      expect(text, contains('Total: 0 item'));
    });

    test('an archived product is excluded even if checked', () {
      final archived = buildProduct(id: 1, name: 'Produk Musiman', isArchived: true);
      final list = RestockList()
        ..id = 1
        ..createdAt = DateTime(2026, 7, 16)
        ..items = [buildItem(productId: 1, qtyInPcs: 10)];

      final text = buildKulakanListShareText(
        list: list,
        productsById: {1: archived},
        categoriesById: {},
        now: DateTime(2026, 7, 16),
      );

      expect(text, isNot(contains('Produk Musiman')));
      expect(text, contains('Total: 0 item'));
    });

    test('empty/whitespace supplierName renders "-"', () {
      final list = RestockList()
        ..id = 1
        ..supplierName = null
        ..createdAt = DateTime(2026, 7, 16)
        ..items = [];

      final text = buildKulakanListShareText(
        list: list,
        productsById: {},
        categoriesById: {},
        now: DateTime(2026, 7, 16),
      );

      expect(text, contains('Daftar Kulakan - -'));
    });

    group('grouping by top-level category', () {
      test('groups by the TOP-LEVEL ancestor, not the leaf category, and puts Lainnya last', () {
        final sembako = Category()
          ..id = 1
          ..name = 'Sembako'
          ..parentId = null
          ..createdAt = DateTime(2026, 1, 1);
        final beras = Category()
          ..id = 2
          ..name = 'Beras'
          ..parentId = 1
          ..createdAt = DateTime(2026, 1, 1);
        final minuman = Category()
          ..id = 3
          ..name = 'Minuman'
          ..parentId = null
          ..createdAt = DateTime(2026, 1, 1);

        // productA tagged to the leaf "Beras" -> should group under root "Sembako".
        final productA = buildProduct(id: 1, name: 'Beras Premium', categoryId: 2);
        // productB tagged directly to the top-level "Minuman".
        final productB = buildProduct(id: 2, name: 'Teh Botol', categoryId: 3);
        // productC uncategorized -> "Lainnya".
        final productC = buildProduct(id: 3, name: 'Barang Lain', categoryId: null);

        final list = RestockList()
          ..id = 1
          ..createdAt = DateTime(2026, 7, 16)
          ..items = [
            buildItem(productId: 3, qtyInPcs: 1),
            buildItem(productId: 1, qtyInPcs: 2),
            buildItem(productId: 2, qtyInPcs: 3),
          ];

        final text = buildKulakanListShareText(
          list: list,
          productsById: {1: productA, 2: productB, 3: productC},
          categoriesById: {1: sembako, 2: beras, 3: minuman},
          now: DateTime(2026, 7, 16),
        );

        expect(text, contains('Sembako'));
        expect(text, contains('Minuman'));
        expect(text, contains(lainnyaGroupName));
        expect(text, isNot(contains('Beras\n')));

        final sembakoIndex = text.indexOf('Sembako');
        final minumanIndex = text.indexOf('Minuman');
        final lainnyaIndex = text.indexOf(lainnyaGroupName);
        expect(lainnyaIndex, greaterThan(sembakoIndex));
        expect(lainnyaIndex, greaterThan(minumanIndex));
      });

      test('a product whose category was since deleted falls back to Lainnya, no crash', () {
        final product = buildProduct(id: 1, name: 'Barang Yatim', categoryId: 999);
        final list = RestockList()
          ..id = 1
          ..createdAt = DateTime(2026, 7, 16)
          ..items = [buildItem(productId: 1, qtyInPcs: 1)];

        final text = buildKulakanListShareText(
          list: list,
          productsById: {1: product},
          // categoriesById intentionally does not contain id 999 —
          // simulates the category having been deleted.
          categoriesById: {},
          now: DateTime(2026, 7, 16),
        );

        expect(text, contains(lainnyaGroupName));
        expect(text, contains('Barang Yatim'));
      });
    });
  });
}
