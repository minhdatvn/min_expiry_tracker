import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import 'calendar_service.dart';
import 'database_service.dart';
import 'log_service.dart';
import 'notify_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  Future<int> exportBackup() async {
    final items = await DatabaseService.instance.getAllItems();

    final Map<String, dynamic> backupPayload = {
      'app': 'MinExpiryTracker',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
    };

    final String jsonString = jsonEncode(backupPayload);
    final String dateStamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String fileName = 'MinExpiryTracker_$dateStamp.json';

    final Directory tempDir = await getTemporaryDirectory();
    final File backupFile = File('${tempDir.path}/$fileName');
    await backupFile.writeAsString(jsonString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backupFile.path)],
        subject: 'MinExpiryTracker Backup ($dateStamp)',
      ),
    );

    await LogService.instance.addLog(
      'BACKUP',
      encodeLogMessage('logBackupExported', {
        'count': items.length,
        'fileName': fileName,
      }),
    );

    return items.length;
  }

  Future<int?> importBackup() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final File file = File(result.files.single.path!);
    final String content = await file.readAsString();

    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'MinExpiryTracker' ||
        decoded['items'] is! List) {
      await LogService.instance.addLog(
        'ERROR',
        encodeLogMessage('logRestoreInvalid'),
      );
      throw const FormatException('Invalid MinExpiryTracker backup file.');
    }

    final List<dynamic> rawItems = decoded['items'];
    final List<HouseholdItem> restoredItems = rawItems
        .map((e) => HouseholdItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // Bước 1: Dọn các sự kiện Lịch của dữ liệu cũ đang nằm trên máy hiện tại
    final existingItems = await DatabaseService.instance.getAllItems();
    for (final oldItem in existingItems) {
      await CalendarService.instance.deleteItemCalendarEvents(oldItem);
    }

    // Bước 2: Xóa sạch mã Lịch cũ (calendarEventId & calendarId) từ máy trước trong file backup
    final cleanedItems = restoredItems.map((item) {
      final resetAlerts = item.alerts
          .map((a) => a.copyWith(clearCalendarEventId: true))
          .toList();
      return item.copyWith(alerts: resetAlerts);
    }).toList();

    // Bước 3: Ghi đè toàn bộ vào SQLite trong 1 giao dịch nguyên tử
    final savedItems =
        await DatabaseService.instance.replaceAllItems(cleanedItems);

    // Bước 4: Đặt lại toàn bộ Thông báo offline và đồng bộ mới sang Lịch của máy hiện tại
    await NotifyService.instance.cancelAllAlerts();
    bool calendarUnavailable = false;

    for (final item in savedItems) {
      // Truyền cancelExisting: false vì vừa gọi cancelAllAlerts() ngay phía trên -> khôi phục nhanh hơn
      await NotifyService.instance.scheduleItemAlerts(
        item,
        cancelExisting: false,
      );

      if (!calendarUnavailable && item.alerts.any((a) => a.addToCalendar)) {
        final syncResult =
            await CalendarService.instance.syncItemCalendarEvents(item);

        if (syncResult.errorKey == 'logCalendarDenied' ||
            syncResult.errorKey == 'logCalendarNoWritable') {
          calendarUnavailable = true;
        } else {
          final syncedItem = item.copyWith(alerts: syncResult.alerts);
          await DatabaseService.instance.updateItem(syncedItem);
        }
      }
    }

    await LogService.instance.addLog(
      'BACKUP',
      encodeLogMessage('logBackupRestored', {'count': savedItems.length}),
    );

    // Thu hồi dung lượng trống của dữ liệu ảnh cũ vừa bị ghi đè
    await DatabaseService.instance.compactDatabase();

    return savedItems.length;
  }
}