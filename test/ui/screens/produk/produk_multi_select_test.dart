import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/services/photo_storage_service.dart';
import 'package:inventaris_toko/ui/screens/produk/produk_screen.dart';
import 'package:inventaris_toko/ui/widgets/product_grid_card.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';
import '../../widget_test_helpers.dart';

/// Records deletions instead of touching the filesystem.
class _FakePhotoStorageService implements PhotoStorageService {
  final List<String> deleted = [];

  @override
  Future<void> deletePhoto(String path) async => deleted.add(path);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository mutationRepository;
  late _FakePhotoStorageService photoStorage;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    mutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(
      isar,
      mutationRepository,
      AppSettingsRepository(isar),
    );
    photoStorage = _FakePhotoStorageService();
  });

  tearDown(() async => closeTestIsar(isar));

  Future<Product> makeProduct(String name, {double initialStock = 0}) async {
    final category = await categoryRepository.create('Cat $name');
    return productRepository.create(
      name: name,
      categoryId: category.id,
      unit: 'pcs',
      sellPrice: 1000,
      initialStock: initialStock,
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProdukScreen(isar: isar, photoStorageService: photoStorage),
    ));
    await settleAfterAsyncWork(tester);
  }

  /// A hand-rolled long press rather than [WidgetTester.longPress].
  /// These tests run inside [WidgetTester.runAsync] because Isar needs the
  /// real async zone, and there the recognizer's 500ms timer is a real
  /// timer — advancing the fake clock, which is all longPress does, never
  /// fires it.
  Future<void> longPressCard(WidgetTester tester, String name) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text(name)));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await tester.pump();
    await gesture.up();
    await settleAfterAsyncWork(tester);
  }

  ProductGridCard cardFor(WidgetTester tester, String name) =>
      tester.widget<ProductGridCard>(find.ancestor(
        of: find.text(name),
        matching: find.byType(ProductGridCard),
      ));

  testWidgets('a long press starts selection with that product ticked',
      (tester) async {
    await tester.runAsync(() async {
      await makeProduct('Chiki');
      await makeProduct('Chitato');
      await pumpScreen(tester);

      expect(find.byKey(const Key('produk_selection_archive')), findsNothing);

      await longPressCard(tester, 'Chiki');

      expect(find.text('1 dipilih'), findsOneWidget);
      expect(cardFor(tester, 'Chiki').selected, isTrue);
      expect(cardFor(tester, 'Chitato').selected, isFalse);
      // Every card shows a tick while selecting, so it is clear which
      // ones can be picked.
      expect(cardFor(tester, 'Chitato').selectionMode, isTrue);
    });
  });

  testWidgets('tapping while selecting toggles instead of opening detail',
      (tester) async {
    await tester.runAsync(() async {
      await makeProduct('Chiki');
      await makeProduct('Chitato');
      await pumpScreen(tester);

      await longPressCard(tester, 'Chiki');
      await tester.tap(find.text('Chitato'));
      await settleAfterAsyncWork(tester);

      expect(find.text('2 dipilih'), findsOneWidget);
      // Still on the grid — no navigation happened.
      expect(find.byType(ProductGridCard), findsNWidgets(2));

      await tester.tap(find.text('Chitato'));
      await settleAfterAsyncWork(tester);
      expect(find.text('1 dipilih'), findsOneWidget);
    });
  });

  testWidgets('closing selection clears it', (tester) async {
    await tester.runAsync(() async {
      await makeProduct('Chiki');
      await pumpScreen(tester);

      await longPressCard(tester, 'Chiki');
      await tester.tap(find.byKey(const Key('produk_selection_close')));
      await settleAfterAsyncWork(tester);

      expect(find.text('1 dipilih'), findsNothing);
      expect(cardFor(tester, 'Chiki').selectionMode, isFalse);
    });
  });

  testWidgets('archiving the selection hides the products and offers an undo',
      (tester) async {
    await tester.runAsync(() async {
      await makeProduct('Chiki');
      await makeProduct('Chitato');
      await pumpScreen(tester);

      await longPressCard(tester, 'Chiki');
      await tester.tap(find.text('Chitato'));
      await settleAfterAsyncWork(tester);
      await tester.tap(find.byKey(const Key('produk_selection_archive')));
      await settleAfterAsyncWork(tester);

      expect(find.byType(ProductGridCard), findsNothing);
      expect((await productRepository.getArchived()).length, 2);
      expect(find.text('2 produk diarsipkan'), findsOneWidget);

      // The undo is the whole reason bulk archive is safe to offer.
      await tester.tap(find.text('Urungkan'));
      await settleAfterAsyncWork(tester);

      expect((await productRepository.getAll()).length, 2);
    });
  });

  testWidgets('deleting a selection with history keeps the ledger and offers archiving',
      (tester) async {
    await tester.runAsync(() async {
      final withHistory = await makeProduct('Punya riwayat', initialStock: 4);
      await makeProduct('Bersih');
      await pumpScreen(tester);

      await longPressCard(tester, 'Punya riwayat');
      await tester.tap(find.text('Bersih'));
      await settleAfterAsyncWork(tester);
      await tester.tap(find.byKey(const Key('produk_selection_delete')));
      await settleAfterAsyncWork(tester);

      // Confirm the destructive action.
      await tester.tap(find.text('Hapus'));
      await settleAfterAsyncWork(tester);

      // The blocked product is named and archiving is offered in the
      // same dialog rather than leaving a half-done operation unexplained.
      expect(find.text('Sebagian Tidak Bisa Dihapus'), findsOneWidget);
      await tester.tap(find.text('Arsipkan'));
      await settleAfterAsyncWork(tester);

      // Mutations survived, the product survived (archived), and only the
      // clean one is gone.
      expect(await mutationRepository.getHistoryForProduct(withHistory.id), isNotEmpty);
      expect((await productRepository.getById(withHistory.id))!.isArchived, isTrue);
      expect(await productRepository.getAll(), isEmpty);
    });
  });

  testWidgets('a clean delete removes the product and its photo file',
      (tester) async {
    await tester.runAsync(() async {
      final product = await makeProduct('Bersih');
      await productRepository.update(id: product.id, photoPath: '/photos/bersih.jpg');
      await pumpScreen(tester);

      await longPressCard(tester, 'Bersih');
      await tester.tap(find.byKey(const Key('produk_selection_delete')));
      await settleAfterAsyncWork(tester);
      await tester.tap(find.text('Hapus'));
      await settleAfterAsyncWork(tester);

      expect(await productRepository.getAll(includeArchived: true), isEmpty);
      expect(photoStorage.deleted, ['/photos/bersih.jpg']);
    });
  });
}
