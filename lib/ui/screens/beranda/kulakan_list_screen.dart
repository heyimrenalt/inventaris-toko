import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../../data/models/product.dart';
import '../../../data/models/restock_list.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/restock_list_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/unit_conversion.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/restock_qty_field.dart';

/// A persisted kulakan (restock) shopping list for one store/supplier —
/// header (store name), one row per product with an editable pack/pcs
/// quantity, share-to-WhatsApp, and "Selesai" to write checked items'
/// quantities back into [Product.lastRestockQty].
///
/// This screen is a pure shopping list: it never touches
/// [Product.currentStock]. See [RestockListRepository] for why.
class KulakanListScreen extends StatefulWidget {
  const KulakanListScreen({super.key, required this.isar, required this.restockListId});

  final Isar isar;
  final int restockListId;

  @override
  State<KulakanListScreen> createState() => _KulakanListScreenState();
}

class _KulakanListScreenState extends State<KulakanListScreen> {
  late final RestockListRepository _restockListRepository = RestockListRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    StockMutationRepository(widget.isar),
    AppSettingsRepository(widget.isar),
  );
  late final CategoryRepository _categoryRepository = CategoryRepository(widget.isar);
  late final TextEditingController _supplierController;

  RestockList? _list;
  Map<int, Product> _productsById = {};
  Map<int, Category> _categoriesById = {};
  bool _loading = true;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _supplierController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _restockListRepository.getById(widget.restockListId);
    if (list == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Products referenced by a list item may since have been hard-deleted
    // — getById returning null for those is expected, not an error; see
    // _buildRow's "(dihapus)" handling. Still-archived products are
    // returned normally (ProductRepository.getById doesn't filter by
    // isArchived), so those are distinguished by product.isArchived
    // instead.
    final productsById = <int, Product>{};
    for (final item in list.items) {
      final product = await _productRepository.getById(item.productId);
      if (product != null) productsById[item.productId] = product;
    }

    final categories = await _categoryRepository.getAll();
    final categoriesById = {for (final category in categories) category.id: category};

    if (!mounted) return;
    setState(() {
      _list = list;
      _productsById = productsById;
      _categoriesById = categoriesById;
      _supplierController.text = list.supplierName ?? '';
      _loading = false;
    });
  }

  Future<void> _onSupplierNameChanged(String value) async {
    await _restockListRepository.updateSupplierName(widget.restockListId, value);
    setState(() => _list?.supplierName = value.trim().isEmpty ? null : value.trim());
  }

  Future<void> _onQtyChanged(int productId, double qtyInPcs, bool inputUnitWasPack) async {
    await _restockListRepository.updateItemQty(
      listId: widget.restockListId,
      productId: productId,
      qtyInPcs: qtyInPcs,
      inputUnitWasPack: inputUnitWasPack,
    );
    final item = _list?.items.where((i) => i.productId == productId).firstOrNull;
    item?.qtyInPcs = qtyInPcs;
    item?.inputUnitWasPack = inputUnitWasPack;
  }

  Future<void> _toggleChecked(int productId) async {
    await _restockListRepository.toggleChecked(widget.restockListId, productId);
    final item = _list?.items.where((i) => i.productId == productId).firstOrNull;
    if (item == null) return;
    setState(() => item.isChecked = !item.isChecked);
  }

  Future<void> _shareToWhatsApp() async {
    final list = _list;
    if (list == null) return;
    final text = buildKulakanListShareText(
      list: list,
      productsById: _productsById,
      categoriesById: _categoriesById,
    );
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Same plain-text format as [_shareToWhatsApp] (both must always match
  /// — see [buildKulakanListShareText]), copied to the system clipboard
  /// instead of opened in the share sheet. Safe to invoke repeatedly in a
  /// row (e.g. a rapid double-tap): each call is an independent
  /// read-then-write with no shared mutable state, so it's naturally
  /// idempotent — the clipboard just gets overwritten with the same text
  /// and another identical SnackBar is queued, no crash.
  Future<void> _copyToClipboard() async {
    final list = _list;
    if (list == null) return;
    final text = buildKulakanListShareText(
      list: list,
      productsById: _productsById,
      categoriesById: _categoriesById,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppSnack.info(context, 'Daftar kulakan disalin ke clipboard');
  }

  Future<void> _complete() async {
    setState(() => _completing = true);
    await _restockListRepository.complete(widget.restockListId);
    if (!mounted) return;
    AppSnack.success(context, 'Daftar kulakan selesai');
    Navigator.of(context).pop();
  }

  bool get _hasCheckedItems => _list?.items.any((item) => item.isChecked) ?? false;

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final hasCheckedItems = _hasCheckedItems;
    return Scaffold(
      appBar: AppHeader.withBack(
        title: 'Daftar Kulakan',
        onBack: () => Navigator.of(context).pop(),
        trailing: _loading || list == null
            ? null
            : SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      key: const Key('kulakan_list_copy_button'),
                      icon: const Icon(Icons.copy),
                      tooltip: hasCheckedItems ? 'Salin ke clipboard' : 'Centang minimal 1 barang',
                      onPressed: hasCheckedItems ? _copyToClipboard : null,
                    ),
                    IconButton(
                      key: const Key('kulakan_list_whatsapp_button'),
                      icon: const Icon(Icons.share),
                      tooltip: hasCheckedItems ? 'Bagikan ke WhatsApp' : 'Centang minimal 1 barang',
                      onPressed: hasCheckedItems ? _shareToWhatsApp : null,
                    ),
                  ],
                ),
              ),
      ),
      body: _loading || list == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    key: const Key('kulakan_list_supplier_field'),
                    controller: _supplierController,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      labelText: 'Nama toko/supplier',
                      hintText: 'cth. Toko Pak Adi',
                    ),
                    onChanged: _onSupplierNameChanged,
                  ),
                ),
                if (list.items.isNotEmpty && !hasCheckedItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Centang minimal 1 barang',
                        key: const Key('kulakan_list_share_hint'),
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                Expanded(
                  child: list.items.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          key: const Key('kulakan_list_items'),
                          itemCount: list.items.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) => _buildRow(list.items[index]),
                        ),
                ),
                // SafeArea + an inner 16 Padding: bottom gap is the system
                // inset *plus* 16 (matching the Tambah Produk "Simpan"
                // button's floating spacing), not SafeArea(minimum:)'s
                // max(inset, 16) which sits the button flush-low.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        key: const Key('kulakan_list_complete_button'),
                        onPressed: (_completing || list.items.isEmpty) ? null : _complete,
                        child: _completing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Selesai', style: AppTextStyles.body.copyWith(color: AppColors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const Key('kulakan_list_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Belum ada produk di daftar ini.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.gray700),
        ),
      ),
    );
  }

  Widget _buildRow(RestockListItem item) {
    final product = _productsById[item.productId];
    return product == null ? _buildUnavailableRow(item) : _buildProductRow(item, product);
  }

  /// A product hard-deleted while it still sat in this list. There's no
  /// live product to read from — [RestockListItem.productNameSnapshot] is
  /// the only thing left to show — so this is a read-only row: no photo,
  /// no editable qty (there's no [Product.unitsPerPack] left to interpret
  /// it against), and the checkbox is disabled since there's nothing left
  /// to actually go buy. Always excluded from the WhatsApp share text.
  Widget _buildUnavailableRow(RestockListItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Checkbox(
            key: Key('kulakan_list_checkbox_${item.productId}'),
            value: item.isChecked,
            onChanged: null,
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.help_outline, color: AppColors.gray500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${item.productNameSnapshot} (dihapus)',
              key: Key('kulakan_list_deleted_marker_${item.productId}'),
              style: AppTextStyles.body.copyWith(color: AppColors.gray500, fontStyle: FontStyle.italic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('${_formatNumber(item.qtyInPcs)} pcs', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  /// Deliberately mirrors PrioritasKulakanScreen._buildRow /
  /// PriorityProductCard._buildFull exactly so the two lists look identical:
  /// a single row of [checkbox | green accent bar + name + stock + unit
  /// conversion | quantity stepper]. No urgency label here (this is a
  /// shopping list, not the priority calculation), and no photo — same as
  /// Prioritas Kulakan.
  Widget _buildProductRow(RestockListItem item, Product product) {
    final isArchived = product.isArchived;
    final accentColor = isArchived ? AppColors.gray500 : AppColors.primary;
    final conversion = _stockConversionLine(
      product.currentStock,
      product.unitsPerPack,
      product.unitsPerDus,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                key: Key('kulakan_list_checkbox_${product.id}'),
                value: item.isChecked,
                onChanged: (_) => _toggleChecked(product.id),
              ),
              Expanded(
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 6, color: accentColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isArchived ? '${product.name} (diarsipkan)' : product.name,
                                key: isArchived
                                    ? Key('kulakan_list_archived_marker_${product.id}')
                                    : null,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isArchived ? AppColors.gray500 : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stok: ${_formatNumber(product.currentStock)} ${product.unit}',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (conversion != null)
                                Text(
                                  conversion,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: RestockQtyField(
                  productId: product.id,
                  unitsPerPack: product.unitsPerPack,
                  unitsPerDus: product.unitsPerDus,
                  initialQtyInPcs: item.qtyInPcs,
                  initialInputUnitWasPack: item.inputUnitWasPack,
                  allowsFractionalQuantity: product.allowsFractionalQuantity,
                  onChanged: (qtyInPcs, inputUnitWasPack) =>
                      _onQtyChanged(product.id, qtyInPcs, inputUnitWasPack),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

/// "= 6 pack = 1 dus" breakdown of [currentStock] — identical rule and
/// output to PriorityProductCard's own stock conversion, so the Daftar
/// Kulakan rows read exactly like the Prioritas Kulakan rows.
String? _stockConversionLine(double currentStock, int? unitsPerPack, int? unitsPerDus) {
  final parts = <String>[];
  if (unitsPerPack != null) {
    final packs = UnitConversion.fromPcs(
      qtyInPcs: currentStock,
      unit: EnteredUnit.pack,
      unitsPerPack: unitsPerPack,
      unitsPerDus: unitsPerDus,
    );
    if (_isWholeNumber(packs)) parts.add('${_formatGrouped(packs)} pack');
  }
  if (unitsPerDus != null) {
    final dus = UnitConversion.fromPcs(
      qtyInPcs: currentStock,
      unit: EnteredUnit.dus,
      unitsPerPack: unitsPerPack,
      unitsPerDus: unitsPerDus,
    );
    if (_isWholeNumber(dus)) parts.add('${_formatGrouped(dus)} dus');
  }
  if (parts.isEmpty) return null;
  return '= ${parts.join(' = ')}';
}

bool _isWholeNumber(double value) => (value - value.roundToDouble()).abs() < 0.001;

String _formatGrouped(double value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}

const _shareMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Group header used for products with no category, a category that was
/// since deleted, or (defensively) a broken parent chain. Always sorted
/// last among the groups in [buildKulakanListShareText].
const lainnyaGroupName = 'Lainnya';

/// Plain-text kulakan list formatted for WhatsApp (no markdown — WhatsApp
/// doesn't render it), grouped by each product's TOP-LEVEL category (its
/// root ancestor, not the leaf category it's directly tagged to), in the
/// order those groups first appear in the list — except [lainnyaGroupName],
/// which always sorts last.
///
/// Only checked items are included, and only if their product still
/// exists and isn't archived: an unchecked item wasn't actually bought,
/// and a deleted/archived product isn't something to hand a supplier —
/// see [KulakanListScreen._buildUnavailableRow]/[KulakanListScreen._buildProductRow]
/// for how those are still shown (never hidden) on-screen. A top-level
/// function (not a private method) so it's directly unit-testable
/// without driving the share sheet.
String buildKulakanListShareText({
  required RestockList list,
  required Map<int, Product> productsById,
  required Map<int, Category> categoriesById,
  DateTime? now,
}) {
  final eligibleItems = list.items.where((item) {
    if (!item.isChecked) return false;
    final product = productsById[item.productId];
    return product != null && !product.isArchived;
  }).toList();

  final groupOrder = <String>[];
  final groupedItems = <String, List<RestockListItem>>{};
  for (final item in eligibleItems) {
    final product = productsById[item.productId]!;
    final groupName = _topLevelCategoryName(product.categoryId, categoriesById);
    groupedItems.putIfAbsent(groupName, () => []).add(item);
    if (!groupOrder.contains(groupName)) groupOrder.add(groupName);
  }
  // Lainnya always sorts last, regardless of when it first appeared.
  if (groupOrder.remove(lainnyaGroupName)) groupOrder.add(lainnyaGroupName);

  final buffer = StringBuffer()
    ..writeln('Daftar Kulakan - ${list.supplierName ?? '-'}')
    ..writeln(_formatShareDate(now ?? DateTime.now()))
    ..writeln();

  var number = 1;
  for (final groupName in groupOrder) {
    buffer.writeln(groupName);
    for (final item in groupedItems[groupName]!) {
      final product = productsById[item.productId]!;
      buffer.writeln('$number. ${product.name} - ${_formatQtyForShare(item, product)}');
      number++;
    }
    buffer.writeln();
  }

  buffer.write('Total: ${eligibleItems.length} item');

  return buffer.toString();
}

/// Walks [Category.parentId] up from [categoryId] to its root ancestor.
/// Falls back to [lainnyaGroupName] when there's no category, the
/// category itself was deleted (missing from [categoriesById]), or
/// (defensively) a cycle/broken chain is hit partway up — in the latter
/// case the last category successfully resolved is used as the
/// "top-level" rather than crashing or looping forever.
String _topLevelCategoryName(int? categoryId, Map<int, Category> categoriesById) {
  if (categoryId == null) return lainnyaGroupName;
  final start = categoriesById[categoryId];
  if (start == null) return lainnyaGroupName;

  var current = start;
  final visitedIds = {current.id};
  while (current.parentId != null) {
    final parent = categoriesById[current.parentId];
    if (parent == null || !visitedIds.add(parent.id)) break;
    current = parent;
  }
  return current.name;
}

/// "24 pcs" normally, or "2 pack (24 pcs)" when this item was actually
/// entered in packs — driven by [RestockListItem.inputUnitWasPack], not
/// merely by whether the product supports packs at all: a pack-capable
/// product whose item was typed in pcs still displays as plain pcs.
String _formatQtyForShare(RestockListItem item, Product product) {
  final unitsPerPack = product.unitsPerPack;
  if (!item.inputUnitWasPack || unitsPerPack == null) {
    return '${_formatNumber(item.qtyInPcs)} pcs';
  }
  final packs = item.qtyInPcs / unitsPerPack;
  return '${_formatNumber(packs)} pack (${_formatNumber(item.qtyInPcs)} pcs)';
}

String _formatShareDate(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_shareMonths[date.month - 1]} ${date.year} - $hour:$minute';
}
