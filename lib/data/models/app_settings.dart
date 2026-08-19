import 'package:isar_community/isar.dart';

part 'app_settings.g.dart';

/// Singleton collection: always exactly one row, at fixed [id] 0.
@collection
class AppSettings {
  Id id = 0;

  late double defaultMinStockThreshold;

  /// When the backup file was last written to app storage.
  ///
  /// The `@Name` annotation pins the Isar property name to its original
  /// `lastBackupAt` so renaming the Dart field does NOT read as
  /// (drop old property + add new one), which would silently null out
  /// this value on every existing device. Do not remove it.
  @Name('lastBackupAt')
  DateTime? lastGeneratedAt;

  /// When a generated backup file last actually left the phone via the
  /// share sheet. `null` = never exported.
  DateTime? lastExportedAt;

  bool dailySummaryEnabled = true;

  int dailySummaryHour = 20;

  int dailySummaryMinute = 0;

  bool criticalStockAlertEnabled = true;

  /// Slot 1 of up to 3 daily times "Alert stok kritis" fires at. Always
  /// set — a fresh install gets one alert time with no extra setup.
  int criticalStockAlertHour1 = 9;

  int criticalStockAlertMinute1 = 0;

  /// Slots 2 and 3 are optional (`null` = not configured). Hour and
  /// minute for a slot are always written together — never read one
  /// without the other outside of [criticalStockAlertTimes].
  int? criticalStockAlertHour2;

  int? criticalStockAlertMinute2;

  int? criticalStockAlertHour3;

  int? criticalStockAlertMinute3;

  /// How many days ahead of running out "Prioritas Kulakan" starts
  /// warning — drives urgency (see `PrioritasKulakanCalculator`). 1-90.
  int restockLeadTimeDays = 3;

  /// How many days of stock a suggested restock quantity should cover —
  /// drives the suggested quantity (see `PrioritasKulakanCalculator`).
  /// 1-90.
  int restockCoverDays = 7;

  /// Whether the one-time "Notifikasi tidak muncul?" OEM battery info
  /// dialog (see `PengaturanScreen`) has already been dismissed. Defaults
  /// to `false` for both fresh installs and legacy rows written before
  /// this field existed (Isar zero-fills a missing bool field to
  /// `false`), so the dialog still shows exactly once for either case.
  bool batteryOptimizationDialogDismissed = false;

  /// Whether the one-time [MutationSnapshotBackfill] — which fills
  /// [StockMutation.sellPriceSnapshot]/[StockMutation.costPriceSnapshot]
  /// on rows recorded before those fields existed — has already run.
  ///
  /// Same reasoning as [batteryOptimizationDialogDismissed]: `false` for
  /// both fresh installs and legacy rows written before this field
  /// existed (Isar zero-fills a missing bool to `false`), so the backfill
  /// runs exactly once for either case. The backfill is idempotent
  /// regardless, so a lost flag costs a redundant pass, not corruption.
  bool mutationPriceSnapshotBackfillDone = false;

  /// When retention last swept the auto-backup directory (see
  /// `AutoBackupService.sweepRetentionIfDue`). `null` = never.
  ///
  /// Deliberately LOCAL ONLY: it is not written to, or read from, the
  /// backup JSON. It describes the state of one phone's backup folder, so
  /// carrying it to another device would only suppress that device's first
  /// sweep for a week. Restoring a backup therefore resets it to `null`,
  /// which is the safe direction — the next start sweeps.
  DateTime? lastRetentionSweepAt;

  /// The 1-3 configured "Alert stok kritis" times, derived from the slot
  /// fields above. Never empty: slot 1 always contributes.
  @ignore
  List<({int hour, int minute})> get criticalStockAlertTimes {
    final times = <({int hour, int minute})>[
      (hour: criticalStockAlertHour1, minute: criticalStockAlertMinute1),
    ];
    if (criticalStockAlertHour2 != null && criticalStockAlertMinute2 != null) {
      times.add((hour: criticalStockAlertHour2!, minute: criticalStockAlertMinute2!));
    }
    if (criticalStockAlertHour3 != null && criticalStockAlertMinute3 != null) {
      times.add((hour: criticalStockAlertHour3!, minute: criticalStockAlertMinute3!));
    }
    return times;
  }
}
