import '../data/models/product.dart';
import '../data/models/stock_mutation.dart';
import 'mutation_pricing.dart';

/// The period a profit report covers.
///
/// Two genuinely distinct states, never collapsed into one: [allTime]
/// means "no time filter at all" (the query runs without a `createdAt`
/// where-clause), while [ReportPeriod.days] is a real, bounded window.
/// Representing "Semua" as a `DateTime(1970)..now` range would make the
/// two indistinguishable and would quietly become wrong the moment a
/// mutation is recorded outside those arbitrary bounds.
///
/// ## Local time vs UTC
///
/// Isar stores a `DateTime` as `value.toUtc().microsecondsSinceEpoch` and
/// reads it back with `.toLocal()`, so `StockMutation.createdAt` is an
/// *instant* that round-trips through local time. `createdAt` is written
/// as `DateTime.now()` — local. The boundaries here are therefore built
/// with the plain (local) `DateTime(y, m, d)` constructor so that "1
/// August" means the shop's own midnight-to-midnight day, and comparison
/// against a stored instant is apples-to-apples. Nothing in this class
/// ever calls `toUtc()`; local boundaries meet local timestamps.
///
/// ## Boundary inclusivity
///
/// The window is `startInclusive <= createdAt < endExclusive`, where
/// [endExclusive] is midnight at the *start of the day after* the end
/// day. That is exactly "everything up to and including the last instant
/// of the end day" — including 23:59:59.999 — but unlike a literal
/// `23:59:59.999` cut-off it cannot drop a mutation landing in the final
/// sub-millisecond (Isar keeps microsecond precision, and `DateTime.now()`
/// supplies it). [endInclusive] exposes the 23:59:59.999 form for display
/// and documentation.
class ReportPeriod {
  /// No time filter: every mutation ever recorded.
  const ReportPeriod.allTime()
      : _startDay = null,
        _endDay = null;

  /// A closed day-range covering [start]'s day through [end]'s day, both
  /// inclusive. Only the calendar-date part of each argument is used; any
  /// time-of-day is discarded, so a picker that hands back 00:00 and one
  /// that hands back 14:37 produce the same period.
  ///
  /// Throws [ArgumentError] when [end]'s day is before [start]'s day — an
  /// inverted period is not silently repaired by swapping, because that
  /// would hide a real input error from the caller (and from the user).
  /// The UI must prevent the inversion in the first place; this is the
  /// backstop that makes an inverted [ReportPeriod] unconstructible.
  ///
  /// Future dates are **clamped, not rejected**: an end day after [today]
  /// is pulled back to [today]. There can be no sales in the future, so a
  /// future end date is harmless rather than erroneous — clamping keeps
  /// "1 Jan – 31 Dec" usable as "the year so far" instead of failing it.
  /// A *start* day in the future is left alone: it yields a legitimately
  /// empty window rather than being silently rewritten into a different
  /// period than the one asked for.
  factory ReportPeriod.days(DateTime start, DateTime end, {DateTime? today}) {
    final startDay = _dayOf(start);
    var endDay = _dayOf(end);
    if (endDay.isBefore(startDay)) {
      throw ArgumentError('Tanggal akhir tidak boleh sebelum tanggal mulai.');
    }

    final todayDay = _dayOf(today ?? DateTime.now());
    if (endDay.isAfter(todayDay) && !startDay.isAfter(todayDay)) {
      endDay = todayDay;
    }
    return ReportPeriod._(startDay, endDay);
  }

  const ReportPeriod._(this._startDay, this._endDay);

  final DateTime? _startDay;
  final DateTime? _endDay;

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool get isAllTime => _startDay == null;

  /// Local midnight at the beginning of the start day, or `null` for
  /// [ReportPeriod.allTime].
  DateTime? get startInclusive => _startDay;

  /// Local midnight at the beginning of the day *after* the end day — the
  /// exclusive upper bound actually used by the query. `null` for
  /// [ReportPeriod.allTime].
  DateTime? get endExclusive {
    final endDay = _endDay;
    if (endDay == null) return null;
    return DateTime(endDay.year, endDay.month, endDay.day + 1);
  }

  /// The last instant of the end day at millisecond resolution
  /// (23:59:59.999), for labels and docs. The query uses [endExclusive];
  /// see the class doc for why.
  DateTime? get endInclusive {
    final endDay = _endDay;
    if (endDay == null) return null;
    return DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59, 999);
  }

  /// The start day, midnight — same value as [startInclusive], named for
  /// display code that wants the calendar date rather than the bound.
  DateTime? get startDay => _startDay;

  /// The end day, midnight.
  DateTime? get endDay => _endDay;

  /// Whether [instant] falls inside this period. Kept in sync with the
  /// query bounds by construction so in-memory checks and database
  /// filtering can never disagree.
  bool contains(DateTime instant) {
    if (isAllTime) return true;
    return !instant.isBefore(_startDay!) && instant.isBefore(endExclusive!);
  }

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod && other._startDay == _startDay && other._endDay == _endDay;

  @override
  int get hashCode => Object.hash(_startDay, _endDay);
}

/// One product's contribution to a [ProfitReport], aggregated from that
/// product's stock-out mutations inside the report period only.
class ProductProfitLine {
  ProductProfitLine({
    required this.productId,
    required this.name,
    required this.unit,
    required this.quantitySold,
    required this.revenue,
    required this.cost,
  });

  final int productId;

  /// The product's name, or a placeholder when the product row is gone —
  /// a deleted product's historical sales still belong in the report, and
  /// its price snapshots still carry the numbers needed to value them.
  final String name;
  final String unit;

  double quantitySold;
  double revenue;
  double cost;

  double get profit => revenue - cost;

  /// Effective per-unit sell price over the period: total revenue divided
  /// by total quantity. Deliberately derived from the aggregated snapshot
  /// values rather than read from the product, so a later price edit can't
  /// change what a past period reports. Zero quantity can't occur (a line
  /// only exists because something was sold) but is guarded anyway.
  double get averageSellPrice => quantitySold == 0 ? 0 : revenue / quantitySold;

  /// Effective per-unit cost price over the period. See [averageSellPrice].
  double get averageCostPrice => quantitySold == 0 ? 0 : cost / quantitySold;
}

/// Totals plus per-product breakdown for one [ReportPeriod].
class ProfitReport {
  const ProfitReport({
    required this.period,
    required this.totalRevenue,
    required this.totalCost,
    required this.lines,
  });

  const ProfitReport.empty(this.period)
      : totalRevenue = 0,
        totalCost = 0,
        lines = const [];

  final ReportPeriod period;
  final double totalRevenue;
  final double totalCost;

  /// Products with at least one valued stock-out in the period, sorted by
  /// profit descending. A product with no sales in the period is absent
  /// entirely rather than present with zeroes.
  final List<ProductProfitLine> lines;

  double get totalProfit => totalRevenue - totalCost;

  /// Number of *distinct products actually sold* in the period — not the
  /// size of the catalogue. "Total Produk" on a profit report answers
  /// "how many products earned this money", which is the only reading
  /// that varies with the selected range; a catalogue count would be
  /// identical for every period and is what made the old filter look
  /// broken.
  int get productsSold => lines.length;

  double get totalQuantitySold =>
      lines.fold<double>(0, (sum, line) => sum + line.quantitySold);

  /// True when nothing was sold in the period — the signal for the
  /// "Tidak ada transaksi pada periode ini" empty state, which must be
  /// distinguishable from a period that genuinely totalled zero profit.
  bool get isEmpty => lines.isEmpty;
}

/// Folds stock-out mutations into a [ProfitReport].
///
/// Pure and synchronous: it takes rows already loaded from the database
/// plus a product lookup, so the aggregation itself is testable without
/// Isar and the repository stays responsible only for fetching.
class ProfitReportBuilder {
  const ProfitReportBuilder._();

  /// [products] maps product id to the current [Product] row, with a
  /// missing entry meaning the product was deleted.
  ///
  /// A mutation is counted only when [MutationPricing] can resolve *both*
  /// a sell and a cost price for it — from its snapshots, or failing that
  /// from the product. An unresolvable row (no cost data ever recorded, or
  /// a pre-backfill row whose product is also gone) contributes nothing:
  /// "unknown" is not "zero", and inventing a zero would silently inflate
  /// profit. This mirrors [StockMutationRepository.profitForMutation].
  static ProfitReport build({
    required ReportPeriod period,
    required Iterable<StockMutation> stockOutMutations,
    required Map<int, Product> products,
  }) {
    var totalRevenue = 0.0;
    var totalCost = 0.0;
    final byProduct = <int, ProductProfitLine>{};

    for (final mutation in stockOutMutations) {
      if (mutation.type != StockMutationType.stockOut) continue;
      if (!period.contains(mutation.createdAt)) continue;

      final product = products[mutation.productId];
      final prices = MutationPricing.resolve(mutation, product);
      final sellPrice = prices.sellPrice;
      final costPrice = prices.costPrice;
      if (sellPrice == null || costPrice == null) continue;

      final qty = mutation.quantity;
      final revenue = sellPrice * qty;
      final cost = costPrice * qty;

      totalRevenue += revenue;
      totalCost += cost;

      final line = byProduct[mutation.productId];
      if (line == null) {
        byProduct[mutation.productId] = ProductProfitLine(
          productId: mutation.productId,
          name: product?.name ?? 'Produk terhapus (#${mutation.productId})',
          unit: product?.unit ?? '',
          quantitySold: qty,
          revenue: revenue,
          cost: cost,
        );
      } else {
        line
          ..quantitySold += qty
          ..revenue += revenue
          ..cost += cost;
      }
    }

    final lines = byProduct.values.toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));

    return ProfitReport(
      period: period,
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      lines: lines,
    );
  }
}

/// The span of sale dates behind a profit figure — see
/// [StockMutationRepository.getProfitableStockOutDateRange]. Both ends are
/// real `createdAt` instants of qualifying mutations, in local time;
/// [earliest] and [latest] are the same instant when only one sale
/// qualifies.
///
/// Lives in the domain layer rather than beside the repository that
/// produces it because the *label* built from it is rendered by the UI and
/// by the PDF, neither of which should have to import Isar to name a date
/// range.
class ProfitDateRange {
  const ProfitDateRange({required this.earliest, required this.latest});

  final DateTime earliest;
  final DateTime latest;
}
