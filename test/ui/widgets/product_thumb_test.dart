import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/product_thumb.dart';

void main() {
  testWidgets('renders a package icon placeholder at the default size', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProductThumb()),
    ));

    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

    final sizedContainer = tester.widget<Container>(find.byType(Container));
    expect(sizedContainer.constraints?.maxWidth ?? 52, 52);
  });

  testWidgets('honors a custom size', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProductThumb(size: 96)),
    ));

    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}
