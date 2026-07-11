import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import 'kelola_kategori_screen.dart';

class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key, required this.isar});

  final Isar isar;

  void _showNotAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur ini belum tersedia')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const _SectionHeader('Produk'),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.category),
            title: const Text('Kelola kategori', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => KelolaKategoriScreen(isar: isar)),
              );
            },
          ),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.rule),
            title: const Text('Batas minimum stok default', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotAvailable(context),
          ),
          const _SectionHeader('Data'),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.backup),
            title: const Text('Cadangkan data', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotAvailable(context),
          ),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.restore),
            title: const Text('Pulihkan data', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotAvailable(context),
          ),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Hapus semua data',
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotAvailable(context),
          ),
          const _SectionHeader('Lainnya'),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang aplikasi', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotAvailable(context),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
