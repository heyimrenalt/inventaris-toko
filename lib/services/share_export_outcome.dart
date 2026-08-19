import 'package:share_plus/share_plus.dart';

/// Whether a share-sheet outcome counts as "the backup file actually left
/// the phone", i.e. whether [AppSettings.lastExportedAt] should be stamped.
///
/// KNOWN LIMITATION (deliberate, do not try to solve): a `success` status
/// only means the user picked a target app. If they pick WhatsApp and then
/// cancel inside WhatsApp, this still reports `true`. It is a heuristic,
/// not proof of delivery.
///
/// [ShareResultStatus.unavailable] is treated as NOT exported: the wrong
/// direction is the safer one. A backup reminder that fires after a real
/// export is merely noisy; one that stays silent when nothing was ever
/// exported is exactly the bug this split removes.
bool shouldRecordExport(ShareResultStatus status) =>
    status == ShareResultStatus.success;
