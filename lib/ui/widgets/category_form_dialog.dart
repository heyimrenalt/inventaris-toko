import 'package:flutter/material.dart';

import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/repository_exceptions.dart';

/// Shows the add/rename category dialog and returns the created/renamed
/// [Category] on success, or `null` if the user cancelled. Shared between
/// Kelola Kategori (Pengaturan), [CategoryTreePicker]'s inline add
/// affordances, and the product form, so the name-validation UX only
/// lives in one place.
///
/// [parentId] only applies when creating (i.e. when [existing] is null):
/// it's the parent to create the new category under (`null` for a root
/// category). A rename keeps the category's existing parent, since
/// re-parenting is out of scope for this dialog.
Future<Category?> showCategoryFormDialog({
  required BuildContext context,
  required CategoryRepository repository,
  Category? existing,
  int? parentId,
}) {
  final controller = TextEditingController(text: existing?.name ?? '');
  String? errorText;

  return showDialog<Category>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            try {
              final Category result;
              if (existing == null) {
                result = await repository.create(controller.text, parentId: parentId);
              } else {
                result = await repository.rename(existing.id, controller.text);
              }
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(result);
            } on ValidationException {
              setDialogState(() => errorText = 'Nama kategori tidak boleh kosong');
            } on DuplicateCategoryNameException {
              setDialogState(() => errorText = 'Kategori dengan nama ini sudah ada');
            }
          }

          return AlertDialog(
            title: Text(
              existing == null ? 'Tambah Kategori' : 'Ubah Kategori',
              style: const TextStyle(fontSize: 18),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Nama kategori',
                errorText: errorText,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Batal', style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: submit,
                child: const Text('Simpan', style: TextStyle(fontSize: 16)),
              ),
            ],
          );
        },
      );
    },
  );
}
