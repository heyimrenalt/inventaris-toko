import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

/// A search field that live-searches products by name as the user types
/// (via [ProductRepository.searchByName], which already excludes
/// archived products) and shows matches in a dropdown list below the
/// field. Tapping a result invokes [onProductSelected] and clears the
/// search. The trailing scan button is a placeholder — barcode scanning
/// is out of scope for this app — and just shows the same "belum
/// tersedia" message used everywhere else a scan button appears
/// (Product Form, Catat Mutasi).
class ProductSearchBar extends StatefulWidget {
  const ProductSearchBar({
    super.key,
    required this.productRepository,
    required this.onProductSelected,
  });

  final ProductRepository productRepository;
  final ValueChanged<Product> onProductSelected;

  @override
  State<ProductSearchBar> createState() => _ProductSearchBarState();
}

class _ProductSearchBarState extends State<ProductSearchBar> {
  final TextEditingController _controller = TextEditingController();
  List<Product> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final results = await widget.productRepository.searchByName(trimmed);
    if (!mounted) return;
    // Guards against a slower earlier search resolving after a later,
    // shorter one and clobbering its results with stale matches.
    if (_controller.text.trim() != trimmed) return;
    setState(() => _results = results);
  }

  void _clear() {
    _controller.clear();
    setState(() => _results = []);
  }

  void _selectProduct(Product product) {
    _controller.clear();
    setState(() => _results = []);
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onProductSelected(product);
  }

  void _handleScan() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pemindaian barcode belum tersedia, silakan ketik manual')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('beranda_search_field'),
          controller: _controller,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Cari produk',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clear,
                  ),
                IconButton(
                  key: const Key('beranda_scan_button'),
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Pindai barcode',
                  onPressed: _handleScan,
                ),
              ],
            ),
          ),
          onChanged: _search,
        ),
        if (_results.isNotEmpty)
          Container(
            key: const Key('beranda_search_results'),
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = _results[index];
                return ListTile(
                  dense: true,
                  title: Text(product.name, style: const TextStyle(fontSize: 15)),
                  subtitle: Text(
                    '${_formatQuantity(product.currentStock)} ${product.unit}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  onTap: () => _selectProduct(product),
                );
              },
            ),
          ),
      ],
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
