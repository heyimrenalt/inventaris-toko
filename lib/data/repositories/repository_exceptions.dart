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

/// Thrown by [CategoryRepository.delete] when the category or any of its
/// descendant categories (at any depth) is still referenced by at least
/// one [Product]. [productCount] is the aggregate count across the whole
/// subtree, not just this category. Deletion is refused rather than
/// cascading, since silently orphaning or deleting products is never the
/// right default for inventory data.
class CategoryInUseException implements Exception {
  CategoryInUseException(this.categoryId, this.productCount);

  final int categoryId;
  final int productCount;

  @override
  String toString() =>
      'CategoryInUseException: category $categoryId is referenced by '
      '$productCount product(s) (including sub-categories) and cannot be deleted';
}

/// Thrown by [CategoryRepository.delete] when the category has one or
/// more child categories. A category's subtree must be deleted from the
/// leaves up — deleting a parent never implicitly deletes or reassigns
/// its children.
class CategoryHasChildrenException implements Exception {
  CategoryHasChildrenException(this.categoryId, this.childCount);

  final int categoryId;
  final int childCount;

  @override
  String toString() =>
      'CategoryHasChildrenException: category $categoryId has $childCount '
      'sub-categor${childCount == 1 ? 'y' : 'ies'} and cannot be deleted';
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

/// Thrown by [StockMutationRepository.recordMutation] when a stock-out
/// quantity exceeds the product's current stock. Stock-out is rejected
/// outright in that case — no mutation is recorded and [Product.currentStock]
/// is left untouched.
class InsufficientStockException implements Exception {
  InsufficientStockException({
    required this.productId,
    required this.currentStock,
    required this.requestedQuantity,
  });

  final int productId;
  final double currentStock;
  final double requestedQuantity;

  @override
  String toString() =>
      'InsufficientStockException: product $productId has $currentStock in '
      'stock, requested $requestedQuantity';
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

/// Thrown by `DataWipeService.wipeAll` ("Hapus semua data" in Pengaturan)
/// when one or more Isar collections still couldn't be cleared after the
/// best-effort per-collection fallback pass. [failedCollections] names
/// which ones are still unresolved — the UI surfaces this as a "coba
/// install ulang aplikasi" message, since a collection clear failing even
/// on retry points at something more fundamental than a transient error.
class DataWipeException implements Exception {
  DataWipeException(this.failedCollections);

  final List<String> failedCollections;

  @override
  String toString() =>
      'DataWipeException: failed to clear ${failedCollections.join(', ')}';
}

/// Why `BackupService.validateAndParse` rejected a candidate backup file.
enum BackupValidationFailureReason {
  /// The file's contents aren't parseable JSON at all (corrupted/truncated
  /// download, or not a JSON file to begin with).
  invalidJson,

  /// Parsed fine, but there's no top-level `"version"` field — not a
  /// backup file produced by this app at all.
  missingVersion,

  /// Has a `"version"` field, but not one this app version knows how to
  /// import (only version 1 is supported today).
  unsupportedVersion,
}

/// Thrown by `BackupService.validateAndParse` when the selected file isn't
/// a usable backup. Callers map [reason] to a specific Indonesian message
/// (see `PengaturanScreen`) rather than a generic "invalid file" string.
class BackupValidationException implements Exception {
  BackupValidationException(this.reason, {this.foundVersion});

  final BackupValidationFailureReason reason;

  /// The `"version"` value actually found in the file, when [reason] is
  /// [BackupValidationFailureReason.unsupportedVersion].
  final Object? foundVersion;

  @override
  String toString() => 'BackupValidationException: $reason (foundVersion: $foundVersion)';
}

/// Thrown by `BackupService.importBackup` when the import itself fails
/// after the file has already passed validation — the dangerous case,
/// since the current data has already been wiped by this point.
/// [rollbackSucceeded] tells the caller whether the pre-restore snapshot
/// could be re-applied, so the UI can show either "your previous data is
/// safe" or "please reinstall" accordingly.
class BackupRestoreException implements Exception {
  BackupRestoreException({required this.rollbackSucceeded, this.cause});

  final bool rollbackSucceeded;
  final Object? cause;

  @override
  String toString() =>
      'BackupRestoreException: import failed (rollbackSucceeded: $rollbackSucceeded, cause: $cause)';
}
