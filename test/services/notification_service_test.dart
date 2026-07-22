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

  @override
  Future<void> cancelAllNotifications() async {
    cancelAllCallCount++;
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

class _FakeAlarmScheduler implements AlarmScheduler {
  final List<({int slotIndex, DateTime time})> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> scheduleExact(int slotIndex, DateTime time) async {
    scheduled.add((slotIndex: slotIndex, time: time));
  }

  @override
  Future<void> cancel(int slotIndex) async {
    cancelled.add(slotIndex);
  }
}

class _FakeExactAlarmPermission implements ExactAlarmPermission {
  bool canSchedule = true;
  int requestCount = 0;

  @override
  Future<bool> canScheduleExactAlarms() async => canSchedule;

  @override
  Future<void> requestExactAlarmsPermission() async {
    requestCount++;
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
  late _FakeAlarmScheduler fakeAlarmScheduler;
  late _FakeExactAlarmPermission fakeExactAlarmPermission;

  setUp(() {
    fakeSender = _FakeNotificationSender();
    fakeScheduler = _FakeWorkScheduler();
    fakeAlarmScheduler = _FakeAlarmScheduler();
    fakeExactAlarmPermission = _FakeExactAlarmPermission();
    NotificationService.sender = fakeSender;
    NotificationService.scheduler = fakeScheduler;
    NotificationService.alarmScheduler = fakeAlarmScheduler;
    NotificationService.exactAlarmPermission = fakeExactAlarmPermission;
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

  group('criticalStockAlertNotificationId', () {
    test('is deterministic and distinct per slot', () {
      final ids = [for (var slot = 0; slot < 3; slot++) criticalStockAlertNotificationId(slot)];

      expect(ids.toSet(), hasLength(3), reason: 'each slot must get its own notification ID');
      expect(criticalStockAlertNotificationId(0), criticalStockAlertNotificationId(0));
    });
  });

  group('scheduleCriticalStockAlerts', () {
    late Isar isar;
    late AppSettingsRepository settingsRepository;

    setUp(() async {
      isar = await openTestIsar();
      settingsRepository = AppSettingsRepository(isar);
    });

    tearDown(() async {
      await closeTestIsar(isar);
    });

    test('cancels every slot before scheduling, so a shrunk slot list leaves no stale alarm', () async {
      var settings = await settingsRepository.updateCriticalStockAlertSlots([
        (hour: 9, minute: 0),
        (hour: 13, minute: 0),
        (hour: 18, minute: 0),
      ]);
      await NotificationService.scheduleCriticalStockAlerts(settings, now: DateTime(2026, 1, 1, 8));
      expect(fakeAlarmScheduler.scheduled, hasLength(3));

      fakeAlarmScheduler.scheduled.clear();
      fakeAlarmScheduler.cancelled.clear();
      settings = await settingsRepository.updateCriticalStockAlertSlots([(hour: 9, minute: 0)]);
      await NotificationService.scheduleCriticalStockAlerts(settings, now: DateTime(2026, 1, 1, 8));

      // All 3 possible slots are canceled up front (no leaked stale IDs)...
      expect(fakeAlarmScheduler.cancelled, containsAll([0, 1, 2]));
      // ...and only the one remaining slot is re-armed.
      expect(fakeAlarmScheduler.scheduled, hasLength(1));
      expect(fakeAlarmScheduler.scheduled.single.slotIndex, 0);
    });

    test('canceling one slot does not remove another (fake scheduler cancels by slot index)', () async {
      await fakeAlarmScheduler.cancel(1);

      expect(fakeAlarmScheduler.cancelled, [1]);
      expect(fakeAlarmScheduler.cancelled, isNot(contains(0)));
      expect(fakeAlarmScheduler.cancelled, isNot(contains(2)));
    });

    test('3 configured slots produce 3 distinct alarm schedule calls', () async {
      final settings = await settingsRepository.updateCriticalStockAlertSlots([
        (hour: 9, minute: 0),
        (hour: 13, minute: 0),
        (hour: 18, minute: 0),
      ]);

      await NotificationService.scheduleCriticalStockAlerts(settings, now: DateTime(2026, 1, 1, 8));

      expect(fakeAlarmScheduler.scheduled.map((s) => s.slotIndex).toSet(), {0, 1, 2});
    });

    test('a slot time already past today is scheduled for tomorrow, not immediately or skipped', () async {
      final settings = await settingsRepository.updateCriticalStockAlertSlots([(hour: 8, minute: 0)]);
      final now = DateTime(2026, 1, 1, 9, 0); // 09:00, slot is 08:00 -> already passed

      await NotificationService.scheduleCriticalStockAlerts(settings, now: now);

      expect(fakeAlarmScheduler.scheduled, hasLength(1));
      final scheduledTime = fakeAlarmScheduler.scheduled.single.time;
      expect(scheduledTime, DateTime(2026, 1, 2, 8, 0));
    });

    test('a slot time still ahead today is scheduled for today', () async {
      final settings = await settingsRepository.updateCriticalStockAlertSlots([(hour: 20, minute: 0)]);
      final now = DateTime(2026, 1, 1, 9, 0);

      await NotificationService.scheduleCriticalStockAlerts(settings, now: now);

      expect(fakeAlarmScheduler.scheduled.single.time, DateTime(2026, 1, 1, 20, 0));
    });

    test('disabling the feature cancels every slot and schedules nothing', () async {
      var settings = await settingsRepository.updateCriticalStockAlertSlots([(hour: 9, minute: 0)]);
      await NotificationService.scheduleCriticalStockAlerts(settings, now: DateTime(2026, 1, 1, 8));
      fakeAlarmScheduler.scheduled.clear();

      settings = await settingsRepository.updateCriticalStockAlertEnabled(false);
      await NotificationService.scheduleCriticalStockAlerts(settings, now: DateTime(2026, 1, 1, 8));

      expect(fakeAlarmScheduler.scheduled, isEmpty);
      expect(fakeAlarmScheduler.cancelled, containsAll([0, 1, 2]));
    });
  });

  group('cancelAll', () {
    test('cancels the daily-summary task, every critical-stock alarm slot, and the notification tray', () async {
      await NotificationService.cancelAll();

      expect(fakeScheduler.cancelled, contains('dailySummaryTask'));
      expect(fakeAlarmScheduler.cancelled, containsAll([0, 1, 2]));
      expect(fakeSender.cancelAllCallCount, 1);
    });
  });

  group('exact-alarm scheduling mode', () {
    test('every critical-stock slot alarm uses exact + allowWhileIdle (fixes the Doze-deferral delay)', () {
      expect(criticalStockAlarmExact, isTrue);
      expect(criticalStockAlarmAllowWhileIdle, isTrue);
      expect(criticalStockAlarmWakeup, isTrue);
      expect(criticalStockAlarmRescheduleOnReboot, isTrue);
    });
  });

  group('executeCriticalStockAlertSlot', () {
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

    test('sends nothing when criticalStockAlertEnabled is false', () async {
      await createCriticalProduct('Indomie Goreng');
      await settingsRepository.updateCriticalStockAlertEnabled(false);

      await NotificationService.executeCriticalStockAlertSlot(isar, 0);

      expect(fakeSender.calls, isEmpty);
    });

    test('sends nothing when no product is currently critical', () async {
      await NotificationService.executeCriticalStockAlertSlot(isar, 0);

      expect(fakeSender.calls, isEmpty);
    });

    test('sends one combined alert for every currently-critical product, using the slot\'s own ID', () async {
      await createCriticalProduct('Indomie Goreng');

      await NotificationService.executeCriticalStockAlertSlot(isar, 1);

      expect(fakeSender.calls, hasLength(1));
      final sent = fakeSender.calls.single;
      expect(sent.id, criticalStockAlertNotificationId(1));
      expect(sent.body, '⚠️ Stok kritis: Indomie Goreng habis — segera kulakan');
      expect(sent.channelId, stockCriticalChannelId);
      expect(sent.highImportance, isTrue);
    });

    test('a different slot firing afterward re-alerts on the same still-critical product', () async {
      await createCriticalProduct('Indomie Goreng');

      await NotificationService.executeCriticalStockAlertSlot(isar, 0);
      await NotificationService.executeCriticalStockAlertSlot(isar, 1);

      expect(fakeSender.calls, hasLength(2));
      expect(fakeSender.calls[0].id, criticalStockAlertNotificationId(0));
      expect(fakeSender.calls[1].id, criticalStockAlertNotificationId(1));
      expect(fakeSender.calls[0].body, fakeSender.calls[1].body);
    });

    test('the same slot firing twice in a row (e.g. the daily re-arm landing early) sends again while still critical',
        () async {
      await createCriticalProduct('Indomie Goreng');

      await NotificationService.executeCriticalStockAlertSlot(isar, 0);
      await NotificationService.executeCriticalStockAlertSlot(isar, 0);

      expect(fakeSender.calls, hasLength(2));
    });

    test('a product that recovers above the threshold is excluded from the next slot', () async {
      final product = await createCriticalProduct('Indomie Goreng');
      await NotificationService.executeCriticalStockAlertSlot(isar, 0);
      expect(fakeSender.calls, hasLength(1));

      await mutationRepository.recordMutation(
        productId: product.id,
        type: StockMutationType.stockIn,
        quantity: 10,
      );

      await NotificationService.executeCriticalStockAlertSlot(isar, 1);

      expect(fakeSender.calls, hasLength(1), reason: 'no longer critical, so slot 1 has nothing to send');
    });

    test('an archived product is excluded even if still under threshold', () async {
      final product = await createCriticalProduct('Indomie Goreng');
      await productRepository.archive(product.id);

      await NotificationService.executeCriticalStockAlertSlot(isar, 0);

      expect(fakeSender.calls, isEmpty);
    });
  });

  group('exact-alarm permission', () {
    test('canScheduleExactAlarms reflects the injected permission state', () async {
      fakeExactAlarmPermission.canSchedule = false;
      expect(await NotificationService.canScheduleExactAlarms(), isFalse);

      fakeExactAlarmPermission.canSchedule = true;
      expect(await NotificationService.canScheduleExactAlarms(), isTrue);
    });

    test('requestExactAlarmsPermission delegates to the injected permission seam', () async {
      await NotificationService.requestExactAlarmsPermission();

      expect(fakeExactAlarmPermission.requestCount, 1);
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
      // That single mutation already leaves dailyVelocity high enough
      // relative to the remaining currentStock (5) that estimatedDays
      // lands within the yellow/red band, i.e. urgency != neutral — so
      // this product counts toward "perlu dikulak" with no further setup.
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
