import 'package:isar_community/isar.dart';

part 'category.g.dart';

@Collection(accessor: 'categories')
class Category {
  Id id = Isar.autoIncrement;

  /// Name uniqueness is scoped to siblings (same [parentId]), not global,
  /// so it can't be enforced via a single-field unique index the way it
  /// was before nesting existed — [CategoryRepository] checks it manually
  /// against categories sharing the same [parentId] instead.
  @Index()
  late String name;

  /// Self-reference to the parent [Category]. `null` means this is a
  /// root-level (top-level) category. Defaults to `null` so every
  /// category that existed before nesting was added simply becomes a
  /// root category with no children — no migration script needed.
  @Index()
  int? parentId;

  late DateTime createdAt;
}
