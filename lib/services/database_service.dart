import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/item_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('min_expiry_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1, // Giữ version 1 sạch sẽ trong giai đoạn đang phát triển
      onCreate: _createDB,
    );
  }

  // Tạo mới 2 bảng hoàn chỉnh ngay từ đầu: items và app_logs
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        expiryDate TEXT NOT NULL,
        openedDate TEXT,
        paoValue INTEGER,
        paoUnit TEXT DEFAULT 'months',
        quantity INTEGER,
        imageBase64 TEXT,
        owner TEXT,
        location TEXT,
        notes TEXT,
        alerts TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        action TEXT NOT NULL,
        message TEXT NOT NULL
      )
    ''');
  }

  // 1. CREATE
  Future<int> insertItem(HouseholdItem item) async {
    final db = await instance.database;
    final data = item.toMap()..remove('id');
    return await db.insert('items', data);
  }

  // 2. READ
  Future<List<HouseholdItem>> getAllItems() async {
    final db = await instance.database;
    final maps = await db.query('items');
    return maps.map((map) => HouseholdItem.fromMap(map)).toList();
  }

  // 3. UPDATE
  Future<int> updateItem(HouseholdItem item) async {
    final db = await instance.database;
    return await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // 4. DELETE
  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 5. Xóa toàn bộ danh sách vật phẩm (dùng trước khi Restore)
  Future<void> clearAllItems() async {
    final db = await instance.database;
    await db.delete('items');
  }

  // 6. Lấy danh sách Chủ sở hữu đã dùng (không trùng lặp) để chọn nhanh & lọc
  Future<List<String>> getDistinctOwners() async {
    final db = await instance.database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT owner FROM items WHERE owner IS NOT NULL AND TRIM(owner) != '' ORDER BY owner ASC",
    );
    return rows.map((r) => (r['owner'] as String).trim()).toList();
  }

  // 7. Lấy danh sách Vị trí đã dùng (không trùng lặp) để chọn nhanh
  Future<List<String>> getDistinctLocations() async {
    final db = await instance.database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT location FROM items WHERE location IS NOT NULL AND TRIM(location) != '' ORDER BY location ASC",
    );
    return rows.map((r) => (r['location'] as String).trim()).toList();
  }

  // 8. Thay thế toàn bộ vật phẩm trong 1 giao dịch nguyên tử (dùng khi Restore)
  Future<List<HouseholdItem>> replaceAllItems(List<HouseholdItem> items) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      await txn.delete('items');
      final List<HouseholdItem> savedItems = [];
      for (final item in items) {
        final data = item.toMap()..remove('id');
        final newId = await txn.insert('items', data);
        savedItems.add(item.copyWith(id: newId));
      }
      return savedItems;
    });
  }

  // 9. Thu hồi dung lượng trống trong file SQLite (giúp file .db co gọn thực tế trên bộ nhớ máy)
  Future<void> compactDatabase() async {
    try {
      final db = await instance.database;
      await db.execute('VACUUM');
    } catch (_) {
      // Lệnh VACUUM không chạy được khi đang mở transaction -> bỏ qua êm ái nếu bận
    }
  }
}