import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/category.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/repository_exceptions.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/services/backup_service.dart';
import 'package:inventaris_toko/services/data_wipe_service.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:inventaris_toko/ui/screens/pengaturan/pengaturan_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';
import '../produk/fake_photo_storage_service.dart';

/// Avoids touching the real flutter_local_notifications plugin channel
/// (unavailable in `flutter test`) whenever "Hapus semua data" calls
/// through to [NotificationService.cancelAll].
class _FakeNotificationSender implements NotificationSender {
  int cancelAllCallCount = 0;

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required bool highImportance,
    String? payload,
  }) async {}

  @override
  Future<void> cancelAllNotifications() async {
    cancelAllCallCount++;
  }
}

/// Always throws, so a widget test can drive "Hapus semua data"'s
/// failure-dialog path without needing a real Isar failure.
class _ThrowingDataWipeService implements DataWipeService {
  @override
  Future<void> wipeAll() async {
    throw Exception('simulated wipe failure');
  }
}

/// Always throws from [exportToFile], so a widget test can drive
/// "Cadangkan Data"'s failure SnackBar without a real file-system failure.
class _ThrowingExportBackupService extends BackupService {
  _ThrowingExportBackupService(super.isar);

  @override
  Future<File> exportToFile({required Directory directory, DateTime? now}) async {
    throw Exception('simulated export failure');
  }
}

/// Always throws [BackupRestoreException] from [importBackup] (after a
/// real, always-successful [validateAndParse]), so a widget test can drive
/// "Pulihkan Data"'s two distinct failure-dialog messages (rollback
/// succeeded vs. rollback also failed) without a real Isar failure.
class _ThrowingImportBackupService extends BackupService {
  _ThrowingImportBackupService(super.isar, {required this.rollbackSucceeded});

  final bool rollbackSucceeded;

  @override
  Future<Map<String, dynamic>> validateAndParse(String jsonString) async {
    return {'version': backupSchemaVersion, 'data': <String, dynamic>{}};
  }

  @override
  Future<void> importBackup(Map<String, dynamic> backup) async {
    throw BackupRestoreException(rollbackSucceeded: rollbackSucceeded, cause: 'simulated');
  }
}

/// Test double for [BackupFilePicker]: returns [pathToReturn] (or `null`,
/// simulating the user cancelling the OS picker) without a real
/// file-picker platform channel.
class _FakeBackupFilePicker implements BackupFilePicker {
  _FakeBackupFilePicker({this.pathToReturn});

  String? pathToReturn;
  int callCount = 0;

  @override
  Future<String?> pickJsonFile() async {
    callCount++;
    return pathToReturn;
  }
}

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

/// Same reasoning as [_FakeWorkScheduler], but for the exact per-slot
/// alarms behind "Alert stok kritis" (no real AndroidAlarmManager channel
/// in `flutter test`).
class _FakeAlarmScheduler implements AlarmScheduler {
  final List<int> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> scheduleExact(int slotIndex, DateTime time) async {
    scheduled.add(slotIndex);
  }

  @override
  Future<void> cancel(int slotIndex) async {
    cancelled.add(slotIndex);
  }
}

/// Fakes the exact-alarm runtime permission check so tests can drive both
/// the granted and denied paths without a real platform channel.
class _FakeExactAlarmPermission implements ExactAlarmPermission {
  bool canSchedule = true;
  int requestCount = 0;

  @override
  Future<bool> canScheduleExactAlarms() async => canSchedule;

  @override
  Future<void> requestExactAlarmsPermission() async {
    requestCount++;
  }
}

void main() {
  late Isar isar;
  late _FakeAlarmScheduler fakeAlarmScheduler;
  late _FakeExactAlarmPermission fakeExactAlarmPermission;
  late _FakeNotificationSender fakeNotificationSender;
  late Directory tempDir;

  setUp(() async {
    isar = await openTestIsar();
    NotificationService.scheduler = _FakeWorkScheduler();
    fakeAlarmScheduler = _FakeAlarmScheduler();
    fakeExactAlarmPermission = _FakeExactAlarmPermission();
    fakeNotificationSender = _FakeNotificationSender();
    NotificationService.alarmScheduler = fakeAlarmScheduler;
    NotificationService.exactAlarmPermission = fakeExactAlarmPermission;
    NotificationService.sender = fakeNotificationSender;
    tempDir = await Directory.systemTemp.createTemp('pengaturan_screen_test_');
  });

  tearDown(() async {
    await closeTestIsar(isar);
    await tempDir.delete(recursive: true);
  });

  /// [dismissBatteryDialog] defaults to true so the one-time OEM
  /// battery-optimization dialog (auto-shown when
  /// `AppSettings.batteryOptimizationDialogDismissed` is false) doesn't
  /// cover the screen and intercept every other test's taps — pass
  /// `false` only in tests that specifically exercise that dialog.
  Future<void> pumpScreen(
    WidgetTester tester, {
    bool dismissBatteryDialog = true,
    DataWipeService? dataWipeService,
    BackupService? backupService,
    BackupFilePicker? backupFilePicker,
    VoidCallback? onDataReset,
  }) async {
    if (dismissBatteryDialog) {
      await AppSettingsRepository(isar).dismissBatteryOptimizationDialog();
    }
    await tester.pumpWidget(MaterialApp(
      home: PengaturanScreen(
        isar: isar,
        dataWipeService: dataWipeService,
        backupService: backupService,
        backupFilePicker: backupFilePicker,
        exportDirectoryResolver: () async => tempDir,
        onDataReset: onDataReset,
      ),
    ));
    await settleAfterAsyncWork(tester);
  }

  /// The "Prioritas Kulakan" section (added ahead of "Notifikasi") pushes
  /// the critical-stock-alert controls below the default 600px test
  /// viewport — far enough that they're outside the list's cache extent
  /// and not even built yet, so a plain `tap()`/`find.byKey()` can't reach
  /// them without scrolling there first.
  Future<void> scrollToCriticalStockSection(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('pengaturan_critical_stock_toggle')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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
      await scrollToCriticalStockSection(tester);

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
        await scrollToCriticalStockSection(tester);

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
      await scrollToCriticalStockSection(tester);
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
      await scrollToCriticalStockSection(tester);

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
      await scrollToCriticalStockSection(tester);

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
        await scrollToCriticalStockSection(tester);

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
        await scrollToCriticalStockSection(tester);

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

  // Regression coverage for the restock-setting dialog's controller
  // lifecycle: the dialog used to dispose its TextEditingController
  // immediately after showDialog's Future resolved, which raced the
  // dialog's own exit-transition animation — a real
  // disposed-while-still-listened bug, not just a leak. Fixed by owning
  // the controller through a proper StatefulWidget's initState/dispose
  // instead (see _RestockSettingDialog in pengaturan_screen.dart).
  testWidgets(
    'opening, saving, and reopening the "Peringatan Kulakan" dialog 5 times in a row: no exception',
    (tester) async {
      await tester.runAsync(() async {
        await expectNoFlutterErrors(tester, () async {
          await pumpScreen(tester);

          for (var i = 0; i < 5; i++) {
            await tester.tap(find.byKey(const Key('pengaturan_restock_lead_time_tile')));
            await tester.pumpAndSettle();

            final value = 2 + i;
            await tester.enterText(
              find.byKey(const Key('pengaturan_restock_setting_field')),
              '$value',
            );
            await tester.tap(find.byKey(const Key('pengaturan_restock_setting_save')));
            await settleAfterAsyncWork(tester);

            expect(find.text('$value hari'), findsOneWidget);
          }
        });
      });
    },
  );

  group('Prioritas Kulakan copy', () {
    testWidgets('both rows render their label and description', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);

        expect(find.text(restockLeadTimeLabel), findsOneWidget);
        expect(find.text(restockLeadTimeDescription), findsOneWidget);
        expect(find.text('Perkiraan jumlah stok untuk dikulak'), findsOneWidget);
        expect(find.text(restockCoverDaysDescription), findsOneWidget);
      });
    });

    testWidgets('lead-time dialog result line follows what is typed', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);

        await tester.tap(find.byKey(const Key('pengaturan_restock_lead_time_tile')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('pengaturan_restock_setting_field')), '5');
        await tester.pump();
        expect(
          find.text(
            'Barang ditandai perlu dikulak saat stok diperkirakan tinggal cukup untuk 5 hari.',
          ),
          findsOneWidget,
        );

        // Empty field: the line disappears rather than showing "null hari".
        await tester.enterText(find.byKey(const Key('pengaturan_restock_setting_field')), '');
        await tester.pump();
        expect(find.byKey(const Key('pengaturan_restock_setting_result')), findsNothing);
      });
    });

    testWidgets('cover-days dialog uses its own result sentence', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);

        await tester.tap(find.byKey(const Key('pengaturan_restock_cover_days_tile')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('pengaturan_restock_setting_field')), '10');
        await tester.pump();
        expect(
          find.text('Saran jumlah beli dihitung agar stok cukup untuk 10 hari ke depan.'),
          findsOneWidget,
        );
      });
    });
  });

  group('buildRestockSettingResultText', () {
    test('fills the day count into each template', () {
      expect(
        buildRestockSettingResultText(restockLeadTimeResultTemplate, '3'),
        'Barang ditandai perlu dikulak saat stok diperkirakan tinggal cukup untuk 3 hari.',
      );
      expect(
        buildRestockSettingResultText(restockCoverDaysResultTemplate, ' 7 '),
        'Saran jumlah beli dihitung agar stok cukup untuk 7 hari ke depan.',
      );
    });

    test('returns null for empty, non-numeric, and below-minimum input', () {
      for (final input in ['', '   ', 'abc', '0', '-2']) {
        expect(
          buildRestockSettingResultText(restockLeadTimeResultTemplate, input),
          isNull,
          reason: 'input "$input" should produce no result line',
        );
      }
    });

    test('still describes above-maximum input (validation rejects it on save)', () {
      expect(
        buildRestockSettingResultText(restockCoverDaysResultTemplate, '200'),
        contains('200 hari'),
      );
    });
  });

  group('exact-alarm permission', () {
    testWidgets(
      'turning critical stock alerts on with permission denied shows a dialog instead of scheduling',
      (tester) async {
        await tester.runAsync(() async {
          fakeExactAlarmPermission.canSchedule = false;
          await pumpScreen(tester);
          await scrollToCriticalStockSection(tester);

          // Off then back on: disabling never checks permission (only
          // cancels), so toggling on is what actually exercises the
          // permission-denied path.
          await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
          await settleAfterAsyncWork(tester);
          fakeAlarmScheduler.scheduled.clear();
          await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
          await settleAfterAsyncWork(tester);

          expect(find.text('Izin alarm diperlukan'), findsOneWidget);
          expect(fakeAlarmScheduler.scheduled, isEmpty, reason: 'must not crash into a real exact-alarm call');
        });
      },
    );

    testWidgets('tapping "Buka Pengaturan" in the permission dialog opens the exact-alarm settings',
        (tester) async {
      await tester.runAsync(() async {
        fakeExactAlarmPermission.canSchedule = false;
        await pumpScreen(tester);
        await scrollToCriticalStockSection(tester);

        await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
        await settleAfterAsyncWork(tester);
        await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
        await settleAfterAsyncWork(tester);

        await tester.tap(find.text('Buka Pengaturan'));
        await settleAfterAsyncWork(tester);

        expect(fakeExactAlarmPermission.requestCount, 1);
      });
    });

    testWidgets('turning critical stock alerts on with permission granted schedules normally, no dialog',
        (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await scrollToCriticalStockSection(tester);

        await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
        await settleAfterAsyncWork(tester);
        fakeAlarmScheduler.scheduled.clear();
        await tester.tap(find.byKey(const Key('pengaturan_critical_stock_toggle')));
        await settleAfterAsyncWork(tester);

        expect(find.text('Izin alarm diperlukan'), findsNothing);
        expect(fakeAlarmScheduler.scheduled, isNotEmpty);
      });
    });
  });

  group('battery optimization dialog', () {
    testWidgets('shows automatically on first load when not yet dismissed', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester, dismissBatteryDialog: false);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Notifikasi tidak muncul?'), findsWidgets);
      });
    });

    testWidgets('does not show again once already dismissed', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);

        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    testWidgets('checking "Jangan tampilkan lagi" and closing persists the dismissal', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester, dismissBatteryDialog: false);
        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.byKey(const Key('pengaturan_battery_dialog_dont_show_again')));
        await tester.pump();
        await tester.tap(find.text('Tutup'));
        await settleAfterAsyncWork(tester);

        final settings = await AppSettingsRepository(isar).get();
        expect(settings.batteryOptimizationDialogDismissed, isTrue);
      });
    });

    testWidgets('closing without checking the box does not persist the dismissal', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester, dismissBatteryDialog: false);

        await tester.tap(find.text('Tutup'));
        await settleAfterAsyncWork(tester);

        final settings = await AppSettingsRepository(isar).get();
        expect(settings.batteryOptimizationDialogDismissed, isFalse);
      });
    });

    testWidgets('the "Notifikasi tidak muncul?" tile reopens the dialog on demand', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await tester.scrollUntilVisible(
          find.byKey(const Key('pengaturan_notification_troubleshoot_tile')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('pengaturan_notification_troubleshoot_tile')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
      });
    });
  });

  group('Hapus semua data', () {
    Future<void> scrollToHapusSemuaDataTile(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('pengaturan_hapus_semua_data_tile')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> openStep1(WidgetTester tester) async {
      await scrollToHapusSemuaDataTile(tester);
      await tester.tap(find.byKey(const Key('pengaturan_hapus_semua_data_tile')));
      await tester.pumpAndSettle();
    }

    /// Drives past step 1 ("Lanjutkan") into step 2's type-to-confirm
    /// dialog.
    Future<void> openStep2(WidgetTester tester) async {
      await openStep1(tester);
      await tester.tap(find.byKey(const Key('hapus_semua_data_step1_lanjutkan')));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping the tile shows the step 1 warning dialog', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await openStep1(tester);

        expect(find.text('Hapus semua data?'), findsOneWidget);
        expect(
          find.text('Semua produk, mutasi, kategori, dan pengaturan akan dihapus permanen.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('cancelling step 1 deletes nothing', (tester) async {
      await tester.runAsync(() async {
        final category = await CategoryRepository(isar).create('Snacks');
        await ProductRepository(
          isar,
          StockMutationRepository(isar),
          AppSettingsRepository(isar),
        ).create(name: 'Indomie Goreng', categoryId: category.id, sellPrice: 3000, unit: 'pcs');

        await pumpScreen(tester);
        await openStep1(tester);
        await tester.tap(find.text('Batal'));
        await settleAfterAsyncWork(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(await isar.products.count(), 1);
      });
    });

    testWidgets('cancelling step 2 deletes nothing', (tester) async {
      await tester.runAsync(() async {
        final category = await CategoryRepository(isar).create('Snacks');
        await ProductRepository(
          isar,
          StockMutationRepository(isar),
          AppSettingsRepository(isar),
        ).create(name: 'Indomie Goreng', categoryId: category.id, sellPrice: 3000, unit: 'pcs');

        await pumpScreen(tester);
        await openStep2(tester);
        expect(find.text('Ketik HAPUS untuk konfirmasi'), findsOneWidget);

        await tester.tap(find.text('Batal'));
        await settleAfterAsyncWork(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(await isar.products.count(), 1);
      });
    });

    testWidgets('step 2 confirm button starts disabled with an empty field', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await openStep2(tester);

        final button =
            tester.widget<FilledButton>(find.byKey(const Key('hapus_semua_data_step2_confirm')));
        expect(button.onPressed, isNull);
      });
    });

    testWidgets('typing "hapus" lowercase keeps the confirm button disabled', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await openStep2(tester);

        await tester.enterText(find.byKey(const Key('hapus_semua_data_confirm_field')), 'hapus');
        await tester.pump();

        final button =
            tester.widget<FilledButton>(find.byKey(const Key('hapus_semua_data_step2_confirm')));
        expect(button.onPressed, isNull);
      });
    });

    testWidgets('typing "HAPUS" exactly enables the confirm button', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await openStep2(tester);

        await tester.enterText(find.byKey(const Key('hapus_semua_data_confirm_field')), 'HAPUS');
        await tester.pump();

        final button =
            tester.widget<FilledButton>(find.byKey(const Key('hapus_semua_data_step2_confirm')));
        expect(button.onPressed, isNotNull);
      });
    });

    testWidgets('typing "HAPUS " with a trailing space trims and enables the confirm button',
        (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await openStep2(tester);

        await tester.enterText(find.byKey(const Key('hapus_semua_data_confirm_field')), 'HAPUS ');
        await tester.pump();

        final button =
            tester.widget<FilledButton>(find.byKey(const Key('hapus_semua_data_step2_confirm')));
        expect(button.onPressed, isNotNull);
      });
    });

    testWidgets(
      'confirming a successful wipe clears data, resets settings, shows a SnackBar, and calls onDataReset',
      (tester) async {
        await tester.runAsync(() async {
          final category = await CategoryRepository(isar).create('Snacks');
          await ProductRepository(
            isar,
            StockMutationRepository(isar),
            AppSettingsRepository(isar),
          ).create(name: 'Indomie Goreng', categoryId: category.id, sellPrice: 3000, unit: 'pcs');
          await AppSettingsRepository(isar).updateDailySummaryTime(hour: 6, minute: 30);

          var dataWipedCallCount = 0;
          await pumpScreen(tester, onDataReset: () => dataWipedCallCount++);
          await openStep2(tester);
          await tester.enterText(find.byKey(const Key('hapus_semua_data_confirm_field')), 'HAPUS');
          await tester.pump();
          await tester.tap(find.byKey(const Key('hapus_semua_data_step2_confirm')));
          await settleAfterAsyncWork(tester);

          expect(find.text('Semua data berhasil dihapus.'), findsOneWidget);
          expect(dataWipedCallCount, 1);
          expect(await isar.products.count(), 0);
          expect(await isar.categories.count(), 0);

          final settings = await AppSettingsRepository(isar).get();
          expect(settings.dailySummaryHour, 20, reason: 'settings must reset to defaults');
        });
      },
    );

    testWidgets('a fresh install with no data still succeeds and shows the success SnackBar',
        (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await openStep2(tester);
        await tester.enterText(find.byKey(const Key('hapus_semua_data_confirm_field')), 'HAPUS');
        await tester.pump();
        await tester.tap(find.byKey(const Key('hapus_semua_data_step2_confirm')));
        await settleAfterAsyncWork(tester);

        expect(find.text('Semua data berhasil dihapus.'), findsOneWidget);
      });
    });

    testWidgets('a failed wipe shows an error dialog instead of the success SnackBar',
        (tester) async {
      await tester.runAsync(() async {
        var dataWipedCallCount = 0;
        await pumpScreen(
          tester,
          dataWipeService: _ThrowingDataWipeService(),
          onDataReset: () => dataWipedCallCount++,
        );
        await openStep2(tester);
        await tester.enterText(find.byKey(const Key('hapus_semua_data_confirm_field')), 'HAPUS');
        await tester.pump();
        await tester.tap(find.byKey(const Key('hapus_semua_data_step2_confirm')));
        await settleAfterAsyncWork(tester);

        expect(find.text('Gagal menghapus data'), findsOneWidget);
        expect(find.text('Semua data berhasil dihapus.'), findsNothing);
        expect(dataWipedCallCount, 0);
      });
    });
  });

  group('Cadangkan Data', () {
    Future<void> scrollToCadangkanDataTile(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('pengaturan_cadangkan_data_tile')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows "Belum pernah dicadangkan" when no backup has been made yet', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await scrollToCadangkanDataTile(tester);

        expect(find.text('Belum pernah dicadangkan'), findsOneWidget);
      });
    });

    testWidgets('tapping the tile shows the confirm dialog', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await scrollToCadangkanDataTile(tester);

        await tester.tap(find.byKey(const Key('pengaturan_cadangkan_data_tile')));
        await tester.pumpAndSettle();

        expect(find.text('Cadangkan semua data aplikasi ke file?'), findsOneWidget);
      });
    });

    testWidgets('cancelling the confirm dialog does nothing', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await scrollToCadangkanDataTile(tester);

        await tester.tap(find.byKey(const Key('pengaturan_cadangkan_data_tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Batal'));
        await settleAfterAsyncWork(tester);

        expect(find.text('Belum pernah dicadangkan'), findsOneWidget);
        expect(tempDir.listSync(), isEmpty);
      });
    });

    testWidgets(
      'confirming writes a backup file, updates the subtitle, and shows a success SnackBar',
      (tester) async {
        await tester.runAsync(() async {
          final category = await CategoryRepository(isar).create('Snacks');
          await ProductRepository(
            isar,
            StockMutationRepository(isar),
            AppSettingsRepository(isar),
          ).create(name: 'Indomie Goreng', categoryId: category.id, sellPrice: 3000, unit: 'pcs');

          await pumpScreen(tester);
          await scrollToCadangkanDataTile(tester);

          await tester.tap(find.byKey(const Key('pengaturan_cadangkan_data_tile')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('cadangkan_data_confirm')));
          await settleAfterAsyncWork(tester);

          expect(find.text('Data berhasil dicadangkan'), findsOneWidget);
          expect(find.textContaining('Terakhir dicadangkan:'), findsOneWidget);

          final files = tempDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
          expect(files, isNotEmpty);
          final content = jsonDecode(await files.first.readAsString());
          expect(content['version'], backupSchemaVersion);

          final settings = await AppSettingsRepository(isar).get();
          expect(settings.lastBackupAt, isNotNull);
        });
      },
    );

    testWidgets('a failed export shows the specific error SnackBar, not a success one', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester, backupService: _ThrowingExportBackupService(isar));
        await scrollToCadangkanDataTile(tester);

        await tester.tap(find.byKey(const Key('pengaturan_cadangkan_data_tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cadangkan_data_confirm')));
        await settleAfterAsyncWork(tester);

        expect(find.textContaining('Gagal mencadangkan data:'), findsOneWidget);
        expect(find.text('Data berhasil dicadangkan'), findsNothing);
      });
    });
  });

  group('Pulihkan Data', () {
    Future<void> scrollToPulihkanDataTile(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('pengaturan_pulihkan_data_tile')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping the tile shows the warning dialog', (tester) async {
      await tester.runAsync(() async {
        await pumpScreen(tester);
        await scrollToPulihkanDataTile(tester);

        await tester.tap(find.byKey(const Key('pengaturan_pulihkan_data_tile')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Pulihkan data dari file backup? Semua data saat ini akan DIGANTI '
            'dengan data dari backup. Tindakan ini tidak bisa dibatalkan.',
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('cancelling the warning dialog never opens the file picker', (tester) async {
      await tester.runAsync(() async {
        final fakePicker = _FakeBackupFilePicker();
        await pumpScreen(tester, backupFilePicker: fakePicker);
        await scrollToPulihkanDataTile(tester);

        await tester.tap(find.byKey(const Key('pengaturan_pulihkan_data_tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Batal'));
        await settleAfterAsyncWork(tester);

        expect(fakePicker.callCount, 0);
      });
    });

    testWidgets('the user cancelling the OS file picker does nothing', (tester) async {
      await tester.runAsync(() async {
        final category = await CategoryRepository(isar).create('Snacks');
        await ProductRepository(
          isar,
          StockMutationRepository(isar),
          AppSettingsRepository(isar),
        ).create(name: 'Indomie Goreng', categoryId: category.id, sellPrice: 3000, unit: 'pcs');

        final fakePicker = _FakeBackupFilePicker(pathToReturn: null);
        await pumpScreen(tester, backupFilePicker: fakePicker);
        await scrollToPulihkanDataTile(tester);

        await tester.tap(find.byKey(const Key('pengaturan_pulihkan_data_tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('pulihkan_data_confirm')));
        await settleAfterAsyncWork(tester);

        expect(fakePicker.callCount, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(await isar.products.count(), 1, reason: 'nothing should have been touched');
      });
    });

    Future<void> confirmPulihkan(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('pengaturan_pulihkan_data_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pulihkan_data_confirm')));
      await settleAfterAsyncWork(tester);
    }

    testWidgets('picking invalid (non-JSON) content shows the "File tidak valid" dialog', (tester) async {
      await tester.runAsync(() async {
        final badFile = File('${tempDir.path}/bad.json');
        await badFile.writeAsString('not json at all {{{');

        await pumpScreen(tester, backupFilePicker: _FakeBackupFilePicker(pathToReturn: badFile.path));
        await scrollToPulihkanDataTile(tester);
        await confirmPulihkan(tester);

        expect(find.text('Gagal memulihkan data'), findsOneWidget);
        expect(
          find.text('File tidak valid. Pastikan file ini adalah backup dari aplikasi Inventaris Toko.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('picking JSON with no version field shows the "File tidak valid" dialog', (tester) async {
      await tester.runAsync(() async {
        final file = File('${tempDir.path}/no_version.json');
        await file.writeAsString(jsonEncode({'data': {}}));

        await pumpScreen(tester, backupFilePicker: _FakeBackupFilePicker(pathToReturn: file.path));
        await scrollToPulihkanDataTile(tester);
        await confirmPulihkan(tester);

        expect(
          find.text('File tidak valid. Pastikan file ini adalah backup dari aplikasi Inventaris Toko.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('picking an unsupported version shows the "Versi tidak didukung" dialog', (tester) async {
      await tester.runAsync(() async {
        final file = File('${tempDir.path}/future_version.json');
        await file.writeAsString(jsonEncode({'version': 99, 'data': {}}));

        await pumpScreen(tester, backupFilePicker: _FakeBackupFilePicker(pathToReturn: file.path));
        await scrollToPulihkanDataTile(tester);
        await confirmPulihkan(tester);

        expect(find.text('Versi backup tidak didukung. Perbarui aplikasi.'), findsOneWidget);
      });
    });

    testWidgets(
      'picking a valid backup restores the data, calls onDataReset, and shows a success SnackBar',
      (tester) async {
        await tester.runAsync(() async {
          final settingsRepository = AppSettingsRepository(isar);
          final category = await CategoryRepository(isar).create('Snacks');
          await ProductRepository(
            isar,
            StockMutationRepository(isar),
            settingsRepository,
          ).create(name: 'Indomie Goreng', categoryId: category.id, sellPrice: 3000, unit: 'pcs');

          final backupFile = await BackupService(isar, photoStorageService: FakePhotoStorageService())
              .exportToFile(directory: tempDir, now: DateTime(2026, 1, 1));

          // Simulate "current data is different from the backup" — the
          // whole point of a restore is to replace it.
          await ProductRepository(
            isar,
            StockMutationRepository(isar),
            settingsRepository,
          ).create(name: 'Produk Lain', sellPrice: 1000, unit: 'pcs');
          expect(await isar.products.count(), 2);

          var onDataResetCallCount = 0;
          await pumpScreen(
            tester,
            backupFilePicker: _FakeBackupFilePicker(pathToReturn: backupFile.path),
            onDataReset: () => onDataResetCallCount++,
          );
          await scrollToPulihkanDataTile(tester);
          await confirmPulihkan(tester);

          expect(find.text('Data berhasil dipulihkan'), findsOneWidget);
          expect(onDataResetCallCount, 1);
          expect(await isar.products.count(), 1);
          final restoredProduct = await isar.products.where().findFirst();
          expect(restoredProduct?.name, 'Indomie Goreng');
        });
      },
    );

    testWidgets('an import failure with a successful rollback shows the specific dialog', (tester) async {
      await tester.runAsync(() async {
        // Content is irrelevant: _ThrowingImportBackupService.validateAndParse
        // ignores it, but the file must exist for File.readAsString() to
        // succeed on the way there.
        final file = File('${tempDir.path}/whatever.json');
        await file.writeAsString('{}');

        await pumpScreen(
          tester,
          backupService: _ThrowingImportBackupService(isar, rollbackSucceeded: true),
          backupFilePicker: _FakeBackupFilePicker(pathToReturn: file.path),
        );
        await scrollToPulihkanDataTile(tester);
        await confirmPulihkan(tester);

        expect(
          find.text(
            'Gagal memulihkan data dari backup. Data sebelumnya berhasil '
            'dikembalikan, tidak ada perubahan.',
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('an import failure where rollback also fails shows the unrecoverable-error dialog',
        (tester) async {
      await tester.runAsync(() async {
        final file = File('${tempDir.path}/whatever2.json');
        await file.writeAsString('{}');

        await pumpScreen(
          tester,
          backupService: _ThrowingImportBackupService(isar, rollbackSucceeded: false),
          backupFilePicker: _FakeBackupFilePicker(pathToReturn: file.path),
        );
        await scrollToPulihkanDataTile(tester);
        await confirmPulihkan(tester);

        expect(
          find.text(
            'Gagal memulihkan data. Data sebelumnya juga tidak dapat '
            'dikembalikan. Silakan coba lagi dengan file backup yang valid.',
          ),
          findsOneWidget,
        );
      });
    });
  });
}
