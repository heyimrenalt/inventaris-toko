import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../data/models/app_settings.dart';
import '../data/models/category.dart';
import '../data/models/cost_price_adjustment.dart';
import '../data/models/product.dart';
import '../data/models/restock_list.dart';
import '../data/models/stock_mutation.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/repository_exceptions.dart';
import 'notification_service.dart';
import 'photo_storage_service.dart';

/// Schema version of the backup JSON format this app version writes and
/// reads. Bump only alongside a matching migration path in
/// [BackupService.validateAndParse]/[BackupService.importBackup] — for now
/// only version 1 exists, so any other value is rejected outright.
const backupSchemaVersion = 1;

/// Tracks [pubspec.yaml]'s `version:` field — purely informational in the
/// backup file (not used for any compatibility decision, [backupSchemaVersion]
/// is), so it isn't worth wiring up a package-info plugin just to read it
/// at runtime.
const _appVersion = '1.0.0';

/// Exports all app data (every Isar collection, plus product photos
/// embedded as base64) to a single self-contained JSON file, and restores
/// from one. See `PengaturanScreen`'s "Cadangkan Data"/"Pulihkan Data"
/// tiles for the only callers.
class BackupService {
  BackupService(this._isar, {PhotoStorageService? photoStorageService})
      : _photoStorageService = photoStorageService ?? const ImagePickerPhotoStorageService();

  final Isar _isar;
  final PhotoStorageService _photoStorageService;

  /// Builds the full backup envelope (`version`/`appVersion`/`exportedAt`/
  /// `data`) as a JSON-serializable map.
  ///
  /// [includePhotos] is `true` for a real export and for the on-disk
  /// backup file. [importBackup] also calls this with `false` to take a
  /// lightweight pre-restore snapshot: that snapshot never touches photo
  /// files (a restore's own wipe step never deletes them either — see
  /// [importBackup]), so re-encoding every photo to base64 just in case a
  /// rollback is needed would be pure waste. With photos excluded, each
  /// product's original `photoPath` is included verbatim instead, since
  /// the rollback path re-`put()`s straight back into Isar without ever
  /// decoding/writing a photo file.
  Future<Map<String, dynamic>> buildBackupData({bool includePhotos = true}) async {
    final settings = await AppSettingsRepository(_isar).get();
    final categories = await _isar.categories.where().findAll();
    final products = await _isar.products.where().findAll();
    final mutations = await _isar.stockMutations.where().findAll();
    final costPriceAdjustments = await _isar.costPriceAdjustments.where().findAll();
    final restockLists = await _isar.restockLists.where().findAll();

    final productMaps = <Map<String, dynamic>>[];
    for (final product in products) {
      productMaps.add(await _productToJson(product, includePhotos: includePhotos));
    }

    return {
      'version': backupSchemaVersion,
      'appVersion': _appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {
        'appSettings': _appSettingsToJson(settings),
        'categories': categories.map(_categoryToJson).toList(),
        'products': productMaps,
        'mutations': mutations.map(_mutationToJson).toList(),
        'costPriceAdjustments': costPriceAdjustments.map(_costPriceAdjustmentToJson).toList(),
        'restockLists': restockLists.map(_restockListToJson).toList(),
      },
    };
  }

  /// Writes a full backup (with photos) to a new file named
  /// `inventaris_backup_{yyyy-MM-dd_HH-mm-ss}.json` inside [directory], and
  /// records the export time on [AppSettings.lastBackupAt]. Returns the
  /// written [File].
  ///
  /// The final JSON stringification — the one part of a large export
  /// (hundreds of products with embedded photo base64, 50MB+) that's both
  /// synchronous and CPU-heavy enough to jank the UI thread — runs in a
  /// background isolate via [compute]. Everything before it (Isar reads,
  /// photo file reads) is normal `await`-yielding I/O and doesn't need one.
  Future<File> exportToFile({required Directory directory, DateTime? now}) async {
    final data = await buildBackupData();
    final jsonString = await compute(_jsonEncodeForCompute, data);

    final effectiveNow = now ?? DateTime.now();
    final fileName = 'inventaris_backup_${_formatFileTimestamp(effectiveNow)}.json';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(jsonString);

    await AppSettingsRepository(_isar).updateLastBackupAt(effectiveNow);

    return file;
  }

  /// Parses and validates [jsonString] as a backup file, returning the
  /// decoded envelope on success. Throws [BackupValidationException]
  /// (with a specific [BackupValidationFailureReason]) otherwise — never a
  /// raw [FormatException] — so callers can show one specific Indonesian
  /// message per failure mode.
  ///
  /// The decode itself runs via [compute] for the same ANR-avoidance
  /// reason as [exportToFile]'s encode.
  Future<Map<String, dynamic>> validateAndParse(String jsonString) async {
    Object? decoded;
    try {
      decoded = await compute(_jsonDecodeForCompute, jsonString);
    } catch (_) {
      throw BackupValidationException(BackupValidationFailureReason.invalidJson);
    }

    if (decoded is! Map || decoded['data'] is! Map) {
      throw BackupValidationException(BackupValidationFailureReason.invalidJson);
    }

    final version = decoded['version'];
    if (version == null) {
      throw BackupValidationException(BackupValidationFailureReason.missingVersion);
    }
    if (version != backupSchemaVersion) {
      throw BackupValidationException(
        BackupValidationFailureReason.unsupportedVersion,
        foundVersion: version,
      );
    }

    return decoded.cast<String, dynamic>();
  }

  /// Wipes all current data and imports [backup] (an already-[validateAndParse]d
  /// envelope) in place of it: categories, then products (photos decoded
  /// and written back to app storage), then mutations, cost-price
  /// adjustments, restock lists, and finally app settings — that order
  /// matters only in the sense that it mirrors dependency direction
  /// (products reference categories, mutations/adjustments/restock items
  /// reference products); Isar itself doesn't enforce foreign keys, so
  /// nothing actually breaks if it happened to run out of order, but
  /// keeping it dependency-first is what the "no orphan references" repo
  /// convention expects. Every record is `put()` with its original id
  /// preserved, so cross-references (`categoryId`, `productId`, `parentId`)
  /// still resolve correctly after import — Isar treats an explicit
  /// (non-[Isar.autoIncrement]) id as literal and advances its internal
  /// auto-increment counter past it.
  ///
  /// Notifications are cancelled before the wipe and rescheduled from
  /// whatever `AppSettings` ends up in place afterward (the restored
  /// settings on success, or the rolled-back original settings if the
  /// import failed and rollback succeeded).
  ///
  /// On failure partway through, attempts to roll back to the pre-restore
  /// state using a lightweight snapshot taken up front (see
  /// [buildBackupData]'s `includePhotos: false` mode — the original photo
  /// files are never touched by this method, so rollback never needs to
  /// re-decode/rewrite them). Always throws [BackupRestoreException] on
  /// any import failure, with `rollbackSucceeded` telling the caller
  /// whether the original data is safe.
  Future<void> importBackup(Map<String, dynamic> backup) async {
    final data = (backup['data'] as Map).cast<String, dynamic>();
    final rollbackSnapshot = await buildBackupData(includePhotos: false);

    await NotificationService.cancelAll();

    Object? importError;
    try {
      await _wipeAllCollections();
      await _importInto(data, useRawPhotoPath: false);
    } catch (cause) {
      importError = cause;
    }

    if (importError != null) {
      var rollbackSucceeded = false;
      try {
        final rollbackData = (rollbackSnapshot['data'] as Map).cast<String, dynamic>();
        await _wipeAllCollections();
        await _importInto(rollbackData, useRawPhotoPath: true);
        rollbackSucceeded = true;
      } catch (_) {
        rollbackSucceeded = false;
      }

      if (rollbackSucceeded) {
        await _rescheduleNotifications();
      }
      throw BackupRestoreException(rollbackSucceeded: rollbackSucceeded, cause: importError);
    }

    await _rescheduleNotifications();
  }

  Future<void> _rescheduleNotifications() async {
    final settings = await AppSettingsRepository(_isar).get();
    await NotificationService.scheduleDailySummary(settings);
    await NotificationService.scheduleCriticalStockAlerts(settings);
  }

  Future<void> _wipeAllCollections() async {
    await _isar.writeTxn(() async {
      await _isar.categories.clear();
      await _isar.products.clear();
      await _isar.stockMutations.clear();
      await _isar.appSettings.clear();
      await _isar.costPriceAdjustments.clear();
      await _isar.restockLists.clear();
    });
  }

  /// Imports one `data` map's collections into (already-wiped) Isar, in
  /// dependency order. [useRawPhotoPath] selects which of a product's two
  /// mutually-exclusive photo fields to trust — see [buildBackupData]'s
  /// doc comment on `includePhotos`.
  Future<void> _importInto(Map<String, dynamic> data, {required bool useRawPhotoPath}) async {
    final categories = _listOf(data['categories']);
    final products = _listOf(data['products']);
    final mutations = _listOf(data['mutations']);
    final costPriceAdjustments = _listOf(data['costPriceAdjustments']);
    final restockLists = _listOf(data['restockLists']);
    final appSettingsJson = data['appSettings'] as Map?;

    await _isar.writeTxn(() async {
      for (final json in categories) {
        await _isar.categories.put(_categoryFromJson(json));
      }
    });

    // Photo decode/write is real file I/O — built up front, outside any
    // writeTxn, so the transaction below is just fast Isar puts.
    final productObjects = <Product>[];
    for (final json in products) {
      productObjects.add(await _productFromJson(json, useRawPhotoPath: useRawPhotoPath));
    }
    await _isar.writeTxn(() async {
      for (final product in productObjects) {
        await _isar.products.put(product);
      }
    });

    await _isar.writeTxn(() async {
      for (final json in mutations) {
        await _isar.stockMutations.put(_mutationFromJson(json));
      }
    });

    await _isar.writeTxn(() async {
      for (final json in costPriceAdjustments) {
        await _isar.costPriceAdjustments.put(_costPriceAdjustmentFromJson(json));
      }
    });

    await _isar.writeTxn(() async {
      for (final json in restockLists) {
        await _isar.restockLists.put(_restockListFromJson(json));
      }
    });

    if (appSettingsJson != null) {
      await _isar.writeTxn(() async {
        await _isar.appSettings.put(_appSettingsFromJson(appSettingsJson.cast<String, dynamic>()));
      });
    }
  }

  List<Map<String, dynamic>> _listOf(Object? value) =>
      (value as List? ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

  Future<Map<String, dynamic>> _productToJson(Product product, {required bool includePhotos}) async {
    String? photoBase64;
    String? rawPhotoPath;

    if (includePhotos) {
      final path = product.photoPath;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final mimeType = _mimeTypeForExtension(p.extension(path));
          photoBase64 = 'data:$mimeType;base64,${base64Encode(bytes)}';
        }
      }
    } else {
      rawPhotoPath = product.photoPath;
    }

    return {
      'id': product.id,
      'name': product.name,
      'code': product.code,
      'categoryId': product.categoryId,
      'photoBase64': photoBase64,
      if (!includePhotos) 'photoPath': rawPhotoPath,
      'sellPrice': product.sellPrice,
      'unit': product.unit,
      'currentStock': product.currentStock,
      'minStockThreshold': product.minStockThreshold,
      'averageCostPrice': product.averageCostPrice,
      'createdAt': product.createdAt.toIso8601String(),
      'updatedAt': product.updatedAt.toIso8601String(),
      'isArchived': product.isArchived,
      'archivedAt': product.archivedAt?.toIso8601String(),
      'criticalStockAlertState': product.criticalStockAlertState,
      'unitsPerPack': product.unitsPerPack,
      'unitsPerDus': product.unitsPerDus,
      'lastRestockQty': product.lastRestockQty,
      'allowsFractionalQuantity': product.allowsFractionalQuantity,
    };
  }

  Future<Product> _productFromJson(Map<String, dynamic> json, {required bool useRawPhotoPath}) async {
    String? photoPath;
    if (useRawPhotoPath) {
      photoPath = json['photoPath'] as String?;
    } else {
      final photoBase64 = json['photoBase64'] as String?;
      if (photoBase64 != null) {
        photoPath = await _decodeAndSavePhoto(photoBase64);
      }
    }

    return Product()
      ..id = json['id'] as int
      ..name = json['name'] as String
      ..code = json['code'] as String?
      ..categoryId = json['categoryId'] as int?
      ..photoPath = photoPath
      ..sellPrice = (json['sellPrice'] as num).toDouble()
      ..unit = json['unit'] as String
      ..currentStock = (json['currentStock'] as num).toDouble()
      ..minStockThreshold = (json['minStockThreshold'] as num).toDouble()
      ..averageCostPrice = (json['averageCostPrice'] as num?)?.toDouble()
      ..createdAt = DateTime.parse(json['createdAt'] as String)
      ..updatedAt = DateTime.parse(json['updatedAt'] as String)
      ..isArchived = json['isArchived'] as bool? ?? false
      ..archivedAt = _parseNullableDate(json['archivedAt'])
      ..criticalStockAlertState = json['criticalStockAlertState'] as int?
      ..unitsPerPack = json['unitsPerPack'] as int?
      ..unitsPerDus = json['unitsPerDus'] as int?
      ..lastRestockQty = (json['lastRestockQty'] as num?)?.toDouble()
      ..allowsFractionalQuantity = json['allowsFractionalQuantity'] as bool? ?? false;
  }

  Future<String> _decodeAndSavePhoto(String dataUri) async {
    final commaIndex = dataUri.indexOf(',');
    final header = commaIndex >= 0 ? dataUri.substring(0, commaIndex) : '';
    final base64Part = commaIndex >= 0 ? dataUri.substring(commaIndex + 1) : dataUri;
    final bytes = base64Decode(base64Part);
    return _photoStorageService.writePhotoBytes(bytes, extension: _extensionForMimeHeader(header));
  }

  Map<String, dynamic> _categoryToJson(Category category) => {
        'id': category.id,
        'name': category.name,
        'parentId': category.parentId,
        'createdAt': category.createdAt.toIso8601String(),
      };

  Category _categoryFromJson(Map<String, dynamic> json) => Category()
    ..id = json['id'] as int
    ..name = json['name'] as String
    ..parentId = json['parentId'] as int?
    ..createdAt = DateTime.parse(json['createdAt'] as String);

  Map<String, dynamic> _mutationToJson(StockMutation mutation) => {
        'id': mutation.id,
        'productId': mutation.productId,
        'type': mutation.type.name,
        'quantity': mutation.quantity,
        'note': mutation.note,
        'stockAfter': mutation.stockAfter,
        'createdAt': mutation.createdAt.toIso8601String(),
        'enteredUnit': mutation.enteredUnit?.name,
        'enteredQuantity': mutation.enteredQuantity,
      };

  StockMutation _mutationFromJson(Map<String, dynamic> json) => StockMutation()
    ..id = json['id'] as int
    ..productId = json['productId'] as int
    ..type = StockMutationType.values.byName(json['type'] as String)
    ..quantity = (json['quantity'] as num).toDouble()
    ..note = json['note'] as String?
    ..stockAfter = (json['stockAfter'] as num).toDouble()
    ..createdAt = DateTime.parse(json['createdAt'] as String)
    ..enteredUnit = _parseNullableEnum(json['enteredUnit'], EnteredUnit.values)
    ..enteredQuantity = (json['enteredQuantity'] as num?)?.toDouble();

  Map<String, dynamic> _costPriceAdjustmentToJson(CostPriceAdjustment adjustment) => {
        'id': adjustment.id,
        'productId': adjustment.productId,
        'oldCost': adjustment.oldCost,
        'newCost': adjustment.newCost,
        'adjustedAt': adjustment.adjustedAt.toIso8601String(),
        'note': adjustment.note,
      };

  CostPriceAdjustment _costPriceAdjustmentFromJson(Map<String, dynamic> json) => CostPriceAdjustment()
    ..id = json['id'] as int
    ..productId = json['productId'] as int
    ..oldCost = (json['oldCost'] as num?)?.toDouble()
    ..newCost = (json['newCost'] as num?)?.toDouble()
    ..adjustedAt = DateTime.parse(json['adjustedAt'] as String)
    ..note = json['note'] as String?;

  Map<String, dynamic> _restockListToJson(RestockList list) => {
        'id': list.id,
        'supplierName': list.supplierName,
        'createdAt': list.createdAt.toIso8601String(),
        'completedAt': list.completedAt?.toIso8601String(),
        'items': list.items
            .map((item) => {
                  'productId': item.productId,
                  'productNameSnapshot': item.productNameSnapshot,
                  'qtyInPcs': item.qtyInPcs,
                  'inputUnitWasPack': item.inputUnitWasPack,
                  'isChecked': item.isChecked,
                })
            .toList(),
      };

  RestockList _restockListFromJson(Map<String, dynamic> json) {
    final items = _listOf(json['items']);
    return RestockList()
      ..id = json['id'] as int
      ..supplierName = json['supplierName'] as String?
      ..createdAt = DateTime.parse(json['createdAt'] as String)
      ..completedAt = _parseNullableDate(json['completedAt'])
      ..items = items
          .map((item) => RestockListItem()
            ..productId = item['productId'] as int
            ..productNameSnapshot = item['productNameSnapshot'] as String
            ..qtyInPcs = (item['qtyInPcs'] as num).toDouble()
            ..inputUnitWasPack = item['inputUnitWasPack'] as bool
            ..isChecked = item['isChecked'] as bool)
          .toList();
  }

  Map<String, dynamic> _appSettingsToJson(AppSettings settings) => {
        'defaultMinStockThreshold': settings.defaultMinStockThreshold,
        'lastBackupAt': settings.lastBackupAt?.toIso8601String(),
        'dailySummaryEnabled': settings.dailySummaryEnabled,
        'dailySummaryHour': settings.dailySummaryHour,
        'dailySummaryMinute': settings.dailySummaryMinute,
        'criticalStockAlertEnabled': settings.criticalStockAlertEnabled,
        'criticalStockAlertHour1': settings.criticalStockAlertHour1,
        'criticalStockAlertMinute1': settings.criticalStockAlertMinute1,
        'criticalStockAlertHour2': settings.criticalStockAlertHour2,
        'criticalStockAlertMinute2': settings.criticalStockAlertMinute2,
        'criticalStockAlertHour3': settings.criticalStockAlertHour3,
        'criticalStockAlertMinute3': settings.criticalStockAlertMinute3,
        'restockLeadTimeDays': settings.restockLeadTimeDays,
        'restockCoverDays': settings.restockCoverDays,
        'batteryOptimizationDialogDismissed': settings.batteryOptimizationDialogDismissed,
      };

  AppSettings _appSettingsFromJson(Map<String, dynamic> json) => AppSettings()
    ..id = 0
    ..defaultMinStockThreshold = (json['defaultMinStockThreshold'] as num).toDouble()
    ..lastBackupAt = _parseNullableDate(json['lastBackupAt'])
    ..dailySummaryEnabled = json['dailySummaryEnabled'] as bool
    ..dailySummaryHour = json['dailySummaryHour'] as int
    ..dailySummaryMinute = json['dailySummaryMinute'] as int
    ..criticalStockAlertEnabled = json['criticalStockAlertEnabled'] as bool
    ..criticalStockAlertHour1 = json['criticalStockAlertHour1'] as int
    ..criticalStockAlertMinute1 = json['criticalStockAlertMinute1'] as int
    ..criticalStockAlertHour2 = json['criticalStockAlertHour2'] as int?
    ..criticalStockAlertMinute2 = json['criticalStockAlertMinute2'] as int?
    ..criticalStockAlertHour3 = json['criticalStockAlertHour3'] as int?
    ..criticalStockAlertMinute3 = json['criticalStockAlertMinute3'] as int?
    ..restockLeadTimeDays = json['restockLeadTimeDays'] as int
    ..restockCoverDays = json['restockCoverDays'] as int
    ..batteryOptimizationDialogDismissed = json['batteryOptimizationDialogDismissed'] as bool;

  DateTime? _parseNullableDate(Object? value) => value == null ? null : DateTime.parse(value as String);

  T? _parseNullableEnum<T extends Enum>(Object? value, List<T> values) =>
      value == null ? null : values.byName(value as String);

  String _mimeTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _extensionForMimeHeader(String header) {
    if (header.contains('image/png')) return '.png';
    if (header.contains('image/webp')) return '.webp';
    return '.jpg';
  }

  String _formatFileTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}_${two(dt.hour)}-${two(dt.minute)}-${two(dt.second)}';
  }
}

String _jsonEncodeForCompute(Map<String, dynamic> data) => jsonEncode(data);

Object? _jsonDecodeForCompute(String source) => jsonDecode(source);
