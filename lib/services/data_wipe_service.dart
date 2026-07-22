import 'package:isar_community/isar.dart';

import '../data/models/app_settings.dart';
import '../data/models/category.dart';
import '../data/models/cost_price_adjustment.dart';
import '../data/models/product.dart';
import '../data/models/restock_list.dart';
import '../data/models/stock_mutation.dart';
import '../data/repositories/repository_exceptions.dart';
import 'notification_service.dart';
import 'photo_storage_service.dart';

/// Wipes every piece of data this app holds — every Isar collection, every
/// saved product photo file, and every scheduled/shown notification. Used
/// exclusively by "Hapus semua data" in Pengaturan, behind its own
/// triple-confirmation flow (see `PengaturanScreen`) — there is no other
/// caller, since this is irreversible.
abstract class DataWipeService {
  Future<void> wipeAll();
}

class IsarDataWipeService implements DataWipeService {
  IsarDataWipeService(this._isar, {PhotoStorageService? photoStorageService})
      : _photoStorageService = photoStorageService ?? const ImagePickerPhotoStorageService();

  final Isar _isar;
  final PhotoStorageService _photoStorageService;

  @override
  Future<void> wipeAll() async {
    final photoPaths = (await _isar.products.where().findAll())
        .map((product) => product.photoPath)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();

    // A single atomic transaction: if any collection's clear() throws,
    // Isar rolls the whole thing back, so a failure here never leaves a
    // half-wiped database. Only if this itself can't commit does the
    // best-effort per-collection fallback below even run.
    try {
      await _isar.writeTxn(() async {
        await _isar.categories.clear();
        await _isar.products.clear();
        await _isar.stockMutations.clear();
        // Clearing (rather than resetting field-by-field) is also how
        // "reset AppSettings to defaults" is satisfied here: the next
        // AppSettingsRepository.get() recreates the singleton row from
        // its own default values, the same as a fresh install.
        await _isar.appSettings.clear();
        await _isar.costPriceAdjustments.clear();
        await _isar.restockLists.clear();
      });
    } catch (_) {
      final stillFailing = await _clearCollectionsIndividually();
      if (stillFailing.isNotEmpty) {
        throw DataWipeException(stillFailing);
      }
    }

    for (final path in photoPaths) {
      await _photoStorageService.deletePhoto(path);
    }

    try {
      await NotificationService.cancelAll();
    } catch (_) {
      // Best-effort: the data wipe itself already succeeded by this
      // point, so a notification-cancellation glitch shouldn't surface
      // to the user as a failed wipe.
    }
  }

  /// Fallback for when the single atomic transaction above couldn't
  /// commit: clears each collection in its own transaction, so a failure
  /// on one doesn't block the others from still being wiped. Returns the
  /// names of any collections that still couldn't be cleared, for
  /// [DataWipeException].
  Future<List<String>> _clearCollectionsIndividually() async {
    final clears = <String, Future<void> Function()>{
      'categories': () => _isar.categories.clear(),
      'products': () => _isar.products.clear(),
      'stockMutations': () => _isar.stockMutations.clear(),
      'appSettings': () => _isar.appSettings.clear(),
      'costPriceAdjustments': () => _isar.costPriceAdjustments.clear(),
      'restockLists': () => _isar.restockLists.clear(),
    };

    final failures = <String>[];
    for (final entry in clears.entries) {
      try {
        await _isar.writeTxn(entry.value);
      } catch (_) {
        failures.add(entry.key);
      }
    }
    return failures;
  }
}
