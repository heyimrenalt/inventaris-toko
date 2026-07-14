import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../widgets/mutation_list_item.dart';

/// Quick-entry form for recording a stock mutation. Two entry modes:
/// - [product] null: starts in product-search mode (reached from the
///   Mutasi tab's Catat button).
/// - [product] provided: skips straight to the form, product shown
///   read-only for context (reached from Product Detail's Stok
///   masuk/keluar buttons). [initialType] pre-selects the toggle but
///   stays user-changeable, in case the wrong button was tapped.
class CatatMutasiScreen extends StatefulWidget {
  const CatatMutasiScreen({
    super.key,
    required this.isar,
    this.product,
    this.initialType,
  });

  final Isar isar;
  final Product? product;
  final StockMutationType? initialType;

  @override
  State<CatatMutasiScreen> createState() => _CatatMutasiScreenState();
}

class _CatatMutasiScreenState extends State<CatatMutasiScreen> {
  late final StockMutationRepository _mutationRepository = StockMutationRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _mutationRepository,
    AppSettingsRepository(widget.isar),
  );

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  Product? _selectedProduct;
  StockMutationType _type = StockMutationType.stockIn;
  List<Product> _searchResults = [];
  String? _quantityErrorText;
  _InsufficientStockError? _insufficientStockError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.product;
    final initialType = widget.initialType;
    if (initialType != null) {
      _type = initialType;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await _productRepository.searchByName(query);
    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _showScanNotAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pemindaian barcode belum tersedia, silakan ketik manual')),
    );
  }

  Future<void> _submit() async {
    final product = _selectedProduct;
    if (product == null) return;

    setState(() {
      _quantityErrorText = null;
      _insufficientStockError = null;
    });

    final quantity = double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      setState(() => _quantityErrorText = 'Jumlah harus lebih dari 0');
      return;
    }

    if (_type == StockMutationType.stockOut && quantity > product.currentStock) {
      setState(() {
        _insufficientStockError = _InsufficientStockError(
          currentStock: product.currentStock,
          requestedQuantity: quantity,
          unit: product.unit,
        );
      });
      return;
    }

    double? costPricePerUnit;
    if (_type == StockMutationType.stockIn) {
      final costPriceText = _costPriceController.text.trim();
      if (costPriceText.isNotEmpty) {
        costPricePerUnit = double.tryParse(costPriceText.replaceAll(',', '.'));
      }
    }

    setState(() => _saving = true);
    try {
      final mutation = await _mutationRepository.recordMutation(
        productId: product.id,
        type: _type,
        quantity: quantity,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        costPricePerUnit: costPricePerUnit,
      );
      if (!mounted) return;
      final verb = _type == StockMutationType.stockIn ? 'Stok masuk' : 'Stok keluar';
      final sign = _type == StockMutationType.stockIn ? '+' : '-';
      final messenger = ScaffoldMessenger.of(context);
      final mutationId = mutation.id;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$verb dicatat: $sign${formatMutationQuantity(quantity)} ${product.name}',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Batalkan',
            onPressed: () => _undoMutation(messenger, mutationId),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      setState(() {
        _insufficientStockError = _InsufficientStockError(
          currentStock: e.currentStock,
          requestedQuantity: e.requestedQuantity,
          unit: product.unit,
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Reverses the just-saved mutation via the SnackBar's "Batalkan"
  /// action. By the time this fires (up to 5 seconds later, per the
  /// SnackBar's duration), this screen has already been popped — so this
  /// deliberately doesn't touch `context`/`mounted` for the repository
  /// call itself, only for the follow-up confirmation SnackBar, which
  /// uses the [messenger] reference resolved *before* the pop (it belongs
  /// to an ancestor Scaffold that outlives this screen).
  Future<void> _undoMutation(ScaffoldMessengerState messenger, int mutationId) async {
    await _mutationRepository.undoMutation(mutationId);
    messenger.showSnackBar(const SnackBar(content: Text('Mutasi dibatalkan')));
  }

  @override
  Widget build(BuildContext context) {
    final product = _selectedProduct;
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Mutasi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: product == null ? _buildSearch() : _buildForm(product),
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('catat_mutasi_search'),
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Cari produk',
                  hintText: 'Ketik nama produk',
                ),
                onChanged: _search,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _showScanNotAvailable,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Pindai barcode',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.trim().isEmpty
                        ? 'Ketik nama produk untuk mencari.'
                        : 'Produk tidak ditemukan.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    return ListTile(
                      minVerticalPadding: 16,
                      title: Text(product.name, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(
                        'Stok saat ini: ${formatMutationQuantity(product.currentStock)} ${product.unit}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () => _selectProduct(product),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildForm(Product product) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('catat_mutasi_product_context'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${product.name} — stok saat ini: ${formatMutationQuantity(product.currentStock)} '
              '${product.unit}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  key: const Key('catat_mutasi_type_in'),
                  label: 'Stok masuk',
                  icon: Icons.arrow_upward,
                  color: Colors.green[700]!,
                  selected: _type == StockMutationType.stockIn,
                  onTap: () => setState(() => _type = StockMutationType.stockIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeButton(
                  key: const Key('catat_mutasi_type_out'),
                  label: 'Stok keluar',
                  icon: Icons.arrow_downward,
                  color: Colors.red[700]!,
                  selected: _type == StockMutationType.stockOut,
                  onTap: () => setState(() => _type = StockMutationType.stockOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('catat_mutasi_quantity'),
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Jumlah',
              errorText: _quantityErrorText,
              // Built as a widget (not `errorText`) so the current-stock
              // figure can be bolded and the message is never line-capped
              // or ellipsized — `errorText` internally renders with
              // maxLines/TextOverflow.ellipsis, which risks clipping this
              // message since it's longer than the app's other inline
              // errors.
              error: _insufficientStockError == null
                  ? null
                  : _InsufficientStockErrorText(error: _insufficientStockError!),
            ),
          ),
          if (_type == StockMutationType.stockIn) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('catat_mutasi_cost_price'),
              controller: _costPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Harga modal per unit (opsional)',
                hintText: 'Kosongkan jika sama dengan sebelumnya',
                prefixText: 'Rp ',
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('catat_mutasi_note'),
            controller: _noteController,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'contoh: dari supplier A, terjual',
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('catat_mutasi_submit'),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: selected
          ? ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16)),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16)),
            ),
    );
  }
}

class _InsufficientStockError {
  const _InsufficientStockError({
    required this.currentStock,
    required this.requestedQuantity,
    required this.unit,
  });

  final double currentStock;
  final double requestedQuantity;
  final String unit;
}

/// Renders the "Stok tidak mencukupi" message with the current-stock
/// figure bolded so it stands out against the rest of the sentence.
/// Deliberately builds its own [Text.rich] instead of going through
/// [InputDecoration.errorText] (a plain String) — that's the only way to
/// bold part of the message, and as a side effect it also guarantees the
/// text wraps in full with no line cap or ellipsis, unlike the
/// `errorText` path which renders with `maxLines`/`TextOverflow.ellipsis`
/// internally.
class _InsufficientStockErrorText extends StatelessWidget {
  const _InsufficientStockErrorText({required this.error});

  final _InsufficientStockError error;

  @override
  Widget build(BuildContext context) {
    final currentStockLabel =
        '${formatMutationQuantity(error.currentStock)} ${error.unit}';
    final requestedLabel =
        '${formatMutationQuantity(error.requestedQuantity)} ${error.unit}';
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Stok tidak mencukupi. Stok saat ini: '),
          TextSpan(
            text: currentStockLabel,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: ', jumlah yang dimasukkan: $requestedLabel.'),
        ],
      ),
    );
  }
}
