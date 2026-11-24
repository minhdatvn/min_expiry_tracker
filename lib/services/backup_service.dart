import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import 'calendar_service.dart';
import 'database_service.dart';
import 'log_service.dart';
import 'notify_service.dart';

class BackupPreview {
  final List<HouseholdItem> items;
  final DateTime? exportedAt;

  const BackupPreview({
    required this.items,
    required this.exportedAt,
  });
}

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  // Chữ ký nhị phân 8 byte "METBAK01" để Android/app khác không nhận nhầm là text hay file zip
  static const List<int> _magicHeader = [
    0x4D, 0x45, 0x54, 0x42, 0x41, 0x4B, 0x30, 0x31,
  ];
  static const String fileExtension = 'minexpiry';

  // Tín hiệu báo các màn hình (HomeScreen) tự tải lại danh sách khi khôi phục xong
  final ValueNotifier<int> restoreVersionNotifier = ValueNotifier<int>(0);

  bool _hasMagicHeader(List<int> bytes) {
    if (bytes.length <= _magicHeader.length) return false;
    for (int i = 0; i < _magicHeader.length; i++) {
      if (bytes[i] != _magicHeader[i]) return false;
    }
    return true;
  }

  Future<int> exportBackup() async {
    final items = await DatabaseService.instance.getAllItems();

    final Map<String, dynamic> backupPayload = {
      'app': 'MinExpiryTracker',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
    };

    final String jsonString = jsonEncode(backupPayload);
    final List<int> compressed = gzip.encode(utf8.encode(jsonString));
    final List<int> outputBytes = [..._magicHeader, ...compressed];

    final String dateStamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String fileName = 'MinExpiryTracker_$dateStamp.$fileExtension';

    final Directory tempDir = await getTemporaryDirectory();
    final File backupFile = File('${tempDir.path}/$fileName');
    await backupFile.writeAsBytes(outputBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(backupFile.path, mimeType: 'application/octet-stream'),
        ],
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

  // Đọc & kiểm tra tính hợp lệ của file (.minexpiry mới hoặc .json cũ) trước khi hỏi xác nhận
  Future<BackupPreview> inspectBackupFile(String filePath) async {
    final File file = File(filePath);
    final List<int> bytes = await file.readAsBytes();

    final String content;
    if (_hasMagicHeader(bytes)) {
      final compressedPayload = bytes.sublist(_magicHeader.length);
      content = utf8.decode(gzip.decode(compressedPayload));
    } else {
      // Tương thích ngược với các file .json đã sao lưu trước đây
      content = utf8.decode(bytes);
    }

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

    final DateTime? exportedAt = decoded['exportedAt'] != null
        ? DateTime.tryParse(decoded['exportedAt'].toString())
        : null;

    return BackupPreview(
      items: restoredItems,
      exportedAt: exportedAt,
    );
  }

  // Thực thi khôi phục (ghi đè toàn bộ) từ dữ liệu đã kiểm tra hợp lệ
  Future<int> restoreFromPreview(BackupPreview preview) async {
    // Bước 1: Dọn các sự kiện Lịch của dữ liệu cũ đang nằm trên máy hiện tại
    final existingItems = await DatabaseService.instance.getAllItems();
    for (final oldItem in existingItems) {
      await CalendarService.instance.deleteItemCalendarEvents(oldItem);
    }

    // Bước 2: Xóa sạch mã Lịch cũ (calendarEventId & calendarId) từ máy trước
    final cleanedItems = preview.items.map((item) {
      final resetAlerts = item.alerts
          .map((a) => a.copyWith(clearCalendarEventId: true))
          .toList();
      return item.copyWith(alerts: resetAlerts);
    }).toList();

    // Bước 3: Ghi đè toàn bộ vào SQLite trong 1 giao dịch nguyên tử
    final savedItems =
        await DatabaseService.instance.replaceAllItems(cleanedItems);

    // Bước 4: Đặt lại toàn bộ Thông báo offline và đồng bộ mới sang Lịch
    await NotifyService.instance.cancelAllAlerts();
    bool calendarUnavailable = false;

    for (final item in savedItems) {
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

    await DatabaseService.instance.compactDatabase();

    // Thông báo cho HomeScreen tự tải lại danh sách mới
    restoreVersionNotifier.value++;

    return savedItems.length;
  }

  // Chọn file thủ công và kiểm tra hợp lệ trước khi hiện hộp thoại xác nhận
  Future<BackupPreview?> pickAndInspectBackup() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    return await inspectBackupFile(result.files.single.path!);
  }
}