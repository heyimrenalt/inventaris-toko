import 'package:flutter_test/flutter_test.dart';

import 'package:inventaris_toko/main.dart';

void main() {
  testWidgets('App boots and shows setup confirmation', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Setup OK'), findsOneWidget);
  });
}
