import 'package:flutter/material.dart';

/// Generic "not implemented yet" screen body used by tabs/settings items
/// that don't have real functionality in this task.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
