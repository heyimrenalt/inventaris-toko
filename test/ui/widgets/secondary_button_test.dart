import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/widgets/secondary_button.dart';

void main() {
  testWidgets('renders label and calls onPressed when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SecondaryButton(label: 'Batal', onPressed: () => tapped = true),
      ),
    ));

    expect(find.text('Batal'), findsOneWidget);
    await tester.tap(find.byType(SecondaryButton));
    expect(tapped, isTrue);
  });

  testWidgets('disabled state is non-tappable', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SecondaryButton(label: 'Batal', onPressed: null),
      ),
    ));

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.enabled, isFalse);
  });
}
