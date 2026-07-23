import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/restock_list_repository.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/prioritas_kulakan_calculator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/priority_product_card.dart';
import '../../widgets/product_search_bar.dart';
import '../../widgets/restock_qty_field.dart';
import '../produk/product_detail_screen.dart';
import 'kulakan_list_screen.dart';

class PrioritasKulakanScreen extends StatefulWidget {
  const PrioritasKulakanScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<PrioritasKulakanScreen> createState() => _PrioritasKulakanScreenState();
}

class _PrioritasKulakanScreenState extends State<PrioritasKulakanScreen> {
  late final StockMutationRepository _mutationRepository = StockMutationRepository(widget.isar);
  late final AppSettingsRepository _settingsRepository = AppSettingsRepository(widget.isar);
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    _mutationRepository,
    _settingsRepository,
  );
  late final RestockListRepository _restockListRepository = RestockListRepository(widget.isar);
  static const _calculator = PrioritasKulakanCalculator();

  List<PrioritasKulakanResult> _results = [];
  bool _loading = true;

  /// Which products' checkboxes are currently ticked. Nothing is ever
  /// auto-checked (including on first load) — the user picks items
  /// deliberately, one by one, or via "Centang Semua". A background
  /// [_load] triggered by an unrelated mutation elsewhere in the app must
  /// never reset a choice the user already made on this screen, so this
  /// is only ever mutated by [_toggleChecked]/[_centangSemua]/
  /// [_hapusSemuaCentang], never by [_load] itself — except to drop a
  /// product that just became archived (see [_load]'s doc comment).
  final Set<int> _checkedProductIds = {};

  /// Every product ever shown on this screen this session, so a product
  /// that becomes archived while the page is open (and so drops out of
  /// [ProductRepository.getAll]'s normal, non-archived result) can still
  /// be looked up directly and kept visible with an archived marker
  /// instead of silently vanishing — see [_load].
  final Set<int> _seenProductIds = {};

  /// Prefilled/edited qty (always in pcs) per product, initialized once
  /// per product from `product.lastRestockQty ?? suggestedRestockQty`
  /// (see [_prefillQtyInPcs]) and from then on left to the user's own
  /// edits or to [_centangSemua] — [_load] never overwrites an entry that
  /// already exists, so a background reload can't clobber an in-progress
  /// edit.
  final Map<int, double> _qtyInPcsByProductId = {};
  final Map<int, bool> _inputUnitWasPackByProductId = {};

  /// Whether the user has manually edited a row's qty this session —
  /// [_centangSemua] must never overwrite these.
  final Set<int> _userEditedProductIds = {};

  /// Bumped whenever a row's qty is set programmatically (initial
  /// prefill or [_centangSemua]) so the qty field's [ValueKey] changes,
  /// forcing [RestockQtyField] to rebuild from the new initial value —
  /// it otherwise only ever reads its initial value once, in its own
  /// `initState`.
  final Map<int, int> _qtyFieldRevisionByProductId = {};

  StreamSubscription<void>? _productsSubscription;
  StreamSubscription<void>? _mutationsSubscription;
  StreamSubscription<void>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _productsSubscription = widget.isar.products.watchLazy().listen((_) => _load());
    _mutationsSubscription = widget.isar.stockMutations.watchLazy().listen((_) => _load());
    // Editing restockLeadTimeDays/restockCoverDays in Pengaturan must
    // recompute urgency/quantity here even when this screen stays open —
    // stale urgency from before the settings change would be misleading.
    _settingsSubscription = widget.isar.appSettings.watchLazy().listen((_) => _load());
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _mutationsSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _settingsRepository.get();
    final products = await _productRepository.getAll();

    final stockOutByProduct = <int, List<StockMutation>>{};
    for (final product in products) {
      stockOutByProduct[product.id] =
          await _mutationRepository.getStockOutHistoryForProduct(product.id);
    }

    final results = _calculator.calculateAll(
      products: products,
      stockOutMutationsByProductId: stockOutByProduct,
      restockLeadTimeDays: settings.restockLeadTimeDays,
      restockCoverDays: settings.restockCoverDays,
    );

    // A product seen before but missing from this fresh, non-archived
    // result set either got archived or hard-deleted since. Only the
    // former is still worth showing (with a disabled, marked row) — a
    // hard-deleted product has nothing left to buy.
    final resultProductIds = results.map((result) => result.product.id).toSet();
    for (final productId in _seenProductIds) {
      if (resultProductIds.contains(productId)) continue;
      final product = await _productRepository.getById(productId);
      if (product == null || !product.isArchived) continue;
      final archivedResult = _calculator.calculate(
        product: product,
        stockOutMutations: await _mutationRepository.getStockOutHistoryForProduct(productId),
        restockLeadTimeDays: settings.restockLeadTimeDays,
        restockCoverDays: settings.restockCoverDays,
      );
      if (archivedResult != null) results.add(archivedResult);
    }

    for (final result in results) {
      final productId = result.product.id;
      _seenProductIds.add(productId);
      if (result.product.isArchived) {
        // An archived product can't be checked — see the checkbox's
        // onChanged in _buildRow.
        _checkedProductIds.remove(productId);
      }
      _qtyInPcsByProductId.putIfAbsent(productId, () => _prefillQtyInPcs(result));
      _inputUnitWasPackByProductId.putIfAbsent(productId, () => false);
      _qtyFieldRevisionByProductId.putIfAbsent(productId, () => 0);
    }

    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  /// `product.lastRestockQty` if set, else `suggestedRestockQty` — never
  /// null/blank/zero, per the "Prioritas Kulakan" restock-qty prefill
  /// rule.
  double _prefillQtyInPcs(PrioritasKulakanResult result) =>
      result.product.lastRestockQty ?? result.suggestedRestockQty.toDouble();

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(isar: widget.isar, productId: product.id),
      ),
    );
    await _load();
  }

  void _toggleChecked(int productId) {
    setState(() {
      if (!_checkedProductIds.remove(productId)) {
        _checkedProductIds.add(productId);
      }
    });
  }

  void _onQtyChanged(int productId, double qtyInPcs, bool inputUnitWasPack) {
    _userEditedProductIds.add(productId);
    _qtyInPcsByProductId[productId] = qtyInPcs;
    _inputUnitWasPackByProductId[productId] = inputUnitWasPack;
  }

  bool get _checkableResultsExist => _results.any((result) => !result.product.isArchived);

  bool get _allChecked =>
      _checkableResultsExist &&
      _results
          .where((result) => !result.product.isArchived)
          .every((result) => _checkedProductIds.contains(result.product.id));

  /// Checks every checkable row and makes sure each shows a prefilled
  /// qty — without touching a qty the user already edited this session
  /// (see [_userEditedProductIds]).
  void _centangSemua() {
    if (!_checkableResultsExist) return;
    setState(() {
      for (final result in _results) {
        if (result.product.isArchived) continue;
        final productId = result.product.id;
        _checkedProductIds.add(productId);
        if (_userEditedProductIds.contains(productId)) continue;

        final prefill = _prefillQtyInPcs(result);
        if (_qtyInPcsByProductId[productId] != prefill) {
          _qtyFieldRevisionByProductId[productId] =
              (_qtyFieldRevisionByProductId[productId] ?? 0) + 1;
        }
        _qtyInPcsByProductId[productId] = prefill;
        _inputUnitWasPackByProductId[productId] = false;
      }
    });
  }

  void _hapusSemuaCentang() {
    setState(() => _checkedProductIds.clear());
  }

  /// Builds a new persisted [RestockList] from the currently checked
  /// items, using each row's current qty (the prefill, unless the user
  /// edited it — see [_qtyInPcsByProductId]), then opens
  /// [KulakanListScreen] to let the user name the store, adjust
  /// quantities (with pack/pcs support), share to WhatsApp, and mark
  /// items bought.
  Future<void> _buatDaftarKulakan() async {
    final checked = _results.where((result) => _checkedProductIds.contains(result.product.id));
    final list = await _restockListRepository.create(
      items: [
        for (final result in checked)
          RestockListItemInput(
            productId: result.product.id,
            productName: result.product.name,
            qtyInPcs: _qtyInPcsByProductId[result.product.id] ?? _prefillQtyInPcs(result),
            inputUnitWasPack: _inputUnitWasPackByProductId[result.product.id] ?? false,
            // Every item here already passed the _checkedProductIds filter
            // above — it must arrive on KulakanListScreen still checked,
            // not silently reset (see RestockListItemInput.isChecked).
            isChecked: true,
          ),
      ],
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KulakanListScreen(isar: widget.isar, restockListId: list.id),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final checkedCount = _checkedProductIds.length;
    return Scaffold(
      appBar: AppHeader.withBack(
        title: 'Prioritas Kulakan',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildCentangSemuaBar(),
                    const Divider(height: 0.5, thickness: 0.5),
                    Expanded(
                      child: ListView.builder(
                        key: const Key('prioritas_kulakan_list'),
                        itemCount: _results.length,
                        itemBuilder: (context, index) => _buildRow(_results[index]),
                      ),
                    ),
                    _buildFooter(checkedCount),
                  ],
                ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          boxShadow: AppDimensions.elevatedSearchShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
            ),
            child: ProductSearchBar(
              productRepository: _productRepository,
              onProductSelected: _openDetail,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCentangSemuaBar() {
    final allChecked = _allChecked;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const Key('prioritas_kulakan_centang_semua_button'),
          onPressed: _checkableResultsExist ? (allChecked ? _hapusSemuaCentang : _centangSemua) : null,
          icon: Icon(allChecked ? Icons.remove_done : Icons.done_all),
          label: Text(
            allChecked ? 'Batal Centang Semua' : 'Centang Semua',
            style: AppTextStyles.body,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(int checkedCount) {
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$checkedCount barang dipilih',
            key: const Key('prioritas_kulakan_selected_count'),
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('kulakan_buat_daftar_button'),
              onPressed: checkedCount == 0 ? null : _buatDaftarKulakan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00AA0D),
              ),
              child: const Text('Buat Daftar Kulakan', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(PrioritasKulakanResult result) {
    final product = result.product;
    final isArchived = product.isArchived;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                key: Key('kulakan_checkbox_${product.id}'),
                value: _checkedProductIds.contains(product.id),
                onChanged: isArchived ? null : (_) => _toggleChecked(product.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PriorityProductCard(
                      result: result,
                      onTap: () => _openDetail(product),
                    ),
                    if (isArchived)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6),
                        child: Text(
                          '(diarsipkan)',
                          key: Key('prioritas_kulakan_archived_marker_${product.id}'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: RestockQtyField(
                  key: ValueKey('qty_${product.id}_${_qtyFieldRevisionByProductId[product.id] ?? 0}'),
                  productId: product.id,
                  unitsPerPack: product.unitsPerPack,
                  unitsPerDus: product.unitsPerDus,
                  initialQtyInPcs: _qtyInPcsByProductId[product.id] ?? _prefillQtyInPcs(result),
                  initialInputUnitWasPack: _inputUnitWasPackByProductId[product.id] ?? false,
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

  Widget _buildEmptyState() {
    return Center(
      key: const Key('prioritas_kulakan_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Belum ada data penjualan untuk dihitung. Catat beberapa mutasi '
          'stok keluar dulu.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[700]),
        ),
      ),
    );
  }
}
