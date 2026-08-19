import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/cost_price_adjustment.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/services/auto_backup_service.dart';
import 'package:inventaris_toko/services/backup_service.dart';
import 'package:isar_community/isar.dart';

import '../data/repositories/test_isar.dart';

/// Every timestamp in this file hangs off one fixed "today" so the
/// day-boundary cases stay readable.
final _today = DateTime(2026, 8, 19);
DateTime _at(int hour, {int day = 19, int minute = 0}) =>
    DateTime(2026, 8, day, hour, minute);

void main() {
  group('decideAutoBackup', () {
    // The pure schedule. No database, no filesystem, no clock.

    test('an empty database is never backed up', () {
      expect(
        decideAutoBackup(
          now: _at(23),
          lastGeneratedAt: null,
          latestChangeAt: null,
          newestAutoBackupAt: null,
        ),
        const SkipAutoBackup(AutoBackupSkipReason.noChanges),
      );
    });

    test('skips when nothing changed since the last backup of any kind', () {
      expect(
        decideAutoBackup(
          now: _at(23),
          lastGeneratedAt: _at(10),
          latestChangeAt: _at(9),
          newestAutoBackupAt: _at(23, day: 18),
        ),
        const SkipAutoBackup(AutoBackupSkipReason.noChanges),
      );
    });

    test('a change exactly at lastGeneratedAt does not count as new', () {
      // The backup captured that write; re-running would only produce a
      // byte-identical file.
      expect(
        decideAutoBackup(
          now: _at(23),
          lastGeneratedAt: _at(10),
          latestChangeAt: _at(10),
          newestAutoBackupAt: _at(23, day: 18),
        ),
        const SkipAutoBackup(AutoBackupSkipReason.noChanges),
      );
    });

    test('a manual export suppresses tonight\'s snapshot when nothing changed after it', () {
      // lastGeneratedAt is stamped by manual exports too — that is the
      // point of comparing against it rather than against the newest
      // auto-backup file.
      expect(
        decideAutoBackup(
          now: _at(23),
          lastGeneratedAt: _at(22),
          latestChangeAt: _at(15),
          newestAutoBackupAt: null,
        ),
        const SkipAutoBackup(AutoBackupSkipReason.noChanges),
      );
    });

    test('generates when changes exist and there has never been a snapshot', () {
      // Deliberately at 08:00: a first snapshot does not wait for tonight.
      expect(
        decideAutoBackup(
          now: _at(8),
          lastGeneratedAt: null,
          latestChangeAt: _at(7),
          newestAutoBackupAt: null,
        ),
        const GenerateAutoBackup(),
      );
    });

    test('generates at the preferred hour', () {
      expect(
        decideAutoBackup(
          now: _at(23),
          lastGeneratedAt: _at(10),
          latestChangeAt: _at(20),
          newestAutoBackupAt: _at(23, day: 18),
        ),
        const GenerateAutoBackup(),
      );
    });

    test('skips a second run later in the same preferred hour', () {
      // 23:00 wrote today's file; the 23:30 tick must not write another.
      expect(
        decideAutoBackup(
          now: _at(23, minute: 30),
          lastGeneratedAt: _at(10),
          latestChangeAt: _at(20),
          newestAutoBackupAt: _at(23),
        ),
        const SkipAutoBackup(AutoBackupSkipReason.alreadyBackedUpToday),
      );
    });

    test('a change made after today\'s snapshot still waits for tomorrow', () {
      // One file per calendar day is the whole retention model; a late
      // sale does not earn a second one.
      expect(
        decideAutoBackup(
          now: _at(23, minute: 45),
          lastGeneratedAt: _at(23),
          latestChangeAt: _at(23, minute: 30),
          newestAutoBackupAt: _at(23),
        ),
        const SkipAutoBackup(AutoBackupSkipReason.alreadyBackedUpToday),
      );
    });

    test('waits for the preferred hour when the last snapshot is still recent', () {
      expect(
        decideAutoBackup(
          now: _at(9),
          lastGeneratedAt: _at(23, day: 18),
          latestChangeAt: _at(8),
          newestAutoBackupAt: _at(23, day: 18),
        ),
        const SkipAutoBackup(AutoBackupSkipReason.waitingForPreferredHour),
      );
    });

    test('runs at any hour once the last snapshot is a full interval old', () {
      // The phone was off at 23:00 yesterday, so no tick landed in the
      // preferred hour. Skipping a day is worse than backing up at 08:00.
      expect(
        decideAutoBackup(
          now: _at(8, day: 20),
          lastGeneratedAt: _at(7, day: 18),
          latestChangeAt: _at(7, day: 20),
          newestAutoBackupAt: _at(7, day: 18),
        ),
        const GenerateAutoBackup(),
      );
    });

    test('the max-interval boundary is inclusive', () {
      expect(
        decideAutoBackup(
          now: _at(7, day: 20),
          lastGeneratedAt: _at(7, day: 18),
          latestChangeAt: _at(6, day: 20),
          newestAutoBackupAt: _at(7, day: 19),
        ),
        const GenerateAutoBackup(),
      );
      expect(
        decideAutoBackup(
          now: _at(6, day: 20, minute: 59),
          lastGeneratedAt: _at(7, day: 18),
          latestChangeAt: _at(6, day: 20),
          newestAutoBackupAt: _at(7, day: 19),
        ),
        const SkipAutoBackup(AutoBackupSkipReason.waitingForPreferredHour),
      );
    });

    test('"same day" is calendar-based, not 24-hours-based', () {
      // 00:30 and 23:00 on the same date are 22.5h apart but still one day:
      // a snapshot taken just after midnight is today's.
      expect(
        decideAutoBackup(
          now: _at(23),
          lastGeneratedAt: _at(0, minute: 30),
          latestChangeAt: _at(20),
          newestAutoBackupAt: _at(0, minute: 30),
        ),
        const SkipAutoBackup(AutoBackupSkipReason.alreadyBackedUpToday),
      );
    });

    test('a snapshot from the same day-of-month a year earlier is not today', () {
      expect(
        decideAutoBackup(
          now: _at(9),
          lastGeneratedAt: DateTime(2025, 8, 19, 9),
          latestChangeAt: _at(8),
          newestAutoBackupAt: DateTime(2025, 8, 19, 9),
        ),
        const GenerateAutoBackup(),
      );
    });
  });

  group('parseBackupFileTimestamp', () {
    test('round-trips whatever formatBackupFileTimestamp writes', () {
      final stamp = DateTime(2026, 8, 19, 23, 5, 7);
      final name = '$autoBackupFilePrefix${formatBackupFileTimestamp(stamp)}.json';

      expect(parseBackupFileTimestamp(name, prefix: autoBackupFilePrefix), stamp);
    });

    test('accepts a full path, not just a bare filename', () {
      final stamp = DateTime(2026, 1, 2, 3, 4, 5);
      final path = '/data/user/0/app/files/'
          '$autoBackupFilePrefix${formatBackupFileTimestamp(stamp)}.json';

      expect(parseBackupFileTimestamp(path, prefix: autoBackupFilePrefix), stamp);
    });

    test('the two prefixes never match each other', () {
      final stamp = formatBackupFileTimestamp(DateTime(2026, 8, 19, 23));

      expect(
        parseBackupFileTimestamp('$manualBackupFilePrefix$stamp.json',
            prefix: autoBackupFilePrefix),
        isNull,
      );
      expect(
        parseBackupFileTimestamp('$autoBackupFilePrefix$stamp.json',
            prefix: manualBackupFilePrefix),
        isNull,
      );
    });

    test('rejects digits that are not a real date', () {
      // DateTime(2026, 13, 1) silently rolls over to 2027-01-01, so a
      // regex alone would accept this.
      expect(
        parseBackupFileTimestamp('${autoBackupFilePrefix}2026-13-01_00-00-00.json',
            prefix: autoBackupFilePrefix),
        isNull,
      );
      expect(
        parseBackupFileTimestamp('${autoBackupFilePrefix}2026-02-30_00-00-00.json',
            prefix: autoBackupFilePrefix),
        isNull,
      );
    });

    test('rejects malformed names instead of throwing', () {
      for (final name in [
        '${autoBackupFilePrefix}not-a-date.json',
        '${autoBackupFilePrefix}2026-08-19.json',
        '$autoBackupFilePrefix${formatBackupFileTimestamp(_today)}.txt',
        'random.json',
        '',
      ]) {
        expect(parseBackupFileTimestamp(name, prefix: autoBackupFilePrefix), isNull,
            reason: 'name: "$name"');
      }
    });
  });

  group('with a database', () {
    late Isar isar;
    late Directory tempDir;
    late AutoBackupService service;
    late AppSettingsRepository settingsRepository;

    setUp(() async {
      isar = await openTestIsar();
      tempDir = await Directory.systemTemp.createTemp('auto_backup_test_');
      settingsRepository = AppSettingsRepository(isar);
      service = AutoBackupService(isar, directory: tempDir);
    });

    tearDown(() async {
      await closeTestIsar(isar);
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> putProduct({required DateTime updatedAt, String name = 'Beras'}) async {
      await isar.writeTxn(() async {
        await isar.products.put(Product()
          ..name = name
          ..sellPrice = 12000
          ..unit = 'pcs'
          ..currentStock = 10
          ..minStockThreshold = 2
          ..createdAt = updatedAt
          ..updatedAt = updatedAt);
      });
    }

    Future<void> putMutation({required DateTime createdAt}) async {
      await isar.writeTxn(() async {
        await isar.stockMutations.put(StockMutation()
          ..productId = 1
          ..type = StockMutationType.stockOut
          ..quantity = 1
          ..stockAfter = 9
          ..createdAt = createdAt);
      });
    }

    Future<void> putAdjustment({required DateTime adjustedAt}) async {
      await isar.writeTxn(() async {
        await isar.costPriceAdjustments.put(CostPriceAdjustment()
          ..productId = 1
          ..oldCost = 100
          ..newCost = 120
          ..adjustedAt = adjustedAt);
      });
    }

    Future<File> writeAutoBackupFile(DateTime stamp) async {
      final file = File(
        '${tempDir.path}/$autoBackupFilePrefix${formatBackupFileTimestamp(stamp)}.json',
      );
      await file.writeAsString('{}');
      return file;
    }

    group('latestChangeAt', () {
      test('is null for an empty database', () async {
        expect(await service.latestChangeAt(), isNull);
      });

      test('is the newest timestamp across all three tracked collections', () async {
        await putProduct(updatedAt: _at(9));
        await putMutation(createdAt: _at(17));
        await putAdjustment(adjustedAt: _at(13));

        expect(await service.latestChangeAt(), _at(17));
      });

      test('sees a product edit even with no mutations at all', () async {
        await putProduct(updatedAt: _at(11));

        expect(await service.latestChangeAt(), _at(11));
      });

      test('sees a cost-price adjustment as the newest change', () async {
        await putMutation(createdAt: _at(9));
        await putAdjustment(adjustedAt: _at(21));

        expect(await service.latestChangeAt(), _at(21));
      });
    });

    group('listAutoBackupFiles', () {
      test('is empty for a directory that does not exist', () async {
        final missing = Directory('${tempDir.path}/nope');

        expect(await AutoBackupService.listAutoBackupFiles(missing), isEmpty);
      });

      test('ignores manual exports and unrelated files', () async {
        await writeAutoBackupFile(_at(23, day: 18));
        await File('${tempDir.path}/$manualBackupFilePrefix'
                '${formatBackupFileTimestamp(_at(10))}.json')
            .writeAsString('{}');
        await File('${tempDir.path}/notes.txt').writeAsString('hi');

        final files = await AutoBackupService.listAutoBackupFiles(tempDir);

        expect(files, hasLength(1));
        expect(files.single.path, contains(autoBackupFilePrefix));
      });

      test('orders by the timestamp in the name, not by mtime', () async {
        // Written newest-first so filesystem order and mtime both disagree
        // with the intended ordering.
        await writeAutoBackupFile(_at(23, day: 19));
        await writeAutoBackupFile(_at(23, day: 17));
        await writeAutoBackupFile(_at(23, day: 18));

        final files = await AutoBackupService.listAutoBackupFiles(tempDir);
        final stamps = [
          for (final f in files) parseBackupFileTimestamp(f.path, prefix: autoBackupFilePrefix),
        ];

        expect(stamps, [_at(23, day: 17), _at(23, day: 18), _at(23, day: 19)]);
      });

      test('newestAutoBackupAt reads the last entry, and is null when empty', () async {
        expect(AutoBackupService.newestAutoBackupAt(const []), isNull);

        await writeAutoBackupFile(_at(23, day: 17));
        await writeAutoBackupFile(_at(23, day: 19));

        final files = await AutoBackupService.listAutoBackupFiles(tempDir);

        expect(AutoBackupService.newestAutoBackupAt(files), _at(23, day: 19));
      });
    });

    group('runIfNeeded', () {
      test('writes an auto-prefixed snapshot when changes exist', () async {
        await putProduct(updatedAt: _at(20));

        final file = await service.runIfNeeded(now: _at(23));

        expect(file, isNotNull);
        expect(file!.path, contains(autoBackupFilePrefix));
        expect(await file.exists(), isTrue);
        expect(await AutoBackupService.listAutoBackupFiles(tempDir), hasLength(1));
      });

      test('the snapshot carries no photo bytes', () async {
        await isar.writeTxn(() async {
          await isar.products.put(Product()
            ..name = 'Beras'
            ..photoPath = '/data/photos/beras.jpg'
            ..sellPrice = 12000
            ..unit = 'pcs'
            ..currentStock = 10
            ..minStockThreshold = 2
            ..createdAt = _at(20)
            ..updatedAt = _at(20));
        });

        final file = await service.runIfNeeded(now: _at(23));
        final decoded = jsonDecode(await file!.readAsString()) as Map<String, dynamic>;
        final product = ((decoded['data'] as Map)['products'] as List).single as Map;

        expect(product['photoBase64'], isNull);
        // The path is kept so the snapshot still points at the photo files,
        // which live in the same app storage and share its lifetime.
        expect(product['photoPath'], '/data/photos/beras.jpg');
      });

      test('stamps lastGeneratedAt so the next tick sees no changes', () async {
        await putProduct(updatedAt: _at(20));

        expect(await service.runIfNeeded(now: _at(23)), isNotNull);
        expect((await settingsRepository.get()).lastGeneratedAt, _at(23));
      });

      test('writes nothing when the database has not changed', () async {
        await putProduct(updatedAt: _at(9));
        await settingsRepository.updateLastGeneratedAt(_at(10));

        expect(await service.runIfNeeded(now: _at(23)), isNull);
        expect(await AutoBackupService.listAutoBackupFiles(tempDir), isEmpty);
      });

      test('a second tick the same day writes no second file', () async {
        await putProduct(updatedAt: _at(20));
        expect(await service.runIfNeeded(now: _at(23)), isNotNull);

        await putMutation(createdAt: _at(23, minute: 20));

        expect(await service.runIfNeeded(now: _at(23, minute: 30)), isNull);
        expect(await AutoBackupService.listAutoBackupFiles(tempDir), hasLength(1));
      });

      test('the next day writes a second file', () async {
        await putProduct(updatedAt: _at(20));
        expect(await service.runIfNeeded(now: _at(23)), isNotNull);

        await putMutation(createdAt: _at(19, day: 20));

        expect(await service.runIfNeeded(now: _at(23, day: 20)), isNotNull);
        expect(await AutoBackupService.listAutoBackupFiles(tempDir), hasLength(2));
      });

      test('does not run before the preferred hour when a recent snapshot exists', () async {
        await putProduct(updatedAt: _at(20, day: 18));
        expect(await service.runIfNeeded(now: _at(23, day: 18)), isNotNull);

        await putMutation(createdAt: _at(8));

        expect(await service.runIfNeeded(now: _at(9)), isNull);
        expect(await AutoBackupService.listAutoBackupFiles(tempDir), hasLength(1));
      });

      test('returns null instead of throwing when the directory is unusable', () async {
        // A file where the directory should be: every write below it fails.
        final blocked = File('${tempDir.path}/blocked');
        await blocked.writeAsString('not a directory');
        final blockedService = AutoBackupService(isar, directory: Directory(blocked.path));
        await putProduct(updatedAt: _at(20));

        expect(await blockedService.runIfNeeded(now: _at(23)), isNull);
      });
    });
  });
}
