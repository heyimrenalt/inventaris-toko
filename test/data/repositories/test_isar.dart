import 'dart:io';

import 'package:inventaris_toko/data/models/app_settings.dart';
import 'package:inventaris_toko/data/models/category.dart';
import 'package:inventaris_toko/data/models/cost_price_adjustment.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/restock_list.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:isar_community/isar.dart';

bool _coreInitialized = false;

/// Opens a throwaway Isar instance backed by a fresh temp directory, so
/// each test gets an isolated database. Isar (embedded, file-backed) has
/// no pure in-memory mode; this is the standard pattern for its tests.
Future<Isar> openTestIsar() async {
  if (!_coreInitialized) {
    // `flutter test` runs on the host VM, not inside an app bundle, so
    // the native isar library isn't already on the process's library
    // search path the way it would be in a real app. This downloads
    // (and caches) the right binary for the host platform once per test
    // run, per the isar_community testing docs.
    await Isar.initializeIsarCore(download: true);
    _coreInitialized = true;
  }

  final dir = await Directory.systemTemp.createTemp('isar_test_');
  return Isar.open(
    [
      CategorySchema,
      ProductSchema,
      StockMutationSchema,
      AppSettingsSchema,
      CostPriceAdjustmentSchema,
      RestockListSchema,
    ],
    directory: dir.path,
    name: 'test_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(dir)}',
  );
}

Future<void> closeTestIsar(Isar isar) async {
  await isar.close(deleteFromDisk: true);
}
