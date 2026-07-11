import 'package:isar_community/isar.dart';

part 'category.g.dart';

@Collection(accessor: 'categories')
class Category {
  Id id = Isar.autoIncrement;

  /// `caseSensitive: false` makes Isar's unique index treat e.g. "Snacks"
  /// and "snacks" as the same value, so case-insensitive uniqueness is
  /// enforced at the database level without a separate normalized field.
  @Index(unique: true, caseSensitive: false)
  late String name;

  late DateTime createdAt;
}
