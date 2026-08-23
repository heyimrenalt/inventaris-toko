import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/domain/backup_reminder_policy.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:isar_community/isar.dart';

import '../data/repositories/test_isar.dart';

class _FakeSender implements NotificationSender {
  final List<({int id, String title, String body, String channelId, String? payload})> calls = [];

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
  }) async {
    calls.add((id: id, title: title, body: body, channelId: channelId, payload: payload));
  }

  @override
  Future<void> cancelAllNotifications() async {}
}

class _FakeWorkScheduler implements WorkScheduler {
  final List<String> registeredPeriodic = [];

  @override
  Future<void> cancel(String uniqueName) async {}

  @override
  Future<void> registerOneOff(String uniqueName, String taskName, {required Duration initialDelay}) async {}

  @override
  Future<void> registerPeriodic(String uniqueName, String taskName, {required Duration frequency}) async {
    registeredPeriodic.add(uniqueName);
  }
}

void main() {
  late Isar isar;
  late AppSettingsRepository settingsRepository;
  late _FakeSender sender;
  late _FakeWorkScheduler scheduler;

  final now = DateTime(2026, 8, 23, 10);

  setUp(() async {
    isar = await openTestIsar();
    settingsRepository = AppSettingsRepository(isar);
    sender = _FakeSender();
    scheduler = _FakeWorkScheduler();
    NotificationService.sender = sender;
    NotificationService.scheduler = scheduler;
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('registers the daily reminder check unconditionally', () async {
    await NotificationService.scheduleBackupReminder();
    expect(scheduler.registeredPeriodic, contains(backupReminderTaskName));
  });

  test('sends nothing when the export is fresh', () async {
    await settingsRepository.updateLastExportedAt(now.subtract(const Duration(days: 3)));

    await NotificationService.executeBackupReminderTask(isar, now: now);

    expect(sender.calls, isEmpty);
  });

  test('sends a reminder when the export is stale, and stamps the reminder', () async {
    await settingsRepository.updateLastExportedAt(now.subtract(const Duration(days: 14)));

    await NotificationService.executeBackupReminderTask(isar, now: now);

    expect(sender.calls, hasLength(1));
    expect(sender.calls.single.id, backupReminderNotificationId);
    expect(sender.calls.single.title, contains('backup data Toko Mama'));
    expect(sender.calls.single.body, contains('backup sekarang'));
    expect(sender.calls.single.channelId, backupReminderChannelId);

    final settings = await settingsRepository.get();
    expect(settings.lastBackupReminderAt, now);
  });

  test('an auto-backup does not reset the staleness clock', () async {
    await settingsRepository.updateLastExportedAt(now.subtract(const Duration(days: 20)));
    // What the unattended job stamps: a snapshot that never left the phone.
    await settingsRepository.updateLastGeneratedAt(now);

    await NotificationService.executeBackupReminderTask(isar, now: now);

    expect(sender.calls, hasLength(1), reason: 'staleness must be measured from lastExportedAt');
  });

  test('never exported: first run only anchors, second run inside grace stays silent', () async {
    await NotificationService.executeBackupReminderTask(isar, now: now);
    expect(sender.calls, isEmpty);

    final settings = await settingsRepository.get();
    expect(settings.backupReminderFirstSeenAt, now);

    await NotificationService.executeBackupReminderTask(
      isar,
      now: now.add(const Duration(days: 6)),
    );
    expect(sender.calls, isEmpty);
  });

  test('never exported: fires once the grace period has elapsed', () async {
    await NotificationService.executeBackupReminderTask(isar, now: now);
    await NotificationService.executeBackupReminderTask(
      isar,
      now: now.add(firstExportGracePeriod),
    );

    expect(sender.calls, hasLength(1));
    expect(sender.calls.single.body, contains('belum pernah dicadangkan'));
  });

  test('repeats on the same cadence while the export stays stale', () async {
    await settingsRepository.updateLastExportedAt(now.subtract(const Duration(days: 14)));

    await NotificationService.executeBackupReminderTask(isar, now: now);
    // A day later: still stale, but inside the cycle — silent.
    await NotificationService.executeBackupReminderTask(
      isar,
      now: now.add(const Duration(days: 1)),
    );
    expect(sender.calls, hasLength(1));

    await NotificationService.executeBackupReminderTask(
      isar,
      now: now.add(staleExportThreshold),
    );
    expect(sender.calls, hasLength(2));
  });
}
