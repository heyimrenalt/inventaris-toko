import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/prioritas_kulakan_calculator.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/mutation_list_item.dart';
import '../../widgets/unit_qty_field.dart';

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
  late final AppSettingsRepository _appSettingsRepository = AppSettingsRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _mutationRepository,
    _appSettingsRepository,
  );
  static const _calculator = PrioritasKulakanCalculator();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  Product? _selectedProduct;
  StockMutationType _type = StockMutationType.stockIn;
  List<Product> _searchResults = [];
  List<PrioritasKulakanResult> _frequentlySold = [];

  /// Kept in canonical pcs regardless of which unit [UnitQtyField] is
  /// currently displaying — see [_enteredUnit]/[_enteredValue] for the
  /// raw as-typed value, kept only for [StockMutation] history display.
  double _quantityInPcs = 0;
  EnteredUnit _enteredUnit = EnteredUnit.pcs;
  double _enteredValue = 0;
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
    // Only search mode (no product pre-selected) ever shows the quick-select
    // shortcuts, so there's no reason to spend the query when the form
    // already skips straight past search.
    if (_selectedProduct == null) {
      _loadFrequentlySold();
    }
  }

  Future<void> _loadFrequentlySold() async {
    final settings = await _appSettingsRepository.get();
    final products = await _productRepository.getAll();

    final stockOutByProduct = await _mutationRepository
        .getStockOutHistoryForProducts(products.map((product) => product.id));

    final results = _calculator.calculateAll(
      products: products,
      stockOutMutationsByProductId: stockOutByProduct,
      restockLeadTimeDays: settings.restockLeadTimeDays,
      restockCoverDays: settings.restockCoverDays,
    )..sort((a, b) => b.dailyVelocity.compareTo(a.dailyVelocity));

    if (!mounted) return;
    setState(() => _frequentlySold = results.take(5).toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _submit() async {
    // Guards against a second tap slipping through before the button's
    // `onPressed: _saving ? null : _submit` binding is rebuilt — that
    // rebuild only happens on the next frame, so two taps dispatched
    // before then both still hit the old (non-null) callback. Reading
    // the field directly here (rather than relying on the widget
    // rebuild) blocks the re-entrant call synchronously, before it can
    // record a second mutation or pop the route a second time.
    if (_saving) return;

    final product = _selectedProduct;
    if (product == null) return;

    setState(() {
      _quantityErrorText = null;
      _insufficientStockError = null;
    });

    if (_quantityInPcs <= 0) {
      setState(() => _quantityErrorText = 'Jumlah harus lebih dari 0');
      return;
    }

    if (_type == StockMutationType.stockOut && _quantityInPcs > product.currentStock) {
      setState(() {
        _insufficientStockError = _InsufficientStockError(
          currentStock: product.currentStock,
          requestedQuantity: _quantityInPcs,
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
        quantity: _quantityInPcs,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        costPricePerUnit: costPricePerUnit,
        enteredUnit: _enteredUnit,
        enteredQuantity: _enteredValue,
      );

      if (!mounted) return;
      final verb = _type == StockMutationType.stockIn ? 'Stok masuk' : 'Stok keluar';
      final sign = _type == StockMutationType.stockIn ? '+' : '-';
      final messenger = ScaffoldMessenger.of(context);
      final mutationId = mutation.id;
      AppSnack.actionOn(
        messenger,
        message:
            '$verb dicatat: $sign${formatMutationQuantity(_quantityInPcs)} ${product.name}',
        actionLabel: 'Batalkan',
        duration: const Duration(seconds: 5),
        onAction: () => _undoMutation(messenger, mutationId),
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
    AppSnack.infoOn(messenger, 'Mutasi dibatalkan');
  }

  @override
  Widget build(BuildContext context) {
    final product = _selectedProduct;
    return Scaffold(
      appBar: AppHeader.withBack(
        title: 'Catat Mutasi',
        onBack: () => Navigator.of(context).pop(),
      ),
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
        if (_frequentlySold.isNotEmpty) ...[
          const Text(
            'Sering keluar',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            key: const Key('catat_mutasi_frequently_sold_chips'),
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _frequentlySold.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final product = _frequentlySold[index].product;
                return ActionChip(
                  key: Key('frequently_sold_chip_${product.id}'),
                  label: Text(product.name),
                  onPressed: () => _selectProduct(product),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          key: const Key('catat_mutasi_search'),
          controller: _searchController,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: const InputDecoration(
            labelText: 'Cari produk',
            hintText: 'Ketik nama produk',
          ),
          onChanged: _search,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.trim().isEmpty
                        ? 'Ketik nama produk untuk mencari.'
                        : 'Produk tidak ditemukan.',
                    style: AppTextStyles.body.copyWith(color: AppColors.gray500),
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
                      title: Text(product.name, style: AppTextStyles.body),
                      subtitle: Text(
                        'Stok saat ini: ${formatMutationQuantity(product.currentStock)} ${product.unit}',
                        style: AppTextStyles.caption,
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
            decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${product.name} — stok saat ini: ${formatMutationQuantity(product.currentStock)} '
              '${product.unit}',
              style: AppTextStyles.bodyMedium,
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
                  color: AppColors.primary,
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
                  color: AppColors.redPrimary,
                  selected: _type == StockMutationType.stockOut,
                  onTap: () => setState(() => _type = StockMutationType.stockOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          UnitQtyField(
            product: product,
            initialQtyInPcs: _quantityInPcs,
            initialEnteredUnit: _enteredUnit,
            label: 'Jumlah',
            onChanged: (qtyInPcs, enteredUnit, enteredValue) {
              _quantityInPcs = qtyInPcs;
              _enteredUnit = enteredUnit;
              _enteredValue = enteredValue;
            },
          ),
          if (_quantityErrorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                _quantityErrorText!,
                style: AppTextStyles.caption.copyWith(color: AppColors.redPrimary),
              ),
            ),
          // A separate widget (not folded into UnitQtyField's own error
          // slot) so the current-stock figure can be bolded and the
          // message is never line-capped or ellipsized.
          if (_insufficientStockError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: _InsufficientStockErrorText(error: _insufficientStockError!),
            ),
          if (_type == StockMutationType.stockIn) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('catat_mutasi_cost_price'),
              controller: _costPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.body,
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
            style: AppTextStyles.body,
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
                  : Text('Simpan', style: AppTextStyles.body.copyWith(color: AppColors.white)),
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
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: AppColors.white),
              icon: Icon(icon),
              label: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.white)),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
              icon: Icon(icon),
              label: Text(label, style: AppTextStyles.body.copyWith(color: color)),
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
