import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
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

    await DatabaseService.instance.clearAllItems();
    await NotifyService.instance.cancelAllAlerts();

    for (final item in restoredItems) {
      final newId = await DatabaseService.instance.insertItem(item);
      await NotifyService.instance.scheduleItemAlerts(item, overrideId: newId);
    }

    await LogService.instance.addLog(
      'BACKUP',
      encodeLogMessage('logBackupRestored', {'count': restoredItems.length}),
    );

    return restoredItems.length;
  }
}