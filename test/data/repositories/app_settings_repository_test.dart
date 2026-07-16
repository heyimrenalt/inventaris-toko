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
    expect(settings.dailySummaryEnabled, isTrue);
    expect(settings.dailySummaryHour, 20);
    expect(settings.dailySummaryMinute, 0);
    expect(settings.criticalStockAlertEnabled, isTrue);
    expect(settings.criticalStockAlertHour1, 9);
    expect(settings.criticalStockAlertMinute1, 0);
    expect(settings.criticalStockAlertHour2, isNull);
    expect(settings.criticalStockAlertMinute2, isNull);
    expect(settings.criticalStockAlertHour3, isNull);
    expect(settings.criticalStockAlertMinute3, isNull);
    expect(settings.criticalStockAlertTimes, [(hour: 9, minute: 0)]);
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

  test('updateDailySummaryEnabled persists the new value', () async {
    await repository.updateDailySummaryEnabled(false);
    final settings = await repository.get();
    expect(settings.dailySummaryEnabled, isFalse);
  });

  test('updateDailySummaryTime persists hour and minute', () async {
    await repository.updateDailySummaryTime(hour: 7, minute: 45);
    final settings = await repository.get();
    expect(settings.dailySummaryHour, 7);
    expect(settings.dailySummaryMinute, 45);
  });

  test('updateCriticalStockAlertEnabled persists the new value', () async {
    await repository.updateCriticalStockAlertEnabled(false);
    final settings = await repository.get();
    expect(settings.criticalStockAlertEnabled, isFalse);
  });

  test('updateCriticalStockAlertSlots with 1 slot persists it and clears slots 2/3', () async {
    await repository.updateCriticalStockAlertSlots([(hour: 7, minute: 15)]);
    final settings = await repository.get();

    expect(settings.criticalStockAlertHour1, 7);
    expect(settings.criticalStockAlertMinute1, 15);
    expect(settings.criticalStockAlertHour2, isNull);
    expect(settings.criticalStockAlertMinute2, isNull);
    expect(settings.criticalStockAlertHour3, isNull);
    expect(settings.criticalStockAlertMinute3, isNull);
    expect(settings.criticalStockAlertTimes, [(hour: 7, minute: 15)]);
  });

  test('updateCriticalStockAlertSlots with 3 slots persists all three in order', () async {
    await repository.updateCriticalStockAlertSlots([
      (hour: 9, minute: 0),
      (hour: 13, minute: 30),
      (hour: 18, minute: 45),
    ]);
    final settings = await repository.get();

    expect(settings.criticalStockAlertTimes, [
      (hour: 9, minute: 0),
      (hour: 13, minute: 30),
      (hour: 18, minute: 45),
    ]);
  });

  test('updateCriticalStockAlertSlots shrinking from 3 to 1 clears the now-unused slots', () async {
    await repository.updateCriticalStockAlertSlots([
      (hour: 9, minute: 0),
      (hour: 13, minute: 30),
      (hour: 18, minute: 45),
    ]);

    await repository.updateCriticalStockAlertSlots([(hour: 10, minute: 0)]);
    final settings = await repository.get();

    expect(settings.criticalStockAlertTimes, [(hour: 10, minute: 0)]);
    expect(settings.criticalStockAlertHour2, isNull);
    expect(settings.criticalStockAlertMinute2, isNull);
    expect(settings.criticalStockAlertHour3, isNull);
    expect(settings.criticalStockAlertMinute3, isNull);
  });

  test('get() heals a legacy row predating the notification fields', () async {
    // Simulates a real upgrade scenario: a row written before Task 10
    // has none of the new fields in its stored bytes, so Isar fills
    // reads past its buffer with each type's raw sentinel — `long.min`
    // for a non-nullable int, in this case — not the model's field
    // initializers (those only apply to objects built fresh in Dart).
    final legacyRow = AppSettings()
      ..id = 0
      ..defaultMinStockThreshold = 5
      ..dailySummaryHour = -9223372036854775808
      ..dailySummaryMinute = -9223372036854775808
      ..dailySummaryEnabled = false
      ..criticalStockAlertEnabled = false;
    await isar.writeTxn(() async {
      await isar.appSettings.put(legacyRow);
    });

    final healed = await repository.get();
    expect(healed.dailySummaryHour, 20);
    expect(healed.dailySummaryMinute, 0);
    expect(healed.dailySummaryEnabled, isTrue);
    expect(healed.criticalStockAlertEnabled, isTrue);
    expect(healed.criticalStockAlertHour1, 9);
    expect(healed.criticalStockAlertMinute1, 0);

    // Persisted, not just returned in-memory.
    final reread = await isar.appSettings.get(0);
    expect(reread!.dailySummaryHour, 20);
  });

  test('get() heals a row predating just the "Alert stok kritis" slot fields', () async {
    // A row written after Task 10 but before the multi-jam-terjadwal slot
    // fields existed: dailySummaryHour/Minute are already valid, but
    // criticalStockAlertHour1/Minute1 hit the same missing-field sentinel.
    final legacyRow = AppSettings()
      ..id = 0
      ..defaultMinStockThreshold = 5
      ..dailySummaryHour = 20
      ..dailySummaryMinute = 0
      ..dailySummaryEnabled = true
      ..criticalStockAlertEnabled = false
      ..criticalStockAlertHour1 = -9223372036854775808
      ..criticalStockAlertMinute1 = -9223372036854775808;
    await isar.writeTxn(() async {
      await isar.appSettings.put(legacyRow);
    });

    final healed = await repository.get();
    expect(healed.criticalStockAlertHour1, 9);
    expect(healed.criticalStockAlertMinute1, 0);
    expect(healed.criticalStockAlertEnabled, isTrue);
    expect(healed.criticalStockAlertHour2, isNull);
    expect(healed.criticalStockAlertHour3, isNull);
  });

  test('get() leaves a valid row untouched', () async {
    await repository.updateDailySummaryTime(hour: 6, minute: 30);
    await repository.updateCriticalStockAlertEnabled(false);
    await repository.updateCriticalStockAlertSlots([(hour: 11, minute: 0), (hour: 21, minute: 0)]);

    final settings = await repository.get();
    expect(settings.dailySummaryHour, 6);
    expect(settings.dailySummaryMinute, 30);
    expect(settings.criticalStockAlertEnabled, isFalse);
    expect(settings.criticalStockAlertTimes, [(hour: 11, minute: 0), (hour: 21, minute: 0)]);
  });
}
