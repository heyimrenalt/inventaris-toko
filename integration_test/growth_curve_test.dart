import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:inventaris_toko/services/backup_service.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:inventaris_toko/services/recap_pdf_builder.dart';
import 'package:inventaris_toko/ui/screens/beranda/beranda_screen.dart';
import 'package:inventaris_toko/ui/screens/keuntungan/rekap_keuntungan_screen.dart';
import 'package:inventaris_toko/ui/widgets/report_period_filter.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../test_support/scale_seed.dart';

/// **Growth-curve** scaling test: the same five operations measured at four
/// dataset sizes, so what matters is the *shape* of each curve rather than
/// any single absolute number.
///
/// ## Why one run, four sizes
///
/// This phone throttles hard enough that identical code has measured up to
/// ~2× apart across separate runs (documented in
/// `docs/task6-scale-test-report.md` §3.4). Any curve assembled from
/// numbers taken in different runs would therefore be measuring thermal
/// state, not scaling. So all four sizes are seeded and measured **back to
/// back inside a single run**, and only ratios *within* that run are
/// reported. Absolute values are debug-build upper bounds and are not
/// release figures.
///
/// Sizes are still measured in ascending order, which means the largest
/// size is the most thermally disadvantaged. That biases the curve towards
/// looking *worse* than reality at 2500 — a conservative direction for a
/// test whose purpose is spotting superlinear growth.
///
/// ## Safety
///
/// Identical to `scale_performance_test.dart`: every size gets a throwaway
/// Isar instance in a fresh subdirectory of the *cache* directory under its
/// own database name, cleared by [assertSafeSeedDirectory] against the real
/// documents directory before anything is opened, and deleted from disk
/// afterwards. `IsarService.open()` — the only path to real shop data — is
/// never called. Notification statics are pointed at no-op fakes for the
/// whole run, so the restore path's cancel/reschedule never touches the
/// device's tray or alarm manager.
///
/// ## Running it
///
///     flutter test integration_test/growth_curve_test.dart -d MR9T5L9LJ7GIGYQ8
///
/// The matrix and the ratio table are printed to the console at the end.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Mutation counts to measure. Product counts are derived at a consistent
  /// 5:1 mutation-to-product ratio, matching the 200/1000 shape the earlier
  /// scale test used, so a size step changes *how much* data there is
  /// without changing its shape.
  const sizes = <int>[250, 500, 1000, 2500];
  int productsFor(int mutations) => mutations ~/ 5; // 50 / 100 / 200 / 500

  /// A small dataset run through every operation first, with its results
  /// thrown away.
  ///
  /// Required for the curve to mean anything. This is a debug build, so the
  /// first pass through each code path also pays for JIT compilation of the
  /// screens, the PDF layout engine and the JSON codec. In a run without
  /// this, the smallest size absorbed all of that and measured *slower* than
  /// the next size up (Rekap 4008 ms @250 vs 2117 ms @500; PDF 1277 vs 683),
  /// which turns the first ratio into noise and hides the real shape.
  const warmupMutations = 100;

  final matrix = _Matrix(sizes);
  final discarded = _Matrix(sizes);

  setUpAll(() {
    NotificationService.sender = _NoopNotificationSender();
    NotificationService.scheduler = _NoopWorkScheduler();
    NotificationService.alarmScheduler = _NoopAlarmScheduler();
    NotificationService.exactAlarmPermission = _NoopExactAlarmPermission();
  });

  tearDownAll(() => matrix.printReport());

  for (final mutationCount in [warmupMutations, ...sizes]) {
    final productCount = productsFor(mutationCount);
    final isWarmup = mutationCount == warmupMutations;
    // Warm-up results go into a matrix that is never printed.
    final target = isWarmup ? discarded : matrix;
    final label = isWarmup ? 'WARM-UP (discarded)' : 'growth curve';

    testWidgets(
      '$label @ $productCount produk / $mutationCount mutasi',
      timeout: const Timeout(Duration(minutes: 15)),
      (tester) async {
        final productionDir = await getApplicationDocumentsDirectory();
        final cacheDir = await getTemporaryDirectory();
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final seedDir = Directory('${cacheDir.path}/growth_seed_$stamp');
        assertSafeSeedDirectory(
          seedDirectory: seedDir.path,
          productionDirectory: productionDir.path,
        );
        await seedDir.create(recursive: true);

        final isar = await Isar.open(
          [
            CategorySchema,
            ProductSchema,
            StockMutationSchema,
            AppSettingsSchema,
            CostPriceAdjustmentSchema,
            RestockListSchema,
          ],
          directory: seedDir.path,
          name: 'growth_seed_$stamp',
        );
        addTearDown(() async {
          // Ordering matters: widgets are already unmounted by the end of the
          // body (see the pumpWidget(SizedBox) below), so every watchLazy
          // subscription has been cancelled in dispose() and nothing can be
          // mid-query when the native instance goes away.
          await isar.close(deleteFromDisk: true);
          if (seedDir.existsSync()) {
            await seedDir.delete(recursive: true);
          }
        });

        final plan = buildScaleSeedPlan(
          productCount: productCount,
          mutationCount: mutationCount,
        );
        final mutationRepository = StockMutationRepository(isar);
        final productRepository = ProductRepository(
          isar,
          mutationRepository,
          AppSettingsRepository(isar),
        );

        // Seeding is reported for feasibility only — it is not a user-facing
        // operation and its cost is dominated by one write transaction per
        // mutation, which no user ever performs in a batch.
        final seedStopwatch = Stopwatch()..start();
        await _seed(
          isar: isar,
          plan: plan,
          categoryRepository: CategoryRepository(isar),
          productRepository: productRepository,
          mutationRepository: mutationRepository,
        );
        seedStopwatch.stop();
        target.record('SEEDING (not user-facing)', mutationCount,
            seedStopwatch.elapsedMilliseconds);

        expect(await isar.products.count(), productCount);
        expect(await isar.stockMutations.count(), mutationCount);

        // The covariate Rekap is suspected to scale with: how many distinct
        // products have at least one sale, i.e. how many rows the report
        // renders. Recorded so the curve can be read against it rather than
        // against the mutation count alone.
        final report = await mutationRepository.buildProfitReport(
          const ReportPeriod.allTime(),
        );
        target.record('— sold products (report rows)', mutationCount,
            report.lines.length, isTime: false);

        // ---- 1. Rekap Keuntungan: open until the figures are on screen ----
        await target.measure('1. Rekap Keuntungan → figures on screen', mutationCount,
            () async {
          await tester.pumpWidget(_app(RekapKeuntunganScreen(
            isar: isar,
            mutationRepository: mutationRepository,
          )));
          // Concrete condition, never pumpAndSettle: this screen shows a
          // CircularProgressIndicator while loading, which schedules a frame
          // forever, so settling degenerates into a busy-wait. 'Salin' lives
          // in the bottom action bar, which is built only when the report is
          // loaded and non-empty — so finding it means the figures are up.
          await _pumpUntilFound(tester, find.text('Salin'));
        });
        expect(find.byKey(const Key('recap_empty_period')), findsNothing);

        // ---- 2. Beranda: open until first meaningful render ----
        await target.measure('2. Beranda → summary figures on screen', mutationCount,
            () async {
          await tester.pumpWidget(_app(BerandaScreen(isar: isar)));
          // Same reasoning: Beranda renders a bare
          // CircularProgressIndicator while `_loading`. The total-profit
          // summary tile only exists once loading is done, so it is the
          // first frame that means anything to the user.
          await _pumpUntilFound(
            tester,
            find.byKey(const Key('beranda_summary_total_keuntungan')),
          );
        });

        // Unmount both screens before measuring anything else. This is not
        // tidiness — it is required for the numbers below to mean anything.
        // BerandaScreen subscribes to `watchLazy()` on products, mutations
        // and appSettings and calls `_load()` on every change, so leaving it
        // mounted while the backup import wipes and rewrites six collections
        // triggers a storm of concurrent `_load()` calls (each one a
        // per-mutation product-lookup loop). That inflates the import timing
        // with unrelated screen work, keeps queries in flight past the end
        // of the test, and reliably segfaulted IsarCore on this device when
        // the instance was closed underneath them.
        await tester.pumpWidget(const SizedBox.shrink());
        // Let any load already in flight finish while Isar is still open.
        await tester.pump(const Duration(milliseconds: 500));

        // ---- 3. PDF export of the profit report ----
        final range = await mutationRepository.getProfitableStockOutDateRange();
        final fonts = await target.measure(
          '3a. PDF: load bundled font',
          mutationCount,
          () => loadRecapPdfFonts(),
        );
        final pdfBytes = await target.measure(
          '3. PDF: generate document',
          mutationCount,
          () => buildRecapPdf(
            report: report,
            periodLabel: buildPeriodLabel(
              const ReportPeriod.allTime(),
              allTimeRange: range,
            ),
            fonts: fonts,
          ),
        );
        expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
        target.record('3b. PDF size (KB)', mutationCount,
            (pdfBytes.length / 1024).round(), isTime: false);

        // ---- 4. Backup EXPORT: serialise + write to file ----
        // The first end-to-end exercise of backup at 1000 and 2500 rows;
        // the integrity suite only ever ran it at 40/250.
        final backupService = BackupService(isar);
        final backupFile = await target.measure(
          '4. Backup EXPORT (serialise + write file)',
          mutationCount,
          () => backupService.exportToFile(directory: seedDir),
        );
        final backupBytes = await backupFile.length();
        target.record('4b. Backup file size (KB)', mutationCount,
            (backupBytes / 1024).round(), isTime: false);

        // ---- 5. Backup IMPORT: read + restore round-trip ----
        final jsonString = await target.measure(
          '5a. Backup: read file from disk',
          mutationCount,
          () => backupFile.readAsString(),
        );
        final parsed = await target.measure(
          '5b. Backup: validate + parse JSON',
          mutationCount,
          () => backupService.validateAndParse(jsonString),
        );
        await target.measure(
          '5. Backup IMPORT (snapshot + wipe + restore)',
          mutationCount,
          () => backupService.importBackup(parsed),
        );

        // The restore actually restored, at every size — a timing for a
        // no-op would be worthless.
        expect(await isar.products.count(), productCount);
        expect(await isar.stockMutations.count(), mutationCount);
      },
    );
  }
}

/// Creates the plan's categories, products and mutations through the real
/// repositories, then backdates every mutation to its planned timestamp.
///
/// Same approach (and same reason) as `scale_performance_test.dart`'s
/// seeder: writing through the repositories means the seeded state is what
/// the app itself would have produced — stock, weighted-average HPP, price
/// snapshots, critical-alert state — rather than hand-built rows. `createdAt`
/// is the one field `recordMutation` will not accept, so it is rewritten
/// afterwards in a single transaction; the plan is in ascending time order,
/// so that never reorders the ledger relative to the stock arithmetic.
///
/// No photos are attached: photo base64 would dominate the backup-size and
/// export-time curves with a constant that has nothing to do with ledger
/// growth, which is what these curves are about.
Future<void> _seed({
  required Isar isar,
  required ScaleSeedPlan plan,
  required CategoryRepository categoryRepository,
  required ProductRepository productRepository,
  required StockMutationRepository mutationRepository,
}) async {
  final categoryIdByIndex = <int, int>{};
  for (final category in plan.categories) {
    final parentIndex = category.parentIndex;
    final created = await categoryRepository.create(
      category.name,
      parentId: parentIndex == null ? null : categoryIdByIndex[parentIndex],
    );
    categoryIdByIndex[category.index] = created.id;
  }

  final productIdByIndex = <int, int>{};
  for (final product in plan.products) {
    final categoryIndex = product.categoryIndex;
    final created = await productRepository.create(
      name: product.name,
      categoryId: categoryIndex == null ? null : categoryIdByIndex[categoryIndex],
      sellPrice: product.sellPrice,
      unit: product.unit,
      minStockThreshold: product.minStockThreshold,
    );
    productIdByIndex[product.index] = created.id;
  }

  final mutationIds = <int>[];
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

  final rows = await isar.stockMutations.getAll(mutationIds);
  await isar.writeTxn(() async {
    for (var i = 0; i < plan.mutations.length; i++) {
      final row = rows[i]!;
      row.createdAt = plan.mutations[i].at;
      await isar.stockMutations.put(row);
    }
  });
}

/// Pumps frames until [finder] matches, or fails after [timeout].
///
/// The deterministic alternative to `pumpAndSettle` for screens that show a
/// progress indicator while loading: an indefinitely-animating widget means
/// "settled" never arrives on its own terms, so pumping to an explicit
/// condition is the only way to get a number that means "time until the user
/// can see the data".
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 120),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out after $timeout waiting for: $finder');
}

/// Wraps a screen in the same MaterialApp configuration `main.dart` uses, so
/// localised date/number formatting behaves as it does in the app.
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

/// Operation × dataset-size results, printed as two markdown tables: the raw
/// matrix, and the consecutive-size ratio per operation with superlinear
/// growth flagged.
///
/// Nothing is asserted on these numbers, deliberately — a threshold would
/// turn a thermally throttled phone into a failing test suite rather than a
/// report.
class _Matrix {
  _Matrix(this.sizes);

  final List<int> sizes;

  /// Operation label -> dataset size -> value. Insertion-ordered, so the
  /// printed rows follow the order the operations were measured in.
  final Map<String, Map<int, num>> _values = {};

  /// Rows whose values are not milliseconds (byte sizes, row counts). Their
  /// ratios are still printed — a size row growing exactly with the data is
  /// useful context — but they are never verdicted as fast/slow, and the
  /// millisecond noise floor does not apply to them.
  final Set<String> _nonTimeRows = {};

  void record(String operation, int size, num value, {bool isTime = true}) {
    (_values[operation] ??= <int, num>{})[size] = value;
    if (!isTime) _nonTimeRows.add(operation);
  }

  Future<T> measure<T>(String operation, int size, Future<T> Function() body) async {
    final stopwatch = Stopwatch()..start();
    final result = await body();
    stopwatch.stop();
    record(operation, size, stopwatch.elapsedMilliseconds);
    return result;
  }

  void printReport() {
    if (_values.isEmpty) return;

    final labelWidth = _values.keys
        .map((k) => k.length)
        .fold<int>('Operation'.length, (a, b) => a > b ? a : b);

    final buffer = StringBuffer()
      ..writeln()
      ..writeln('=== GROWTH CURVE: ms by dataset size (single run, ascending) ===')
      ..writeln();

    String row(String label, Iterable<String> cells) =>
        '| ${label.padRight(labelWidth)} | ${cells.map((c) => c.padLeft(8)).join(' | ')} |';

    buffer
      ..writeln(row('Operation', sizes.map((s) => '$s')))
      ..writeln('|${'-' * (labelWidth + 2)}|${sizes.map((_) => '${'-' * 9}:').join('|')}|');

    for (final entry in _values.entries) {
      buffer.writeln(row(
        entry.key,
        sizes.map((s) => entry.value[s]?.toString() ?? '—'),
      ));
    }

    buffer
      ..writeln()
      ..writeln('=== CONSECUTIVE-SIZE RATIOS (data grows 2x, 2x, 2.5x) ===')
      ..writeln();

    final ratioHeaders = <String>[];
    for (var i = 1; i < sizes.length; i++) {
      ratioHeaders.add('${sizes[i - 1]}→${sizes[i]}');
    }

    buffer
      ..writeln(row('Operation', [...ratioHeaders, 'verdict']))
      ..writeln('|${'-' * (labelWidth + 2)}|'
          '${[...ratioHeaders, ''].map((_) => '${'-' * 9}:').join('|')}|');

    for (final entry in _values.entries) {
      final cells = <String>[];
      final isTimeRow = !_nonTimeRows.contains(entry.key);
      var superlinear = false;
      var noiseOnly = false;
      for (var i = 1; i < sizes.length; i++) {
        final previous = entry.value[sizes[i - 1]];
        final current = entry.value[sizes[i]];
        if (previous == null || current == null || previous == 0) {
          cells.add('—');
          continue;
        }
        // Below this, a step is timer granularity and scheduling jitter
        // rather than scaling: a 2 ms -> 6 ms move is a "3x regression" by
        // arithmetic and nothing at all in reality. Such rows get their
        // ratios printed but are never flagged.
        const noiseFloorMillis = 50;
        final belowNoiseFloor =
            isTimeRow && current < noiseFloorMillis && previous < noiseFloorMillis;

        final ratio = current / previous;
        // The data itself grows by this factor between the two sizes, so
        // that is the bar linear scaling has to clear. 1.35x slack absorbs
        // this device's run-to-run noise without hiding a real quadratic —
        // a quadratic would show ~4x against a 2x data step, not ~2.7x.
        final dataGrowth = sizes[i] / sizes[i - 1];
        final isSuper = isTimeRow && !belowNoiseFloor && ratio > dataGrowth * 1.35;
        if (isSuper) superlinear = true;
        if (belowNoiseFloor) noiseOnly = true;
        cells.add('${ratio.toStringAsFixed(2)}x${isSuper ? '!' : ''}');
      }
      cells.add(!isTimeRow
          ? 'not a timing'
          : superlinear
              ? 'SUPERLINEAR'
              : noiseOnly
                  ? 'sub-50ms'
                  : 'linear/ok');
      buffer.writeln(row(entry.key, cells));
    }

    buffer
      ..writeln()
      ..writeln('"!" marks a step where the operation grew more than 1.35x '
          'faster than the data did.')
      ..writeln('Absolute ms are debug-build upper bounds on a throttling '
          'device; only the ratios are the deliverable.');

    // ignore: avoid_print
    print(buffer.toString());
  }
}

class _NoopNotificationSender implements NotificationSender {
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
  }) async {}

  @override
  Future<void> cancelAllNotifications() async {}
}

class _NoopWorkScheduler implements WorkScheduler {
  @override
  Future<void> cancel(String uniqueName) async {}

  @override
  Future<void> registerOneOff(String uniqueName, String taskName,
      {required Duration initialDelay}) async {}

  @override
  Future<void> registerPeriodic(String uniqueName, String taskName,
      {required Duration frequency}) async {}
}

class _NoopAlarmScheduler implements AlarmScheduler {
  @override
  Future<void> scheduleExact(int slotIndex, DateTime time) async {}

  @override
  Future<void> cancel(int slotIndex) async {}
}

class _NoopExactAlarmPermission implements ExactAlarmPermission {
  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmsPermission() async {}
}
