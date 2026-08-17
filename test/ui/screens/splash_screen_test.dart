import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/screens/splash_screen.dart';
import 'package:inventaris_toko/ui/widgets/app_logo.dart';

void main() {
  testWidgets('shows the logo, app name and tagline', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Toko Mama'), findsOneWidget);
    expect(find.text('Kelola stok, tanpa ribet'), findsOneWidget);
  });

  testWidgets('fades in "Menyiapkan data..." once startup drags past 3s',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Menyiapkan data...'), findsNothing);

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Menyiapkan data...'), findsOneWidget);
    final fade = tester.widget<FadeTransition>(
      find.byKey(const Key('splash_slow_message')),
    );
    expect(fade.opacity.value, 1.0, reason: 'appeared without fading in');
  });

  testWidgets('never shows the slow-start message when init finishes first',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Menyiapkan data...'), findsNothing);

    // Stands in for the FutureBuilder swapping the splash out for the real
    // app. A leaked slow-start timer would surface here as a "Timer is
    // still pending" failure at the end of the test.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 3500));

    expect(find.text('Menyiapkan data...'), findsNothing);
  });
}
