import 'package:isar_community/isar.dart';

import '../../domain/hpp_calculator.dart';
import '../../domain/mutation_pricing.dart';
import '../../domain/profit_report.dart';
import '../models/product.dart';
import '../models/stock_mutation.dart';
import 'repository_exceptions.dart';

/// The only repository allowed to change [Product.currentStock]. Every
/// change to stock — including a product's initial stock at creation —
/// must go through [recordMutation] so the [StockMutation] ledger stays
/// complete.
class StockMutationRepository {
  StockMutationRepository(this._isar);

  final Isar _isar;

  /// [costPricePerUnit] is only meaningful when [type] is
  /// [StockMutationType.stockIn]: if provided, [Product.averageCostPrice] is
  /// recalculated via [HppCalculator.calculateNewAverage] and written in the
  /// same write transaction as the stock update, so the two never diverge.
  /// Ignored for stockOut, and a no-op when left null (HPP stays unchanged).
  Future<StockMutation> recordMutation({
    required int productId,
    required StockMutationType type,
    required double quantity,
    String? note,
    double? costPricePerUnit,
    EnteredUnit? enteredUnit,
    double? enteredQuantity,
  }) async {
    if (quantity <= 0) {
      throw ValidationException('quantity must be > 0');
    }

    return _isar.writeTxn(() async {
      final product = await _isar.products.get(productId);
      if (product == null) {
        throw NotFoundException('Product $productId not found');
      }

      if (!product.allowsFractionalQuantity && quantity != quantity.roundToDouble()) {
        throw ValidationException('quantity must be a whole number for this product');
      }

      final double newStock;
      if (type == StockMutationType.stockIn) {
        newStock = product.currentStock + quantity;
        if (costPricePerUnit != null) {
          product.averageCostPrice = HppCalculator.calculateNewAverage(
            currentStock: product.currentStock,
            currentAvgCost: product.averageCostPrice ?? 0,
            incomingQty: quantity,
            incomingCostPrice: costPricePerUnit,
          );
        }
      } else {
        // Stock-out can never take currentStock negative. Rather than
        // clamping to 0, the whole mutation is rejected: no Product or
        // StockMutation write happens, so the ledger never contains a
        // stock-out that doesn't reflect what actually left the shelf.
        if (quantity > product.currentStock) {
          throw InsufficientStockException(
            productId: productId,
            currentStock: product.currentStock,
            requestedQuantity: quantity,
          );
        }
        newStock = product.currentStock - quantity;
      }

      product.currentStock = newStock;
      product.updatedAt = DateTime.now();

      // Maintain the "Alert stok kritis" queue state alongside the stock
      // change itself, in the same write transaction — this is the only
      // place currentStock changes, so it's the single correct place to
      // detect a critical-episode transition (see
      // Product.criticalStockAlertState doc comment for the state
      // machine). `??=` leaves an already-pending/notified product
      // untouched while it stays critical, so a run of stock-out
      // mutations on the same low-stock product doesn't re-queue it.
      if (newStock <= product.minStockThreshold) {
        product.criticalStockAlertState ??= criticalStockAlertStatePending;
      } else {
        product.criticalStockAlertState = null;
      }

      // Price snapshots are read here, after the HPP recalculation above,
      // and written inside this same transaction as the product itself —
      // so a stockIn's costPriceSnapshot is the *post*-batch weighted
      // average, and no crash can leave a mutation whose snapshot
      // disagrees with the product row it was taken from.
      //
      // averageCostPrice is nullable and stays nullable here: a product
      // with no cost data yet (or a stockIn recorded without a cost
      // price, which doesn't trigger a recalculation) snapshots a `null`
      // cost rather than a fabricated 0. Profit for such a row is
      // "unknown", not "equal to the full sell price" — see
      // [MutationPricing].
      final mutation = StockMutation()
        ..productId = productId
        ..type = type
        ..quantity = quantity
        ..note = note
        ..stockAfter = newStock
        ..enteredUnit = enteredUnit
        ..enteredQuantity = enteredQuantity
        ..sellPriceSnapshot = product.sellPrice
        ..costPriceSnapshot = product.averageCostPrice
        ..snapshotBackfilled = false
        ..createdAt = DateTime.now();

      await _isar.products.put(product);
      await _isar.stockMutations.put(mutation);

      return mutation;
    });
  }

  Future<List<StockMutation>> getHistoryForProduct(int productId) {
    return _isar.stockMutations
        .filter()
        .productIdEqualTo(productId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// The single newest mutation for [productId], or `null` if it has no
  /// history. Used by callers to decide whether a given mutation row is
  /// eligible for cancellation (only the most recent mutation for a
  /// product may be undone from the history screens).
  Future<StockMutation?> getMostRecentMutationForProduct(int productId) {
    return _isar.stockMutations
        .filter()
        .productIdEqualTo(productId)
        .sortByCreatedAtDesc()
        .findFirst();
  }

  /// Reverses [mutationId] by recording a compensating mutation of the
  /// opposite type for the same quantity — a stockOut is undone by a
  /// stockIn and vice versa. The original record is never deleted or
  /// modified: the ledger stays append-only, and the undo shows up as a
  /// new opposing entry.
  ///
  /// Whether [mutationId] is actually eligible to be undone (e.g. "only
  /// the most recent mutation for a product") is entirely the caller's
  /// concern — this method just executes the compensating write.
  /// Cancels [mutationId] by writing a compensating (reversing) entry and
  /// returns that new entry — the caller can pass its id straight back to
  /// [undoMutation] again to "undo the undo" (e.g. a SnackBar's Urungkan
  /// action), which re-applies the original quantity.
  Future<StockMutation> undoMutation(int mutationId) async {
    final original = await _isar.stockMutations.get(mutationId);
    if (original == null) {
      throw NotFoundException('Mutation $mutationId not found');
    }

    final product = await _isar.products.get(original.productId);
    final compensatingType = original.type == StockMutationType.stockIn
        ? StockMutationType.stockOut
        : StockMutationType.stockIn;

    // Strips any existing "Dibatalkan: " prefix first, so undoing an
    // already-undone mutation produces a single clean "Dibatalkan: X"
    // note instead of nesting ("Dibatalkan: Dibatalkan: X") every time
    // the same chain is undone back and forth.
    final baseNote =
        original.note?.replaceFirst(RegExp(r'^Dibatalkan:\s*'), '') ?? product?.name ?? 'mutasi';

    // Deliberately doesn't forward original.enteredUnit/enteredQuantity:
    // an undo is a new, system-generated event, not a re-entry of the
    // same user input, so it carries no entered-unit provenance of its
    // own — same reasoning as why its note is reworded rather than
    // copied verbatim.
    return recordMutation(
      productId: original.productId,
      type: compensatingType,
      quantity: original.quantity,
      note: 'Dibatalkan: $baseNote',
    );
  }

  /// All stockOut mutations for [productId], oldest first. Feeds
  /// [PrioritasKulakanCalculator], which needs the earliest stockOut date
  /// (and every quantity in between) to compute daily velocity.
  Future<List<StockMutation>> getStockOutHistoryForProduct(int productId) {
    return _isar.stockMutations
        .filter()
        .productIdEqualTo(productId)
        .typeEqualTo(StockMutationType.stockOut)
        .sortByCreatedAt()
        .findAll();
  }

  /// Same as [getHistoryForProduct] but capped at [limit] — for previews
  /// (e.g. Product Detail's recent-history section) that link out to the
  /// full history via [getHistoryForProduct] instead of loading everything
  /// just to show a handful of rows.
  Future<List<StockMutation>> getRecentHistoryForProduct(int productId, int limit) {
    return _isar.stockMutations
        .filter()
        .productIdEqualTo(productId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<List<StockMutation>> getRecentMutations(int limit) {
    return _isar.stockMutations
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  /// Full mutation history across all products, newest first — used by
  /// the Mutasi tab, which shows the complete ledger with no filters.
  Future<List<StockMutation>> getAllMutations() {
    return _isar.stockMutations.where().sortByCreatedAtDesc().findAll();
  }

  /// Sums stock-in and stock-out quantities separately for mutations
  /// created at or after [since] (e.g. `DateTime.now().subtract(const
  /// Duration(days: 7))` for a rolling 7-day window). Computed as a
  /// single indexed query rather than loading everything and summing in
  /// the UI layer.
  Future<StockMutationTotals> getTotalsSince(DateTime since) async {
    final mutations = await _isar.stockMutations
        .filter()
        .createdAtGreaterThan(since, include: true)
        .findAll();

    var stockIn = 0.0;
    var stockOut = 0.0;
    for (final mutation in mutations) {
      if (mutation.type == StockMutationType.stockIn) {
        stockIn += mutation.quantity;
      } else {
        stockOut += mutation.quantity;
      }
    }
    return StockMutationTotals(stockIn: stockIn, stockOut: stockOut);
  }

  /// Profit for a single mutation, resolved through [MutationPricing] —
  /// its price snapshots when it has them, the product's current prices
  /// otherwise. `null` when the prices can't be resolved at all (no cost
  /// data has ever been recorded, or the product is gone and the row
  /// predates snapshots), which callers treat as "not counted" rather
  /// than as zero.
  Future<double?> profitForMutation(StockMutation mutation) async {
    final product = await _isar.products.get(mutation.productId);
    return MutationPricing.profit(mutation, product);
  }

  /// Every stock-out mutation inside [period], oldest first.
  ///
  /// The period is applied **here, by the database**, via the `createdAt`
  /// index — not by filtering an already-loaded "fetch everything" result
  /// and not after aggregation. [ReportPeriod.allTime] deliberately runs
  /// with no where-clause at all rather than with sentinel bounds.
  ///
  /// Bounds are `startInclusive <= createdAt < endExclusive`; see
  /// [ReportPeriod] for why the upper bound is exclusive-at-next-midnight
  /// rather than a literal 23:59:59.999, and for the local-time reasoning.
  Future<List<StockMutation>> getStockOutMutationsInPeriod(ReportPeriod period) {
    if (period.isAllTime) {
      return _isar.stockMutations
          .filter()
          .typeEqualTo(StockMutationType.stockOut)
          .sortByCreatedAt()
          .findAll();
    }

    return _isar.stockMutations
        .where()
        .createdAtBetween(
          period.startInclusive!,
          period.endExclusive!,
          includeLower: true,
          includeUpper: false,
        )
        .filter()
        .typeEqualTo(StockMutationType.stockOut)
        .sortByCreatedAt()
        .findAll();
  }

  /// The `createdAt` of the oldest mutation ever recorded, or `null` when
  /// the ledger is empty.
  ///
  /// Runs as a **single indexed query**: `anyCreatedAt()` walks the
  /// `createdAt` index in ascending order and [findFirst] stops at the
  /// first entry, so the cost is one index seek regardless of how many
  /// mutations exist. Nothing is loaded into memory to be minimised.
  ///
  /// The returned value is a local [DateTime] (Isar reads timestamps back
  /// with `.toLocal()`), matching how [ReportPeriod] builds its bounds —
  /// so callers can compare or format it without mixing UTC and local.
  Future<DateTime?> getEarliestMutationDate() async {
    final earliest =
        await _isar.stockMutations.where().anyCreatedAt().findFirst();
    return earliest?.createdAt;
  }

  /// How many rows one page of [_edgeProfitableStockOutDate] pulls at a
  /// time. Large enough that the realistic case (the oldest/newest sale
  /// resolves prices fine) costs exactly one page, small enough that a
  /// long tail of unresolvable rows never loads the whole ledger.
  static const int _edgeScanPageSize = 100;

  /// The earliest and latest sale dates that actually feed the profit
  /// figures, or `null` when nothing qualifies.
  ///
  /// "Qualifies" is deliberately the *same* predicate the profit
  /// calculation uses (see [calculateProfitByDate] /
  /// [ProfitReportBuilder.build]): a stock-out mutation whose sell **and**
  /// cost price can both be resolved through [MutationPricing]. A stock-out
  /// with no resolvable cost contributes nothing to the total, so it must
  /// not be allowed to define the range either — otherwise the label would
  /// claim a start date whose transaction isn't in the number below it.
  ///
  /// Walks the `createdAt` index from each end (ascending for the min,
  /// descending for the max) in pages, stopping at the first qualifying
  /// row. It never loads the whole ledger to be minimised: with resolvable
  /// prices — the normal case — it reads one row's worth of work per end.
  ///
  /// Returned values are local [DateTime]s (Isar reads timestamps back with
  /// `.toLocal()`), consistent with how [ReportPeriod] builds its day
  /// boundaries — no UTC is involved anywhere on this path.
  Future<ProfitDateRange?> getProfitableStockOutDateRange() async {
    final earliest = await _edgeProfitableStockOutDate(descending: false);
    if (earliest == null) return null;
    final latest = await _edgeProfitableStockOutDate(descending: true);
    // `latest` cannot be null once `earliest` isn't — the same row
    // qualifies from either direction — but fall back rather than assert.
    return ProfitDateRange(earliest: earliest, latest: latest ?? earliest);
  }

  Future<DateTime?> _edgeProfitableStockOutDate({required bool descending}) async {
    var offset = 0;
    while (true) {
      final page = await _isar.stockMutations
          .where(sort: descending ? Sort.desc : Sort.asc)
          .anyCreatedAt()
          .filter()
          .typeEqualTo(StockMutationType.stockOut)
          .offset(offset)
          .limit(_edgeScanPageSize)
          .findAll();
      if (page.isEmpty) return null;

      final products =
          await _isar.products.getAll(page.map((m) => m.productId).toSet().toList());
      final productsById = <int, Product>{
        for (final product in products) ?product?.id: ?product,
      };

      for (final mutation in page) {
        if (MutationPricing.profit(mutation, productsById[mutation.productId]) != null) {
          return mutation.createdAt;
        }
      }

      if (page.length < _edgeScanPageSize) return null;
      offset += page.length;
    }
  }

  /// The profit report for [period]: totals and per-product breakdown,
  /// aggregated from the [StockMutation] ledger.
  ///
  /// Every figure it returns — revenue, cost, profit, per-product
  /// quantity — comes from stock-out rows in the period, valued through
  /// [MutationPricing]. Nothing is read from a precomputed [Product]
  /// total, because a Product row has no time dimension and so cannot
  /// respond to the selected range at all.
  Future<ProfitReport> buildProfitReport(ReportPeriod period) async {
    final mutations = await getStockOutMutationsInPeriod(period);
    if (mutations.isEmpty) return ProfitReport.empty(period);

    // One batched lookup for the products involved, rather than a `get`
    // per mutation: a busy day can hold hundreds of rows for a handful of
    // products. Missing ids (deleted products) simply stay absent from
    // the map — see [ProfitReportBuilder.build].
    final productIds = mutations.map((m) => m.productId).toSet().toList();
    final products = await _isar.products.getAll(productIds);
    final productsById = <int, Product>{
      for (final product in products) ?product?.id: ?product,
    };

    return ProfitReportBuilder.build(
      period: period,
      stockOutMutations: mutations,
      products: productsById,
    );
  }

  /// Calculates total profit from all stock-out mutations, using each
  /// mutation's price snapshots (see [profitForMutation]). Mutations
  /// whose prices can't be resolved contribute nothing.
  ///
  /// [period] defaults to [ReportPeriod.allTime]; pass a bounded period to
  /// scope the total to it.
  Future<double> calculateTotalProfit([
    ReportPeriod period = const ReportPeriod.allTime(),
  ]) async {
    final stockOutMutations = await getStockOutMutationsInPeriod(period);

    double totalProfit = 0.0;
    for (final mutation in stockOutMutations) {
      totalProfit += (await profitForMutation(mutation)) ?? 0;
    }

    return totalProfit;
  }

  /// Calculates profit grouped by date. Returns a map of date -> profit.
  /// Only includes dates with stock-out mutations.
  ///
  /// [period] defaults to [ReportPeriod.allTime]; pass a bounded period to
  /// scope the grouping to it. Keys are local midnight dates, matching the
  /// local-day boundaries [ReportPeriod] filters on.
  Future<Map<DateTime, double>> calculateProfitByDate([
    ReportPeriod period = const ReportPeriod.allTime(),
  ]) async {
    final stockOutMutations = await getStockOutMutationsInPeriod(period);

    final profitByDate = <DateTime, double>{};

    for (final mutation in stockOutMutations) {
      final profit = await profitForMutation(mutation);
      if (profit == null) continue;

      final dateKey = DateTime(
        mutation.createdAt.year,
        mutation.createdAt.month,
        mutation.createdAt.day,
      );

      profitByDate[dateKey] = (profitByDate[dateKey] ?? 0) + profit;
    }

    return profitByDate;
  }

  /// Calculates profit grouped by month. Returns a map of "Bulan Tahun" -> profit.
  ///
  /// [period] defaults to [ReportPeriod.allTime]; pass a bounded period to
  /// scope the grouping to it.
  Future<Map<String, double>> calculateProfitByMonth([
    ReportPeriod period = const ReportPeriod.allTime(),
  ]) async {
    final profitByDate = await calculateProfitByDate(period);
    final profitByMonth = <String, double>{};

    for (final entry in profitByDate.entries) {
      final date = entry.key;
      final monthKey = '${_getMonthName(date.month)} ${date.year}';
      profitByMonth[monthKey] = (profitByMonth[monthKey] ?? 0) + entry.value;
    }

    return profitByMonth;
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }
}

class StockMutationTotals {
  const StockMutationTotals({required this.stockIn, required this.stockOut});

  final double stockIn;
  final double stockOut;
}
