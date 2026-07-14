import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';

void main() {
  const calculator = PrioritasKulakanCalculator();
  final now = DateTime(2026, 7, 13);

  Product product({required double currentStock}) {
    return Product()
      ..id = 1
      ..name = 'Test Product'
      ..categoryId = 1
      ..sellPrice = 1000
      ..unit = 'pcs'
      ..currentStock = currentStock
      ..minStockThreshold = 5
      ..createdAt = now
      ..updatedAt = now;
  }

  StockMutation stockOut({required double quantity, required DateTime createdAt}) {
    return StockMutation()
      ..productId = 1
      ..type = StockMutationType.stockOut
      ..quantity = quantity
      ..stockAfter = 0
      ..createdAt = createdAt;
  }

  test('computes daily velocity across several days of stockOut history', () {
    final mutations = [
      stockOut(quantity: 2, createdAt: now.subtract(const Duration(days: 3))),
      stockOut(quantity: 2, createdAt: now.subtract(const Duration(days: 1))),
      stockOut(quantity: 2, createdAt: now),
    ];

    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: mutations,
      now: now,
    );

    // 6 units total / 3 days since the earliest mutation = 2/day.
    expect(result, isNotNull);
    expect(result!.dailyVelocity, 2.0);
  });

  test('a single stockOut mutation uses a minimum 1-day divisor, no division by zero', () {
    final mutations = [stockOut(quantity: 5, createdAt: now)];

    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: mutations,
      now: now,
    );

    expect(result, isNotNull);
    expect(result!.dailyVelocity, 5.0);
    expect(result.dailyVelocity.isFinite, isTrue);
  });

  test('estimated days remaining is currentStock / dailyVelocity', () {
    final mutations = [
      stockOut(quantity: 2, createdAt: now.subtract(const Duration(days: 3))),
      stockOut(quantity: 2, createdAt: now.subtract(const Duration(days: 1))),
      stockOut(quantity: 2, createdAt: now),
    ];

    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: mutations,
      now: now,
    );

    // velocity is 2/day (see the earlier test); 10 / 2 = 5 days.
    expect(result!.estimatedDaysRemaining, 5.0);
    expect(result.isOutOfStock, isFalse);
  });

  test('currentStock <= 0 produces the "stok habis sekarang" special case', () {
    final mutations = [stockOut(quantity: 5, createdAt: now)];

    final zeroStockResult = calculator.calculate(
      product: product(currentStock: 0),
      stockOutMutations: mutations,
      now: now,
    );
    expect(zeroStockResult!.isOutOfStock, isTrue);
    expect(zeroStockResult.estimatedDaysRemaining, 0.0);
    expect(zeroStockResult.urgency, PriorityUrgency.red);

    final negativeStockResult = calculator.calculate(
      product: product(currentStock: -1),
      stockOutMutations: mutations,
      now: now,
    );
    expect(negativeStockResult!.isOutOfStock, isTrue);
    expect(negativeStockResult.estimatedDaysRemaining, 0.0);
    expect(negativeStockResult.urgency, PriorityUrgency.red);
  });

  test('urgency boundaries: exactly 2 days is red, exactly 7 days is yellow, above 7 is neutral', () {
    // velocity is exactly 1/day, so currentStock == estimatedDaysRemaining.
    final mutations = [stockOut(quantity: 1, createdAt: now)];

    final atRedBoundary = calculator.calculate(
      product: product(currentStock: 2),
      stockOutMutations: mutations,
      now: now,
    );
    expect(atRedBoundary!.estimatedDaysRemaining, 2.0);
    expect(atRedBoundary.urgency, PriorityUrgency.red);

    final justAboveRedBoundary = calculator.calculate(
      product: product(currentStock: 3),
      stockOutMutations: mutations,
      now: now,
    );
    expect(justAboveRedBoundary!.urgency, PriorityUrgency.yellow);

    final atYellowBoundary = calculator.calculate(
      product: product(currentStock: 7),
      stockOutMutations: mutations,
      now: now,
    );
    expect(atYellowBoundary!.estimatedDaysRemaining, 7.0);
    expect(atYellowBoundary.urgency, PriorityUrgency.yellow);

    final justAboveYellowBoundary = calculator.calculate(
      product: product(currentStock: 8),
      stockOutMutations: mutations,
      now: now,
    );
    expect(justAboveYellowBoundary!.urgency, PriorityUrgency.neutral);
  });

  test('isBelowOneDay is true when currentStock <= 0 ("stok habis sekarang")', () {
    final mutations = [stockOut(quantity: 5, createdAt: now)];

    final result = calculator.calculate(
      product: product(currentStock: 0),
      stockOutMutations: mutations,
      now: now,
    );

    expect(result!.isBelowOneDay, isTrue);
  });

  test('isBelowOneDay is true for a fractional estimatedDaysRemaining below 1', () {
    // velocity is 2/day; currentStock 1 -> 0.5 days remaining.
    final mutations = [stockOut(quantity: 2, createdAt: now)];

    final result = calculator.calculate(
      product: product(currentStock: 1),
      stockOutMutations: mutations,
      now: now,
    );

    expect(result!.estimatedDaysRemaining, 0.5);
    expect(result.isBelowOneDay, isTrue);
  });

  test('isBelowOneDay is false once estimatedDaysRemaining reaches exactly 1', () {
    // velocity is 1/day; currentStock 1 -> exactly 1 day remaining.
    final mutations = [stockOut(quantity: 1, createdAt: now)];

    final result = calculator.calculate(
      product: product(currentStock: 1),
      stockOutMutations: mutations,
      now: now,
    );

    expect(result!.estimatedDaysRemaining, 1.0);
    expect(result.isBelowOneDay, isFalse);
  });

  test('a product with zero stockOut mutations is not eligible (returns null)', () {
    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: const [],
      now: now,
    );

    expect(result, isNull);
  });

  test('suggestedRestockQty is ceil(velocity x 7) - currentStock, minimum 1', () {
    final mutations = [
      stockOut(quantity: 2, createdAt: now.subtract(const Duration(days: 3))),
      stockOut(quantity: 2, createdAt: now.subtract(const Duration(days: 1))),
      stockOut(quantity: 2, createdAt: now),
    ];

    // velocity is 2/day (see the earlier test); ceil(2*7) - 10 = 14 - 10 = 4.
    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: mutations,
      now: now,
    );
    expect(result!.dailyVelocity, 2.0);
    expect(result.suggestedRestockQty, 4);

    // A fractional velocity still rounds the 7-day target up before
    // subtracting: ceil(1.5*7) - 5 = ceil(10.5) - 5 = 11 - 5 = 6.
    final fractionalMutations = [stockOut(quantity: 1.5, createdAt: now)];
    final fractionalResult = calculator.calculate(
      product: product(currentStock: 5),
      stockOutMutations: fractionalMutations,
      now: now,
    );
    expect(fractionalResult!.dailyVelocity, 1.5);
    expect(fractionalResult.suggestedRestockQty, 6);
  });

  test('suggestedRestockQty is at least 1 even when currentStock already covers 7+ days', () {
    // velocity is 2/day; ceil(2*7) = 14, well below currentStock of 100.
    final mutations = [
      stockOut(quantity: 2, createdAt: now.subtract(const Duration(days: 3))),
      stockOut(quantity: 2, createdAt: now.subtract(const Duration(days: 1))),
      stockOut(quantity: 2, createdAt: now),
    ];

    final result = calculator.calculate(
      product: product(currentStock: 100),
      stockOutMutations: mutations,
      now: now,
    );

    expect(result!.suggestedRestockQty, 1);
  });

  test('calculateAll excludes ineligible products and sorts most-urgent first', () {
    final urgent = product(currentStock: 2)..id = 1;
    final mild = product(currentStock: 20)..id = 2;
    final ineligible = product(currentStock: 10)..id = 3;

    final results = calculator.calculateAll(
      products: [mild, urgent, ineligible],
      stockOutMutationsByProductId: {
        1: [stockOut(quantity: 1, createdAt: now)], // velocity 1/day -> 2 days left
        2: [stockOut(quantity: 1, createdAt: now)], // velocity 1/day -> 20 days left
        // product 3 has no stockOut history at all.
      },
      now: now,
    );

    expect(results.map((r) => r.product.id).toList(), [1, 2]);
  });
}
