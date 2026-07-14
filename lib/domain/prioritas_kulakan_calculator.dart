import '../data/models/product.dart';
import '../data/models/stock_mutation.dart';

enum PriorityUrgency { red, yellow, neutral }

class PrioritasKulakanResult {
  const PrioritasKulakanResult({
    required this.product,
    required this.dailyVelocity,
    required this.estimatedDaysRemaining,
    required this.isOutOfStock,
    required this.urgency,
    required this.suggestedRestockQty,
  });

  final Product product;
  final double dailyVelocity;

  /// currentStock ÷ dailyVelocity. Still populated (as 0) when
  /// [isOutOfStock] is true, so callers can sort on this field
  /// uniformly — but it must never be displayed literally as a fractional
  /// day count; see [isBelowOneDay].
  final double estimatedDaysRemaining;

  final bool isOutOfStock;

  final PriorityUrgency urgency;

  /// Suggested quantity to buy so currentStock covers 7 more days at the
  /// current sell rate: `ceil(dailyVelocity × 7) − currentStock`, never
  /// less than 1 — a product that already has 7+ days of cover still gets
  /// a token restock suggestion rather than 0, since this number only
  /// feeds a shopping-list line the user can edit after sharing anyway.
  final int suggestedRestockQty;

  /// True when there's less than a full day of stock left, including the
  /// [isOutOfStock] case. Display code should show a "Waktunya kulakan!"
  /// label instead of "X hari lagi" (or a "0"/fractional day count) when
  /// this is true.
  bool get isBelowOneDay => isOutOfStock || estimatedDaysRemaining < 1;
}

/// Pure velocity/priority calculation for "prioritas kulakan" (purchase
/// priority). Takes already-fetched [Product]/[StockMutation] data and
/// returns a computed result — no Isar or repository dependency inside
/// the calculation itself, so it's unit-testable with plain in-memory
/// fake data. The caller (a repository method or a screen's
/// data-loading logic) is responsible for fetching the real data from
/// Isar and feeding it in.
///
/// v1 is intentionally a simple all-time-average velocity model — no
/// weighting of recent sales, no seasonality. Refining that is deferred
/// until there's real usage data to tune it against.
class PrioritasKulakanCalculator {
  const PrioritasKulakanCalculator();

  static const int redThresholdDays = 2;
  static const int yellowThresholdDays = 7;

  /// Returns null when [stockOutMutations] is empty: a product with no
  /// stockOut history ever has no velocity to estimate from, so it isn't
  /// eligible to appear in "Prioritas Kulakan" at all.
  PrioritasKulakanResult? calculate({
    required Product product,
    required List<StockMutation> stockOutMutations,
    DateTime? now,
  }) {
    if (stockOutMutations.isEmpty) return null;

    final totalQuantity =
        stockOutMutations.fold<double>(0, (sum, mutation) => sum + mutation.quantity);
    final earliestDate = stockOutMutations
        .map((mutation) => mutation.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final dailyVelocity = totalQuantity / _daysSince(earliestDate, now ?? DateTime.now());

    final isOutOfStock = product.currentStock <= 0;
    final estimatedDaysRemaining = isOutOfStock ? 0.0 : product.currentStock / dailyVelocity;

    return PrioritasKulakanResult(
      product: product,
      dailyVelocity: dailyVelocity,
      estimatedDaysRemaining: estimatedDaysRemaining,
      isOutOfStock: isOutOfStock,
      urgency: _urgencyFor(estimatedDaysRemaining, isOutOfStock),
      suggestedRestockQty: _suggestedRestockQty(dailyVelocity, product.currentStock),
    );
  }

  int _suggestedRestockQty(double dailyVelocity, double currentStock) {
    final needed = (dailyVelocity * 7).ceil() - currentStock;
    return needed.ceil() < 1 ? 1 : needed.ceil();
  }

  /// Convenience for what the Beranda and Prioritas Kulakan screens
  /// actually need: every eligible product's result, sorted ascending by
  /// estimated days remaining (most urgent first). Products with no
  /// stockOut history (i.e. [calculate] would return null) are silently
  /// excluded.
  List<PrioritasKulakanResult> calculateAll({
    required List<Product> products,
    required Map<int, List<StockMutation>> stockOutMutationsByProductId,
    DateTime? now,
  }) {
    final results = <PrioritasKulakanResult>[];
    for (final product in products) {
      final result = calculate(
        product: product,
        stockOutMutations: stockOutMutationsByProductId[product.id] ?? const [],
        now: now,
      );
      if (result != null) results.add(result);
    }
    results.sort((a, b) => a.estimatedDaysRemaining.compareTo(b.estimatedDaysRemaining));
    return results;
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

  PriorityUrgency _urgencyFor(double estimatedDaysRemaining, bool isOutOfStock) {
    if (isOutOfStock || estimatedDaysRemaining <= redThresholdDays) return PriorityUrgency.red;
    if (estimatedDaysRemaining <= yellowThresholdDays) return PriorityUrgency.yellow;
    return PriorityUrgency.neutral;
  }
}
