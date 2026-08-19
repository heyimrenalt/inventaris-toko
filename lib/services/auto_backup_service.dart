import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/cost_price_adjustment.dart';
import '../data/models/product.dart';
import '../data/models/stock_mutation.dart';
import '../data/repositories/app_settings_repository.dart';
import 'backup_service.dart';

/// Workmanager task name for the unattended backup job. Registered as a
/// periodic task separate from the daily summary's — deliberately, because
/// the daily summary can be switched off in Pengaturan, and losing backups
/// must never be a side effect of turning off a noisy notification.
const autoBackupTaskName = 'autoBackupTask';

/// How often the OS is asked to run [autoBackupTaskName]. Well below the
/// once-a-day cadence the job itself enforces: workmanager periods are
/// inexact and Doze-deferrable, so the job is woken often and decides for
/// itself whether today's snapshot is already taken (see
/// [decideAutoBackup]). Fewer, wider ticks would let a deferred run push a
/// day's snapshot out entirely.
const autoBackupTickFrequency = Duration(hours: 2);

/// Hour of day the job prefers to run at — late enough that the snapshot
/// captures a finished trading day. Only a preference: see
/// [decideAutoBackup] for the two conditions that override it.
const autoBackupPreferredHour = 23;

/// How stale the newest auto-backup has to be before the job stops waiting
/// for [autoBackupPreferredHour] and runs at whatever hour it woke up.
/// Without this the job would skip a whole day whenever no tick happened to
/// land in the preferred hour.
const autoBackupMaxInterval = Duration(hours: 24);

/// Why [decideAutoBackup] declined to write a snapshot. Every branch is
/// named so tests assert on the *reason*, not just on "nothing happened" —
/// the two skip paths that matter (nothing changed vs already done today)
/// are easy to confuse when only the outcome is observable.
enum AutoBackupSkipReason {
  /// Nothing has been written to the database since the last backup of any
  /// kind (manual export included — both stamp `lastGeneratedAt`).
  noChanges,

  /// An auto-backup for today's date already exists.
  alreadyBackedUpToday,

  /// Changes exist and today has no snapshot yet, but it is not
  /// [autoBackupPreferredHour] yet and the newest snapshot is still recent
  /// enough to wait for it.
  waitingForPreferredHour,
}

/// The decision [AutoBackupService.runIfNeeded] acts on, split out as a
/// pure function over plain values so the whole schedule can be tested
/// without a database, a filesystem, or a clock.
sealed class AutoBackupDecision {
  const AutoBackupDecision();
}

class GenerateAutoBackup extends AutoBackupDecision {
  const GenerateAutoBackup();

  @override
  bool operator ==(Object other) => other is GenerateAutoBackup;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'GenerateAutoBackup()';
}

class SkipAutoBackup extends AutoBackupDecision {
  const SkipAutoBackup(this.reason);

  final AutoBackupSkipReason reason;

  @override
  bool operator ==(Object other) => other is SkipAutoBackup && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'SkipAutoBackup(${reason.name})';
}

/// Whether the auto-backup job should write a snapshot right now.
///
/// * [latestChangeAt] — the newest write timestamp anywhere in the database
///   (see [AutoBackupService.latestChangeAt]), or `null` for an empty one.
/// * [lastGeneratedAt] — `AppSettings.lastGeneratedAt`, stamped by *any*
///   backup write, manual export included. Comparing against it (rather
///   than against the newest auto-backup) is what stops the job from
///   re-snapshotting data a manual export just captured.
/// * [newestAutoBackupAt] — timestamp parsed from the newest
///   [autoBackupFilePrefix] file on disk, or `null` if there is none. The
///   files, not a stored field, are the record of what has been written:
///   if retention or the user deletes them, the job correctly notices it
///   has no recent snapshot.
///
/// The ordering of the checks matters. "Nothing changed" is tested first so
/// an idle shop never writes a run of byte-identical files, and the
/// once-per-day guard is tested before the hour so a snapshot already taken
/// at 23:00 isn't taken again at 23:30.
AutoBackupDecision decideAutoBackup({
  required DateTime now,
  required DateTime? lastGeneratedAt,
  required DateTime? latestChangeAt,
  required DateTime? newestAutoBackupAt,
  int preferredHour = autoBackupPreferredHour,
  Duration maxInterval = autoBackupMaxInterval,
}) {
  final hasChanges = latestChangeAt != null &&
      (lastGeneratedAt == null || latestChangeAt.isAfter(lastGeneratedAt));
  if (!hasChanges) return const SkipAutoBackup(AutoBackupSkipReason.noChanges);

  if (newestAutoBackupAt != null && _isSameDay(newestAutoBackupAt, now)) {
    return const SkipAutoBackup(AutoBackupSkipReason.alreadyBackedUpToday);
  }

  // No snapshot at all yet (fresh install, or retention/user wiped them):
  // don't make the first one wait for tonight.
  if (newestAutoBackupAt == null) return const GenerateAutoBackup();

  if (now.hour >= preferredHour) return const GenerateAutoBackup();

  // The preferred hour was missed — the phone was off, or no tick landed in
  // it. Run anyway rather than skipping a day.
  if (now.difference(newestAutoBackupAt) >= maxInterval) return const GenerateAutoBackup();

  return const SkipAutoBackup(AutoBackupSkipReason.waitingForPreferredHour);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Unattended daily backup into app-specific storage.
///
/// Deliberately *not* a replacement for "Cadangkan Data": these snapshots
/// live in a directory that is deleted when the app is uninstalled and hold
/// no photo bytes, so they protect against corrupted or wrongly-deleted
/// data, not against a lost phone. Only a manual export that leaves the
/// phone protects against that.
class AutoBackupService {
  AutoBackupService(this._isar, {BackupService? backupService, this.directory})
      : _backupService = backupService ?? BackupService(_isar);

  final Isar _isar;
  final BackupService _backupService;

  /// Where snapshots are written. `null` means [resolveBackupDirectory] —
  /// tests pass a temp directory instead, since path_provider has no
  /// platform channel under `flutter test`.
  final Directory? directory;

  /// App-specific external storage, falling back to the documents
  /// directory — the same location "Cadangkan Data" writes to, and the same
  /// reason: no runtime storage permission is needed for it, and on Android
  /// 11+ other apps cannot browse it.
  static Future<Directory> resolveBackupDirectory() async {
    final external = await getExternalStorageDirectory();
    return external ?? await getApplicationDocumentsDirectory();
  }

  /// Writes today's snapshot if [decideAutoBackup] says to, and returns the
  /// file it wrote — or `null` when it skipped.
  ///
  /// Never throws: this runs in a background isolate with nobody to show an
  /// error to, and a failed backup must not take down the workmanager task
  /// (which would make the OS back off from scheduling it at all).
  Future<File?> runIfNeeded({DateTime? now}) async {
    try {
      final effectiveNow = now ?? DateTime.now();
      final directory = this.directory ?? await resolveBackupDirectory();
      final settings = await AppSettingsRepository(_isar).get();

      final decision = decideAutoBackup(
        now: effectiveNow,
        lastGeneratedAt: settings.lastGeneratedAt,
        latestChangeAt: await latestChangeAt(),
        newestAutoBackupAt: newestAutoBackupAt(await listAutoBackupFiles(directory)),
      );
      if (decision is! GenerateAutoBackup) return null;

      final file = await _backupService.exportToFile(
        directory: directory,
        now: effectiveNow,
        includePhotos: false,
        fileNamePrefix: autoBackupFilePrefix,
      );

      return file;
    } catch (_) {
      return null;
    }
  }

  /// The newest write timestamp in the database, or `null` if it is empty.
  ///
  /// Covers stock mutations, product edits, and cost-price adjustments.
  /// Deliberately *not* exhaustive: renaming a category (`Category` records
  /// only `createdAt`) and ticking a restock-list item (`isChecked` carries
  /// no timestamp at all) are invisible here, so a day whose only change was
  /// one of those gets no snapshot. That is accepted rather than fixed: the
  /// alternative is a version counter bumped inside every repository write —
  /// including `recordMutation`, the hottest write path in the app — and
  /// such a change is picked up anyway by the next snapshot after any real
  /// mutation. Deleting a product is invisible for the same reason (a
  /// deleted row cannot raise a maximum), which is harmless: the existing
  /// snapshots still contain it, which is what a backup is for.
  Future<DateTime?> latestChangeAt() async {
    final newestMutation = await _isar.stockMutations.where().sortByCreatedAtDesc().findFirst();
    final newestProduct = await _isar.products.where().sortByUpdatedAtDesc().findFirst();
    final newestAdjustment =
        await _isar.costPriceAdjustments.where().sortByAdjustedAtDesc().findFirst();

    final candidates = <DateTime>[
      if (newestMutation != null) newestMutation.createdAt,
      if (newestProduct != null) newestProduct.updatedAt,
      if (newestAdjustment != null) newestAdjustment.adjustedAt,
    ];
    if (candidates.isEmpty) return null;

    return candidates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Every auto-backup file in [directory], oldest first, ordered by the
  /// timestamp in the filename rather than by filesystem mtime — a restore,
  /// a copy, or a sync tool rewrites mtime, but the name is what the
  /// snapshot actually claims about itself.
  ///
  /// Files that do not parse (anything else in the directory, manual
  /// exports included) are dropped.
  static Future<List<File>> listAutoBackupFiles(Directory directory) async {
    if (!await directory.exists()) return const [];

    final dated = <(DateTime, File)>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final timestamp = parseBackupFileTimestamp(entity.path, prefix: autoBackupFilePrefix);
      if (timestamp == null) continue;
      dated.add((timestamp, entity));
    }
    dated.sort((a, b) => a.$1.compareTo(b.$1));

    return [for (final entry in dated) entry.$2];
  }

  /// Timestamp of the newest file in [files] (which [listAutoBackupFiles]
  /// returns oldest first), or `null` when there are none.
  static DateTime? newestAutoBackupAt(List<File> files) => files.isEmpty
      ? null
      : parseBackupFileTimestamp(files.last.path, prefix: autoBackupFilePrefix);
}
