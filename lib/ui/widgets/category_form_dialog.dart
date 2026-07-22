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
  return showDialog<Category>(
    context: context,
    builder: (dialogContext) => _CategoryFormDialog(
      repository: repository,
      existing: existing,
      parentId: parentId,
    ),
  );
}

/// A dedicated [StatefulWidget] (rather than a bare [TextEditingController]
/// captured by the enclosing function + a `StatefulBuilder`) so its
/// controller is created in `initState` and disposed only in `dispose` —
/// disposing it right after `showDialog`'s Future resolves (as this used
/// to do) races the dialog's own exit-transition animation: the
/// `AlertDialog`/`TextField` stay mounted and the field's `EditableText`
/// stays listening on the controller for the duration of that animation,
/// so an immediate dispose there is a real "disposed while still
/// listened" bug, not just a leak. Owning the controller through the
/// normal State lifecycle instead means Flutter itself only calls
/// `dispose()` once the widget is actually gone.
class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.repository,
    required this.existing,
    required this.parentId,
  });

  final CategoryRepository repository;
  final Category? existing;
  final int? parentId;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final Category result;
      final existing = widget.existing;
      if (existing == null) {
        result = await widget.repository.create(_controller.text, parentId: widget.parentId);
      } else {
        result = await widget.repository.rename(existing.id, _controller.text);
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ValidationException {
      if (!mounted) return;
      setState(() => _errorText = 'Nama kategori tidak boleh kosong');
    } on DuplicateCategoryNameException {
      if (!mounted) return;
      setState(() => _errorText = 'Kategori dengan nama ini sudah ada');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Tambah Kategori' : 'Ubah Kategori',
        style: const TextStyle(fontSize: 18),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: 'Nama kategori',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Simpan', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
