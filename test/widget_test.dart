import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventaris_toko/ui/navigation/main_scaffold.dart';
import 'package:isar_community/isar.dart';

import 'data/repositories/test_isar.dart';

void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  testWidgets('all 4 tabs render and can be switched without crashing', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MainScaffold(isar: isar)));
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Produk'), findsOneWidget);
    expect(find.text('Mutasi'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Beranda — belum diimplementasikan'), findsOneWidget);

    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();
    expect(find.text('Produk — belum diimplementasikan'), findsOneWidget);

    await tester.tap(find.text('Mutasi'));
    await tester.pumpAndSettle();
    expect(find.text('Mutasi — belum diimplementasikan'), findsOneWidget);

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Kelola kategori'), findsOneWidget);
  });
}
