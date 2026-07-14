import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/mutasi/mutasi_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository stockMutationRepository;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    stockMutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      stockMutationRepository,
      AppSettingsRepository(isar),
    );
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // Matches MyApp's real locale config (see main.dart) — without it,
    // the date range picker falls back to English/US formatting, and
    // the tests wouldn't be exercising the same behavior real users see.
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')],
      home: MutasiScreen(isar: isar),
    ));
    await settleAfterAsyncWork(tester);
  }

  // recordMutation always stamps `createdAt` with the real current time,
  // so tests needing an old mutation (day-grouping, date-range filters)
  // insert directly instead, mirroring the approach used for
  // getTotalsSince's repository test.
  Future<StockMutation> insertMutationAt({
    required int productId,
    required StockMutationType type,
    required double quantity,
    required DateTime createdAt,
    String? note,
  }) async {
    final mutation = StockMutation()
      ..productId = productId
      ..type = type
      ..quantity = quantity
      ..note = note
      ..stockAfter = 0
      ..createdAt = createdAt;
    await isar.writeTxn(() async {
      await isar.stockMutations.put(mutation);
    });
    return mutation;
  }

  testWidgets('shows empty state when there is no mutation history', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.text('Belum ada riwayat mutasi stok.'), findsOneWidget);
    });
  });

  testWidgets('shows the summary card with correct rolling-7-day totals', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 10,
      );
      await stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 3,
      );

      await pumpScreen(tester);

      expect(find.byKey(const Key('mutasi_summary_in')), findsOneWidget);
      expect(find.byKey(const Key('mutasi_summary_out')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('mutasi_summary_in')),
          matching: find.text('10'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('mutasi_summary_out')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('shows history list items with correct in/out visual distinction', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 10,
      );
      await stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 3,
      );

      await pumpScreen(tester);

      expect(find.text('+10 pcs'), findsOneWidget);
      expect(find.text('-3 pcs'), findsOneWidget);

      final inIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward).first);
      expect(inIcon.color, Colors.green[700]);
      final outIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_downward).first);
      expect(outIcon.color, Colors.red[700]);
    });
  });

  testWidgets('tapping Catat navigates to Catat Mutasi in search mode', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Catat'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Catat Mutasi'), findsOneWidget);
      expect(find.byKey(const Key('catat_mutasi_search')), findsOneWidget);
    });
  });

  testWidgets(
    'recording a mutation elsewhere (direct repository call) auto-refreshes without any manual trigger',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
        );

        await pumpScreen(tester);
        expect(find.text('Belum ada riwayat mutasi stok.'), findsOneWidget);

        // Simulates a mutation recorded from a different, separately
        // mounted screen (e.g. Product Detail's Stok masuk button) while
        // this Mutasi tab stays alive in MainScaffold's IndexedStack —
        // exactly the case the watchLazy() subscription is meant to fix.
        await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 7,
        );

        await settleAfterAsyncWork(tester);

        expect(find.text('Belum ada riwayat mutasi stok.'), findsNothing);
        expect(find.text('+7 pcs'), findsOneWidget);
      });
    },
  );

  testWidgets('history list renders with day-group headers separating different days', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Chips',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
      );

      final now = DateTime.now();
      await insertMutationAt(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 5,
        createdAt: now,
      );
      await insertMutationAt(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 3,
        createdAt: now.subtract(const Duration(days: 1)),
      );

      await pumpScreen(tester);

      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Kemarin'), findsOneWidget);
    });
  });

  testWidgets(
    'typing in the search field filters the list live to matching product name or note',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final chips = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
        );
        final soda = await productRepository.create(
          name: 'Soda',
          categoryId: category.id,
          sellPrice: 2000,
          unit: 'botol',
        );
        await stockMutationRepository.recordMutation(
          productId: chips.id,
          type: StockMutationType.stockIn,
          quantity: 5,
        );
        await stockMutationRepository.recordMutation(
          productId: soda.id,
          type: StockMutationType.stockIn,
          quantity: 2,
          note: 'dari supplier A',
        );

        await pumpScreen(tester);
        expect(find.text('+5 pcs'), findsOneWidget);
        expect(find.text('+2 botol'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('mutasi_search')), 'chips');
        await settleAfterAsyncWork(tester);

        expect(find.text('+5 pcs'), findsOneWidget);
        expect(find.text('+2 botol'), findsNothing);

        // Search by note instead.
        await tester.enterText(find.byKey(const Key('mutasi_search')), 'supplier a');
        await settleAfterAsyncWork(tester);

        expect(find.text('+2 botol'), findsOneWidget);
        expect(find.text('+5 pcs'), findsNothing);
      });
    },
  );

  testWidgets(
    'search with no matches shows "Tidak ditemukan" distinct from the no-history empty state',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
          initialStock: 5,
        );

        await pumpScreen(tester);

        await tester.enterText(find.byKey(const Key('mutasi_search')), 'nonexistent product');
        await settleAfterAsyncWork(tester);

        expect(find.text('Tidak ditemukan.'), findsOneWidget);
        expect(find.text('Belum ada riwayat mutasi stok.'), findsNothing);
      });
    },
  );

  testWidgets(
    'selecting a real date range via the calendar filters the list, and clearing it restores the full list',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
        );

        final now = DateTime.now();
        await insertMutationAt(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 5,
          createdAt: now,
        );
        await insertMutationAt(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 9,
          createdAt: now.subtract(const Duration(days: 10)),
        );

        await pumpScreen(tester);
        expect(find.text('+5 pcs'), findsOneWidget);
        expect(find.text('+9 pcs'), findsOneWidget);

        await tester.tap(find.byKey(const Key('mutasi_date_range_button')));
        await tester.pumpAndSettle();

        // Calendar mode is the default entry mode (the keyboard/text
        // input toggle is also available — see the separate manual-input
        // test below — but this test exercises tapping day cells
        // directly). Tapping today's cell twice selects a valid 1-day
        // range (start == end == today) without needing a second
        // distinct day — sidesteps having to handle "today is the 1st of
        // the month" (yesterday would be on a different, not-currently-
        // displayed calendar page).
        final todayCell = find
            .descendant(of: find.byType(Dialog), matching: find.text('${now.day}'))
            .first;
        await tester.tap(todayCell);
        await tester.pumpAndSettle();
        await tester.tap(todayCell);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simpan'));
        await settleAfterAsyncWork(tester);

        expect(find.byKey(const Key('mutasi_date_range_chip')), findsOneWidget);
        expect(find.text('+5 pcs'), findsOneWidget);
        expect(find.text('+9 pcs'), findsNothing);

        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('mutasi_date_range_chip')),
            matching: find.byIcon(Icons.clear),
          ),
        );
        await settleAfterAsyncWork(tester);

        expect(find.byKey(const Key('mutasi_date_range_chip')), findsNothing);
        expect(find.text('+5 pcs'), findsOneWidget);
        expect(find.text('+9 pcs'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'typing digits into the manual date fields auto-formats them with "/" as DD/MM/YYYY',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
        );
        await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 5,
        );

        await pumpScreen(tester);

        await tester.enterText(find.byKey(const Key('mutasi_date_start_field')), '01012026');
        await tester.pumpAndSettle();

        expect(find.text('01/01/2026'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'typing a nonexistent calendar date (30 Feb) shows a validation error, and it clears once corrected',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
        );
        await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 5,
        );

        await pumpScreen(tester);

        // February never has a 30th, in a leap year or otherwise.
        await tester.enterText(find.byKey(const Key('mutasi_date_start_field')), '30022026');
        await tester.pumpAndSettle();
        expect(find.text('Tanggal tidak valid.'), findsOneWidget);

        // 32 is never a valid day in any month either.
        await tester.enterText(find.byKey(const Key('mutasi_date_end_field')), '32012026');
        await tester.pumpAndSettle();
        expect(find.text('Tanggal tidak valid.'), findsNWidgets(2));

        // Correcting to a real date (29 Feb on a leap year) clears the error.
        await tester.enterText(find.byKey(const Key('mutasi_date_start_field')), '29022024');
        await tester.pumpAndSettle();
        expect(find.text('Tanggal tidak valid.'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'applying the filter with an empty date field shows "Wajib diisi" and does not filter',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
        );
        await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 5,
        );

        await pumpScreen(tester);
        expect(find.text('+5 pcs'), findsOneWidget);

        await tester.tap(find.byKey(const Key('mutasi_date_apply_button')));
        await tester.pumpAndSettle();

        expect(find.text('Wajib diisi'), findsNWidgets(2));
        expect(find.byKey(const Key('mutasi_date_range_chip')), findsNothing);
        expect(find.text('+5 pcs'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'only the most recent mutation for a product shows a "Batalkan" action, and cancelling it records a compensating entry',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
          initialStock: 10,
        );
        await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 3,
        );
        final latest = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockIn,
          quantity: 2,
        );

        await pumpScreen(tester);

        // Only one "Batalkan" (undo) icon button exists across the whole
        // history — the older stockOut mutation is not the most recent
        // for this product, so it must not show the action.
        expect(find.byIcon(Icons.undo), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${latest.id}')), findsOneWidget);

        await tester.tap(find.byKey(Key('mutation_cancel_${latest.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Batalkan').last);
        await settleAfterAsyncWork(tester);

        expect(find.text('Mutasi dibatalkan'), findsOneWidget);

        final history = await stockMutationRepository.getHistoryForProduct(product.id);
        expect(
          history.any(
            (m) => m.type == StockMutationType.stockOut && (m.note ?? '').startsWith('Dibatalkan'),
          ),
          isTrue,
        );
      });
    },
  );

  testWidgets(
    'with 3 mutations for the same product, only the newest shows a cancel button — the other two show none at all',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
          initialStock: 20,
        );

        final m1 = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 1,
        );
        final m2 = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 1,
        );
        final m3 = await stockMutationRepository.recordMutation(
          productId: product.id,
          type: StockMutationType.stockOut,
          quantity: 1,
        );

        await pumpScreen(tester);

        expect(find.byIcon(Icons.undo), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${m3.id}')), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${m2.id}')), findsNothing);
        expect(find.byKey(Key('mutation_cancel_${m1.id}')), findsNothing);
      });
    },
  );

  testWidgets(
    'with multiple products each having their own history, each product shows its own cancel button only on its own newest row',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final chips = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
          initialStock: 20,
        );
        final soda = await productRepository.create(
          name: 'Soda',
          categoryId: category.id,
          sellPrice: 2000,
          unit: 'botol',
          initialStock: 20,
        );

        // Each product gets its own 3-mutation history, interleaved in
        // time, so a naive "last mutation in the whole ledger" check
        // (instead of a per-product one) would wrongly single out just
        // one row across both products.
        await stockMutationRepository.recordMutation(
            productId: chips.id, type: StockMutationType.stockOut, quantity: 1);
        await stockMutationRepository.recordMutation(
            productId: soda.id, type: StockMutationType.stockOut, quantity: 1);
        await stockMutationRepository.recordMutation(
            productId: chips.id, type: StockMutationType.stockOut, quantity: 1);
        final sodaMiddle = await stockMutationRepository.recordMutation(
            productId: soda.id, type: StockMutationType.stockOut, quantity: 1);
        final chipsNewest = await stockMutationRepository.recordMutation(
            productId: chips.id, type: StockMutationType.stockOut, quantity: 1);
        final sodaNewest = await stockMutationRepository.recordMutation(
            productId: soda.id, type: StockMutationType.stockOut, quantity: 1);

        await pumpScreen(tester);

        // Exactly one cancel button per product — not one for the whole
        // list, and not one for every row.
        expect(find.byIcon(Icons.undo), findsNWidgets(2));
        expect(find.byKey(Key('mutation_cancel_${chipsNewest.id}')), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${sodaNewest.id}')), findsOneWidget);
        expect(find.byKey(Key('mutation_cancel_${sodaMiddle.id}')), findsNothing);
      });
    },
  );

  group('filterMutations (pure logic)', () {
    late Product chips;
    late Product soda;

    setUp(() {
      final now = DateTime.now();
      chips = Product()
        ..id = 1
        ..name = 'Chips'
        ..categoryId = 1
        ..sellPrice = 1000
        ..unit = 'pcs'
        ..currentStock = 0
        ..minStockThreshold = 5
        ..createdAt = now
        ..updatedAt = now;
      soda = Product()
        ..id = 2
        ..name = 'Soda'
        ..categoryId = 1
        ..sellPrice = 2000
        ..unit = 'botol'
        ..currentStock = 0
        ..minStockThreshold = 5
        ..createdAt = now
        ..updatedAt = now;
    });

    StockMutation mutation({
      required int productId,
      required DateTime createdAt,
      String? note,
      double quantity = 1,
    }) {
      return StockMutation()
        ..productId = productId
        ..type = StockMutationType.stockIn
        ..quantity = quantity
        ..note = note
        ..stockAfter = 0
        ..createdAt = createdAt;
    }

    test('date range excludes mutations outside it, includes boundary days', () {
      final day1 = DateTime(2026, 1, 1, 10);
      final day2 = DateTime(2026, 1, 5, 10);
      final day3 = DateTime(2026, 1, 10, 10);
      final mutations = [
        mutation(productId: chips.id, createdAt: day1),
        mutation(productId: chips.id, createdAt: day2),
        mutation(productId: chips.id, createdAt: day3),
      ];

      final result = filterMutations(
        mutations: mutations,
        productById: {chips.id: chips},
        range: DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)),
      );

      expect(result, hasLength(2));
      expect(result, containsAll([mutations[0], mutations[1]]));
    });

    test('search matches product name case-insensitively', () {
      final mutations = [
        mutation(productId: chips.id, createdAt: DateTime.now()),
        mutation(productId: soda.id, createdAt: DateTime.now()),
      ];

      final result = filterMutations(
        mutations: mutations,
        productById: {chips.id: chips, soda.id: soda},
        searchQuery: 'CHIPS',
      );

      expect(result, [mutations[0]]);
    });

    test('search matches note case-insensitively', () {
      final mutations = [
        mutation(productId: chips.id, createdAt: DateTime.now(), note: 'dari supplier A'),
        mutation(productId: soda.id, createdAt: DateTime.now(), note: 'terjual'),
      ];

      final result = filterMutations(
        mutations: mutations,
        productById: {chips.id: chips, soda.id: soda},
        searchQuery: 'supplier',
      );

      expect(result, [mutations[0]]);
    });

    test('date range and search combine (both constraints apply)', () {
      final inRangeMatch = mutation(productId: chips.id, createdAt: DateTime(2026, 1, 3));
      final inRangeNoMatch = mutation(productId: soda.id, createdAt: DateTime(2026, 1, 3));
      final outOfRangeMatch = mutation(productId: chips.id, createdAt: DateTime(2026, 2, 1));
      final mutations = [inRangeMatch, inRangeNoMatch, outOfRangeMatch];

      final result = filterMutations(
        mutations: mutations,
        productById: {chips.id: chips, soda.id: soda},
        range: DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 10)),
        searchQuery: 'chips',
      );

      expect(result, [inRangeMatch]);
    });

    test('combination matching nothing returns an empty list', () {
      final mutations = [mutation(productId: chips.id, createdAt: DateTime.now())];

      final result = filterMutations(
        mutations: mutations,
        productById: {chips.id: chips},
        searchQuery: 'does not exist',
      );

      expect(result, isEmpty);
    });

    test('a null range (cleared filter) returns the full list', () {
      final mutations = [
        mutation(productId: chips.id, createdAt: DateTime(2020, 1, 1)),
        mutation(productId: chips.id, createdAt: DateTime.now()),
      ];

      final result = filterMutations(mutations: mutations, productById: {chips.id: chips});

      expect(result, hasLength(2));
    });
  });
}
