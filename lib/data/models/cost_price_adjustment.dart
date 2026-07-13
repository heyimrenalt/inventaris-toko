import 'package:isar_community/isar.dart';

part 'cost_price_adjustment.g.dart';

/// Audit trail for manual corrections to [Product.averageCostPrice] made
/// via the Edit Product form's "Harga modal (koreksi)" field.
///
/// Deliberately a separate collection from [StockMutation] rather than
/// reusing it: a manual HPP correction never changes stock quantity, and
/// [StockMutation] is documented as the ledger of quantity changes only —
/// folding a non-quantity event into it would make `stockAfter`/`quantity`
/// meaningless for these rows. A dedicated lightweight collection keeps
/// that ledger clean and keeps this one purpose-built for "what was HPP
/// before/after, and when".
///
/// Not surfaced in any UI yet — this exists purely for traceability so a
/// later screen (or support investigation) can answer "was this product's
/// HPP ever manually overridden, and to what".
@Collection(accessor: 'costPriceAdjustments')
class CostPriceAdjustment {
  Id id = Isar.autoIncrement;

  /// Foreign key to [Product.id]. Stored as a plain field (not an IsarLink),
  /// same convention as [StockMutation.productId].
  @Index()
  late int productId;

  /// [Product.averageCostPrice] immediately before this adjustment. Null
  /// means the product had no cost data yet.
  double? oldCost;

  /// [Product.averageCostPrice] immediately after this adjustment. Null
  /// means the correction cleared HPP back to "no data".
  double? newCost;

  late DateTime adjustedAt;

  String? note;
}
