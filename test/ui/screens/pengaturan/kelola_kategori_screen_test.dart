import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/ui/screens/pengaturan/kelola_kategori_screen.dart';
import 'package:isar_community/isar.dart';

import '../../../data/repositories/test_isar.dart';

// NOTE on tester.runAsync() + the extra real delay below: KelolaKategoriScreen
// triggers real Isar FFI calls reactively (from initState and button
// handlers) while being pumped. testWidgets() runs inside Flutter's
// fake-async test zone, and even inside tester.runAsync(), pumpAndSettle()
// only advances the widget tree's own frame/animation scheduling — it does
// not itself wait for an unrelated real Future (Isar's native completion)
// to resolve. Confirmed by tracing: the repository call was still
// completing *after* pumpAndSettle() had already given up. So after any
// action that triggers a real repository call, we do a real (runAsync)
// `pump()` + short `Future.delayed` + `pumpAndSettle()` — the delay gives
// the real FFI completion time to land and call setState before we ask the
// tree to settle.
void main() {
  late Isar isar;
  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;

  setUp(() async {
    isar = await openTestIsar();
    categoryRepository = CategoryRepository(isar);
    productRepository = ProductRepository(
      isar,
      StockMutationRepository(isar),
      AppSettingsRepository(isar),
    );
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> settleAfterAsyncWork(WidgetTester tester) async {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: KelolaKategoriScreen(isar: isar)));
    await settleAfterAsyncWork(tester);
  }

  Future<void> openAddDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Kategori'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when no categories exist', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(
        find.text('Belum ada kategori. Tambahkan kategori pertama untuk mulai.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Tambah Kategori'), findsOneWidget);
    });
  });

  testWidgets('shows list of categories when they exist', (tester) async {
    await tester.runAsync(() async {
      await categoryRepository.create('Snacks');
      await categoryRepository.create('Drinks');

      await pumpScreen(tester);

      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('Drinks'), findsOneWidget);
      expect(
        find.text('Belum ada kategori. Tambahkan kategori pertama untuk mulai.'),
        findsNothing,
      );
    });
  });

  testWidgets('add flow: valid name is added to the visible list', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await openAddDialog(tester);
      await tester.enterText(find.byType(TextField), 'Snacks');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('Kategori ditambahkan'), findsOneWidget);
      expect(await categoryRepository.getAll(), hasLength(1));
    });
  });

  testWidgets('add flow: empty name shows validation error and keeps dialog open', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await openAddDialog(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Nama kategori tidak boleh kosong'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(await categoryRepository.getAll(), isEmpty);
    });
  });

  testWidgets('add flow: duplicate name shows validation error and keeps dialog open', (tester) async {
    await tester.runAsync(() async {
      await categoryRepository.create('Snacks');
      await pumpScreen(tester);

      await openAddDialog(tester);
      await tester.enterText(find.byType(TextField), 'Snacks');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Kategori dengan nama ini sudah ada'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(await categoryRepository.getAll(), hasLength(1));
    });
  });

  testWidgets('rename flow: renames and reflects new name in the list', (tester) async {
    await tester.runAsync(() async {
      await categoryRepository.create('Snacks');
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Ubah'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Minuman');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await settleAfterAsyncWork(tester);

      expect(find.text('Minuman'), findsOneWidget);
      expect(find.text('Snacks'), findsNothing);
      expect(find.text('Kategori diperbarui'), findsOneWidget);
    });
  });

  testWidgets('delete flow: confirming delete on an unused category removes it', (tester) async {
    await tester.runAsync(() async {
      await categoryRepository.create('Snacks');
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
      await tester.pumpAndSettle();

      // Confirm inside the "Hapus Kategori" confirmation dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Hapus'),
        ),
      );
      await settleAfterAsyncWork(tester);

      expect(find.text('Snacks'), findsNothing);
      expect(find.text('Kategori dihapus'), findsOneWidget);
      expect(await categoryRepository.getAll(), isEmpty);
    });
  });

  testWidgets(
    'delete flow: category in use shows blocking message with product count and stays in list',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        await productRepository.create(
          name: 'Chips',
          categoryId: category.id,
          sellPrice: 1000,
          unit: 'pcs',
        );

        await pumpScreen(tester);

        await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Hapus'),
          ),
        );
        await settleAfterAsyncWork(tester);

        expect(
          find.textContaining('masih dipakai oleh 1 produk'),
          findsOneWidget,
        );
        expect(find.text('Snacks'), findsOneWidget);
        expect(await categoryRepository.getAll(), hasLength(1));
      });
    },
  );
}
