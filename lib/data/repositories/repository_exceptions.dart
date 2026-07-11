/// Thrown when a value supplied to a repository method fails a business
/// rule (e.g. empty name, negative price). Callers must handle or
/// propagate this — there is no silent failure path.
class ValidationException implements Exception {
  ValidationException(this.message);

  final String message;

  @override
  String toString() => 'ValidationException: $message';
}

/// Thrown when a lookup by id finds nothing.
class NotFoundException implements Exception {
  NotFoundException(this.message);

  final String message;

  @override
  String toString() => 'NotFoundException: $message';
}

/// Thrown by [CategoryRepository.delete] when the category is still
/// referenced by at least one [Product]. Deletion is refused rather than
/// cascading, since silently orphaning or deleting products is never the
/// right default for inventory data.
class CategoryInUseException implements Exception {
  CategoryInUseException(this.categoryId, this.productCount);

  final int categoryId;
  final int productCount;

  @override
  String toString() =>
      'CategoryInUseException: category $categoryId is referenced by '
      '$productCount product(s) and cannot be deleted';
}

/// Thrown when a category name (case-insensitive) already exists.
class DuplicateCategoryNameException implements Exception {
  DuplicateCategoryNameException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateCategoryNameException: "$name" already exists';
}

/// Thrown when a non-empty product code already exists on another product.
class DuplicateProductCodeException implements Exception {
  DuplicateProductCodeException(this.code);

  final String code;

  @override
  String toString() => 'DuplicateProductCodeException: "$code" already exists';
}

/// Thrown by [ProductRepository.delete] when the product still has
/// [StockMutation] history. See the comment on that method for why
/// deletion is blocked rather than cascading.
class ProductHasHistoryException implements Exception {
  ProductHasHistoryException(this.productId, this.mutationCount);

  final int productId;
  final int mutationCount;

  @override
  String toString() =>
      'ProductHasHistoryException: product $productId has $mutationCount '
      'stock mutation(s) and cannot be deleted';
}
