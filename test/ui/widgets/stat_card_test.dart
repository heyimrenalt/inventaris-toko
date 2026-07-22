import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/stat_card.dart';

void main() {
  testWidgets('renders label, value, and subtitle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatCard(
          label: 'Total produk',
          value: '48',
          subtitle: 'produk aktif',
          variant: StatCardVariant.green,
        ),
      ),
    ));

    expect(find.text('Total produk'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('produk aktif'), findsOneWidget);
  });

  testWidgets('renders without a subtitle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatCard(label: 'Perlu kulakan', value: '5', variant: StatCardVariant.red),
      ),
    ));

    expect(find.text('Perlu kulakan'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
