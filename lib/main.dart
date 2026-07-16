import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:isar_community/isar.dart';

import 'data/isar_service.dart';
import 'services/notification_service.dart';
import 'ui/navigation/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventaris Toko',
      navigatorKey: NotificationService.navigatorKey,
      // Every screen in this app is already hand-written in Indonesian;
      // the only place this locale setting actually matters is Flutter's
      // own built-in components (the date range picker, specifically) —
      // it switches their date parsing/formatting to Indonesian's
      // day-month-year convention (via intl's per-locale CLDR data)
      // instead of defaulting to US month-day-year.
      locale: const Locale('id'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')],
      home: FutureBuilder<Isar>(
        future: _openAndInitialize(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Gagal membuka database: ${snapshot.error}'),
              ),
            );
          }
          return MainScaffold(isar: snapshot.data!);
        },
      ),
    );
  }

  Future<Isar> _openAndInitialize() async {
    final isar = await IsarService.open();
    await NotificationService.initialize();
    return isar;
  }
}
