import 'package:isar_community/isar.dart';

import '../models/app_settings.dart';
import '../models/product.dart';
import '../models/stock_mutation.dart';
import '../repositories/app_settings_repository.dart';

/// One-time backfill for [StockMutation.sellPriceSnapshot] /
/// [StockMutation.costPriceSnapshot] on rows recorded before those fields
/// existed.
///
/// Historical prices genuinely aren't recoverable for those rows — the
/// old schema never stored them — so the best available approximation is
/// the product's *current* prices. Every row filled this way is marked
/// [StockMutation.snapshotBackfilled] so that imprecision stays visible
/// instead of masquerading as a real point-in-time capture.
///
/// Idempotent in two independent ways: it only touches rows whose
/// [StockMutation.sellPriceSnapshot] is null, and it is guarded by
/// [AppSettings.mutationPriceSnapshotBackfillDone] so it normally runs at
/// most once per install. Running it twice is harmless either way.
class MutationSnapshotBackfill {
  MutationSnapshotBackfill(this._isar);

  final Isar _isar;

  /// Runs the backfill unless the persisted flag says it already ran.
  /// Returns the number of rows written (0 when skipped).
  Future<int> runIfNeeded() async {
    final settings = await AppSettingsRepository(_isar).get();
    if (settings.mutationPriceSnapshotBackfillDone) {
      return 0;
    }

    final written = await run();

    settings.mutationPriceSnapshotBackfillDone = true;
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    return written;
  }

  /// The backfill itself, without the flag guard — exposed separately so
  /// it can be re-run deliberately (and tested for idempotency) without
  /// having to clear the flag first. Returns the number of rows written.
  Future<int> run() async {
    // Only rows with no snapshot at all are candidates: a row that
    // already carries snapshots — whether captured at write time or by a
    // previous backfill pass — is never overwritten. This is what makes
    // a second run a no-op rather than a re-approximation.
    final candidates = await _isar.stockMutations
        .filter()
        .sellPriceSnapshotIsNull()
        .findAll();
    if (candidates.isEmpty) {
      return 0;
    }

    // Products are fetched once per distinct id rather than once per
    // mutation — a ledger typically has far more mutations than products.
    final productIds = candidates.map((m) => m.productId).toSet().toList();
    final products = <int, Product>{};
    for (final product in await _isar.products.getAll(productIds)) {
      if (product != null) {
        products[product.id] = product;
      }
    }

    final toWrite = <StockMutation>[];
    for (final mutation in candidates) {
      final product = products[mutation.productId];
      // Product hard-deleted since the mutation was recorded: there is
      // nothing to copy from, so the snapshots stay null and
      // MutationPricing keeps reporting "unknown" for this row. Not an
      // error, and never a crash.
      if (product == null) continue;

      mutation
        ..sellPriceSnapshot = product.sellPrice
        // Stays null when the product has no cost data — same
        // nullable-vs-zero distinction the write path keeps.
        ..costPriceSnapshot = product.averageCostPrice
        ..snapshotBackfilled = true;
      toWrite.add(mutation);
    }

    if (toWrite.isEmpty) {
      return 0;
    }

    await _isar.writeTxn(() async {
      await _isar.stockMutations.putAll(toWrite);
    });

    return toWrite.length;
  }
}
