import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/widgets/stock_badge.dart';

void main() {
  Color textColorOf(WidgetTester tester) {
    final text = tester.widget<Text>(find.byType(Text));
    return text.style!.color!;
  }

  Color fillColorOf(WidgetTester tester) {
    final container = tester.widget<Container>(find.byType(Container));
    return (container.decoration as BoxDecoration).color!;
  }

  testWidgets('safe level uses the green subtle/text pair', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StockBadge(text: '45', level: StockLevel.safe)),
    ));

    expect(find.text('45'), findsOneWidget);
    expect(fillColorOf(tester), AppColors.greenSubtle);
    expect(textColorOf(tester), AppColors.greenText);
  });

  testWidgets('warning level uses the yellow subtle/text pair', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StockBadge(text: '8', level: StockLevel.warning)),
    ));

    expect(fillColorOf(tester), AppColors.yellowSubtle);
    expect(textColorOf(tester), AppColors.yellowText);
  });

  testWidgets('danger level uses the red subtle/text pair', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StockBadge(text: '0', level: StockLevel.danger)),
    ));

    expect(fillColorOf(tester), AppColors.redSubtle);
    expect(textColorOf(tester), AppColors.redText);
  });
}
