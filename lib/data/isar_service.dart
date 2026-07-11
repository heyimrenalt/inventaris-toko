import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  IsarService._();

  static Isar? _instance;

  static Future<Isar> open() async {
    if (_instance != null) {
      return _instance!;
    }

    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      // TODO: add schemas here in Task 1
      [],
      directory: dir.path,
    );

    return _instance!;
  }

  static Isar get instance {
    final isar = _instance;
    if (isar == null) {
      throw StateError('IsarService.open() must be called before accessing instance.');
    }
    return isar;
  }
}
