import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/product.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../data/repositories/stock_mutation_repository.dart';
import '../../../services/photo_storage_service.dart';
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

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _sellPriceController;
  late final TextEditingController _unitController;
  late final TextEditingController _initialStockController;
  late final TextEditingController _minStockController;

  String? _photoPath;
  int? _categoryId;
  bool _saving = false;
  bool _initializing = true;

  String? _nameError;
  String? _codeError;
  String? _categoryError;
  String? _priceError;
  String? _unitError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _codeController = TextEditingController(text: existing?.code ?? '');
    _sellPriceController =
        TextEditingController(text: existing != null ? _formatNumberInput(existing.sellPrice) : '');
    _unitController = TextEditingController(text: existing?.unit ?? '');
    _initialStockController = TextEditingController(text: '0');
    _minStockController = TextEditingController(
      text: existing != null ? _formatNumberInput(existing.minStockThreshold) : '',
    );
    _photoPath = existing?.photoPath;
    _categoryId = existing?.categoryId;

    if (existing == null) {
      _loadDefaultThreshold();
    } else {
      _initializing = false;
    }
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
    _sellPriceController.dispose();
    _unitController.dispose();
    _initialStockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  void _showScanNotAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pemindaian barcode belum tersedia, silakan ketik manual')),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<PhotoPickSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Ambil Foto', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.of(sheetContext).pop(PhotoPickSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat mengakses kamera/galeri. Periksa izin aplikasi.')),
      );
    }
  }

  Future<void> _submit() async {
    setState(() {
      _nameError = null;
      _codeError = null;
      _categoryError = null;
      _priceError = null;
      _unitError = null;
    });

    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _categoryError = 'Pilih kategori terlebih dahulu');
      return;
    }

    final sellPrice = double.tryParse(_sellPriceController.text.replaceAll(',', '.')) ?? -1;
    final minThreshold = double.tryParse(_minStockController.text.replaceAll(',', '.'));
    final initialStock = double.tryParse(_initialStockController.text.replaceAll(',', '.')) ?? 0;

    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await _productRepository.update(
          id: widget.existing!.id,
          name: _nameController.text,
          categoryId: categoryId,
          code: _codeController.text,
          photoPath: _photoPath ?? '',
          sellPrice: sellPrice,
          unit: _unitController.text,
          minStockThreshold: minThreshold,
        );
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
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEditing ? 'Produk diperbarui' : 'Produk ditambahkan')),
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
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Produk' : 'Tambah Produk')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildPhotoPicker()),
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('product_form_name'),
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Nama produk',
                      hintText: 'contoh: Sendal jepit ukuran 39',
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('product_form_code'),
                          controller: _codeController,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Kode barang (opsional)',
                            errorText: _codeError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton.filledTonal(
                          onPressed: _showScanNotAvailable,
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'Pindai barcode',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CategoryPickerField(
                    isar: widget.isar,
                    selectedCategoryId: _categoryId,
                    errorText: _categoryError,
                    onChanged: (value) => setState(() {
                      _categoryId = value;
                      _categoryError = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('product_form_price'),
                    controller: _sellPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Harga jual',
                      prefixText: 'Rp ',
                      errorText: _priceError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('product_form_unit'),
                    controller: _unitController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Satuan',
                      hintText: 'contoh: pcs, kg, dus',
                      errorText: _unitError,
                    ),
                  ),
                  if (!widget.isEditing) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('product_form_initial_stock'),
                      controller: _initialStockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(labelText: 'Stok awal'),
                    ),
                  ],
                  if (widget.isEditing) ...[
                    const SizedBox(height: 16),
                    _buildReadOnlyCurrentStock(),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('product_form_min_stock'),
                    controller: _minStockController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(labelText: 'Batas minimum stok'),
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
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReadOnlyCurrentStock() {
    final existing = widget.existing!;
    return Container(
      key: const Key('product_form_current_stock_readonly'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Stok saat ini: ${_formatNumberInput(existing.currentStock)} ${existing.unit} '
              '(gunakan menu Stok masuk/keluar untuk mengubah)',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 140,
          height: 140,
          child: (photoPath == null || photoPath.isEmpty)
              ? Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.add_a_photo, size: 40, color: Colors.grey[700]),
                )
              : Image.file(
                  File(photoPath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
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
