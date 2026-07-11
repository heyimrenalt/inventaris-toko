import 'package:isar_community/isar.dart';

import '../models/app_settings.dart';

/// Singleton row at fixed id 0.
class AppSettingsRepository {
  AppSettingsRepository(this._isar);

  static const int _singletonId = 0;
  static const double _defaultMinStockThreshold = 5;

  final Isar _isar;

  Future<AppSettings> get() async {
    final existing = await _isar.appSettings.get(_singletonId);
    if (existing != null) {
      return existing;
    }

    final defaults = AppSettings()
      ..id = _singletonId
      ..defaultMinStockThreshold = _defaultMinStockThreshold
      ..lastBackupAt = null;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(defaults);
    });

    return defaults;
  }

  Future<AppSettings> updateDefaultMinStockThreshold(double value) async {
    final settings = await get();
    settings.defaultMinStockThreshold = value;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return settings;
  }
}
