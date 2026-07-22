import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/app_settings.dart';
import 'package:inventaris_toko/data/models/category.dart';
import 'package:inventaris_toko/data/models/cost_price_adjustment.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/data/models/restock_list.dart';
import 'package:inventaris_toko/data/models/stock_mutation.dart';
import 'package:isar_community/isar.dart';

/// One-off check (not part of the regular suite's regression coverage —
/// see restock_list_repository_test.dart / product_repository_test.dart
/// for that): opens a DB written with the pre-Task-C schema (no
/// RestockList collection, no Product.unitsPerPack/lastRestockQty), then
/// reopens the same directory with the new schema and confirms the
/// existing product survives with no data loss and both new fields null.
void main() {
  test('reopening an old-schema DB with the new schema loses no data', () async {
    await Isar.initializeIsarCore(download: true);
    final dir = await Directory.systemTemp.createTemp('isar_migration_');

    final oldIsar = await Isar.open(
      [CategorySchema, ProductSchema, StockMutationSchema, AppSettingsSchema, CostPriceAdjustmentSchema],
      directory: dir.path,
      name: 'migration_test',
    );
    await oldIsar.writeTxn(() async {
      final p = Product()
        ..name = 'Existing Product'
        ..sellPrice = 1000
        ..unit = 'pcs'
        ..currentStock = 5
        ..minStockThreshold = 2
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      await oldIsar.products.put(p);
    });
    await oldIsar.close();

    final newIsar = await Isar.open(
      [
        CategorySchema,
        ProductSchema,
        StockMutationSchema,
        AppSettingsSchema,
        CostPriceAdjustmentSchema,
        RestockListSchema,
      ],
      directory: dir.path,
      name: 'migration_test',
    );

    final products = await newIsar.products.where().findAll();
    expect(products, hasLength(1));
    expect(products.first.name, 'Existing Product');
    expect(products.first.currentStock, 5);
    expect(products.first.unitsPerPack, isNull);
    expect(products.first.lastRestockQty, isNull);
    // Confirms the reasoning documented on Product.allowsFractionalQuantity:
    // Isar's binary reader returns `false` — not this field's own Dart
    // default — for any property missing from an already-stored record,
    // so a pre-existing product silently and correctly becomes "whole
    // units only" the moment this field ships.
    expect(products.first.allowsFractionalQuantity, isFalse);
    expect(products.first.unitsPerDus, isNull);

    await newIsar.close(deleteFromDisk: true);
  });
}
