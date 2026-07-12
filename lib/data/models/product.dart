import 'package:isar_community/isar.dart';

part 'product.g.dart';

@Collection(accessor: 'products')
class Product {
  Id id = Isar.autoIncrement;

  @Index()
  late String name;

  /// Optional barcode/product code. Uniqueness for non-null/non-empty
  /// values is enforced manually in [ProductRepository] rather than via
  /// `@Index(unique: true)`: Isar's null-handling semantics for unique
  /// indexes aren't documented clearly enough to depend on for a field
  /// that is expected to repeatedly be null, so this stays a plain
  /// lookup index and the uniqueness check is done explicitly in code.
  @Index()
  String? code;

  /// Foreign key to [Category.id]. Stored as a plain field (not an
  /// IsarLink) per spec.
  late int categoryId;

  String? photoPath;

  late double sellPrice;

  late String unit;

  /// Never set directly outside of [StockMutationRepository.recordMutation].
  late double currentStock;

  late double minStockThreshold;

  late DateTime createdAt;

  late DateTime updatedAt;

  /// Archived products are hidden from normal listings but not deleted —
  /// an alternative to [ProductRepository.delete] for products that have
  /// stock mutation history (and so can't be hard-deleted) but the user
  /// still wants off their active list.
  bool isArchived = false;

  DateTime? archivedAt;
}
