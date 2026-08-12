import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Groups raw digits into DD/MM/YYYY as the user types, inserting "/"
/// after the day and month. Doesn't judge whether the resulting date is
/// real — [parseDdMmYyyy] handles validity once a full date is entered.
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < truncated.length; i++) {
      buffer.write(truncated[i]);
      final isLast = i == truncated.length - 1;
      if (!isLast && (i == 1 || i == 3)) buffer.write('/');
    }

    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Earliest year typed input accepts. Matches [ReportPeriodFilter]'s
/// calendar `firstDate: DateTime(2020)` — the same floor the calendar
/// picker enforces, so typed and picked dates can't disagree on what's in
/// range.
const int kMinValidYear = 2020;

/// Latest year typed input accepts: the current year, matching
/// [ReportPeriodFilter]'s calendar `lastDate` (today's date — this checks
/// only the year component, since a year-level bound can't reproduce the
/// picker's exact day cutoff without duplicating its call site).
int maxValidYear() => DateTime.now().year;

/// Message for a year outside [kMinValidYear]..[maxValidYear]. Kept next to
/// [parseDdMmYyyy] so a caller can surface a specific reason instead of a
/// generic "invalid date" message — not wired into any screen by this
/// change, since that's a UI-layer concern.
String yearRangeError() => 'Tahun harus antara $kMinValidYear–${maxValidYear()}';

/// Parses a DD/MM/YYYY string, or returns null if it isn't a real
/// calendar date. Rather than a hand-rolled days-per-month table, this
/// relies on [DateTime]'s own normalizing constructor: DateTime(2026, 2,
/// 30) silently rolls over to March 2nd, so comparing the constructed
/// date's fields back against the parsed input catches both plain
/// out-of-range days and month-specific ones (30 Feb, 29 Feb outside a
/// leap year) without this code needing to know how many days each month
/// has.
///
/// Leading/trailing whitespace is rejected, not trimmed — `text` must be
/// exactly 10 characters of `DD/MM/YYYY`, so a stray space already fails
/// the length check below before reaching the digit parsing.
DateTime? parseDdMmYyyy(String text) {
  if (text.length != 10) return null;
  final parts = text.split('/');
  if (parts.length != 3) return null;

  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  if (year < kMinValidYear || year > maxValidYear()) return null;

  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _formatRangeLabel(DateTimeRange range) =>
    '${_formatDate(range.start)} - ${_formatDate(range.end)}';

/// Date-range filter with two typeable DD/MM/YYYY fields (Tanggal Mulai /
/// Tanggal Akhir) plus a calendar-icon fallback, both ending up calling
/// [onChanged] with the same [DateTimeRange] the calendar picker would
/// have produced — the caller doesn't need to know which input method
/// was used.
class DateRangeFilterBar extends StatefulWidget {
  const DateRangeFilterBar({
    super.key,
    required this.selectedRange,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTimeRange? selectedRange;
  final ValueChanged<DateTimeRange?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<DateRangeFilterBar> createState() => _DateRangeFilterBarState();
}

class _DateRangeFilterBarState extends State<DateRangeFilterBar> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  String? _startError;
  String? _endError;

  @override
  void initState() {
    super.initState();
    final range = widget.selectedRange;
    _startController = TextEditingController(text: range == null ? '' : _formatDate(range.start));
    _endController = TextEditingController(text: range == null ? '' : _formatDate(range.end));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _handleStartChanged(String value) {
    setState(() {
      _startError = value.length < 10 ? null : (parseDdMmYyyy(value) == null ? 'Tanggal tidak valid.' : null);
    });
  }

  void _handleEndChanged(String value) {
    setState(() {
      _endError = value.length < 10 ? null : (parseDdMmYyyy(value) == null ? 'Tanggal tidak valid.' : null);
    });
  }

  void _applyTyped() {
    final startText = _startController.text;
    final endText = _endController.text;
    final start = parseDdMmYyyy(startText);
    final end = parseDdMmYyyy(endText);

    setState(() {
      _startError = startText.isEmpty ? 'Wajib diisi' : (start == null ? 'Tanggal tidak valid.' : null);
      _endError = endText.isEmpty ? 'Wajib diisi' : (end == null ? 'Tanggal tidak valid.' : null);
    });

    if (start == null || end == null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    widget.onChanged(
      start.isAfter(end) ? DateTimeRange(start: end, end: start) : DateTimeRange(start: start, end: end),
    );
  }

  Future<void> _openCalendar() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      initialDateRange: widget.selectedRange,
      // Typing now has its own always-visible fields above, so the
      // calendar no longer needs the SDK's built-in keyboard-entry
      // toggle — it can stay calendar-only.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (picked == null) return;
    setState(() {
      _startController.text = _formatDate(picked.start);
      _endController.text = _formatDate(picked.end);
      _startError = null;
      _endError = null;
    });
    widget.onChanged(picked);
  }

  void _clear() {
    setState(() {
      _startController.clear();
      _endController.clear();
      _startError = null;
      _endError = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    // Drives the Terapkan button's visual state only — it stays tappable
    // either way, so tapping it while incomplete/invalid still surfaces
    // "Wajib diisi" / the format error instead of silently doing nothing.
    final canApply =
        parseDdMmYyyy(_startController.text) != null && parseDdMmYyyy(_endController.text) != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('mutasi_date_start_field'),
                  controller: _startController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [DateInputFormatter()],
                  maxLength: 10,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Tanggal Mulai',
                    hintText: 'DD/MM/YYYY',
                    counterText: '',
                    isDense: true,
                    errorText: _startError,
                  ),
                  onChanged: _handleStartChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('mutasi_date_end_field'),
                  controller: _endController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [DateInputFormatter()],
                  maxLength: 10,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Tanggal Akhir',
                    hintText: 'DD/MM/YYYY',
                    counterText: '',
                    isDense: true,
                    errorText: _endError,
                  ),
                  onChanged: _handleEndChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('mutasi_date_range_button'),
                  onPressed: _openCalendar,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Kalender', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('mutasi_date_apply_button'),
                  onPressed: _applyTyped,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Terapkan', style: TextStyle(fontSize: 13)),
                  style: canApply
                      ? null
                      : ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
            ],
          ),
          if (widget.selectedRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  key: const Key('mutasi_date_range_chip'),
                  label: Text(
                    _formatRangeLabel(widget.selectedRange!),
                    style: const TextStyle(fontSize: 13),
                  ),
                  onDeleted: _clear,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
