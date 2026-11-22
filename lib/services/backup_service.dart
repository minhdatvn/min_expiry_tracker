import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/item_model.dart';
import 'database_service.dart';
import 'notify_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  // --- 1. XUẤT DỮ LIỆU RA FILE .JSON (SAO LƯU) ---
  // Trả về số lượng vật phẩm đã sao lưu
  Future<int> exportBackup() async {
    // Lấy toàn bộ danh sách vật phẩm hiện có trong SQLite
    final items = await DatabaseService.instance.getAllItems();

    // Đóng gói dữ liệu kèm "nhãn nhận diện" để sau này kiểm tra file có đúng của app không
    final Map<String, dynamic> backupPayload = {
      'app': 'MinExpiryTracker',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
    };

    // Chuyển toàn bộ dữ liệu thành chuỗi văn bản JSON chuẩn
    final String jsonString = jsonEncode(backupPayload);

    // Tạo tên file có gắn ngày hiện tại, VD: MinExpiryTracker_2026-11-22.json
    final String dateStamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String fileName = 'MinExpiryTracker_$dateStamp.json';

    // Lưu tạm file .json vào thư mục đệm của app
    final Directory tempDir = await getTemporaryDirectory();
    final File backupFile = File('${tempDir.path}/$fileName');
    await backupFile.writeAsString(jsonString);

    // Mở bảng chia sẻ gốc của Android -> Chọn "Save to Drive" hoặc lưu vào máy
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backupFile.path)],
        subject: 'MinExpiryTracker Backup ($dateStamp)',
      ),
    );

    return items.length;
  }

  // --- 2. NHẬP DỮ LIỆU TỪ FILE .JSON (KHÔI PHỤC) ---
  // Trả về: số lượng món đã khôi phục, hoặc null nếu người dùng bấm Hủy chọn file
  Future<int?> importBackup() async {
    // Mở trình chọn file của Android (có thể chọn từ Bộ nhớ máy hoặc Google Drive)
    // Mẹo: Dùng FileType.any vì một số máy Android bị ẩn file .json nếu lọc đuôi quá chặt
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    // Người dùng bấm Back không chọn file nào
    if (result == null || result.files.single.path == null) {
      return null;
    }

    final File file = File(result.files.single.path!);
    final String content = await file.readAsString();

    // Bước A: Giải mã và kiểm tra file TRƯỚC KHI xóa dữ liệu cũ (đảm bảo an toàn tuyệt đối!)
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'MinExpiryTracker' ||
        decoded['items'] is! List) {
      throw const FormatException('Invalid MinExpiryTracker backup file.');
    }

    // Chuyển danh sách JSON thành danh sách HouseholdItem hoàn chỉnh
    final List<dynamic> rawItems = decoded['items'];
    final List<HouseholdItem> restoredItems = rawItems
        .map((e) => HouseholdItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // Bước B: File đã xác nhận hợp lệ -> tiến hành thay thế dữ liệu cũ và đặt lại thông báo
    await DatabaseService.instance.clearAllItems();
    await NotifyService.instance.cancelAllAlerts();

    for (final item in restoredItems) {
      final newId = await DatabaseService.instance.insertItem(item);
      await NotifyService.instance.scheduleItemAlerts(item, overrideId: newId);
    }

    return restoredItems.length;
  }
}
