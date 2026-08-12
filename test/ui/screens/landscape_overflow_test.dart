import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/ui/screens/mutasi/catat_mutasi_screen.dart';
import 'package:inventaris_toko/ui/screens/mutasi/mutasi_screen.dart';
import 'package:inventaris_toko/ui/screens/mutasi/product_mutation_history_screen.dart';
import 'package:inventaris_toko/ui/screens/pengaturan/kelola_kategori_screen.dart';
import 'package:inventaris_toko/ui/screens/pengaturan/pengaturan_screen.dart';
import 'package:inventaris_toko/ui/screens/produk/archived_products_screen.dart';
import 'package:inventaris_toko/ui/screens/produk/product_detail_screen.dart';
import 'package:inventaris_toko/ui/screens/produk/product_form_screen.dart';
import 'package:inventaris_toko/ui/screens/produk/produk_screen.dart';
import 'package:isar_community/isar.dart';

import '../../data/repositories/test_isar.dart';
import '../widget_test_helpers.dart';

const _sizes = [
  Size(800, 360), // common phone landscape
  Size(667, 320), // very short landscape (tight case)
  Size(1024, 768), // tablet landscape
];

/// Pumps [screen], asserts no overflow/layout exception was thrown at any
/// of the representative landscape sizes above, and reports the first
/// failure in full if one occurs.
Future<void> _expectNoLandscapeOverflow(
  WidgetTester tester,
  String label,
  Widget Function() buildScreen,
) async {
  for (final size in _sizes) {
    FlutterErrorDetails? captured;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      captured ??= details;
      originalOnError?.call(details);
    };

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(home: buildScreen()));
    await settleAfterAsyncWork(tester);

    FlutterError.onError = originalOnError;
    if (captured != null) {
      // ignore: avoid_print
      print('$label @ $size => FULL DETAILS:\n${captured.toString()}');
    }
    expect(captured, isNull, reason: '$label overflowed at $size');

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository stockMutationRepository;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    stockMutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      stockMutationRepository,
      AppSettingsRepository(isar),
    );
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  testWidgets('ProdukScreen: no landscape overflow (empty + with data)', (tester) async {
    await tester.runAsync(() async {
      await _expectNoLandscapeOverflow(
        tester,
        'ProdukScreen (empty)',
        () => ProdukScreen(isar: isar),
      );

      final snacks = await categoryRepository.create('Snacks');
      await categoryRepository.create('Drinks');
      await categoryRepository.create('Household');
      for (var i = 0; i < 5; i++) {
        await productRepository.create(
          name: 'Chips $i',
          categoryId: snacks.id,
          sellPrice: 5000,
          unit: 'pcs',
          initialStock: 12,
        );
      }

      await _expectNoLandscapeOverflow(
        tester,
        'ProdukScreen (with data)',
        () => ProdukScreen(isar: isar),
      );
    });
  });

  testWidgets('MutasiScreen: no landscape overflow (empty + with data)', (tester) async {
    await tester.runAsync(() async {
      await _expectNoLandscapeOverflow(
        tester,
        'MutasiScreen (empty)',
        () => MutasiScreen(isar: isar),
      );

      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );
      await stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 5,
      );

      await _expectNoLandscapeOverflow(
        tester,
        'MutasiScreen (with data)',
        () => MutasiScreen(isar: isar),
      );
    });
  });

  testWidgets('CatatMutasiScreen: no landscape overflow (search mode + form mode)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );

      await _expectNoLandscapeOverflow(
        tester,
        'CatatMutasiScreen (search mode)',
        () => CatatMutasiScreen(isar: isar),
      );

      await _expectNoLandscapeOverflow(
        tester,
        'CatatMutasiScreen (form mode)',
        () => CatatMutasiScreen(isar: isar, product: product),
      );
    });
  });

  testWidgets('PengaturanScreen: no landscape overflow', (tester) async {
    await tester.runAsync(() async {
      await _expectNoLandscapeOverflow(
        tester,
        'PengaturanScreen',
        () => PengaturanScreen(isar: isar),
      );
    });
  });

  testWidgets('KelolaKategoriScreen: no landscape overflow (empty + with data)', (tester) async {
    await tester.runAsync(() async {
      // KelolaKategoriScreen is bottom-sheet content: showModalBottomSheet
      // normally wraps it in a Material ancestor, which this direct pump
      // has to provide itself.
      await _expectNoLandscapeOverflow(
        tester,
        'KelolaKategoriScreen (empty)',
        () => Material(child: KelolaKategoriScreen(isar: isar)),
      );

      await categoryRepository.create('Snacks');
      await categoryRepository.create('Drinks');

      await _expectNoLandscapeOverflow(
        tester,
        'KelolaKategoriScreen (with data)',
        () => Material(child: KelolaKategoriScreen(isar: isar)),
      );
    });
  });

  testWidgets('ProductFormScreen: no landscape overflow (add + edit)', (tester) async {
    await tester.runAsync(() async {
      await categoryRepository.create('Snacks');

      await _expectNoLandscapeOverflow(
        tester,
        'ProductFormScreen (add)',
        () => ProductFormScreen(isar: isar),
      );

      final category = await categoryRepository.create('Drinks');
      final product = await productRepository.create(
        name: 'Teh Botol',
        categoryId: category.id,
        sellPrice: 4000,
        unit: 'botol',
        initialStock: 20,
        code: 'TB001',
      );

      await _expectNoLandscapeOverflow(
        tester,
        'ProductFormScreen (edit)',
        () => ProductFormScreen(isar: isar, existing: product),
      );
    });
  });

  testWidgets('ProductDetailScreen: no landscape overflow', (tester) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );
      await stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 5,
      );

      await _expectNoLandscapeOverflow(
        tester,
        'ProductDetailScreen',
        () => ProductDetailScreen(isar: isar, productId: product.id),
      );
    });
  });

  testWidgets('ArchivedProductsScreen: no landscape overflow (empty + with data)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _expectNoLandscapeOverflow(
        tester,
        'ArchivedProductsScreen (empty)',
        () => ArchivedProductsScreen(isar: isar),
      );

      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );
      await productRepository.archive(product.id);

      await _expectNoLandscapeOverflow(
        tester,
        'ArchivedProductsScreen (with data)',
        () => ArchivedProductsScreen(isar: isar),
      );
    });
  });

  testWidgets('ProductMutationHistoryScreen: no landscape overflow (empty + with data)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final category = await categoryRepository.create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );

      await _expectNoLandscapeOverflow(
        tester,
        'ProductMutationHistoryScreen (empty)',
        () => ProductMutationHistoryScreen(isar: isar, product: product),
      );

      await stockMutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 5,
      );
      final updated = await productRepository.getById(product.id);

      await _expectNoLandscapeOverflow(
        tester,
        'ProductMutationHistoryScreen (with data)',
        () => ProductMutationHistoryScreen(isar: isar, product: updated!),
      );
    });
  });
}
