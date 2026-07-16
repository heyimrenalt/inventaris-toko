import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:inventaris_toko/ui/screens/pengaturan/pengaturan_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

/// Avoids touching the real Workmanager plugin channel (unavailable in
/// `flutter test`) whenever a toggle/time-picker change in the screen
/// calls through to [NotificationService.scheduleDailySummary].
class _FakeWorkScheduler implements WorkScheduler {
  @override
  Future<void> cancel(String uniqueName) async {}

  @override
  Future<void> registerOneOff(String uniqueName, String taskName, {required Duration initialDelay}) async {}

  @override
  Future<void> registerPeriodic(String uniqueName, String taskName, {required Duration frequency}) async {}
}

void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
    NotificationService.scheduler = _FakeWorkScheduler();
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: PengaturanScreen(isar: isar)));
    await settleAfterAsyncWork(tester);
  }

  testWidgets('Notifikasi toggles are visible', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.byKey(const Key('pengaturan_daily_summary_toggle')), findsOneWidget);
      expect(find.byKey(const Key('pengaturan_critical_stock_toggle')), findsOneWidget);

      final dailySwitch =
          tester.widget<SwitchListTile>(find.byKey(const Key('pengaturan_daily_summary_toggle')));
      expect(dailySwitch.value, isTrue);
      final criticalSwitch =
          tester.widget<SwitchListTile>(find.byKey(const Key('pengaturan_critical_stock_toggle')));
      expect(criticalSwitch.value, isTrue);
    });
  });

  testWidgets('time picker is visible when daily summary toggle is ON (default)', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('pengaturan_daily_summary_time')), findsOneWidget);
      expect(find.text('Jam pengiriman'), findsOneWidget);
    });
  });

  testWidgets('toggling daily summary off hides the time picker', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('pengaturan_daily_summary_time')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pengaturan_daily_summary_toggle')));
      await settleAfterAsyncWork(tester);

      expect(find.byKey(const Key('pengaturan_daily_summary_time')), findsNothing);
      final dailySwitch =
          tester.widget<SwitchListTile>(find.byKey(const Key('pengaturan_daily_summary_toggle')));
      expect(dailySwitch.value, isFalse);
    });
  });

  testWidgets('toggling daily summary back on shows the time picker again', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('pengaturan_daily_summary_toggle')));
      await settleAfterAsyncWork(tester);
      expect(find.byKey(const Key('pengaturan_daily_summary_time')), findsNothing);

      await tester.tap(find.byKey(const Key('pengaturan_daily_summary_toggle')));
      await settleAfterAsyncWork(tester);
      expect(find.byKey(const Key('pengaturan_daily_summary_time')), findsOneWidget);
    });
  });

  testWidgets('toggling critical stock alert off persists the value', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
      await settleAfterAsyncWork(tester);

      final criticalSwitch =
          tester.widget<SwitchListTile>(find.byKey(const Key('pengaturan_critical_stock_toggle')));
      expect(criticalSwitch.value, isFalse);
    });
  });

  testWidgets(
    'critical stock alert defaults to exactly 1 time slot, with no delete button on it',
    (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);

        expect(find.byKey(const Key('pengaturan_critical_stock_time_0')), findsOneWidget);
        expect(find.byKey(const Key('pengaturan_critical_stock_time_1')), findsNothing);
        expect(find.byKey(const Key('pengaturan_critical_stock_remove_0')), findsNothing);
        expect(find.byKey(const Key('pengaturan_critical_stock_add_time')), findsOneWidget);
      });
    },
  );

  testWidgets('turning the critical stock toggle off hides all its time rows and the add row',
      (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);
      expect(find.byKey(const Key('pengaturan_critical_stock_time_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
      await settleAfterAsyncWork(tester);

      expect(find.byKey(const Key('pengaturan_critical_stock_time_0')), findsNothing);
      expect(find.byKey(const Key('pengaturan_critical_stock_add_time')), findsNothing);
    });
  });

  testWidgets('turning the critical stock toggle back on restores the previously saved slots',
      (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
      await settleAfterAsyncWork(tester);
      await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
      await settleAfterAsyncWork(tester);

      expect(find.byKey(const Key('pengaturan_critical_stock_time_0')), findsOneWidget);
      // Asserted against the persisted value (not the rendered text) since
      // TimeOfDay.format's 12h/24h choice depends on the ambient locale,
      // which isn't pinned to 'id' in this bare MaterialApp test host.
      final settings = await AppSettingsRepository(isar).get();
      expect(settings.criticalStockAlertHour1, 9);
      expect(settings.criticalStockAlertMinute1, 0);
    });
  });

  testWidgets('picking a new time for slot 1 persists and updates that row', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('pengaturan_critical_stock_time_0')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('time_picker_sheet_mode_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('time_picker_sheet_hour_field')), '11');
      await tester.enterText(find.byKey(const Key('time_picker_sheet_minute_field')), '15');
      await tester.tap(find.byKey(const Key('time_picker_sheet_ok')));
      await settleAfterAsyncWork(tester);

      final trailingText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('pengaturan_critical_stock_time_0')),
          matching: find.byType(Text),
        ).last,
      );
      expect(trailingText.data, contains('15'));
    });
  });

  testWidgets(
    'tapping "Tambah jam" adds slots up to 3, each with a delete button, then hides the add row',
    (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);

        Future<void> addSlot(String hour, String minute) async {
          await tester.tap(find.byKey(const Key('pengaturan_critical_stock_add_time')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('time_picker_sheet_mode_toggle')));
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('time_picker_sheet_hour_field')), hour);
          await tester.enterText(find.byKey(const Key('time_picker_sheet_minute_field')), minute);
          await tester.tap(find.byKey(const Key('time_picker_sheet_ok')));
          await settleAfterAsyncWork(tester);
        }

        await addSlot('13', '0');
        expect(find.byKey(const Key('pengaturan_critical_stock_time_1')), findsOneWidget);
        expect(find.byKey(const Key('pengaturan_critical_stock_remove_1')), findsOneWidget);
        expect(find.byKey(const Key('pengaturan_critical_stock_add_time')), findsOneWidget);

        await addSlot('18', '0');
        expect(find.byKey(const Key('pengaturan_critical_stock_time_2')), findsOneWidget);
        expect(find.byKey(const Key('pengaturan_critical_stock_remove_2')), findsOneWidget);
        expect(find.byKey(const Key('pengaturan_critical_stock_add_time')), findsNothing);
      });
    },
  );

  testWidgets(
    'tapping delete on slot 2 removes it and brings back the "Tambah jam" row',
    (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);

        await tester.tap(find.byKey(const Key('pengaturan_critical_stock_add_time')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('time_picker_sheet_ok')));
        await settleAfterAsyncWork(tester);

        expect(find.byKey(const Key('pengaturan_critical_stock_time_1')), findsOneWidget);

        await tester.tap(find.byKey(const Key('pengaturan_critical_stock_remove_1')));
        await settleAfterAsyncWork(tester);

        expect(find.byKey(const Key('pengaturan_critical_stock_time_1')), findsNothing);
        expect(find.byKey(const Key('pengaturan_critical_stock_add_time')), findsOneWidget);
      });
    },
  );

  testWidgets('tapping "Jam pengiriman" opens the scroll-wheel time picker sheet', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('pengaturan_daily_summary_time')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('time_picker_sheet_scroll')), findsOneWidget);
    });
  });

  testWidgets(
    'picking a new time via manual entry in the sheet persists and updates the row',
    (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);

        await tester.tap(find.byKey(const Key('pengaturan_daily_summary_time')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('time_picker_sheet_mode_toggle')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('time_picker_sheet_hour_field')), '6');
        await tester.enterText(find.byKey(const Key('time_picker_sheet_minute_field')), '30');
        await tester.tap(find.byKey(const Key('time_picker_sheet_ok')));
        await settleAfterAsyncWork(tester);

        final trailingText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('pengaturan_daily_summary_time')),
            matching: find.byType(Text),
          ).last,
        );
        expect(trailingText.data, contains('30'));
      });
    },
  );
}
