import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../data/isar_service.dart';
import '../../../data/models/cost_price_adjustment.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_mutation.dart';
import '../../../domain/last_activity.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_snack.dart';

/// Simple, static "about" page — no external links and nothing editable,
/// since this is an offline-first app with no feedback/support surface to
/// send the user to.
class TentangAplikasiScreen extends StatefulWidget {
  const TentangAplikasiScreen({
    super.key,
    this.packageInfoLoader,
    this.lastActivityLoader,
  });

  static const String appName = 'Inventaris Toko';

  static const String description =
      'Inventaris Toko membantu mencatat stok, harga modal, dan keuntungan '
      'toko dengan rapi langsung dari HP — tanpa perlu buku catatan atau '
      'komputer. Semua data tersimpan di HP dan bisa dicadangkan kapan saja.';

  /// Test seam only — real callers always let this default to
  /// [PackageInfo.fromPlatform]. [PackageInfo] caches its first-ever
  /// platform lookup in a static field with no reset hook, so a widget
  /// test can't otherwise force the "lookup failed" path deterministically;
  /// this lets a test inject a loader that throws instead.
  final Future<PackageInfo> Function()? packageInfoLoader;

  /// Test seam only — real callers let this default to the Isar-backed
  /// lookup, which reads the newest write timestamp across the user's own
  /// records.
  final Future<List<DateTime?>> Function()? lastActivityLoader;

  @override
  State<TentangAplikasiScreen> createState() => _TentangAplikasiScreenState();
}

class _TentangAplikasiScreenState extends State<TentangAplikasiScreen> {
  late final Future<PackageInfo> Function() _loadPackageInfo =
      widget.packageInfoLoader ?? PackageInfo.fromPlatform;

  late final Future<List<DateTime?>> Function() _loadLastActivity =
      widget.lastActivityLoader ?? _latestDataTimestamps;

  String _versionLabel = '-';
  String _lastActivityLabel = kNoActivityLabel;
  int _iconTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadLastActivityLabel();
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

  Future<void> _loadLastActivityLabel() async {
    try {
      final timestamps = await _loadLastActivity();
      if (!mounted) return;
      setState(() => _lastActivityLabel = resolveLastActivityLabel(timestamps));
    } catch (_) {
      // Isar unavailable (e.g. a widget test that never opened it) — the
      // "Belum ada aktivitas" fallback already covers this.
    }
  }

  /// The newest write timestamp of each collection the user actually
  /// writes to: the stock-mutation ledger, products (created *and* edited,
  /// since an edit leaves `createdAt` untouched), and cost-price
  /// adjustments. Categories and settings are excluded — they're
  /// configuration, not the "data activity" the row is about.
  static Future<List<DateTime?>> _latestDataTimestamps() async {
    final isar = IsarService.instance;
    final results = await Future.wait<DateTime?>([
      isar.stockMutations.where().sortByCreatedAtDesc().findFirst().then((m) => m?.createdAt),
      isar.products.where().sortByUpdatedAtDesc().findFirst().then((p) => p?.updatedAt),
      isar.products.where().sortByCreatedAtDesc().findFirst().then((p) => p?.createdAt),
      isar.costPriceAdjustments
          .where()
          .sortByAdjustedAtDesc()
          .findFirst()
          .then((a) => a?.adjustedAt),
    ]);
    return results;
  }

  void _onIconTap() {
    _iconTapCount++;
    if (_iconTapCount < 5) return;
    _iconTapCount = 0;
    AppSnack.info(context, 'Terima kasih sudah pakai Inventaris Toko!');
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
                      child: const AppLogo(size: 84),
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
                    TentangAplikasiScreen.description,
                    key: const Key('tentang_aplikasi_description'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.gray700),
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
                  _infoRow('Terakhir diperbarui', _lastActivityLabel),
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
