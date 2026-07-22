import 'package:flutter/material.dart';
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

/// Programmatically triggers a [RefreshIndicator]'s pull-to-refresh
/// sequence (no drag gesture needed) and waits for its real (Isar-backed)
/// `onRefresh` work to finish.
///
/// Deliberately does *not* end with a [WidgetTester.pumpAndSettle] the way
/// [settleAfterAsyncWork] does: while visible, the indicator shows an
/// indeterminate (repeating) spinner, which schedules a new frame forever
/// — `pumpAndSettle()` would time out for as long as it's on screen. Real
/// time is pumped forward directly instead, long enough for both the
/// indicator's own show/hide animation and `onRefresh`'s real async work
/// to complete.
Future<void> triggerRefresh(
  WidgetTester tester, {
  Duration totalWait = const Duration(seconds: 2),
  Duration pollInterval = const Duration(milliseconds: 50),
}) async {
  final refreshFuture =
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
  var elapsed = Duration.zero;
  while (elapsed < totalWait) {
    await tester.pump(pollInterval);
    await Future<void>.delayed(pollInterval);
    elapsed += pollInterval;
  }
  await refreshFuture;
  await tester.pump();
}

/// Runs [body] and fails the test if any exception reaches
/// [FlutterError.onError] while it runs — e.g. a "used after dispose"
/// error, or a disposed-while-still-listened framework assertion, thrown
/// asynchronously (from a callback, an animation tick, or a stream
/// listener) rather than synchronously during `pump()`/`build()`.
///
/// A plain widget test does NOT automatically fail on this class of
/// error: `FlutterError.onError`'s default handler only logs to the
/// console, so a controller/listener lifecycle bug that fires outside
/// the direct pump/build call stack can silently pass. Wrap any test
/// that drives a form submit, a dialog dismissal, or anything else that
/// disposes a controller with this to make that failure explicit and
/// attributable instead of leaving it to slip through.
Future<void> expectNoFlutterErrors(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
    originalOnError?.call(details);
  };

  try {
    await body();
  } finally {
    FlutterError.onError = originalOnError;
  }

  expect(
    errors,
    isEmpty,
    reason: errors.map((e) => e.exceptionAsString()).join('\n---\n'),
  );
}
