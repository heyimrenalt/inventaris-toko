import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/app_settings.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/services/share_export_outcome.dart';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repositories/test_isar.dart';

/// Mirrors the branch in `PengaturanScreen._cadangkanData`: only a share
/// outcome that [shouldRecordExport] accepts writes `lastExportedAt`.
Future<AppSettings> applyShareResult(
  AppSettingsRepository repository,
  ShareResultStatus status,
  DateTime now,
) async {
  if (shouldRecordExport(status)) {
    return repository.updateLastExportedAt(now);
  }
  return repository.get();
}

void main() {
  late Isar isar;
  late AppSettingsRepository settingsRepository;

  setUp(() async {
    isar = await openTestIsar();
    settingsRepository = AppSettingsRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('share result → lastExportedAt', () {
    test('dismissed does not set lastExportedAt', () async {
      final settings = await applyShareResult(
        settingsRepository,
        ShareResultStatus.dismissed,
        DateTime(2026, 8, 19, 9),
      );

      expect(shouldRecordExport(ShareResultStatus.dismissed), isFalse);
      expect(settings.lastExportedAt, isNull);
      expect((await settingsRepository.get()).lastExportedAt, isNull);
    });

    test('unavailable does not set lastExportedAt', () async {
      final settings = await applyShareResult(
        settingsRepository,
        ShareResultStatus.unavailable,
        DateTime(2026, 8, 19, 9),
      );

      expect(shouldRecordExport(ShareResultStatus.unavailable), isFalse);
      expect(settings.lastExportedAt, isNull);
      expect((await settingsRepository.get()).lastExportedAt, isNull);
    });

    test('success sets lastExportedAt', () async {
      final settings = await applyShareResult(
        settingsRepository,
        ShareResultStatus.success,
        DateTime(2026, 8, 19, 9),
      );

      expect(shouldRecordExport(ShareResultStatus.success), isTrue);
      expect(settings.lastExportedAt, DateTime(2026, 8, 19, 9));
      expect((await settingsRepository.get()).lastExportedAt, DateTime(2026, 8, 19, 9));
    });
  });

  group('@Name annotation regression guard', () {
    test('data stored under the original Isar property name `lastBackupAt` is '
        'still readable via the renamed Dart field', () async {
      await isar.writeTxn(() async {
        await isar.appSettings.put(AppSettings()
          ..id = 0
          ..defaultMinStockThreshold = 5
          ..lastGeneratedAt = DateTime(2026, 6, 1, 10));
      });

      // Query by the Isar-level property name — this only compiles/matches
      // because @Name('lastBackupAt') kept the stored property name stable.
      final byOldPropertyName = await isar.appSettings
          .filter()
          .lastGeneratedAtEqualTo(DateTime(2026, 6, 1, 10))
          .findAll();
      expect(byOldPropertyName, hasLength(1));
      expect(byOldPropertyName.single.lastGeneratedAt, DateTime(2026, 6, 1, 10));

      expect(
        AppSettingsSchema.properties.keys,
        contains('lastBackupAt'),
        reason: 'removing @Name would rename the stored Isar property and '
            'silently null out lastGeneratedAt on existing devices',
      );
      expect(AppSettingsSchema.properties.keys, isNot(contains('lastGeneratedAt')));
    });
  });
}
