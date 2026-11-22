import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/item_model.dart';

class DatabaseService {
  // --- MẪU THIẾT KẾ SINGLETON ---
  // Đảm bảo cả ứng dụng chỉ dùng DUY NHẤT 1 kết nối tới kho dữ liệu,
  // tránh mở nhiều kết nối cùng lúc gây nặng máy hoặc khóa file database.
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  // Hàm khởi tạo riêng tư (có dấu gạch dưới _) để bên ngoài không tự tạo thêm bản sao
  DatabaseService._init();

  // Lấy kết nối database: nếu đã mở rồi thì dùng lại, chưa mở thì khởi tạo mới
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('min_expiry_tracker.db');
    return _database!;
  }

  // Tìm thư mục an toàn trên Android và mở (hoặc tạo mới) file database
  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB, // Hàm này chỉ chạy 1 lần duy nhất khi cài app lần đầu
    );
  }

  // Tạo bảng "items" giống như kẻ tiêu đề các cột trong 1 trang Excel
  // Lưu ý: Tên các cột phải KHỚP 100% với hàm toMap() trong item_model.dart
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        expiryDate TEXT NOT NULL,
        openedDate TEXT,
        paoMonths INTEGER,
        quantity INTEGER,
        imageBase64 TEXT,
        owner TEXT,
        alertDays TEXT
      )
    ''');
  }

  // 1. CREATE: Thêm một vật phẩm mới vào kho và trả về mã ID mà SQLite tự cấp
  Future<int> insertItem(HouseholdItem item) async {
    final db = await instance.database;
    // Bỏ trường 'id' để SQLite tự động đánh số tăng dần (1, 2, 3...)
    final data = item.toMap()..remove('id');
    return await db.insert('items', data);
  }

  // 2. READ: Lấy toàn bộ danh sách vật phẩm đang lưu trong máy
  Future<List<HouseholdItem>> getAllItems() async {
    final db = await instance.database;
    final maps = await db.query('items');

    // Chuyển từng dòng dữ liệu Map từ SQLite thành đối tượng HouseholdItem
    return maps.map((map) => HouseholdItem.fromMap(map)).toList();
  }

  // 3. UPDATE: Cập nhật thông tin một vật phẩm dựa theo đúng mã ID của nó
  Future<int> updateItem(HouseholdItem item) async {
    final db = await instance.database;
    return await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',        // Dấu ? giúp chống lỗi cú pháp và bảo mật truy vấn
      whereArgs: [item.id],   // Thay giá trị item.id vào vị trí dấu ?
    );
  }

  // 4. DELETE: Xóa hẳn một vật phẩm khỏi kho dữ liệu theo ID
  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 5. Xóa toàn bộ các dòng trong bảng items (dùng trước khi khôi phục bản sao lưu)
  Future<void> clearAllItems() async {
    final db = await instance.database;
    await db.delete('items');
  }
}