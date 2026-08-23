import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/cost_price_adjustment_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../domain/hpp_calculator.dart';
import '../../../domain/unit_conversion.dart';
import '../../../domain/unit_quantity_rules.dart';
import '../../../services/photo_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/category_picker_field.dart';

/// Shared add/edit form. [existing] null means "add"; non-null means
/// "edit" — pre-filled, with the "Stok awal" field hidden (stock only
/// ever changes through StockMutationRepository, never this form) and
/// current stock shown read-only for context instead.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.isar,
    this.existing,
    PhotoStorageService? photoStorageService,
  }) : photoStorageService = photoStorageService ?? const ImagePickerPhotoStorageService();

  final Isar isar;
  final Product? existing;
  final PhotoStorageService photoStorageService;

  bool get isEditing => existing != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final ProductRepository _productRepository = ProductRepository(
    widget.isar,
    StockMutationRepository(widget.isar),
    AppSettingsRepository(widget.isar),
  );
  late final AppSettingsRepository _appSettingsRepository = AppSettingsRepository(widget.isar);
  late final CostPriceAdjustmentRepository _costPriceAdjustmentRepository =
      CostPriceAdjustmentRepository(widget.isar);

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellPriceController;
  late final TextEditingController _unitController;
  late final TextEditingController _unitsPerPackController;
  late final TextEditingController _unitsPerDusController;
  late final TextEditingController _initialStockController;
  late final TextEditingController _minStockController;

  String? _photoPath;
  int? _categoryId;
  bool _allowsFractionalQuantity = false;
  bool _saving = false;
  bool _initializing = true;

  String? _nameError;
  String? _codeError;
  String? _categoryError;
  String? _priceError;
  String? _unitError;

  /// Both "Stok awal" and "Batas minimum stok" hold a quantity in the
  /// canonical pcs unit, so they route through [UnitQuantityRules] like
  /// every other quantity field rather than hardcoding `decimal: true` —
  /// a countable product must not get a fractional opening stock. The
  /// price fields above them are money, not quantities, and keep their own
  /// always-decimal keyboard.
  TextInputType get _stockKeyboardType => UnitQuantityRules.keyboardType(
        unit: EnteredUnit.pcs,
        productAllowsFractional: _allowsFractionalQuantity,
      );

  List<TextInputFormatter> get _stockInputFormatters => UnitQuantityRules.inputFormatters(
        unit: EnteredUnit.pcs,
        productAllowsFractional: _allowsFractionalQuantity,
      );
  String? _unitsPerPackError;
  String? _unitsPerDusError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _codeController = TextEditingController(text: existing?.code ?? '');
    // Pre-filled with the current HPP in edit mode (this is the "Harga
    // modal (koreksi)" manual-correction field there), left blank in add
    // mode (the initial "Harga modal" field).
    _costPriceController = TextEditingController(
      text: existing?.averageCostPrice != null ? _formatNumberInput(existing!.averageCostPrice!) : '',
    );
    _sellPriceController =
        TextEditingController(text: existing != null ? _formatNumberInput(existing.sellPrice) : '');
    _unitController = TextEditingController(text: existing?.unit ?? '');
    _unitsPerPackController = TextEditingController(
      text: existing?.unitsPerPack != null ? existing!.unitsPerPack.toString() : '',
    );
    _unitsPerDusController = TextEditingController(
      text: existing?.unitsPerDus != null ? existing!.unitsPerDus.toString() : '',
    );
    _initialStockController = TextEditingController(text: '0');
    _minStockController = TextEditingController(
      text: existing != null ? _formatNumberInput(existing.minStockThreshold) : '',
    );
    _photoPath = existing?.photoPath;
    _categoryId = existing?.categoryId;
    _allowsFractionalQuantity = existing?.allowsFractionalQuantity ?? false;

    // Live margin preview reacts to both fields in both modes: the cost
    // price field is editable in edit mode too now (as a manual HPP
    // correction), not just at creation.
    _sellPriceController.addListener(_onLivePriceFieldsChanged);
    _costPriceController.addListener(_onLivePriceFieldsChanged);

    // Drives the live "Ringkasan kemasan" summary, the conditional
    // visibility of the dus field, and the min-stock pack/dus caption —
    // all three need to recompute on every keystroke in any of these
    // three fields, not just their own.
    _unitsPerPackController.addListener(_onPackagingFieldsChanged);
    _unitsPerDusController.addListener(_onPackagingFieldsChanged);
    _minStockController.addListener(_onPackagingFieldsChanged);

    if (existing == null) {
      _loadDefaultThreshold();
    } else {
      _initializing = false;
    }
  }

  void _onLivePriceFieldsChanged() => setState(() {});

  /// Drives the live "Ringkasan kemasan" summary, the dus field's hint
  /// text, and the min-stock pack/dus caption on every keystroke in any
  /// of the three fields. Deliberately does *not* cascade-clear "Isi per
  /// dus" when "Isi per pack" is cleared — a dus can be configured
  /// directly in pcs with no pack tier at all (see UnitConversion), so
  /// clearing pack doesn't make an existing dus value meaningless.
  void _onPackagingFieldsChanged() => setState(() {});

  bool get _packagingHasValidPack {
    final (value, valid) = _parseUnitsPerPack();
    return valid && value != null;
  }

  double? _liveSellPrice() {
    final value = double.tryParse(_sellPriceController.text.trim().replaceAll(',', '.'));
    return (value == null || value <= 0) ? null : value;
  }

  double? _liveCostPrice() {
    final text = _costPriceController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  Future<void> _loadDefaultThreshold() async {
    final settings = await _appSettingsRepository.get();
    if (!mounted) return;
    setState(() {
      _minStockController.text = _formatNumberInput(settings.defaultMinStockThreshold);
      _initializing = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _unitController.dispose();
    _unitsPerPackController.dispose();
    _unitsPerDusController.dispose();
    _initialStockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<PhotoPickSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              // TODO(ui-migration): fontSize 16 kept inline — AppTextStyles.subheading
              // is the only size-16 token and would flip w400 -> w700.
              title: const Text('Ambil Foto', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.of(sheetContext).pop(PhotoPickSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              // TODO(ui-migration): fontSize 16 kept inline — AppTextStyles.subheading
              // is the only size-16 token and would flip w400 -> w700.
              title: const Text('Pilih dari Galeri', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.of(sheetContext).pop(PhotoPickSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final newPath = await widget.photoStorageService.pickAndSavePhoto(source);
      if (newPath == null) return;
      final oldPath = _photoPath;
      if (!mounted) return;
      setState(() => _photoPath = newPath);
      if (oldPath != null && oldPath.isNotEmpty && oldPath != newPath) {
        await widget.photoStorageService.deletePhoto(oldPath);
      }
    } on PhotoPermissionDeniedException {
      if (!mounted) return;
      AppSnack.error(
        context,
        'Tidak dapat mengakses kamera/galeri. Periksa izin aplikasi.',
      );
    }
  }

  /// `null` when the field is left blank (pcs-only, valid). Sets
  /// [_unitsPerPackError] and returns `false` when the text is non-blank
  /// but not a valid integer >= 2 — checked locally, before the repository
  /// call, so 0/1/negative/non-numeric all get the same inline error
  /// immediately rather than round-tripping through a thrown exception.
  (int?, bool) _parseUnitsPerPack() {
    final text = _unitsPerPackController.text.trim();
    if (text.isEmpty) return (null, true);
    final value = int.tryParse(text);
    if (value == null || value < 2) return (null, false);
    return (value, true);
  }

  /// Same shape as [_parseUnitsPerPack] — `null`/`true` when left blank,
  /// `null`/`false` when non-blank but not a valid integer >= 2.
  (int?, bool) _parseUnitsPerDus() {
    final text = _unitsPerDusController.text.trim();
    if (text.isEmpty) return (null, true);
    final value = int.tryParse(text);
    if (value == null || value < 2) return (null, false);
    return (value, true);
  }

  Future<void> _submit() async {
    // See the matching guard in CatatMutasiScreen._submit() — blocks a
    // second tap that lands before the disabled-button rebuild takes
    // effect, so a rapid double-tap can't record/update the product twice
    // or pop the route twice.
    if (_saving) return;

    setState(() {
      _nameError = null;
      _codeError = null;
      _categoryError = null;
      _priceError = null;
      _unitError = null;
      _unitsPerPackError = null;
      _unitsPerDusError = null;
    });

    final categoryId = _categoryId;

    final sellPrice = double.tryParse(_sellPriceController.text.replaceAll(',', '.')) ?? -1;
    final minThreshold = double.tryParse(_minStockController.text.replaceAll(',', '.'));
    final initialStock = double.tryParse(_initialStockController.text.replaceAll(',', '.')) ?? 0;

    final (unitsPerPack, unitsPerPackValid) = _parseUnitsPerPack();
    if (!unitsPerPackValid) {
      setState(() {
        _unitsPerPackError = 'Isi per pack harus angka bulat >= 2 (kosongkan jika hanya per pcs)';
      });
      return;
    }

    final (unitsPerDus, unitsPerDusValid) = _parseUnitsPerDus();
    if (!unitsPerDusValid) {
      setState(() {
        _unitsPerDusError = 'Isi per dus harus angka bulat >= 2';
      });
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await _productRepository.update(
          id: widget.existing!.id,
          name: _nameController.text,
          categoryId: categoryId,
          // categoryId itself can't distinguish "leave unchanged" from
          // "clear to Lainnya" now that null is a valid category value —
          // clearCategory is the explicit signal for the latter. See the
          // comment on ProductRepository.update.
          clearCategory: categoryId == null,
          code: _codeController.text,
          photoPath: _photoPath ?? '',
          sellPrice: sellPrice,
          unit: _unitController.text,
          minStockThreshold: minThreshold,
          unitsPerPack: unitsPerPack,
          // Same "null can't distinguish leave-unchanged from clear"
          // situation as clearCategory above.
          clearUnitsPerPack: unitsPerPack == null,
          unitsPerDus: unitsPerDus,
          clearUnitsPerDus: unitsPerDus == null,
          allowsFractionalQuantity: _allowsFractionalQuantity,
        );

        // Manual HPP correction: only write an adjustment (and only touch
        // averageCostPrice) if the "Harga modal (koreksi)" field actually
        // changed from the stored value — leaving it untouched must be a
        // no-op, not a redundant audit row.
        final correctedCost = _liveCostPrice();
        if (correctedCost != widget.existing!.averageCostPrice) {
          await _costPriceAdjustmentRepository.recordAdjustment(
            productId: widget.existing!.id,
            newCost: correctedCost,
          );
        }
      } else {
        await _productRepository.create(
          name: _nameController.text,
          categoryId: categoryId,
          sellPrice: sellPrice,
          unit: _unitController.text,
          code: _codeController.text,
          photoPath: _photoPath,
          minStockThreshold: minThreshold,
          initialStock: initialStock,
          averageCostPrice: _liveCostPrice(),
          unitsPerPack: unitsPerPack,
          unitsPerDus: unitsPerDus,
          allowsFractionalQuantity: _allowsFractionalQuantity,
        );
      }
      if (!mounted) return;
      AppSnack.success(
        context,
        widget.isEditing ? 'Produk diperbarui' : 'Produk ditambahkan',
      );
      Navigator.of(context).pop(true);
    } on ValidationException catch (e) {
      // ProductRepository only exposes one generic ValidationException
      // type for several fields; we match its (stable, repository-owned)
      // message text to route the error to the right field rather than
      // re-deriving the validation rules here.
      setState(() {
        final message = e.message;
        if (message.contains('name')) {
          _nameError = 'Nama produk tidak boleh kosong';
        } else if (message.contains('Unit')) {
          _unitError = 'Satuan tidak boleh kosong';
        } else if (message.contains('sellPrice')) {
          _priceError = 'Harga jual harus >= 0';
        } else if (message.contains('unitsPerDus')) {
          _unitsPerDusError = 'Isi per dus harus angka bulat >= 2';
        } else if (message.contains('unitsPerPack')) {
          _unitsPerPackError = 'Isi per pack harus angka bulat >= 2 (kosongkan jika hanya per pcs)';
        }
      });
    } on DuplicateProductCodeException {
      setState(() => _codeError = 'Kode barang ini sudah dipakai produk lain');
    } on NotFoundException {
      setState(() => _categoryError = 'Kategori tidak ditemukan, pilih ulang');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader.withBack(
        title: widget.isEditing ? 'Edit Produk' : 'Tambah Produk',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // Reserve the system navigation-bar inset at the bottom so the
              // "Simpan" button clears the Android nav bar — without this it
              // renders underneath it and taps land on the nav bar instead of
              // the button (reported as "tombol Simpan tidak bisa diklik").
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildPhotoPicker()),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    key: const Key('product_form_name'),
                    controller: _nameController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Nama produk',
                      hintText: 'contoh: Sendal jepit ukuran 39',
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('product_form_code'),
                    controller: _codeController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Kode barang (opsional)',
                      errorText: _codeError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CategoryPickerField(
                    isar: widget.isar,
                    selectedCategoryId: _categoryId,
                    errorText: _categoryError,
                    onChanged: (value) => setState(() {
                      _categoryId = value;
                      _categoryError = null;
                    }),
                  ),
                  if (widget.isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildReadOnlyHpp(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('product_form_cost_price'),
                    controller: _costPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText:
                          widget.isEditing ? 'Harga modal (koreksi)' : 'Harga modal (opsional)',
                      hintText: widget.isEditing
                          ? 'Ubah untuk mengoreksi HPP secara manual'
                          : 'Harga beli/modal per unit',
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('product_form_price'),
                    controller: _sellPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Harga jual',
                      prefixText: 'Rp ',
                      errorText: _priceError,
                    ),
                  ),
                  _buildMarginPanel(),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('product_form_unit'),
                    controller: _unitController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Satuan',
                      hintText: 'contoh: pcs, kg, dus',
                      errorText: _unitError,
                    ),
                  ),
                  SwitchListTile(
                    key: const Key('product_form_allows_fractional_quantity'),
                    contentPadding: EdgeInsets.zero,
                    title: Text('Boleh jumlah pecahan', style: AppTextStyles.body),
                    // TODO(ui-migration): subtitle has no style while the title
                    // above uses AppTextStyles.body — a real inconsistency, not a
                    // token swap. Deferred to a design pass.
                    subtitle: const Text(
                      'Aktifkan untuk barang timbang/ukur (kg, liter, dll) yang boleh '
                      'jumlahnya pecahan. Biarkan mati untuk barang satuan (pcs/pack/dus).',
                    ),
                    value: _allowsFractionalQuantity,
                    onChanged: (value) => setState(() => _allowsFractionalQuantity = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const Key('product_form_units_per_pack'),
                    controller: _unitsPerPackController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Isi per pack (opsional)',
                      hintText: 'Berapa pcs dalam 1 pack? cth: 6',
                      errorText: _unitsPerPackError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('product_form_units_per_dus'),
                    controller: _unitsPerDusController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Isi per dus (opsional)',
                      // A dus can be defined either relative to a pack
                      // (once "Isi per pack" is filled) or directly in pcs
                      // (a dus that skips the pack tier entirely) — see
                      // UnitConversion's class doc comment for the same
                      // rule applied everywhere else in the app.
                      hintText: _packagingHasValidPack
                          ? 'Berapa pack dalam 1 dus? cth: 6'
                          : 'Berapa pcs dalam 1 dus (tanpa pack)? cth: 12',
                      errorText: _unitsPerDusError,
                    ),
                  ),
                  _buildKemasanSummary(),
                  if (!widget.isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      key: const Key('product_form_initial_stock'),
                      controller: _initialStockController,
                      // Stok awal is a quantity in the canonical pcs unit,
                      // so it obeys the same discrete/continuous rule as
                      // every other quantity field — driven by the
                      // fractional-quantity switch further down this form.
                      keyboardType: _stockKeyboardType,
                      inputFormatters: _stockInputFormatters,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(labelText: 'Stok awal'),
                    ),
                  ],
                  if (widget.isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildReadOnlyCurrentStock(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('product_form_min_stock'),
                    controller: _minStockController,
                    keyboardType: _stockKeyboardType,
                    inputFormatters: _stockInputFormatters,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(labelText: 'Batas minimum stok'),
                  ),
                  if (_minStockConversionCaption() case final caption?)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
                      child: Text(
                        caption,
                        key: const Key('product_form_min_stock_conversion'),
                        // TODO(ui-migration): AppTextStyles.caption matches size 12
                        // but carries gray700 (#616161); grey[600] is #757575, so
                        // the swap would darken the text. No #757575 token exists.
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('product_form_submit'),
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isEditing ? 'Simpan Perubahan' : 'Simpan',
                              style: AppTextStyles.body.copyWith(color: AppColors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReadOnlyHpp() {
    final avgCost = widget.existing!.averageCostPrice;
    return Container(
      key: const Key('product_form_hpp_readonly'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
      ),
      child: Row(
        children: [
          // TODO(ui-migration): icon size 20 left raw — no icon-size token exists.
          const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              avgCost == null
                  ? 'HPP saat ini: belum ada data harga modal'
                  : 'HPP saat ini: ${_formatCurrency(avgCost)}/unit '
                      '(diperbarui otomatis saat restock, atau koreksi manual di bawah)',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Live "Untung per unit" / margin preview, recalculated on every rebuild
  /// from the current sell price and cost price fields — hidden entirely
  /// when either input is missing/invalid, per spec.
  Widget _buildMarginPanel() {
    final sellPrice = _liveSellPrice();
    final costPrice = _liveCostPrice();
    final profit = HppCalculator.profitPerUnit(sellPrice ?? 0, costPrice);
    final margin = HppCalculator.marginPercent(sellPrice ?? 0, costPrice);
    if (sellPrice == null || profit == null || margin == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        key: const Key('product_form_margin_panel'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          // TODO(ui-migration): 8% translucent green composites to ~#F1F9F1 over
          // white; AppColors.greenSubtle is the opaque #E8F5E9, a visibly darker
          // fill. Not an identical swap.
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Untung per unit: ${_formatCurrency(profit)}',
              style: AppTextStyles.bodyMedium,
            ),
            Text(
              'Margin: ${margin.round()}%',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Live "Ringkasan kemasan" card below the pack/dus fields — hidden
  /// entirely until at least one of pack/dus is validly filled.
  /// Recalculates on every keystroke in pack/dus (see
  /// [_onPackagingFieldsChanged]) using the in-progress, unsaved
  /// controller values, not the committed product.
  Widget _buildKemasanSummary() {
    final (unitsPerPack, packValid) = _parseUnitsPerPack();
    final (unitsPerDus, dusValid) = _parseUnitsPerDus();
    final effectivePack = packValid ? unitsPerPack : null;
    final effectiveDus = dusValid ? unitsPerDus : null;
    if (effectivePack == null && effectiveDus == null) return const SizedBox.shrink();

    final lines = <String>[];
    if (effectivePack != null) {
      lines.add('1 pack = ${_formatGrouped(effectivePack.toDouble())} pcs');
    }
    if (effectiveDus != null) {
      if (effectivePack != null) {
        final pcsPerDus = effectiveDus * effectivePack;
        lines.add(
          '1 dus = ${_formatGrouped(effectiveDus.toDouble())} pack = '
          '${_formatGrouped(pcsPerDus.toDouble())} pcs',
        );
      } else {
        // Dus defined directly in pcs, skipping the pack tier entirely.
        lines.add('1 dus = ${_formatGrouped(effectiveDus.toDouble())} pcs');
      }
    }

    // Current stock is only known once the product exists — the "add"
    // form's "Stok awal" hasn't been recorded as a mutation yet, so
    // there's no committed currentStock to convert.
    String? stockLine;
    String? stockConversion;
    if (widget.isEditing) {
      final currentStock = widget.existing!.currentStock;
      stockLine = 'Stok saat ini: ${_formatGrouped(currentStock)} pcs';
      stockConversion = _stockConversionLine(currentStock, effectivePack, effectiveDus);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        key: const Key('product_form_kemasan_summary'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          // TODO(ui-migration): teal is outside the palette entirely — mapping it
          // to green/yellow would change the color. Design decision, not migration.
          color: Colors.teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
          // TODO(ui-migration): teal outside palette — see above.
          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // TODO(ui-migration): icon size 18 raw (no icon-size token); teal
                // outside palette.
                Icon(Icons.inventory_2, size: 18, color: Colors.teal[700]),
                // TODO(ui-migration): 6 is off the spacing scale (xs=4, sm=8).
                const SizedBox(width: 6),
                Text(
                  'Ringkasan kemasan',
                  // TODO(ui-migration): bodyMedium would flip w700 -> w600, and
                  // teal[800] is outside the palette.
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                ),
              ],
            ),
            // TODO(ui-migration): 6 is off the spacing scale (xs=4, sm=8).
            const SizedBox(height: 6),
            for (final line in lines) Text(line, style: AppTextStyles.body),
            if (stockLine != null) ...[
              const Divider(height: AppSpacing.lg),
              Text(stockLine, style: AppTextStyles.bodyMedium),
              if (stockConversion != null) Text(stockConversion, style: AppTextStyles.body),
            ],
          ],
        ),
      ),
    );
  }

  /// "≈ 6 pack, 1 dus" read-only hint below "Batas minimum stok",
  /// computed from the in-progress pack/dus/min-stock controller values —
  /// `null` (no caption) when neither pack nor dus is validly filled,
  /// min-stock isn't a parseable number, or the min-stock value doesn't
  /// divide evenly into any configured tier.
  String? _minStockConversionCaption() {
    final (unitsPerPack, packValid) = _parseUnitsPerPack();
    final (unitsPerDus, dusValid) = _parseUnitsPerDus();
    final effectivePack = packValid ? unitsPerPack : null;
    final effectiveDus = dusValid ? unitsPerDus : null;
    if (effectivePack == null && effectiveDus == null) return null;

    final minStock = double.tryParse(_minStockController.text.trim().replaceAll(',', '.'));
    if (minStock == null) return null;

    final parts = <String>[];
    if (effectivePack != null) {
      final packs = UnitConversion.fromPcs(
        qtyInPcs: minStock,
        unit: EnteredUnit.pack,
        unitsPerPack: effectivePack,
        unitsPerDus: effectiveDus,
      );
      if (_isWholeNumber(packs)) parts.add('${_formatGrouped(packs)} pack');
    }
    if (effectiveDus != null) {
      final dus = UnitConversion.fromPcs(
        qtyInPcs: minStock,
        unit: EnteredUnit.dus,
        unitsPerPack: effectivePack,
        unitsPerDus: effectiveDus,
      );
      if (_isWholeNumber(dus)) parts.add('${_formatGrouped(dus)} dus');
    }
    if (parts.isEmpty) return null;
    return '≈ ${parts.join(', ')}';
  }

  Widget _buildReadOnlyCurrentStock() {
    final existing = widget.existing!;
    return Container(
      key: const Key('product_form_current_stock_readonly'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
      ),
      child: Row(
        children: [
          // TODO(ui-migration): icon size 20 left raw — no icon-size token exists.
          const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Stok saat ini: ${_formatNumberInput(existing.currentStock)} ${existing.unit} '
              '(gunakan menu Stok masuk/keluar untuk mengubah)',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    final photoPath = _photoPath;
    return GestureDetector(
      key: const Key('product_form_photo_picker'),
      onTap: _pickPhoto,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.inputRadius),
        child: SizedBox(
          width: 140,
          height: 140,
          child: (photoPath == null || photoPath.isEmpty)
              ? Container(
                  color: AppColors.gray300,
                  // TODO(ui-migration): icon size 40 left raw — no icon-size token.
                  child: const Icon(Icons.add_a_photo, size: 40, color: AppColors.gray700),
                )
              : Image.file(
                  File(photoPath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.gray300,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
        ),
      ),
    );
  }
}

String _formatNumberInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// Unlike Product Detail's currency formatter (which only ever formats
/// non-negative prices), profit-per-unit can be negative when the cost
/// price exceeds the sell price — so the sign is split off before grouping
/// digits rather than being swept into the thousands-separator math.
String _formatCurrency(double value) {
  final isNegative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp ${isNegative ? '-' : ''}$buffer';
}

/// "= 6 pack = 1 dus" breakdown of a pcs quantity — each tier shown only
/// when it independently divides evenly (epsilon 0.001), `null` when
/// neither tier is configured or neither divides evenly.
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
