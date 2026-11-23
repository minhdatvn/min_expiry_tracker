import '../constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart'; // MỚI: Dịch nhãn hành động & nội dung Log
import '../services/log_service.dart';
import '../services/notify_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<AppLog> _logs = [];
  bool _isLoading = true;
  String _selectedAction = 'All';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await LogService.instance.getLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  List<AppLog> get _filteredLogs {
    if (_selectedAction == 'All') return _logs;
    return _logs.where((log) => log.action == _selectedAction).toList();
  }

  int _countByAction(String action) {
    if (action == 'All') return _logs.length;
    return _logs.where((log) => log.action == action).length;
  }

  Future<void> _sendTestNotification() async {
    final l10n = AppLocalizations.of(context)!;
    await NotifyService.instance.showTestNotification();
    await _loadLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.testNotificationSent)),
    );
  }

  Future<void> _confirmClearLogs() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearLogsTitle),
        content: Text(l10n.clearLogsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LogService.instance.clearLogs();
      await _loadLogs();
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'ADD':
        return Colors.green.shade700;
      case 'UPDATE':
        return Colors.blue.shade700;
      case 'DELETE':
        return Colors.red.shade700;
      case 'CALENDAR':
        return Colors.purple.shade700;
      case 'NOTIFY':
        return Colors.orange.shade800;
      case 'BACKUP':
        return Colors.indigo.shade700;
      case 'ERROR':
        return Colors.red.shade900;
      default:
        return Colors.teal.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final timeFormat = DateFormat(isVi ? 'dd/MM, HH:mm:ss' : 'MMM dd, HH:mm:ss');
    final displayLogs = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appActivityLogs),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: l10n.sendTestNotification,
            onPressed: _sendTestNotification,
          ),
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.clearLogs,
              onPressed: _confirmClearLogs,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Thanh lọc ngang đã dịch tên nhóm hành động (Thêm, Cập nhật, Thông báo, Lịch...)
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: AppConstants.logActionFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final action = AppConstants.logActionFilters[index];
                  final count = _countByAction(action);
                  final labelText = localizeLogAction(l10n, action);

                  return ChoiceChip(
                    label: Text('$labelText ($count)'),
                    selected: _selectedAction == action,
                    onSelected: (_) {
                      setState(() => _selectedAction = action);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayLogs.isEmpty
                      ? Center(
                          child: Text(
                            _logs.isEmpty
                                ? l10n.noLogsYet
                                : l10n.noActionLogsFound(
                                    localizeLogAction(l10n, _selectedAction),
                                  ),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: displayLogs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = displayLogs[index];
                            final badgeColor = _getActionColor(log.action);

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: Container(
                                // Tăng nhẹ chiều rộng lên 78px để chữ "Thông báo" / "Cập nhật" nằm gọn 1 dòng
                                width: 78,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: badgeColor.withAlpha(80),
                                  ),
                                ),
                                child: Text(
                                  localizeLogAction(l10n, log.action),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              title: Text(
                                localizeLogMessage(l10n, log.message),
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                timeFormat.format(log.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}