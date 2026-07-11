import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/app_settings.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:isar_community/isar.dart';

import 'test_isar.dart';

void main() {
  late Isar isar;
  late AppSettingsRepository repository;

  setUp(() async {
    isar = await openTestIsar();
    repository = AppSettingsRepository(isar);
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  test('get() creates default settings on first call', () async {
    final settings = await repository.get();
    expect(settings.id, 0);
    expect(settings.defaultMinStockThreshold, 5);
    expect(settings.lastBackupAt, isNull);
  });

  test('get() returns the same singleton on subsequent calls', () async {
    final first = await repository.get();
    await repository.updateDefaultMinStockThreshold(12);

    final second = await repository.get();
    expect(second.id, first.id);
    expect(second.defaultMinStockThreshold, 12);

    expect((await isar.appSettings.where().findAll()), hasLength(1));
  });

  test('updateDefaultMinStockThreshold persists the new value', () async {
    await repository.updateDefaultMinStockThreshold(8);
    final settings = await repository.get();
    expect(settings.defaultMinStockThreshold, 8);
  });
}
