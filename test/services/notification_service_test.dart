import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/repositories/app_settings_repository.dart';
import 'package:inventaris_toko/data/repositories/category_repository.dart';
import 'package:inventaris_toko/data/repositories/product_repository.dart';
import 'package:inventaris_toko/data/repositories/stock_mutation_repository.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:inventaris_toko/services/notification_service.dart';
import 'package:isar_community/isar.dart';

import '../data/repositories/test_isar.dart';

class _FakeNotificationSender implements NotificationSender {
  final List<_SentNotification> calls = [];

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
  }) async {
    calls.add(_SentNotification(
      id: id,
      title: title,
      body: body,
      channelId: channelId,
      highImportance: highImportance,
      payload: payload,
    ));
  }
}

class _SentNotification {
  _SentNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.channelId,
    required this.highImportance,
    this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String channelId;
  final bool highImportance;
  final String? payload;
}

class _FakeWorkScheduler implements WorkScheduler {
  final List<String> registeredPeriodic = [];
  final List<String> registeredOneOff = [];
  final List<String> cancelled = [];

  @override
  Future<void> cancel(String uniqueName) async {
    cancelled.add(uniqueName);
  }

  @override
  Future<void> registerOneOff(String uniqueName, String taskName, {required Duration initialDelay}) async {
    registeredOneOff.add(uniqueName);
  }

  @override
  Future<void> registerPeriodic(String uniqueName, String taskName, {required Duration frequency}) async {
    registeredPeriodic.add(uniqueName);
  }
}

Product _buildProduct({required int id, required String name}) {
  final now = DateTime.now();
  return Product()
    ..id = id
    ..name = name
    ..sellPrice = 1000
    ..unit = 'pcs'
    ..currentStock = 0
    ..minStockThreshold = 5
    ..createdAt = now
    ..updatedAt = now;
}

void main() {
  late _FakeNotificationSender fakeSender;
  late _FakeWorkScheduler fakeScheduler;

  setUp(() {
    fakeSender = _FakeNotificationSender();
    fakeScheduler = _FakeWorkScheduler();
    NotificationService.sender = fakeSender;
    NotificationService.scheduler = fakeScheduler;
  });

  group('isWithinNotificationWindow', () {
    test('boundary values around the configured target time', () {
      final target = DateTime(2026, 1, 1, 20, 0);

      expect(NotificationService.isWithinNotificationWindow(target, 20, 0), isTrue);
      expect(
        NotificationService.isWithinNotificationWindow(
          target.add(const Duration(minutes: 30)),
          20,
          0,
        ),
        isTrue,
      );
      expect(
        NotificationService.isWithinNotificationWindow(
          target.subtract(const Duration(minutes: 30)),
          20,
          0,
        ),
        isTrue,
      );
      expect(
        NotificationService.isWithinNotificationWindow(
          target.add(const Duration(minutes: 31)),
          20,
          0,
        ),
        isFalse,
      );
      expect(
        NotificationService.isWithinNotificationWindow(
          target.subtract(const Duration(minutes: 31)),
          20,
          0,
        ),
        isFalse,
      );
    });
  });

  group('buildCriticalStockAlertBody', () {
    test('single product uses the singular template', () {
      final product = _buildProduct(id: 7, name: 'Indomie Goreng');

      expect(
        NotificationService.buildCriticalStockAlertBody([product]),
        '⚠️ Stok kritis: Indomie Goreng habis — segera kulakan',
      );
    });

    test('multiple products lists every name in the plural template', () {
      final products = [
        _buildProduct(id: 1, name: 'Buku'),
        _buildProduct(id: 2, name: 'Pulpen'),
        _buildProduct(id: 3, name: 'Pensil'),
      ];

      expect(
        NotificationService.buildCriticalStockAlertBody(products),
        '⚠️ 3 barang stok kritis: Buku, Pulpen, Pensil — segera kulakan',
      );
    });
  });

  group('executeCriticalStockAlertTask', () {
    late Isar isar;
    late AppSettingsRepository settingsRepository;
    late StockMutationRepository mutationRepository;
    late ProductRepository productRepository;

    setUp(() async {
      isar = await openTestIsar();
      settingsRepository = AppSettingsRepository(isar);
      mutationRepository = StockMutationRepository(isar);
      productRepository = ProductRepository(isar, mutationRepository, settingsRepository);
    });

    tearDown(() async {
      await closeTestIsar(isar);
    });

    Future<Product> createCriticalProduct(String name) async {
      final product = await productRepository.create(
        name: name,
        sellPrice: 1000,
        unit: 'pcs',
        initialStock: 5,
        minStockThreshold: 5,
      );
      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );
      return product;
    }

    test('returns early without sending anything when criticalStockAlertEnabled is false', () async {
      await createCriticalProduct('Indomie Goreng');
      await settingsRepository.updateCriticalStockAlertEnabled(false);

      await NotificationService.executeCriticalStockAlertTask(isar, now: DateTime.now());

      expect(fakeSender.calls, isEmpty);
    });

    test('sends nothing when no configured slot is due', () async {
      await createCriticalProduct('Indomie Goreng');
      final now = DateTime.now();
      final farHour = (now.hour + 6) % 24;
      await settingsRepository.updateCriticalStockAlertSlots([(hour: farHour, minute: 0)]);

      await NotificationService.executeCriticalStockAlertTask(isar, now: now);

      expect(fakeSender.calls, isEmpty);
    });

    test('sends nothing when a slot is due but the queue is empty', () async {
      final now = DateTime.now();
      await settingsRepository.updateCriticalStockAlertSlots([(hour: now.hour, minute: now.minute)]);

      await NotificationService.executeCriticalStockAlertTask(isar, now: now);

      expect(fakeSender.calls, isEmpty);
    });

    test('a due slot sends one combined alert for every queued product and marks them notified',
        () async {
      final now = DateTime.now();
      await settingsRepository.updateCriticalStockAlertSlots([(hour: now.hour, minute: now.minute)]);
      final product = await createCriticalProduct('Indomie Goreng');

      await NotificationService.executeCriticalStockAlertTask(isar, now: now);

      expect(fakeSender.calls, hasLength(1));
      final sent = fakeSender.calls.single;
      expect(sent.body, '⚠️ Stok kritis: Indomie Goreng habis — segera kulakan');
      expect(sent.channelId, stockCriticalChannelId);
      expect(sent.highImportance, isTrue);

      final updated = await isar.products.get(product.id);
      expect(updated!.criticalStockAlertState, criticalStockAlertStateNotified);
    });

    test('a second due slot the same day does not re-notify an already-notified product',
        () async {
      final now = DateTime.now();
      await settingsRepository.updateCriticalStockAlertSlots([(hour: now.hour, minute: now.minute)]);
      await createCriticalProduct('Indomie Goreng');

      await NotificationService.executeCriticalStockAlertTask(isar, now: now);
      expect(fakeSender.calls, hasLength(1));

      // Same window fires again (e.g. two periodic ticks land in it) —
      // nothing new is queued, so nothing new is sent.
      await NotificationService.executeCriticalStockAlertTask(isar, now: now);
      expect(fakeSender.calls, hasLength(1));
    });

    test('a product that recovers above the threshold and drops again is treated as a new episode',
        () async {
      final now = DateTime.now();
      await settingsRepository.updateCriticalStockAlertSlots([(hour: now.hour, minute: now.minute)]);
      final product = await createCriticalProduct('Indomie Goreng');

      await NotificationService.executeCriticalStockAlertTask(isar, now: now);
      expect(fakeSender.calls, hasLength(1));

      // Recovers above the threshold, then drops critical again.
      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 10,
      );
      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 10,
      );

      await NotificationService.executeCriticalStockAlertTask(isar, now: now);

      expect(fakeSender.calls, hasLength(2));
      expect(fakeSender.calls.last.body, '⚠️ Stok kritis: Indomie Goreng habis — segera kulakan');
    });
  });

  group('executeDailySummaryTask', () {
    late Isar isar;
    late AppSettingsRepository settingsRepository;
    late StockMutationRepository mutationRepository;
    late ProductRepository productRepository;

    setUp(() async {
      isar = await openTestIsar();
      settingsRepository = AppSettingsRepository(isar);
      mutationRepository = StockMutationRepository(isar);
      productRepository = ProductRepository(isar, mutationRepository, settingsRepository);
    });

    tearDown(() async {
      await closeTestIsar(isar);
    });

    test('returns early without sending anything when dailySummaryEnabled is false', () async {
      await settingsRepository.updateDailySummaryEnabled(false);

      await NotificationService.executeDailySummaryTask(isar, now: DateTime.now());

      expect(fakeSender.calls, isEmpty);
    });

    test('calculates today\'s stockOut total and perlu-kulakan count', () async {
      final now = DateTime.now();
      await settingsRepository.updateDailySummaryTime(hour: now.hour, minute: now.minute);

      final category = await CategoryRepository(isar).create('Snacks');
      final product = await productRepository.create(
        name: 'Indomie Goreng',
        categoryId: category.id,
        sellPrice: 3000,
        unit: 'pcs',
        initialStock: 10,
      );
      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockOut,
        quantity: 5,
      );

      await NotificationService.executeDailySummaryTask(isar, now: now);

      expect(fakeSender.calls, hasLength(1));
      final sent = fakeSender.calls.single;
      expect(sent.body, '5 barang terjual hari ini · 1 barang perlu dikulak segera');
      expect(sent.channelId, dailySummaryChannelId);
      expect(sent.highImportance, isFalse);
    });

    test('generates the "Tidak ada aktivitas" body when both counts are 0', () async {
      final now = DateTime.now();
      await settingsRepository.updateDailySummaryTime(hour: now.hour, minute: now.minute);

      await NotificationService.executeDailySummaryTask(isar, now: now);

      expect(fakeSender.calls, hasLength(1));
      expect(
        fakeSender.calls.single.body,
        'Tidak ada aktivitas hari ini · Stok aman semua 👍',
      );
    });

    test('reschedules a retry instead of sending when run outside the notification window', () async {
      final now = DateTime.now();
      // Configured for a time far away from "now" on the same day.
      final farHour = (now.hour + 6) % 24;
      await settingsRepository.updateDailySummaryTime(hour: farHour, minute: 0);

      await NotificationService.executeDailySummaryTask(isar, now: now);

      expect(fakeSender.calls, isEmpty);
      expect(fakeScheduler.registeredOneOff, isNotEmpty);
    });
  });
}
