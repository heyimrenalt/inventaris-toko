/// Pure HPP (Harga Pokok Penjualan / cost of goods sold) and profit-margin
/// calculations. No Isar dependency, so it's unit-testable standalone — same
/// shape as [PrioritasKulakanCalculator].
class HppCalculator {
  const HppCalculator._();

  /// Weighted average cost after a stockIn batch of [incomingQty] units at
  /// [incomingCostPrice] each, given [currentStock] units already on hand at
  /// [currentAvgCost] each.
  ///
  /// When [currentStock] is 0 (no old stock to weight against — including a
  /// product whose HPP was never set), the result is simply
  /// [incomingCostPrice]: there's nothing to average with.
  static double calculateNewAverage({
    required double currentStock,
    required double currentAvgCost,
    required double incomingQty,
    required double incomingCostPrice,
  }) {
    if (currentStock <= 0) return incomingCostPrice;
    return ((currentStock * currentAvgCost) + (incomingQty * incomingCostPrice)) /
        (currentStock + incomingQty);
  }

  /// Profit per unit, or null if [avgCostPrice] has no cost data yet.
  static double? profitPerUnit(double sellPrice, double? avgCostPrice) {
    if (avgCostPrice == null) return null;
    return sellPrice - avgCostPrice;
  }

  /// Margin as a percentage of [sellPrice], or null if [avgCostPrice] has no
  /// cost data yet or [sellPrice] is 0 (division by zero).
  static double? marginPercent(double sellPrice, double? avgCostPrice) {
    if (avgCostPrice == null || sellPrice == 0) return null;
    return (sellPrice - avgCostPrice) / sellPrice * 100;
  }
}
