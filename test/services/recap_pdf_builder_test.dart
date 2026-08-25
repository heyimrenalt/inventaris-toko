import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:inventaris_toko/services/recap_pdf_builder.dart';
import 'package:inventaris_toko/ui/widgets/report_period_filter.dart';

/// Builds a [ProfitReport] with [count] synthetic product lines. Each line
/// carries plausible revenue/cost so totals and per-line averages are
/// non-trivial.
ProfitReport _report({
  required int count,
  ReportPeriod period = const ReportPeriod.allTime(),
  String Function(int i)? name,
}) {
  final lines = <ProductProfitLine>[
    for (var i = 0; i < count; i++)
      ProductProfitLine(
        productId: i + 1,
        name: name?.call(i) ?? 'Produk ${i + 1}',
        unit: 'pcs',
        quantitySold: (i + 1).toDouble(),
        revenue: (i + 1) * 10000.0,
        cost: (i + 1) * 6000.0,
      ),
  ];
  final totalRevenue = lines.fold<double>(0, (s, l) => s + l.revenue);
  final totalCost = lines.fold<double>(0, (s, l) => s + l.cost);
  return ProfitReport(
    period: period,
    totalRevenue: totalRevenue,
    totalCost: totalCost,
    lines: lines,
  );
}

/// The %PDF magic header every valid PDF starts with.
final _pdfMagic = utf8.encode('%PDF');

final _fixedDate = DateTime(2026, 7, 25, 14, 30);

void main() {
  setUpAll(() async {
    // DateFormat('...', 'id_ID') needs Indonesian locale symbol data.
    await initializeDateFormatting('id_ID');
  });

  group('buildRecapPdf', () {
    test('returns non-empty bytes beginning with the %PDF header', () async {
      final bytes = await buildRecapPdf(
        report: _report(count: 3),
        periodLabel: '3 Jan 2026 - 11 Agu 2026 (Semua)',
        generatedAt: _fixedDate,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 4), equals(_pdfMagic));
    });

    test('handles an empty product list without throwing', () async {
      final bytes = await buildRecapPdf(
        report: const ProfitReport.empty(ReportPeriod.allTime()),
        periodLabel: kRecapNoTransactionsPeriod,
        generatedAt: _fixedDate,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 4), equals(_pdfMagic));
    });

    test('handles 60+ products without throwing (pagination path)', () async {
      final bytes = await buildRecapPdf(
        report: _report(count: 75),
        periodLabel: '3 Jan 2026 - 11 Agu 2026 (Semua)',
        generatedAt: _fixedDate,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 4), equals(_pdfMagic));
    });

    test('handles a 200-character product name without throwing', () async {
      final longName = 'A' * 200;
      final bytes = await buildRecapPdf(
        report: _report(count: 1, name: (_) => longName),
        periodLabel: '3 Jan 2026 - 11 Agu 2026 (Semua)',
        generatedAt: _fixedDate,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 4), equals(_pdfMagic));
    });

    test('renders a bounded date-range report without throwing', () async {
      final period = ReportPeriod.days(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 25),
      );
      final bytes = await buildRecapPdf(
        report: _report(count: 5, period: period),
        periodLabel: buildPeriodLabel(period),
        generatedAt: _fixedDate,
      );
      expect(bytes.sublist(0, 4), equals(_pdfMagic));
    });
  });

  group('formatRecapCurrency', () {
    test('formats thousands with a dot separator and Rp prefix', () {
      expect(formatRecapCurrency(643000), 'Rp 643.000');
    });

    test('formats zero as "Rp 0"', () {
      expect(formatRecapCurrency(0), 'Rp 0');
    });

    test('renders a negative amount with a minus sign', () {
      final formatted = formatRecapCurrency(-500000);
      expect(formatted, contains('-'));
      expect(formatted, 'Rp -500.000');
    });
  });
}
