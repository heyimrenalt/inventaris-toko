import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/widgets/danger_button.dart';

void main() {
  testWidgets('renders label, calls onPressed, and uses the red-primary fill', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DangerButton(label: 'Hapus', onPressed: () => tapped = true),
      ),
    ));

    expect(find.text('Hapus'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final resolvedBackground = button.style?.backgroundColor?.resolve(<WidgetState>{});
    expect(resolvedBackground, AppColors.redPrimary);

    await tester.tap(find.byType(DangerButton));
    expect(tapped, isTrue);
  });
}
