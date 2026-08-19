import 'package:isar_community/isar.dart';

import '../models/app_settings.dart';
import 'repository_exceptions.dart';

/// Singleton row at fixed id 0.
class AppSettingsRepository {
  AppSettingsRepository(this._isar);

  static const int _singletonId = 0;
  static const double _defaultMinStockThreshold = 5;
  static const int _defaultRestockLeadTimeDays = 3;
  static const int _defaultRestockCoverDays = 7;
  static const int minRestockSettingDays = 1;
  static const int maxRestockSettingDays = 90;

  final Isar _isar;

  Future<AppSettings> get() async {
    final existing = await _isar.appSettings.get(_singletonId);
    if (existing != null) {
      return _healLegacyRestockFields(await _healLegacyNotificationFields(existing));
    }

    final defaults = AppSettings()
      ..id = _singletonId
      ..defaultMinStockThreshold = _defaultMinStockThreshold
      ..lastGeneratedAt = null
      ..lastExportedAt = null
      ..dailySummaryEnabled = true
      ..dailySummaryHour = 20
      ..dailySummaryMinute = 0
      ..criticalStockAlertEnabled = true
      ..criticalStockAlertHour1 = 9
      ..criticalStockAlertMinute1 = 0
      ..criticalStockAlertHour2 = null
      ..criticalStockAlertMinute2 = null
      ..criticalStockAlertHour3 = null
      ..criticalStockAlertMinute3 = null
      ..restockLeadTimeDays = _defaultRestockLeadTimeDays
      ..restockCoverDays = _defaultRestockCoverDays;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(defaults);
    });

    return defaults;
  }

  /// A row written before the notification fields existed (Task 10) — or
  /// before the "Alert stok kritis" slot fields existed (multi-jam
  /// terjadwal) — has none of them in its stored bytes. Isar fills reads
  /// past a legacy row's buffer with each type's raw "missing" sentinel —
  /// `long.min` for a non-nullable int field, for instance — not this
  /// model's field initializers, which only run for objects constructed
  /// fresh in Dart. A `dailySummaryHour`/`criticalStockAlertHour1` outside
  /// 0..23 is the tell for that case; when it fires, every notification
  /// field on this row predates the feature, so they're all reset to
  /// their intended defaults in one self-healing write (every real app
  /// install that existed before this task will hit this exactly once, on
  /// its first read after updating).
  Future<AppSettings> _healLegacyNotificationFields(AppSettings settings) async {
    final hasValidTime =
        settings.dailySummaryHour >= 0 &&
        settings.dailySummaryHour <= 23 &&
        settings.dailySummaryMinute >= 0 &&
        settings.dailySummaryMinute <= 59 &&
        settings.criticalStockAlertHour1 >= 0 &&
        settings.criticalStockAlertHour1 <= 23 &&
        settings.criticalStockAlertMinute1 >= 0 &&
        settings.criticalStockAlertMinute1 <= 59;
    if (hasValidTime) {
      return settings;
    }

    settings
      ..dailySummaryEnabled = true
      ..dailySummaryHour = 20
      ..dailySummaryMinute = 0
      ..criticalStockAlertEnabled = true
      ..criticalStockAlertHour1 = 9
      ..criticalStockAlertMinute1 = 0
      ..criticalStockAlertHour2 = null
      ..criticalStockAlertMinute2 = null
      ..criticalStockAlertHour3 = null
      ..criticalStockAlertMinute3 = null;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  /// A row written before "Prioritas Kulakan"'s restock settings existed
  /// has neither field in its stored bytes, so Isar fills reads past its
  /// buffer with the raw `long.min` sentinel — well outside
  /// [minRestockSettingDays]..[maxRestockSettingDays], which is the tell
  /// used here (same approach as
  /// [_healLegacyNotificationFields]).
  Future<AppSettings> _healLegacyRestockFields(AppSettings settings) async {
    final hasValidRestockSettings =
        settings.restockLeadTimeDays >= minRestockSettingDays &&
        settings.restockLeadTimeDays <= maxRestockSettingDays &&
        settings.restockCoverDays >= minRestockSettingDays &&
        settings.restockCoverDays <= maxRestockSettingDays;
    if (hasValidRestockSettings) {
      return settings;
    }

    settings
      ..restockLeadTimeDays = _defaultRestockLeadTimeDays
      ..restockCoverDays = _defaultRestockCoverDays;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> updateDefaultMinStockThreshold(double value) async {
    final settings = await get();
    settings.defaultMinStockThreshold = value;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> updateDailySummaryEnabled(bool value) async {
    final settings = await get();
    settings.dailySummaryEnabled = value;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> updateDailySummaryTime({required int hour, required int minute}) async {
    final settings = await get();
    settings.dailySummaryHour = hour;
    settings.dailySummaryMinute = minute;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> updateCriticalStockAlertEnabled(bool value) async {
    final settings = await get();
    settings.criticalStockAlertEnabled = value;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  /// Replaces all configured "Alert stok kritis" times with [slots]
  /// (1-3 entries, in slot order). Unused slots 2/3 are cleared to
  /// `null` so [AppSettings.criticalStockAlertTimes] reflects exactly
  /// what's passed in.
  Future<AppSettings> updateCriticalStockAlertSlots(List<({int hour, int minute})> slots) async {
    assert(slots.isNotEmpty && slots.length <= 3, 'slots must have 1 to 3 entries');

    final settings = await get();
    settings.criticalStockAlertHour1 = slots[0].hour;
    settings.criticalStockAlertMinute1 = slots[0].minute;
    settings.criticalStockAlertHour2 = slots.length >= 2 ? slots[1].hour : null;
    settings.criticalStockAlertMinute2 = slots.length >= 2 ? slots[1].minute : null;
    settings.criticalStockAlertHour3 = slots.length >= 3 ? slots[2].hour : null;
    settings.criticalStockAlertMinute3 = slots.length >= 3 ? slots[2].minute : null;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> updateRestockLeadTimeDays(int value) async {
    _validateRestockSettingDays(value);
    final settings = await get();
    settings.restockLeadTimeDays = value;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> updateRestockCoverDays(int value) async {
    _validateRestockSettingDays(value);
    final settings = await get();
    settings.restockCoverDays = value;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> updateLastGeneratedAt(DateTime timestamp) async {
    final settings = await get();
    settings.lastGeneratedAt = timestamp;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> updateLastExportedAt(DateTime timestamp) async {
    final settings = await get();
    settings.lastExportedAt = timestamp;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  Future<AppSettings> dismissBatteryOptimizationDialog() async {
    final settings = await get();
    settings.batteryOptimizationDialogDismissed = true;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }

  void _validateRestockSettingDays(int value) {
    if (value < minRestockSettingDays || value > maxRestockSettingDays) {
      throw ValidationException(
        'Nilai harus antara $minRestockSettingDays dan $maxRestockSettingDays hari',
      );
    }
  }
}
