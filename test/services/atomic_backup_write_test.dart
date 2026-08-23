import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('atomic_backup_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  File target(String name) => File(p.join(dir.path, name));

  test('a successful write leaves a complete file at the final path', () async {
    final file = target('inventaris_backup_2026-08-23_10-00-00.json');

    final written = await writeFileAtomically(file, '{"version":1}');

    expect(written.path, file.path);
    expect(await file.readAsString(), '{"version":1}');
    // No temp litter left behind.
    expect(await File('${file.path}$backupTempFileSuffix').exists(), isFalse);
  });

  test('the final path holds nothing until the rename completes', () async {
    final file = target('inventaris_backup_2026-08-23_11-00-00.json');
    final temp = File('${file.path}$backupTempFileSuffix');

    // Stand in for a write killed after the bytes landed but before the
    // rename — the exact window the old plain writeAsString had no
    // protection for.
    await temp.writeAsString('{"partial":');
    expect(await file.exists(), isFalse,
        reason: 'a half-written backup must never occupy the real filename');

    await temp.rename(file.path);
    expect(await file.exists(), isTrue);
  });

  test('a killed write cannot be mistaken for a snapshot by the auto-backup scanner', () async {
    final file = target('inventaris_autobackup_2026-08-23_23-00-00.json');
    final temp = File('${file.path}$backupTempFileSuffix');
    await temp.writeAsString('{"partial":');

    expect(
      parseBackupFileTimestamp(temp.path, prefix: autoBackupFilePrefix),
      isNull,
      reason: 'the temp name must not parse as a backup, or the day counts as backed up',
    );
  });

  test('an existing file survives a failed write', () async {
    final file = target('inventaris_backup_2026-08-23_12-00-00.json');
    await file.writeAsString('{"good":true}');

    // A directory at the temp path makes openWrite fail.
    await Directory('${file.path}$backupTempFileSuffix').create();

    await expectLater(writeFileAtomically(file, '{"new":true}'), throwsA(isA<Object>()));
    expect(await file.readAsString(), '{"good":true}');
  });
}
