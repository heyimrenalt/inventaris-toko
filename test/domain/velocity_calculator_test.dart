import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/domain/velocity_calculator.dart';

void main() {
  const calculator = VelocityCalculator();
  final now = DateTime(2026, 1, 1);

  StockMutation stockOut({
    required double quantity,
    required DateTime createdAt,
    String? note,
  }) {
    return StockMutation()
      ..productId = 1
      ..type = StockMutationType.stockOut
      ..quantity = quantity
      ..note = note
      ..stockAfter = 0
      ..createdAt = createdAt;
  }

  test('weighted formula: 60 in the last 30 days + 30 older, 90 total over 90 days -> 1.7/day', () {
    final mutations = [
      // Outside the 30-day window, but counts toward the all-time total
      // and sets the 90-day-ago earliest date.
      stockOut(quantity: 30, createdAt: now.subtract(const Duration(days: 90))),
      // Inside the 30-day window (15 days ago).
      stockOut(quantity: 60, createdAt: now.subtract(const Duration(days: 15))),
    ];

    final result = calculator.calculate(stockOutMutations: mutations, now: now);

    // velocity30d = 60 / 30 = 2.0; velocityAllTime = 90 / 90 = 1.0;
    // dailyVelocity = 2.0*0.7 + 1.0*0.3 = 1.7.
    expect(result.dailyVelocity, closeTo(1.7, 1e-9));
  });

  test('a product with zero stockOut mutations has velocity 0', () {
    final result = calculator.calculate(stockOutMutations: const []);

    expect(result.dailyVelocity, 0);
    expect(result.stockOutCount, 0);
    expect(result.dataAgeDays, 0);
  });

  test('a single stockOut mutation recorded today does not divide by zero', () {
    final result = calculator.calculate(
      stockOutMutations: [stockOut(quantity: 9, createdAt: now)],
      now: now,
    );

    // daysSinceFirst clamps to 1: velocity30d = 9/30, velocityAllTime = 9/1.
    expect(result.dailyVelocity, closeTo(9 * (0.7 / 30 + 0.3), 1e-9));
    expect(result.dailyVelocity.isFinite, isTrue);
    expect(result.dataAgeDays, 1);
  });

  test('an undone mutation (Dibatalkan: note) is excluded from the totals', () {
    final undoOnly = calculator.calculate(
      stockOutMutations: [
        stockOut(quantity: 100, createdAt: now, note: 'Dibatalkan: koreksi stok masuk'),
      ],
      now: now,
    );
    expect(undoOnly.dailyVelocity, 0);
    expect(undoOnly.stockOutCount, 0);

    final mixed = calculator.calculate(
      stockOutMutations: [
        stockOut(quantity: 100, createdAt: now, note: 'Dibatalkan: koreksi stok masuk'),
        stockOut(quantity: 9, createdAt: now),
      ],
      now: now,
    );
    // Only the real (non-undo) mutation counts.
    expect(mixed.stockOutCount, 1);
    expect(mixed.dailyVelocity, closeTo(9 * (0.7 / 30 + 0.3), 1e-9));
  });

  test('a future-dated mutation (clock skew) is clamped to now, not treated as negative days', () {
    final result = calculator.calculate(
      stockOutMutations: [stockOut(quantity: 9, createdAt: now.add(const Duration(days: 5)))],
      now: now,
    );

    expect(result.dailyVelocity, closeTo(9 * (0.7 / 30 + 0.3), 1e-9));
    expect(result.dailyVelocity.isFinite, isTrue);
    expect(result.dataAgeDays, 1);
  });

  test('dataAgeDays clamps at 30 even when the sales history is much older', () {
    final result = calculator.calculate(
      stockOutMutations: [stockOut(quantity: 30, createdAt: now.subtract(const Duration(days: 90)))],
      now: now,
    );

    expect(result.dataAgeDays, 30);
  });
}
