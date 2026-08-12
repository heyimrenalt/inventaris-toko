import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/profit_report.dart';

/// Formats a numeric Rupiah amount the same way the on-screen recap does:
/// `NumberFormat('#,##0', 'id_ID')` with a leading `Rp ` and a thousands
/// separator (`Rp 643.000`). Kept as a top-level pure function so both the
/// PDF and its unit tests share one implementation.
///
/// - `643000` -> `Rp 643.000`
/// - `0`      -> `Rp 0`
/// - negative -> rendered with a leading minus (`Rp -500.000`)
///
/// The value is truncated toward zero (`toInt()`) exactly as the existing
/// `_formatCurrency` helpers do, so the PDF and the screen never disagree
/// on the last digit.
String formatRecapCurrency(num value) {
  final formatter = NumberFormat('#,##0', 'id_ID');
  return 'Rp ${formatter.format(value.toInt())}';
}

/// Quantity formatting shared with the on-screen recap: whole numbers drop
/// the decimal, fractional quantities keep it.
String _formatQty(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// Printed as the period when the report covers all time but the ledger
/// holds no mutations at all — there is no earliest date to report, and
/// inventing one (or falling back to the epoch) would be a lie. Public so
/// the PDF and its tests refer to the same string.
const String kRecapNoTransactionsPeriod = 'Belum ada transaksi';

/// The reporting-period label used in the PDF header.
///
/// A bounded window prints exactly the range that was selected, formatted
/// as a `d MMM yyyy` range (collapsed to a single date when start and end
/// fall on the same day) — the same format the on-screen filter uses.
///
/// "Semua" (all-time) is **resolved to a real range** rather than printed
/// as the uninformative "Semua Periode": it runs from
/// [earliestMutationAt]'s calendar day — the `createdAt` of the oldest
/// mutation in the database, see
/// `StockMutationRepository.getEarliestMutationDate` — through [today],
/// the day the PDF is generated. Both ends are reduced to their *local*
/// calendar day, matching how [ReportPeriod] computes filter boundaries,
/// so a mutation recorded late in the evening still reports its own day.
///
/// With no mutations at all ([earliestMutationAt] is null) there is no
/// honest range, so [kRecapNoTransactionsPeriod] is printed instead.
/// A single mutation — or one recorded today — yields start == end, which
/// is valid and collapses to that one date.
String recapPeriodLabel(
  ReportPeriod period, {
  DateTime? earliestMutationAt,
  DateTime? today,
}) {
  final format = DateFormat('d MMM yyyy', 'id_ID');

  if (period.isAllTime) {
    if (earliestMutationAt == null) return kRecapNoTransactionsPeriod;
    final start = _dayOf(earliestMutationAt);
    final end = _dayOf(today ?? DateTime.now());
    return _range(format, start, end);
  }

  return _range(format, period.startDay!, period.endDay!);
}

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

String _range(DateFormat format, DateTime startDay, DateTime endDay) {
  final start = format.format(startDay);
  final end = format.format(endDay);
  return start == end ? start : '$start - $end';
}

/// The fonts embedded in the recap PDF. Bundling a TrueType font (rather
/// than relying on the PDF standard Type1 Helvetica, which only covers
/// Latin-1) is what lets non-ASCII product names render correctly.
class RecapPdfFonts {
  const RecapPdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;
}

/// Loads the app's bundled Plus Jakarta Sans font for embedding in the PDF.
///
/// This is the one impure step (it touches [rootBundle]), kept out of
/// [buildRecapPdf] so the builder itself stays a pure, unit-testable
/// function. The app calls this and hands the result to [buildRecapPdf];
/// tests omit it and fall back to the built-in Helvetica.
Future<RecapPdfFonts> loadRecapPdfFonts() async {
  final data =
      await rootBundle.load('assets/fonts/PlusJakartaSans-VariableFont_wght.ttf');
  // The variable font renders its default (regular) instance; the PDF
  // engine cannot pick a `wght` axis value, so "bold" reuses the same
  // glyphs and relies on the table layout for emphasis. A single embedded
  // face is enough to cover the Latin glyph range product names use.
  final font = pw.Font.ttf(data);
  return RecapPdfFonts(regular: font, bold: font);
}

/// Builds the "Rekap Keuntungan" PDF as raw bytes.
///
/// A **pure function of its inputs**: it takes an already-built
/// [ProfitReport] plus optional presentation inputs and never touches a
/// [BuildContext], Isar, or the clock unless [generatedAt] is omitted. That
/// makes it directly unit-testable.
///
/// - [report]     the profit figures to render (totals + per-product lines).
/// - [shopName]   shown as the header title when non-empty; otherwise a
///                generic "Rekap Keuntungan Toko" title is used.
/// - [generatedAt] the "dibuat" timestamp; defaults to [DateTime.now]. It
///                is also the end of the resolved range for an all-time
///                report ("today").
/// - [earliestMutationAt] the `createdAt` of the oldest mutation in the
///                database, used only to resolve an all-time period into a
///                real date range. Null (or omitted) for a bounded period,
///                and null for an empty ledger — see [recapPeriodLabel].
/// - [fonts]      embedded font faces; when null the PDF falls back to the
///                built-in Helvetica (Latin-1 only).
///
/// An empty report (no product lines) produces a **valid PDF** that states
/// there is no data, rather than blocking the share — see the empty-state
/// message below.
Future<Uint8List> buildRecapPdf({
  required ProfitReport report,
  String? shopName,
  DateTime? generatedAt,
  DateTime? earliestMutationAt,
  RecapPdfFonts? fonts,
}) async {
  final timestamp = generatedAt ?? DateTime.now();
  final title = (shopName != null && shopName.trim().isNotEmpty)
      ? shopName.trim()
      : 'Rekap Keuntungan Toko';

  final theme = fonts == null
      ? null
      : pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold);

  final doc = pw.Document();

  final timestampLabel =
      DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(timestamp);
  final periodLabel = recapPeriodLabel(
    report.period,
    earliestMutationAt: earliestMutationAt,
    today: timestamp,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: theme,
      header: (context) => context.pageNumber == 1
          ? _buildHeader(title, timestampLabel, periodLabel)
          : pw.SizedBox(height: 0),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Halaman ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) {
        if (report.isEmpty) {
          return [
            pw.SizedBox(height: 24),
            pw.Center(
              child: pw.Text(
                'Tidak ada data penjualan pada periode ini.',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ),
          ];
        }
        // Returned as a flat list of top-level widgets. The product table
        // is a *direct* child (not nested in a Column) so MultiPage can
        // split it across pages; a table wrapped inside another multi-child
        // widget is treated as atomic and would overflow instead.
        return [
          _buildSummary(report),
          pw.SizedBox(height: 20),
          pw.Text(
            'Detail Per Produk (${report.lines.length})',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildProductTable(report),
        ];
      },
    ),
  );

  return doc.save();
}

pw.Widget _buildHeader(String title, String timestampLabel, String periodLabel) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Periode: $periodLabel',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
      ),
      pw.Text(
        'Dibuat: $timestampLabel',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 1, color: PdfColors.grey400),
      pw.SizedBox(height: 4),
    ],
  );
}

pw.Widget _buildSummary(ProfitReport report) {
  pw.Widget row(String label, String value, {bool highlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey800,
              fontWeight: highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: highlight ? PdfColors.green800 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: PdfColors.grey300),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Ringkasan Total',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        row('Total Penjualan', formatRecapCurrency(report.totalRevenue)),
        row('Total Modal', formatRecapCurrency(report.totalCost)),
        row('Total Keuntungan', formatRecapCurrency(report.totalProfit),
            highlight: true),
        row('Total Produk', '${report.productsSold} jenis'),
        row('Total Stok', '${_formatQty(report.totalQuantitySold)} pcs'),
      ],
    ),
  );
}

pw.Widget _buildProductTable(ProfitReport report) {
  final headers = [
    'No.',
    'Nama Produk',
    'Harga Jual',
    'Modal',
    'Terjual',
    'Profit',
  ];

  final data = <List<String>>[
    for (var i = 0; i < report.lines.length; i++)
      () {
        final line = report.lines[i];
        return <String>[
          '${i + 1}',
          line.name,
          formatRecapCurrency(line.averageSellPrice),
          formatRecapCurrency(line.averageCostPrice),
          _formatQty(line.quantitySold),
          formatRecapCurrency(line.profit),
        ];
      }(),
  ];

  // TableHelper.fromTextArray inside a MultiPage splits across pages and
  // repeats the header row on every page automatically. Cell text wraps, so
  // very long product names grow the row height instead of breaking the
  // layout.
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: data,
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    headerStyle: pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellHeight: 18,
    headerAlignment: pw.Alignment.centerLeft,
    cellAlignments: {
      0: pw.Alignment.centerRight,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.centerRight,
    },
    columnWidths: {
      0: const pw.FixedColumnWidth(24),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(1.6),
      3: const pw.FlexColumnWidth(1.6),
      4: const pw.FlexColumnWidth(1.1),
      5: const pw.FlexColumnWidth(1.6),
    },
  );
}
