import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:isar_community/isar.dart';

import 'data/isar_service.dart';
import 'data/migrations/mutation_snapshot_backfill.dart';
import 'data/repositories/app_settings_repository.dart';
import 'services/notification_service.dart';
import 'ui/navigation/main_scaffold.dart';
import 'ui/screens/splash_min_duration.dart';
import 'ui/screens/splash_screen.dart';
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  /// Floor on how long the splash stays up. See [withMinimumDuration] for
  /// why startup is deliberately not allowed to be instant.
  static const minimumSplashDuration = Duration(milliseconds: 1500);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Created once here rather than in `build()`: a FutureBuilder whose
  /// future is rebuilt on every MaterialApp rebuild would re-run the whole
  /// open-and-migrate sequence and throw the app back to the splash.
  late final Future<Isar> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initWithMinDuration();
  }

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
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SplashScreen();
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

  /// Runs startup behind the splash's minimum-duration floor, and reports
  /// how long the real work actually took. The timing is console-only
  /// observability — nothing branches on it — and the case worth watching
  /// (the post-upgrade backfill on a real device with real data) is one no
  /// dev-machine run can reproduce.
  Future<Isar> _initWithMinDuration() async {
    final stopwatch = Stopwatch()..start();
    // Timed around the real work only, not around the gate — a number that
    // reads 1500ms on every fast launch would tell us nothing.
    final init = _openAndInitialize().whenComplete(() {
      stopwatch.stop();
      debugPrint(
        '[splash] init completed in ${stopwatch.elapsedMilliseconds}ms',
      );
    });
    return withMinimumDuration(init, MyApp.minimumSplashDuration);
  }

  Future<Isar> _openAndInitialize() async {
    final isar = await IsarService.open();
    // Awaited, unlike the notification reschedule below: profit figures
    // read straight off the mutation ledger, so the first frame must not
    // render numbers computed from half-backfilled snapshots. It's a
    // guarded one-shot pass — a no-op on every launch after the first.
    await MutationSnapshotBackfill(isar).runIfNeeded();
    await NotificationService.initialize();
    // Fire-and-forget: restores any notifications lost to a force-stop or
    // reboot since the app was last opened. Not awaited so it never
    // delays the first frame — cancel+reschedule is a handful of cheap
    // OS alarm/work-manager calls, not a heavy Isar query.
    unawaited(_rescheduleNotifications(isar));
    // Ordering matters: this routes to a screen built from
    // IsarService.instance, so it must run after IsarService.open() above.
    // Fire-and-forget for the same reason as the reschedule — it defers
    // its own navigation to the next frame anyway.
    unawaited(NotificationService.handleNotificationLaunch());
    return isar;
  }

  Future<void> _rescheduleNotifications(Isar isar) async {
    final settings = await AppSettingsRepository(isar).get();
    await NotificationService.scheduleDailySummary(settings);
    await NotificationService.scheduleCriticalStockAlerts(settings);
  }
}
