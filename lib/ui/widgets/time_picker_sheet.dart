import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _InputMode { scroll, manual }

/// Time picker as a modal bottom sheet with two interchangeable input
/// modes: an iOS-alarm-style scroll wheel ([CupertinoDatePicker]) by
/// default, and a manual hour/minute typing mode toggled via a text
/// button. Both modes stay in sync with each other when switching, so
/// whichever one the user leaves in place is faithfully what "OK"
/// returns.
class TimePickerSheet extends StatefulWidget {
  const TimePickerSheet({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  /// Shows the sheet and returns the picked [TimeOfDay], or `null` if
  /// cancelled/dismissed.
  static Future<TimeOfDay?> show(BuildContext context, {required TimeOfDay initialTime}) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TimePickerSheet(initialTime: initialTime),
    );
  }

  @override
  State<TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<TimePickerSheet> {
  late DateTime _scrollValue;
  _InputMode _mode = _InputMode.scroll;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _scrollValue = DateTime(
      now.year,
      now.month,
      now.day,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
    _hourController = TextEditingController(text: _twoDigits(widget.initialTime.hour));
    _minuteController = TextEditingController(text: _twoDigits(widget.initialTime.minute));
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  /// Parses the manual fields, or `null` if either is out of range/blank
  /// — the single source of truth for both live validation and submit.
  TimeOfDay? _parsedManualTime() {
    final hour = int.tryParse(_hourController.text.trim());
    final minute = int.tryParse(_minuteController.text.trim());
    if (hour == null || hour < 0 || hour > 23) return null;
    if (minute == null || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _toggleMode() {
    setState(() {
      if (_mode == _InputMode.scroll) {
        _hourController.text = _twoDigits(_scrollValue.hour);
        _minuteController.text = _twoDigits(_scrollValue.minute);
        _manualError = null;
        _mode = _InputMode.manual;
      } else {
        // A manual value that doesn't parse is left behind rather than
        // carried into the wheel — the wheel can't represent "invalid",
        // so it just keeps whatever it last had.
        final manual = _parsedManualTime();
        if (manual != null) {
          _scrollValue = DateTime(
            _scrollValue.year,
            _scrollValue.month,
            _scrollValue.day,
            manual.hour,
            manual.minute,
          );
        }
        _mode = _InputMode.scroll;
      }
    });
  }

  void _submit() {
    if (_mode == _InputMode.manual) {
      final manual = _parsedManualTime();
      if (manual == null) {
        setState(() => _manualError = 'Jam 0-23, menit 0-59');
        return;
      }
      Navigator.of(context).pop(manual);
    } else {
      Navigator.of(context).pop(TimeOfDay(hour: _scrollValue.hour, minute: _scrollValue.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Jam pengiriman',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_mode == _InputMode.scroll)
              SizedBox(
                key: const Key('time_picker_sheet_scroll'),
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: _scrollValue,
                  onDateTimeChanged: (value) => _scrollValue = value,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      child: TextField(
                        key: const Key('time_picker_sheet_hour_field'),
                        controller: _hourController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28),
                        maxLength: 2,
                        decoration: const InputDecoration(counterText: ''),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('.', style: TextStyle(fontSize: 28)),
                    ),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        key: const Key('time_picker_sheet_minute_field'),
                        controller: _minuteController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28),
                        maxLength: 2,
                        decoration: const InputDecoration(counterText: ''),
                      ),
                    ),
                  ],
                ),
              ),
            if (_manualError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _manualError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            const SizedBox(height: 4),
            TextButton(
              key: const Key('time_picker_sheet_mode_toggle'),
              onPressed: _toggleMode,
              child: Text(_mode == _InputMode.scroll ? 'Ketik manual' : 'Gunakan scroll'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('time_picker_sheet_cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('time_picker_sheet_ok'),
                    onPressed: _submit,
                    child: const Text('OK', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
