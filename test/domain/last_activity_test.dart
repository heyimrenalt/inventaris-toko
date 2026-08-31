import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/domain/last_activity.dart';

void main() {
  group('resolveLastActivityLabel', () {
    test('formats a single timestamp in Indonesian short form', () {
      expect(
        resolveLastActivityLabel([DateTime(2026, 8, 25, 14, 30)]),
        '25 Agu 2026',
      );
    });

    test('picks the newest timestamp when several are present', () {
      expect(
        resolveLastActivityLabel([
          DateTime(2026, 1, 3),
          DateTime(2026, 5, 17),
          DateTime(2025, 12, 31),
        ]),
        '17 Mei 2026',
      );
    });

    test('ignores nulls mixed in with real timestamps', () {
      expect(
        resolveLastActivityLabel([null, DateTime(2026, 2, 1), null]),
        '1 Feb 2026',
      );
    });

    test('falls back when there is no activity at all', () {
      expect(resolveLastActivityLabel([null, null, null]), 'Belum ada aktivitas');
      expect(resolveLastActivityLabel(const []), 'Belum ada aktivitas');
      expect(kNoActivityLabel, 'Belum ada aktivitas');
    });

    test('covers every month abbreviation', () {
      final labels = [
        for (var month = 1; month <= 12; month++)
          resolveLastActivityLabel([DateTime(2026, month, 9)]),
      ];
      expect(labels, [
        '9 Jan 2026', '9 Feb 2026', '9 Mar 2026', '9 Apr 2026',
        '9 Mei 2026', '9 Jun 2026', '9 Jul 2026', '9 Agu 2026',
        '9 Sep 2026', '9 Okt 2026', '9 Nov 2026', '9 Des 2026',
      ]);
    });
  });
}
