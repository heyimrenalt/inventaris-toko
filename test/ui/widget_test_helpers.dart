import 'package:flutter_test/flutter_test.dart';

/// After tapping something that triggers a real Isar repository call,
/// `pumpAndSettle()` alone won't wait for it: testWidgets() runs inside
/// Flutter's fake-async test zone, and pumpAndSettle() only advances the
/// widget tree's own frame/animation scheduling — it does not wait for an
/// unrelated real Future (Isar's native completion) to resolve. Traced in
/// Task 2 (see kelola_kategori_screen_test.dart): the repository call was
/// still completing *after* pumpAndSettle() had already given up.
///
/// A "wait until no loading spinner" heuristic doesn't generalize either:
/// some actions (e.g. the category dialog's Simpan button) trigger a real
/// repository call with no visual loading indicator at all, so that
/// heuristic exits on the very first frame without waiting at all. So
/// instead this always spends a fixed real wall-clock budget (inside
/// `tester.runAsync()`), pumping between short real delays so any
/// mid-flight setState gets picked up, then does a final pumpAndSettle().
Future<void> settleAfterAsyncWork(
  WidgetTester tester, {
  Duration totalWait = const Duration(milliseconds: 600),
  Duration pollInterval = const Duration(milliseconds: 50),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < totalWait) {
    await tester.pump();
    await Future<void>.delayed(pollInterval);
    elapsed += pollInterval;
  }
  await tester.pumpAndSettle();
}
