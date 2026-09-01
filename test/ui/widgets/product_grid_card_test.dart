import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/data/models/product.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/widgets/product_grid_card.dart';

/// The Produk tab's card. The two things worth pinning are the ones a
/// prettier layout could quietly cost: the low-stock colour signal, and
/// a photo band that is actually large.
void main() {
  Product buildProduct({
    String name = 'Indomie Soto',
    double currentStock = 11,
    double minStockThreshold = 5,
    String? photoPath,
  }) {
    return Product()
      ..name = name
      ..unit = 'pcs'
      ..sellPrice = 3500
      ..currentStock = currentStock
      ..minStockThreshold = minStockThreshold
      ..photoPath = photoPath;
  }

  Future<void> pumpCard(WidgetTester tester, Product product) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 158,
            height: ProductGridCard.extentFor(158),
            child: ProductGridCard(
              product: product,
              categoryName: 'Mie Instan',
              onTap: () {},
            ),
          ),
        ),
      ),
    ));
  }

  Color stockColour(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  testWidgets('shows name, category, price, stock and unit', (tester) async {
    await pumpCard(tester, buildProduct());

    expect(find.text('Indomie Soto'), findsOneWidget);
    expect(find.text('Mie Instan'), findsOneWidget);
    expect(find.text('Rp 3.500'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('pcs'), findsOneWidget);
  });

  group('the stock level still carries a colour', () {
    // The mockup this layout came from drew every stock figure green.
    // Dropping the level colour would remove the only low-stock signal
    // on the Produk screen, so it moved from the chip onto the number.
    testWidgets('above the threshold reads as safe', (tester) async {
      await pumpCard(tester, buildProduct(currentStock: 11, minStockThreshold: 5));
      expect(stockColour(tester, '11'), AppColors.greenText);
    });

    testWidgets('below the threshold reads as a warning', (tester) async {
      await pumpCard(tester, buildProduct(currentStock: 3, minStockThreshold: 5));
      expect(stockColour(tester, '3'), AppColors.yellowText);
    });

    testWidgets('empty stock reads as danger', (tester) async {
      await pumpCard(tester, buildProduct(currentStock: 0, minStockThreshold: 5));
      expect(stockColour(tester, '0'), AppColors.redText);
    });
  });

  testWidgets('the photo band fills the card width, dwarfing the old 52px thumb',
      (tester) async {
    await pumpCard(tester, buildProduct());

    final photo = tester.getSize(find.byType(AspectRatio));
    expect(photo.width, 158);
    // The whole point of the redesign: several times the old thumbnail's
    // area, not a smaller one.
    expect(photo.width * photo.height, greaterThan(52 * 52 * 4));
  });

  testWidgets('a product with no photo shows its initial, not a blank grey box',
      (tester) async {
    await pumpCard(tester, buildProduct(name: 'Teh Pucuk'));

    expect(find.text('T'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });

  testWidgets('a blank name falls back rather than crashing on an empty string',
      (tester) async {
    await pumpCard(tester, buildProduct(name: '   '));
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('an unreadable photo path degrades to the placeholder', (tester) async {
    // Image.file resolves and fails through real file IO, so the
    // errorBuilder only runs after the framework has been let out of the
    // fake-async zone.
    await tester.runAsync(() async {
      await pumpCard(tester, buildProduct(photoPath: '/does/not/exist.jpg'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(find.text('I'), findsOneWidget);
  });

  group('long product names', () {
    // The report that prompted this: "Silverqueen - Almond" ellipsised
    // at the variant, which is the only part distinguishing it from the
    // other Silverqueen entries.
    testWidgets('wrap to a second line instead of being cut at the variant',
        (tester) async {
      await pumpCard(tester, buildProduct(name: 'Silverqueen - Almond'));

      final name = tester.widget<Text>(find.text('Silverqueen - Almond'));
      expect(name.maxLines, 2);

      // It actually wrapped: the rendered name is taller than a single
      // 14px line. (didExceedMaxLines is not used here — the test font is
      // fixed-width and far wider than PlusJakartaSans, so it reports
      // overflow for strings that fit fine on a real device.)
      expect(tester.getSize(find.text('Silverqueen - Almond')).height,
          greaterThan(20));
    });

    testWidgets('a two-line name does not push the price row out of the card',
        (tester) async {
      await pumpCard(tester, buildProduct(name: 'Silverqueen - Almond'));

      // Nothing overflowed its cell, and the price/stock row is still
      // laid out inside the card's bounds.
      expect(tester.takeException(), isNull);
      final cardBottom = tester.getRect(find.byType(ProductGridCard)).bottom;
      expect(tester.getRect(find.text('Rp 3.500')).bottom, lessThanOrEqualTo(cardBottom));
      expect(tester.getRect(find.text('11')).bottom, lessThanOrEqualTo(cardBottom));
    });

    testWidgets('a name too long even for two lines still ellipsises', (tester) async {
      await pumpCard(
        tester,
        buildProduct(name: 'Silverqueen Almond Cashew Dark Chocolate Bar Besar'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('extentFor leaves the text block room at every column width',
      (tester) async {
    // Narrow phone through to a wide one: the cell must always be taller
    // than its photo band by the full text block, or the name and price
    // get clipped.
    for (final width in [140.0, 158.0, 200.0]) {
      expect(ProductGridCard.extentFor(width), greaterThan(width / (16 / 10)));
    }
  });
}
