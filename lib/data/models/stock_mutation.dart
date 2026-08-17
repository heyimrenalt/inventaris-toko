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
  ///
  /// Deliberately *not* indexed. An index here was A/B tested against the
  /// per-product history loops and measured no benefit (640ms with
  /// `filter()` vs 686ms with `where()` + index over 200 products / 1000
  /// rows): the cost is per-call async overhead across 200 sequential
  /// queries, not row scanning — fetching the whole ledger is only 21ms.
  /// The fix was to batch those loops into one query plus a group-by in
  /// Dart (~7ms), which leaves an index with nothing to win and a real
  /// write-amplification cost on mutation inserts, the hottest write path.
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

  /// [Product.sellPrice] as it stood the instant this mutation was
  /// recorded. Frozen here so a later price edit can't retroactively
  /// rewrite historical profit — the whole reason these snapshots exist.
  ///
  /// `null` means "no snapshot was recorded" (a row written before these
  /// fields existed, or one the backfill couldn't resolve), which is
  /// deliberately distinct from a snapshot of `0`. Never read directly
  /// for profit math: go through [MutationPricing], which owns the
  /// fall-back-to-current-price rule.
  double? sellPriceSnapshot;

  /// [Product.averageCostPrice] as it stood the instant this mutation was
  /// recorded — for a stockIn, *after* [HppCalculator] folded that batch
  /// into the weighted average, so it reflects the post-batch cost.
  ///
  /// `null` when the product had no cost data at all at that moment
  /// (averageCostPrice was itself null), same nullable-vs-zero
  /// distinction as [sellPriceSnapshot].
  double? costPriceSnapshot;

  /// `true` when the snapshots on this row were filled in by the one-time
  /// [MutationSnapshotBackfill] from the product's *current* prices rather
  /// than captured at mutation time — so their imprecision stays
  /// traceable, since those prices may have drifted since the mutation
  /// actually happened.
  ///
  /// Defaults to `false`, which is also what Isar's binary reader returns
  /// for a bool missing from an already-stored record (see the note on
  /// [Product.allowsFractionalQuantity]) — so legacy rows read as
  /// "not backfilled" with no explicit migration of this field needed.
  bool snapshotBackfilled = false;
}
