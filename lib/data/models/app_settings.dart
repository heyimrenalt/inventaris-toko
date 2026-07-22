import 'package:isar_community/isar.dart';

part 'app_settings.g.dart';

/// Singleton collection: always exactly one row, at fixed [id] 0.
@collection
class AppSettings {
  Id id = 0;

  late double defaultMinStockThreshold;

  DateTime? lastBackupAt;

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
