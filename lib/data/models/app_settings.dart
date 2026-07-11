import 'package:isar_community/isar.dart';

part 'app_settings.g.dart';

/// Singleton collection: always exactly one row, at fixed [id] 0.
@collection
class AppSettings {
  Id id = 0;

  late double defaultMinStockThreshold;

  DateTime? lastBackupAt;
}
