import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar_community/isar.dart';
import 'package:workmanager/workmanager.dart';

import '../data/isar_service.dart';
import '../data/models/app_settings.dart';
import '../data/models/product.dart';
import '../data/models/stock_mutation.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/stock_mutation_repository.dart';
import '../domain/prioritas_kulakan_calculator.dart';
import '../ui/screens/beranda/prioritas_kulakan_screen.dart';

const dailySummaryChannelId = 'channel_daily_summary';
const stockCriticalChannelId = 'channel_stock_critical';

const _dailySummaryTaskName = 'dailySummaryTask';
const _dailySummaryRetryTaskName = 'dailySummaryRetryTask';
const _criticalStockAlertTaskName = 'criticalStockAlertTask';
const _payloadDailySummary = 'daily_summary';
const _payloadCriticalStock = 'critical_stock';

const _dailySummaryNotificationId = 1;
const _combinedCriticalStockNotificationId = 2;

/// Thin seam over [FlutterLocalNotificationsPlugin] so the pure
/// content-building logic in [NotificationService] can be unit-tested by
/// swapping [NotificationService.sender] for a fake, without touching a
/// real platform channel (which isn't available in `flutter test`).
abstract class NotificationSender {
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required bool highImportance,
    String? payload,
  });
}

class _PluginNotificationSender implements NotificationSender {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

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
  }) {
    return _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: highImportance ? Importance.high : Importance.defaultImportance,
          priority: highImportance ? Priority.high : Priority.defaultPriority,
        ),
      ),
      payload: payload,
    );
  }
}

/// Same seam as [NotificationSender], but for workmanager scheduling calls
/// — kept mockable for the same reason (no real platform channel in
/// `flutter test`).
abstract class WorkScheduler {
  Future<void> registerPeriodic(String uniqueName, String taskName, {required Duration frequency});
  Future<void> registerOneOff(String uniqueName, String taskName, {required Duration initialDelay});
  Future<void> cancel(String uniqueName);
}

class _WorkmanagerScheduler implements WorkScheduler {
  @override
  Future<void> registerPeriodic(String uniqueName, String taskName, {required Duration frequency}) {
    return Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: frequency,
      // update (not replace): preserves the original schedule/timing
      // instead of canceling and restarting the periodic work outright —
      // recommended by WorkManager since 2.8.0.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  @override
  Future<void> registerOneOff(String uniqueName, String taskName, {required Duration initialDelay}) {
    return Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      initialDelay: initialDelay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  @override
  Future<void> cancel(String uniqueName) {
    return Workmanager().cancelByUniqueName(uniqueName);
  }
}

/// Android-only push notifications for this offline-first app: a daily
/// stock summary and a critical-stock alert, both scheduled via
/// [Workmanager] (since the app itself isn't always running) rather than
/// sent instantly — the target audience is elderly shop owners, so
/// notifications are batched into a calm, rekap-style alert at user-set
/// times instead of firing once per product the moment it goes critical.
/// See [Product.criticalStockAlertState] for how products queue up
/// between alerts.
class NotificationService {
  NotificationService._();

  /// Swappable for tests. Defaults to the real plugin.
  static NotificationSender sender = _PluginNotificationSender();

  /// Swappable for tests. Defaults to real [Workmanager] calls.
  static WorkScheduler scheduler = _WorkmanagerScheduler();

  /// Attach to [MaterialApp]'s `navigatorKey` so a notification tap can
  /// navigate without a `BuildContext` — the daily-summary tap in
  /// particular may fire from the background isolate's own notification
  /// response callback, long after any specific screen's context is gone.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(initSettings, onDidReceiveNotificationResponse: _onNotificationTap);

    final androidPlugin =
        plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        dailySummaryChannelId,
        'Ringkasan Harian',
        description: 'Ringkasan stok harian toko',
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        stockCriticalChannelId,
        'Stok Kritis',
        description: 'Peringatan stok kritis',
        importance: Importance.high,
      ),
    );

    await Workmanager().initialize(callbackDispatcher);
  }

  static void _onNotificationTap(NotificationResponse response) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (response.payload == _payloadCriticalStock) {
      navigator.push(
        MaterialPageRoute(builder: (_) => PrioritasKulakanScreen(isar: IsarService.instance)),
      );
    } else {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  /// Registers (or cancels) the periodic daily-summary background task
  /// based on [settings]. The task itself runs every 24h regardless of
  /// [AppSettings.dailySummaryHour]/[dailySummaryMinute] — since
  /// workmanager can't target an exact wall-clock time, timing precision
  /// is handled inside [executeDailySummaryTask]'s ±30 minute window
  /// check instead.
  static Future<void> scheduleDailySummary(AppSettings settings) async {
    await scheduler.cancel(_dailySummaryTaskName);
    if (!settings.dailySummaryEnabled) return;

    await scheduler.registerPeriodic(
      _dailySummaryTaskName,
      _dailySummaryTaskName,
      frequency: const Duration(hours: 24),
    );
  }

  /// Registers (or cancels) the periodic critical-stock-alert background
  /// task based on [settings]. Unlike [scheduleDailySummary] (one target
  /// time a day), up to 3 independent times a day can be configured, so
  /// this runs at workmanager's minimum periodic frequency (15 minutes)
  /// rather than once every 24h — [executeCriticalStockAlertTask] checks
  /// every configured slot's ±30 minute window on each tick and is a
  /// no-op unless one is due, so the extra wakeups don't do real work
  /// most of the time. A run landing inside the same window twice (e.g.
  /// because the OS batched two ticks close together) is harmless: the
  /// second run simply finds nothing pending to send (see
  /// [executeCriticalStockAlertTask]).
  static Future<void> scheduleCriticalStockAlerts(AppSettings settings) async {
    await scheduler.cancel(_criticalStockAlertTaskName);
    if (!settings.criticalStockAlertEnabled) return;

    await scheduler.registerPeriodic(
      _criticalStockAlertTaskName,
      _criticalStockAlertTaskName,
      frequency: const Duration(minutes: 15),
    );
  }

  /// The actual work run by [callbackDispatcher] on every critical-stock
  /// periodic tick. Sends at most one combined "rekap" notification per
  /// call — never one per product — covering every product that went
  /// critical since the last alert. Sends nothing at all when the queue
  /// is empty, so a scheduled time with no news stays silent.
  static Future<void> executeCriticalStockAlertTask(Isar isar, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final settingsRepository = AppSettingsRepository(isar);
    final settings = await settingsRepository.get();

    if (!settings.criticalStockAlertEnabled) return;

    final isSlotDue = settings.criticalStockAlertTimes.any(
      (slot) => isWithinNotificationWindow(effectiveNow, slot.hour, slot.minute),
    );
    if (!isSlotDue) return;

    // Re-checked against the product's current threshold (not just the
    // queue flag) as a defensive guard against a stale queue entry left
    // behind by e.g. the user raising minStockThreshold after the
    // product was queued.
    final pendingProducts = (await isar.products
            .filter()
            .criticalStockAlertStateEqualTo(criticalStockAlertStatePending)
            .findAll())
        .where((product) => product.currentStock <= product.minStockThreshold)
        .toList();
    if (pendingProducts.isEmpty) return;

    await sender.showNotification(
      id: _combinedCriticalStockNotificationId,
      title: 'Stok Kritis',
      body: buildCriticalStockAlertBody(pendingProducts),
      channelId: stockCriticalChannelId,
      channelName: 'Stok Kritis',
      channelDescription: 'Peringatan stok kritis',
      highImportance: true,
      payload: _payloadCriticalStock,
    );

    await isar.writeTxn(() async {
      for (final product in pendingProducts) {
        product.criticalStockAlertState = criticalStockAlertStateNotified;
      }
      await isar.products.putAll(pendingProducts);
    });
  }

  static String buildCriticalStockAlertBody(List<Product> products) {
    if (products.length == 1) {
      return '⚠️ Stok kritis: ${products.first.name} habis — segera kulakan';
    }
    final names = products.map((p) => p.name).join(', ');
    return '⚠️ ${products.length} barang stok kritis: $names — segera kulakan';
  }

  static String buildDailySummaryBody({required int soldToday, required int needRestockCount}) {
    if (soldToday == 0 && needRestockCount == 0) {
      return 'Tidak ada aktivitas hari ini · Stok aman semua 👍';
    }
    return '$soldToday barang terjual hari ini · $needRestockCount barang perlu dikulak segera';
  }

  /// True when [now] falls within ±30 minutes of `targetHour:targetMinute`
  /// on the same day — the tolerance window workmanager's inexact
  /// periodic scheduling is checked against, since the OS may run the
  /// task early/late depending on battery optimization/Doze state.
  static bool isWithinNotificationWindow(DateTime now, int targetHour, int targetMinute) {
    final target = DateTime(now.year, now.month, now.day, targetHour, targetMinute);
    return now.difference(target).abs() <= const Duration(minutes: 30);
  }

  /// The actual work run by [callbackDispatcher] once a day. Takes a
  /// plain [Isar] instance (not `IsarService`, which is a private-
  /// constructor singleton wrapper with no way to construct a test
  /// instance) — consistent with every repository in this codebase.
  static Future<void> executeDailySummaryTask(Isar isar, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final settingsRepository = AppSettingsRepository(isar);
    final settings = await settingsRepository.get();

    if (!settings.dailySummaryEnabled) return;

    if (!isWithinNotificationWindow(effectiveNow, settings.dailySummaryHour, settings.dailySummaryMinute)) {
      // The OS ran the periodic task outside the user's configured
      // window (battery optimization deferred it) — try again sooner
      // rather than waiting a full 24h for the next periodic run.
      await scheduler.registerOneOff(
        _dailySummaryRetryTaskName,
        _dailySummaryTaskName,
        initialDelay: const Duration(minutes: 15),
      );
      return;
    }

    final mutationRepository = StockMutationRepository(isar);
    final productRepository = ProductRepository(isar, mutationRepository, settingsRepository);

    final products = await productRepository.getAll();
    final startOfDay = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
    final totals = await mutationRepository.getTotalsSince(startOfDay);
    final soldToday = totals.stockOut.round();

    final stockOutByProduct = <int, List<StockMutation>>{};
    for (final product in products) {
      stockOutByProduct[product.id] =
          await mutationRepository.getStockOutHistoryForProduct(product.id);
    }

    const calculator = PrioritasKulakanCalculator();
    final results = calculator.calculateAll(
      products: products,
      stockOutMutationsByProductId: stockOutByProduct,
      now: effectiveNow,
    );
    final needRestockCount = results.where((r) => r.urgency != PriorityUrgency.neutral).length;

    await sender.showNotification(
      id: _dailySummaryNotificationId,
      title: 'Ringkasan hari ini — Toko Mama',
      body: buildDailySummaryBody(soldToday: soldToday, needRestockCount: needRestockCount),
      channelId: dailySummaryChannelId,
      channelName: 'Ringkasan Harian',
      channelDescription: 'Ringkasan stok harian toko',
      highImportance: false,
      payload: _payloadDailySummary,
    );
  }
}

/// Workmanager entry point: runs in a separate background isolate with no
/// access to the main isolate's [IsarService] cache, so it reopens Isar
/// itself. Registered once via `Workmanager().initialize(callbackDispatcher)`
/// in [NotificationService.initialize].
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final isar = await IsarService.open();
    switch (task) {
      case _dailySummaryTaskName:
        await NotificationService.executeDailySummaryTask(isar);
      case _criticalStockAlertTaskName:
        await NotificationService.executeCriticalStockAlertTask(isar);
    }
    return true;
  });
}
