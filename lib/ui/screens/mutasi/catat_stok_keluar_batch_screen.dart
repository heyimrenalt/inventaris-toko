import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/unit_conversion.dart';
import '../../widgets/app_header.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/mutation_list_item.dart';
import '../../widgets/product_search_bar.dart';
import '../../widgets/unit_qty_field.dart';

class _CartItem {
  _CartItem(this.product)
      : qtyInPcs = 1,
        enteredUnit = EnteredUnit.pcs,
        enteredValue = 1;

  final Product product;

  /// Always canonical pcs, regardless of [enteredUnit] — see
  /// [enteredUnit]/[enteredValue] for the raw as-typed value.
  double qtyInPcs;
  EnteredUnit enteredUnit;
  double enteredValue;

  /// Bumped whenever the quantity is changed from outside the row's own
  /// [UnitQtyField] (see [_addProduct]'s "already in cart" branch) — used
  /// as part of that field's [Key] to force it to remount and pick up
  /// the new value, since [UnitQtyField] otherwise only reads its
  /// `initialQtyInPcs`/`initialEnteredUnit` once, in `initState`.
  int revision = 0;

  // Unlike the old QuantityStepper (default min: 1), UnitQtyField's own
  // stepper only floors at 0, and its text field never blocks 0 outright
  // — so this has to check it explicitly, or a 0-quantity item would
  // sail past `isValid` and hit recordMutation's own
  // "quantity must be > 0" ValidationException uncaught (only
  // InsufficientStockException is caught in _save()).
  bool get isValid => qtyInPcs > 0 && qtyInPcs <= product.currentStock;

  String? get errorText {
    if (qtyInPcs <= 0) return 'Jumlah harus lebih dari 0';
    if (qtyInPcs > product.currentStock) {
      return 'Stok tidak mencukupi: tersedia ${formatMutationQuantity(product.currentStock)} ${product.unit}';
    }
    return null;
  }
}

/// Shopping-cart-style entry for recording stock-out on several products
/// in one session. Unlike [CatatMutasiScreen] (single product per save),
/// nothing here is written to Isar until "Simpan semua" is tapped — the
/// cart itself is ephemeral widget state.
class CatatStokKeluarBatchScreen extends StatefulWidget {
  const CatatStokKeluarBatchScreen({super.key, required this.isar, this.initialProduct});

  final Isar isar;

  /// Pre-added at quantity 1 when opened from Product Detail's "Stok
  /// keluar" button, so the user isn't forced to re-search for the
  /// product they just came from.
  final Product? initialProduct;

  @override
  State<CatatStokKeluarBatchScreen> createState() => _CatatStokKeluarBatchScreenState();
}

class _CatatStokKeluarBatchScreenState extends State<CatatStokKeluarBatchScreen> {
  late final StockMutationRepository _mutationRepository = StockMutationRepository(widget.isar);
  late final AppSettingsRepository _appSettingsRepository = AppSettingsRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _mutationRepository,
    _appSettingsRepository,
  );

  final List<_CartItem> _cart = [];
  bool _saving = false;

  bool get _allValid => _cart.every((item) => item.isValid);
  bool get _canSave => _cart.isNotEmpty && _allValid && !_saving;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProduct;
    if (initial != null) {
      _cart.add(_CartItem(initial));
    }
  }

  void _addProduct(Product product) {
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    setState(() {
      if (existingIndex >= 0) {
        // Bumps by 1 in whatever unit the row is currently showing, not
        // always 1 pcs — re-selecting a dus-entered row from search
        // should add another dus, not silently switch it to pcs.
        final item = _cart[existingIndex];
        item.qtyInPcs += UnitConversion.toPcs(
          value: 1,
          unit: item.enteredUnit,
          unitsPerPack: item.product.unitsPerPack,
          unitsPerDus: item.product.unitsPerDus,
        );
        item.enteredValue += 1;
        item.revision++;
      } else {
        _cart.add(_CartItem(product));
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateQuantity(int index, double qtyInPcs, EnteredUnit enteredUnit, double enteredValue) {
    setState(() {
      _cart[index]
        ..qtyInPcs = qtyInPcs
        ..enteredUnit = enteredUnit
        ..enteredValue = enteredValue;
    });
  }

  Future<bool> _confirmExit() async {
    if (_cart.isEmpty) return true;
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Batalkan pencatatan?',
      message:
          'Ada ${_cart.length} barang yang belum disimpan. Keluar sekarang akan '
          'membatalkan semuanya.',
      confirmLabel: 'Keluar',
      isDestructive: true,
    );
    return confirmed == true;
  }

  Future<void> _undoMutation(ScaffoldMessengerState messenger, int mutationId) async {
    await _mutationRepository.undoMutation(mutationId);
    messenger.showSnackBar(const SnackBar(content: Text('Mutasi dibatalkan')));
  }

  Future<void> _save() async {
    // See the matching guard in CatatMutasiScreen._submit() — `_canSave`
    // (used for `onPressed`) only reflects `_saving` after the next
    // rebuild, so a rapid double-tap can still invoke `_save` a second
    // time before that rebuild lands. Re-checking `_saving` directly
    // here blocks the re-entrant call synchronously.
    if (!_canSave || _saving) return;

    setState(() => _saving = true);

    final succeeded = <_CartItem>[];
    final failedNames = <String>[];
    StockMutation? lastMutation;

    for (final item in List<_CartItem>.from(_cart)) {
      try {
        final mutation = await _mutationRepository.recordMutation(
          productId: item.product.id,
          type: StockMutationType.stockOut,
          quantity: item.qtyInPcs,
          enteredUnit: item.enteredUnit,
          enteredQuantity: item.enteredValue,
        );
        lastMutation = mutation;
        succeeded.add(item);
      } on InsufficientStockException {
        failedNames.add(item.product.name);
      }
    }

    if (!mounted) return;

    setState(() {
      _cart.removeWhere(succeeded.contains);
      _saving = false;
    });

    final messenger = ScaffoldMessenger.of(context);

    if (failedNames.isEmpty) {
      // A cart that only ever held one item behaves like a single-item
      // mutation for undo purposes — it gets the same SnackBar undo as
      // CatatMutasiScreen. A genuine multi-item batch save does not: there
      // is no atomic way to undo several independent mutations at once.
      if (succeeded.length == 1 && lastMutation != null) {
        final item = succeeded.first;
        final mutationId = lastMutation.id;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Tersimpan: ${item.product.name} -${formatMutationQuantity(item.qtyInPcs)}',
            ),
            duration: const Duration(seconds: 5),
            // SnackBar.persist defaults to true whenever action is
            // non-null (see SnackBar's own doc comment on `persist`),
            // which makes the `duration` above a no-op — the SnackBar
            // would otherwise sit there until manually swiped away
            // instead of auto-dismissing.
            persist: false,
            action: SnackBarAction(
              label: 'Batalkan',
              onPressed: () => _undoMutation(messenger, mutationId),
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('${succeeded.length} barang berhasil dicatat')),
        );
      }
      Navigator.of(context).pop(true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${succeeded.length} berhasil, ${failedNames.length} gagal: ${failedNames.join(', ')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _cart.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _confirmExit();
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppHeader.withBack(
          title: 'Catat stok keluar',
          onBack: () => Navigator.maybePop(context),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ProductSearchBar(
                productRepository: _productRepository,
                onProductSelected: _addProduct,
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildCartList()),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('batch_save_button'),
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Simpan semua (${_cart.length} barang)',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Cari produk di atas untuk mulai mencatat.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('batch_cart_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _cart.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildCartRow(index),
    );
  }

  Widget _buildCartRow(int index) {
    final item = _cart[index];
    return Dismissible(
      key: ValueKey(item.product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red[700],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeItem(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.product.name} — stok: '
                        '${formatMutationQuantity(item.product.currentStock)} ${item.product.unit}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (item.errorText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.errorText!,
                          key: Key('batch_item_error_$index'),
                          style: const TextStyle(fontSize: 13, color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  key: Key('batch_remove_$index'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus dari daftar',
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            UnitQtyField(
              key: ValueKey('${item.product.id}_${item.revision}'),
              product: item.product,
              initialQtyInPcs: item.qtyInPcs,
              initialEnteredUnit: item.enteredUnit,
              onChanged: (qtyInPcs, enteredUnit, enteredValue) =>
                  _updateQuantity(index, qtyInPcs, enteredUnit, enteredValue),
            ),
          ],
        ),
      ),
    );
  }
}
