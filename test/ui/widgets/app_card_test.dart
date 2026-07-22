import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/app_card.dart';

void main() {
  testWidgets('renders its child', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppCard(child: Text('Isi kartu'))),
    ));

    expect(find.text('Isi kartu'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppCard(onTap: () => tapped = true, child: const Text('Isi kartu')),
      ),
    ));

    await tester.tap(find.byType(AppCard));
    expect(tapped, isTrue);
  });

  testWidgets('is not tappable when onTap is omitted', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppCard(child: Text('Isi kartu'))),
    ));

    expect(find.byType(InkWell), findsNothing);
  });
}
