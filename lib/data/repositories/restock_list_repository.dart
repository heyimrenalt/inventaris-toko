import 'package:isar_community/isar.dart';

import '../models/product.dart';
import '../models/restock_list.dart';
import 'repository_exceptions.dart';

/// One row to seed a new [RestockList] with — see [RestockListRepository.create].
class RestockListItemInput {
  RestockListItemInput({
    required this.productId,
    required this.productName,
    required this.qtyInPcs,
    required this.inputUnitWasPack,
    this.isChecked = false,
  });

  final int productId;

  /// Snapshotted onto [RestockListItem.productNameSnapshot] — see its doc
  /// comment for why.
  final String productName;
  final double qtyInPcs;
  final bool inputUnitWasPack;

  /// Whether this item should start checked on the new list. Defaults to
  /// `false` (a bare new list starts with nothing bought yet) — a caller
  /// building a list from an already-checked selection (see
  /// `PrioritasKulakanScreen._buatDaftarKulakan`) passes `true` so that
  /// selection survives onto the new list instead of being silently
  /// discarded.
  final bool isChecked;
}

/// Manages kulakan (restock) shopping lists.
///
/// A [RestockList] is a pure shopping list: it never reads or writes
/// [Product.currentStock]. Stock only ever changes through
/// `StockMutationRepository.recordMutation`, driven manually from Tab
/// Mutasi once the user actually receives goods — a user may only buy
/// part of a list, and cost price varies per batch, so auto-incrementing
/// stock from a shopping list would corrupt the weighted-average HPP.
///
/// The one thing this repository does write onto [Product] is
/// [Product.lastRestockQty], and only for items checked off (actually
/// bought) at [complete] time.
class RestockListRepository {
  RestockListRepository(this._isar);

  final Isar _isar;

  Future<RestockList> create({
    String? supplierName,
    required List<RestockListItemInput> items,
  }) async {
    final list = RestockList()
      ..supplierName = _normalizeSupplierName(supplierName)
      ..createdAt = DateTime.now()
      ..items = items
          .map((input) => RestockListItem()
            ..productId = input.productId
            ..productNameSnapshot = input.productName
            ..qtyInPcs = input.qtyInPcs
            ..inputUnitWasPack = input.inputUnitWasPack
            ..isChecked = input.isChecked)
          .toList();

    await _isar.writeTxn(() => _isar.restockLists.put(list));
    return list;
  }

  Future<RestockList?> getById(int id) => _isar.restockLists.get(id);

  Future<List<RestockList>> getActive() =>
      _isar.restockLists.filter().completedAtIsNull().sortByCreatedAtDesc().findAll();

  Future<List<RestockList>> getAll() =>
      _isar.restockLists.where().sortByCreatedAtDesc().findAll();

  Future<RestockList> updateSupplierName(int id, String? supplierName) async {
    final list = await _requireList(id);
    list.supplierName = _normalizeSupplierName(supplierName);
    await _isar.writeTxn(() => _isar.restockLists.put(list));
    return list;
  }

  Future<RestockList> updateItemQty({
    required int listId,
    required int productId,
    required double qtyInPcs,
    required bool inputUnitWasPack,
  }) async {
    final list = await _requireList(listId);
    final item = _requireItem(list, productId);

    // Validate: reject fractional quantities for non-fractional units (pcs/pack/dus)
    final product = await _isar.products.get(productId);
    if (product != null && !product.allowsFractionalQuantity) {
      // For non-fractional products, round to nearest integer to prevent decimals
      final roundedQty = qtyInPcs.roundToDouble();
      item.qtyInPcs = roundedQty;
    } else {
      item.qtyInPcs = qtyInPcs;
    }

    item.inputUnitWasPack = inputUnitWasPack;
    await _isar.writeTxn(() => _isar.restockLists.put(list));
    return list;
  }

  Future<RestockList> toggleChecked(int listId, int productId) async {
    final list = await _requireList(listId);
    final item = _requireItem(list, productId);
    item.isChecked = !item.isChecked;
    await _isar.writeTxn(() => _isar.restockLists.put(list));
    return list;
  }

  /// Marks the list completed and writes every checked item's [qtyInPcs]
  /// into that product's [Product.lastRestockQty] — the reference
  /// quantity offered as a prefill next time. Unchecked items (still in
  /// the list, but not actually bought this trip) are left alone: writing
  /// their quantity would prefill a future list with something that
  /// never actually happened.
  Future<RestockList> complete(int id) async {
    final list = await _requireList(id);
    list.completedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.restockLists.put(list);
      for (final item in list.items) {
        if (!item.isChecked) continue;
        final product = await _isar.products.get(item.productId);
        if (product == null) continue;
        product.lastRestockQty = item.qtyInPcs;
        await _isar.products.put(product);
      }
    });

    return list;
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.restockLists.delete(id));
  }

  Future<RestockList> _requireList(int id) async {
    final list = await _isar.restockLists.get(id);
    if (list == null) {
      throw NotFoundException('RestockList $id not found');
    }
    return list;
  }

  RestockListItem _requireItem(RestockList list, int productId) {
    for (final item in list.items) {
      if (item.productId == productId) return item;
    }
    throw NotFoundException('RestockListItem for product $productId not found in list ${list.id}');
  }

  String? _normalizeSupplierName(String? name) {
    final trimmed = name?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
