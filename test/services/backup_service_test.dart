import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/app_settings.dart';
import 'package:inventaris_toko/data/models/category.dart';
import 'package:inventaris_toko/data/models/cost_price_adjustment.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/restock_list.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/cost_price_adjustment_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/repository_exceptions.dart';
import 'package:inventaris_toko/data/repositories/restock_list_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/services/backup_service.dart';
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
  int registeredPeriodicCount = 0;

  @override
  Future<void> cancel(String uniqueName) async {
    cancelled.add(uniqueName);
  }

  @override
  Future<void> registerOneOff(String uniqueName, String taskName, {required Duration initialDelay}) async {}

  @override
  Future<void> registerPeriodic(String uniqueName, String taskName, {required Duration frequency}) async {
    registeredPeriodicCount++;
  }
}

class _FakeAlarmScheduler implements AlarmScheduler {
  final List<int> cancelled = [];
  final List<int> scheduled = [];

  @override
  Future<void> scheduleExact(int slotIndex, DateTime time) async {
    scheduled.add(slotIndex);
  }

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
  late BackupService backupService;
  late FakePhotoStorageService fakePhotoStorageService;
  late _FakeNotificationSender fakeSender;
  late _FakeWorkScheduler fakeScheduler;
  late _FakeAlarmScheduler fakeAlarmScheduler;

  late CategoryRepository categoryRepository;
  late ProductRepository productRepository;
  late StockMutationRepository mutationRepository;
  late AppSettingsRepository settingsRepository;
  late CostPriceAdjustmentRepository costPriceAdjustmentRepository;
  late RestockListRepository restockListRepository;

  late Directory tempDir;

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
    backupService = BackupService(isar, photoStorageService: fakePhotoStorageService);

    settingsRepository = AppSettingsRepository(isar);
    mutationRepository = StockMutationRepository(isar);
    productRepository = ProductRepository(isar, mutationRepository, settingsRepository);
    categoryRepository = CategoryRepository(isar);
    costPriceAdjustmentRepository = CostPriceAdjustmentRepository(isar);
    restockListRepository = RestockListRepository(isar);

    tempDir = await Directory.systemTemp.createTemp('backup_test_');
  });

  tearDown(() async {
    await closeTestIsar(isar);
    await tempDir.delete(recursive: true);
  });

  Future<Category> seedCategory() => categoryRepository.create('Snacks');

  Future<Product> seedProduct({int? categoryId, String? photoPath}) {
    return productRepository.create(
      name: 'Indomie Goreng',
      categoryId: categoryId,
      sellPrice: 3000,
      unit: 'pcs',
      photoPath: photoPath,
      initialStock: 10,
    );
  }

  group('buildBackupData (export)', () {
    test('produces a map with the version envelope fields', () async {
      final data = await backupService.buildBackupData();

      expect(data['version'], backupSchemaVersion);
      expect(data['appVersion'], isA<String>());
      expect(data['exportedAt'], isA<String>());
      expect(DateTime.tryParse(data['exportedAt'] as String), isNotNull);
    });

    test('is valid, round-trippable JSON', () async {
      final data = await backupService.buildBackupData();

      final jsonString = jsonEncode(data);
      final decoded = jsonDecode(jsonString);

      expect(decoded, isA<Map>());
      expect(decoded['version'], backupSchemaVersion);
    });

    test('includes every collection key, even with no data', () async {
      final data = await backupService.buildBackupData();
      final inner = data['data'] as Map;

      expect(inner.keys, containsAll([
        'appSettings',
        'categories',
        'products',
        'mutations',
        'costPriceAdjustments',
        'restockLists',
      ]));
    });

    test('with 0 products: products array is empty but present', () async {
      final data = await backupService.buildBackupData();
      final inner = data['data'] as Map;

      expect(inner['products'], isA<List>());
      expect(inner['products'], isEmpty);
    });

    test('a product with a photo gets a populated photoBase64 field', () async {
      final photoFile = File('${tempDir.path}/photo.jpg');
      await photoFile.writeAsBytes([1, 2, 3, 4, 5]);
      final category = await seedCategory();
      await seedProduct(categoryId: category.id, photoPath: photoFile.path);

      final data = await backupService.buildBackupData();
      final products = (data['data'] as Map)['products'] as List;
      final product = products.single as Map;

      expect(product['photoBase64'], isA<String>());
      expect(product['photoBase64'], startsWith('data:image/jpeg;base64,'));
      final base64Part = (product['photoBase64'] as String).split(',').last;
      expect(base64Decode(base64Part), [1, 2, 3, 4, 5]);
    });

    test('a product with no photo has a null photoBase64 field', () async {
      final category = await seedCategory();
      await seedProduct(categoryId: category.id);

      final data = await backupService.buildBackupData();
      final products = (data['data'] as Map)['products'] as List;
      final product = products.single as Map;

      expect(product.containsKey('photoBase64'), isTrue);
      expect(product['photoBase64'], isNull);
    });

    test('exportToFile updates AppSettings.lastBackupAt', () async {
      final before = await settingsRepository.get();
      expect(before.lastBackupAt, isNull);

      await backupService.exportToFile(directory: tempDir, now: DateTime(2026, 7, 17, 10, 30));

      final after = await settingsRepository.get();
      expect(after.lastBackupAt, DateTime(2026, 7, 17, 10, 30));
    });

    test('exportToFile writes a file named with the given timestamp', () async {
      final file = await backupService.exportToFile(
        directory: tempDir,
        now: DateTime(2026, 7, 17, 10, 30, 5),
      );

      expect(file.path, endsWith('inventaris_backup_2026-07-17_10-30-05.json'));
      expect(await file.exists(), isTrue);
      final content = jsonDecode(await file.readAsString());
      expect(content['version'], backupSchemaVersion);
    });
  });

  group('validateAndParse', () {
    test('rejects invalid JSON', () async {
      await expectLater(
        backupService.validateAndParse('{not valid json'),
        throwsA(isA<BackupValidationException>().having(
          (e) => e.reason,
          'reason',
          BackupValidationFailureReason.invalidJson,
        )),
      );
    });

    test('rejects JSON without a version field', () async {
      await expectLater(
        backupService.validateAndParse(jsonEncode({'data': {}})),
        throwsA(isA<BackupValidationException>().having(
          (e) => e.reason,
          'reason',
          BackupValidationFailureReason.missingVersion,
        )),
      );
    });

    test('rejects an unsupported version', () async {
      await expectLater(
        backupService.validateAndParse(jsonEncode({'version': 99, 'data': {}})),
        throwsA(isA<BackupValidationException>().having(
          (e) => e.reason,
          'reason',
          BackupValidationFailureReason.unsupportedVersion,
        )),
      );
    });

    test('accepts a well-formed version-1 backup', () async {
      final data = await backupService.buildBackupData();
      final parsed = await backupService.validateAndParse(jsonEncode(data));

      expect(parsed['version'], backupSchemaVersion);
    });
  });

  group('importBackup', () {
    test('invalid/unvalidated data never reaches the wipe step (no data touched on validation failure)', () async {
      final category = await seedCategory();
      await seedProduct(categoryId: category.id);

      await expectLater(
        backupService.validateAndParse('not json'),
        throwsA(isA<BackupValidationException>()),
      );

      expect(await isar.products.count(), 1, reason: 'validation failure must never touch existing data');
    });

    test('restores categories, products, and mutations matching the original', () async {
      final category = await seedCategory();
      final product = await seedProduct(categoryId: category.id);
      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 3,
      );
      await costPriceAdjustmentRepository.recordAdjustment(
        productId: product.id,
        newCost: 2500,
        note: 'koreksi',
      );
      await restockListRepository.create(
        supplierName: 'Toko Grosir',
        items: [
          RestockListItemInput(
            productId: product.id,
            productName: product.name,
            qtyInPcs: 12,
            inputUnitWasPack: false,
          ),
        ],
      );

      final backup = await backupService.buildBackupData();

      // Wipe first (simulating a fresh install / prior "Hapus Semua Data").
      await isar.writeTxn(() async {
        await isar.categories.clear();
        await isar.products.clear();
        await isar.stockMutations.clear();
        await isar.costPriceAdjustments.clear();
        await isar.restockLists.clear();
      });

      await backupService.importBackup(backup);

      final restoredCategory = await isar.categories.get(category.id);
      expect(restoredCategory?.name, 'Snacks');

      final restoredProduct = await isar.products.get(product.id);
      expect(restoredProduct?.name, 'Indomie Goreng');
      expect(restoredProduct?.categoryId, category.id);
      expect(restoredProduct?.currentStock, 7); // 10 - 3

      final restoredMutations = await isar.stockMutations.filter().productIdEqualTo(product.id).findAll();
      expect(restoredMutations, hasLength(2)); // stok awal + stockOut

      final restoredAdjustments =
          await isar.costPriceAdjustments.filter().productIdEqualTo(product.id).findAll();
      expect(restoredAdjustments, hasLength(1));
      expect(restoredAdjustments.single.newCost, 2500);

      final restoredLists = await isar.restockLists.where().findAll();
      expect(restoredLists, hasLength(1));
      expect(restoredLists.single.supplierName, 'Toko Grosir');
      expect(restoredLists.single.items.single.productId, product.id);
    });

    test('a product referencing a category resolves correctly after import (category imported first)', () async {
      final category = await seedCategory();
      final product = await seedProduct(categoryId: category.id);
      final backup = await backupService.buildBackupData();

      await isar.writeTxn(() async {
        await isar.products.clear();
        await isar.categories.clear();
      });

      await backupService.importBackup(backup);

      final restoredProduct = await isar.products.get(product.id);
      final restoredCategory = await isar.categories.get(restoredProduct!.categoryId!);
      expect(restoredCategory, isNotNull);
      expect(restoredCategory!.name, 'Snacks');
    });

    test('a product with a photo: the photo is decoded and written back via PhotoStorageService', () async {
      final photoFile = File('${tempDir.path}/photo.jpg');
      await photoFile.writeAsBytes([9, 8, 7, 6]);
      final category = await seedCategory();
      await seedProduct(categoryId: category.id, photoPath: photoFile.path);

      final backup = await backupService.buildBackupData();

      await isar.writeTxn(() async {
        await isar.products.clear();
        await isar.categories.clear();
      });
      fakePhotoStorageService.writtenBytes.clear();

      await backupService.importBackup(backup);

      expect(fakePhotoStorageService.writtenBytes, hasLength(1));
      expect(fakePhotoStorageService.writtenBytes.single, [9, 8, 7, 6]);

      final restoredProduct = await isar.products.where().findFirst();
      expect(restoredProduct?.photoPath, isNotNull);
      expect(restoredProduct?.photoPath, startsWith('/fake/photos/'));
    });

    test('restore on a fresh install (no existing data) succeeds without crashing', () async {
      final backup = await backupService.buildBackupData();

      await expectLater(backupService.importBackup(backup), completes);
      expect(await isar.products.count(), 0);
    });

    test('cancels notifications before import and reschedules after', () async {
      final category = await seedCategory();
      await seedProduct(categoryId: category.id);
      final backup = await backupService.buildBackupData();

      await backupService.importBackup(backup);

      expect(fakeSender.cancelAllCallCount, 1);
      expect(fakeScheduler.registeredPeriodicCount, greaterThan(0));
    });

    test('round trip: export -> wipe -> import -> data identical to the original', () async {
      final category = await seedCategory();
      final product = await seedProduct(categoryId: category.id);
      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 4,
      );
      final settingsBefore = await settingsRepository.updateRestockLeadTimeDays(5);

      final backup = await backupService.buildBackupData();

      await isar.writeTxn(() async {
        await isar.categories.clear();
        await isar.products.clear();
        await isar.stockMutations.clear();
        await isar.appSettings.clear();
      });

      await backupService.importBackup(backup);

      final restoredProduct = await isar.products.get(product.id);
      expect(restoredProduct?.name, product.name);
      expect(restoredProduct?.currentStock, 6); // 10 - 4
      expect(restoredProduct?.sellPrice, product.sellPrice);

      final restoredCategory = await isar.categories.get(category.id);
      expect(restoredCategory?.name, category.name);

      final restoredMutations = await isar.stockMutations.filter().productIdEqualTo(product.id).findAll();
      expect(restoredMutations, hasLength(2));

      final restoredSettings = await settingsRepository.get();
      expect(restoredSettings.restockLeadTimeDays, settingsBefore.restockLeadTimeDays);
    });

    test('failed import rolls back to the original data', () async {
      final category = await seedCategory();
      final product = await seedProduct(categoryId: category.id);

      final corruptBackup = <String, dynamic>{
        'version': backupSchemaVersion,
        'data': {
          'appSettings': (await backupService.buildBackupData())['data']['appSettings'],
          'categories': [],
          'products': [
            {'id': 'not-a-valid-id-field-type'},
          ],
          'mutations': [],
          'costPriceAdjustments': [],
          'restockLists': [],
        },
      };

      await expectLater(
        backupService.importBackup(corruptBackup),
        throwsA(isA<BackupRestoreException>().having(
          (e) => e.rollbackSucceeded,
          'rollbackSucceeded',
          isTrue,
        )),
      );

      final restoredProduct = await isar.products.get(product.id);
      expect(restoredProduct, isNotNull, reason: 'rollback should have restored the original product');
      expect(restoredProduct?.name, 'Indomie Goreng');
      final restoredCategory = await isar.categories.get(category.id);
      expect(restoredCategory, isNotNull);
    });
  });
}
