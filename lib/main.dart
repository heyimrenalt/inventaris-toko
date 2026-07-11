import 'package:flutter/material.dart';

import 'data/isar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarService.open();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventaris Toko',
      home: Scaffold(
        body: Center(
          child: Text('Setup OK'),
        ),
      ),
    );
  }
}
