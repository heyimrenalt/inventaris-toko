import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/domain/hpp_calculator.dart';

void main() {
  group('calculateNewAverage', () {
    test('weighted average with prior stock > 0', () {
      // 10 units @ Rp5000 + 5 units @ Rp8000 = (50000 + 40000) / 15 = 6000.
      final result = HppCalculator.calculateNewAverage(
        currentStock: 10,
        currentAvgCost: 5000,
        incomingQty: 5,
        incomingCostPrice: 8000,
      );
      expect(result, 6000);
    });

    test('current stock 0 returns incoming cost price exactly', () {
      final result = HppCalculator.calculateNewAverage(
        currentStock: 0,
        currentAvgCost: 0,
        incomingQty: 20,
        incomingCostPrice: 4500,
      );
      expect(result, 4500);
    });

    test('first purchase from zero stock does not divide by zero', () {
      // The divisor would be currentStock + incomingQty = 0 + 0 if the
      // early return for currentStock <= 0 weren't there.
      final result = HppCalculator.calculateNewAverage(
        currentStock: 0,
        currentAvgCost: 0,
        incomingQty: 0,
        incomingCostPrice: 7000,
      );
      expect(result, 7000);
      expect(result.isFinite, isTrue);
    });

    test('incoming quantity 0 with prior stock leaves the average unchanged', () {
      // Divisor is currentStock + 0 = 10, not 0: no NaN/Infinity, and a
      // zero-quantity batch can't move the existing average.
      final result = HppCalculator.calculateNewAverage(
        currentStock: 10,
        currentAvgCost: 5000,
        incomingQty: 0,
        incomingCostPrice: 9999,
      );
      expect(result, 5000);
      expect(result.isFinite, isTrue);
    });

    test('second purchase at a different price produces the weighted average', () {
      // First purchase: 20 units @ Rp4000 from zero stock -> 4000.
      final afterFirst = HppCalculator.calculateNewAverage(
        currentStock: 0,
        currentAvgCost: 0,
        incomingQty: 20,
        incomingCostPrice: 4000,
      );
      expect(afterFirst, 4000);

      // Second purchase: 20 units @ Rp6000 on top of 20 @ Rp4000
      // = (80000 + 120000) / 40 = 5000 — weighted, not the plain mean of
      // the two prices only because the quantities happen to match here,
      // so a third, unequal batch is checked below.
      final afterSecond = HppCalculator.calculateNewAverage(
        currentStock: 20,
        currentAvgCost: afterFirst,
        incomingQty: 20,
        incomingCostPrice: 6000,
      );
      expect(afterSecond, 5000);

      // Third purchase: 10 units @ Rp10000 on top of 40 @ Rp5000
      // = (200000 + 100000) / 50 = 6000 — the plain mean would be 7500.
      final afterThird = HppCalculator.calculateNewAverage(
        currentStock: 40,
        currentAvgCost: afterSecond,
        incomingQty: 10,
        incomingCostPrice: 10000,
      );
      expect(afterThird, 6000);
    });
  });

  group('profitPerUnit', () {
    test('returns correct value when both inputs valid', () {
      expect(HppCalculator.profitPerUnit(10000, 6000), 4000);
    });

    test('returns null when avgCostPrice is null', () {
      expect(HppCalculator.profitPerUnit(10000, null), isNull);
    });
  });

  group('marginPercent', () {
    test('returns correct percentage', () {
      // (10000 - 7500) / 10000 * 100 = 25%.
      expect(HppCalculator.marginPercent(10000, 7500), 25);
    });

    test('returns null when sellPrice is 0', () {
      expect(HppCalculator.marginPercent(0, 5000), isNull);
    });

    test('returns null when avgCostPrice is null', () {
      expect(HppCalculator.marginPercent(10000, null), isNull);
    });
  });
}
