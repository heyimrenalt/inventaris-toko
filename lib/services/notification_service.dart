import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar_community/isar.dart';
import 'package:workmanager/workmanager.dart';

import '../data/isar_service.dart';
import '../data/models/app_settings.dart';
import '../data/models/product.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/stock_mutation_repository.dart';
import '../domain/backup_reminder_policy.dart';
import '../domain/prioritas_kulakan_calculator.dart';
import '../ui/screens/beranda/prioritas_kulakan_screen.dart';
import 'auto_backup_service.dart';

const dailySummaryChannelId = 'channel_daily_summary';
const stockCriticalChannelId = 'channel_stock_critical';
const backupReminderChannelId = 'channel_backup_reminder';

const _dailySummaryTaskName = 'dailySummaryTask';
const _dailySummaryRetryTaskName = 'dailySummaryRetryTask';
const _payloadDailySummary = 'daily_summary';
const _payloadCriticalStock = 'critical_stock';
const _payloadBackupReminder = 'backup_reminder';

/// Workmanager task behind the stale-export reminder. Its own task (not a
/// branch of the auto-backup job) for the same reason the auto-backup job
/// is separate from the daily summary: the two answer different questions
/// — "is today's snapshot taken?" vs "has a backup left the phone
/// lately?" — and neither should be able to switch the other off.
const backupReminderTaskName = 'backupReminderTask';

/// How often the OS is asked to run [backupReminderTaskName]. Daily: the
/// decision it makes has day granularity, and a deferred tick simply
/// pushes one reminder a few hours later, never skips it — the due time
/// is recomputed from stored timestamps on every run.
const backupReminderTickFrequency = Duration(hours: 24);

const _dailySummaryNotificationId = 1;
const backupReminderNotificationId = 2;

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

/// Where tapping a notification takes the user. Both notification kinds
/// this app sends are about restocking, so both land on the same screen;
/// anything else (an unknown or missing payload) just opens the app.
enum NotificationTapDestination { prioritasKulakan, home }

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
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundTapHandler,
    );

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

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        backupReminderChannelId,
        'Pengingat Backup',
        description: 'Pengingat mencadangkan data ke luar HP',
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

  /// Where a notification tap should land, derived purely from its
  /// payload. Split out from the navigation itself so the warm path
  /// ([_onNotificationTap]) and the cold-start path
  /// ([handleNotificationLaunch]) can't drift apart, and so the mapping is
  /// unit-testable without a real notifications plugin.
  static NotificationTapDestination resolveTapDestination(String? payload) {
    switch (payload) {
      case _payloadCriticalStock:
      case _payloadDailySummary:
        return NotificationTapDestination.prioritasKulakan;
      default:
        return NotificationTapDestination.home;
    }
  }

  /// Performs the navigation [resolveTapDestination] selects. No-op when
  /// no navigator is mounted yet — the cold-start path re-runs this after
  /// the first frame instead (see [handleNotificationLaunch]).
  static void navigateForPayload(String? payload) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (resolveTapDestination(payload)) {
      case NotificationTapDestination.prioritasKulakan:
        navigator.push(
          MaterialPageRoute(builder: (_) => PrioritasKulakanScreen(isar: IsarService.instance)),
        );
      case NotificationTapDestination.home:
        navigator.popUntil((route) => route.isFirst);
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    navigateForPayload(response.payload);
  }

  /// Replays the routing for the notification that cold-started the app.
  /// Tapping a notification while the process is dead launches the app
  /// without ever invoking `onDidReceiveNotificationResponse`, so without
  /// this the tap silently lands on the default screen.
  ///
  /// MUST be called after [IsarService.open] has completed —
  /// [navigateForPayload] builds a screen from `IsarService.instance`.
  /// Routing is deferred to the next frame because at this point the
  /// app's `home` is still the loading indicator; by the post-frame
  /// callback the navigator exists and MainScaffold is the route
  /// underneath.
  static Future<void> handleNotificationLaunch() async {
    final launchDetails = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) return;

    final payload = launchDetails?.notificationResponse?.payload;
    WidgetsBinding.instance.addPostFrameCallback((_) => navigateForPayload(payload));
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

  /// Registers the unattended backup job (see [AutoBackupService]).
  ///
  /// Lives here only because this file owns the [WorkScheduler] seam and
  /// [callbackDispatcher]; it is deliberately *not* part of
  /// [scheduleDailySummary] and reads no notification setting, so switching
  /// off "Ringkasan Harian" can never switch off backups as a side effect.
  /// Unconditional and idempotent — `registerPeriodic` uses
  /// `ExistingPeriodicWorkPolicy.update`, so calling it on every launch
  /// keeps the job alive after a force-stop or reboot without restarting
  /// its schedule.
  static Future<void> scheduleAutoBackup() async {
    await scheduler.registerPeriodic(
      autoBackupTaskName,
      autoBackupTaskName,
      frequency: autoBackupTickFrequency,
    );
  }

  /// Registers the daily stale-export reminder check (see
  /// [executeBackupReminderTask]). Unconditional and idempotent for the
  /// same reasons as [scheduleAutoBackup]: this reminder is the last line
  /// of defence against total data loss, so it is not tied to any
  /// notification toggle.
  static Future<void> scheduleBackupReminder() async {
    await scheduler.registerPeriodic(
      backupReminderTaskName,
      backupReminderTaskName,
      frequency: backupReminderTickFrequency,
    );
  }

  /// Runs the stale-export check and, if a reminder is due, sends it.
  ///
  /// Staleness is measured purely from [AppSettings.lastExportedAt] —
  /// stamped only when a generated file actually leaves the phone via the
  /// share sheet. Auto-backups stamp `lastGeneratedAt` instead and are
  /// deliberately invisible here (see [staleExportThreshold]).
  static Future<void> executeBackupReminderTask(Isar isar, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final repository = AppSettingsRepository(isar);
    final settings = await repository.get();

    final decision = decideBackupReminder(
      now: effectiveNow,
      lastExportedAt: settings.lastExportedAt,
      lastRemindedAt: settings.lastBackupReminderAt,
      firstSeenAt: settings.backupReminderFirstSeenAt,
    );

    // Anchor the never-exported grace period on the first run, whether or
    // not anything is sent this time.
    if (settings.backupReminderFirstSeenAt == null) {
      await repository.updateBackupReminderState(firstSeenAt: effectiveNow);
    }

    if (!decision.shouldNotifyNow) return;

    await sender.showNotification(
      id: backupReminderNotificationId,
      title: 'Waktunya backup data Toko Mama',
      body: buildBackupReminderBody(settings.lastExportedAt, effectiveNow),
      channelId: backupReminderChannelId,
      channelName: 'Pengingat Backup',
      channelDescription: 'Pengingat mencadangkan data ke luar HP',
      highImportance: true,
      payload: _payloadBackupReminder,
    );

    await repository.updateBackupReminderState(lastRemindedAt: effectiveNow);
  }

  /// Body for the stale-export reminder. Names how long it has been (or
  /// that it has never happened) so the notification carries the reason,
  /// not just the nag — same shape as the critical-stock body, which
  /// leads with the facts and ends with the action.
  static String buildBackupReminderBody(DateTime? lastExportedAt, DateTime now) {
    if (lastExportedAt == null) {
      return 'Data belum pernah dicadangkan ke luar HP — backup sekarang.';
    }
    final days = now.difference(lastExportedAt).inDays;
    return 'Backup terakhir $days hari lalu — backup sekarang.';
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

  /// How many product names the critical-stock body names outright before
  /// collapsing the rest into "dan N lainnya". Android ellipsizes a long
  /// body anyway, so an unbounded comma-joined list just loses the tail
  /// silently — better to cut it deliberately and keep the real total
  /// visible in the count.
  static const criticalStockAlertNamedProductLimit = 3;

  /// Severity score for ordering the critical list, lowest = most critical.
  /// Uses `currentStock / minStockThreshold` (how deep below minimum, as a
  /// fraction) rather than the absolute gap, so a product's severity is
  /// judged against its own threshold: 0 of 5 outranks 3 of 50, even
  /// though the latter's absolute gap is far larger.
  ///
  /// Deliberately computed from fields already on [Product] — no extra
  /// queries. The richer [PrioritasKulakanCalculator] urgency signal would
  /// need one stock-out history query per product, which is too much work
  /// for an alarm-fire callback.
  static double _criticalStockSeverity(Product product) {
    if (product.currentStock <= 0) return 0;
    if (product.minStockThreshold <= 0) return double.maxFinite;
    return product.currentStock / product.minStockThreshold;
  }

  static String buildCriticalStockAlertBody(List<Product> products) {
    // Most critical first, so a truncated list names the products that
    // actually need attention rather than whatever order the DB returned.
    // Ties break on lower absolute stock, then name, to keep the body
    // stable across fires instead of shuffling between equal products.
    final ordered = List<Product>.of(products)
      ..sort((a, b) {
        final bySeverity = _criticalStockSeverity(a).compareTo(_criticalStockSeverity(b));
        if (bySeverity != 0) return bySeverity;
        final byStock = a.currentStock.compareTo(b.currentStock);
        if (byStock != 0) return byStock;
        return a.name.compareTo(b.name);
      });

    if (ordered.length == 1) {
      return '⚠️ Stok kritis: ${ordered.first.name} habis — segera kulakan, cek sekarang';
    }

    final shown = ordered.take(criticalStockAlertNamedProductLimit);
    final names = shown.map((p) => p.name).join(', ');
    final remaining = ordered.length - criticalStockAlertNamedProductLimit;
    final tail = remaining > 0 ? '$names dan $remaining lainnya' : names;
    return '⚠️ ${ordered.length} barang stok kritis: $tail — segera kulakan, cek sekarang';
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

    final stockOutByProduct = await mutationRepository
        .getStockOutHistoryForProducts(products.map((product) => product.id));

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

/// Notification-tap entry point for taps delivered while the app process
/// isn't in the foreground. Runs in its own background isolate, which has
/// neither the main isolate's navigator nor its [IsarService] cache, so it
/// deliberately does nothing: the tap brings the app up, and
/// [NotificationService.handleNotificationLaunch] does the actual routing
/// once Isar is open. Registering it is still required — without a
/// background handler the plugin can drop the response instead of
/// recording it in the launch details.
@pragma('vm:entry-point')
void notificationBackgroundTapHandler(NotificationResponse response) {}

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
      case autoBackupTaskName:
        await AutoBackupService(isar).runIfNeeded();
      case backupReminderTaskName:
        await NotificationService.executeBackupReminderTask(isar);
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
