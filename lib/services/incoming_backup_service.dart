import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'backup_service.dart';
import 'locale_service.dart';

class IncomingBackupService {
  static final IncomingBackupService instance = IncomingBackupService._init();
  IncomingBackupService._init();

  static const MethodChannel _channel = MethodChannel(
    'com.min.expiry_tracker/incoming_file',
  );

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isInitialized = false;
  bool _isHandling = false;

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileReceived' && call.arguments is String) {
        await _handleIncomingFile(call.arguments as String);
      }
    });
  }

  // Gọi 1 lần sau khi HomeScreen hiển thị xong để đón file lúc mở app từ trạng thái tắt hẳn
  Future<void> checkInitialFile() async {
    try {
      final String? initialPath =
          await _channel.invokeMethod<String>('getInitialFile');
      if (initialPath != null && initialPath.isNotEmpty) {
        await _handleIncomingFile(initialPath);
      }
    } catch (_) {}
  }

  Future<void> _handleIncomingFile(String filePath) async {
    if (_isHandling) {
      await _cleanupTempFile(filePath);
      return;
    }
    _isHandling = true;

    try {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      final l10n =
          AppLocalizations.of(context) ?? LocaleService.instance.currentL10n;

      BackupPreview preview;
      try {
        preview = await BackupService.instance.inspectBackupFile(filePath);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(l10n.restoreError),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;

      final dateText = preview.exportedAt != null
          ? formatDateByLocale(context, preview.exportedAt!, includeTime: true)
          : '-';

      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.incomingBackupTitle),
          content: Text(
            l10n.incomingBackupContent(dateText, preview.items.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.restoreNow),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      // Hiện hộp thoại chờ trong lúc khôi phục DB, Lịch & Thông báo
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.restoringBackup)),
              ],
            ),
          ),
        ),
      );

      int restoredCount = 0;
      try {
        restoredCount =
            await BackupService.instance.restoreFromPreview(preview);
      } finally {
        navigatorKey.currentState?.pop();
      }

      // Đưa về màn hình chính để tránh kẹt ở màn hình Sửa của dữ liệu cũ
      navigatorKey.currentState?.popUntil((route) => route.isFirst);

      final updatedContext = navigatorKey.currentContext;
      if (updatedContext != null && updatedContext.mounted) {
        ScaffoldMessenger.maybeOf(updatedContext)?.showSnackBar(
          SnackBar(
            content: Text(l10n.restoreSuccess(restoredCount)),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (_) {
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        final l10n = AppLocalizations.of(currentContext) ??
            LocaleService.instance.currentL10n;
        ScaffoldMessenger.maybeOf(currentContext)?.showSnackBar(
          SnackBar(
            content: Text(l10n.restoreError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await _cleanupTempFile(filePath);
      _isHandling = false;
    }
  }

  Future<void> _cleanupTempFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}