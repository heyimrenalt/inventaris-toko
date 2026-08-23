import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/theme/app_theme.dart';
import 'package:inventaris_toko/ui/widgets/app_snack.dart';

/// Pumps a screen with a single button that triggers [onTap] with a
/// context below the Scaffold, so `ScaffoldMessenger.of` resolves.
Future<void> _pumpTrigger(
  WidgetTester tester,
  void Function(BuildContext context) onTap,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => onTap(context),
            child: const Text('trigger'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('trigger'));
  // The entrance animation must fully complete before the SnackBar is
  // interactive and before ScaffoldMessengerState arms its dismiss Timer
  // — see snackbar_auto_dismiss_test.dart for the same idiom.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

SnackBar _shownSnackBar(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

void main() {
  group('AppSnack', () {
    testWidgets('success renders a SnackBar on the success colour', (
      tester,
    ) async {
      await _pumpTrigger(tester, (context) => AppSnack.success(context, 'ok'));

      expect(find.text('ok'), findsOneWidget);
      expect(_shownSnackBar(tester).backgroundColor, AppColors.successPrimary);
    });

    testWidgets('error renders a SnackBar on the red colour', (tester) async {
      await _pumpTrigger(tester, (context) => AppSnack.error(context, 'gagal'));

      expect(find.text('gagal'), findsOneWidget);
      expect(_shownSnackBar(tester).backgroundColor, AppColors.redPrimary);
    });

    testWidgets('info renders a SnackBar on the neutral colour', (
      tester,
    ) async {
      await _pumpTrigger(tester, (context) => AppSnack.info(context, 'info'));

      expect(find.text('info'), findsOneWidget);
      final background = _shownSnackBar(tester).backgroundColor;
      expect(background, isNot(AppColors.successPrimary));
      expect(background, isNot(AppColors.redPrimary));
    });

    testWidgets('action renders a tappable action that invokes its callback', (
      tester,
    ) async {
      var tapped = 0;
      await _pumpTrigger(
        tester,
        (context) => AppSnack.action(
          context,
          message: 'Mutasi dibatalkan',
          actionLabel: 'Urungkan',
          onAction: () => tapped++,
        ),
      );

      expect(find.text('Mutasi dibatalkan'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Urungkan'), findsOneWidget);

      await tester.tap(find.text('Urungkan'));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('action auto-dismisses after its custom duration', (
      tester,
    ) async {
      await _pumpTrigger(
        tester,
        (context) => AppSnack.action(
          context,
          message: 'Tersimpan',
          actionLabel: 'Batalkan',
          onAction: () {},
          duration: const Duration(seconds: 5),
        ),
      );

      // `persist` has to stay false, otherwise a SnackBar carrying an
      // action ignores its duration and sits there until swiped away.
      expect(_shownSnackBar(tester).persist, isFalse);
      expect(_shownSnackBar(tester).duration, const Duration(seconds: 5));

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tersimpan'), findsNothing);
    });

    testWidgets('every variant inherits the floating pill theme', (
      tester,
    ) async {
      await _pumpTrigger(tester, (context) => AppSnack.success(context, 'ok'));

      final theme = Theme.of(tester.element(find.byType(SnackBar))).snackBarTheme;
      expect(theme.behavior, SnackBarBehavior.floating);
      expect(theme.shape, isA<RoundedRectangleBorder>());
    });
  });
}
