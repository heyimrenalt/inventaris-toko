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
import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/services/backup_service.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:inventaris_toko/ui/screens/beranda/beranda_screen.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../test_support/scale_seed.dart';

/// Tracks [BerandaScreen] reloads: how many have started, and whether one is
/// still running right now.
///
/// The test needs both. It must not close Isar while a reload is still
/// querying — that is exactly the crash — and the reload *count* is the
/// storm measured directly on the device rather than inferred from commit
/// counts.
///
/// "Still running" has to span the whole of `_load`, not one query inside
/// it. `_load` opens with an `AppSettingsRepository.get()` and closes with a
/// `StockMutationRepository.calculateTotalProfit()`, so the two are used as
/// the load's start and end markers. Instrumenting the product query in the
/// middle was not enough: a load parked in `calculateTotalProfit` after
/// `getAll` had already returned looked idle, and teardown closed the
/// database underneath it.
///
/// This is deliberately coupled to `_load`'s shape. If `_load` gains a new
/// last Isar call, [_InstrumentedMutationRepository] has to follow it.
class _ReloadTracker {
  int startedCount = 0;
  int inFlight = 0;
}

/// Marks a reload as *started* — `get()` is `_load`'s first await.
class _InstrumentedSettingsRepository extends AppSettingsRepository {
  _InstrumentedSettingsRepository(super.isar, this._tracker);

  final _ReloadTracker _tracker;

  @override
  Future<AppSettings> get() async {
    _tracker.startedCount++;
    _tracker.inFlight++;
    return super.get();
  }
}

/// Marks a reload as *finished* — `calculateTotalProfit()` is `_load`'s last
/// await, and it runs unconditionally, before the mounted check.
class _InstrumentedMutationRepository extends StockMutationRepository {
  _InstrumentedMutationRepository(super.isar, this._tracker);

  final _ReloadTracker _tracker;

  @override
  Future<double> calculateTotalProfit([ReportPeriod period = const ReportPeriod.allTime()]) async {
    try {
      return await super.calculateTotalProfit(period);
    } finally {
      _tracker.inFlight--;
    }
  }
}

/// Crash regression test: **a backup restore while Beranda is on screen**.
///
/// ## What this reproduces
///
/// `BerandaScreen` subscribes to `watchLazy()` on products, mutations and
/// appSettings and reloads on every change. Restore used to run seven
/// separate write transactions (one wipe, then one per collection), and
/// every commit woke every listener — so a restore fired a burst of
/// concurrent `_load()`s, each a full re-query of the whole catalogue,
/// *while* IsarCore was still bulk-writing. That reliably crashed the
/// engine with `SIGSEGV in [anon:dart-code]` on a real device, and left
/// queries in flight past the end of the test.
///
/// `growth_curve_test.dart` deliberately unmounts Beranda before its
/// restore, because it is measuring restore timing and the reload storm
/// polluted the numbers. That sidesteps the bug rather than testing it —
/// hence this test, which does the opposite and keeps Beranda mounted
/// throughout, which is what the real app does when the user restores from
/// the Pengaturan tab.
///
/// ## Why it repeats
///
/// The failure was a native memory fault under concurrency, so a single
/// green run proves very little: the fix has to hold across repeated runs,
/// not merely make the crash rarer. Each iteration is a full seed → export
/// → restore cycle against a fresh Isar instance with the screen live.
///
/// ## Safety
///
/// Same discipline as the other integration tests here: a throwaway Isar in
/// a fresh subdirectory of the *cache* directory, checked against the real
/// documents directory by [assertSafeSeedDirectory] before anything opens,
/// and deleted afterwards. `IsarService.open()` — the only path to real shop
/// data — is never called, and notification statics are no-ops so the
/// restore path's cancel/reschedule never touches the device tray.
///
/// ## Running it
///
///     flutter test integration_test/restore_with_beranda_mounted_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The size the crash was originally observed at. This matters: at 500
  /// mutations the unfixed code passed ten runs out of ten, so a smaller
  /// dataset would have been a test that could never fail. At 2500 the
  /// unfixed code fails on the first iteration every time.
  const mutationCount = 2500;
  const productCount = mutationCount ~/ 5;

  /// The crash was probabilistic, so a single green run proves little.
  ///
  /// Iteration 1 is the one that catches it: this is a debug build, so the
  /// first pass through Beranda's load path also pays for JIT compilation,
  /// which widens the window in which a reload overlaps the restore's
  /// writes. Later iterations run warm and are much less likely to collide.
  /// The extra iterations are still worth running — they are what would
  /// catch a fix that merely made the race rarer.
  const iterations = 10;

  setUpAll(() {
    NotificationService.sender = _NoopNotificationSender();
    NotificationService.scheduler = _NoopWorkScheduler();
    NotificationService.alarmScheduler = _NoopAlarmScheduler();
    NotificationService.exactAlarmPermission = _NoopExactAlarmPermission();
  });

  for (var iteration = 1; iteration <= iterations; iteration++) {
    testWidgets(
      'restore with Beranda mounted survives — iteration $iteration/$iterations',
      timeout: const Timeout(Duration(minutes: 10)),
      (tester) async {
        final productionDir = await getApplicationDocumentsDirectory();
        final cacheDir = await getTemporaryDirectory();
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final seedDir = Directory('${cacheDir.path}/restore_repro_$stamp');
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
          name: 'restore_repro_$stamp',
        );

        var screenDisposed = false;
        addTearDown(() async {
          // The screen must be gone — and therefore its watchLazy
          // subscriptions cancelled — before the native instance does. This
          // is the ordering the original crash violated.
          if (!screenDisposed) {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 500));
          }
          await isar.close(deleteFromDisk: true);
          if (seedDir.existsSync()) {
            await seedDir.delete(recursive: true);
          }
        });

        final tracker = _ReloadTracker();
        final mutationRepository = _InstrumentedMutationRepository(isar, tracker);
        final settingsRepository = _InstrumentedSettingsRepository(isar, tracker);
        final productRepository = ProductRepository(
          isar,
          mutationRepository,
          settingsRepository,
        );
        // Registered after the isar.close teardown above, so it runs
        // *before* it: nothing may still be querying when the native
        // instance goes away.
        addTearDown(() {
          expect(tracker.inFlight, 0,
              reason: 'a query still running here is what segfaults IsarCore on close');
        });

        await _seed(
          isar: isar,
          plan: buildScaleSeedPlan(
            productCount: productCount,
            mutationCount: mutationCount,
          ),
          categoryRepository: CategoryRepository(isar),
          productRepository: productRepository,
          mutationRepository: mutationRepository,
        );

        expect(await isar.products.count(), productCount);
        expect(await isar.stockMutations.count(), mutationCount);

        // ---- Beranda goes on screen and STAYS there.
        await tester.pumpWidget(_app(BerandaScreen(
          isar: isar,
          productRepository: productRepository,
          settingsRepository: settingsRepository,
          mutationRepository: mutationRepository,
        )));
        await _pumpUntilFound(
          tester,
          find.byKey(const Key('beranda_summary_total_keuntungan')),
        );
        await _pumpUntilQuiet(tester, tracker);

        final backupService = BackupService(isar);
        final backupFile = await backupService.exportToFile(directory: seedDir);
        final parsed = await backupService.validateAndParse(
          await backupFile.readAsString(),
        );

        // Counted from here, not earlier: exportToFile stamps
        // `lastBackupAt`, which is an appSettings commit of its own and
        // legitimately costs one reload. Only the restore is under test.
        await _pumpUntilQuiet(tester, tracker);
        final reloadsBeforeRestore = tracker.startedCount;

        // ---- The restore, with the screen live and listening. Frames are
        // pumped throughout, so the screen genuinely reacts to the commit
        // rather than sitting frozen while an await completes.
        var importDone = false;
        final import = backupService.importBackup(parsed).then((_) {
          importDone = true;
        });
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        while (!importDone && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await import;
        expect(importDone, isTrue, reason: 'restore did not finish in time');

        // Let the post-commit reload run to completion while the screen is
        // still mounted and Isar is still open — the window the crash used
        // to open in. Waiting on a *finder* here would be no wait at all:
        // the summary tile is already on screen from the pre-restore load.
        // Quiescence is the only condition that actually means "the reload
        // this restore triggered has finished".
        await _pumpUntilQuiet(tester, tracker);

        // The restore is one commit, so it costs one reload. Under the old
        // seven-transaction restore this was a burst — and those overlapping
        // reloads, running full catalogue queries against a database still
        // being bulk-written, are what crashed IsarCore.
        expect(
          tracker.startedCount - reloadsBeforeRestore,
          1,
          reason: 'a restore must cost exactly one Beranda reload',
        );

        // The restore really restored, and the screen survived it.
        expect(await isar.products.count(), productCount);
        expect(await isar.stockMutations.count(), mutationCount);
        expect(find.byKey(const Key('beranda_summary_total_produk')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
        expect(tracker.inFlight, 0);
        screenDisposed = true;
      },
    );
  }
}

/// Creates the plan's categories, products and mutations through the real
/// repositories, then backdates every mutation to its planned timestamp.
/// Same seeder, and same reasoning, as `growth_curve_test.dart`'s: writing
/// through the repositories means the seeded state is what the app itself
/// would have produced.
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

/// Pumps frames until [finder] matches, or fails after [timeout]. Beranda
/// shows an indefinitely-animating progress indicator while loading, so
/// `pumpAndSettle` would never return.
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

/// Pumps frames until no reload is in flight and none has *started* for a
/// clear stretch, i.e. the screen has genuinely settled rather than merely
/// finished the reload that happened to be running when we looked.
Future<void> _pumpUntilQuiet(
  WidgetTester tester,
  _ReloadTracker tracker, {
  Duration quietFor = const Duration(milliseconds: 750),
  Duration timeout = const Duration(minutes: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  var lastStarted = -1;
  var quietSince = DateTime.now();

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));

    final busy = tracker.inFlight > 0 || tracker.startedCount != lastStarted;
    if (busy) {
      lastStarted = tracker.startedCount;
      quietSince = DateTime.now();
      continue;
    }
    if (DateTime.now().difference(quietSince) >= quietFor) return;
  }
  throw TestFailure('Beranda never went quiet: '
      'inFlight=${tracker.inFlight}, started=${tracker.startedCount}');
}

/// Wraps a screen in the same MaterialApp configuration `main.dart` uses.
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
