import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: call IsarService.open() once real schemas exist (Task 1).
  // Isar.open() throws if the schemas list is empty, so it can't be
  // wired in until there's at least one collection to pass.
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
