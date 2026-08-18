import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/profit_report.dart';
import 'date_range_picker_sheet.dart';

/// Formats a [ReportPeriod] for display. Shared with any caller that
/// needs to label which period a set of numbers belongs to.
///
/// For an all-time period this returns the bare word "Semua", which says
/// nothing about *which* dates the numbers cover. Prefer
/// [buildPeriodLabel]: it is the label every output actually renders, and
/// it resolves "Semua" into the real span of the sales behind the figures.
String formatReportPeriod(ReportPeriod period) {
  if (period.isAllTime) return 'Semua';
  final format = DateFormat('d MMM yyyy', 'id_ID');
  final start = format.format(period.startDay!);
  final end = format.format(period.endDay!);
  return start == end ? start : '$start - $end';
}

/// Printed as the period when the report covers all time but no sale
/// qualifies for the profit calculation — there is no date range to
/// report, and inventing one (or falling back to the epoch) would be a
/// lie. Public so every renderer and its tests refer to the same string.
const String kRecapNoTransactionsPeriod = 'Belum ada transaksi';

/// **The** period label. Every surface that names the period of a profit
/// report — the Detail Keuntungan sub-text, the Rekap Keuntungan
/// "Periode:" line, the copied recap text, the share subject and the PDF
/// header — renders the string this function returns, so they cannot
/// disagree about the same report.
///
/// * A bounded period prints exactly the range that was selected
///   ([formatReportPeriod], collapsed to one date when start == end).
///   [allTimeRange] is ignored: a selected window must never be widened by
///   the data that happens to sit outside it.
/// * All-time resolves to `"<earliest sale> - <latest sale> (Semua)"`,
///   collapsing to `"<date> (Semua)"` for a single sale. [allTimeRange]
///   must come from `StockMutationRepository.getProfitableStockOutDateRange`,
///   whose predicate — a stock-out whose sell *and* cost price both
///   resolve — is deliberately the same one the profit total uses. Any
///   looser source (the oldest mutation of any type, say, or "today")
///   would put dates in the label that contributed nothing to the figure
///   printed beside it.
/// * All-time with no qualifying sale yields [kRecapNoTransactionsPeriod].
///
/// Note what is *absent*: the clock. The end of an all-time range is the
/// latest sale, never `DateTime.now()` — the period describes the data,
/// not the moment the report was printed. (The PDF states its generation
/// time separately, on its own "Dibuat:" line.)
String buildPeriodLabel(ReportPeriod period, {ProfitDateRange? allTimeRange}) {
  if (!period.isAllTime) return formatReportPeriod(period);
  if (allTimeRange == null) return kRecapNoTransactionsPeriod;

  // Routed through ReportPeriod/formatReportPeriod rather than a second
  // date formatter of its own, so the resolved span reads exactly like
  // every other period label in the app. ReportPeriod's future-end
  // clamping is neutralised by passing the latest sale as `today`: these
  // are recorded dates, not a range to be sanity-checked against now.
  final span = ReportPeriod.days(
    allTimeRange.earliest,
    allTimeRange.latest,
    today: allTimeRange.latest,
  );
  return '${formatReportPeriod(span)} '
      '(${formatReportPeriod(const ReportPeriod.allTime())})';
}

/// The warning shown when an inverted range somehow reaches
/// [ReportPeriodFilter]. Public so both the widget and its tests refer to
/// the same string.
const String kInvertedRangeWarning =
    'Tanggal mulai tidak boleh setelah tanggal akhir';

/// The one date-range filter used by every profit report screen.
///
/// Extracted from Detail Keuntungan — which is the canonical treatment —
/// so Rekap Keuntungan cannot drift away from it again. Both screens
/// render the identical control and get the identical behaviour:
///
/// * boundaries are inclusive on both ends; [ReportPeriod] turns the two
///   picked calendar days into `start 00:00:00.000 .. end 23:59:59.999`
///   local (implemented as a half-open bound so a sub-millisecond tail
///   can't be dropped — see [ReportPeriod]),
/// * [onChanged] fires with the new period, and callers re-run their
///   query from it, so picking a range always rebuilds,
/// * "Semua" (all-time) is a distinct state, not a very wide range, and
///   is reachable through its own button,
/// * an end day before the start day is impossible: [showDateRangePicker]
///   won't produce one, and if one ever arrives anyway the period is
///   rejected and [kInvertedRangeWarning] is shown instead of being
///   silently swapped.
class ReportPeriodFilter extends StatelessWidget {
  const ReportPeriodFilter({
    super.key,
    required this.period,
    required this.onChanged,
    this.keyPrefix = 'report_period',
    this.enabled = true,
  });

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  /// Prefix for the widget keys of the two buttons, so a screen hosting
  /// more than one filter (or a test targeting a specific screen) can
  /// still address them unambiguously.
  final String keyPrefix;

  /// False while the hosting screen is busy loading, which greys the
  /// picker out rather than queueing up a second query.
  final bool enabled;

  Future<void> _pickRange(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDateRangePickerSheet(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      initialRange: period.isAllTime
          ? null
          : DateTimeRange(start: period.startDay!, end: period.endDay!),
    );
    if (picked == null || !context.mounted) return;

    // The sheet's own "Terapkan" gating already keeps end >= start, so
    // this catch is a backstop rather than the primary defence — but it
    // is the one that guarantees the user sees *why* nothing was applied
    // if it ever does.
    try {
      onChanged(ReportPeriod.days(picked.start, picked.end, today: today));
    } on ArgumentError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('report_period_inverted_warning'),
          content: Text(kInvertedRangeWarning),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: Key('${keyPrefix}_pick_range_button'),
            onPressed: enabled ? () => _pickRange(context) : null,
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(
              period.isAllTime ? 'Pilih Tanggal Range' : formatReportPeriod(period),
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (!period.isAllTime) ...[
          const SizedBox(width: 8),
          TextButton(
            key: Key('${keyPrefix}_clear_range_button'),
            onPressed:
                enabled ? () => onChanged(const ReportPeriod.allTime()) : null,
            child: const Text('Semua', style: TextStyle(fontSize: 13)),
          ),
        ],
      ],
    );
  }
}
