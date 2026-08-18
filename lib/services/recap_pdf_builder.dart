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
/// - [generatedAt] the "Dibuat:" timestamp; defaults to [DateTime.now].
///                It says when the document was printed and nothing more —
///                it is deliberately *not* an end date for [periodLabel].
/// - [periodLabel] the finished "Periode:" string, built by the caller
///                with `buildPeriodLabel`. Taken as a string rather than
///                re-derived here so the PDF header cannot say anything
///                different from the screen the user pressed Share on;
///                it also keeps this builder free of any dependency on
///                the UI layer or the repository.
/// - [fonts]      embedded font faces; when null the PDF falls back to the
///                built-in Helvetica (Latin-1 only).
///
/// An empty report (no product lines) produces a **valid PDF** that states
/// there is no data, rather than blocking the share — see the empty-state
/// message below.
Future<Uint8List> buildRecapPdf({
  required ProfitReport report,
  required String periodLabel,
  String? shopName,
  DateTime? generatedAt,
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
