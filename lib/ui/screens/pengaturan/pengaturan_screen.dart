import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../../services/notification_service.dart';
import '../../widgets/time_picker_sheet.dart';
import 'kelola_kategori_screen.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key, required this.isar});

  final Isar isar;

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  late final AppSettingsRepository _settingsRepository = AppSettingsRepository(widget.isar);

  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepository.get();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  void _showNotAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur ini belum tersedia')),
    );
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
    await NotificationService.scheduleCriticalStockAlerts(settings);
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
    await NotificationService.scheduleCriticalStockAlerts(updated);
  }

  /// Opens the time picker straight away for the new slot (2nd or 3rd) —
  /// the slot is only appended if the user actually confirms a time,
  /// rather than adding a placeholder row the user then has to edit.
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
    await NotificationService.scheduleCriticalStockAlerts(updated);
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
    await NotificationService.scheduleCriticalStockAlerts(updated);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
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
                MaterialPageRoute(builder: (_) => KelolaKategoriScreen(isar: widget.isar)),
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
          if (settings != null) ..._buildNotifikasiSection(settings),
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
          // Bounded width: ListTile's trailing slot has no intrinsic width
          // limit of its own, and an unbounded Text here can end up wider
          // than the tile (e.g. on narrower screens or larger system font
          // sizes), which throws a layout assertion ("Trailing widget
          // consumes the entire tile width") instead of just wrapping.
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
