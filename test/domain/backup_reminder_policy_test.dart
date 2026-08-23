import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/domain/backup_reminder_policy.dart';

void main() {
  final now = DateTime(2026, 8, 23, 10);

  BackupReminderDecision decide({
    DateTime? lastExportedAt,
    DateTime? lastRemindedAt,
    DateTime? firstSeenAt,
  }) =>
      decideBackupReminder(
        now: now,
        lastExportedAt: lastExportedAt,
        lastRemindedAt: lastRemindedAt,
        firstSeenAt: firstSeenAt,
      );

  group('staleness threshold', () {
    test('exported 13 days ago is not stale', () {
      final decision = decide(lastExportedAt: now.subtract(const Duration(days: 13)));
      expect(decision.isStale, isFalse);
      expect(decision.shouldNotifyNow, isFalse);
      expect(decision.nextReminderAt, now.add(const Duration(days: 1)));
    });

    test('exported exactly 14 days ago is stale (boundary)', () {
      final decision = decide(lastExportedAt: now.subtract(const Duration(days: 14)));
      expect(decision.isStale, isTrue);
      expect(decision.shouldNotifyNow, isTrue);
    });

    test('exported 15 days ago is stale', () {
      final decision = decide(lastExportedAt: now.subtract(const Duration(days: 15)));
      expect(decision.isStale, isTrue);
      expect(decision.shouldNotifyNow, isTrue);
    });

    test('one minute short of 14 days is not stale', () {
      final decision = decide(
        lastExportedAt: now.subtract(const Duration(days: 14)).add(const Duration(minutes: 1)),
      );
      expect(decision.isStale, isFalse);
      expect(decision.shouldNotifyNow, isFalse);
    });
  });

  group('never exported', () {
    test('is stale but does not fire on the very first check', () {
      final decision = decide(lastExportedAt: null, firstSeenAt: null);
      expect(decision.isStale, isTrue);
      expect(decision.shouldNotifyNow, isFalse);
      expect(decision.nextReminderAt, now.add(firstExportGracePeriod));
    });

    test('does not fire inside the grace period', () {
      final decision = decide(
        lastExportedAt: null,
        firstSeenAt: now.subtract(const Duration(days: 6)),
      );
      expect(decision.isStale, isTrue);
      expect(decision.shouldNotifyNow, isFalse);
      expect(decision.nextReminderAt, now.add(const Duration(days: 1)));
    });

    test('fires once the grace period has elapsed', () {
      final decision = decide(
        lastExportedAt: null,
        firstSeenAt: now.subtract(firstExportGracePeriod),
      );
      expect(decision.shouldNotifyNow, isTrue);
      expect(decision.nextReminderAt, now.add(staleExportThreshold));
    });
  });

  group('repeat cadence', () {
    test('does not fire again inside the same cycle', () {
      final decision = decide(
        lastExportedAt: now.subtract(const Duration(days: 30)),
        lastRemindedAt: now.subtract(const Duration(days: 3)),
      );
      expect(decision.isStale, isTrue);
      expect(decision.shouldNotifyNow, isFalse);
      expect(decision.nextReminderAt, now.add(const Duration(days: 11)));
    });

    test('fires again a full cycle after the previous reminder', () {
      final decision = decide(
        lastExportedAt: now.subtract(const Duration(days: 40)),
        lastRemindedAt: now.subtract(staleExportThreshold),
      );
      expect(decision.shouldNotifyNow, isTrue);
      expect(decision.nextReminderAt, now.add(staleExportThreshold));
    });

    test('a fresh export silences a previously reminded install', () {
      final decision = decide(
        lastExportedAt: now.subtract(const Duration(days: 1)),
        lastRemindedAt: now.subtract(const Duration(days: 2)),
      );
      expect(decision.isStale, isFalse);
      expect(decision.shouldNotifyNow, isFalse);
    });
  });
}
