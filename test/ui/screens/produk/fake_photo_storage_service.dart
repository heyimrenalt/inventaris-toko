import 'package:inventaris_toko/services/photo_storage_service.dart';

/// Test double for [PhotoStorageService]. The real implementation drives
/// the OS image picker, which can't be reliably automated in a widget
/// test — this returns a known fake path instead, so tests can verify
/// the widget correctly displays/saves whatever the service returns
/// without touching the OS picker UI.
class FakePhotoStorageService implements PhotoStorageService {
  FakePhotoStorageService({this.pathToReturn = '/fake/photos/photo.jpg'});

  final String? pathToReturn;
  final List<String> deletedPaths = [];
  int pickCallCount = 0;

  @override
  Future<String?> pickAndSavePhoto(PhotoPickSource source) async {
    pickCallCount++;
    return pathToReturn;
  }

  @override
  Future<void> deletePhoto(String path) async {
    deletedPaths.add(path);
  }

  final List<List<int>> writtenBytes = [];

  @override
  Future<String> writePhotoBytes(List<int> bytes, {required String extension}) async {
    writtenBytes.add(bytes);
    return '/fake/photos/restored_${writtenBytes.length}$extension';
  }
}
