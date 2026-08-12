import '../data/models/product.dart';
import '../data/models/stock_mutation.dart';

/// The sell/cost prices that apply to one [StockMutation], already
/// resolved through the snapshot-or-fallback rule. [costPrice] is
/// nullable because a product can genuinely have no cost data (see
/// [Product.averageCostPrice]); [sellPrice] is nullable only for the
/// degenerate case of a snapshot-less mutation whose product is gone.
class ResolvedMutationPrices {
  const ResolvedMutationPrices({
    required this.sellPrice,
    required this.costPrice,
  });

  final double? sellPrice;
  final double? costPrice;

  /// Profit for the whole mutation quantity, or `null` when either price
  /// is unknown — "unknown" is not the same as "zero profit", so callers
  /// must decide explicitly whether to skip or count such a row.
  ///
  /// Never clamped: selling below cost legitimately yields a negative
  /// number and that number is the truth.
  double? profitFor(double quantity) {
    final sell = sellPrice;
    final cost = costPrice;
    if (sell == null || cost == null) return null;
    return (sell - cost) * quantity;
  }
}

/// The single place where "use the snapshot, else fall back to the
/// product's current price" lives. Every profit calculation in the app
/// must resolve its prices here rather than reading [Product] directly,
/// so the fallback rule can never drift between call sites.
class MutationPricing {
  const MutationPricing._();

  /// [product] should be the [Product] referenced by [mutation.productId],
  /// or `null` if it no longer exists — a deleted product is not an error
  /// here: it simply leaves any price with no snapshot unresolved
  /// (`null`) instead of throwing.
  static ResolvedMutationPrices resolve(StockMutation mutation, Product? product) {
    return ResolvedMutationPrices(
      sellPrice: mutation.sellPriceSnapshot ?? product?.sellPrice,
      costPrice: mutation.costPriceSnapshot ?? product?.averageCostPrice,
    );
  }

  /// Convenience for the common case: profit for [mutation]'s full
  /// quantity, `null` when prices can't be resolved. See
  /// [ResolvedMutationPrices.profitFor].
  static double? profit(StockMutation mutation, Product? product) {
    return resolve(mutation, product).profitFor(mutation.quantity);
  }
}
