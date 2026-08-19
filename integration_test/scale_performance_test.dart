import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inventaris_toko/data/migrations/mutation_snapshot_backfill.dart';
import 'package:inventaris_toko/data/models/app_settings.dart';
import 'package:inventaris_toko/data/models/category.dart';
import 'package:inventaris_toko/data/models/cost_price_adjustment.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/restock_list.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';
import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:inventaris_toko/services/recap_pdf_builder.dart';
import 'package:inventaris_toko/ui/screens/beranda/beranda_screen.dart';
import 'package:inventaris_toko/ui/screens/beranda/prioritas_kulakan_screen.dart';
import 'package:inventaris_toko/ui/screens/keuntungan/keuntungan_detail_screen.dart';
import 'package:inventaris_toko/ui/screens/keuntungan/rekap_keuntungan_screen.dart';
import 'package:inventaris_toko/ui/screens/mutasi/mutasi_screen.dart';
import 'package:inventaris_toko/ui/screens/produk/produk_screen.dart';
import 'package:inventaris_toko/ui/widgets/report_period_filter.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../test_support/scale_seed.dart';

/// Scale test: ~200 products and ~1000 mutations spread over six months,
/// on a real device, measuring the positive-path flows and verifying that
/// correctness holds at that size.
///
/// ## Safety
///
/// Everything here runs against a throwaway Isar instance in a fresh
/// subdirectory of the *cache* directory, opened with its own database
/// name — never `IsarService.open()`, which is hardcoded to the app
/// documents directory where the real shop data lives. Before opening
/// anything, [assertSafeSeedDirectory] compares the target against the
/// real documents directory and throws if it is that directory or sits
/// inside it. The instance is deleted from disk afterwards.
///
/// The app's own `NotificationService` statics are pointed at a fake
/// sender for the accuracy check, so no notification is ever posted to the
/// device's tray and no alarm is ever scheduled.
///
/// ## Running it
///
///     flutter test integration_test/scale_performance_test.dart -d <device>
///
/// The timing table is printed to the console at the end of the run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// One dataset, seeded once, shared by every measurement — re-seeding
  /// per test would dominate the run and, worse, measure a different
  /// database each time.
  late Isar isar;
  late Directory seedDir;
  late ScaleSeedPlan plan;
  late ExpectedProfit expected;
  late StockMutationRepository mutationRepository;
  late ProductRepository productRepository;

  /// Maps a plan product index to the Isar id it was actually created
  /// with, so expectations stated in plan terms can be checked against
  /// rows fetched from the database.
  final productIdByIndex = <int, int>{};

  final timings = _Timings();

  setUpAll(() async {
    plan = buildScaleSeedPlan(productCount: 200, mutationCount: 1000);
    expected = expectedProfitFor(plan);

    // The guard runs against the real production path, resolved the same
    // way IsarService.open() resolves it — not against a guessed string.
    final productionDir = await getApplicationDocumentsDirectory();
    final cacheDir = await getTemporaryDirectory();
    seedDir = Directory(
      '${cacheDir.path}/scale_seed_${DateTime.now().microsecondsSinceEpoch}',
    );
    assertSafeSeedDirectory(
      seedDirectory: seedDir.path,
      productionDirectory: productionDir.path,
    );
    await seedDir.create(recursive: true);

    isar = await Isar.open(
      [
        CategorySchema,
        ProductSchema,
        StockMutationSchema,
        AppSettingsSchema,
        CostPriceAdjustmentSchema,
        RestockListSchema,
      ],
      directory: seedDir.path,
      name: 'scale_seed_${DateTime.now().microsecondsSinceEpoch}',
    );

    mutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      mutationRepository,
      AppSettingsRepository(isar),
    );

    await _seed(
      isar: isar,
      plan: plan,
      productRepository: productRepository,
      categoryRepository: CategoryRepository(isar),
      mutationRepository: mutationRepository,
      productIdByIndex: productIdByIndex,
      timings: timings,
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (seedDir.existsSync()) {
      await seedDir.delete(recursive: true);
    }
    timings.printTable();
  });

  testWidgets('seeded dataset has the expected size and shape', (tester) async {
    expect(await isar.products.count(), plan.products.length);
    expect(await isar.stockMutations.count(), plan.mutations.length);
    expect(await isar.categories.count(), plan.categories.length);

    // Backdating actually took: the ledger must span several months, not
    // sit entirely at the moment the seed ran.
    final earliest = await mutationRepository.getEarliestMutationDate();
    expect(earliest, isNotNull);
    expect(
      DateTime.now().difference(earliest!).inDays,
      greaterThan(120),
      reason: 'timestamps were not spread across the intended window',
    );
  });

  testWidgets('profit report is correct and fast at 1000 mutations',
      (tester) async {
    const period = ReportPeriod.allTime();

    final report = await timings.measureAsync(
      'Profit report query + aggregation (all time)',
      () => mutationRepository.buildProfitReport(period),
    );

    // The cross-check: figures computed by the app's query path against
    // figures computed independently from the plan. Tolerance is for
    // double accumulation order only, not for missing rows.
    expect(report.totalRevenue, closeTo(expected.totalRevenue, 0.5));
    expect(report.totalCost, closeTo(expected.totalCost, 0.5));
    expect(report.totalProfit, closeTo(expected.totalProfit, 1));
    expect(report.totalQuantitySold, closeTo(expected.quantitySold, 0.001));
    expect(report.productsSold, expected.productsSold);

    // Sorted by profit descending, as the screen relies on.
    for (var i = 1; i < report.lines.length; i++) {
      expect(report.lines[i - 1].profit >= report.lines[i].profit, isTrue);
    }

    await timings.measureAsync(
      'Profitable date-range resolution (all time label)',
      () => mutationRepository.getProfitableStockOutDateRange(),
    );

    // A bounded period must be cheaper than all-time — it rides the
    // createdAt index instead of scanning the whole ledger.
    final now = DateTime.now();
    final lastMonth = ReportPeriod.days(
      DateTime(now.year, now.month - 1, now.day),
      now,
    );
    await timings.measureAsync(
      'Profit report query + aggregation (last 30 days)',
      () => mutationRepository.buildProfitReport(lastMonth),
    );
  });

  testWidgets('rekap keuntungan screen renders the full dataset',
      (tester) async {
    await timings.measureAsync('Rekap Keuntungan screen: open to figures', () async {
      await tester.pumpWidget(
        _app(
          RekapKeuntunganScreen(
            isar: isar,
            mutationRepository: mutationRepository,
          ),
        ),
      );
      // Deliberately NOT pumpAndSettle: while `_loading` is true this
      // screen shows a CircularProgressIndicator, which schedules a frame
      // forever, so pumpAndSettle degenerates into a busy-wait whose
      // duration reflects frame-pump overhead rather than the screen's
      // own cost. Measured at 12s, 550s and 6s across three runs of
      // identical code — unusable as a metric. Pumping to a concrete
      // condition instead makes the number mean "time until the figures
      // are on screen", which is what we actually want to know.
      // `.hitTestable()`: being in the tree is not enough. On a real
      // device the render view is still Size(0, 0) for the first frames
      // after pumpWidget, so the action bar can be mounted and laid out
      // against a zero-sized surface — present to a plain finder, but at
      // a global offset that tap() cannot hit. Waiting until the widget
      // actually answers a hit test at its centre makes the measurement
      // mean "time until the figures are on screen and usable", and makes
      // the tap below deterministic.
      await _pumpUntilFound(tester, find.text('Salin').hitTestable());
    });

    expect(find.text('Rekap Keuntungan'), findsOneWidget);
    expect(find.byKey(const Key('recap_empty_period')), findsNothing);

    await timings.measureAsync('Copy-to-clipboard (full report)', () async {
      await tester.tap(find.text('Salin').hitTestable());
      // Two frames: one to run the tap handler, one to start the SnackBar.
      // Settling here would wait out the SnackBar's full 3s display and
      // dismissal, which measures Material's animation, not the copy.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
    expect(find.textContaining('disalin ke clipboard'), findsOneWidget);
  });

  testWidgets('PDF export of the full report', (tester) async {
    final report = await mutationRepository.buildProfitReport(
      const ReportPeriod.allTime(),
    );
    final range = await mutationRepository.getProfitableStockOutDateRange();

    final fonts = await timings.measureAsync(
      'PDF: load bundled font',
      () => loadRecapPdfFonts(),
    );

    final bytes = await timings.measureAsync(
      'PDF: generate document (${report.lines.length} product rows)',
      () => buildRecapPdf(
        report: report,
        periodLabel: buildPeriodLabel(
          const ReportPeriod.allTime(),
          allTimeRange: range,
        ),
        fonts: fonts,
      ),
    );

    expect(bytes.length, greaterThan(1000));
    // %PDF- magic: a real document, not an empty buffer.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    await timings.measureAsync('PDF: write bytes to temp file', () async {
      final file = File('${seedDir.path}/scale_recap.pdf');
      await file.writeAsBytes(bytes);
      expect(await file.length(), bytes.length);
    });
  });

  testWidgets('keuntungan detail screen (per-date profit grouping)',
      (tester) async {
    // Isolates the per-mutation profit path (calculateProfitByDate →
    // profitForMutation → one products.get per row) from the batched path
    // buildProfitReport uses, so the two can be compared in the report.
    await timings.measureAsync(
      'calculateProfitByDate (per-mutation product lookup)',
      () => mutationRepository.calculateProfitByDate(),
    );

    await timings.measureAsync(
      'calculateTotalProfit (per-mutation product lookup)',
      () => mutationRepository.calculateTotalProfit(),
    );

    await timings.measureAsync('Keuntungan Detail screen: open to figures',
        () async {
      await tester.pumpWidget(
        _app(KeuntunganDetailScreen(
          isar: isar,
          mutationRepository: mutationRepository,
        )),
      );
      await tester.pumpAndSettle();
    });
  });

  testWidgets('produk list query and scroll', (tester) async {
    await timings.measureAsync(
      'Produk: getAll() query (200 products)',
      () => productRepository.getAll(),
    );
    await timings.measureAsync(
      'Produk: searchByName() query',
      () => productRepository.searchByName('Produk Uji 1'),
    );

    await timings.measureAsync('Produk screen: open to list', () async {
      await tester.pumpWidget(_app(ProdukScreen(isar: isar)));
      await tester.pumpAndSettle();
    });

    await timings.measureAsync('Produk screen: scroll 20 flings', () async {
      for (var i = 0; i < 20; i++) {
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -400),
          3000,
        );
        await tester.pumpAndSettle();
      }
    });
  });

  testWidgets('mutasi history query and scroll', (tester) async {
    await timings.measureAsync(
      'Mutasi: getAllMutations() query (1000 rows)',
      () => mutationRepository.getAllMutations(),
    );
    await timings.measureAsync(
      'Mutasi: getHistoryForProduct() query',
      () => mutationRepository.getHistoryForProduct(productIdByIndex[0]!),
    );

    await timings.measureAsync('Mutasi screen: open to list', () async {
      await tester.pumpWidget(_app(MutasiScreen(isar: isar)));
      await tester.pumpAndSettle();
    });

    await timings.measureAsync('Mutasi screen: scroll 20 flings', () async {
      for (var i = 0; i < 20; i++) {
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -400),
          3000,
        );
        await tester.pumpAndSettle();
      }
    });
  });

  testWidgets('per-product stock-out history loop (Beranda / daily summary)',
      (tester) async {
    final products = await productRepository.getAll();
    expect(products, hasLength(plan.products.length));

    // A/B/C in a single run, so thermal state and device load are
    // identical for all three. Comparing across runs proved worthless:
    // this phone throttles enough between runs to move every figure ~2x,
    // which is larger than the effect being measured.
    //
    // A — the per-product loop with filter() on productId. filter() never
    // consults an index in Isar, so this is a full scan of the 1000-row
    // ledger per product.
    late final Map<int, List<StockMutation>> viaFilter;
    await timings.measureAsync(
      'A) x${products.length} loop, filter() on productId (unindexed scan)',
      () async {
        final byProduct = <int, List<StockMutation>>{};
        for (final product in products) {
          byProduct[product.id] = await isar.stockMutations
              .filter()
              .productIdEqualTo(product.id)
              .typeEqualTo(StockMutationType.stockOut)
              .sortByCreatedAt()
              .findAll();
        }
        viaFilter = byProduct;
      },
    );

    // B — the same loop through the repository. This once rode a productId
    // index via where(); that index measured no benefit over A (the cost is
    // per-call async overhead, not scanning) and was reverted, so B is now
    // A routed through getStockOutHistoryForProduct.
    late final Map<int, List<StockMutation>> perProduct;
    await timings.measureAsync(
      'B) x${products.length} loop, where() on productId index',
      () async {
        final byProduct = <int, List<StockMutation>>{};
        for (final product in products) {
          byProduct[product.id] =
              await mutationRepository.getStockOutHistoryForProduct(product.id);
        }
        perProduct = byProduct;
      },
    );

    // Routing through the repository must not change what comes back.
    for (final product in products) {
      expect(
        perProduct[product.id]!.map((m) => m.id).toList(),
        viaFilter[product.id]!.map((m) => m.id).toList(),
        reason: 'repository and inline results differ for ${product.id}',
      );
    }

    // C — one query plus an in-memory group-by. This is what the app now
    // actually does, via getStockOutHistoryForProducts; A and B are kept
    // as the baselines it's measured against.
    late final Map<int, List<StockMutation>> batched;
    await timings.measureAsync(
      'C) one query + group-by in Dart (no loop)',
      () async {
        final rows = await isar.stockMutations
            .filter()
            .typeEqualTo(StockMutationType.stockOut)
            .sortByCreatedAt()
            .findAll();
        final byProduct = <int, List<StockMutation>>{};
        for (final row in rows) {
          (byProduct[row.productId] ??= <StockMutation>[]).add(row);
        }
        batched = byProduct;
      },
    );

    // The comparison is only meaningful if both really produce the same
    // grouping — otherwise the faster one is just doing less work.
    for (final product in products) {
      final loop = perProduct[product.id] ?? const <StockMutation>[];
      final bulk = batched[product.id] ?? const <StockMutation>[];
      expect(bulk.map((m) => m.id).toList(), loop.map((m) => m.id).toList(),
          reason: 'grouping differs for product ${product.id}');
    }

    final settings = await AppSettingsRepository(isar).get();
    await timings.measureAsync(
      'PrioritasKulakanCalculator.calculateAll (pure CPU, 200 products)',
      () async => const PrioritasKulakanCalculator().calculateAll(
        products: products,
        stockOutMutationsByProductId: perProduct,
        restockLeadTimeDays: settings.restockLeadTimeDays,
        restockCoverDays: settings.restockCoverDays,
      ),
    );

    await timings.measureAsync('Beranda screen: open to figures', () async {
      await tester.pumpWidget(_app(BerandaScreen(isar: isar)));
      await tester.pumpAndSettle();
    });

    await timings.measureAsync('Prioritas Kulakan screen: open to list',
        () async {
      await tester.pumpWidget(_app(PrioritasKulakanScreen(isar: isar)));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('daily summary background task end to end', (tester) async {
    final fakeSender = _RecordingNotificationSender();
    final fakeScheduler = _RecordingWorkScheduler();
    final realSender = NotificationService.sender;
    final realScheduler = NotificationService.scheduler;
    NotificationService.sender = fakeSender;
    NotificationService.scheduler = fakeScheduler;
    addTearDown(() {
      NotificationService.sender = realSender;
      NotificationService.scheduler = realScheduler;
    });

    // Pinned to the configured time so the task takes its real work path
    // rather than the "outside the window, retry later" early return —
    // otherwise this would measure nothing.
    final settings = await AppSettingsRepository(isar).get();
    final now = DateTime.now();
    final atConfiguredTime = DateTime(
      now.year,
      now.month,
      now.day,
      settings.dailySummaryHour,
      settings.dailySummaryMinute,
    );

    await timings.measureAsync(
      'Daily summary task: full run (contains the 200-query loop)',
      () => NotificationService.executeDailySummaryTask(
        isar,
        now: atConfiguredTime,
      ),
    );

    // It did the work rather than deferring itself.
    expect(fakeScheduler.registeredOneOffs, isEmpty);
    expect(fakeSender.calls, hasLength(1));
    expect(fakeSender.calls.single.channelId, dailySummaryChannelId);
  });

  testWidgets('critical-stock notification is accurate at 200 products',
      (tester) async {
    final fakeSender = _RecordingNotificationSender();
    final realSender = NotificationService.sender;
    NotificationService.sender = fakeSender;
    addTearDown(() => NotificationService.sender = realSender);

    // What the alert *should* name, derived from the plan rather than
    // from the same database the code under test reads.
    final expectedIndexes = expectedCriticalProductIndexes(plan, expected);
    final expectedNames = {
      for (final index in expectedIndexes) plan.products[index].name,
    };
    expect(
      expectedNames,
      isNotEmpty,
      reason: 'the dataset must contain critical products to be a real test',
    );

    await timings.measureAsync(
      'Critical-stock alert: query + body build (200 products)',
      () => NotificationService.executeCriticalStockAlertSlot(isar, 0),
    );

    // No duplicates: one batched rekap notification, never one per product.
    expect(fakeSender.calls, hasLength(1));
    final sent = fakeSender.calls.single;
    expect(sent.id, criticalStockAlertNotificationId(0));
    expect(sent.channelId, stockCriticalChannelId);

    // The count in the body must be the true total, even though the body
    // only names the first few.
    expect(
      sent.body,
      contains('${expectedNames.length} barang stok kritis'),
      reason: 'body: ${sent.body}',
    );

    // Accuracy, checked against the database rather than only the body
    // (which truncates): exactly the right products are critical, with no
    // missed and no wrongly-included product.
    final actuallyCritical = (await isar.products.where().findAll())
        .where((p) => !p.isArchived && p.currentStock <= p.minStockThreshold)
        .map((p) => p.name)
        .toSet();
    expect(actuallyCritical, expectedNames);

    // Every product the body does name must be genuinely critical — the
    // "wrong product picked" failure this test exists to catch.
    for (final product in plan.products) {
      if (!sent.body.contains(product.name)) continue;
      expect(
        expectedNames,
        contains(product.name),
        reason: '${product.name} was named but is not critical',
      );
    }

    // Firing a second slot re-alerts on the same live set under its own
    // notification id — it must not be suppressed, nor collide with slot 0.
    await NotificationService.executeCriticalStockAlertSlot(isar, 1);
    expect(fakeSender.calls, hasLength(2));
    expect(fakeSender.calls[1].id, criticalStockAlertNotificationId(1));
    expect(fakeSender.calls[1].body, sent.body);
  });

  /// The post-upgrade first-launch path, which the shared dataset above
  /// cannot exercise: rows seeded through `recordMutation` already carry
  /// price snapshots, so `MutationSnapshotBackfill` finds nothing to do.
  ///
  /// A real pre-snapshot database has 1000 rows with a **null**
  /// `sellPriceSnapshot`, and `main.dart` **awaits** the backfill before
  /// the first frame — so whatever this costs is time the user spends
  /// staring at the splash on the first launch after updating.
  ///
  /// Gets its own throwaway instance (same guard, same cleanup) because it
  /// needs legacy-shaped rows, and because the backfill mutates every row
  /// it touches.
  group('MutationSnapshotBackfill on a legacy-shaped database', () {
    late Isar legacyIsar;
    late Directory legacyDir;

    setUpAll(() async {
      final productionDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getTemporaryDirectory();
      legacyDir = Directory(
        '${cacheDir.path}/legacy_seed_${DateTime.now().microsecondsSinceEpoch}',
      );
      assertSafeSeedDirectory(
        seedDirectory: legacyDir.path,
        productionDirectory: productionDir.path,
      );
      await legacyDir.create(recursive: true);

      legacyIsar = await Isar.open(
        [
          CategorySchema,
          ProductSchema,
          StockMutationSchema,
          AppSettingsSchema,
          CostPriceAdjustmentSchema,
          RestockListSchema,
        ],
        directory: legacyDir.path,
        name: 'legacy_seed_${DateTime.now().microsecondsSinceEpoch}',
      );

      await _seedLegacyShaped(isar: legacyIsar, plan: plan, timings: timings);
    });

    tearDownAll(() async {
      await legacyIsar.close(deleteFromDisk: true);
      if (legacyDir.existsSync()) {
        await legacyDir.delete(recursive: true);
      }
    });

    testWidgets('first run backfills every row, and is not free', (tester) async {
      expect(
        await legacyIsar.stockMutations
            .filter()
            .sellPriceSnapshotIsNull()
            .count(),
        plan.mutations.length,
        reason: 'the legacy fixture must start with no snapshots at all',
      );

      final written = await timings.measureAsync(
        'Backfill: FIRST run on 1000 legacy rows (awaited before first frame)',
        () => MutationSnapshotBackfill(legacyIsar).runIfNeeded(),
      );

      expect(written, plan.mutations.length);
      expect(
        await legacyIsar.stockMutations
            .filter()
            .sellPriceSnapshotIsNull()
            .count(),
        0,
        reason: 'every row should carry a snapshot after the backfill',
      );

      // Provenance is preserved: these are approximations from current
      // prices, and must stay marked as such.
      final sample = await legacyIsar.stockMutations.where().findAll();
      expect(sample.every((m) => m.snapshotBackfilled), isTrue);

      // The flag was persisted, which is what makes later launches cheap.
      expect(
        (await AppSettingsRepository(legacyIsar).get())
            .mutationPriceSnapshotBackfillDone,
        isTrue,
      );
    });

    testWidgets('subsequent launches pay almost nothing', (tester) async {
      // What every launch after the first costs — this is the number that
      // matters for ordinary startup, as opposed to the one-off above.
      final written = await timings.measureAsync(
        'Backfill: guarded no-op (every launch after the first)',
        () => MutationSnapshotBackfill(legacyIsar).runIfNeeded(),
      );
      expect(written, 0);

      // Unguarded re-run: proves idempotency is a property of the row
      // filter itself, not only of the persisted flag.
      final rewritten = await timings.measureAsync(
        'Backfill: unguarded re-run (idempotency check)',
        () => MutationSnapshotBackfill(legacyIsar).run(),
      );
      expect(rewritten, 0);
    });

    testWidgets('profit becomes computable once snapshots exist',
        (tester) async {
      // The point of the backfill: before it, these rows resolve no cost
      // price and contribute nothing to profit. After it, they do.
      final report = await timings.measureAsync(
        'Profit report on backfilled legacy data',
        () => StockMutationRepository(legacyIsar)
            .buildProfitReport(const ReportPeriod.allTime()),
      );

      expect(report.isEmpty, isFalse);
      expect(report.totalRevenue, greaterThan(0));
      expect(report.lines, isNotEmpty);
    });
  });
}

/// Writes a pre-snapshot-era database: products with current prices, and
/// mutations with **null** `sellPriceSnapshot`/`costPriceSnapshot`.
///
/// Deliberately writes rows directly rather than going through
/// `recordMutation` — the whole point is to produce rows that the current
/// write path can no longer produce, since it always captures snapshots.
/// Stock and HPP are computed here so the products still look plausible,
/// but they are not what this fixture is testing.
Future<void> _seedLegacyShaped({
  required Isar isar,
  required ScaleSeedPlan plan,
  required _Timings timings,
}) async {
  await timings.measureAsync('SEED: write legacy-shaped rows (no snapshots)',
      () async {
    final now = DateTime.now();
    final stock = <int, double>{for (final p in plan.products) p.index: 0};
    final avgCost = <int, double?>{for (final p in plan.products) p.index: null};

    // Replayed so the resulting product rows carry a stock level and an
    // HPP consistent with the ledger — the backfill copies the product's
    // *current* prices, so they need to be realistic.
    for (final mutation in plan.mutations) {
      final i = mutation.productIndex;
      if (mutation.type == SeedMutationType.stockIn) {
        final cost = mutation.costPricePerUnit!;
        avgCost[i] = stock[i]! <= 0
            ? cost
            : ((stock[i]! * (avgCost[i] ?? 0)) + (mutation.quantity * cost)) /
                (stock[i]! + mutation.quantity);
        stock[i] = stock[i]! + mutation.quantity;
      } else {
        stock[i] = stock[i]! - mutation.quantity;
      }
    }

    final products = <Product>[
      for (final seed in plan.products)
        Product()
          ..id = seed.index + 1
          ..name = seed.name
          ..categoryId = null
          ..sellPrice = seed.sellPrice
          ..unit = seed.unit
          ..currentStock = stock[seed.index]!
          ..minStockThreshold = seed.minStockThreshold
          ..averageCostPrice = avgCost[seed.index]
          ..createdAt = now
          ..updatedAt = now,
    ];

    final mutations = <StockMutation>[
      for (final seed in plan.mutations)
        StockMutation()
          ..productId = seed.productIndex + 1
          ..type = seed.type == SeedMutationType.stockIn
              ? StockMutationType.stockIn
              : StockMutationType.stockOut
          ..quantity = seed.quantity
          ..stockAfter = 0
          ..createdAt = seed.at
          // The defining characteristic of a legacy row.
          ..sellPriceSnapshot = null
          ..costPriceSnapshot = null
          ..snapshotBackfilled = false,
    ];

    await isar.writeTxn(() async {
      await isar.products.putAll(products);
      await isar.stockMutations.putAll(mutations);
    });
  });
}

/// Creates the plan's categories, products and mutations, then backdates
/// every mutation to its planned timestamp.
///
/// Rows are written through the real repositories — not by putting model
/// objects directly — so the seeded state is exactly what the app itself
/// would have produced: stock levels, weighted-average HPP, price
/// snapshots and critical-alert state all maintained by
/// `StockMutationRepository.recordMutation`.
///
/// `createdAt` is the one thing the repository will not accept (it always
/// stamps `DateTime.now()`), so it is rewritten afterwards in a single
/// write transaction. Mutations are recorded in ascending planned-time
/// order, so rewriting the timestamps never reorders the ledger relative
/// to the stock arithmetic that produced it.
Future<void> _seed({
  required Isar isar,
  required ScaleSeedPlan plan,
  required ProductRepository productRepository,
  required CategoryRepository categoryRepository,
  required StockMutationRepository mutationRepository,
  required Map<int, int> productIdByIndex,
  required _Timings timings,
}) async {
  final categoryIdByIndex = <int, int>{};

  await timings.measureAsync(
    'SEED: create ${plan.categories.length} categories',
    () async {
      for (final category in plan.categories) {
        final parentIndex = category.parentIndex;
        final created = await categoryRepository.create(
          category.name,
          // Parents always precede children in the plan, so the lookup
          // below can never miss.
          parentId: parentIndex == null ? null : categoryIdByIndex[parentIndex],
        );
        categoryIdByIndex[category.index] = created.id;
      }
    },
  );

  await timings.measureAsync(
    'SEED: create ${plan.products.length} products',
    () async {
      for (final product in plan.products) {
        final categoryIndex = product.categoryIndex;
        final created = await productRepository.create(
          name: product.name,
          categoryId:
              categoryIndex == null ? null : categoryIdByIndex[categoryIndex],
          sellPrice: product.sellPrice,
          unit: product.unit,
          minStockThreshold: product.minStockThreshold,
        );
        productIdByIndex[product.index] = created.id;
      }
    },
  );

  final mutationIds = <int>[];
  await timings.measureAsync(
    'SEED: record ${plan.mutations.length} mutations',
    () async {
      for (final mutation in plan.mutations) {
        final recorded = await mutationRepository.recordMutation(
          productId: productIdByIndex[mutation.productIndex]!,
          type: mutation.type == SeedMutationType.stockIn
              ? StockMutationType.stockIn
              : StockMutationType.stockOut,
          quantity: mutation.quantity,
          costPricePerUnit: mutation.costPricePerUnit,
        );
        mutationIds.add(recorded.id);
      }
    },
  );

  await timings.measureAsync('SEED: backdate mutation timestamps', () async {
    final rows = await isar.stockMutations.getAll(mutationIds);
    await isar.writeTxn(() async {
      for (var i = 0; i < plan.mutations.length; i++) {
        final row = rows[i]!;
        row.createdAt = plan.mutations[i].at;
        await isar.stockMutations.put(row);
      }
    });
  });
}

/// Pumps frames until [finder] matches, or fails after [timeout].
///
/// The deterministic alternative to `pumpAndSettle` for screens that show
/// a progress indicator while loading: an indefinitely-animating widget
/// means "settled" never arrives on its own terms, so pumping to an
/// explicit condition is both faster and stable enough to time.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out after $timeout waiting for: $finder');
}

/// Wraps a screen in the same MaterialApp configuration `main.dart` uses,
/// so localised date/number formatting behaves as it does in the app.
Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('id')],
    home: home,
  );
}

/// Collects wall-clock timings and prints them as a table at the end of
/// the run. Console output is the deliverable here — nothing branches on
/// these numbers, deliberately: a threshold assertion would make the suite
/// fail on a slow device rather than report what it measured.
class _Timings {
  final List<({String name, int millis})> _entries = [];

  /// Millisecond mark past which an operation is flagged in the printed
  /// table as worth investigating. 1s is where an offline, local-database
  /// action stops feeling instant.
  static const int slowThresholdMillis = 1000;

  Future<T> measureAsync<T>(String name, Future<T> Function() body) async {
    final stopwatch = Stopwatch()..start();
    final result = await body();
    stopwatch.stop();
    _entries.add((name: name, millis: stopwatch.elapsedMilliseconds));
    return result;
  }

  void printTable() {
    if (_entries.isEmpty) return;

    final nameWidth = _entries
        .map((e) => e.name.length)
        .fold<int>('Operation'.length, (a, b) => a > b ? a : b);

    final buffer = StringBuffer()
      ..writeln()
      ..writeln('=== SCALE TEST TIMINGS (200 produk / 1000 mutasi) ===')
      ..writeln(
        '| ${'Operation'.padRight(nameWidth)} | ${'ms'.padLeft(7)} | Flag |',
      )
      ..writeln('|${'-' * (nameWidth + 2)}|${'-' * 9}|------|');

    for (final entry in _entries) {
      final flag = entry.millis >= slowThresholdMillis ? 'SLOW' : '';
      buffer.writeln(
        '| ${entry.name.padRight(nameWidth)} | '
        '${entry.millis.toString().padLeft(7)} | ${flag.padRight(4)} |',
      );
    }

    final slow = _entries.where((e) => e.millis >= slowThresholdMillis);
    buffer.writeln();
    if (slow.isEmpty) {
      buffer.writeln('No operation exceeded ${slowThresholdMillis}ms.');
    } else {
      buffer.writeln('Flagged (>= ${slowThresholdMillis}ms):');
      for (final entry in slow) {
        buffer.writeln('  - ${entry.name}: ${entry.millis}ms');
      }
    }

    // ignore: avoid_print
    print(buffer.toString());
  }
}

/// Captures workmanager scheduling calls instead of making them, so the
/// daily-summary run never touches a real platform channel and never
/// leaves background work registered on the demo phone.
class _RecordingWorkScheduler implements WorkScheduler {
  final List<String> registeredOneOffs = [];

  @override
  Future<void> registerPeriodic(
    String uniqueName,
    String taskName, {
    required Duration frequency,
  }) async {}

  @override
  Future<void> registerOneOff(
    String uniqueName,
    String taskName, {
    required Duration initialDelay,
  }) async {
    registeredOneOffs.add(uniqueName);
  }

  @override
  Future<void> cancel(String uniqueName) async {}
}

class _SentNotification {
  const _SentNotification({
    required this.id,
    required this.body,
    required this.channelId,
  });

  final int id;
  final String body;
  final String channelId;
}

/// Captures notifications instead of posting them, so the accuracy check
/// never puts anything in the demo phone's tray.
class _RecordingNotificationSender implements NotificationSender {
  final List<_SentNotification> calls = [];

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required bool highImportance,
    String? payload,
  }) async {
    calls.add(_SentNotification(id: id, body: body, channelId: channelId));
  }

  @override
  Future<void> cancelAllNotifications() async {}
}
