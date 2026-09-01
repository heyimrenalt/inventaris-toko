import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/mutasi/mutasi_screen.dart';
import 'package:inventaris_toko/ui/screens/mutasi/product_mutation_history_screen.dart';
import 'package:inventaris_toko/ui/widgets/date_range_filter.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

/// The date filters' lower bound comes from the data, not from an
/// invented offset: `firstDate` is the earliest mutation in the ledger,
/// falling back to today when there is none. These tests pin the two
/// things that used to be wrong — a real date older than the old
/// hardcoded floor being rejected, and the floor being a guess at all.
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

  tearDown(() async => closeTestIsar(isar));

  Widget wrap(Widget home) => MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id')],
        home: home,
      );

  // recordMutation always stamps `createdAt` with the real current time,
  // so a mutation from years ago has to be inserted directly.
  Future<StockMutation> insertMutationAt({
    required int productId,
    required DateTime createdAt,
  }) async {
    final mutation = StockMutation()
      ..productId = productId
      ..type = StockMutationType.stockIn
      ..quantity = 1
      ..stockAfter = 1
      ..createdAt = createdAt;
    await isar.writeTxn(() => isar.stockMutations.put(mutation));
    return mutation;
  }

  String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  DateRangeFilterBar filterBar(WidgetTester tester) =>
      tester.widget<DateRangeFilterBar>(find.byType(DateRangeFilterBar));

  /// The three-years-ago anchor, kept away from month/day edges so no
  /// leap-day or month-length special case creeps into the assertion.
  DateTime threeYearsAgo() {
    final now = DateTime.now();
    return DateTime(now.year - 3, 6, 15, 10);
  }

  group('Mutasi tab', () {
    testWidgets('takes its firstDate from the earliest mutation, not an offset',
        (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          unit: 'pcs',
          sellPrice: 5000,
        );
        final oldest = threeYearsAgo();
        await insertMutationAt(productId: product.id, createdAt: oldest);
        await insertMutationAt(productId: product.id, createdAt: DateTime.now());

        await tester.pumpWidget(wrap(MutasiScreen(isar: isar)));
        await settleAfterAsyncWork(tester);

        expect(filterBar(tester).firstDate, oldest);
      });
    });

    testWidgets(
        'accepts a date three years back — the old now.year-2 floor rejected it',
        (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          unit: 'pcs',
          sellPrice: 5000,
        );
        final oldest = threeYearsAgo();
        await insertMutationAt(productId: product.id, createdAt: oldest);

        await tester.pumpWidget(wrap(MutasiScreen(isar: isar)));
        await settleAfterAsyncWork(tester);

        // Sanity: this date really is outside the bound the screen used
        // to invent, so the test would have failed before the change.
        expect(oldest.year, lessThan(DateTime.now().year - 2));

        await tester.enterText(
          find.byKey(const Key('mutasi_date_start_field')),
          formatDate(oldest),
        );
        await tester.enterText(
          find.byKey(const Key('mutasi_date_end_field')),
          formatDate(DateTime.now()),
        );
        await tester.pumpAndSettle();

        expect(find.text(kTooEarlyDateError), findsNothing);
        expect(find.text(kInvalidDateError), findsNothing);

        await tester.tap(find.byKey(const Key('mutasi_date_apply_button')));
        await settleAfterAsyncWork(tester);

        // The range applied: the chip only renders once onChanged fired
        // with a real DateTimeRange.
        expect(find.byKey(const Key('mutasi_date_range_chip')), findsOneWidget);
        expect(filterBar(tester).selectedRange!.start, DateTime(oldest.year, 6, 15));
      });
    });
  });

  group('Riwayat per produk', () {
    testWidgets('takes its firstDate from the earliest mutation in the ledger',
        (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        final product = await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          unit: 'pcs',
          sellPrice: 5000,
        );
        final oldest = threeYearsAgo();
        await insertMutationAt(productId: product.id, createdAt: oldest);

        await tester.pumpWidget(
          wrap(ProductMutationHistoryScreen(isar: isar, product: product)),
        );
        await settleAfterAsyncWork(tester);

        expect(filterBar(tester).firstDate, oldest);
      });
    });
  });

  group('empty ledger fallback', () {
    testWidgets('no mutations leaves the screens on their empty state, bound unused',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(wrap(MutasiScreen(isar: isar)));
        await settleAfterAsyncWork(tester);

        // The filter bar isn't built at all with an empty ledger, so the
        // firstDate == lastDate == today case can't be reached through
        // this screen — the widget-level test below covers it directly.
        expect(find.byType(DateRangeFilterBar), findsNothing);
        expect(find.text('Belum ada riwayat mutasi stok.'), findsOneWidget);
      });
    });

    testWidgets('firstDate == lastDate == today raises no range error and applies',
        (tester) async {
      final now = DateTime.now();
      DateTimeRange? applied;

      await tester.pumpWidget(wrap(Scaffold(
        body: DateRangeFilterBar(
          selectedRange: null,
          firstDate: now,
          lastDate: now,
          onChanged: (range) => applied = range,
        ),
      )));

      await tester.enterText(
        find.byKey(const Key('mutasi_date_start_field')),
        formatDate(now),
      );
      await tester.enterText(
        find.byKey(const Key('mutasi_date_end_field')),
        formatDate(now),
      );
      await tester.pumpAndSettle();

      expect(find.text(kTooEarlyDateError), findsNothing);
      expect(find.text(kFutureDateError), findsNothing);
      expect(find.text(kInvalidDateError), findsNothing);

      await tester.tap(find.byKey(const Key('mutasi_date_apply_button')));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.start, DateTime(now.year, now.month, now.day));
      expect(applied!.end, applied!.start);
    });

    testWidgets('the calendar still opens sanely on today with a same-day bound',
        (tester) async {
      final now = DateTime.now();

      await tester.pumpWidget(wrap(Scaffold(
        body: DateRangeFilterBar(
          selectedRange: null,
          firstDate: now,
          lastDate: now,
          onChanged: (_) {},
        ),
      )));

      await tester.tap(find.byKey(const Key('mutasi_date_range_button')));
      await tester.pumpAndSettle();

      // A single-day range picker opened without tripping Material's
      // firstDate/lastDate assertions, and it is showing today.
      expect(tester.takeException(), isNull);
      expect(find.text('${now.day}'), findsWidgets);
    });
  });
}
