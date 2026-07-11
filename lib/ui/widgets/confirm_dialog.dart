import 'package:flutter/material.dart';

/// Shows a confirmation dialog and returns `true` if the user confirmed,
/// `false`/`null` otherwise. Used anywhere a destructive or otherwise
/// non-reversible action needs an explicit second tap before it happens.
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Batal',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: Text(message, style: const TextStyle(fontSize: 16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel, style: const TextStyle(fontSize: 16)),
        ),
        TextButton(
          style: isDestructive
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel, style: const TextStyle(fontSize: 16)),
        ),
      ],
    ),
  );
}
