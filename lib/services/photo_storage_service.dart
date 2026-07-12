import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum PhotoPickSource { camera, gallery }

/// Thrown by [PhotoStorageService.pickAndSavePhoto] when the OS denies
/// camera/gallery access, so callers can show a specific message instead
/// of silently doing nothing (which would look identical to the user
/// simply cancelling the picker).
class PhotoPermissionDeniedException implements Exception {
  const PhotoPermissionDeniedException();
}

/// Abstracts photo selection + persistence so widgets don't talk to
/// `image_picker`/the filesystem directly. Tests inject a fake
/// implementation instead of driving the real OS picker.
abstract class PhotoStorageService {
  /// Prompts the user to pick a photo from [source] and copies it into
  /// permanent app storage. Returns the new permanent path, or `null` if
  /// the user cancelled the picker.
  ///
  /// Throws [PhotoPermissionDeniedException] if the OS denies camera or
  /// gallery access.
  Future<String?> pickAndSavePhoto(PhotoPickSource source);

  /// Deletes a previously saved photo file. Safe to call even if the
  /// file no longer exists.
  Future<void> deletePhoto(String path);
}

class ImagePickerPhotoStorageService implements PhotoStorageService {
  const ImagePickerPhotoStorageService();

  static const String _photosDirName = 'product_photos';

  @override
  Future<String?> pickAndSavePhoto(PhotoPickSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source == PhotoPickSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
    } on PlatformException {
      throw const PhotoPermissionDeniedException();
    }

    if (picked == null) {
      return null;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(documentsDir.path, _photosDirName));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().microsecondsSinceEpoch}${p.extension(picked.path)}';
    final destination = p.join(photosDir.path, fileName);
    await File(picked.path).copy(destination);
    return destination;
  }

  @override
  Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Best-effort cleanup; an already-missing or locked file isn't
      // worth surfacing to the user.
    }
  }
}
