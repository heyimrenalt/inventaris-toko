import '../data/models/stock_mutation.dart';

class VelocityResult {
  const VelocityResult({
    required this.dailyVelocity,
    required this.stockOutCount,
    required this.dataAgeDays,
  });

  final double dailyVelocity;

  /// Number of real stockOut mutations the estimate is based on — undo
  /// compensating entries (see [VelocityCalculator]) are not counted.
  final int stockOutCount;

  /// `min(30, days since the earliest counted stockOut mutation)`, for a
  /// UI caption like "berdasarkan rata-rata {dataAgeDays} hari terakhir".
  /// 0 when there's no counted stockOut history at all.
  final int dataAgeDays;
}

/// Weighted daily sell-rate estimator feeding "Prioritas Kulakan".
///
/// v2: blends a recent 30-day rate with the all-time rate (70/30) so a
/// burst or lull in the last month moves the estimate without being
/// swamped by months-old history.
class VelocityCalculator {
  const VelocityCalculator();

  static const int recentWindowDays = 30;
  static const double recentWeight = 0.7;
  static const double allTimeWeight = 0.3;

  /// Undo is append-only (see [StockMutationRepository.undoMutation]):
  /// there's no soft-delete/undone flag on [StockMutation]. Undoing a
  /// stockOut records a compensating stockIn (already excluded, since
  /// callers only pass stockOut mutations in), but undoing a stockIn
  /// records a compensating *stockOut* — an inventory correction, not a
  /// real sale. The only signal that distinguishes it is the
  /// "Dibatalkan: " note prefix [StockMutationRepository.undoMutation]
  /// tags it with, so it's excluded here.
  static const String _undoNotePrefix = 'Dibatalkan: ';

  VelocityResult calculate({
    required List<StockMutation> stockOutMutations,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final realMutations = stockOutMutations
        .where((mutation) => !(mutation.note?.startsWith(_undoNotePrefix) ?? false))
        .toList(growable: false);

    if (realMutations.isEmpty) {
      return const VelocityResult(
        dailyVelocity: 0,
        stockOutCount: 0,
        dataAgeDays: 0,
      );
    }

    // Mutations dated in the future (clock skew) are treated as having
    // happened "now" rather than excluded or allowed to produce a
    // negative day count.
    final effectiveDates = realMutations
        .map((mutation) =>
            mutation.createdAt.isAfter(effectiveNow) ? effectiveNow : mutation.createdAt)
        .toList(growable: false);

    final earliestDate = effectiveDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final daysSinceFirst = _daysSince(earliestDate, effectiveNow);

    final windowStart = effectiveNow.subtract(const Duration(days: recentWindowDays));
    var recentTotal = 0.0;
    var allTimeTotal = 0.0;
    for (var i = 0; i < realMutations.length; i++) {
      final quantity = realMutations[i].quantity;
      allTimeTotal += quantity;
      if (!effectiveDates[i].isBefore(windowStart)) {
        recentTotal += quantity;
      }
    }

    final velocity30d = recentTotal / recentWindowDays;
    final velocityAllTime = allTimeTotal / daysSinceFirst;
    final dailyVelocity = velocity30d * recentWeight + velocityAllTime * allTimeWeight;

    final stockOutCount = realMutations.length;

    return VelocityResult(
      dailyVelocity: dailyVelocity,
      stockOutCount: stockOutCount,
      dataAgeDays: daysSinceFirst > recentWindowDays ? recentWindowDays : daysSinceFirst,
    );
  }

  /// Whole calendar days between [earliest] and [now], minimum 1 — a
  /// single stockOut mutation recorded today would otherwise divide by
  /// zero.
  int _daysSince(DateTime earliest, DateTime now) {
    final earliestDate = DateTime(earliest.year, earliest.month, earliest.day);
    final nowDate = DateTime(now.year, now.month, now.day);
    final days = nowDate.difference(earliestDate).inDays;
    return days < 1 ? 1 : days;
  }
}
