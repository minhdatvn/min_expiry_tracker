import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';

// Cụm giao diện quản lý danh sách mốc cảnh báo & ô tick đồng bộ Lịch điện thoại
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
  final TextEditingController _valueController = TextEditingController();
  String _selectedUnit = 'days';

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _addAlertMilestone() {
    final l10n = AppLocalizations.of(context)!;
    final value = int.tryParse(_valueController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidPositiveNumber)),
      );
      return;
    }

    final alreadyExists = widget.alerts.any(
      (a) => a.value == value && a.unit == _selectedUnit,
    );
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.alertAlreadyExists)),
      );
      return;
    }

    // Tạo bản sao danh sách mới, thêm mốc, sắp xếp lại rồi gửi về màn hình cha
    final updated = List<AlertMilestone>.from(widget.alerts)
      ..add(AlertMilestone(value: value, unit: _selectedUnit))
      ..sort((a, b) => b.totalHours.compareTo(a.totalHours));

    _valueController.clear();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.alertsSectionTitle,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.alertsSectionHint,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),

        // Thanh nhập mốc nhắc mới
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.beforeLabel,
                  hintText: '3',
                  border: const OutlineInputBorder(),
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
                  border: const OutlineInputBorder(),
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
            IconButton.filled(
              onPressed: _addAlertMilestone,
              icon: const Icon(Icons.add),
              tooltip: l10n.addAlertTooltip,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Danh sách các mốc đã cài đặt
        if (widget.alerts.isEmpty)
          Text(
            l10n.noAlertsSet,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          )
        else
          Column(
            children: widget.alerts.asMap().entries.map((entry) {
              final index = entry.key;
              final alert = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      alert.unit == 'hours'
                          ? Icons.schedule
                          : Icons.notifications_outlined,
                      size: 18,
                      color: Colors.teal.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizeAlertLabel(l10n, alert),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _toggleCalendar(index, !alert.addToCalendar),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: alert.addToCalendar,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (checked) {
                              _toggleCalendar(index, checked ?? false);
                            },
                          ),
                          Text(
                            l10n.addToCalendar,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
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