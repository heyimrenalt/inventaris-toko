import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/widgets/status_badge.dart';

void main() {
  Color textColorOf(WidgetTester tester) {
    final text = tester.widget<Text>(find.byType(Text));
    return text.style!.color!;
  }

  Color fillColorOf(WidgetTester tester) {
    final container = tester.widget<Container>(find.byType(Container));
    return (container.decoration as BoxDecoration).color!;
  }

  testWidgets('success variant uses the green subtle/text pair', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatusBadge(text: 'Stok aman', variant: StatusBadgeVariant.success),
      ),
    ));

    expect(find.text('Stok aman'), findsOneWidget);
    expect(fillColorOf(tester), AppColors.greenSubtle);
    expect(textColorOf(tester), AppColors.greenText);
  });

  testWidgets('warning variant uses the yellow subtle/text pair', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatusBadge(text: '3 hari lagi', variant: StatusBadgeVariant.warning),
      ),
    ));

    expect(fillColorOf(tester), AppColors.yellowSubtle);
    expect(textColorOf(tester), AppColors.yellowText);
  });

  testWidgets('danger variant uses the red subtle/text pair', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatusBadge(text: 'Stok habis', variant: StatusBadgeVariant.danger),
      ),
    ));

    expect(fillColorOf(tester), AppColors.redSubtle);
    expect(textColorOf(tester), AppColors.redText);
  });
}
