import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppHeader.withBack(
        title: 'Tentang Aplikasi',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            // App identity header on a white card, matching the elevated
            // card system used across the rest of the app.
            _card(
              child: Column(
                children: [
                  GestureDetector(
                    key: const Key('tentang_aplikasi_icon'),
                    onTap: _onIconTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.pillRadius),
                      child: Image.asset('assets/icon/app_icon.png', width: 84, height: 84),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    TentangAplikasiScreen.appName,
                    key: const Key('tentang_aplikasi_app_name'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenSubtle,
                      borderRadius: BorderRadius.circular(AppDimensions.pillRadius),
                    ),
                    child: Text(
                      'Versi $_versionLabel',
                      key: const Key('tentang_aplikasi_version'),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.greenText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Aplikasi pencatatan stok barang untuk toko kelontong.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: AppColors.gray700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dibuat oleh ${TentangAplikasiScreen.developerName}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: AppColors.gray700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Technical info as labelled rows on their own white card.
            _card(
              child: Column(
                children: [
                  _infoRow('Versi aplikasi', _versionLabel),
                  const Divider(height: AppSpacing.md),
                  _infoRow('Flutter', _dartVersionLabel),
                  const Divider(height: AppSpacing.md),
                  _infoRow('Database', 'Isar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body.copyWith(color: AppColors.gray700)),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}
