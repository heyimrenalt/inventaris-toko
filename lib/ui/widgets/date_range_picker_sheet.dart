import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'date_range_filter.dart';

/// Opens the "Rentang tanggal" sheet and returns the picked [DateTimeRange],
/// or `null` if dismissed without applying.
///
/// Both fields take typed DD/MM/YYYY input — formatted by
/// [DateInputFormatter] and validated per keystroke by
/// [validateDateInput], the same logic [DateRangeFilterBar] uses on the
/// Mutasi screens — or a tap on the
/// calendar icon, which opens the native date picker and writes its result
/// back through [_formatDate] in the same DD/MM/YYYY shape, so both input
/// paths converge on one format instead of risking drift between them.
Future<DateTimeRange?> showDateRangePickerSheet({
  required BuildContext context,
  required DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DateRangePickerSheet(
      initialRange: initialRange,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

DateTime _clamp(DateTime date, DateTime first, DateTime last) {
  if (date.isBefore(first)) return first;
  if (date.isAfter(last)) return last;
  return date;
}

class _DateRangePickerSheet extends StatefulWidget {
  const _DateRangePickerSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DateRangePickerSheet> createState() => _DateRangePickerSheetState();
}

class _DateRangePickerSheetState extends State<_DateRangePickerSheet> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  String? _startError;
  String? _endError;

  @override
  void initState() {
    super.initState();
    final range = widget.initialRange;
    _startController = TextEditingController(text: range == null ? '' : _formatDate(range.start));
    _endController = TextEditingController(text: range == null ? '' : _formatDate(range.end));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  /// The one shared live validator, same call the Mutasi filter bar
  /// makes — errors surface per keystroke rather than waiting for a
  /// complete ten-character date.
  DateInputValidation _validate(String value) => validateDateInput(
        value,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
      );

  void _handleStartChanged(String value) => setState(() => _startError = _validate(value).error);

  void _handleEndChanged(String value) => setState(() => _endError = _validate(value).error);

  Future<void> _openCalendar({required bool isStart}) async {
    final controller = isStart ? _startController : _endController;
    final parsed = _validate(controller.text).date;
    final initialDate = _clamp(parsed ?? widget.lastDate, widget.firstDate, widget.lastDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _formatDate(picked);
      if (isStart) {
        _startError = null;
      } else {
        _endError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _validate(_startController.text).date;
    final end = _validate(_endController.text).date;
    final rangeError =
        start != null && end != null && end.isBefore(start) ? 'Tanggal akhir harus setelah tanggal mulai.' : null;
    final canApply = start != null && end != null && rangeError == null;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.cardRadius)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rentang tanggal', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
              Text('Format hari/bulan/tahun', style: AppTextStyles.body.copyWith(color: AppColors.gray700)),
              const SizedBox(height: AppSpacing.xl),
              _DateField(
                fieldKey: const Key('date_range_sheet_start_field'),
                calendarKey: const Key('date_range_sheet_start_calendar_icon'),
                validIconKey: const Key('date_range_sheet_start_valid_icon'),
                label: 'Tanggal mulai',
                controller: _startController,
                errorText: _startError,
                isValid: start != null,
                onChanged: _handleStartChanged,
                onTapCalendar: () => _openCalendar(isStart: true),
              ),
              const SizedBox(height: AppSpacing.xl),
              _DateField(
                fieldKey: const Key('date_range_sheet_end_field'),
                calendarKey: const Key('date_range_sheet_end_calendar_icon'),
                validIconKey: const Key('date_range_sheet_end_valid_icon'),
                label: 'Tanggal akhir',
                controller: _endController,
                errorText: _endError ?? rangeError,
                isValid: end != null && rangeError == null,
                onChanged: _handleEndChanged,
                onTapCalendar: () => _openCalendar(isStart: false),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Slash disisipkan otomatis · maks. 8 digit',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(height: 1, color: AppColors.gray100),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('date_range_sheet_cancel_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: const BorderSide(color: AppColors.gray300),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        foregroundColor: AppColors.darkText,
                      ),
                      child: const Text('Batal', style: AppTextStyles.bodyMedium),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('date_range_sheet_apply_button'),
                      onPressed:
                          canApply ? () => Navigator.of(context).pop(DateTimeRange(start: start, end: end)) : null,
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.gray300,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.calendarKey,
    required this.validIconKey,
    required this.label,
    required this.controller,
    required this.errorText,
    required this.isValid,
    required this.onChanged,
    required this.onTapCalendar,
  });

  final Key fieldKey;
  final Key calendarKey;
  final Key validIconKey;
  final String label;
  final TextEditingController controller;
  final String? errorText;
  final bool isValid;
  final ValueChanged<String> onChanged;
  final VoidCallback onTapCalendar;

  static const _fieldRadius = 28.0;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final borderRadius = BorderRadius.circular(_fieldRadius);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.subheading),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          maxLength: 10,
          style: AppTextStyles.body,
          onChanged: onChanged,
          decoration: InputDecoration(
            counterText: '',
            hintText: 'hh/bb/tttt',
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray500),
            prefixIcon: IconButton(
              key: calendarKey,
              icon: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
              onPressed: onTapCalendar,
            ),
            suffixIcon: isValid
                ? Icon(Icons.check_circle_outline, key: validIconKey, color: AppColors.primary, size: 22)
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: hasError ? AppColors.redPrimary : AppColors.gray300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: hasError ? AppColors.redPrimary : AppColors.primary, width: 1.5),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(errorText!, style: AppTextStyles.caption.copyWith(color: AppColors.redText)),
        ],
      ],
    );
  }
}
