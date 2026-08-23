/// How long an off-device export may go stale before the app reminds the
/// user to make a new one.
///
/// The clock this threshold applies to is `AppSettings.lastExportedAt` —
/// the moment a backup file actually *left the phone* via the share sheet
/// — never `lastGeneratedAt`. Auto-backups run daily and write into
/// app-specific external storage, which dies with the phone and carries no
/// photos; letting one reset this timer would mean the reminder never
/// fires for exactly the user who needs it.
const staleExportThreshold = Duration(days: 14);

/// Grace period before the very first reminder on an install that has
/// never exported anything (`lastExportedAt == null`).
///
/// A brand-new install is genuinely un-backed-up and is the user who most
/// needs the nudge, but firing on day 0 — while they are still entering
/// their first products and have nothing worth saving — reads as noise and
/// trains them to dismiss the notification. So the first reminder is due
/// half a cycle after the app first observed the install
/// ([firstSeenAt]), i.e. well within the first 14-day cycle, and every
/// reminder after that follows the normal cadence.
const firstExportGracePeriod = Duration(days: 7);

/// The outcome of the staleness check.
///
/// * [isStale] — whether the off-device export is older than the
///   threshold at all (`null` export counts as stale). Describes the data,
///   independent of notification timing.
/// * [shouldNotifyNow] — whether a reminder is actually due to be sent at
///   `now`, which additionally respects the grace period and the
///   don't-repeat-within-a-cycle rule.
/// * [nextReminderAt] — when the next reminder becomes due. When
///   [shouldNotifyNow] is true this is one full cycle after `now` (the
///   caller is about to send one); otherwise it is the moment the pending
///   reminder comes due.
typedef BackupReminderDecision = ({
  bool isStale,
  bool shouldNotifyNow,
  DateTime nextReminderAt,
});

/// Whether the user should be reminded, at [now], to make an off-device
/// backup.
///
/// * [lastExportedAt] — `AppSettings.lastExportedAt`, or `null` if the
///   user has never exported. The ONLY staleness clock (see
///   [staleExportThreshold]).
/// * [lastRemindedAt] — when this reminder last fired, or `null` if it
///   never has. Drives the repeat cadence: a still-unexported install is
///   reminded again one [threshold] after the previous reminder, rather
///   than firing once and going silent, or firing on every single check.
/// * [firstSeenAt] — when the reminder job first ran on this install,
///   used only as the anchor for [firstExportGracePeriod] when nothing
///   has ever been exported. `null` means "first ever check", which
///   anchors on [now].
///
/// Pure: no clock, no database, no filesystem.
BackupReminderDecision decideBackupReminder({
  required DateTime now,
  required DateTime? lastExportedAt,
  required DateTime? lastRemindedAt,
  required DateTime? firstSeenAt,
  Duration threshold = staleExportThreshold,
  Duration firstReminderGrace = firstExportGracePeriod,
}) {
  final isStale = lastExportedAt == null || now.difference(lastExportedAt) >= threshold;

  // When the reminder would first be due ignoring any earlier reminder.
  var dueAt = lastExportedAt != null
      ? lastExportedAt.add(threshold)
      : (firstSeenAt ?? now).add(firstReminderGrace);

  // Never remind twice inside one cycle, whichever of the two clocks is
  // later wins.
  if (lastRemindedAt != null) {
    final repeatAt = lastRemindedAt.add(threshold);
    if (repeatAt.isAfter(dueAt)) dueAt = repeatAt;
  }

  final shouldNotifyNow = isStale && !now.isBefore(dueAt);

  return (
    isStale: isStale,
    shouldNotifyNow: shouldNotifyNow,
    nextReminderAt: shouldNotifyNow ? now.add(threshold) : dueAt,
  );
}
