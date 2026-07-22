import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/section_header.dart';

void main() {
  testWidgets('renders the title with no trailing link by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SectionHeader(title: 'Prioritas kulakan')),
    ));

    expect(find.text('Prioritas kulakan'), findsOneWidget);
    expect(find.text('Lihat semua'), findsNothing);
  });

  testWidgets('renders and taps the trailing action link', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SectionHeader(
          title: 'Prioritas kulakan',
          actionLabel: 'Lihat semua',
          onActionTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Lihat semua'), findsOneWidget);
    await tester.tap(find.text('Lihat semua'));
    expect(tapped, isTrue);
  });
}
