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
}
