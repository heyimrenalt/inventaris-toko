import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
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
const _payloadDailySummary = 'daily_summary';
const _payloadCriticalStock = 'critical_stock';

const _dailySummaryNotificationId = 1;

/// Up to 3 daily "Alert stok kritis" slots, each with its own fixed
/// notification ID ([criticalStockAlertNotificationId]) and alarm ID
/// (see [_criticalStockAlertAlarmId]). Distinct per slot so slot 2 firing
/// doesn't silently replace slot 1's still-visible tray entry, and
/// canceling/rescheduling one slot never touches another's alarm.
const maxCriticalStockAlertSlots = 3;
const _criticalStockAlertBaseNotificationId = 100;
const _criticalStockAlertBaseAlarmId = 200;

int criticalStockAlertNotificationId(int slotIndex) => _criticalStockAlertBaseNotificationId + slotIndex;

int _criticalStockAlertAlarmId(int slotIndex) => _criticalStockAlertBaseAlarmId + slotIndex;

/// The [AndroidAlarmManager.oneShotAt] flags every critical-stock slot
/// alarm is scheduled with — `exact` + `allowWhileIdle` is what actually
/// fixes the Doze-deferral delay bug (`AlarmManagerCompat
/// .setExactAndAllowWhileIdle` under the hood); `wakeup` ensures the
/// device wakes to service it; `rescheduleOnReboot` survives a device
/// restart. Exposed as named constants (rather than inlined in
/// [_AndroidAlarmManagerScheduler.scheduleExact]) so a test can assert on
/// them directly — `AndroidAlarmManager` itself has no platform channel
/// available under `flutter test`.
const criticalStockAlarmExact = true;
const criticalStockAlarmWakeup = true;
const criticalStockAlarmAllowWhileIdle = true;
const criticalStockAlarmRescheduleOnReboot = true;

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

  /// Dismisses every currently-shown notification from this app's tray.
  /// Used by "Hapus semua data" so a stale critical-stock/daily-summary
  /// notification doesn't linger after the data behind it is gone.
  Future<void> cancelAllNotifications();
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

  @override
  Future<void> cancelAllNotifications() => _plugin.cancelAll();
}

/// Same seam as [NotificationSender], but for workmanager scheduling calls
/// — kept mockable for the same reason (no real platform channel in
/// `flutter test`). Only used by the daily summary now: workmanager's
/// 15-minute-minimum, inexact/Doze-deferrable periodic tasks aren't
/// precise enough for the critical-stock alert's exact per-slot times
/// (see [AlarmScheduler]).
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

/// Same seam as [NotificationSender]/[WorkScheduler], but for the
/// per-slot exact alarms behind "Alert stok kritis". Kept mockable for
/// the same reason (no real platform channel in `flutter test`).
///
/// Unlike [WorkScheduler], each alarm here is exact
/// (`setExactAndAllowWhileIdle`) and carries its own Dart callback that
/// re-queries Isar at fire time — required because the alert's content
/// ("which products are critical right now") can't be baked in ahead of
/// time the way `flutter_local_notifications.zonedSchedule` bakes in a
/// fixed title/body; only a real background-alarm callback (this, not
/// `zonedSchedule`) can run that live query at the exact configured
/// moment.
abstract class AlarmScheduler {
  Future<void> scheduleExact(int slotIndex, DateTime time);
  Future<void> cancel(int slotIndex);
}

class _AndroidAlarmManagerScheduler implements AlarmScheduler {
  @override
  Future<void> scheduleExact(int slotIndex, DateTime time) {
    return AndroidAlarmManager.oneShotAt(
      time,
      _criticalStockAlertAlarmId(slotIndex),
      criticalStockAlarmCallback,
      exact: criticalStockAlarmExact,
      wakeup: criticalStockAlarmWakeup,
      allowWhileIdle: criticalStockAlarmAllowWhileIdle,
      rescheduleOnReboot: criticalStockAlarmRescheduleOnReboot,
    );
  }

  @override
  Future<void> cancel(int slotIndex) {
    return AndroidAlarmManager.cancel(_criticalStockAlertAlarmId(slotIndex));
  }
}

/// Same seam as [NotificationSender]/[WorkScheduler]/[AlarmScheduler], but
/// for the exact-alarm runtime permission check — kept mockable for the
/// same reason (no real platform channel in `flutter test`).
abstract class ExactAlarmPermission {
  Future<bool> canScheduleExactAlarms();
  Future<void> requestExactAlarmsPermission();
}

class _PluginExactAlarmPermission implements ExactAlarmPermission {
  @override
  Future<bool> canScheduleExactAlarms() async {
    final androidPlugin = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<void> requestExactAlarmsPermission() async {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }
}

/// Android-only push notifications for this offline-first app: a daily
/// stock summary (workmanager — see [WorkScheduler]) and a critical-stock
/// alert (exact per-slot alarms — see [AlarmScheduler]), both batched
/// into a calm, rekap-style alert rather than firing once per product —
/// the target audience is elderly shop owners.
class NotificationService {
  NotificationService._();

  /// Swappable for tests. Defaults to the real plugin.
  static NotificationSender sender = _PluginNotificationSender();

  /// Swappable for tests. Defaults to real [Workmanager] calls.
  static WorkScheduler scheduler = _WorkmanagerScheduler();

  /// Swappable for tests. Defaults to real [AndroidAlarmManager] calls.
  static AlarmScheduler alarmScheduler = _AndroidAlarmManagerScheduler();

  /// Swappable for tests. Defaults to the real plugin.
  static ExactAlarmPermission exactAlarmPermission = _PluginExactAlarmPermission();

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
    await AndroidAlarmManager.initialize();
  }

  /// True when the OS will actually let an exact alarm fire on time.
  /// Android 12+ (API 31+) lets the user revoke the app's "Alarms &
  /// reminders" access after install/grant — this surfaces that state so
  /// `PengaturanScreen` can warn before scheduling alerts that would
  /// otherwise silently fall back to inexact (and thus Doze-deferrable)
  /// delivery. `true` on older Android where the concept doesn't exist.
  static Future<bool> canScheduleExactAlarms() => exactAlarmPermission.canScheduleExactAlarms();

  /// Opens the system "Alarms & reminders" settings page for this app so
  /// the user can grant `SCHEDULE_EXACT_ALARM`. Only ever called from an
  /// explicit user tap (see `PengaturanScreen`) — never on first launch —
  /// per Play policy on requesting sensitive permissions.
  static Future<void> requestExactAlarmsPermission() => exactAlarmPermission.requestExactAlarmsPermission();

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

  /// Registers (or cancels) the up-to-3 exact daily alarms behind "Alert
  /// stok kritis", based on [settings]. Every configured slot is
  /// canceled and re-armed from scratch on every call (cheap — just OS
  /// AlarmManager calls) so a settings change never leaves a stale slot
  /// alarm behind, and a slot whose target time has already passed today
  /// is armed for the same time tomorrow instead ([_nextOccurrence]).
  /// Each armed alarm re-arms itself for the next day after firing (see
  /// [criticalStockAlarmCallback]) — an exact one-shot alarm fires once,
  /// so the daily recurrence is maintained by the callback, not by the
  /// OS.
  static Future<void> scheduleCriticalStockAlerts(AppSettings settings, {DateTime? now}) async {
    for (var slot = 0; slot < maxCriticalStockAlertSlots; slot++) {
      await alarmScheduler.cancel(slot);
    }
    if (!settings.criticalStockAlertEnabled) return;

    final effectiveNow = now ?? DateTime.now();
    final times = settings.criticalStockAlertTimes;
    for (var slot = 0; slot < times.length; slot++) {
      final time = times[slot];
      await alarmScheduler.scheduleExact(slot, _nextOccurrence(effectiveNow, time.hour, time.minute));
    }
  }

  /// Cancels every background notification path this app schedules: the
  /// daily-summary workmanager task, all (up to 3) exact critical-stock
  /// alarm slots, and any notification currently sitting in the tray.
  /// Used by "Hapus semua data" (see `PengaturanScreen`), where a wipe
  /// must leave nothing scheduled to fire against data that no longer
  /// exists. Unconditional — unlike [scheduleDailySummary]/
  /// [scheduleCriticalStockAlerts], it doesn't consult `AppSettings`,
  /// since the settings row itself is being wiped alongside everything
  /// else.
  static Future<void> cancelAll() async {
    await scheduler.cancel(_dailySummaryTaskName);
    for (var slot = 0; slot < maxCriticalStockAlertSlots; slot++) {
      await alarmScheduler.cancel(slot);
    }
    await sender.cancelAllNotifications();
  }

  /// The next moment `hour:minute` occurs at or after [now] — today if
  /// that time hasn't passed yet, otherwise tomorrow. Used both for the
  /// initial arm ([scheduleCriticalStockAlerts]) and for re-arming a
  /// slot the day after it fires ([_rescheduleCriticalStockAlarmSlot]),
  /// so a slot configured for a time already past today rolls forward
  /// instead of firing immediately or failing silently.
  static DateTime _nextOccurrence(DateTime now, int hour, int minute) {
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// Re-arms [slotIndex]'s exact alarm for the same time tomorrow, based
  /// on whatever `AppSettings` currently says — run once per fire, right
  /// after [executeCriticalStockAlertSlot], from
  /// [criticalStockAlarmCallback]. If the slot was disabled or removed
  /// since it was last armed (e.g. the user deleted slot 3 while its
  /// alarm was still pending), it's simply left canceled: nothing to
  /// re-arm.
  static Future<void> _rescheduleCriticalStockAlarmSlot(Isar isar, int slotIndex) async {
    final settingsRepository = AppSettingsRepository(isar);
    final settings = await settingsRepository.get();
    if (!settings.criticalStockAlertEnabled) return;

    final times = settings.criticalStockAlertTimes;
    if (slotIndex >= times.length) return;

    final time = times[slotIndex];
    await alarmScheduler.scheduleExact(slotIndex, _nextOccurrence(DateTime.now(), time.hour, time.minute));
  }

  /// The actual work run when [slotIndex]'s exact alarm fires (see
  /// [criticalStockAlarmCallback]). Sends one combined "rekap"
  /// notification covering every product currently at or below its
  /// threshold — never one per product — using a query against live
  /// stock levels rather than the queue-and-suppress state machine the
  /// old workmanager-ticker design used, so each of the (up to 3) daily
  /// slots independently re-alerts on whatever is still critical, rather
  /// than only the first slot to fire that day. Sends nothing when
  /// nothing is critical, so a slot with no news stays silent.
  static Future<void> executeCriticalStockAlertSlot(Isar isar, int slotIndex) async {
    final settingsRepository = AppSettingsRepository(isar);
    final settings = await settingsRepository.get();
    if (!settings.criticalStockAlertEnabled) return;

    final criticalProducts = (await isar.products.where().findAll())
        .where((product) => !product.isArchived && product.currentStock <= product.minStockThreshold)
        .toList();
    if (criticalProducts.isEmpty) return;

    await sender.showNotification(
      id: criticalStockAlertNotificationId(slotIndex),
      title: 'Stok Kritis',
      body: buildCriticalStockAlertBody(criticalProducts),
      channelId: stockCriticalChannelId,
      channelName: 'Stok Kritis',
      channelDescription: 'Peringatan stok kritis',
      highImportance: true,
      payload: _payloadCriticalStock,
    );
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
  /// on the same day — the tolerance window the daily summary's
  /// workmanager-driven periodic tick is checked against, since the OS
  /// may run that task early/late depending on battery optimization/Doze
  /// state. The critical-stock alert no longer needs this: its exact
  /// alarms fire (and are checked) only at their configured moment.
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
      restockLeadTimeDays: settings.restockLeadTimeDays,
      restockCoverDays: settings.restockCoverDays,
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
/// in [NotificationService.initialize]. Only handles the daily summary now
/// — the critical-stock alert runs on exact alarms instead (see
/// [criticalStockAlarmCallback]).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final isar = await IsarService.open();
    switch (task) {
      case _dailySummaryTaskName:
        await NotificationService.executeDailySummaryTask(isar);
    }
    return true;
  });
}

/// AndroidAlarmManager entry point for a critical-stock-alert slot: runs
/// in the alarm service's own background isolate, with no access to the
/// main isolate's [IsarService] cache, so it reopens Isar itself — same
/// reasoning as [callbackDispatcher]. `alarmId` is whatever was passed to
/// [AndroidAlarmManager.oneShotAt] ([_criticalStockAlertAlarmId]); the
/// slot index is recovered from it since `params` isn't needed for
/// anything else here.
@pragma('vm:entry-point')
Future<void> criticalStockAlarmCallback(int alarmId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final slotIndex = alarmId - _criticalStockAlertBaseAlarmId;
  final isar = await IsarService.open();
  await NotificationService.executeCriticalStockAlertSlot(isar, slotIndex);
  await NotificationService._rescheduleCriticalStockAlarmSlot(isar, slotIndex);
}
