import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/domain/prioritas_kulakan_calculator.dart';

void main() {
  const calculator = PrioritasKulakanCalculator();
  final now = DateTime(2026, 7, 13);
  const defaultLeadTime = 3;
  const defaultCoverDays = 7;

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

  /// [count] mutations of [quantityEach], all dated exactly 30 days ago
  /// (the edge of [VelocityCalculator.recentWindowDays], still counted as
  /// "within window"). All-time and recent totals are then identical, so
  /// the 70/30 blend collapses to a single clean rate:
  /// `dailyVelocity == (count * quantityEach) / 30`.
  List<StockMutation> confidentMutations({required int count, required double quantityEach}) {
    return List.generate(
      count,
      (_) => stockOut(quantity: quantityEach, createdAt: now.subtract(const Duration(days: 30))),
    );
  }

  test('computes the weighted 70/30 blend of recent and all-time velocity', () {
    final mutations = [
      // Outside the 30-day window, but counts toward the all-time total
      // and sets the 90-day-ago earliest date.
      stockOut(quantity: 30, createdAt: now.subtract(const Duration(days: 90))),
      // Inside the 30-day window (15 days ago).
      stockOut(quantity: 60, createdAt: now.subtract(const Duration(days: 15))),
    ];

    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: mutations,
      restockLeadTimeDays: defaultLeadTime,
      restockCoverDays: defaultCoverDays,
      now: now,
    );

    // velocity30d = 60/30 = 2.0; velocityAllTime = 90/90 = 1.0;
    // dailyVelocity = 2.0*0.7 + 1.0*0.3 = 1.7.
    expect(result, isNotNull);
    expect(result!.dailyVelocity, closeTo(1.7, 1e-9));
  });

  test('a single stockOut mutation uses a minimum 1-day divisor, no division by zero', () {
    final mutations = [stockOut(quantity: 5, createdAt: now)];

    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: mutations,
      restockLeadTimeDays: defaultLeadTime,
      restockCoverDays: defaultCoverDays,
      now: now,
    );

    expect(result, isNotNull);
    // daysSinceFirst clamps to 1: velocity30d = 5/30, velocityAllTime = 5/1.
    expect(result!.dailyVelocity, closeTo(5 * (0.7 / 30 + 0.3), 1e-9));
    expect(result.dailyVelocity.isFinite, isTrue);
  });

  test('a product with zero stockOut mutations is not eligible (returns null)', () {
    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: const [],
      restockLeadTimeDays: defaultLeadTime,
      restockCoverDays: defaultCoverDays,
      now: now,
    );

    expect(result, isNull);
  });

  test('a product whose only stockOut "mutations" are undone (Dibatalkan) entries is not eligible',
      () {
    final result = calculator.calculate(
      product: product(currentStock: 10),
      stockOutMutations: [
        stockOut(quantity: 5, createdAt: now)..note = 'Dibatalkan: koreksi stok masuk',
      ],
      restockLeadTimeDays: defaultLeadTime,
      restockCoverDays: defaultCoverDays,
      now: now,
    );

    expect(result, isNull);
  });

  group('urgency', () {
    test('currentStock <= 0 is always red (rule 1 beats the velocity-based rules)', () {
      // out-of-stock (rule 1) must win over the velocity-based rules, so
      // estimatedDaysRemaining stays null regardless.
      final mutations = [stockOut(quantity: 5, createdAt: now)];

      final result = calculator.calculate(
        product: product(currentStock: 0),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: defaultCoverDays,
        now: now,
      );

      expect(result!.isOutOfStock, isTrue);
      expect(result.urgency, PriorityUrgency.red);
      expect(result.estimatedDaysRemaining, isNull);

      final negativeStockResult = calculator.calculate(
        product: product(currentStock: -1),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: defaultCoverDays,
        now: now,
      );
      expect(negativeStockResult!.urgency, PriorityUrgency.red);
    });

    test('a thin single-mutation history with stock in hand is neutral when the estimate lands '
        'past 2x lead time',
        () {
      // velocity30d = 5/30, velocityAllTime = 5/1 (daysSinceFirst clamps
      // to 1) -> dailyVelocity = (5/30)*0.7 + 5*0.3 = 97/60 ≈ 1.61667/day.
      // estimatedDays = 20 / (97/60) = 1200/97 ≈ 12.3711, which is above
      // 2x the default lead time (6) -> neutral.
      final mutations = [stockOut(quantity: 5, createdAt: now)];

      final result = calculator.calculate(
        product: product(currentStock: 20),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: defaultCoverDays,
        now: now,
      );

      expect(result!.isOutOfStock, isFalse);
      expect(result.dailyVelocity, closeTo(97 / 60, 1e-9));
      expect(result.estimatedDaysRemaining, closeTo(1200 / 97, 1e-9));
      expect(result.urgency, PriorityUrgency.neutral);
    });

    test('stock in the yellow band (between lead time and 2x lead time) '
        'is yellow, not red — a 20-unit product should not be flagged as urgent just because it '
        "has any sales history", () {
      // 5 mutations of quantity 24 dated exactly 30 days ago -> dailyVelocity
      // = (5*24)/30 = 4.0/day exactly.
      final mutations = confidentMutations(count: 5, quantityEach: 24);

      final result = calculator.calculate(
        product: product(currentStock: 20),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: defaultCoverDays,
        now: now,
      );

      expect(result!.dailyVelocity, closeTo(4.0, 1e-9));
      // 20 / 4.0 = 5.0 days -> within [3, 6] (leadTime..2*leadTime).
      expect(result.estimatedDaysRemaining, closeTo(5.0, 1e-9));
      expect(result.urgency, PriorityUrgency.yellow);
    });

    test('estimatedDays below lead time is red', () {
      // 5 mutations of quantity 60 dated exactly 30 days ago -> dailyVelocity
      // = (5*60)/30 = 10.0/day exactly.
      final mutations = confidentMutations(count: 5, quantityEach: 60);

      final result = calculator.calculate(
        product: product(currentStock: 20),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: defaultCoverDays,
        now: now,
      );

      expect(result!.dailyVelocity, closeTo(10.0, 1e-9));
      // 20 / 10.0 = 2.0 days -> below leadTime (3).
      expect(result.estimatedDaysRemaining, closeTo(2.0, 1e-9));
      expect(result.urgency, PriorityUrgency.red);
    });

    test('estimatedDays above 2x lead time is neutral', () {
      final mutations = confidentMutations(count: 5, quantityEach: 24); // 4.0/day
      final result = calculator.calculate(
        product: product(currentStock: 40),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: defaultCoverDays,
        now: now,
      );

      // 40 / 4.0 = 10 days -> above 2*leadTime (6).
      expect(result!.estimatedDaysRemaining, closeTo(10.0, 1e-9));
      expect(result.urgency, PriorityUrgency.neutral);
    });

    test('dailyVelocity of exactly 0 is neutral with no estimate shown', () {
      final mutations = List.generate(
        5,
        (_) => stockOut(quantity: 0, createdAt: now.subtract(const Duration(days: 10))),
      );

      final result = calculator.calculate(
        product: product(currentStock: 20),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: defaultCoverDays,
        now: now,
      );

      expect(result!.dailyVelocity, 0);
      expect(result.isOutOfStock, isFalse);
      expect(result.urgency, PriorityUrgency.neutral);
      expect(result.estimatedDaysRemaining, isNull);
    });

    test('urgency boundaries respect a custom restockLeadTimeDays', () {
      // dailyVelocity exactly 1.0/day (5 mutations of quantity 6, 30 days
      // ago each: (5*6)/30 = 1.0).
      final mutations = confidentMutations(count: 5, quantityEach: 6);

      final atLeadTimeBoundary = calculator.calculate(
        product: product(currentStock: 5),
        stockOutMutations: mutations,
        restockLeadTimeDays: 5,
        restockCoverDays: defaultCoverDays,
        now: now,
      );
      expect(atLeadTimeBoundary!.estimatedDaysRemaining, closeTo(5.0, 1e-9));
      expect(atLeadTimeBoundary.urgency, PriorityUrgency.yellow);

      final justBelowLeadTimeBoundary = calculator.calculate(
        product: product(currentStock: 4),
        stockOutMutations: mutations,
        restockLeadTimeDays: 5,
        restockCoverDays: defaultCoverDays,
        now: now,
      );
      expect(justBelowLeadTimeBoundary!.urgency, PriorityUrgency.red);

      final atDoubleLeadTimeBoundary = calculator.calculate(
        product: product(currentStock: 10),
        stockOutMutations: mutations,
        restockLeadTimeDays: 5,
        restockCoverDays: defaultCoverDays,
        now: now,
      );
      expect(atDoubleLeadTimeBoundary!.estimatedDaysRemaining, closeTo(10.0, 1e-9));
      expect(atDoubleLeadTimeBoundary.urgency, PriorityUrgency.yellow);

      final justAboveDoubleLeadTimeBoundary = calculator.calculate(
        product: product(currentStock: 11),
        stockOutMutations: mutations,
        restockLeadTimeDays: 5,
        restockCoverDays: defaultCoverDays,
        now: now,
      );
      expect(justAboveDoubleLeadTimeBoundary!.urgency, PriorityUrgency.neutral);
    });
  });

  group('suggestedRestockQty', () {
    test('is ceil(dailyVelocity x restockCoverDays) - currentStock', () {
      // A mutation of quantity 60 dated exactly 30 days ago gives an exact
      // 2.0/day velocity; ceil(2*7) - 5 = 14 - 5 = 9.
      final mutations = [stockOut(quantity: 60, createdAt: now.subtract(const Duration(days: 30)))];
      final result = calculator.calculate(
        product: product(currentStock: 5),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: 7,
        now: now,
      );

      expect(result!.dailyVelocity, closeTo(2.0, 1e-9));
      expect(result.suggestedRestockQty, 9);
    });

    test('is at least 1 even when currentStock already covers restockCoverDays+', () {
      // velocity is exactly 2/day; ceil(2*7) = 14, well below currentStock
      // of 100.
      final mutations = [stockOut(quantity: 60, createdAt: now.subtract(const Duration(days: 30)))];

      final result = calculator.calculate(
        product: product(currentStock: 100),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: 7,
        now: now,
      );

      expect(result!.suggestedRestockQty, 1);
    });

    test('a fractional velocity still rounds the cover-days target up before subtracting', () {
      // A mutation of quantity 45 dated exactly 30 days ago gives an exact
      // 1.5/day velocity; ceil(1.5*7) - 5 = ceil(10.5) - 5 = 11 - 5 = 6.
      final mutations = [stockOut(quantity: 45, createdAt: now.subtract(const Duration(days: 30)))];
      final result = calculator.calculate(
        product: product(currentStock: 5),
        stockOutMutations: mutations,
        restockLeadTimeDays: defaultLeadTime,
        restockCoverDays: 7,
        now: now,
      );

      expect(result!.dailyVelocity, closeTo(1.5, 1e-9));
      expect(result.suggestedRestockQty, 6);
    });
  });

  test('calculateAll excludes ineligible products and sorts most-urgent first', () {
    final urgent = product(currentStock: 2)..id = 1;
    final mild = product(currentStock: 20)..id = 2;
    final ineligible = product(currentStock: 10)..id = 3;

    // Both products have identical stockOut history (same quantity, same
    // date), so they share the same dailyVelocity —
    // ordering is driven purely by currentStock (2 vs 20).
    final mutations = confidentMutations(count: 5, quantityEach: 1);

    final results = calculator.calculateAll(
      products: [mild, urgent, ineligible],
      stockOutMutationsByProductId: {
        1: mutations,
        2: mutations,
        // product 3 has no stockOut history at all.
      },
      restockLeadTimeDays: defaultLeadTime,
      restockCoverDays: defaultCoverDays,
      now: now,
    );

    expect(results.map((r) => r.product.id).toList(), [1, 2]);
  });

  test('calculateAll sorts out-of-stock (red, no estimate) ahead of a red product that still has '
      'a fractional estimate', () {
    final outOfStock = product(currentStock: 0)..id = 1;
    final almostOut = product(currentStock: 1)..id = 2;

    // High velocity so estimatedDays for "almostOut" lands well below
    // leadTime (red).
    final mutations = confidentMutations(count: 5, quantityEach: 60); // 10.0/day

    final results = calculator.calculateAll(
      products: [almostOut, outOfStock],
      stockOutMutationsByProductId: {1: mutations, 2: mutations},
      restockLeadTimeDays: defaultLeadTime,
      restockCoverDays: defaultCoverDays,
      now: now,
    );

    expect(results.map((r) => r.product.id).toList(), [1, 2]);
    expect(results.first.urgency, PriorityUrgency.red);
    expect(results.last.urgency, PriorityUrgency.red);
  });

  group('formatEstimatedDaysLabel', () {
    test('below 1 day reads "kurang dari 1 hari"', () {
      expect(formatEstimatedDaysLabel(0.5), 'kurang dari 1 hari');
      expect(formatEstimatedDaysLabel(0.99), 'kurang dari 1 hari');
    });

    test('above 30 days caps at "lebih dari 30 hari"', () {
      expect(formatEstimatedDaysLabel(31), 'lebih dari 30 hari');
      expect(formatEstimatedDaysLabel(847), 'lebih dari 30 hari');
    });

    test('in between rounds to whole days', () {
      expect(formatEstimatedDaysLabel(6.67), '7 hari lagi');
      expect(formatEstimatedDaysLabel(5.0), '5 hari lagi');
    });
  });

  group('formatVelocity', () {
    test('shows whole numbers with no decimals', () {
      expect(formatVelocity(9.0), '9');
      expect(formatVelocity(9), '9');
    });

    test('rounds a fractional rate to the nearest whole number', () {
      expect(formatVelocity(5.2), '5');
      expect(formatVelocity(1.5), '2');
      expect(formatVelocity(1.44), '1');
      expect(formatVelocity(1.46), '1');
    });

    test('rounds a positive rate that would round down to zero up to 1', () {
      expect(formatVelocity(0.3), '1');
      expect(formatVelocity(0.49), '1');
    });

    test('shows "0" only when the rate is truly zero', () {
      expect(formatVelocity(0), '0');
    });
  });
}
