import '../data/models/product.dart';
import '../data/models/stock_mutation.dart';
import 'velocity_calculator.dart';

enum PriorityUrgency { red, yellow, neutral }

class PrioritasKulakanResult {
  const PrioritasKulakanResult({
    required this.product,
    required this.dailyVelocity,
    required this.dataAgeDays,
    required this.estimatedDaysRemaining,
    required this.isOutOfStock,
    required this.urgency,
    required this.suggestedRestockQty,
  });

  final Product product;
  final double dailyVelocity;

  /// `min(30, days since the earliest counted stockOut mutation)` — for a
  /// UI caption like "berdasarkan rata-rata {dataAgeDays} hari terakhir".
  final int dataAgeDays;

  /// currentStock ÷ dailyVelocity, or `null` when there's nothing
  /// meaningful to show: the product is out of stock (a fact, not a
  /// prediction — see [isOutOfStock]) or [dailyVelocity] is zero.
  final double? estimatedDaysRemaining;

  final bool isOutOfStock;

  final PriorityUrgency urgency;

  /// Suggested quantity to buy so currentStock covers
  /// `AppSettings.restockCoverDays` more days at the current sell rate:
  /// `max(1, ceil(dailyVelocity × restockCoverDays) − currentStock)`.
  final int suggestedRestockQty;
}

/// Pure velocity/priority calculation for "prioritas kulakan" (purchase
/// priority). Takes already-fetched [Product]/[StockMutation] data and
/// returns a computed result — no Isar or repository dependency inside
/// the calculation itself, so it's unit-testable with plain in-memory
/// fake data. The caller (a repository method or a screen's
/// data-loading logic) is responsible for fetching the real data from
/// Isar and feeding it in.
///
/// Velocity itself is computed by [VelocityCalculator] (a 70/30 blend of
/// recent and all-time sell rate); this class turns that number into the
/// restock-priority fields the "Prioritas Kulakan" screens need.
///
/// Urgency rules, in priority order:
/// 1. `currentStock <= 0` → red — an empty shelf is a fact, not a
///    prediction.
/// 2. `dailyVelocity == 0` → neutral, no estimated-days number shown.
/// 3. Otherwise, `estimatedDays = currentStock ÷ dailyVelocity` compared
///    against `restockLeadTimeDays` / `2 × restockLeadTimeDays`.
class PrioritasKulakanCalculator {
  const PrioritasKulakanCalculator();

  static const VelocityCalculator _velocityCalculator = VelocityCalculator();

  /// Returns null when [stockOutMutations] has no real (non-undo) stockOut
  /// entries: a product with no sales history ever has no velocity to
  /// estimate from, so it isn't eligible to appear in "Prioritas Kulakan"
  /// at all.
  PrioritasKulakanResult? calculate({
    required Product product,
    required List<StockMutation> stockOutMutations,
    required int restockLeadTimeDays,
    required int restockCoverDays,
    DateTime? now,
  }) {
    final velocity = _velocityCalculator.calculate(
      stockOutMutations: stockOutMutations,
      now: now,
    );
    if (velocity.stockOutCount == 0) return null;

    final dailyVelocity = velocity.dailyVelocity;
    final currentStock = product.currentStock;
    final isOutOfStock = currentStock <= 0;

    double? estimatedDaysRemaining;
    final PriorityUrgency urgency;

    if (isOutOfStock) {
      urgency = PriorityUrgency.red;
    } else if (dailyVelocity == 0) {
      urgency = PriorityUrgency.neutral;
    } else {
      final days = currentStock / dailyVelocity;
      estimatedDaysRemaining = days;
      if (days < restockLeadTimeDays) {
        urgency = PriorityUrgency.red;
      } else if (days <= restockLeadTimeDays * 2) {
        urgency = PriorityUrgency.yellow;
      } else {
        urgency = PriorityUrgency.neutral;
      }
    }

    return PrioritasKulakanResult(
      product: product,
      dailyVelocity: dailyVelocity,
      dataAgeDays: velocity.dataAgeDays,
      estimatedDaysRemaining: estimatedDaysRemaining,
      isOutOfStock: isOutOfStock,
      urgency: urgency,
      suggestedRestockQty: _suggestedRestockQty(dailyVelocity, currentStock, restockCoverDays),
    );
  }

  int _suggestedRestockQty(double dailyVelocity, double currentStock, int restockCoverDays) {
    final needed = (dailyVelocity * restockCoverDays).ceil() - currentStock;
    return needed.ceil() < 1 ? 1 : needed.ceil();
  }

  /// Convenience for what the Beranda and Prioritas Kulakan screens
  /// actually need: every eligible product's result, sorted most-urgent
  /// first (red, then yellow, then neutral; ties broken by
  /// [PrioritasKulakanResult.estimatedDaysRemaining] ascending, out-of-
  /// stock products sorting first within red since they have no
  /// estimate). Products with no stockOut history (i.e. [calculate]
  /// would return null) are silently excluded.
  List<PrioritasKulakanResult> calculateAll({
    required List<Product> products,
    required Map<int, List<StockMutation>> stockOutMutationsByProductId,
    required int restockLeadTimeDays,
    required int restockCoverDays,
    DateTime? now,
  }) {
    final results = <PrioritasKulakanResult>[];
    for (final product in products) {
      final result = calculate(
        product: product,
        stockOutMutations: stockOutMutationsByProductId[product.id] ?? const [],
        restockLeadTimeDays: restockLeadTimeDays,
        restockCoverDays: restockCoverDays,
        now: now,
      );
      if (result != null) results.add(result);
    }
    results.sort(_compareUrgency);
    return results;
  }

  int _compareUrgency(PrioritasKulakanResult a, PrioritasKulakanResult b) {
    final rankCompare = _urgencyRank(a.urgency).compareTo(_urgencyRank(b.urgency));
    if (rankCompare != 0) return rankCompare;

    final aDays = a.estimatedDaysRemaining ?? (a.isOutOfStock ? -1 : double.infinity);
    final bDays = b.estimatedDaysRemaining ?? (b.isOutOfStock ? -1 : double.infinity);
    return aDays.compareTo(bDays);
  }

  int _urgencyRank(PriorityUrgency urgency) {
    switch (urgency) {
      case PriorityUrgency.red:
        return 0;
      case PriorityUrgency.yellow:
        return 1;
      case PriorityUrgency.neutral:
        return 2;
    }
  }
}

/// Formats a positive day count for display, per "Prioritas Kulakan"'s
/// UI copy rules: sub-day estimates and multi-month tails are both
/// misleading as raw numbers (a "0 hari" or "847 hari" reads as false
/// precision), so both ends are clamped to a phrase instead.
String formatEstimatedDaysLabel(double days) {
  if (days < 1) return 'kurang dari 1 hari';
  if (days > 30) return 'lebih dari 30 hari';
  return '${days.round()} hari lagi';
}

/// Formats [velocity] to 1 decimal place, stripping a trailing ".0" (so
/// `9.0` reads as `9`, while `1.5` stays `1.5`) — used anywhere a daily
/// sell rate is shown in the UI.
String formatVelocity(double velocity) {
  final rounded = (velocity * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toStringAsFixed(1);
}
