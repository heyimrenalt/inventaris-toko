import 'package:isar_community/isar.dart';

part 'product.g.dart';

/// [Product.criticalStockAlertState]: queued, waiting for the next
/// scheduled "Alert stok kritis" notification.
const criticalStockAlertStatePending = 1;

/// [Product.criticalStockAlertState]: already included in a past "Alert
/// stok kritis" notification, still critical since then.
const criticalStockAlertStateNotified = 2;

@Collection(accessor: 'products')
class Product {
  Id id = Isar.autoIncrement;

  @Index()
  late String name;

  /// Optional barcode/product code. Uniqueness for non-null/non-empty
  /// values is enforced manually in [ProductRepository] rather than via
  /// `@Index(unique: true)`: Isar's null-handling semantics for unique
  /// indexes aren't documented clearly enough to depend on for a field
  /// that is expected to repeatedly be null, so this stays a plain
  /// lookup index and the uniqueness check is done explicitly in code.
  @Index()
  String? code;

  /// Foreign key to [Category.id]. Stored as a plain field (not an
  /// IsarLink) per spec. `null` means the product is uncategorized (the
  /// "Lainnya" bucket) — category assignment is optional.
  @Index()
  int? categoryId;

  String? photoPath;

  late double sellPrice;

  late String unit;

  /// Never set directly outside of [StockMutationRepository.recordMutation].
  late double currentStock;

  late double minStockThreshold;

  /// Weighted average cost per unit (HPP). `null` means no cost data has
  /// ever been recorded for this product — distinct from 0, which would
  /// mean the product's cost is genuinely zero. Never set directly outside
  /// of [ProductRepository.create] (initial value) and
  /// [StockMutationRepository.recordMutation] (recalculated on stockIn
  /// batches that provide a cost price); persists across stock hitting 0.
  double? averageCostPrice;

  late DateTime createdAt;

  late DateTime updatedAt;

  /// Archived products are hidden from normal listings but not deleted —
  /// an alternative to [ProductRepository.delete] for products that have
  /// stock mutation history (and so can't be hard-deleted) but the user
  /// still wants off their active list.
  bool isArchived = false;

  DateTime? archivedAt;

  /// Critical-stock notification queue state for "Alert stok kritis" (see
  /// [NotificationService]). `null` when the product isn't in a critical
  /// episode (stock above [minStockThreshold]). [criticalStockAlertStatePending]
  /// while critical and waiting for the next scheduled alert;
  /// [criticalStockAlertStateNotified] once it has been included in one,
  /// so it isn't queued again on every subsequent stock-out while still
  /// critical. Reset to `null` when stock recovers above the threshold —
  /// a later drop back to critical is then treated as a new episode.
  int? criticalStockAlertState;
}
