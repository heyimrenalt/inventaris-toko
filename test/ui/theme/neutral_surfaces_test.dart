import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/theme/app_colors.dart';
import 'package:inventaris_toko/ui/theme/app_theme.dart';

/// The seed-derived `surfaceContainer*` family used to be blended towards
/// the green seed, which leaked into every Material 3 surface that falls
/// back to it (dialogs, bottom sheets). These guard that the whole family
/// — and the surfaces built on it — stay neutral.
void main() {
  bool isNeutral(Color c) =>
      ((c.r - c.g).abs() < 0.004) && ((c.g - c.b).abs() < 0.004);

  test('every surface container tone is a neutral grey', () {
    final scheme = AppTheme.light.colorScheme;
    for (final color in <Color>[
      scheme.surface,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    ]) {
      expect(isNeutral(color), isTrue, reason: '$color is tinted');
    }
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.scaffoldBackground);
  });

  testWidgets('a Scaffold and a dialog both render neutral backgrounds',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('Tambah Kategori')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    final scaffoldMaterial = tester.widget<Material>(
      find
          .descendant(of: find.byType(Scaffold), matching: find.byType(Material))
          .first,
    );
    expect(scaffoldMaterial.color, AppColors.scaffoldBackground);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialogMaterial = tester.widget<Material>(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );
    expect(dialogMaterial.color, AppColors.white);
  });
}
