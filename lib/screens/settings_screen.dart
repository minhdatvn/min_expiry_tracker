import 'package:flutter/material.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Khóa các nút bấm trong tích tắc khi app đang xuất/nhập file để tránh bấm đúp
  bool _isBusy = false;

  // Xử lý khi bấm nút Sao lưu
  Future<void> _handleBackup() async {
    setState(() => _isBusy = true);
    try {
      final count = await BackupService.instance.exportBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup file ready ($count items).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // Xử lý khi bấm nút Khôi phục (có hỏi xác nhận trước)
  Future<void> _handleRestore() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Backup?'),
        content: const Text(
          'This will replace all current items on this device with the data from your backup file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose File'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      final restoredCount = await BackupService.instance.importBackup();
      if (!mounted) return;

      if (restoredCount != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored $restoredCount items!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not restore: Please select a valid MinExpiryTracker .json file.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Thanh tiến trình mỏng trên cùng khi đang xử lý file
          if (_isBusy) const LinearProgressIndicator(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Data & Backup',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Backup Data'),
            subtitle: const Text(
              'Export all items & photos as a .json file to Google Drive or device storage',
            ),
            enabled: !_isBusy,
            onTap: _handleBackup,
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore Data'),
            subtitle: const Text(
              'Import a previously saved .json backup file and reschedule alerts',
            ),
            enabled: !_isBusy,
            onTap: _handleRestore,
          ),

          const Divider(height: 24),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),

          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MinExpiryTracker'),
            subtitle: Text('Version 1.0.0 • Offline Mode'),
          ),
        ],
      ),
    );
  }
}
