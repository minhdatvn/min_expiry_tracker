import 'database_service.dart';

class AppLog {
  final int? id;
  final DateTime timestamp;
  final String action;
  final String message;

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

  // Giới hạn tối đa 200 bản ghi trong SQLite để file database không phình to theo năm tháng
  static const int _maxStoredLogs = 200;

  Future<void> addLog(String action, String message) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.insert('app_logs', {
        'timestamp': DateTime.now().toIso8601String(),
        'action': action,
        'message': message,
      });

      // Tự động xóa các dòng log cũ vượt quá giới hạn 200 dòng mới nhất
      await db.rawDelete('''
        DELETE FROM app_logs
        WHERE id NOT IN (
          SELECT id FROM app_logs ORDER BY id DESC LIMIT ?
        )
      ''', [_maxStoredLogs]);
    } catch (_) {
      // Đảm bảo lỗi ghi log không bao giờ làm gián đoạn chức năng chính
    }
  }

  Future<List<AppLog>> getLogs({int limit = 150}) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'app_logs',
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map((row) => AppLog.fromMap(row)).toList();
  }

  Future<void> clearLogs() async {
    final db = await DatabaseService.instance.database;
    await db.delete('app_logs');
    await DatabaseService.instance.compactDatabase(); // Thu hồi dung lượng trống sau khi xóa sạch Log
  }
}