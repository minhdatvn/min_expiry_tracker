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
      version: 2,              // Tăng từ 1 lên 2 để kích hoạt onUpgrade trên máy ảo
      onCreate: _createDB,     // Chạy khi cài app mới hoàn toàn
      onUpgrade: _upgradeDB,   // Chạy tự động khi nâng cấp từ bản cũ (v1 -> v2)
    );
  }

  // Tạo bảng mới (dành cho máy cài lần đầu) -> Đã có sẵn cột paoUnit
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        expiryDate TEXT NOT NULL,
        openedDate TEXT,
        paoMonths INTEGER,
        paoUnit TEXT DEFAULT 'months',
        quantity INTEGER,
        imageBase64 TEXT,
        owner TEXT,
        alertDays TEXT
      )
    ''');
  }

  // Tự động thêm cột paoUnit nếu máy đã có sẵn database v1 (khỏi phải gỡ app)
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE items ADD COLUMN paoUnit TEXT DEFAULT 'months'",
      );
    }
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

  // 5. Xóa toàn bộ dữ liệu (dùng trước khi Restore)
  Future<void> clearAllItems() async {
    final db = await instance.database;
    await db.delete('items');
  }
}