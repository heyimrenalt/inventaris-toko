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
