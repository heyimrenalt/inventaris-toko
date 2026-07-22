import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/cost_price_adjustment_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/produk/product_form_screen.dart';
import 'package:inventaris_toko/ui/widgets/category_picker_field.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';
import 'fake_photo_storage_service.dart';

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    productRepository = ProductRepository(
      isar,
      StockMutationRepository(isar),
      AppSettingsRepository(isar),
    );
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> pumpForm(WidgetTester tester, {Product? existing}) async {
    await tester.pumpWidget(MaterialApp(
      home: ProductFormScreen(
        isar: isar,
        existing: existing,
        photoStorageService: FakePhotoStorageService(),
      ),
    ));
    await settleAfterAsyncWork(tester);
  }

  Future<void> openCategoryPicker(WidgetTester tester) async {
    final fieldFinder = find.byKey(const Key('category_picker_field'));
    await tester.ensureVisible(fieldFinder);
    await tester.tap(fieldFinder);
    // CategoryTreePicker shows a CircularProgressIndicator (indefinite
    // animation) until its own real Isar getAll() call resolves — a bare
    // pumpAndSettle() would spin forever waiting on a real Future it
    // can't see, same reasoning as settleAfterAsyncWork everywhere else.
    await settleAfterAsyncWork(tester);
  }

  Future<void> selectCategory(WidgetTester tester, String name) async {
    await openCategoryPicker(tester);
    await tester.tap(find.text(name).last);
    await settleAfterAsyncWork(tester);
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final submitFinder = find.byKey(const Key('product_form_submit'));
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await settleAfterAsyncWork(tester);
  }

  testWidgets('add flow: valid fields creates the product', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await pumpForm(tester);

      // Barcode scanning was dropped from this app — no QR icon anywhere.
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);

      await tester.enterText(find.byKey(const Key('product_form_name')), 'Chips');
      await selectCategory(tester, 'Snacks');
      await tester.enterText(find.byKey(const Key('product_form_price')), '5000');
      await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');

      await tapSubmit(tester);

      final products = await productRepository.getAll();
      expect(products, hasLength(1));
      expect(products.first.name, 'Chips');
      expect(products.first.categoryId, category.id);
      expect(products.first.sellPrice, 5000);
      expect(products.first.unit, 'pcs');
    });
  });

  testWidgets('add flow: category left unset creates an uncategorized product', (tester) async {
    await tester.runAsync(() async {
      await pumpForm(tester);

      await tester.enterText(find.byKey(const Key('product_form_name')), 'Misc Item');
      await tester.enterText(find.byKey(const Key('product_form_price')), '5000');
      await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');

      await tapSubmit(tester);

      final products = await productRepository.getAll();
      expect(products, hasLength(1));
      expect(products.first.categoryId, isNull);
    });
  });

  testWidgets('add flow: empty name shows inline validation error and does not submit', (tester) async {
    await tester.runAsync(() async {
      await categoryRepository.create('Snacks');
      await pumpForm(tester);

      await selectCategory(tester, 'Snacks');
      await tester.enterText(find.byKey(const Key('product_form_price')), '5000');
      await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');

      await tapSubmit(tester);

      expect(find.text('Nama produk tidak boleh kosong'), findsOneWidget);
      expect(find.text('Tambah Produk'), findsOneWidget);
      expect(await productRepository.getAll(), isEmpty);
    });
  });

  testWidgets('add flow: duplicate product code shows inline validation error', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      await productRepository.create(
        name: 'Existing',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        code: '12345',
      );

      await pumpForm(tester);

      await tester.enterText(find.byKey(const Key('product_form_name')), 'Chips');
      await tester.enterText(find.byKey(const Key('product_form_code')), '12345');
      await selectCategory(tester, 'Snacks');
      await tester.enterText(find.byKey(const Key('product_form_price')), '5000');
      await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');

      await tapSubmit(tester);

      expect(find.text('Kode barang ini sudah dipakai produk lain'), findsOneWidget);
      expect(await productRepository.getAll(), hasLength(1));
    });
  });

  testWidgets('add flow: "Stok awal" field is visible when adding', (tester) async {
    await tester.runAsync(() async {
      await pumpForm(tester);

      expect(find.byKey(const Key('product_form_initial_stock')), findsOneWidget);
      expect(find.byKey(const Key('product_form_current_stock_readonly')), findsNothing);
    });
  });

  testWidgets('edit flow: "Stok awal" field is not present when editing', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
        initialStock: 10,
      );

      await pumpForm(tester, existing: product);

      expect(find.byKey(const Key('product_form_initial_stock')), findsNothing);
      expect(find.byKey(const Key('product_form_current_stock_readonly')), findsOneWidget);
    });
  });

  testWidgets('edit flow: saving updates fields but leaves currentStock unchanged', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
        initialStock: 10,
      );

      await pumpForm(tester, existing: product);

      await tester.enterText(find.byKey(const Key('product_form_name')), 'Chips XL');
      await tester.enterText(find.byKey(const Key('product_form_price')), '7500');

      await tapSubmit(tester);

      final updated = await productRepository.getById(product.id);
      expect(updated!.name, 'Chips XL');
      expect(updated.sellPrice, 7500);
      expect(updated.currentStock, 10);
    });
  });

  testWidgets('edit flow: switching an existing product to Lainnya clears its category', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 5000,
        unit: 'pcs',
      );

      await pumpForm(tester, existing: product);

      await openCategoryPicker(tester);
      await tester.tap(find.byKey(const Key('category_picker_uncategorized')));
      await tester.pumpAndSettle();

      await tapSubmit(tester);

      final updated = await productRepository.getById(product.id);
      expect(updated!.categoryId, isNull);
    });
  });

  testWidgets(
    'nested category shows as a "Parent > Child" breadcrumb once selected',
    (tester) async {
      await tester.runAsync(() async {
        final alatTulis = await categoryRepository.create('Alat Tulis');
        await categoryRepository.create('Pulpen', parentId: alatTulis.id);
        await pumpForm(tester);

        await openCategoryPicker(tester);
        await tester.tap(find.byKey(Key('category_picker_expand_${alatTulis.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pulpen'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(CategoryPickerField),
            matching: find.text('Alat Tulis > Pulpen'),
          ),
          findsOneWidget,
        );
      });
    },
  );

  testWidgets('inline category creation adds it, staying in the picker for selection', (tester) async {
    await tester.runAsync(() async {
      await pumpForm(tester);

      await openCategoryPicker(tester);
      await tester.tap(find.byKey(const Key('category_picker_add_root')));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Kategori'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Snacks');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Simpan'),
        ),
      );
      await settleAfterAsyncWork(tester);

      // The dialog closes but the picker sheet stays open, showing the
      // newly created category so the user can now tap it to select it —
      // per spec, inline add never leaves the picker on its own.
      final categories = await categoryRepository.getAll();
      expect(categories, hasLength(1));
      expect(find.text('Snacks'), findsOneWidget);

      await tester.tap(find.text('Snacks'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(CategoryPickerField),
          matching: find.text('Snacks'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'adding a category elsewhere (direct repository call) auto-refreshes the picker '
    'without any manual trigger',
    (tester) async {
      await tester.runAsync(() async {
        await categoryRepository.create('Snacks');
        await pumpForm(tester);
        await openCategoryPicker(tester);

        // Simulates a category added from Kelola Kategori (Pengaturan
        // tab, a separately mounted screen) while this picker stays
        // open — exactly the case the watchLazy() subscription is meant
        // to fix.
        await categoryRepository.create('Drinks');
        await settleAfterAsyncWork(tester);

        expect(find.text('Drinks'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'add flow: filling both harga modal and harga jual shows live margin calculation; '
    'clearing either hides it',
    (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        expect(find.byKey(const Key('product_form_margin_panel')), findsNothing);

        await tester.enterText(find.byKey(const Key('product_form_cost_price')), '7500');
        await tester.pump();
        expect(find.byKey(const Key('product_form_margin_panel')), findsNothing);

        await tester.enterText(find.byKey(const Key('product_form_price')), '10000');
        await tester.pump();

        expect(find.text('Untung per unit: Rp 2.500'), findsOneWidget);
        expect(find.text('Margin: 25%'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('product_form_cost_price')), '');
        await tester.pump();

        expect(find.byKey(const Key('product_form_margin_panel')), findsNothing);
      });
    },
  );

  testWidgets(
    'add flow: harga modal is passed through as the product\'s initial averageCostPrice',
    (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_name')), 'Chips');
        await tester.enterText(find.byKey(const Key('product_form_cost_price')), '3000');
        await tester.enterText(find.byKey(const Key('product_form_price')), '5000');
        await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');

        await tapSubmit(tester);

        final products = await productRepository.getAll();
        expect(products, hasLength(1));
        expect(products.first.averageCostPrice, 3000);
      });
    },
  );

  testWidgets(
    'edit flow: averageCostPrice is shown as read-only context plus a pre-filled '
    'editable correction field, and the live margin preview updates as the sell '
    'price changes',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 5000,
          unit: 'pcs',
          averageCostPrice: 4000,
        );

        await pumpForm(tester, existing: product);

        expect(find.byKey(const Key('product_form_hpp_readonly')), findsOneWidget);
        expect(find.textContaining('HPP saat ini: Rp 4.000/unit'), findsOneWidget);
        expect(find.byKey(const Key('product_form_cost_price')), findsOneWidget);
        expect(find.text('Harga modal (koreksi)'), findsOneWidget);
        expect(find.text('4000'), findsOneWidget);

        // Existing sellPrice (5000) vs. HPP (4000): 1000/5000 = 20%.
        expect(find.text('Untung per unit: Rp 1.000'), findsOneWidget);
        expect(find.text('Margin: 20%'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('product_form_price')), '10000');
        await tester.pump();

        // 10000 - 4000 = 6000; 6000/10000 = 60%.
        expect(find.text('Untung per unit: Rp 6.000'), findsOneWidget);
        expect(find.text('Margin: 60%'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'edit flow: changing the harga modal (koreksi) field and saving updates averageCostPrice '
    'and writes a CostPriceAdjustment audit row, without creating any StockMutation',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 5000,
          unit: 'pcs',
          averageCostPrice: 4000,
        );

        await pumpForm(tester, existing: product);

        await tester.enterText(find.byKey(const Key('product_form_cost_price')), '4500');
        await tapSubmit(tester);

        final updated = await productRepository.getById(product.id);
        expect(updated!.averageCostPrice, 4500);

        final adjustments =
            await CostPriceAdjustmentRepository(isar).getHistoryForProduct(product.id);
        expect(adjustments, hasLength(1));
        expect(adjustments.first.oldCost, 4000);
        expect(adjustments.first.newCost, 4500);

        final mutations = await StockMutationRepository(isar).getHistoryForProduct(product.id);
        expect(mutations, isEmpty);
      });
    },
  );

  testWidgets(
    'edit flow: saving without changing the harga modal (koreksi) field writes no '
    'CostPriceAdjustment row',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 5000,
          unit: 'pcs',
          averageCostPrice: 4000,
        );

        await pumpForm(tester, existing: product);

        await tester.enterText(find.byKey(const Key('product_form_name')), 'Chips XL');
        await tapSubmit(tester);

        final updated = await productRepository.getById(product.id);
        expect(updated!.averageCostPrice, 4000);

        final adjustments =
            await CostPriceAdjustmentRepository(isar).getHistoryForProduct(product.id);
        expect(adjustments, isEmpty);
      });
    },
  );

  testWidgets(
    'edit flow: with no averageCostPrice yet, read-only HPP shows a placeholder and no '
    'margin preview is shown',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 5000,
          unit: 'pcs',
        );

        await pumpForm(tester, existing: product);

        expect(find.textContaining('HPP saat ini: belum ada data harga modal'), findsOneWidget);
        expect(find.byKey(const Key('product_form_margin_panel')), findsNothing);
      });
    },
  );

  testWidgets('add flow: leaving "Isi per pack" blank creates a pcs-only product', (tester) async {
    await tester.runAsync(() async {
      await pumpForm(tester);

      await tester.enterText(find.byKey(const Key('product_form_name')), 'Chips');
      await tester.enterText(find.byKey(const Key('product_form_price')), '5000');
      await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');

      await tapSubmit(tester);

      final products = await productRepository.getAll();
      expect(products.first.unitsPerPack, isNull);
    });
  });

  testWidgets('add flow: a valid "Isi per pack" is saved on the product', (tester) async {
    await tester.runAsync(() async {
      await pumpForm(tester);

      await tester.enterText(find.byKey(const Key('product_form_name')), 'Indomie');
      await tester.enterText(find.byKey(const Key('product_form_price')), '3000');
      await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');
      await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '12');

      await tapSubmit(tester);

      final products = await productRepository.getAll();
      expect(products.first.unitsPerPack, 12);
    });
  });

  for (final invalid in ['0', '1', '-1', 'abc']) {
    testWidgets(
      'add flow: "Isi per pack" of "$invalid" shows an inline error and does not submit',
      (tester) async {
        await tester.runAsync(() async {
          await pumpForm(tester);

          await tester.enterText(find.byKey(const Key('product_form_name')), 'Indomie');
          await tester.enterText(find.byKey(const Key('product_form_price')), '3000');
          await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');
          await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), invalid);

          await tapSubmit(tester);

          expect(
            find.text('Isi per pack harus angka bulat >= 2 (kosongkan jika hanya per pcs)'),
            findsOneWidget,
          );
          expect(await productRepository.getAll(), isEmpty);
        });
      },
    );
  }

  testWidgets('edit flow: "Isi per pack" is pre-filled from the existing product', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        unitsPerPack: 12,
      );

      await pumpForm(tester, existing: product);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('product_form_units_per_pack')))
            .controller!
            .text,
        '12',
      );
    });
  });

  testWidgets('edit flow: clearing "Isi per pack" saves the product back to pcs-only', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        unitsPerPack: 12,
      );

      await pumpForm(tester, existing: product);

      await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '');
      await tapSubmit(tester);

      final updated = await productRepository.getById(product.id);
      expect(updated!.unitsPerPack, isNull);
    });
  });

  testWidgets(
    'add flow: "Isi per dus" can be filled without "Isi per pack" (a dus that skips the pack '
    'tier — e.g. "1 dus = 12 pcs" directly)',
    (tester) async {
      await tester.runAsync(() async {
        await categoryRepository.create('Snacks');
        await pumpForm(tester);
        await tester.enterText(find.byKey(const Key('product_form_name')), 'Teh Kotak');
        await selectCategory(tester, 'Snacks');
        await tester.enterText(find.byKey(const Key('product_form_price')), '3000');
        await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');
        await tester.enterText(find.byKey(const Key('product_form_units_per_dus')), '12');

        await tapSubmit(tester);

        final products = await productRepository.getAll();
        expect(products.first.unitsPerPack, isNull);
        expect(products.first.unitsPerDus, 12);
      });
    },
  );

  testWidgets('add flow: a valid "Isi per pack" + "Isi per dus" is saved on the product',
      (tester) async {
    await tester.runAsync(() async {
      await categoryRepository.create('Snacks');
      await pumpForm(tester);
      await tester.enterText(find.byKey(const Key('product_form_name')), 'Indomie');
      await selectCategory(tester, 'Snacks');
      await tester.enterText(find.byKey(const Key('product_form_price')), '3000');
      await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');
      await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '12');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('product_form_units_per_dus')), '6');

      await tapSubmit(tester);

      final products = await productRepository.getAll();
      expect(products.first.unitsPerPack, 12);
      expect(products.first.unitsPerDus, 6);
    });
  });

  for (final invalid in ['0', '1', '-1', 'abc']) {
    testWidgets(
      'add flow: "Isi per dus" of "$invalid" shows an inline error and does not submit',
      (tester) async {
        await tester.runAsync(() async {
          await pumpForm(tester);
          await tester.enterText(find.byKey(const Key('product_form_name')), 'Indomie');
          await tester.enterText(find.byKey(const Key('product_form_price')), '3000');
          await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');
          await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '12');
          await tester.pump();
          await tester.enterText(find.byKey(const Key('product_form_units_per_dus')), invalid);

          await tapSubmit(tester);

          expect(find.text('Isi per dus harus angka bulat >= 2'), findsOneWidget);
          expect(await productRepository.getAll(), isEmpty);
        });
      },
    );
  }

  testWidgets('edit flow: "Isi per dus" is pre-filled from the existing product', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        unitsPerPack: 12,
        unitsPerDus: 6,
      );
      await pumpForm(tester, existing: product);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('product_form_units_per_dus')))
            .controller!
            .text,
        '6',
      );
    });
  });

  testWidgets('edit flow: clearing "Isi per dus" saves it back to null, leaving "Isi per pack" intact',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        unitsPerPack: 12,
        unitsPerDus: 6,
      );
      await pumpForm(tester, existing: product);

      await tester.enterText(find.byKey(const Key('product_form_units_per_dus')), '');
      await tapSubmit(tester);

      final updated = await productRepository.getById(product.id);
      expect(updated!.unitsPerPack, 12);
      expect(updated.unitsPerDus, isNull);
    });
  });

  group('Ringkasan kemasan summary box', () {
    testWidgets('no pack/dus filled shows no summary box', (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        expect(find.byKey(const Key('product_form_kemasan_summary')), findsNothing);
      });
    });

    testWidgets('pack=6 shows "1 pack = 6 pcs"', (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '6');
        await tester.pump();

        expect(find.byKey(const Key('product_form_kemasan_summary')), findsOneWidget);
        expect(find.text('1 pack = 6 pcs'), findsOneWidget);
      });
    });

    testWidgets('pack=6, dus=6 shows both lines', (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '6');
        await tester.enterText(find.byKey(const Key('product_form_units_per_dus')), '6');
        await tester.pump();

        expect(find.text('1 pack = 6 pcs'), findsOneWidget);
        expect(find.text('1 dus = 6 pack = 36 pcs'), findsOneWidget);
      });
    });

    testWidgets(
      'clearing pack removes the pack line but preserves a dus-without-pack value (no cascade '
      'clear, since dus can stand alone)',
      (tester) async {
        await tester.runAsync(() async {
          await pumpForm(tester);

          await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '6');
          await tester.enterText(find.byKey(const Key('product_form_units_per_dus')), '6');
          await tester.pump();
          expect(find.text('1 dus = 6 pack = 36 pcs'), findsOneWidget);

          await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '');
          await tester.pump();

          expect(find.text('1 pack = 6 pcs'), findsNothing);
          // Dus value is untouched — now shown relative to pcs directly.
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('product_form_units_per_dus')))
                .controller!
                .text,
            '6',
          );
          expect(find.text('1 dus = 6 pcs'), findsOneWidget);
        });
      },
    );

    testWidgets('edit mode, pack=6, dus=6, stock=36 shows the stock conversion in the summary box',
        (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Indomie',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
          unitsPerPack: 6,
          unitsPerDus: 6,
          initialStock: 36,
        );
        await pumpForm(tester, existing: product);

        expect(find.text('Stok saat ini: 36 pcs'), findsOneWidget);
        expect(find.text('= 6 pack = 1 dus'), findsOneWidget);
      });
    });
  });

  group('min-stock pack/dus caption', () {
    testWidgets('pack=6, minStock=36 (dus=6) shows "≈ 6 pack, 1 dus"', (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '6');
        await tester.enterText(find.byKey(const Key('product_form_units_per_dus')), '6');
        await tester.enterText(find.byKey(const Key('product_form_min_stock')), '36');
        await tester.pump();

        expect(find.byKey(const Key('product_form_min_stock_conversion')), findsOneWidget);
        expect(find.text('≈ 6 pack, 1 dus'), findsOneWidget);
      });
    });

    testWidgets('pack=6, minStock=15 shows no caption', (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '6');
        await tester.enterText(find.byKey(const Key('product_form_min_stock')), '15');
        await tester.pump();

        expect(find.byKey(const Key('product_form_min_stock_conversion')), findsNothing);
      });
    });

    testWidgets('no pack set shows no caption regardless of minStock value', (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_min_stock')), '36');
        await tester.pump();

        expect(find.byKey(const Key('product_form_min_stock_conversion')), findsNothing);
      });
    });

    testWidgets('typing pack=6 after minStock=36 was already entered shows the caption live',
        (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_min_stock')), '36');
        await tester.pump();
        expect(find.byKey(const Key('product_form_min_stock_conversion')), findsNothing);

        await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '6');
        await tester.pump();

        expect(find.text('≈ 6 pack'), findsOneWidget);
      });
    });

    testWidgets('minStock=0, pack=6 shows "≈ 0 pack"', (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_units_per_pack')), '6');
        await tester.enterText(find.byKey(const Key('product_form_min_stock')), '0');
        await tester.pump();

        expect(find.text('≈ 0 pack'), findsOneWidget);
      });
    });
  });

  group('allowsFractionalQuantity', () {
    testWidgets('defaults to off for a new product', (tester) async {
      await tester.runAsync(() async {
        await pumpForm(tester);

        final switchTile = tester.widget<SwitchListTile>(
          find.byKey(const Key('product_form_allows_fractional_quantity')),
        );
        expect(switchTile.value, isFalse);
      });
    });

    testWidgets('toggling it on and submitting persists true', (tester) async {
      await tester.runAsync(() async {
        await categoryRepository.create('Sembako');
        await pumpForm(tester);
        await tester.enterText(find.byKey(const Key('product_form_name')), 'Beras');
        await selectCategory(tester, 'Sembako');
        await tester.enterText(find.byKey(const Key('product_form_price')), '15000');
        await tester.enterText(find.byKey(const Key('product_form_unit')), 'kg');

        await tester.tap(find.byKey(const Key('product_form_allows_fractional_quantity')));
        await tester.pump();

        await tapSubmit(tester);

        final products = await productRepository.getAll();
        expect(products.first.allowsFractionalQuantity, isTrue);
      });
    });

    testWidgets('edit flow: pre-fills from the existing product', (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Sembako');
        final product = await productRepository.create(
          name: 'Beras',
          categoryId: category.id,
          sellPrice: 15000,
          unit: 'kg',
          allowsFractionalQuantity: true,
        );
        await pumpForm(tester, existing: product);

        final switchTile = tester.widget<SwitchListTile>(
          find.byKey(const Key('product_form_allows_fractional_quantity')),
        );
        expect(switchTile.value, isTrue);
      });
    });
  });

  // Regression coverage matching the Mutasi form fix (see
  // catat_mutasi_lifecycle_test.dart): _submit() previously had no guard
  // against re-entrant calls before the disabled-button rebuild lands,
  // so a rapid double-tap could create the product twice / pop the
  // route twice.
  testWidgets('rapid double-tap on submit creates exactly one product, no exception', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        await categoryRepository.create('Snacks');
        await pumpForm(tester);

        await tester.enterText(find.byKey(const Key('product_form_name')), 'Chips');
        await selectCategory(tester, 'Snacks');
        await tester.enterText(find.byKey(const Key('product_form_price')), '5000');
        await tester.enterText(find.byKey(const Key('product_form_unit')), 'pcs');

        final submitFinder = find.byKey(const Key('product_form_submit'));
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.tap(submitFinder);
        await tester.pump();
        await tester.tap(submitFinder);
        await settleAfterAsyncWork(tester);

        final all = await productRepository.getAll();
        expect(all.where((p) => p.name == 'Chips'), hasLength(1));
      });
    });
  });
}
