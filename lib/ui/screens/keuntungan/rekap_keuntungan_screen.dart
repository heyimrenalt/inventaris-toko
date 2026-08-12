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
import '../../widgets/app_header.dart';
import '../../widgets/report_period_filter.dart';

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
  bool _loading = true;

  /// True while a PDF is being generated and shared. Disables the Share
  /// button and swaps its label for a spinner so a double-tap can't kick
  /// off two concurrent generations.
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
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _report = report;
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

  String _getPeriodLabel() => formatReportPeriod(_period);

  String _formatQty(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _copyToClipboard() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('📊 REKAP KEUNTUNGAN TOKO');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('Periode: ${_getPeriodLabel()}');
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
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
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
      // Only an all-time report needs the earliest mutation, so the query
      // is skipped entirely for a bounded period — which already carries
      // its own dates.
      final earliestMutationAt = report.period.isAllTime
          ? await widget.mutationRepository.getEarliestMutationDate()
          : null;
      final fonts = await loadRecapPdfFonts();
      final bytes = await buildRecapPdf(
        report: report,
        earliestMutationAt: earliestMutationAt,
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
          subject: 'Rekap Keuntungan - ${_getPeriodLabel()}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat PDF: $e'),
          backgroundColor: Colors.red,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelection(),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            // An empty period gets its own explicit message rather than a
            // wall of zeroes, which reads as a bug rather than as
            // "nothing was sold then".
            else if (report == null || report.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    _emptyPeriodMessage,
                    key: const Key('recap_empty_period'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              )
            else ...[
              _buildSummary(report),
              const SizedBox(height: 20),
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
                onPressed: _copyToClipboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100],
                  foregroundColor: Colors.blue[900],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.share, size: 18),
                label: Text(_sharing ? 'Membuat PDF...' : 'Share'),
                onPressed: _sharing ? null : _shareRecap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.shade300,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Periode',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          // The exact same widget Detail Keuntungan uses, so the two
          // filters cannot drift apart again.
          ReportPeriodFilter(
            keyPrefix: 'recap_period',
            period: _period,
            onChanged: _applyPeriod,
            enabled: !_loading,
          ),
          const SizedBox(height: 12),
          // The active period is always visible, so the numbers below can
          // never be mistaken for a different period's.
          Row(
            children: [
              const Icon(Icons.event, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Periode: ${_getPeriodLabel()}',
                  key: const Key('recap_active_period_label'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Total',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.green.shade600 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(ProfitReport report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Per Produk (${report.lines.length})',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.lines.length,
            separatorBuilder: (context, index) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final item = report.lines[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${item.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Harga Jual: ${_formatCurrency(item.averageSellPrice)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Terjual: ${_formatQty(item.quantitySold)} pcs',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modal: ${_formatCurrency(item.averageCostPrice)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Profit: ${_formatCurrency(item.profit)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade600,
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
