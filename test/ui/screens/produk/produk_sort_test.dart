import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/screens/produk/produk_screen.dart';
import 'package:inventaris_toko/ui/screens/produk/sort_mode.dart';

void main() {
  group('sortProducts function', () {
    test('stockAscending sorts products from lowest to highest stock', () {
      final products = [
        _ProductTestDouble('A', 100),
        _ProductTestDouble('B', 10),
        _ProductTestDouble('C', 50),
      ];

      final sorted = sortProducts(
        products: products,
        sortMode: SortMode.stockAscending,
      );

      expect(sorted[0].currentStock, 10);
      expect(sorted[1].currentStock, 50);
      expect(sorted[2].currentStock, 100);
    });

    test('products with equal stock are sorted alphabetically by name', () {
      final products = [
        _ProductTestDouble('Zebra', 50),
        _ProductTestDouble('Apple', 50),
        _ProductTestDouble('Mango', 50),
      ];

      final sorted = sortProducts(
        products: products,
        sortMode: SortMode.stockAscending,
      );

      expect(sorted[0].name, 'Apple');
      expect(sorted[1].name, 'Mango');
      expect(sorted[2].name, 'Zebra');
    });

    test('empty product list returns empty list without error', () {
      final sorted = sortProducts<_ProductTestDouble>(
        products: [],
        sortMode: SortMode.stockAscending,
      );

      expect(sorted, isEmpty);
    });

    test('single product returns single-element list', () {
      final products = [
        _ProductTestDouble('Single', 10),
      ];

      final sorted = sortProducts(
        products: products,
        sortMode: SortMode.stockAscending,
      );

      expect(sorted.length, 1);
      expect(sorted[0].name, 'Single');
    });

    test('defaultOrder preserves original order', () {
      final products = [
        _ProductTestDouble('C', 100),
        _ProductTestDouble('A', 10),
        _ProductTestDouble('B', 50),
      ];

      final sorted = sortProducts(
        products: products,
        sortMode: SortMode.defaultOrder,
      );

      expect(sorted[0].name, 'C');
      expect(sorted[1].name, 'A');
      expect(sorted[2].name, 'B');
    });

    test('sort with mixed stock levels and names', () {
      final products = [
        _ProductTestDouble('Product Z', 5),
        _ProductTestDouble('Product A', 5),
        _ProductTestDouble('Product M', 10),
      ];

      final sorted = sortProducts(
        products: products,
        sortMode: SortMode.stockAscending,
      );

      expect(sorted[0].name, 'Product A');
      expect(sorted[0].currentStock, 5);
      expect(sorted[1].name, 'Product Z');
      expect(sorted[1].currentStock, 5);
      expect(sorted[2].name, 'Product M');
      expect(sorted[2].currentStock, 10);
    });
  });
}

// Minimal test double that implements the interface needed for sortProducts
class _ProductTestDouble {
  _ProductTestDouble(this.name, this.currentStock);

  final String name;
  final double currentStock;
}
