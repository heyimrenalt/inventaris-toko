import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/screens/splash_min_duration.dart';

const _minimum = Duration(milliseconds: 1500);

void main() {
  test('holds a fast result back until the minimum has elapsed', () {
    fakeAsync((async) {
      final work = Future<void>.delayed(const Duration(milliseconds: 500))
          .then((_) => 'isar');

      String? resolved;
      withMinimumDuration(work, _minimum).then((value) => resolved = value);

      async.elapse(const Duration(milliseconds: 1499));
      expect(resolved, isNull, reason: 'released before the 1500ms floor');

      async.elapse(const Duration(milliseconds: 1));
      expect(resolved, 'isar');
    });
  });

  test('does not delay a result that arrives after the minimum', () {
    fakeAsync((async) {
      final work = Future<void>.delayed(const Duration(milliseconds: 2000))
          .then((_) => 'isar');

      String? resolved;
      withMinimumDuration(work, _minimum).then((value) => resolved = value);

      async.elapse(const Duration(milliseconds: 1999));
      expect(resolved, isNull);

      async.elapse(const Duration(milliseconds: 1));
      expect(resolved, 'isar', reason: 'held past the work it was waiting on');
    });
  });

  test('propagates an init failure instead of sitting on the floor', () {
    fakeAsync((async) {
      final work = Future<String>.delayed(
        const Duration(milliseconds: 500),
        () => throw StateError('database is corrupt'),
      );

      Object? caught;
      withMinimumDuration(work, _minimum).catchError((Object error) {
        caught = error;
        return '';
      });

      async.elapse(const Duration(milliseconds: 500));
      expect(caught, isStateError);
      expect((caught! as StateError).message, 'database is corrupt');

      // Let the (now pointless) floor timer drain so fakeAsync doesn't
      // report it as a pending timer.
      async.elapse(_minimum);
    });
  });
}
