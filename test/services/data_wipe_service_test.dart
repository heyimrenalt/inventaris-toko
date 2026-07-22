import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/category.dart';
import 'package:inventaris_toko/data/models/cost_price_adjustment.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/restock_list.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/cost_price_adjustment_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/restock_list_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/services/data_wipe_service.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:isar_community/isar.dart';

import '../data/repositories/test_isar.dart';
import '../ui/screens/produk/fake_photo_storage_service.dart';

class _FakeNotificationSender implements NotificationSender {
  int cancelAllCallCount = 0;

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
  Future<void> cancelAllNotifications() async {
    cancelAllCallCount++;
  }
}

class _FakeWorkScheduler implements WorkScheduler {
  final List<String> cancelled = [];

  @override
  Future<void> cancel(String uniqueName) async {
    cancelled.add(uniqueName);
  }

  @override
  Future<void> registerOneOff(String uniqueName, String taskName, {required Duration initialDelay}) async {}

  @override
  Future<void> registerPeriodic(String uniqueName, String taskName, {required Duration frequency}) async {}
}

class _FakeAlarmScheduler implements AlarmScheduler {
  final List<int> cancelled = [];

  @override
  Future<void> scheduleExact(int slotIndex, DateTime time) async {}

  @override
  Future<void> cancel(int slotIndex) async {
    cancelled.add(slotIndex);
  }
}

class _FakeExactAlarmPermission implements ExactAlarmPermission {
  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmsPermission() async {}
}

void main() {
  late Isar isar;
  late _FakeNotificationSender fakeSender;
  late _FakeWorkScheduler fakeScheduler;
  late _FakeAlarmScheduler fakeAlarmScheduler;
  late FakePhotoStorageService fakePhotoStorageService;
  late IsarDataWipeService dataWipeService;

  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository mutationRepository;
  late AppSettingsRepository settingsRepository;
  late CostPriceAdjustmentRepository costPriceAdjustmentRepository;
  late RestockListRepository restockListRepository;

  setUp(() async {
    isar = await openTestIsar();
    fakeSender = _FakeNotificationSender();
    fakeScheduler = _FakeWorkScheduler();
    fakeAlarmScheduler = _FakeAlarmScheduler();
    NotificationService.sender = fakeSender;
    NotificationService.scheduler = fakeScheduler;
    NotificationService.alarmScheduler = fakeAlarmScheduler;
    NotificationService.exactAlarmPermission = _FakeExactAlarmPermission();

    fakePhotoStorageService = FakePhotoStorageService();
    dataWipeService = IsarDataWipeService(isar, photoStorageService: fakePhotoStorageService);

    settingsRepository = AppSettingsRepository(isar);
    mutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(isar, mutationRepository, settingsRepository);
    categoryRepository = CategoryRepository(isar);
    costPriceAdjustmentRepository = CostPriceAdjustmentRepository(isar);
    restockListRepository = RestockListRepository(isar);
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  Future<void> seedEverything() async {
    final category = await categoryRepository.create('Snacks');
    final product = await productRepository.create(
      name: 'Indomie Goreng',
      categoryId: category.id,
      sellPrice: 3000,
      unit: 'pcs',
      photoPath: '/fake/photos/indomie.jpg',
      initialStock: 10,
    );
    await mutationRepository.recordMutation(
      productId: product.id,
      type: StockMutationType.stockOut,
      quantity: 2,
    );
    await costPriceAdjustmentRepository.recordAdjustment(
      productId: product.id,
      newCost: 2500,
      note: 'koreksi awal',
    );
    await restockListRepository.create(
      supplierName: 'Toko Grosir',
      items: [
        RestockListItemInput(
          productId: product.id,
          productName: product.name,
          qtyInPcs: 24,
          inputUnitWasPack: false,
        ),
      ],
    );
    // Non-default settings, so the reset-to-defaults assertion is
    // actually meaningful rather than trivially true.
    await settingsRepository.updateDailySummaryTime(hour: 6, minute: 30);
    await settingsRepository.dismissBatteryOptimizationDialog();

    return;
  }

  test('wipes every collection empty', () async {
    await seedEverything();

    await dataWipeService.wipeAll();

    expect(await isar.categories.count(), 0);
    expect(await isar.products.count(), 0);
    expect(await isar.stockMutations.count(), 0);
    expect(await isar.costPriceAdjustments.count(), 0);
    expect(await isar.restockLists.count(), 0);
    // AppSettings has no row of its own left; the next .get() recreates
    // the singleton from defaults (asserted below), so it isn't checked
    // for emptiness here.
  });

  test('deletes every product photo file via the photo storage service', () async {
    await seedEverything();

    await dataWipeService.wipeAll();

    expect(fakePhotoStorageService.deletedPaths, contains('/fake/photos/indomie.jpg'));
  });

  test('resets AppSettings to defaults', () async {
    await seedEverything();
    final beforeWipe = await settingsRepository.get();
    expect(beforeWipe.dailySummaryHour, 6, reason: 'sanity check: seeded a non-default value');
    expect(beforeWipe.batteryOptimizationDialogDismissed, isTrue);

    await dataWipeService.wipeAll();

    final afterWipe = await settingsRepository.get();
    expect(afterWipe.dailySummaryHour, 20);
    expect(afterWipe.dailySummaryMinute, 0);
    expect(afterWipe.batteryOptimizationDialogDismissed, isFalse);
    expect(afterWipe.criticalStockAlertHour1, 9);
  });

  test('cancels scheduled notifications', () async {
    await seedEverything();

    await dataWipeService.wipeAll();

    expect(fakeScheduler.cancelled, isNotEmpty);
    expect(fakeAlarmScheduler.cancelled, containsAll([0, 1, 2]));
    expect(fakeSender.cancelAllCallCount, 1);
  });

  test('fresh install with no data succeeds as a no-op', () async {
    expect(await isar.products.count(), 0);

    await expectLater(dataWipeService.wipeAll(), completes);

    expect(await isar.products.count(), 0);
    expect(fakePhotoStorageService.deletedPaths, isEmpty);
    expect(fakeSender.cancelAllCallCount, 1);
  });

  test('a product with no photo does not attempt any photo deletion', () async {
    final category = await categoryRepository.create('Snacks');
    await productRepository.create(
      name: 'Beras 5kg',
      categoryId: category.id,
      sellPrice: 65000,
      unit: 'pcs',
    );

    await dataWipeService.wipeAll();

    expect(fakePhotoStorageService.deletedPaths, isEmpty);
  });
}
