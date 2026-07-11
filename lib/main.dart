import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import 'data/isar_service.dart';
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
      home: FutureBuilder<Isar>(
        future: IsarService.open(),
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
}
