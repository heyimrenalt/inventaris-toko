import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/widgets/app_header.dart';

void main() {
  group('AppHeader', () {
    testWidgets('renders with title text', (WidgetTester tester) async {
      const testTitle = 'Test Screen';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(title: testTitle),
          ),
        ),
      );

      expect(find.text(testTitle), findsOneWidget);
    });

    testWidgets('title text is bold (heading style)', (WidgetTester tester) async {
      const testTitle = 'Test Screen';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(title: testTitle),
          ),
        ),
      );

      final textWidget = find.byType(Text);
      expect(textWidget, findsOneWidget);

      final text = tester.widget<Text>(textWidget);
      expect(text.style?.fontWeight, FontWeight.w800);
      expect(text.style?.fontSize, 20);
    });

    testWidgets('has white background', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(title: 'Test'),
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, AppColors.white);
    });

    testWidgets('title is left-aligned (centerTitle is false)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(title: 'Test'),
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.centerTitle, false);
    });

    testWidgets('elevation is 0', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(title: 'Test'),
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.elevation, 0);
    });

    testWidgets('scrolledUnderElevation is 0', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(title: 'Test'),
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.scrolledUnderElevation, 0);
    });

    testWidgets('preferredSize height is 56', (WidgetTester tester) async {
      const header = AppHeader(title: 'Test');
      expect(header.preferredSize.height, 56);
    });

    testWidgets('withBack renders back button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppHeader.withBack(
              title: 'Detail Screen',
              onBack: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('withBack back button invokes callback', (WidgetTester tester) async {
      bool backPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppHeader.withBack(
              title: 'Detail Screen',
              onBack: () => backPressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      expect(backPressed, true);
    });

    testWidgets('renders with trailing widget', (WidgetTester tester) async {
      const testTrailing = Text('Action');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(
              title: 'Test',
              trailing: testTrailing,
            ),
          ),
        ),
      );

      expect(find.text('Action'), findsOneWidget);
    });

    testWidgets('back arrow color is dark', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppHeader.withBack(
              title: 'Detail',
              onBack: () {},
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded));
      expect(icon.color, AppColors.darkText);
    });

    testWidgets('no leading widget when not using withBack', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(title: 'Test'),
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leading, null);
    });

    testWidgets('title text color is dark', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(title: 'Test Title'),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, AppColors.darkText);
    });
  });
}
