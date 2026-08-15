import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/profit_report.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/report_period_filter.dart';
import 'rekap_keuntungan_screen.dart';

class KeuntunganDetailScreen extends StatefulWidget {
  const KeuntunganDetailScreen({
    super.key,
    required this.isar,
    this.mutationRepository,
  });

  final Isar isar;
  final StockMutationRepository? mutationRepository;

  @override
  State<KeuntunganDetailScreen> createState() => _KeuntunganDetailScreenState();
}

class _KeuntunganDetailScreenState extends State<KeuntunganDetailScreen> {
  late final StockMutationRepository _mutationRepository =
      widget.mutationRepository ?? StockMutationRepository(widget.isar);

  double _totalProfit = 0.0;
  Map<DateTime, double> _profitByDate = {};

  /// The real span of sales behind the all-time total, shown under the
  /// title so "Semua" carries date information instead of none. `null`
  /// while a specific range is selected (the range is already in the
  /// title) and when no sale qualifies for the profit calculation at all.
  ProfitDateRange? _allTimeRange;
  final Map<String, bool> _expandedMonths = {};
  bool _loading = true;

  /// The period every figure on this screen is computed for. It is passed
  /// straight into the repository queries, so changing it necessarily
  /// re-runs them — there is no separate unfiltered "grand total" that
  /// could keep showing all-time numbers while a range is active.
  ReportPeriod _period = const ReportPeriod.allTime();

  /// Discards a slow response that finished after a newer one, which the
  /// 2-second refresh timer makes easy to provoke while changing periods.
  int _requestId = 0;

  late Timer _refreshTimer;
  StreamSubscription<void>? _mutationsSubscription;

  @override
  void initState() {
    super.initState();
    _load();

    _mutationsSubscription = widget.isar.stockMutations.watchLazy().listen((_) => _load());
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _mutationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    final period = _period;

    // Both figures come from the same period, aggregated from the
    // StockMutation ledger. The headline total is *not* a separate
    // all-time query any more: that mismatch was why selecting a range
    // appeared to change nothing.
    final profitByDate = await _mutationRepository.calculateProfitByDate(period);
    final totalProfit = profitByDate.values.fold<double>(0, (sum, v) => sum + v);

    // Only "Semua" needs the resolved span: a bounded period already
    // states its own dates in the title. Fetched inside the one existing
    // load path (watchLazy + the 2-second timer both call it), so the
    // range refreshes with the figures and no second timer is added.
    final allTimeRange = period.isAllTime
        ? await _mutationRepository.getProfitableStockOutDateRange()
        : null;

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _totalProfit = totalProfit;
      _profitByDate = profitByDate;
      _allTimeRange = allTimeRange;
      _loading = false;

      for (final date in profitByDate.keys) {
        _expandedMonths.putIfAbsent('${_getMonthName(date.month)} ${date.year}', () => false);
      }
    });
  }

  /// The only way [_period] changes — it always re-runs the query.
  void _applyPeriod(ReportPeriod period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _loading = true;
    });
    _load();
  }

  /// "3 Jan 2026 - 11 Agu 2026 (Semua)" — the span the all-time total is
  /// actually made of, followed by the filter the user selected. Built by
  /// the shared [buildPeriodLabel], so this sub-text is byte-identical to
  /// the period Rekap Keuntungan shows, copies, shares and prints.
  ///
  /// `null` — meaning no sub-text renders at all — in the two cases where
  /// this screen has nothing to add: a bounded period (its dates are
  /// already in the title right above) and an all-time period with no
  /// qualifying sale (the title stands alone rather than carrying a
  /// placeholder). The latter is why the empty case is handled here and
  /// not by [buildPeriodLabel]'s [kRecapNoTransactionsPeriod], which the
  /// other surfaces do render.
  String? _allTimeRangeLabel() {
    final range = _allTimeRange;
    if (!_period.isAllTime || range == null) return null;
    return buildPeriodLabel(_period, allTimeRange: range);
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return 'Rp ${formatter.format(value.toInt())}';
  }

  List<MapEntry<DateTime, double>> _getDaysInMonth(
    String monthKey,
    List<MapEntry<DateTime, double>> filteredDates,
  ) {
    final datesByMonth = <DateTime, double>{};

    for (final entry in filteredDates) {
      final date = entry.key;
      final monthName = _getMonthName(date.month);
      final key = '$monthName ${date.year}';

      if (key == monthKey) {
        datesByMonth[date] = entry.value;
      }
    }

    final sorted = datesByMonth.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted;
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hari ini, ${DateFormat('d MMM', 'id_ID').format(date)}';
    } else if (dateOnly == yesterday) {
      return 'Kemarin, ${DateFormat('d MMM', 'id_ID').format(date)}';
    } else {
      return DateFormat('d MMM', 'id_ID').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppHeader.withBack(title: 'Detail Keuntungan'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => await _load(),
              child: Column(
                children: [
                  // Fixed header area
                  SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTotalSection(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildFilterSection(),
                        ],
                      ),
                    ),
                  ),
                  // Scrollable monthly cards area
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: _buildMonthlySection(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalSection() {
    final rangeLabel = _allTimeRangeLabel();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _period.isAllTime
                    ? 'Total Keuntungan Keseluruhan'
                    : 'Total Keuntungan ${formatReportPeriod(_period)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (rangeLabel != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  rangeLabel,
                  key: const Key('keuntungan_all_time_range'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                _formatCurrency(_totalProfit),
                style: AppTextStyles.displayNumber.copyWith(
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.file_download, color: AppColors.white),
              tooltip: 'Lihat Rekap',
              onPressed: _openRekapScreen,
            ),
          ),
        ],
      ),
    );
  }

  /// Pushed as a normal route rather than shown as a modal sheet, so the
  /// recap gets the same AppHeader (title + back button) and scaffold
  /// background as every other menu screen.
  void _openRekapScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RekapKeuntunganScreen(
          isar: widget.isar,
          mutationRepository: _mutationRepository,
          // Opens on whatever period is being viewed here, so the two
          // screens agree on the period the user is looking at.
          initialPeriod: _period,
        ),
      ),
    );
  }

  /// The canonical filter, now living in a shared widget so Rekap
  /// Keuntungan renders the identical control with identical behaviour.
  Widget _buildFilterSection() {
    return ReportPeriodFilter(
      keyPrefix: 'keuntungan',
      period: _period,
      onChanged: _applyPeriod,
    );
  }

  Widget _buildMonthlySection() {
    // No filtering here: _profitByDate is already scoped to _period by
    // the query itself. Filtering after aggregation is exactly the bug
    // this screen used to have.
    final filteredDates = _profitByDate.entries.toList();

    final filteredMonthsMap = <String, double>{};
    for (final entry in filteredDates) {
      final date = entry.key;
      final profit = entry.value;
      final monthName = _getMonthName(date.month);
      final key = '$monthName ${date.year}';
      filteredMonthsMap[key] = (filteredMonthsMap[key] ?? 0) + profit;
    }

    final sortedMonths = filteredMonthsMap.entries.toList()
      ..sort((a, b) {
        final dateA = _parseDateFromKey(a.key);
        final dateB = _parseDateFromKey(b.key);
        return dateB.compareTo(dateA);
      });

    if (sortedMonths.isEmpty) {
      return Text(
        _period.isAllTime
            ? 'Belum ada data keuntungan'
            : 'Tidak ada transaksi pada periode ini',
        key: const Key('keuntungan_empty_period'),
        style: AppTextStyles.body.copyWith(color: AppColors.gray700),
      );
    }

    return Column(
      children: List.generate(
        sortedMonths.length,
        (index) {
          final monthEntry = sortedMonths[index];
          final month = monthEntry.key;
          final profit = monthEntry.value;
          final isExpanded = _expandedMonths[month] ?? false;
          final daysInMonth = _getDaysInMonth(month, filteredDates);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedMonths[month] = !isExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppDimensions.inputRadius),
                        topRight: const Radius.circular(AppDimensions.inputRadius),
                        bottomLeft: Radius.circular(
                          isExpanded ? 0 : AppDimensions.inputRadius,
                        ),
                        bottomRight: Radius.circular(
                          isExpanded ? 0 : AppDimensions.inputRadius,
                        ),
                      ),
                      border: Border.all(color: AppColors.gray300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              month,
                              style: AppTextStyles.subheading,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${daysInMonth.length} hari transaksi',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.gray600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _formatCurrency(profit),
                              style: AppTextStyles.subheading.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: AppColors.gray500,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppDimensions.inputRadius),
                        bottomRight: Radius.circular(AppDimensions.inputRadius),
                      ),
                      border: const Border(
                        left: BorderSide(color: AppColors.gray300),
                        right: BorderSide(color: AppColors.gray300),
                        bottom: BorderSide(color: AppColors.gray300),
                      ),
                    ),
                    constraints: const BoxConstraints(maxHeight: 350),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: daysInMonth.length,
                      itemBuilder: (context, dayIndex) {
                        final dayEntry = daysInMonth[dayIndex];
                        final date = dayEntry.key;
                        final dayProfit = dayEntry.value;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: dayIndex == daysInMonth.length - 1
                                ? 0
                                : AppSpacing.md,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(date),
                                style: AppTextStyles.body,
                              ),
                              Text(
                                _formatCurrency(dayProfit),
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  DateTime _parseDateFromKey(String key) {
    final parts = key.split(' ');
    final monthName = parts[0];
    final year = int.parse(parts[1]);

    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    final month = months.indexOf(monthName) + 1;
    return DateTime(year, month);
  }
}
