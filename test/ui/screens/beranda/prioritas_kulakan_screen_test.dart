import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/restock_list_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/velocity_calculator.dart';
import 'package:inventaris_toko/ui/screens/beranda/kulakan_list_screen.dart';
import 'package:inventaris_toko/ui/screens/beranda/prioritas_kulakan_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository stockMutationRepository;
  late RestockListRepository restockListRepository;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    stockMutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      stockMutationRepository,
      AppSettingsRepository(isar),
    );
    restockListRepository = RestockListRepository(isar);
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')],
      home: PrioritasKulakanScreen(isar: isar),
    ));
    await settleAfterAsyncWork(tester);
  }

  /// [recordMutation] always stamps `DateTime.now()`, so this records
  /// [mutationCount] mutations and then backdates them directly, all to
  /// the same date [_backdateDays] days ago — comfortably inside
  /// [VelocityCalculator.recentWindowDays] (so the mutations are never at
  /// risk of falling just outside the recent window due to the real
  /// wall-clock time elapsing between seeding and the screen's own
  /// `DateTime.now()` call in [_load]). With every mutation on the same
  /// day, `dailyVelocity` is a clean, precomputable blend of the recent
  /// and all-time components (mirroring [VelocityCalculator]'s exact
  /// formula), so choosing [initialStock] so post-mutation currentStock
  /// equals `targetDays * dailyVelocity` still gives a predictable
  /// estimatedDaysRemaining of exactly [targetDays].
  Future<Product> seedEligibleProduct(
    int categoryId,
    String name,
    int targetDays, {
    double stockOutQuantity = 5,
    int? unitsPerPack,
  }) async {
    const mutationCount = 5;
    const backdateDays = 20;
    final totalConsumed = mutationCount * stockOutQuantity;
    final velocity30d = totalConsumed / VelocityCalculator.recentWindowDays;
    final velocityAllTime = totalConsumed / backdateDays;
    final dailyVelocity = velocity30d * VelocityCalculator.recentWeight +
        velocityAllTime * VelocityCalculator.allTimeWeight;
    final targetCurrentStock = targetDays * dailyVelocity;

    final product = await productRepository.create(
      name: name,
      categoryId: categoryId,
      sellPrice: 1000,
      unit: 'pcs',
      initialStock: targetCurrentStock + totalConsumed,
      unitsPerPack: unitsPerPack,
      // The velocity math above produces a fractional currentStock/qty
      // by construction (it's reverse-engineered from a target days
      // estimate, not a real whole-goods scenario) — this fixture isn't
      // exercising the whole-quantity feature, so it opts out of the
      // new default enforcement rather than fighting it.
      allowsFractionalQuantity: true,
    );

    for (var i = 0; i < mutationCount; i++) {
      await stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: stockOutQuantity,
      );
    }

    final mutations = await isar.stockMutations.filter().productIdEqualTo(product.id).findAll();
    final backdated = DateTime.now().subtract(const Duration(days: backdateDays));
    await isar.writeTxn(() async {
      for (final mutation in mutations) {
        mutation.createdAt = backdated;
      }
      await isar.stockMutations.putAll(mutations);
    });

    return product;
  }

  Checkbox checkboxFor(WidgetTester tester, Product product) =>
      tester.widget<Checkbox>(find.byKey(Key('kulakan_checkbox_${product.id}')));

  testWidgets('"Buat Daftar Kulakan" button is visible on the full screen', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      expect(find.byKey(const Key('kulakan_buat_daftar_button')), findsOneWidget);
    });
  });

  testWidgets('page opens with every row unchecked, regardless of urgency', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final red = await seedEligibleProduct(category.id, 'Produk Merah', 1);
      final yellow = await seedEligibleProduct(category.id, 'Produk Kuning', 5);
      final neutral = await seedEligibleProduct(category.id, 'Produk Netral', 10);

      await pumpScreen(tester);

      expect(checkboxFor(tester, red).value, isFalse);
      expect(checkboxFor(tester, yellow).value, isFalse);
      expect(checkboxFor(tester, neutral).value, isFalse);
    });
  });

  testWidgets('every row shows a non-empty, non-zero qty on open', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product = await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      final qtyField =
          tester.widget<TextField>(find.byKey(Key('kulakan_qty_field_${product.id}')));
      final qty = double.tryParse(qtyField.controller!.text);
      expect(qty, isNotNull);
      expect(qty, isNot(0));
    });
  });

  testWidgets('"Buat Daftar Kulakan" is disabled when nothing is checked', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      final button =
          tester.widget<ElevatedButton>(find.byKey(const Key('kulakan_buat_daftar_button')));
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('toggling a checkbox changes its state and updates the footer count',
      (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product = await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      final checkboxKey = Key('kulakan_checkbox_${product.id}');
      expect(tester.widget<Checkbox>(find.byKey(checkboxKey)).value, isFalse);
      expect(find.text('0 barang dipilih'), findsOneWidget);

      await tester.tap(find.byKey(checkboxKey));
      await settleAfterAsyncWork(tester);
      expect(tester.widget<Checkbox>(find.byKey(checkboxKey)).value, isTrue);
      expect(find.text('1 barang dipilih'), findsOneWidget);

      final button =
          tester.widget<ElevatedButton>(find.byKey(const Key('kulakan_buat_daftar_button')));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byKey(checkboxKey));
      await settleAfterAsyncWork(tester);
      expect(tester.widget<Checkbox>(find.byKey(checkboxKey)).value, isFalse);
      expect(find.text('0 barang dipilih'), findsOneWidget);
    });
  });

  testWidgets('editing qty on an unchecked row does not check it', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product = await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      await tester.enterText(find.byKey(Key('kulakan_qty_field_${product.id}')), '99');
      await settleAfterAsyncWork(tester);

      expect(checkboxFor(tester, product).value, isFalse);
      expect(find.text('0 barang dipilih'), findsOneWidget);
    });
  });

  testWidgets('"Centang Semua" checks all rows', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final a = await seedEligibleProduct(category.id, 'Produk A', 1);
      final b = await seedEligibleProduct(category.id, 'Produk B', 10);

      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('prioritas_kulakan_centang_semua_button')));
      await settleAfterAsyncWork(tester);

      expect(checkboxFor(tester, a).value, isTrue);
      expect(checkboxFor(tester, b).value, isTrue);
      expect(find.text('2 barang dipilih'), findsOneWidget);
      expect(find.text('Batal Centang Semua'), findsOneWidget);
    });
  });

  testWidgets('manual qty edit is preserved after "Centang Semua"', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product = await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

      await pumpScreen(tester);

      await tester.enterText(find.byKey(Key('kulakan_qty_field_${product.id}')), '77');
      await settleAfterAsyncWork(tester);

      await tester.tap(find.byKey(const Key('prioritas_kulakan_centang_semua_button')));
      await settleAfterAsyncWork(tester);

      expect(checkboxFor(tester, product).value, isTrue);
      final qtyField =
          tester.widget<TextField>(find.byKey(Key('kulakan_qty_field_${product.id}')));
      expect(qtyField.controller!.text, '77');
    });
  });

  testWidgets(
    'manual qty edit survives uncheck-all then check-all ("Batal Centang Semua" then '
    '"Centang Semua")',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        final product = await seedEligibleProduct(category.id, 'Produk 1 Hari', 1);

        await pumpScreen(tester);

        await tester.enterText(find.byKey(Key('kulakan_qty_field_${product.id}')), '55');
        await settleAfterAsyncWork(tester);

        await tester.tap(find.byKey(const Key('prioritas_kulakan_centang_semua_button')));
        await settleAfterAsyncWork(tester);
        expect(find.text('Batal Centang Semua'), findsOneWidget);

        await tester.tap(find.byKey(const Key('prioritas_kulakan_centang_semua_button')));
        await settleAfterAsyncWork(tester);
        expect(checkboxFor(tester, product).value, isFalse);

        await tester.tap(find.byKey(const Key('prioritas_kulakan_centang_semua_button')));
        await settleAfterAsyncWork(tester);
        expect(checkboxFor(tester, product).value, isTrue);

        final qtyField =
            tester.widget<TextField>(find.byKey(Key('kulakan_qty_field_${product.id}')));
        expect(qtyField.controller!.text, '55');
      });
    },
  );

  testWidgets('"Centang Semua" is disabled on an empty list', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);
      expect(find.byKey(const Key('prioritas_kulakan_empty_state')), findsOneWidget);
      expect(find.byKey(const Key('prioritas_kulakan_centang_semua_button')), findsNothing);
    });
  });

  testWidgets('stepper +/- adjusts qty by 1 pcs for a pcs-only product', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product = await seedEligibleProduct(category.id, 'Produk Pcs', 1);

      await pumpScreen(tester);

      final qtyFieldKey = Key('kulakan_qty_field_${product.id}');
      final before = double.parse(tester.widget<TextField>(find.byKey(qtyFieldKey)).controller!.text);

      await tester.tap(find.byKey(Key('kulakan_qty_stepper_plus_${product.id}')));
      await settleAfterAsyncWork(tester);
      final afterPlus =
          double.parse(tester.widget<TextField>(find.byKey(qtyFieldKey)).controller!.text);
      expect(afterPlus, before + 1);

      await tester.tap(find.byKey(Key('kulakan_qty_stepper_minus_${product.id}')));
      await settleAfterAsyncWork(tester);
      final afterMinus =
          double.parse(tester.widget<TextField>(find.byKey(qtyFieldKey)).controller!.text);
      expect(afterMinus, before);
    });
  });

  testWidgets('stepper +/- adjusts qty by 1 pack when pack unit is active', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Umum');
      final product =
          await seedEligibleProduct(category.id, 'Produk Pack', 1, unitsPerPack: 12);

      await pumpScreen(tester);

      await tester.tap(find.descendant(
        of: find.byKey(Key('kulakan_qty_unit_toggle_${product.id}')),
        matching: find.text('pack'),
      ));
      await settleAfterAsyncWork(tester);

      final qtyFieldKey = Key('kulakan_qty_field_${product.id}');
      final beforePacks =
          double.parse(tester.widget<TextField>(find.byKey(qtyFieldKey)).controller!.text);

      await tester.tap(find.byKey(Key('kulakan_qty_stepper_plus_${product.id}')));
      await settleAfterAsyncWork(tester);
      final afterPacks =
          double.parse(tester.widget<TextField>(find.byKey(qtyFieldKey)).controller!.text);

      expect(afterPacks, beforePacks + 1);
    });
  });

  testWidgets(
    'tapping "Buat Daftar Kulakan" creates a RestockList from checked items and opens '
    'KulakanListScreen',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        final red = await seedEligibleProduct(category.id, 'Produk Merah', 1);
        await seedEligibleProduct(category.id, 'Produk Netral', 10);

        await pumpScreen(tester);
        await tester.tap(find.byKey(Key('kulakan_checkbox_${red.id}')));
        await settleAfterAsyncWork(tester);
        await tester.tap(find.byKey(const Key('kulakan_buat_daftar_button')));
        await settleAfterAsyncWork(tester);

        expect(find.byType(KulakanListScreen), findsOneWidget);

        final lists = await restockListRepository.getActive();
        expect(lists, hasLength(1));
        expect(lists.first.items, hasLength(1));
        expect(lists.first.items.first.productId, red.id);
      });
    },
  );

  testWidgets(
    'tapping "Buat Daftar Kulakan" prefills a checked item\'s qty from lastRestockQty when set',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        final product = await seedEligibleProduct(category.id, 'Produk Merah', 1);
        await productRepository.update(id: product.id, name: product.name);
        await isar.writeTxn(() async {
          final p = (await isar.products.get(product.id))!;
          p.lastRestockQty = 42;
          await isar.products.put(p);
        });

        await pumpScreen(tester);
        await tester.tap(find.byKey(Key('kulakan_checkbox_${product.id}')));
        await settleAfterAsyncWork(tester);
        await tester.tap(find.byKey(const Key('kulakan_buat_daftar_button')));
        await settleAfterAsyncWork(tester);

        final lists = await restockListRepository.getActive();
        expect(lists.first.items.first.qtyInPcs, 42);
      });
    },
  );

  testWidgets(
    'checking 3 items and tapping "Buat Daftar Kulakan" opens KulakanListScreen with exactly '
    'those 3 already checked and their quantities preserved',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        final a = await seedEligibleProduct(category.id, 'Produk A', 1);
        final b = await seedEligibleProduct(category.id, 'Produk B', 1);
        final c = await seedEligibleProduct(category.id, 'Produk C', 1);
        await seedEligibleProduct(category.id, 'Produk Tidak Dipilih', 10);

        await pumpScreen(tester);
        for (final product in [a, b, c]) {
          await tester.tap(find.byKey(Key('kulakan_checkbox_${product.id}')));
          await settleAfterAsyncWork(tester);
        }
        // Edit B's qty before creating the list — the edited value (not
        // just the original prefill) must be what survives onto the new
        // list.
        await tester.enterText(find.byKey(Key('kulakan_qty_field_${b.id}')), '77');
        await settleAfterAsyncWork(tester);

        await tester.tap(find.byKey(const Key('kulakan_buat_daftar_button')));
        await settleAfterAsyncWork(tester);

        expect(find.byType(KulakanListScreen), findsOneWidget);
        for (final product in [a, b, c]) {
          final checkbox =
              tester.widget<Checkbox>(find.byKey(Key('kulakan_list_checkbox_${product.id}')));
          expect(checkbox.value, isTrue, reason: '${product.name} must arrive already checked');
        }
        expect(find.byKey(Key('kulakan_list_checkbox_${a.id}')), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byKey(Key('kulakan_qty_field_${b.id}'))).controller!.text,
          '77',
        );
      });
    },
  );

  testWidgets(
    'navigating back from KulakanListScreen leaves the Prioritas checklist state untouched',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Umum');
        final checked = await seedEligibleProduct(category.id, 'Produk Dicentang', 1);
        final unchecked = await seedEligibleProduct(category.id, 'Produk Tidak Dicentang', 10);

        await pumpScreen(tester);
        await tester.tap(find.byKey(Key('kulakan_checkbox_${checked.id}')));
        await settleAfterAsyncWork(tester);
        await tester.tap(find.byKey(const Key('kulakan_buat_daftar_button')));
        await settleAfterAsyncWork(tester);
        expect(find.byType(KulakanListScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await settleAfterAsyncWork(tester);

        expect(find.byType(KulakanListScreen), findsNothing);
        expect(checkboxFor(tester, checked).value, isTrue);
        expect(checkboxFor(tester, unchecked).value, isFalse);
      });
    },
  );
}
