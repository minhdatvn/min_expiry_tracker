// Khuôn mẫu (Class) định nghĩa toàn bộ thông tin của 1 vật phẩm gia đình
class HouseholdItem {
  // --- CÁC THÔNG TIN BẮT BUỘC (Không có dấu ?) ---
  final String name;          // Tên vật phẩm (VD: "Vitamin C Serum")
  final String category;      // Loại (VD: "Cosmetics", "Medicine", "Food")
  final DateTime expiryDate;  // Hạn sử dụng in trên bao bì

  // --- CÁC THÔNG TIN TÙY CHỌN (Có dấu ? nghĩa là có thể để trống/null) ---
  final int? id;              // Mã định danh (SQLite sẽ tự cấp khi lưu)
  final DateTime? openedDate; // Ngày bắt đầu mở nắp
  final int? paoMonths;       // Hạn sử dụng sau khi mở nắp tính bằng THÁNG (VD: 6)
  final int? quantity;        // Số lượng (VD: 2)
  final String? imagePath;    // Đường dẫn tới file ảnh chụp lưu trong điện thoại
  final String? owner;        // Người sử dụng (VD: "Mom", "Me", "Shared")

  // --- CẤU HÌNH CẢNH BÁO RIÊNG CHO TỪNG MÓN ---
  // Danh sách số ngày nhắc trước khi hết hạn (Mặc định là 30 ngày và 7 ngày)
  final List<int> alertDays;

  // Hàm khởi tạo (Constructor): Dùng để tạo ra một vật phẩm mới
  HouseholdItem({
    this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
    this.openedDate,
    this.paoMonths,
    this.quantity,
    this.imagePath,
    this.owner,
    this.alertDays = const [30, 7], // Nếu người dùng không tự chỉnh, app dùng mặc định này
  });

  // 1. Tự động tính "Hạn sử dụng thực tế" (kết hợp HSD bao bì và HSD sau khi mở nắp)
  DateTime get effectiveExpiryDate {
    // Nếu người dùng có nhập cả Ngày mở nắp VÀ Số tháng dùng sau khi mở
    if (openedDate != null && paoMonths != null) {
      // Cộng thêm số tháng vào ngày mở nắp
      final paoExpiry = DateTime(
        openedDate!.year,
        openedDate!.month + paoMonths!,
        openedDate!.day,
      );
      // So sánh: ngày nào tới trước thì lấy ngày đó để đảm bảo an toàn!
      return paoExpiry.isBefore(expiryDate) ? paoExpiry : expiryDate;
    }
    // Nếu chưa mở nắp, dùng HSD in trên bao bì
    return expiryDate;
  }

  // 2. Tự động tính số ngày còn lại cho đến hạn sử dụng thực tế
  int get daysRemaining {
    final now = DateTime.now();
    // Đưa cả hai về 0 giờ 0 phút để đếm tròn ngày chính xác
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      effectiveExpiryDate.year,
      effectiveExpiryDate.month,
      effectiveExpiryDate.day,
    );
    return target.difference(today).inDays;
  }

  // 3. Đóng gói dữ liệu thành Map (dạng Từ khóa : Giá trị) để lưu vào SQLite hoặc file JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'expiryDate': expiryDate.toIso8601String(),
      // Dấu ?. nghĩa là: chỉ chuyển sang chữ nếu openedDate không bị trống
      'openedDate': openedDate?.toIso8601String(),
      'paoMonths': paoMonths,
      'quantity': quantity,
      'imagePath': imagePath,
      'owner': owner,
      // SQLite không lưu trực tiếp được List, nên ta ghép [30, 7] thành chuỗi "30,7"
      'alertDays': alertDays.join(','),
    };
  }

  // 4. Mở gói dữ liệu từ SQLite / file JSON trở lại thành vật phẩm HouseholdItem
  factory HouseholdItem.fromMap(Map<String, dynamic> map) {
    // Tách chuỗi "30,7" ngược lại thành danh sách số [30, 7]
    final String rawAlerts = map['alertDays'] ?? '';
    final List<int> parsedAlerts = rawAlerts.isEmpty
        ? []
        : rawAlerts.split(',').map((e) => int.parse(e.trim())).toList();

    return HouseholdItem(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      expiryDate: DateTime.parse(map['expiryDate']),
      openedDate: map['openedDate'] != null
          ? DateTime.parse(map['openedDate'])
          : null,
      paoMonths: map['paoMonths'],
      quantity: map['quantity'],
      imagePath: map['imagePath'],
      owner: map['owner'],
      alertDays: parsedAlerts,
    );
  }
}
