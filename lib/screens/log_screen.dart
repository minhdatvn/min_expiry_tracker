import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // Giữ lại nút gửi thông báo thử ngay trong màn hình Log để tiện kiểm tra khi cần
  Future<void> _sendTestNotification() async {
    await NotifyService.instance.showTestNotification();
    await _loadLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification sent!')),
    );
  }

  Future<void> _confirmClearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text('This will remove all activity history records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LogService.instance.clearLogs();
      await _loadLogs();
    }
  }

  // Chọn màu nhãn theo từng loại hành động để dễ nhìn lướt qua
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
      case 'ERROR':
        return Colors.red.shade900;
      default:
        return Colors.teal.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM dd, HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Activity Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Send Test Notification',
            onPressed: _sendTestNotification,
          ),
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Logs',
              onPressed: _confirmClearLogs,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty
                ? Center(
                    child: Text(
                      'No activity logs yet.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final badgeColor = _getActionColor(log.action);

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 74,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withAlpha(80)),
                          ),
                          child: Text(
                            log.action,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        title: Text(
                          log.message,
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
    );
  }
}