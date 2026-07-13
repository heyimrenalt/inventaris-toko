import 'package:flutter/material.dart';

import '../../data/models/stock_mutation.dart';

/// Groups [mutations] by calendar day (time-of-day ignored), preserving
/// insertion order — Dart's default [Map] is a [LinkedHashMap]. Assumes
/// [mutations] is already sorted (e.g. newest-first, as returned by
/// [StockMutationRepository]'s history queries), so each day's bucket
/// stays sorted too. Shared by MutasiScreen and
/// ProductMutationHistoryScreen so both screens group identically.
Map<DateTime, List<StockMutation>> groupMutationsByDay(List<StockMutation> mutations) {
  final grouped = <DateTime, List<StockMutation>>{};
  for (final mutation in mutations) {
    final day = DateTime(
      mutation.createdAt.year,
      mutation.createdAt.month,
      mutation.createdAt.day,
    );
    grouped.putIfAbsent(day, () => []).add(mutation);
  }
  return grouped;
}

/// "Hari ini" for today, "Kemarin" for yesterday, otherwise an absolute
/// "D Month YYYY" date. [day] should be a midnight-normalized date, e.g.
/// a key from [groupMutationsByDay].
String formatDayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (day == today) return 'Hari ini';
  if (day == yesterday) return 'Kemarin';

  const months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  return '${day.day} ${months[day.month - 1]} ${day.year}';
}

/// Day-group section header shown above each day's mutations.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
