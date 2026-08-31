/// Shown on the "Tentang Aplikasi" screen when the database holds no
/// user-written records yet (fresh install).
const String kNoActivityLabel = 'Belum ada aktivitas';

const List<String> _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Resolves the "Terakhir diperbarui" label from the latest write
/// timestamp of each user-data collection.
///
/// [timestamps] may contain nulls (a collection with no rows) and may be
/// empty; the newest non-null one wins. Returns [kNoActivityLabel] when
/// nothing at all has been written yet.
///
/// Formats in Indonesian short form ("25 Agu 2026") without going through
/// `intl`, so it needs no `initializeDateFormatting('id_ID')` — the same
/// hand-rolled month table the rest of the app uses for Indonesian dates.
String resolveLastActivityLabel(Iterable<DateTime?> timestamps) {
  DateTime? latest;
  for (final timestamp in timestamps) {
    if (timestamp == null) continue;
    if (latest == null || timestamp.isAfter(latest)) latest = timestamp;
  }
  if (latest == null) return kNoActivityLabel;

  final local = latest.toLocal();
  return '${local.day} ${_monthAbbreviations[local.month - 1]} ${local.year}';
}
