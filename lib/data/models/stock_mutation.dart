import 'package:isar_community/isar.dart';

part 'stock_mutation.g.dart';

enum StockMutationType {
  stockIn,
  stockOut,
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
}
