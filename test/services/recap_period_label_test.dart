import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/domain/profit_report.dart';
import 'package:inventaris_toko/services/recap_pdf_builder.dart';
import 'package:inventaris_toko/ui/screens/keuntungan/keuntungan_detail_screen.dart';
import 'package:inventaris_toko/ui/screens/keuntungan/rekap_keuntungan_screen.dart';
import 'package:inventaris_toko/ui/widgets/report_period_filter.dart';
import 'package:isar_community/isar.dart';

import '../data/repositories/test_isar.dart';

/// The period label — the string that answers "which dates are these
/// numbers from?".
///
/// Five surfaces render it: the Detail Keuntungan sub-text, the Rekap
/// Keuntungan "Periode:" line, the copied recap text, the share subject
/// and the PDF header. They used to compute it three different ways and
/// disagreed for an all-time report: the screen said "3 Jan - 11 Agu 2026
/// (Semua)", the copy said a bare "Semua", and the PDF said [oldest
/// mutation of *any* type .. today] — a span whose two endpoints had
/// nothing to do with the profit figure printed beside it.
///
/// These tests pin the single [buildPeriodLabel] they now all share, and
/// then assert the five outputs are byte-identical for one report.
void main() {
  late Isar isar;
  late StockMutationRepository mutationRepository;

  setUpAll(() async {
    // DateFormat('d MMM yyyy', 'id_ID') needs Indonesian locale symbols.
    await initializeDateFormatting('id_ID');
  });

  setUp(() async {
    isar = await openTestIsar();
    mutationRepository = StockMutationRepository(isar);
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  /// Writes a mutation directly so the test owns `createdAt` — the
  /// repository always stamps `DateTime.now()`. Defaults describe a sale
  /// that resolves to a profit; the named arguments let a test write the
  /// rows that must *not* define the range (a restock, or a stock-out with
  /// no resolvable cost).
  Future<void> mutationAt(
    DateTime createdAt, {
    StockMutationType type = StockMutationType.stockOut,
    double? sellPriceSnapshot = 3000,
    double? costPriceSnapshot = 2000,
  }) async {
    final mutation = StockMutation()
      ..productId = 1
      ..type = type
      ..quantity = 1
      ..stockAfter = 0
      ..sellPriceSnapshot = sellPriceSnapshot
      ..costPriceSnapshot = costPriceSnapshot
      ..snapshotBackfilled = false
      ..createdAt = createdAt;
    await isar.writeTxn(() => isar.stockMutations.put(mutation));
  }

  group('buildPeriodLabel — all time', () {
    test('resolves to the span between the earliest and latest sale', () {
      final label = buildPeriodLabel(
        const ReportPeriod.allTime(),
        allTimeRange: ProfitDateRange(
          earliest: DateTime(2026, 1, 3, 9),
          latest: DateTime(2026, 8, 11, 20),
        ),
      );

      expect(label, '3 Jan 2026 - 11 Agu 2026 (Semua)');
    });

    test('a single sale collapses to one date', () {
      final at = DateTime(2026, 7, 18, 10, 15);
      final label = buildPeriodLabel(
        const ReportPeriod.allTime(),
        allTimeRange: ProfitDateRange(earliest: at, latest: at),
      );

      expect(label, '18 Jul 2026 (Semua)');
    });

    test('two sales on the same day collapse to that one date', () {
      final label = buildPeriodLabel(
        const ReportPeriod.allTime(),
        allTimeRange: ProfitDateRange(
          earliest: DateTime(2026, 7, 18, 0, 0, 0, 1),
          latest: DateTime(2026, 7, 18, 23, 59, 59, 999),
        ),
      );

      expect(label, '18 Jul 2026 (Semua)');
    });

    test('no qualifying sale prints the no-transaction period, no crash', () {
      final label = buildPeriodLabel(const ReportPeriod.allTime());

      expect(label, kRecapNoTransactionsPeriod);
      expect(label, 'Belum ada transaksi');
    });

    test('the end of the range is the latest sale, never today', () {
      // The bug this replaces: the PDF ended every all-time range at
      // DateTime.now(), so a ledger whose last sale was in July still
      // claimed to cover August. Nothing here reads the clock.
      final label = buildPeriodLabel(
        const ReportPeriod.allTime(),
        allTimeRange: ProfitDateRange(
          earliest: DateTime(2026, 7, 1, 10),
          latest: DateTime(2026, 7, 18, 10),
        ),
      );

      expect(label, '1 Jul 2026 - 18 Jul 2026 (Semua)');
      expect(label, isNot(contains('Agu')));
    });
  });

  group('buildPeriodLabel — selected range', () {
    test('prints the selected range unchanged, ignoring the all-time span',
        () {
      final period = ReportPeriod.days(
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 12),
      );

      // Even when a span is supplied, a bounded period must not be widened
      // by data sitting outside it.
      expect(
        buildPeriodLabel(
          period,
          allTimeRange: ProfitDateRange(
            earliest: DateTime(2004, 11, 2),
            latest: DateTime(2026, 8, 11),
          ),
        ),
        '10 Jul 2026 - 12 Jul 2026',
      );
    });

    test('a single-day selection collapses to one date', () {
      final period = ReportPeriod.days(
        DateTime(2026, 7, 12),
        DateTime(2026, 7, 12),
      );

      expect(
        buildPeriodLabel(
          period,
          allTimeRange: ProfitDateRange(
            earliest: DateTime(2004, 11, 2),
            latest: DateTime(2026, 8, 11),
          ),
        ),
        '12 Jul 2026',
      );
    });

    test('a bounded period never carries the "(Semua)" suffix', () {
      final period = ReportPeriod.days(
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 12),
      );

      expect(buildPeriodLabel(period), isNot(contains('Semua')));
    });
  });

  group('the range comes from the sales behind the figures', () {
    test('a restock does not define the start of the range', () async {
      // The exact shape of the old PDF bug: the oldest row in the ledger
      // is a stock-in, weeks before the only sale. It contributes nothing
      // to the profit total, so it must not name the period either.
      await mutationAt(DateTime(2026, 7, 18), type: StockMutationType.stockIn);
      await mutationAt(DateTime(2026, 8, 11, 14));

      final range = await mutationRepository.getProfitableStockOutDateRange();

      expect(
        buildPeriodLabel(const ReportPeriod.allTime(), allTimeRange: range),
        '11 Agu 2026 (Semua)',
      );
    });

    test('a stock-out with no resolvable cost does not define the range',
        () async {
      await mutationAt(DateTime(2026, 7, 1), costPriceSnapshot: null);
      await mutationAt(DateTime(2026, 8, 11));
      await mutationAt(DateTime(2026, 9, 1), sellPriceSnapshot: null);

      final range = await mutationRepository.getProfitableStockOutDateRange();

      expect(
        buildPeriodLabel(const ReportPeriod.allTime(), allTimeRange: range),
        '11 Agu 2026 (Semua)',
      );
    });

    test('an empty ledger yields no range and the no-transaction label',
        () async {
      final range = await mutationRepository.getProfitableStockOutDateRange();

      expect(range, isNull);
      expect(
        buildPeriodLabel(const ReportPeriod.allTime(), allTimeRange: range),
        kRecapNoTransactionsPeriod,
      );
    });

    test('a ledger of only unqualifying rows yields the no-transaction label',
        () async {
      await mutationAt(DateTime(2026, 7, 18), type: StockMutationType.stockIn);

      final range = await mutationRepository.getProfitableStockOutDateRange();

      expect(range, isNull);
      expect(
        buildPeriodLabel(const ReportPeriod.allTime(), allTimeRange: range),
        kRecapNoTransactionsPeriod,
      );
    });
  });

  group('the PDF prints the label it is handed', () {
    test('the "Periode:" header is the shared label, verbatim', () async {
      final label = buildPeriodLabel(
        const ReportPeriod.allTime(),
        allTimeRange: ProfitDateRange(
          earliest: DateTime(2026, 1, 3),
          latest: DateTime(2026, 8, 11),
        ),
      );

      final bytes = await buildRecapPdf(
        report: const ProfitReport.empty(ReportPeriod.allTime()),
        periodLabel: label,
        generatedAt: DateTime(2026, 8, 14, 9, 30),
      );

      expect(_pdfText(bytes), contains(_squashed('Periode: $label')));
    });

    test('"Dibuat:" still carries the generation date, separately', () async {
      // The period describes the data; the timestamp describes the
      // printing. Splitting them is the point — the July period below
      // survives being printed in August.
      final bytes = await buildRecapPdf(
        report: const ProfitReport.empty(ReportPeriod.allTime()),
        periodLabel: '18 Jul 2026 (Semua)',
        generatedAt: DateTime(2026, 8, 14, 9, 30),
      );

      final text = _pdfText(bytes);
      expect(text, contains(_squashed('Periode: 18 Jul 2026 (Semua)')));
      expect(text, contains(_squashed('Dibuat: 14 Agu 2026, 09:30')));
    });
  });

  group('every surface renders the identical string', () {
    /// Three sales spanning January to August, plus the two kinds of row
    /// that must not widen the range.
    Future<void> seed() async {
      await mutationAt(DateTime(2026, 1, 3, 9));
      await mutationAt(DateTime(2026, 4, 18, 14));
      await mutationAt(DateTime(2026, 8, 11, 20));
      // Older than every sale, and unqualifying — the old PDF would have
      // started the range here.
      await mutationAt(DateTime(2025, 11, 2), type: StockMutationType.stockIn);
    }

    const expected = '3 Jan 2026 - 11 Agu 2026 (Semua)';

    testWidgets('detail screen, rekap screen, copy, share subject and PDF',
        (tester) async {
      // Isar's async API runs on the real event loop, which testWidgets'
      // fake-async zone otherwise never pumps — hence runAsync throughout.
      await tester.runAsync(seed);

      // Captures what the app actually puts on the clipboard, rather than
      // re-deriving it.
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      // 1. Detail Keuntungan's sub-text.
      await tester.pumpWidget(
        MaterialApp(home: KeuntunganDetailScreen(isar: isar)),
      );
      await _settle(tester);

      final detailLabel = tester
          .widget<Text>(find.byKey(const Key('keuntungan_all_time_range')))
          .data!;
      expect(detailLabel, expected);

      // Dispose it before opening the next screen: it holds a 2-second
      // periodic refresh and a watchLazy subscription.
      await tester.pumpWidget(const SizedBox());

      // 2. Rekap Keuntungan's "Periode:" line.
      await tester.pumpWidget(
        MaterialApp(
          home: RekapKeuntunganScreen(
            isar: isar,
            mutationRepository: mutationRepository,
          ),
        ),
      );
      await _settle(tester);

      final onScreen = tester
          .widget<Text>(find.byKey(const Key('recap_active_period_label')))
          .data!;
      expect(onScreen, 'Periode: $expected');

      // 3. The copied recap text.
      await tester.tap(find.text('Salin'));
      await _settle(tester);
      expect(copied, isNotNull);
      final copiedPeriodLine = const LineSplitter()
          .convert(copied!)
          .firstWhere((line) => line.startsWith('Periode: '));
      expect(copiedPeriodLine, 'Periode: $expected');

      // 4. The share subject — read from the getter the share call itself
      // passes to the platform sheet.
      final state = tester.state(find.byType(RekapKeuntunganScreen)) as dynamic;
      expect(state.periodLabel as String, expected);
      expect(state.shareSubject as String, 'Rekap Keuntungan - $expected');

      // 5. The PDF header, generated from the same getter on a day that is
      // deliberately not the last sale's — the old builder would have
      // ended the range here instead.
      late Uint8List bytes;
      await tester.runAsync(() async {
        bytes = await buildRecapPdf(
          report: await mutationRepository
              .buildProfitReport(const ReportPeriod.allTime()),
          periodLabel: state.periodLabel as String,
          generatedAt: DateTime(2026, 9, 30, 8),
        );
      });
      expect(_pdfText(bytes), contains(_squashed('Periode: $expected')));

      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// Advances the real event loop so the screens' Isar queries complete, then
/// draws the result. Both screens are driven by chains of awaits, so this
/// hands off repeatedly rather than waiting once for a guessed duration;
/// Detail Keuntungan's 2-second periodic refresh also means `pumpAndSettle`
/// would never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.idle();
    await tester.pump();
  }
}

/// Strips whitespace, so a string built by the app can be matched against
/// [_pdfText]'s output — see there for why the PDF has no spaces to give.
String _squashed(String value) => value.replaceAll(RegExp(r'\s'), '');

/// The visible text of a generated PDF, with all whitespace removed.
///
/// The `pdf` package deflates its content streams, so the bytes have to be
/// inflated before any of the header text is greppable. Within a stream,
/// text is drawn from literal strings — `(Periode:) Tj`, `(18) Tj`, … —
/// whose escapes are undone here.
///
/// Spaces do not survive: the layout engine positions each word rather
/// than encoding the gap between them as a glyph, so the header comes back
/// as `Periode:18Jul2026(Semua)`. Callers therefore match through
/// [_squashed]; every non-whitespace character, including the parentheses
/// around "Semua", is still asserted exactly.
String _pdfText(Uint8List bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final out = StringBuffer();

  for (final match in RegExp(r'stream\r?\n').allMatches(raw)) {
    final end = raw.indexOf('endstream', match.end);
    if (end < 0) continue;
    final chunk = bytes.sublist(match.end, end);

    List<int> inflated;
    try {
      inflated = const ZLibDecoder().decodeBytes(chunk);
    } catch (_) {
      // Not a deflated stream (an embedded font, say) — skip it.
      continue;
    }

    final content = latin1.decode(inflated, allowInvalid: true);
    for (final literal
        in RegExp(r'\((?:[^()\\]|\\.)*\)', dotAll: true).allMatches(content)) {
      final body = literal.group(0)!;
      out.write(
        body
            .substring(1, body.length - 1)
            .replaceAll(r'\(', '(')
            .replaceAll(r'\)', ')')
            .replaceAll(r'\\', r'\'),
      );
    }
    out.write('\n');
  }

  return out.toString();
}
