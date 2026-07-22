import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'product_thumb.dart';

/// A search field that live-searches products by name as the user types
/// (via [ProductRepository.searchByName], which already excludes
/// archived products) and shows matches in a dropdown list below the
/// field. Tapping a result invokes [onProductSelected] and clears the
/// search.
///
/// The results dropdown is rendered in an [OverlayEntry] anchored to the
/// field via [CompositedTransformTarget]/[CompositedTransformFollower]
/// instead of being laid out as a normal sibling below the [TextField] —
/// this field is used inside a [Positioned] box in Beranda's header that
/// sizes itself off this widget's own height (see BerandaScreen), so a
/// normal in-flow dropdown would grow that box and shift the field itself
/// upward/off-screen as results came in. Anchoring via the overlay keeps
/// the field's own layout size fixed regardless of how many results show.
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
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  List<Product> _results = [];
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _updateResults([]);
      return;
    }
    final results = await widget.productRepository.searchByName(trimmed);
    if (!mounted) return;
    // Guards against a slower earlier search resolving after a later,
    // shorter one and clobbering its results with stale matches.
    if (_controller.text.trim() != trimmed) return;
    _updateResults(results);
  }

  void _updateResults(List<Product> results) {
    setState(() => _results = results);
    if (results.isEmpty) {
      _removeOverlay();
    } else if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: _buildOverlay);
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _clear() {
    _controller.clear();
    _updateResults([]);
  }

  void _selectProduct(Product product) {
    _controller.clear();
    _updateResults([]);
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onProductSelected(product);
  }

  Widget _buildOverlay(BuildContext context) {
    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = fieldBox?.size.width;
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 8),
        child: Container(
          key: const Key('beranda_search_results'),
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            boxShadow: AppDimensions.cardShadow,
          ),
          // Rows paint their own ink splash on the nearest Material
          // ancestor — without this, that would be whatever Material
          // sits behind this Container's own painted background, which
          // Flutter flags as unsafe (invisible ink). clipBehavior keeps
          // the ripple within the card's rounded corners.
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.gray300,
              ),
              itemBuilder: (context, index) {
                final product = _results[index];
                return InkWell(
                  onTap: () => _selectProduct(product),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const ProductThumb(size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            product.name,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatQuantity(product.currentStock)} ${product.unit}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        key: _fieldKey,
        child: TextField(
          key: const Key('beranda_search_field'),
          controller: _controller,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Cari produk...',
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray500),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray500),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.gray500),
                    onPressed: _clear,
                  )
                : null,
          ),
          onChanged: _search,
        ),
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
