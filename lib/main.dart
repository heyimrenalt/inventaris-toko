import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:isar_community/isar.dart';

import 'data/isar_service.dart';
import 'data/repositories/app_settings_repository.dart';
import 'services/notification_service.dart';
import 'ui/navigation/main_scaffold.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventaris Toko',
      navigatorKey: NotificationService.navigatorKey,
      theme: AppTheme.light,
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
    // Fire-and-forget: restores any notifications lost to a force-stop or
    // reboot since the app was last opened. Not awaited so it never
    // delays the first frame — cancel+reschedule is a handful of cheap
    // OS alarm/work-manager calls, not a heavy Isar query.
    unawaited(_rescheduleNotifications(isar));
    return isar;
  }

  Future<void> _rescheduleNotifications(Isar isar) async {
    final settings = await AppSettingsRepository(isar).get();
    await NotificationService.scheduleDailySummary(settings);
    await NotificationService.scheduleCriticalStockAlerts(settings);
  }
}
