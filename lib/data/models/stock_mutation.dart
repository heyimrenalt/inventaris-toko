import 'package:isar_community/isar.dart';

part 'stock_mutation.g.dart';

enum StockMutationType {
  stockIn,
  stockOut,
}

/// Which unit the user actually typed the quantity in — pcs/pack/dus,
/// mirroring [Product.unitsPerPack]/[Product.unitsPerDus]. Purely a
/// display/history convenience: [StockMutation.quantity] is always
/// canonical pcs regardless of this value.
enum EnteredUnit {
  pcs,
  pack,
  dus,
}

@Collection(accessor: 'stockMutations')
class StockMutation {
  Id id = Isar.autoIncrement;

  /// Foreign key to [Product.id]. Stored as a plain field (not an IsarLink).
  late int productId;

  @Enumerated(EnumType.name)
  late StockMutationType type;

  /// Always > 0. What the user actually entered. For stockOut, this is
  /// always <= the product's stock at the time (see
  /// [StockMutationRepository.recordMutation], which rejects the mutation
  /// outright otherwise).
  late double quantity;

  String? note;

  /// Snapshot of Product.currentStock immediately after this mutation.
  late double stockAfter;

  /// Indexed for the future "prioritas kulakan" velocity calculations,
  /// which will query mutation history by time range heavily.
  @Index()
  late DateTime createdAt;

  /// Which unit [enteredQuantity] is expressed in. `null` for mutations
  /// recorded before this field existed, or for any caller that doesn't
  /// supply entered-unit info — [quantity] (always pcs) remains the
  /// source of truth regardless.
  @Enumerated(EnumType.name)
  EnteredUnit? enteredUnit;

  /// Raw quantity as typed, in [enteredUnit] (e.g. `1` for "1 dus").
  /// Used only to redisplay history (see `MutationListItem`); never used
  /// for stock math.
  double? enteredQuantity;
}
