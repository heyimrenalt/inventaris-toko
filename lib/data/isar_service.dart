import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/app_settings.dart';
import 'models/category.dart';
import 'models/cost_price_adjustment.dart';
import 'models/product.dart';
import 'models/stock_mutation.dart';

class IsarService {
  IsarService._();

  static Isar? _instance;

  static Future<Isar> open() async {
    if (_instance != null) {
      return _instance!;
    }

    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      [
        CategorySchema,
        ProductSchema,
        StockMutationSchema,
        AppSettingsSchema,
        CostPriceAdjustmentSchema,
      ],
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
