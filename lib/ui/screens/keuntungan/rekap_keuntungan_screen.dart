import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/profit_report.dart';
import '../../../services/recap_pdf_builder.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/report_period_filter.dart';
import '../../widgets/secondary_button.dart';

/// Shown instead of a screen full of zeroes when the selected period
/// contains no sales — "no transactions" and "zero profit" are different
/// facts and must not look identical.
const String _emptyPeriodMessage = 'Tidak ada transaksi pada periode ini';

/// The "Rekap Keuntungan" report.
///
/// A full screen rather than a modal sheet, so it carries the same
/// [AppHeader] (title + back button) and the same
/// [AppColors.scaffoldBackground] as Detail Keuntungan and every other
/// menu screen. As a sheet its background came from the Material 3
/// default (`colorScheme.surfaceContainerLow`), which is tinted towards
/// the green seed colour — that was the stray green tint.
class RekapKeuntunganScreen extends StatefulWidget {
  const RekapKeuntunganScreen({
    super.key,
    required this.isar,
    required this.mutationRepository,
    this.initialPeriod = const ReportPeriod.allTime(),
  });

  final Isar isar;
  final StockMutationRepository mutationRepository;

  /// The period the sheet opens on. Defaults to "Semua"; a caller (or a
  /// test) can hand it a range instead.
  final ReportPeriod initialPeriod;

  @override
  State<RekapKeuntunganScreen> createState() => _RekapKeuntunganScreenState();
}

class _RekapKeuntunganScreenState extends State<RekapKeuntunganScreen> {
  /// The single piece of state that drives the query. Every figure on
  /// screen is derived from the report fetched for *this* period — there
  /// is no second, widget-local copy of the dates that the query could
  /// fall out of sync with, which is what made the old filter inert.
  late ReportPeriod _period = widget.initialPeriod;

  ProfitReport? _report;

  /// The real span of sales behind an all-time report, resolved once per
  /// load and shared by every output this screen produces — the "Periode:"
  /// line, the copied text, the share subject and the PDF header. `null`
  /// while a bounded period is selected (it carries its own dates) and
  /// when no sale qualifies for the profit calculation.
  ProfitDateRange? _allTimeRange;

  bool _loading = true;

  /// True while a PDF is being generated and shared. Disables the Bagikan
  /// button and swaps its label for progress text so a double-tap can't
  /// kick off two concurrent generations.
  bool _sharing = false;

  /// Guards against an out-of-order response overwriting a newer one when
  /// the user changes the period again while a query is still running.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadRecapData();
  }

  /// Sets the period and immediately re-runs the query. The only way the
  /// period changes, so a range change can never fail to refresh the UI.
  void _applyPeriod(ReportPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    _loadRecapData();
  }

  Future<void> _loadRecapData() async {
    final requestId = ++_requestId;
    final period = _period;
    // Guarded: the first call comes from initState, where _loading is
    // already true and setState() is illegal.
    if (!_loading) setState(() => _loading = true);

    try {
      final report = await widget.mutationRepository.buildProfitReport(period);
      // Only "Semua" needs the resolved span, so the query is skipped
      // entirely for a bounded period. Fetched here, in the one load path,
      // rather than at share time: the label is now on screen too, and
      // every output must read the same value.
      final allTimeRange = period.isAllTime
          ? await widget.mutationRepository.getProfitableStockOutDateRange()
          : null;
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _report = report;
        _allTimeRange = allTimeRange;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return 'Rp ${formatter.format(value.toInt())}';
  }

  /// The single period string this screen renders. Read by the "Periode:"
  /// line, [_copyToClipboard], [shareSubject] and the PDF header, so all
  /// four are byte-identical by construction — there is no second
  /// derivation any of them could drift away from.
  ///
  /// Exposed (on an otherwise private State) so a test can assert that
  /// identity against the strings the other surfaces actually render.
  @visibleForTesting
  String get periodLabel =>
      buildPeriodLabel(_period, allTimeRange: _allTimeRange);

  /// The subject line attached to the shared PDF. Split out from the
  /// share call so it is assertable without mocking the platform share
  /// sheet, the temp directory and the font bundle.
  @visibleForTesting
  String get shareSubject => 'Rekap Keuntungan - $periodLabel';

  String _formatQty(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _copyToClipboard() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('📊 REKAP KEUNTUNGAN TOKO');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('Periode: $periodLabel');
      buffer.writeln('');
      final report = _report;
      if (report == null || report.isEmpty) {
        buffer.writeln(_emptyPeriodMessage);
      } else {
        buffer.writeln('💰 RINGKASAN TOTAL:');
        buffer.writeln('Total Penjualan  : ${_formatCurrency(report.totalRevenue)}');
        buffer.writeln('Total Modal      : ${_formatCurrency(report.totalCost)}');
        buffer.writeln('Total Keuntungan : ${_formatCurrency(report.totalProfit)}');
        buffer.writeln('');
        buffer.writeln('📦 PRODUK TERJUAL:');
        buffer.writeln('Total Produk : ${report.productsSold} jenis');
        buffer.writeln('Total Terjual: ${_formatQty(report.totalQuantitySold)} pcs');
        buffer.writeln('');
        buffer.writeln('📋 DETAIL PER PRODUK:');
        buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');

        for (int i = 0; i < report.lines.length; i++) {
          final item = report.lines[i];
          buffer.writeln('${i + 1}. ${item.name}');
          buffer.writeln('   Harga Jual: ${_formatCurrency(item.averageSellPrice)}');
          buffer.writeln('   Modal: ${_formatCurrency(item.averageCostPrice)}');
          buffer.writeln('   Keuntungan: ${_formatCurrency(item.profit)}');
          buffer.writeln('   Terjual: ${_formatQty(item.quantitySold)} pcs');
          buffer.writeln('');
        }
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (!mounted) return;

      // Show snackbar properly
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Rekap berhasil disalin ke clipboard'),
          duration: Duration(seconds: 3),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.redPrimary,
        ),
      );
    }
  }

  /// Builds a filename-safe slug for the current period, e.g.
  /// `semua-2026-07-25` or `2026-07-01_2026-07-25`.
  String _fileSlug() {
    final fmt = DateFormat('yyyy-MM-dd');
    if (_period.isAllTime) {
      return 'semua-${fmt.format(DateTime.now())}';
    }
    return '${fmt.format(_period.startDay!)}_${fmt.format(_period.endDay!)}';
  }

  /// Generates the recap as a PDF and hands it to the Android share sheet.
  ///
  /// Replaces the old ASCII-box text share. The Copy button still shares
  /// plain text; only this path produces a PDF.
  Future<void> _shareRecap() async {
    if (_sharing) return;
    final report = _report;
    if (report == null) return;

    setState(() => _sharing = true);
    try {
      final fonts = await loadRecapPdfFonts();
      final bytes = await buildRecapPdf(
        report: report,
        // The same string the user is looking at, not a second derivation
        // of it. The PDF's own "Dibuat:" line still carries today's date.
        periodLabel: periodLabel,
        fonts: fonts,
      );

      final dir = await getTemporaryDirectory();
      // Reuse a dedicated sub-folder and wipe previously generated recaps
      // first so temp PDFs can't accumulate indefinitely.
      final outDir = Directory(p.join(dir.path, 'recap_pdf'));
      if (outDir.existsSync()) {
        for (final f in outDir.listSync()) {
          if (f is File && f.path.endsWith('.pdf')) {
            try {
              f.deleteSync();
            } catch (_) {
              // A file still held open by a previous share is not fatal;
              // skip it and carry on.
            }
          }
        }
      } else {
        outDir.createSync(recursive: true);
      }

      final file = File(p.join(outDir.path, 'laporan-keuntungan-${_fileSlug()}.pdf'));
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: shareSubject,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat PDF: $e'),
          backgroundColor: AppColors.redPrimary,
        ),
      );
    } finally {
      // Always re-enable the button, even on error, so it can never get
      // stuck permanently disabled.
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final hasFigures = !_loading && report != null && !report.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppHeader.withBack(title: 'Rekap Keuntungan'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelection(),
            const SizedBox(height: AppSpacing.xl),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            // An empty period gets its own explicit message rather than a
            // wall of zeroes, which reads as a bug rather than as
            // "nothing was sold then".
            else if (report == null || report.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(
                  child: Text(
                    _emptyPeriodMessage,
                    key: const Key('recap_empty_period'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: AppColors.gray600),
                  ),
                ),
              )
            else ...[
              _buildSummary(report),
              const SizedBox(height: AppSpacing.xl),
              _buildProductDetails(report),
            ],
          ],
        ),
      ),
      // Pinned below the scroll area rather than stacked over it, so no
      // manual spacer is needed to keep the last product row reachable.
      bottomNavigationBar: hasFigures ? _buildActionBar() : null,
    );
  }

  Widget _buildActionBar() {
    return SafeArea(
      child: Container(
        color: AppColors.white,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Salin',
                icon: Icons.copy,
                onPressed: _copyToClipboard,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              // No spinner: [PrimaryButton] has no busy state, so the
              // in-progress cue is the disabled style plus the label swap.
              child: PrimaryButton(
                label: _sharing ? 'Membuat PDF...' : 'Bagikan',
                icon: Icons.share,
                onPressed: _sharing ? null : _shareRecap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray300),
        borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Periode',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // The exact same widget Detail Keuntungan uses, so the two
          // filters cannot drift apart again.
          ReportPeriodFilter(
            keyPrefix: 'recap_period',
            period: _period,
            onChanged: _applyPeriod,
            enabled: !_loading,
          ),
          const SizedBox(height: AppSpacing.md),
          // The active period is always visible, so the numbers below can
          // never be mistaken for a different period's.
          Row(
            children: [
              const Icon(
                Icons.event,
                size: AppDimensions.iconXs,
                color: AppColors.gray500,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Periode: $periodLabel',
                  key: const Key('recap_active_period_label'),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(ProfitReport report) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        border: Border.all(color: AppColors.gray300),
        borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Total',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSummaryItem('Total Penjualan', _formatCurrency(report.totalRevenue)),
          _buildSummaryItem('Total Modal', _formatCurrency(report.totalCost)),
          _buildSummaryItem(
            'Total Keuntungan',
            _formatCurrency(report.totalProfit),
            highlight: true,
          ),
          // Products *sold in the period*, not the size of the catalogue.
          // The old catalogue count was identical for every period, which
          // is a large part of why the filter looked like it did nothing.
          _buildSummaryItem('Total Produk', '${report.productsSold} jenis'),
          // Quantity sold in the period. Replaces the old "Total Stok",
          // which reported current inventory — a point-in-time figure with
          // no time dimension, so it could never respond to the range.
          _buildSummaryItem('Total Terjual', '${_formatQty(report.totalQuantitySold)} pcs'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.gray700,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(ProfitReport report) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        border: Border.all(color: AppColors.gray300),
        borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Per Produk (${report.lines.length})',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.lines.length,
            separatorBuilder: (context, index) =>
                const Divider(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = report.lines[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${item.name}',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Harga Jual: ${_formatCurrency(item.averageSellPrice)}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Terjual: ${_formatQty(item.quantitySold)} pcs',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modal: ${_formatCurrency(item.averageCostPrice)}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Profit: ${_formatCurrency(item.profit)}',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
