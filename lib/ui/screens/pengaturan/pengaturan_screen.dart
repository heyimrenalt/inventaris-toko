import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../services/backup_service.dart';
import '../../../services/data_wipe_service.dart';
import '../../../services/notification_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/day_grouped_mutations.dart';
import '../../widgets/time_picker_sheet.dart';
import 'kelola_kategori_screen.dart';
import 'tentang_aplikasi_screen.dart';

/// Thin seam over [FilePicker.platform]'s `pickFiles` so "Pulihkan Data" can be driven
/// end-to-end in a widget test without a real file-picker platform channel
/// (unavailable under `flutter test`) — same reasoning as
/// [NotificationSender]/[PhotoStorageService] elsewhere in this app.
abstract class BackupFilePicker {
  /// Returns the picked file's absolute path, or `null` if the user
  /// cancelled the picker.
  Future<String?> pickJsonFile();
}

class _SystemBackupFilePicker implements BackupFilePicker {
  const _SystemBackupFilePicker();

  @override
  Future<String?> pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    return result?.files.single.path;
  }
}

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({
    super.key,
    required this.isar,
    this.dataWipeService,
    this.backupService,
    this.backupFilePicker,
    this.exportDirectoryResolver,
    this.onDataReset,
  });

  final Isar isar;

  /// Test seam only — real callers always let this default to
  /// [IsarDataWipeService]. Lets a widget test inject a fake that throws,
  /// to drive "Hapus semua data"'s failure-dialog path without needing a
  /// real Isar failure.
  final DataWipeService? dataWipeService;

  /// Test seam only — real callers always let this default to a plain
  /// [BackupService]. Lets a widget test inject a fake that throws, to
  /// drive "Pulihkan Data"'s failure-dialog paths without a real Isar
  /// failure or a real file.
  final BackupService? backupService;

  /// Test seam only — real callers always let this default to
  /// [_SystemBackupFilePicker]. Lets a widget test supply a fake that
  /// returns a path to a prepared temp file (or `null`, for "user
  /// cancelled the picker"), driving the rest of the restore flow for
  /// real.
  final BackupFilePicker? backupFilePicker;

  /// Test seam only — real callers always let this default to
  /// [_defaultExportDirectory] (app-specific external storage via
  /// `path_provider`, unavailable under `flutter test`). Lets a widget
  /// test point "Cadangkan Data" at a plain temp directory instead.
  final Future<Directory> Function()? exportDirectoryResolver;

  /// Invoked right after a successful "Hapus semua data" wipe or a
  /// successful "Pulihkan Data" restore — both replace the entire
  /// database out from under whatever's currently on screen, so
  /// [MainScaffold] switches the bottom nav back to Beranda in response
  /// (its tabs already watch every collection via `watchLazy()` and
  /// refresh on their own). `null` is fine for callers (e.g. tests) that
  /// don't care about that navigation.
  final VoidCallback? onDataReset;

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  late final AppSettingsRepository _settingsRepository = AppSettingsRepository(widget.isar);
  late final DataWipeService _dataWipeService =
      widget.dataWipeService ?? IsarDataWipeService(widget.isar);
  late final BackupService _backupService = widget.backupService ?? BackupService(widget.isar);
  late final BackupFilePicker _backupFilePicker =
      widget.backupFilePicker ?? const _SystemBackupFilePicker();
  late final Future<Directory> Function() _resolveExportDirectory =
      widget.exportDirectoryResolver ?? _defaultExportDirectory;

  AppSettings? _settings;
  bool _progressDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepository.get();
    if (!mounted) return;
    setState(() => _settings = settings);

    if (!settings.batteryOptimizationDialogDismissed) {
      // Deferred to after the first frame: showDialog needs a fully
      // mounted Navigator, which isn't guaranteed yet this early in
      // initState's async continuation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBatteryOptimizationDialog();
      });
    }
  }

  Future<void> _toggleDailySummary(bool value) async {
    final settings = await _settingsRepository.updateDailySummaryEnabled(value);
    if (!mounted) return;
    setState(() => _settings = settings);
    await NotificationService.scheduleDailySummary(settings);
  }

  Future<void> _pickDailySummaryTime() async {
    final settings = _settings;
    if (settings == null) return;

    final picked = await TimePickerSheet.show(
      context,
      initialTime: TimeOfDay(hour: settings.dailySummaryHour, minute: settings.dailySummaryMinute),
    );
    if (picked == null) return;

    final updated = await _settingsRepository.updateDailySummaryTime(
      hour: picked.hour,
      minute: picked.minute,
    );
    if (!mounted) return;
    setState(() => _settings = updated);
    await NotificationService.scheduleDailySummary(updated);
  }

  Future<void> _toggleCriticalStockAlert(bool value) async {
    final settings = await _settingsRepository.updateCriticalStockAlertEnabled(value);
    if (!mounted) return;
    setState(() => _settings = settings);
    await _scheduleCriticalStockAlerts(settings);
  }

  /// Wraps [NotificationService.scheduleCriticalStockAlerts] with an
  /// exact-alarm permission check: Android 12+ lets the user revoke
  /// "Alarms & reminders" after it's granted, and scheduling an exact
  /// alarm without it throws. Disabling the feature (or clearing every
  /// slot) only ever cancels, which needs no permission, so that path is
  /// never blocked by this check.
  Future<void> _scheduleCriticalStockAlerts(AppSettings settings) async {
    final needsExactAlarm = settings.criticalStockAlertEnabled && settings.criticalStockAlertTimes.isNotEmpty;
    if (needsExactAlarm && !await NotificationService.canScheduleExactAlarms()) {
      if (mounted) await _showExactAlarmPermissionDialog();
      return;
    }
    await NotificationService.scheduleCriticalStockAlerts(settings);
  }

  Future<void> _showExactAlarmPermissionDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Izin alarm diperlukan'),
        content: const Text(
          'Izin alarm diperlukan agar notifikasi stok muncul tepat waktu. '
          'Tanpa izin ini, notifikasi bisa terlambat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await NotificationService.requestExactAlarmsPermission();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  /// Explains that some OEMs (Oppo, Realme, Xiaomi, Samsung) kill
  /// background work more aggressively than stock Android — a
  /// restriction no scheduling change in this app can override. Shown
  /// once automatically (see [_loadSettings]) and reachable any time
  /// after via the "Notifikasi tidak muncul?" tile; only the automatic
  /// first showing is suppressed once dismissed with the checkbox
  /// ticked — reopening it manually always shows it regardless.
  Future<void> _showBatteryOptimizationDialog() {
    var dontShowAgain = false;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notifikasi tidak muncul?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beberapa HP (Oppo, Realme, Xiaomi, Samsung) membatasi '
                  'notifikasi aplikasi. Agar notifikasi stok muncul tepat '
                  'waktu:\n\n'
                  '1. Buka Pengaturan HP → Baterai → [nama app] → Izinkan '
                  'aktivitas latar belakang\n'
                  '2. Atau cari \'Pengoptimalan baterai\' dan nonaktifkan '
                  'untuk aplikasi ini.',
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const Key('pengaturan_battery_dialog_dont_show_again'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Jangan tampilkan lagi', style: TextStyle(fontSize: 14)),
                  value: dontShowAgain,
                  onChanged: (value) => setDialogState(() => dontShowAgain = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (dontShowAgain) {
                  final updated = await _settingsRepository.dismissBatteryOptimizationDialog();
                  if (mounted) setState(() => _settings = updated);
                }
              },
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: _openBatteryOptimizationSettings,
              child: const Text('Buka Pengaturan Baterai'),
            ),
          ],
        ),
      ),
    );
  }

  /// Not all OEMs/Android versions expose this settings screen under
  /// this exact action — wrapped so an unsupported device just fails
  /// quietly instead of crashing the dialog.
  Future<void> _openBatteryOptimizationSettings() async {
    try {
      const intent = AndroidIntent(action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS');
      await intent.launch();
    } catch (_) {
      // Unsupported on this device/OEM — nothing more to do.
    }
  }

  Future<void> _pickCriticalStockAlertTime(int index) async {
    final settings = _settings;
    if (settings == null) return;

    final times = settings.criticalStockAlertTimes;
    final current = times[index];
    final picked = await TimePickerSheet.show(
      context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;

    final updatedTimes = List<({int hour, int minute})>.from(times);
    updatedTimes[index] = (hour: picked.hour, minute: picked.minute);
    final updated = await _settingsRepository.updateCriticalStockAlertSlots(updatedTimes);
    if (!mounted) return;
    setState(() => _settings = updated);
    await _scheduleCriticalStockAlerts(updated);
  }

  /// Opens the time picker straight away for the new slot (2nd or 3rd) —
  /// the slot is only appended if the user actually confirms a time,
  /// rather than adding a placeholder row the user then has to edit.
  Future<void> _editRestockLeadTimeDays() async {
    final settings = _settings;
    if (settings == null) return;
    final updated = await _showRestockSettingDialog(
      title: 'Peringatan Kulakan',
      helperText: 'Peringatan kulakan berapa hari sebelum stok habis',
      initialValue: settings.restockLeadTimeDays,
      update: _settingsRepository.updateRestockLeadTimeDays,
    );
    if (updated == null) return;
    setState(() => _settings = updated);
  }

  Future<void> _editRestockCoverDays() async {
    final settings = _settings;
    if (settings == null) return;
    final updated = await _showRestockSettingDialog(
      title: 'Jumlah Hari Kulakan',
      helperText: 'Sekali kulakan untuk berapa hari',
      initialValue: settings.restockCoverDays,
      update: _settingsRepository.updateRestockCoverDays,
    );
    if (updated == null) return;
    setState(() => _settings = updated);
  }

  /// Shared dialog for [_editRestockLeadTimeDays] and
  /// [_editRestockCoverDays] — both are a single bounded integer
  /// (1..[AppSettingsRepository.maxRestockSettingDays] days) with the
  /// same validate-then-save shape, so only the copy and the update call
  /// differ between them.
  Future<AppSettings?> _showRestockSettingDialog({
    required String title,
    required String helperText,
    required int initialValue,
    required Future<AppSettings> Function(int value) update,
  }) {
    return showDialog<AppSettings>(
      context: context,
      builder: (dialogContext) => _RestockSettingDialog(
        title: title,
        helperText: helperText,
        initialValue: initialValue,
        update: update,
      ),
    );
  }

  Future<void> _addCriticalStockAlertSlot() async {
    final settings = _settings;
    if (settings == null) return;

    final times = settings.criticalStockAlertTimes;
    if (times.length >= 3) return;

    final picked = await TimePickerSheet.show(
      context,
      initialTime: const TimeOfDay(hour: 15, minute: 0),
    );
    if (picked == null) return;

    final updatedTimes = [...times, (hour: picked.hour, minute: picked.minute)];
    final updated = await _settingsRepository.updateCriticalStockAlertSlots(updatedTimes);
    if (!mounted) return;
    setState(() => _settings = updated);
    await _scheduleCriticalStockAlerts(updated);
  }

  /// Slot 1 can't be removed — "Alert stok kritis" always needs at least
  /// one active time while the feature itself is enabled.
  Future<void> _removeCriticalStockAlertSlot(int index) async {
    final settings = _settings;
    if (settings == null || index == 0) return;

    final times = settings.criticalStockAlertTimes;
    if (index >= times.length) return;

    final updatedTimes = List<({int hour, int minute})>.from(times)..removeAt(index);
    final updated = await _settingsRepository.updateCriticalStockAlertSlots(updatedTimes);
    if (!mounted) return;
    setState(() => _settings = updated);
    await _scheduleCriticalStockAlerts(updated);
  }

  /// Drives the full triple-confirmation "Hapus semua data" flow: a plain
  /// warning dialog, then a type-to-confirm dialog, then the actual wipe.
  /// Cancelling either dialog leaves everything untouched.
  Future<void> _hapusSemuaData() async {
    final proceededPastWarning = await _showHapusSemuaDataWarningDialog();
    if (proceededPastWarning != true) return;
    if (!mounted) return;

    final typedConfirmation = await _showHapusSemuaDataConfirmDialog();
    if (typedConfirmation != true) return;
    if (!mounted) return;

    try {
      await _dataWipeService.wipeAll();
    } catch (_) {
      if (!mounted) return;
      await _showHapusSemuaDataErrorDialog();
      return;
    }

    // Reload rather than reuse _loadSettings(): that method also drives
    // the one-time OEM battery-optimization dialog, which is only meant
    // to auto-show on this screen's very first load, not every time
    // AppSettings happens to change underneath it.
    final settings = await _settingsRepository.get();
    if (!mounted) return;
    setState(() => _settings = settings);

    widget.onDataReset?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua data berhasil dihapus.')),
    );
  }

  Future<bool?> _showHapusSemuaDataWarningDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: const Text(
          'Semua produk, mutasi, kategori, dan pengaturan akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal', style: TextStyle(fontSize: 16)),
          ),
          FilledButton(
            key: const Key('hapus_semua_data_step1_lanjutkan'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lanjutkan', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showHapusSemuaDataConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _HapusSemuaDataConfirmDialog(),
    );
  }

  Future<void> _showHapusSemuaDataErrorDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gagal menghapus data'),
        content: const Text(
          'Terjadi kesalahan saat menghapus data. Data yang tersisa mungkin '
          'tidak lengkap. Jika masalah ini terus terjadi, coba install ulang '
          'aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _formatLastBackupSubtitle(DateTime? lastBackupAt) {
    if (lastBackupAt == null) return 'Belum pernah dicadangkan';
    final day = DateTime(lastBackupAt.year, lastBackupAt.month, lastBackupAt.day);
    final hour = lastBackupAt.hour.toString().padLeft(2, '0');
    final minute = lastBackupAt.minute.toString().padLeft(2, '0');
    return 'Terakhir dicadangkan: ${formatDayLabel(day)} $hour.$minute';
  }

  /// Non-dismissible (no tap-outside, no back button) so the user can't
  /// accidentally back out mid-export/mid-import while Isar/file work is
  /// still running underneath. Always paired with [_dismissProgressDialog]
  /// in every exit path (success, validation failure, restore failure).
  void _showProgressDialog(String message) {
    _progressDialogShowing = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  void _dismissProgressDialog() {
    if (!_progressDialogShowing) return;
    _progressDialogShowing = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _cadangkanData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cadangkan Data'),
        content: const Text('Cadangkan semua data aplikasi ke file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal', style: TextStyle(fontSize: 16)),
          ),
          FilledButton(
            key: const Key('cadangkan_data_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cadangkan', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    _showProgressDialog('Mencadangkan data...');
    try {
      final directory = await _resolveExportDirectory();
      final file = await _backupService.exportToFile(directory: directory);
      if (!mounted) return;
      _dismissProgressDialog();

      final settings = await _settingsRepository.get();
      if (!mounted) return;
      setState(() => _settings = settings);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil dicadangkan')),
      );

      try {
        // Best-effort and deliberately its own try/catch, separate from
        // the export above: the backup file itself is already safely
        // written and AppSettings.lastBackupAt already updated by this
        // point, so a cancelled/failed share sheet (no share-target app,
        // or — under `flutter test` — no platform channel at all) must
        // never be reported as a backup failure.
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'Backup data Inventaris Toko'),
        );
      } catch (_) {
        // Ignored — see above.
      }
    } catch (e) {
      if (!mounted) return;
      _dismissProgressDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencadangkan data: $e')),
      );
    }
  }

  /// App-specific external storage (no runtime permission needed on
  /// modern Android, unlike shared/public storage) — the file only needs
  /// to exist long enough for the share sheet launched right after to
  /// hand it off to wherever the user actually wants it saved.
  Future<Directory> _defaultExportDirectory() async {
    final external = await getExternalStorageDirectory();
    return external ?? await getApplicationDocumentsDirectory();
  }

  Future<void> _pulihkanData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pulihkan Data'),
        content: const Text(
          'Pulihkan data dari file backup? Semua data saat ini akan DIGANTI '
          'dengan data dari backup. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal', style: TextStyle(fontSize: 16)),
          ),
          FilledButton(
            key: const Key('pulihkan_data_confirm'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Pulihkan', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final pickedPath = await _backupFilePicker.pickJsonFile();
    if (pickedPath == null) return;
    if (!mounted) return;

    _showProgressDialog('Memulihkan data...');
    try {
      final jsonString = await File(pickedPath).readAsString();
      final backup = await _backupService.validateAndParse(jsonString);
      await _backupService.importBackup(backup);
      if (!mounted) return;
      _dismissProgressDialog();

      final settings = await _settingsRepository.get();
      if (!mounted) return;
      setState(() => _settings = settings);

      widget.onDataReset?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil dipulihkan')),
      );
    } on BackupValidationException catch (e) {
      if (!mounted) return;
      _dismissProgressDialog();
      await _showPulihkanDataErrorDialog(_validationErrorMessage(e.reason));
    } on BackupRestoreException catch (e) {
      if (!mounted) return;
      _dismissProgressDialog();
      await _showPulihkanDataErrorDialog(
        e.rollbackSucceeded
            ? 'Gagal memulihkan data dari backup. Data sebelumnya berhasil '
                'dikembalikan, tidak ada perubahan.'
            : 'Gagal memulihkan data. Data sebelumnya juga tidak dapat '
                'dikembalikan. Silakan coba lagi dengan file backup yang valid.',
      );
    } catch (_) {
      if (!mounted) return;
      _dismissProgressDialog();
      await _showPulihkanDataErrorDialog(
        'Gagal membaca file. Periksa izin penyimpanan dan coba lagi.',
      );
    }
  }

  String _validationErrorMessage(BackupValidationFailureReason reason) {
    switch (reason) {
      case BackupValidationFailureReason.unsupportedVersion:
        return 'Versi backup tidak didukung. Perbarui aplikasi.';
      case BackupValidationFailureReason.invalidJson:
      case BackupValidationFailureReason.missingVersion:
        return 'File tidak valid. Pastikan file ini adalah backup dari aplikasi Inventaris Toko.';
    }
  }

  Future<void> _showPulihkanDataErrorDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gagal memulihkan data'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: const AppHeader(title: 'Pengaturan'),
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
                MaterialPageRoute(builder: (_) => KelolaKategoriScreen(isar: widget.isar)),
              );
            },
          ),
          if (settings != null) ..._buildPrioritasKulakanSection(settings),
          if (settings != null) ..._buildNotifikasiSection(settings),
          const _SectionHeader('Data'),
          ListTile(
            key: const Key('pengaturan_cadangkan_data_tile'),
            minVerticalPadding: 16,
            leading: const Icon(Icons.backup),
            title: const Text('Cadangkan Data', style: TextStyle(fontSize: 16)),
            subtitle: Text(
              _formatLastBackupSubtitle(settings?.lastBackupAt),
              style: const TextStyle(fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _cadangkanData,
          ),
          ListTile(
            key: const Key('pengaturan_pulihkan_data_tile'),
            minVerticalPadding: 16,
            leading: const Icon(Icons.restore),
            title: const Text('Pulihkan Data', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pulihkanData,
          ),
          ListTile(
            key: const Key('pengaturan_hapus_semua_data_tile'),
            minVerticalPadding: 16,
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Hapus semua data',
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _hapusSemuaData,
          ),
          const _SectionHeader('Lainnya'),
          ListTile(
            key: const Key('pengaturan_tentang_aplikasi_tile'),
            minVerticalPadding: 16,
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Aplikasi', style: TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TentangAplikasiScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPrioritasKulakanSection(AppSettings settings) {
    return [
      const _SectionHeader('Prioritas Kulakan'),
      ListTile(
        key: const Key('pengaturan_restock_lead_time_tile'),
        minVerticalPadding: 16,
        leading: const Icon(Icons.warning_amber_outlined),
        title: const Text('Peringatan kulakan', style: TextStyle(fontSize: 16)),
        subtitle: const Text(
          'Peringatan kulakan berapa hari sebelum stok habis',
          style: TextStyle(fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${settings.restockLeadTimeDays} hari', style: const TextStyle(fontSize: 16)),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: _editRestockLeadTimeDays,
      ),
      ListTile(
        key: const Key('pengaturan_restock_cover_days_tile'),
        minVerticalPadding: 16,
        leading: const Icon(Icons.shopping_cart_outlined),
        title: const Text('Jumlah hari kulakan', style: TextStyle(fontSize: 16)),
        subtitle: const Text(
          'Sekali kulakan untuk berapa hari',
          style: TextStyle(fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${settings.restockCoverDays} hari', style: const TextStyle(fontSize: 16)),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: _editRestockCoverDays,
      ),
    ];
  }

  List<Widget> _buildNotifikasiSection(AppSettings settings) {
    final time = TimeOfDay(hour: settings.dailySummaryHour, minute: settings.dailySummaryMinute);
    return [
      const _SectionHeader('Notifikasi'),
      SwitchListTile(
        key: const Key('pengaturan_daily_summary_toggle'),
        title: const Text('Ringkasan harian', style: TextStyle(fontSize: 16)),
        value: settings.dailySummaryEnabled,
        onChanged: _toggleDailySummary,
      ),
      if (settings.dailySummaryEnabled)
        ListTile(
          key: const Key('pengaturan_daily_summary_time'),
          minVerticalPadding: 16,
          leading: const Icon(Icons.access_time),
          title: const Text('Jam pengiriman', style: TextStyle(fontSize: 16)),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              time.format(context),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: _pickDailySummaryTime,
        ),
      SwitchListTile(
        key: const Key('pengaturan_critical_stock_toggle'),
        title: const Text('Alert stok kritis', style: TextStyle(fontSize: 16)),
        value: settings.criticalStockAlertEnabled,
        onChanged: _toggleCriticalStockAlert,
      ),
      if (settings.criticalStockAlertEnabled) ..._buildCriticalStockAlertTimeRows(settings),
      ListTile(
        key: const Key('pengaturan_notification_troubleshoot_tile'),
        minVerticalPadding: 16,
        leading: const Icon(Icons.help_outline),
        title: const Text('Notifikasi tidak muncul?', style: TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showBatteryOptimizationDialog,
      ),
    ];
  }


  /// Up to 3 tappable time rows for "Alert stok kritis", plus a
  /// "+ Tambah jam" row when fewer than 3 are configured. Slot 1 (index
  /// 0) has no delete action — at least one time must stay active
  /// whenever the feature itself is on.
  List<Widget> _buildCriticalStockAlertTimeRows(AppSettings settings) {
    final times = settings.criticalStockAlertTimes;
    return [
      for (var index = 0; index < times.length; index++)
        ListTile(
          key: Key('pengaturan_critical_stock_time_$index'),
          minVerticalPadding: 16,
          leading: const Icon(Icons.access_time),
          title: Text('Jam ke-${index + 1}', style: const TextStyle(fontSize: 16)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 70),
                child: Text(
                  TimeOfDay(hour: times[index].hour, minute: times[index].minute).format(context),
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (index > 0)
                IconButton(
                  key: Key('pengaturan_critical_stock_remove_$index'),
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeCriticalStockAlertSlot(index),
                ),
            ],
          ),
          onTap: () => _pickCriticalStockAlertTime(index),
        ),
      if (times.length < 3)
        ListTile(
          key: const Key('pengaturan_critical_stock_add_time'),
          minVerticalPadding: 16,
          leading: const Icon(Icons.add),
          title: const Text('Tambah jam', style: TextStyle(fontSize: 16)),
          onTap: _addCriticalStockAlertSlot,
        ),
    ];
  }
}

/// A dedicated [StatefulWidget] (rather than a bare [TextEditingController]
/// captured by the enclosing function + a `StatefulBuilder`) so its
/// controller is created in `initState` and disposed only in `dispose` —
/// disposing it right after `showDialog`'s Future resolves races the
/// dialog's own exit-transition animation: the `AlertDialog`/`TextField`
/// stay mounted and the field's `EditableText` stays listening on the
/// controller for the duration of that animation, so an immediate
/// dispose there is a real "disposed while still listened" bug, not just
/// a leak. Owning the controller through the normal State lifecycle
/// instead means Flutter itself only calls `dispose()` once the widget
/// is actually gone. See [_CategoryFormDialog] for the same fix applied
/// to the category add/rename dialog.
class _RestockSettingDialog extends StatefulWidget {
  const _RestockSettingDialog({
    required this.title,
    required this.helperText,
    required this.initialValue,
    required this.update,
  });

  final String title;
  final String helperText;
  final int initialValue;
  final Future<AppSettings> Function(int value) update;

  @override
  State<_RestockSettingDialog> createState() => _RestockSettingDialogState();
}

class _RestockSettingDialogState extends State<_RestockSettingDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = int.tryParse(_controller.text.trim());
    if (value == null ||
        value < AppSettingsRepository.minRestockSettingDays ||
        value > AppSettingsRepository.maxRestockSettingDays) {
      setState(() => _errorText =
          'Masukkan angka ${AppSettingsRepository.minRestockSettingDays}-'
          '${AppSettingsRepository.maxRestockSettingDays}');
      return;
    }

    final updated = await widget.update(value);
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 18)),
      // The description reads as a full sentence ("Peringatan kulakan
      // berapa hari sebelum stok habis") — too long for
      // InputDecoration.labelText, which floats as a single line above
      // the field and clips with an ellipsis instead of wrapping. A
      // plain Text above the field wraps properly, so the field itself
      // only needs a short labelText.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.helperText, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 12),
          TextField(
            key: const Key('pengaturan_restock_setting_field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Jumlah hari',
              suffixText: 'hari',
              errorText: _errorText,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(fontSize: 16)),
        ),
        ElevatedButton(
          key: const Key('pengaturan_restock_setting_save'),
          onPressed: _submit,
          child: const Text('Simpan', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}

/// Step 2 of "Hapus semua data": the user must type "HAPUS" exactly
/// (case-sensitive, trimmed) before the confirm button enables. A
/// dedicated [StatefulWidget] for the same controller-lifecycle reason as
/// [_RestockSettingDialog] above — the field's [TextEditingController]
/// must be owned through `initState`/`dispose`, not disposed the moment
/// `showDialog`'s Future resolves.
class _HapusSemuaDataConfirmDialog extends StatefulWidget {
  const _HapusSemuaDataConfirmDialog();

  static const String confirmationText = 'HAPUS';

  @override
  State<_HapusSemuaDataConfirmDialog> createState() => _HapusSemuaDataConfirmDialogState();
}

class _HapusSemuaDataConfirmDialogState extends State<_HapusSemuaDataConfirmDialog> {
  late final TextEditingController _controller;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final matches = _controller.text.trim() == _HapusSemuaDataConfirmDialog.confirmationText;
    if (matches != _isConfirmed) {
      setState(() => _isConfirmed = matches);
    }
  }

  void _submit() {
    if (!_isConfirmed) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Konfirmasi hapus data', style: TextStyle(fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ketik HAPUS untuk konfirmasi'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('hapus_semua_data_confirm_field'),
            controller: _controller,
            autofocus: true,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(labelText: 'Konfirmasi'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal', style: TextStyle(fontSize: 16)),
        ),
        FilledButton(
          key: const Key('hapus_semua_data_step2_confirm'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _isConfirmed ? _submit : null,
          child: const Text('Hapus', style: TextStyle(fontSize: 16)),
        ),
      ],
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
