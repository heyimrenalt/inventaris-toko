import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/screens/pengaturan/faq_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FaqScreen()));
    await tester.pumpAndSettle();
  }

  /// Every question has to be scrolled to before it can be tapped or
  /// asserted on — 11 rows overflow the default 600px test viewport.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 100, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('renders all 11 questions', (tester) async {
    await pumpScreen(tester);

    expect(faqItems, hasLength(11));
    for (final item in faqItems) {
      await scrollTo(tester, find.text(item.question));
      expect(find.text(item.question), findsOneWidget);
    }
  });

  testWidgets('answers are hidden until their question is tapped', (tester) async {
    await pumpScreen(tester);

    final item = faqItems.first;
    expect(find.text(item.answer), findsNothing);

    await tester.tap(find.text(item.question));
    await tester.pumpAndSettle();
    expect(find.text(item.answer), findsOneWidget);
  });

  testWidgets('tapping an open question collapses its answer again', (tester) async {
    await pumpScreen(tester);

    final item = faqItems.first;
    await tester.tap(find.text(item.question));
    await tester.pumpAndSettle();
    expect(find.text(item.answer), findsOneWidget);

    await tester.tap(find.text(item.question));
    await tester.pumpAndSettle();
    expect(find.text(item.answer), findsNothing);
  });

  testWidgets('the bulleted item reveals its bullets when expanded', (tester) async {
    await pumpScreen(tester);

    final item = faqItems.last;
    expect(item.bullets, hasLength(11));

    await scrollTo(tester, find.text(item.question));
    await tester.tap(find.text(item.question));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(item.bullets.first));
    expect(find.text(item.bullets.first), findsOneWidget);
  });

  /// Guards against the clipping bug: expanded, item 11 is taller than the
  /// viewport, so its very last bullet is only reachable if the whole card
  /// scrolls instead of being cut off at the bottom edge.
  testWidgets('the last bullet of item 11 is scrollable into view', (tester) async {
    await pumpScreen(tester);

    final item = faqItems.last;
    await scrollTo(tester, find.text(item.question));
    await tester.tap(find.text(item.question));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(item.bullets.last));
    expect(find.text(item.bullets.last), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
