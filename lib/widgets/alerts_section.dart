import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';

// Cụm giao diện quản lý danh sách mốc cảnh báo & đồng bộ Lịch điện thoại
class AlertsSection extends StatefulWidget {
  final List<AlertMilestone> alerts;
  final ValueChanged<List<AlertMilestone>> onChanged;

  const AlertsSection({
    super.key,
    required this.alerts,
    required this.onChanged,
  });

  @override
  State<AlertsSection> createState() => _AlertsSectionState();
}

class _AlertsSectionState extends State<AlertsSection> {
  static const List<int> _quickDayPresets = [1, 3, 7, 30];

  final TextEditingController _valueController = TextEditingController();
  String _selectedUnit = 'days';

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _addAlertMilestone({int? presetDays}) {
    final l10n = AppLocalizations.of(context)!;
    final int? value =
        presetDays ?? int.tryParse(_valueController.text.trim());
    final String unit = presetDays != null ? 'days' : _selectedUnit;

    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidPositiveNumber)),
      );
      return;
    }

    final alreadyExists = widget.alerts.any(
      (a) => a.value == value && a.unit == unit,
    );
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.alertAlreadyExists)),
      );
      return;
    }

    final updated = List<AlertMilestone>.from(widget.alerts)
      ..add(AlertMilestone(value: value, unit: unit))
      ..sort((a, b) => b.totalHours.compareTo(a.totalHours));

    if (presetDays == null) {
      _valueController.clear();
    }
    widget.onChanged(updated);
  }

  void _toggleCalendar(int index, bool value) {
    final updated = List<AlertMilestone>.from(widget.alerts);
    updated[index] = updated[index].copyWith(addToCalendar: value);
    widget.onChanged(updated);
  }

  void _removeAlert(int index) {
    final updated = List<AlertMilestone>.from(widget.alerts)..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final availablePresets = _quickDayPresets
        .where(
          (days) => !widget.alerts.any(
            (a) => a.unit == 'days' && a.value == days,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 19,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.alertsSectionTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.alertsCalendarHint,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // Thanh nhập mốc nhắc tùy chỉnh
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _addAlertMilestone(),
                decoration: InputDecoration(
                  labelText: l10n.beforeLabel,
                  hintText: '3',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(
                  labelText: l10n.unitLabel,
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'hours',
                    child: Text(l10n.unitHours),
                  ),
                  DropdownMenuItem(
                    value: 'days',
                    child: Text(l10n.unitDays),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedUnit = value);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _addAlertMilestone,
                icon: const Icon(Icons.add),
                tooltip: l10n.addAlertTooltip,
              ),
            ),
          ],
        ),

        // Dãy chip gợi ý thêm nhanh các mốc ngày phổ biến
        if (availablePresets.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.quickAlertsLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availablePresets.map((days) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          avatar: Icon(
                            Icons.add,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          label: Text(
                            l10n.daysBeforeLabel(days),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          side: BorderSide(color: colorScheme.outlineVariant),
                          onPressed: () =>
                              _addAlertMilestone(presetDays: days),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        // Danh sách các mốc đã cài đặt
        if (widget.alerts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.noAlertsSet,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Column(
            children: widget.alerts.asMap().entries.map((entry) {
              final index = entry.key;
              final alert = entry.value;
              final isSynced = alert.addToCalendar;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withAlpha(150),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      alert.unit == 'hours'
                          ? Icons.schedule
                          : Icons.notifications_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizeAlertLabel(l10n, alert),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Nút bật/tắt đồng bộ Lịch dạng pill gọn gàng
                    Tooltip(
                      message: l10n.addToCalendar,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _toggleCalendar(index, !isSynced),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSynced
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSynced
                                  ? colorScheme.primary.withAlpha(150)
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSynced
                                    ? Icons.event_available
                                    : Icons.calendar_today_outlined,
                                size: 15,
                                color: isSynced
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.logActionCalendar,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSynced
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSynced
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.removeAlertTooltip,
                      onPressed: () => _removeAlert(index),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}