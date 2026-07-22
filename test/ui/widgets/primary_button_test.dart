import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/widgets/primary_button.dart';

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onPressed}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrimaryButton(label: 'Simpan', onPressed: onPressed),
      ),
    ));
  }

  testWidgets('renders label and calls onPressed when tapped', (tester) async {
    var tapped = false;
    await pump(tester, onPressed: () => tapped = true);

    expect(find.text('Simpan'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    expect(tapped, isTrue);
  });

  testWidgets('disabled state renders gray and is non-tappable', (tester) async {
    await pump(tester, onPressed: null);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.enabled, isFalse);

    final resolvedBackground = button.style?.backgroundColor
        ?.resolve({WidgetState.disabled});
    expect(resolvedBackground, AppColors.gray300);

    final resolvedForeground = button.style?.foregroundColor
        ?.resolve({WidgetState.disabled});
    expect(resolvedForeground, AppColors.gray500);
  });
}
