import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/screens/pengaturan/tentang_aplikasi_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../widget_test_helpers.dart';

void main() {
  Future<PackageInfo> fakeLoader() async => PackageInfo(
        appName: 'inventaris_toko',
        packageName: 'com.example.inventaris_toko',
        version: '1.0.0',
        buildNumber: '1',
      );

  testWidgets('renders without crashing', (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        await tester.pumpWidget(
          MaterialApp(home: TentangAplikasiScreen(packageInfoLoader: fakeLoader)),
        );
        await settleAfterAsyncWork(tester);

        expect(find.byType(TentangAplikasiScreen), findsOneWidget);
      });
    });
  });

  testWidgets('shows the version reported by package_info_plus', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: TentangAplikasiScreen(packageInfoLoader: fakeLoader)),
      );
      await settleAfterAsyncWork(tester);

      final versionText = tester.widget<Text>(find.byKey(const Key('tentang_aplikasi_version')));
      expect(versionText.data, 'Versi 1.0.0');
    });
  });

  testWidgets('falls back to "-" when the package_info lookup fails, without crashing',
      (tester) async {
    await tester.runAsync(() async {
      await expectNoFlutterErrors(tester, () async {
        await tester.pumpWidget(
          MaterialApp(
            home: TentangAplikasiScreen(
              packageInfoLoader: () async => throw Exception('simulated lookup failure'),
            ),
          ),
        );
        await settleAfterAsyncWork(tester);
      });

      final versionText = tester.widget<Text>(find.byKey(const Key('tentang_aplikasi_version')));
      expect(versionText.data, 'Versi -');
    });
  });

  testWidgets("app name matches the app's known display name", (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: TentangAplikasiScreen(packageInfoLoader: fakeLoader)),
      );
      await settleAfterAsyncWork(tester);

      final nameText = tester.widget<Text>(find.byKey(const Key('tentang_aplikasi_app_name')));
      expect(nameText.data, TentangAplikasiScreen.appName);
      expect(nameText.data, 'Inventaris Toko');
    });
  });

  testWidgets('back navigation returns to the previous screen', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TentangAplikasiScreen(packageInfoLoader: fakeLoader),
                  ),
                ),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Buka'));
      await settleAfterAsyncWork(tester);
      expect(find.byType(TentangAplikasiScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TentangAplikasiScreen), findsNothing);
      expect(find.text('Buka'), findsOneWidget);
    });
  });

  testWidgets('tapping the app icon 5 times shows the easter-egg SnackBar', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: TentangAplikasiScreen(packageInfoLoader: fakeLoader)),
      );
      await settleAfterAsyncWork(tester);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('tentang_aplikasi_icon')));
        await tester.pump();
      }
      await tester.pump();

      expect(find.text('Terima kasih sudah pakai Inventaris Toko!'), findsOneWidget);
    });
  });
}
