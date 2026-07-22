import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:inventaris_toko/ui/navigation/main_scaffold.dart';
import 'package:inventaris_toko/ui/screens/produk/produk_screen.dart';
import 'package:inventaris_toko/ui/widgets/app_header.dart';
import 'package:isar_community/isar.dart';

import '../../data/repositories/test_isar.dart';
import '../widget_test_helpers.dart';

// This file's MainScaffold pump would otherwise get the one-time OEM
// battery-optimization dialog (see PengaturanScreen._loadSettings) auto-shown
// on top of it — PengaturanScreen is one of the 4 tabs IndexedStack builds
// eagerly, so its initState runs immediately even though Beranda is the
// active tab. Left dismissed, that dialog's full-screen ModalBarrier
// intercepts every nav-bar tap these tests make.

/// Avoids touching real plugin channels (unavailable in `flutter test`)
/// when "Hapus semua data" calls through to [NotificationService.cancelAll].
class _FakeNotificationSender implements NotificationSender {
  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required bool highImportance,
    String? payload,
  }) async {}

  @override
  Future<void> cancelAllNotifications() async {}
}

class _FakeWorkScheduler implements WorkScheduler {
  @override
  Future<void> cancel(String uniqueName) async {}

  @override
  Future<void> registerOneOff(String uniqueName, String taskName, {required Duration initialDelay}) async {}

  @override
  Future<void> registerPeriodic(String uniqueName, String taskName, {required Duration frequency}) async {}
}

class _FakeAlarmScheduler implements AlarmScheduler {
  @override
  Future<void> scheduleExact(int slotIndex, DateTime time) async {}

  @override
  Future<void> cancel(int slotIndex) async {}
}

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
    NotificationService.sender = _FakeNotificationSender();
    NotificationService.scheduler = _FakeWorkScheduler();
    NotificationService.alarmScheduler = _FakeAlarmScheduler();
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> pumpScaffold(WidgetTester tester) async {
    await AppSettingsRepository(isar).dismissBatteryOptimizationDialog();
    await tester.pumpWidget(MaterialApp(home: MainScaffold(isar: isar)));
    await settleAfterAsyncWork(tester);
  }

  // Reads the offset straight from ProdukScreen's CustomScrollView
  // controller rather than via find.byType(Scrollable): the search
  // TextField's own EditableText embeds an internal Scrollable for text
  // scrolling, so an unscoped Scrollable finder is ambiguous even within
  // just this one screen.
  double produkScrollOffset(WidgetTester tester) {
    final customScrollView = tester.widget<CustomScrollView>(
      find.descendant(of: find.byType(ProdukScreen), matching: find.byType(CustomScrollView)),
    );
    return customScrollView.controller!.offset;
  }

  Future<void> seedManyProducts(int count) async {
    final category = await categoryRepository.create('Snacks');
    for (var i = 0; i < count; i++) {
      await productRepository.create(
        name: 'Produk $i',
        categoryId: category.id,
        sellPrice: 1000,
        unit: 'pcs',
      );
    }
  }

  testWidgets("tapping the active tab's nav item scrolls its list to offset 0", (tester) async {
    await tester.runAsync(() async {
      await seedManyProducts(40);
      await pumpScaffold(tester);

      await tester.tap(find.byIcon(Icons.inventory_2));
      await settleAfterAsyncWork(tester);

      await tester.drag(find.byType(ProdukScreen), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(produkScrollOffset(tester), greaterThan(0));

      // Produk is already the active tab — this tap should scroll it
      // back to the top instead of doing nothing.
      await tester.tap(find.byIcon(Icons.inventory_2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(produkScrollOffset(tester), 0);
    });
  });

  testWidgets("tapping a different tab's nav item switches tabs and does not scroll", (tester) async {
    await tester.runAsync(() async {
      await seedManyProducts(40);
      await pumpScaffold(tester);

      await tester.tap(find.byIcon(Icons.inventory_2));
      await settleAfterAsyncWork(tester);

      await tester.drag(find.byType(ProdukScreen), const Offset(0, -1000));
      await tester.pumpAndSettle();
      final scrolledOffset = produkScrollOffset(tester);
      expect(scrolledOffset, greaterThan(0));

      // Tapping a different tab (Mutasi) switches tabs...
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await settleAfterAsyncWork(tester);
      expect(find.widgetWithText(AppHeader, 'Mutasi stok'), findsOneWidget);

      // ...and Produk (kept alive underneath by IndexedStack) must not
      // have had its scroll position touched by that tap.
      await tester.tap(find.byIcon(Icons.inventory_2));
      await settleAfterAsyncWork(tester);
      expect(produkScrollOffset(tester), scrolledOffset);
    });
  });

  testWidgets('tapping the active tab while already at offset 0 is a no-op', (tester) async {
    await tester.runAsync(() async {
      await seedManyProducts(40);
      await pumpScaffold(tester);

      await tester.tap(find.byIcon(Icons.inventory_2));
      await settleAfterAsyncWork(tester);
      expect(produkScrollOffset(tester), 0);

      await tester.tap(find.byIcon(Icons.inventory_2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(produkScrollOffset(tester), 0);
    });
  });

  testWidgets(
    'after a successful "Hapus semua data" wipe, the app switches to Beranda showing an empty state',
    (tester) async {
      await tester.runAsync(() async {
        final category = await categoryRepository.create('Snacks');
        await productRepository.create(
          name: 'Indomie Goreng',
          categoryId: category.id,
          sellPrice: 3000,
          unit: 'pcs',
        );

        await pumpScaffold(tester);

        // Sanity check: Beranda (the initial tab) reflects the seeded
        // product before any wipe happens.
        Text totalProdukText() => tester.widget<Text>(
              find
                  .descendant(
                    of: find.byKey(const Key('beranda_summary_total_produk')),
                    matching: find.byType(Text),
                  )
                  .last,
            );
        expect(totalProdukText().data, '1');

        await tester.tap(find.byIcon(Icons.settings));
        await settleAfterAsyncWork(tester);

        await tester.scrollUntilVisible(
          find.byKey(const Key('pengaturan_hapus_semua_data_tile')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('pengaturan_hapus_semua_data_tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('hapus_semua_data_step1_lanjutkan')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('hapus_semua_data_confirm_field')), 'HAPUS');
        await tester.pump();
        await tester.tap(find.byKey(const Key('hapus_semua_data_step2_confirm')));
        await settleAfterAsyncWork(tester);

        final bottomNav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
        expect(bottomNav.currentIndex, 0, reason: 'must switch back to the Beranda tab');

        expect(totalProdukText().data, '0');
        expect(find.byKey(const Key('beranda_priority_empty_state')), findsOneWidget);
      });
    },
  );
}
