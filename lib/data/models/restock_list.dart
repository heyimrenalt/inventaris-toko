import 'package:isar_community/isar.dart';

part 'restock_list.g.dart';

/// A single kulakan (restock) shopping list for one store/supplier trip.
/// Deliberately a pure shopping list — see [RestockListRepository] for why
/// it never touches [Product.currentStock].
@Collection(accessor: 'restockLists')
class RestockList {
  Id id = Isar.autoIncrement;

  /// Free-text store/supplier name, header-level (one list = one store).
  /// `null`/blank means not yet named.
  String? supplierName;

  late DateTime createdAt;

  /// `null` while the list is still being shopped/edited. Set once by
  /// [RestockListRepository.complete], which is also when checked items'
  /// quantities get written back to [Product.lastRestockQty].
  DateTime? completedAt;

  List<RestockListItem> items = [];
}

@embedded
class RestockListItem {
  /// Foreign key to [Product.id].
  int productId = 0;

  /// Snapshot of [Product.name] at the time this item was added to the
  /// list — the only way to still show a sensible row (name + "(dihapus)")
  /// if the product is later hard-deleted, since [productId] alone
  /// wouldn't resolve to anything at that point.
  String productNameSnapshot = '';

  /// Canonical quantity, always in pcs regardless of how the user typed it.
  double qtyInPcs = 0;

  /// Remembers whether the user typed this row in packs or pcs, for
  /// display only — [qtyInPcs] is always the source of truth.
  bool inputUnitWasPack = false;

  /// Whether this item has actually been bought this trip. Only checked
  /// items get written into [Product.lastRestockQty] on completion —
  /// items left in the list but not checked weren't actually bought at
  /// this quantity, so they must not feed the next prefill.
  bool isChecked = false;
}
