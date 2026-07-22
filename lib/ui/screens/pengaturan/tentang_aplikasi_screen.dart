import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../widgets/app_header.dart';

/// Simple, static "about" page — no external links and nothing editable,
/// since this is an offline-first app with no feedback/support surface to
/// send the user to.
class TentangAplikasiScreen extends StatefulWidget {
  const TentangAplikasiScreen({super.key, this.packageInfoLoader});

  static const String appName = 'Inventaris Toko';

  // TODO(dev): fill in the real developer/publisher name once decided.
  static const String developerName = 'Developer';

  /// Test seam only — real callers always let this default to
  /// [PackageInfo.fromPlatform]. [PackageInfo] caches its first-ever
  /// platform lookup in a static field with no reset hook, so a widget
  /// test can't otherwise force the "lookup failed" path deterministically;
  /// this lets a test inject a loader that throws instead.
  final Future<PackageInfo> Function()? packageInfoLoader;

  @override
  State<TentangAplikasiScreen> createState() => _TentangAplikasiScreenState();
}

class _TentangAplikasiScreenState extends State<TentangAplikasiScreen> {
  late final Future<PackageInfo> Function() _loadPackageInfo =
      widget.packageInfoLoader ?? PackageInfo.fromPlatform;

  String _versionLabel = '-';
  int _iconTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await _loadPackageInfo();
      if (!mounted) return;
      setState(() => _versionLabel = info.version);
    } catch (_) {
      // Platform channel unavailable or the lookup otherwise failed — the
      // fallback "-" already covers this.
    }
  }

  void _onIconTap() {
    _iconTapCount++;
    if (_iconTapCount < 5) return;
    _iconTapCount = 0;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terima kasih sudah pakai Inventaris Toko!')),
    );
  }

  /// `dart:io`'s [Platform.version] returns a full string like
  /// "3.5.3 (stable) (Fri Aug 16 ...)" — only the leading semver is shown.
  String get _dartVersionLabel {
    final match = RegExp(r'^[\d.]+').firstMatch(Platform.version);
    return match?.group(0) ?? Platform.version;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppHeader.withBack(
        title: 'Tentang Aplikasi',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  key: const Key('tentang_aplikasi_icon'),
                  onTap: _onIconTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 96,
                      height: 96,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  TentangAplikasiScreen.appName,
                  key: const Key('tentang_aplikasi_app_name'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Versi $_versionLabel',
                  key: const Key('tentang_aplikasi_version'),
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aplikasi pencatatan stok barang untuk toko kelontong. '
                  'Dibuat dengan Flutter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dibuat oleh ${TentangAplikasiScreen.developerName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text('Flutter $_dartVersionLabel', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Database: Isar', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      );
  }
}
