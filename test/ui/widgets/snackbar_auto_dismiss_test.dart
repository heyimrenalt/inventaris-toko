import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Documents a non-obvious Flutter framework behavior that caused a real
/// bug in this app: [SnackBar.persist] defaults to `true` whenever
/// [SnackBar.action] is non-null (see SnackBar's own doc comment on
/// `persist`), and Flutter's own dismiss-timer callback is a no-op when
/// `persist` is true — so a SnackBar with both an action *and* a
/// `duration` silently never auto-dismisses unless `persist: false` is
/// set explicitly. CatatMutasiScreen's and
/// CatatStokKeluarBatchScreen's "Batalkan" undo SnackBars both hit this;
/// see the `persist: false` + accompanying comment at their showSnackBar
/// call sites.
void main() {
  Future<void> pumpSnackBarScreen(
    WidgetTester tester, {
    required bool? persist,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Tersimpan'),
                    duration: const Duration(seconds: 5),
                    persist: persist,
                    action: SnackBarAction(label: 'Batalkan', onPressed: () {}),
                  ),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Show'));
    // The entrance animation must fully complete (default ~250ms) before
    // Flutter's ScaffoldMessengerState even creates its dismiss Timer, so
    // this must be its own pump with a matching duration before the
    // 5-second wait below.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'a SnackBar with an action and persist: false auto-dismisses after its duration',
    (tester) async {
      await pumpSnackBarScreen(tester, persist: false);

      expect(find.text('Tersimpan'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      // The dismiss Timer fires mid-elapse above (triggering the exit
      // animation's reverse()), but the exit animation itself still needs
      // its own duration ticked forward via a real pump — a bare pump()
      // processes a frame at the *same* clock instant and leaves the
      // widget mid-animation, still in the tree.
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tersimpan'), findsNothing);
    },
  );

  testWidgets(
    'a SnackBar with an action and persist left at its default (true) never auto-dismisses',
    (tester) async {
      // persist: null here reproduces the exact bug: SnackBar's own
      // constructor computes `persist = persist ?? action != null`, so
      // leaving it unset defaults to true whenever action is provided.
      await pumpSnackBarScreen(tester, persist: null);

      expect(find.text('Tersimpan'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      // Still showing — this is the bug, kept here as documentation of
      // why persist: false is required, not something to fix.
      expect(find.text('Tersimpan'), findsOneWidget);
    },
  );
}
