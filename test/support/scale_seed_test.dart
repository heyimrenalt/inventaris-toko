import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/domain/hpp_calculator.dart';

import '../../test_support/scale_seed.dart';

/// Unit tests for the scale-test seed plan and its expected-profit
/// cross-check (`test_support/scale_seed.dart`).
///
/// The cross-check is the reason these exist: the scale test asserts the
/// app's profit report against [expectedProfitFor], so a bug *here* would
/// silently turn that assertion into a rubber stamp. The arithmetic is
/// therefore pinned against hand-computed values and against
/// [HppCalculator] itself, not just against itself.
void main() {
  group('buildScaleSeedPlan', () {
    test('produces the requested product and mutation counts', () {
      final plan = buildScaleSeedPlan(productCount: 200, mutationCount: 1000);

      expect(plan.products, hasLength(200));
      expect(plan.mutations, hasLength(1000));
    });

    test('is deterministic for a fixed seed and clock', () {
      final now = DateTime(2026, 8, 17, 10);
      final a = buildScaleSeedPlan(randomSeed: 42, now: now);
      final b = buildScaleSeedPlan(randomSeed: 42, now: now);

      expect(a.mutations.length, b.mutations.length);
      for (var i = 0; i < a.mutations.length; i++) {
        expect(a.mutations[i].productIndex, b.mutations[i].productIndex);
        expect(a.mutations[i].type, b.mutations[i].type);
        expect(a.mutations[i].quantity, b.mutations[i].quantity);
        expect(a.mutations[i].at, b.mutations[i].at);
        expect(a.mutations[i].costPricePerUnit, b.mutations[i].costPricePerUnit);
      }
    });

    test('differs between seeds', () {
      final now = DateTime(2026, 8, 17, 10);
      final a = buildScaleSeedPlan(randomSeed: 1, now: now);
      final b = buildScaleSeedPlan(randomSeed: 2, now: now);

      final aTypes = a.mutations.map((m) => '${m.productIndex}:${m.quantity}');
      final bTypes = b.mutations.map((m) => '${m.productIndex}:${m.quantity}');
      expect(aTypes, isNot(equals(bTypes)));
    });

    test('mutations are in ascending timestamp order', () {
      final plan = buildScaleSeedPlan();

      for (var i = 1; i < plan.mutations.length; i++) {
        expect(
          plan.mutations[i].at.isBefore(plan.mutations[i - 1].at),
          isFalse,
          reason: 'mutation $i is earlier than its predecessor',
        );
      }
    });

    test('spreads timestamps across the requested window and no further', () {
      final now = DateTime(2026, 8, 17, 10);
      final plan = buildScaleSeedPlan(monthsBack: 6, now: now);

      final windowStart = DateTime(2026, 2, 17);
      expect(plan.mutations.first.at.isBefore(windowStart), isFalse);
      expect(plan.mutations.last.at.isAfter(now), isFalse);

      // Several distinct months, not all bunched into one.
      final months = plan.mutations.map((m) => '${m.at.year}-${m.at.month}').toSet();
      expect(months.length, greaterThanOrEqualTo(5));
    });

    test('never drives a product stock negative', () {
      final plan = buildScaleSeedPlan();
      final stock = <int, double>{for (final p in plan.products) p.index: 0};

      for (final mutation in plan.mutations) {
        if (mutation.type == SeedMutationType.stockIn) {
          stock[mutation.productIndex] =
              stock[mutation.productIndex]! + mutation.quantity;
        } else {
          final after = stock[mutation.productIndex]! - mutation.quantity;
          expect(
            after,
            greaterThanOrEqualTo(0),
            reason: 'product ${mutation.productIndex} would go negative',
          );
          stock[mutation.productIndex] = after;
        }
      }
    });

    test('every product is opened by a stock-in before it is ever sold', () {
      final plan = buildScaleSeedPlan();
      final opened = <int>{};

      for (final mutation in plan.mutations) {
        if (mutation.type == SeedMutationType.stockIn) {
          opened.add(mutation.productIndex);
        } else {
          expect(opened, contains(mutation.productIndex));
        }
      }
      expect(opened, hasLength(plan.products.length));
    });

    test('every stock-in carries a cost price and every stock-out does not', () {
      final plan = buildScaleSeedPlan();

      for (final mutation in plan.mutations) {
        if (mutation.type == SeedMutationType.stockIn) {
          expect(mutation.costPricePerUnit, isNotNull);
          expect(mutation.costPricePerUnit, greaterThan(0));
        } else {
          expect(mutation.costPricePerUnit, isNull);
        }
      }
    });

    test('quantities are whole and positive (products are non-fractional)', () {
      final plan = buildScaleSeedPlan();

      for (final mutation in plan.mutations) {
        expect(mutation.quantity, greaterThan(0));
        expect(mutation.quantity, mutation.quantity.roundToDouble());
      }
    });

    test('cost price stays below sell price, so margins are positive', () {
      final plan = buildScaleSeedPlan();

      for (final mutation in plan.mutations) {
        final cost = mutation.costPricePerUnit;
        if (cost == null) continue;
        expect(cost, lessThan(plan.products[mutation.productIndex].sellPrice));
      }
    });

    test('spreads products across nested categories, leaving some uncategorised', () {
      final plan = buildScaleSeedPlan(productCount: 200, uncategorisedEvery: 17);

      expect(plan.categories.any((c) => c.isRoot), isTrue);
      expect(plan.categories.any((c) => !c.isRoot), isTrue);

      // Every child points at a parent that appears earlier in the list,
      // so a single forward pass can create the whole tree.
      final seen = <int>{};
      for (final category in plan.categories) {
        final parent = category.parentIndex;
        if (parent != null) expect(seen, contains(parent));
        seen.add(category.index);
      }

      final used = plan.products.map((p) => p.categoryIndex).toSet();
      expect(used, contains(null));
      expect(used.whereType<int>().length, greaterThan(5));
      // Only leaves are tagged — mirroring how the picker is used.
      final leaves = {
        for (final c in plan.categories)
          if (!c.isRoot) c.index,
      };
      expect(used.whereType<int>().every(leaves.contains), isTrue);
    });

    test('rejects a plan with fewer mutations than products', () {
      expect(
        () => buildScaleSeedPlan(productCount: 10, mutationCount: 5),
        throwsArgumentError,
      );
    });

    test('rejects non-positive product counts and windows', () {
      expect(() => buildScaleSeedPlan(productCount: 0), throwsArgumentError);
      expect(() => buildScaleSeedPlan(monthsBack: 0), throwsArgumentError);
    });
  });

  group('expectedProfitFor', () {
    test('values a single sale at the opening batch cost', () {
      // One product, opened with 100 @ cost, then 10 sold. Built by hand
      // rather than generated, so the expected numbers are obvious.
      final plan = _handPlan(
        sellPrice: 10000,
        events: [
          (SeedMutationType.stockIn, 100.0, 6000.0),
          (SeedMutationType.stockOut, 10.0, null),
        ],
      );

      final expected = expectedProfitFor(plan);

      expect(expected.totalRevenue, 100000);
      expect(expected.totalCost, 60000);
      expect(expected.totalProfit, 40000);
      expect(expected.quantitySold, 10);
      expect(expected.productsSold, 1);
      expect(expected.finalStockByProductIndex[0], 90);
    });

    test('uses the weighted average after a second batch at a new cost', () {
      // 100 @ 6000 then 100 @ 8000 → HPP 7000. The 10 units sold after
      // the second batch must be valued at 7000, not 6000 or 8000.
      final plan = _handPlan(
        sellPrice: 10000,
        events: [
          (SeedMutationType.stockIn, 100.0, 6000.0),
          (SeedMutationType.stockIn, 100.0, 8000.0),
          (SeedMutationType.stockOut, 10.0, null),
        ],
      );

      final expected = expectedProfitFor(plan);

      expect(expected.totalCost, 70000);
      expect(expected.totalProfit, 30000);
    });

    test('values a sale made before a later restock at the older HPP', () {
      // The sale sits between the two batches, so it must be valued at
      // 6000 — the second batch must not retroactively reprice it.
      final plan = _handPlan(
        sellPrice: 10000,
        events: [
          (SeedMutationType.stockIn, 100.0, 6000.0),
          (SeedMutationType.stockOut, 10.0, null),
          (SeedMutationType.stockIn, 100.0, 8000.0),
        ],
      );

      expect(expectedProfitFor(plan).totalCost, 60000);
    });

    test('matches HppCalculator step for step across a generated plan', () {
      // Independent replay through the production calculator: if the
      // library's inlined weighted average ever drifts from
      // HppCalculator, this fails.
      final plan = buildScaleSeedPlan(productCount: 20, mutationCount: 200);

      final stock = <int, double>{for (final p in plan.products) p.index: 0};
      final avgCost = <int, double?>{for (final p in plan.products) p.index: null};
      var revenue = 0.0;
      var cost = 0.0;

      for (final mutation in plan.mutations) {
        final i = mutation.productIndex;
        if (mutation.type == SeedMutationType.stockIn) {
          avgCost[i] = HppCalculator.calculateNewAverage(
            currentStock: stock[i]!,
            currentAvgCost: avgCost[i] ?? 0,
            incomingQty: mutation.quantity,
            incomingCostPrice: mutation.costPricePerUnit!,
          );
          stock[i] = stock[i]! + mutation.quantity;
        } else {
          stock[i] = stock[i]! - mutation.quantity;
          revenue += plan.products[i].sellPrice * mutation.quantity;
          cost += avgCost[i]! * mutation.quantity;
        }
      }

      final expected = expectedProfitFor(plan);
      expect(expected.totalRevenue, closeTo(revenue, 0.000001));
      expect(expected.totalCost, closeTo(cost, 0.000001));
    });

    test('final stock matches a straight replay of the plan', () {
      final plan = buildScaleSeedPlan(productCount: 30, mutationCount: 300);
      final expected = expectedProfitFor(plan);

      final stock = <int, double>{for (final p in plan.products) p.index: 0};
      for (final mutation in plan.mutations) {
        stock[mutation.productIndex] = stock[mutation.productIndex]! +
            (mutation.type == SeedMutationType.stockIn
                ? mutation.quantity
                : -mutation.quantity);
      }

      expect(expected.finalStockByProductIndex, stock);
    });

    test('reports a positive total profit for the default plan', () {
      final expected = expectedProfitFor(buildScaleSeedPlan());

      expect(expected.totalRevenue, greaterThan(0));
      expect(expected.totalProfit, greaterThan(0));
      expect(expected.productsSold, greaterThan(0));
    });
  });

  group('expectedCriticalProductIndexes', () {
    test('selects exactly the products at or below their threshold', () {
      final plan = buildScaleSeedPlan();
      final expected = expectedProfitFor(plan);

      final critical = expectedCriticalProductIndexes(plan, expected);

      expect(critical, isNotEmpty);
      for (final product in plan.products) {
        final stock = expected.finalStockByProductIndex[product.index]!;
        expect(
          critical.contains(product.index),
          stock <= product.minStockThreshold,
          reason: 'product ${product.index} stock $stock vs threshold '
              '${product.minStockThreshold}',
        );
      }
    });

    test('is empty when every product is comfortably stocked', () {
      final plan = _handPlan(
        sellPrice: 10000,
        minStockThreshold: 5,
        events: [(SeedMutationType.stockIn, 100.0, 6000.0)],
      );

      expect(
        expectedCriticalProductIndexes(plan, expectedProfitFor(plan)),
        isEmpty,
      );
    });

    test('includes a product sold down to exactly its threshold', () {
      // Boundary case: the app's predicate is `<=`, so a product sitting
      // *on* its threshold is critical, not safe.
      final plan = _handPlan(
        sellPrice: 10000,
        minStockThreshold: 5,
        events: [
          (SeedMutationType.stockIn, 100.0, 6000.0),
          (SeedMutationType.stockOut, 95.0, null),
        ],
      );

      expect(
        expectedCriticalProductIndexes(plan, expectedProfitFor(plan)),
        {0},
      );
    });
  });

  group('assertSafeSeedDirectory', () {
    test('accepts a directory outside the production one', () {
      expect(
        () => assertSafeSeedDirectory(
          seedDirectory: '/data/user/0/app/cache/scale_seed',
          productionDirectory: '/data/user/0/app/app_flutter',
        ),
        returnsNormally,
      );
    });

    test('refuses the production directory itself', () {
      expect(
        () => assertSafeSeedDirectory(
          seedDirectory: '/data/user/0/app/app_flutter',
          productionDirectory: '/data/user/0/app/app_flutter',
        ),
        throwsA(isA<UnsafeSeedDirectoryError>()),
      );
    });

    test('refuses it regardless of trailing separators', () {
      expect(
        () => assertSafeSeedDirectory(
          seedDirectory: '/data/user/0/app/app_flutter/',
          productionDirectory: '/data/user/0/app/app_flutter',
        ),
        throwsA(isA<UnsafeSeedDirectoryError>()),
      );
    });

    test('refuses a subdirectory of the production directory', () {
      expect(
        () => assertSafeSeedDirectory(
          seedDirectory: '/data/user/0/app/app_flutter/seed',
          productionDirectory: '/data/user/0/app/app_flutter',
        ),
        throwsA(isA<UnsafeSeedDirectoryError>()),
      );
    });

    test('does not mistake a sibling with a shared prefix for a child', () {
      // The bug a naive startsWith() would have: `app_flutter_seed` is a
      // sibling, not a child, and must be allowed.
      expect(
        () => assertSafeSeedDirectory(
          seedDirectory: '/data/user/0/app/app_flutter_seed',
          productionDirectory: '/data/user/0/app/app_flutter',
        ),
        returnsNormally,
      );
    });
  });
}

/// A one-product plan with hand-specified events, for tests that need
/// obvious arithmetic rather than generated data.
ScaleSeedPlan _handPlan({
  required double sellPrice,
  required List<(SeedMutationType, double, double?)> events,
  double minStockThreshold = 5,
}) {
  final start = DateTime(2026, 1, 1);
  return ScaleSeedPlan(
    categories: const [SeedCategory(index: 0, name: 'Uji')],
    products: [
      SeedProduct(
        index: 0,
        name: 'Produk Uji',
        categoryIndex: 0,
        sellPrice: sellPrice,
        unit: 'pcs',
        minStockThreshold: minStockThreshold,
      ),
    ],
    mutations: [
      for (var i = 0; i < events.length; i++)
        SeedMutation(
          productIndex: 0,
          type: events[i].$1,
          quantity: events[i].$2,
          at: start.add(Duration(days: i)),
          costPricePerUnit: events[i].$3,
        ),
    ],
  );
}
