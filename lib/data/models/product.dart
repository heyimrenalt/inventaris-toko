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

  /// How many pcs are in one pack of this product. `null` means the
  /// product is only ever bought/sold in pcs — no pack unit exists for
  /// it. When set, must be >= 2 (validated in [ProductRepository]); 0/1
  /// would make "pack" meaningless as a distinct unit.
  int? unitsPerPack;

  /// The quantity actually bought last time this product was restocked,
  /// always stored in pcs regardless of [unitsPerPack]. `null` until the
  /// first completed [RestockList] checks this product off. Never set
  /// directly outside of [RestockListRepository.complete] — deliberately
  /// not derived from stock-in mutations, since a kulakan list is a
  /// shopping list, not a stock ledger (see [RestockListRepository]).
  double? lastRestockQty;

  /// How many of the next-smaller unit are in one dus. `null` means no
  /// dus unit. Relative to [unitsPerPack] when that's also set (e.g.
  /// `unitsPerPack: 2, unitsPerDus: 3` means 1 dus = 3 pack = 6 pcs) —
  /// but real kulakan goods aren't always 3 tiers deep (e.g. "1 dus = 12
  /// pcs" with no pack in between at all), so [unitsPerPack] being
  /// `null` is a valid, independent state: [unitsPerDus] then means pcs
  /// directly (1 dus = 12 pcs). When set, must be >= 2, same rationale
  /// as [unitsPerPack]. See [UnitConversion] for the conversion math and
  /// [ProductRepository] for validation.
  int? unitsPerDus;

  /// Whether this product's quantity may be entered as a fraction (e.g.
  /// 2.5 kg). `false` (the default) for ordinary countable goods sold in
  /// pcs/pack/dus, where a fractional amount is meaningless. Set `true`
  /// only for goods measured/weighed in fractional units (kg, liter, m).
  /// Enforced in [StockMutationRepository.recordMutation] for every stock
  /// change, and client-side in the quantity-entry widgets.
  ///
  /// Deliberately phrased as an opt-in "allows" flag rather than a
  /// "requires whole" flag: Isar's binary reader returns `false` — not
  /// this field's own Dart default — for any property missing from an
  /// already-stored record. Phrasing it this way means every
  /// pre-existing product silently and correctly becomes "whole units
  /// only" the moment this field ships, with no explicit backfill
  /// needed.
  bool allowsFractionalQuantity = false;
}
