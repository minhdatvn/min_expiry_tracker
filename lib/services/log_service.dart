import 'database_service.dart';

// Khuôn mẫu cho 1 dòng Nhật ký (Log) của ứng dụng
class AppLog {
  final int? id;
  final DateTime timestamp;
  final String action;  // VD: ADD, UPDATE, DELETE, NOTIFY, CALENDAR, BACKUP, ERROR
  final String message; // Nội dung chi tiết sự kiện

  AppLog({
    this.id,
    required this.timestamp,
    required this.action,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'message': message,
    };
  }

  factory AppLog.fromMap(Map<String, dynamic> map) {
    return AppLog(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      action: map['action'],
      message: map['message'],
    );
  }
}

class LogService {
  static final LogService instance = LogService._init();
  LogService._init();

  // Ghi thêm 1 dòng nhật ký vào bảng app_logs trong SQLite
  Future<void> addLog(String action, String message) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.insert('app_logs', {
        'timestamp': DateTime.now().toIso8601String(),
        'action': action,
        'message': message,
      });
    } catch (_) {
      // Đảm bảo lỗi ghi log (nếu có) không bao giờ làm sập chức năng chính của app
    }
  }

  // Lấy danh sách log mới nhất để hiển thị lên màn hình Log
  Future<List<AppLog>> getLogs({int limit = 150}) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'app_logs',
      orderBy: 'id DESC', // Mới nhất xếp lên trên cùng
      limit: limit,
    );
    return rows.map((row) => AppLog.fromMap(row)).toList();
  }

  // Dọn sạch toàn bộ nhật ký khi người dùng bấm nút Xóa Log
  Future<void> clearLogs() async {
    final db = await DatabaseService.instance.database;
    await db.delete('app_logs');
  }
}