import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Groups raw digits into DD/MM/YYYY as the user types, inserting "/"
/// after the day and month. Doesn't judge whether the resulting date is
/// real — [validateDateInput] does that on every keystroke, and
/// [parseDdMmYyyy] on a completed date.
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

    // Map the caret across the reformat by digit count rather than by raw
    // offset: count the digits that precede the caret in what the user just
    // typed, then walk the formatted text until that many digits have gone
    // by. Anchoring to the digits is what lets the auto-inserted "/" shift
    // around without dragging the caret to the end of the field — editing
    // the middle of an existing date leaves the caret where the edit was.
    final caret = newValue.selection.end.clamp(0, newValue.text.length);
    var digitsBeforeCaret = 0;
    for (var i = 0; i < caret; i++) {
      if (_isDigit(newValue.text[i])) digitsBeforeCaret++;
    }
    if (digitsBeforeCaret > truncated.length) digitsBeforeCaret = truncated.length;

    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < digitsBeforeCaret) {
      if (_isDigit(text[offset])) seen++;
      offset++;
    }

    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}

/// Earliest year the report screens allow. Used as the floor
/// `ReportPeriodFilter` hands to both its calendar and its typed fields,
/// so the two can't disagree about what's in range.
const int kMinValidYear = 2020;

/// Shown when the typed text can never become a real calendar date —
/// a day of 82, a month of 13, 31 September, 29 February off a leap year.
const String kInvalidDateError = 'Tanggal tidak valid.';

/// Shown when the typed date is real but lies after the caller's
/// [lastDate] — which every call site sets to today. Future dates are
/// rejected outright rather than clamped: a date the shop hasn't reached
/// yet cannot describe anything that was recorded.
const String kFutureDateError = 'Tanggal tidak boleh melebihi hari ini.';

/// Shown when the typed date is real but older than the caller's
/// [firstDate].
const String kTooEarlyDateError = 'Tanggal terlalu awal.';

/// Message for a year that can't fall inside the caller's bounds. Reported
/// as soon as the typed year prefix rules every allowed year out, so
/// "01/01/19…" fails on the third year digit rather than the fourth.
String yearRangeError(DateTime firstDate, DateTime lastDate) =>
    'Tahun harus antara ${firstDate.year}–${lastDate.year}';

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

/// Longest any month can run, ignoring the leap year question — February
/// gets 29 here so a typed "29/02" isn't rejected before the year that
/// decides it has been entered. The exact leap check happens in
/// [parseDdMmYyyy] once all four year digits are present.
const List<int> _longestMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

/// Parses a DD/MM/YYYY string, or returns null if it isn't a real
/// calendar date within [firstDate]..[lastDate] (both inclusive, compared
/// by calendar day, so a bound carrying a time-of-day still means the
/// whole day).
///
/// Rather than a hand-rolled days-per-month table, this relies on
/// [DateTime]'s own normalizing constructor: DateTime(2026, 2, 30)
/// silently rolls over to March 2nd, so comparing the constructed date's
/// fields back against the parsed input catches both plain out-of-range
/// days and month-specific ones (30 Feb, 29 Feb outside a leap year)
/// without this code needing to know how many days each month has.
///
/// The bounds are the caller's rather than a hardcoded year window: every
/// call site already holds the same `firstDate`/`lastDate` it gives its
/// calendar picker, so typing a date and picking one now accept exactly
/// the same set of days — including the upper bound being *today*, not
/// the end of the current year.
///
/// Leading/trailing whitespace is rejected, not trimmed — `text` must be
/// exactly 10 characters of `DD/MM/YYYY`, so a stray space already fails
/// the length check below before reaching the digit parsing.
DateTime? parseDdMmYyyy(
  String text, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (text.length != 10) return null;
  final parts = text.split('/');
  if (parts.length != 3) return null;

  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;

  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  if (date.isBefore(_dayOf(firstDate))) return null;
  if (date.isAfter(_dayOf(lastDate))) return null;
  return date;
}

/// What [validateDateInput] makes of the text currently in a date field.
///
/// The two states a field cares about are deliberately not opposites:
/// text can be neither valid nor in error ("29" — not a date yet, but
/// nothing rules one out), which is what keeps the error from flashing
/// under the user's fingers while they're still typing.
class DateInputValidation {
  const DateInputValidation._(this.date, this.error);

  /// The parsed date, non-null only once the input is complete and fully
  /// within bounds — the same value [parseDdMmYyyy] would return.
  final DateTime? date;

  /// The message to show in red, non-null only once the input can no
  /// longer become a valid date no matter what is typed next.
  final String? error;

  /// True when the field holds a complete, in-bounds date.
  bool get isValid => date != null;
}

const DateInputValidation _pending = DateInputValidation._(null, null);

DateInputValidation _rejected(String error) => DateInputValidation._(null, error);

/// Validates a partially-typed DD/MM/YYYY string on every keystroke.
///
/// The rule is "flag it the moment it's unsalvageable", not "flag it once
/// it's complete": each prefix is checked against what it could still
/// grow into. A day whose first digit is 4 can only ever reach 40–49, so
/// it fails on that first keystroke; "2" could still become 29, so it
/// doesn't. The same applies to the month (a leading 2 can never lead to
/// 01–12) and to the year, whose typed prefix is compared as an interval
/// against [firstDate]'s year..[lastDate]'s year.
///
/// Only once all eight digits are in does this defer to [parseDdMmYyyy]
/// for the checks that need the whole date: the leap-year question, and
/// the exact day-level bounds.
DateInputValidation validateDateInput(
  String text, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return _pending;

  // Day. With one digit typed the day is still open-ended, so only a
  // first digit above 3 (40-99) is already hopeless.
  final dayFirst = int.parse(digits[0]);
  if (dayFirst > 3) return _rejected(kInvalidDateError);
  if (digits.length >= 2) {
    final day = int.parse(digits.substring(0, 2));
    if (day < 1 || day > 31) return _rejected(kInvalidDateError);
  }
  if (digits.length < 3) return _pending;

  // Month, same shape: a leading digit above 1 can't reach 01-12.
  final monthFirst = int.parse(digits[2]);
  if (monthFirst > 1) return _rejected(kInvalidDateError);
  if (digits.length >= 4) {
    final month = int.parse(digits.substring(2, 4));
    if (month < 1 || month > 12) return _rejected(kInvalidDateError);

    // Day against month, using the longest that month can ever run, so
    // 31/09 fails here while 29/02 waits for the year.
    final day = int.parse(digits.substring(0, 2));
    if (day > _longestMonth[month - 1]) return _rejected(kInvalidDateError);
  }
  if (digits.length <= 4) return _pending;

  // Year, as an interval: the typed prefix pins the leading digits and
  // the rest are free, so "20" covers 2000-2099 and only fails if that
  // whole span misses the allowed years.
  final typed = digits.length - 4;
  final free = 4 - typed;
  final scale = [1, 10, 100, 1000][free];
  final prefix = int.parse(digits.substring(4));
  final lowestYear = prefix * scale;
  final highestYear = lowestYear + scale - 1;
  if (highestYear < firstDate.year || lowestYear > lastDate.year) {
    return _rejected(yearRangeError(firstDate, lastDate));
  }
  if (digits.length < 8) return _pending;

  // Complete: the remaining questions (leap year, and the day-level
  // bounds rather than the year-level ones checked above) all need the
  // whole date, which is exactly what the parser answers.
  final formatted = '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
  final date = parseDdMmYyyy(formatted, firstDate: firstDate, lastDate: lastDate);
  if (date != null) return DateInputValidation._(date, null);

  final year = int.parse(digits.substring(4));
  final month = int.parse(digits.substring(2, 4));
  final day = int.parse(digits.substring(0, 2));
  final asDate = DateTime(year, month, day);
  final isRealDate = asDate.year == year && asDate.month == month && asDate.day == day;
  if (!isRealDate) return _rejected(kInvalidDateError);
  if (asDate.isAfter(_dayOf(lastDate))) return _rejected(kFutureDateError);
  return _rejected(kTooEarlyDateError);
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

  /// Live per-keystroke validation, shared by both fields and identical
  /// to the one the date-range sheet runs — the error appears as soon as
  /// the typed prefix is unsalvageable, not once ten characters are in.
  DateInputValidation _validate(String value) => validateDateInput(
        value,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
      );

  void _handleStartChanged(String value) {
    setState(() => _startError = _validate(value).error);
  }

  void _handleEndChanged(String value) {
    setState(() => _endError = _validate(value).error);
  }

  void _applyTyped() {
    final startText = _startController.text;
    final endText = _endController.text;
    final startValidation = _validate(startText);
    final endValidation = _validate(endText);
    final start = startValidation.date;
    final end = endValidation.date;

    setState(() {
      // An incomplete-but-not-yet-wrong entry ("29/02") has no error of
      // its own, so it falls back to the generic invalid message on tap
      // rather than applying nothing without explanation.
      _startError = startText.isEmpty
          ? 'Wajib diisi'
          : (start == null ? (startValidation.error ?? kInvalidDateError) : null);
      _endError = endText.isEmpty
          ? 'Wajib diisi'
          : (end == null ? (endValidation.error ?? kInvalidDateError) : null);
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
        _validate(_startController.text).isValid && _validate(_endController.text).isValid;

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
