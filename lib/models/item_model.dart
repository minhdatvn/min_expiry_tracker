import 'dart:convert';    // Chuyển đổi giữa Ảnh <-> Chuỗi Base64
import 'dart:typed_data'; // Kiểu dữ liệu mảng byte (Uint8List) để vẽ ảnh

class HouseholdItem {
  // --- THÔNG TIN BẮT BUỘC ---
  final String name;
  final String category;
  final DateTime expiryDate;

  // --- THÔNG TIN TÙY CHỌN ---
  final int? id;
  final DateTime? openedDate;
  final int? paoValue;       // NÂNG CẤP: Con số PAO (VD: 6, 14, 24)
  final String paoUnit;      // MỚI: Đơn vị PAO ('months', 'days', hoặc 'hours')
  final int? quantity;
  final String? imageBase64;
  final String? owner;

  // --- CẤU HÌNH CẢNH BÁO RIÊNG ---
  final List<int> alertDays;

  HouseholdItem({
    this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
    this.openedDate,
    this.paoValue,
    this.paoUnit = 'months', // Mặc định vẫn là 'months' để tương thích dữ liệu cũ
    this.quantity,
    this.imageBase64,
    this.owner,
    this.alertDays = const [30, 7],
  });

  // 1. Giải mã chuỗi imageBase64 thành dữ liệu ảnh thô để vẽ lên màn hình
  Uint8List? get imageBytes {
    if (imageBase64 == null || imageBase64!.isEmpty) {
      return null;
    }
    return base64Decode(imageBase64!);
  }

  // Kiểm tra nhanh món này có đang kích hoạt theo dõi PAO hợp lệ không
  bool get hasPao => openedDate != null && paoValue != null && paoValue! > 0;

  // Kiểm tra nhanh món này có đang tính PAO theo GIỜ không
  bool get isHourlyPao => hasPao && paoUnit == 'hours';

  // Tạo nhãn PAO ngắn gọn để hiển thị lên thẻ (VD: "PAO 6M", "PAO 3D", "PAO 4H")
  String get paoShortLabel {
    if (!hasPao) return '';
    switch (paoUnit) {
      case 'hours':
        return 'PAO ${paoValue}H';
      case 'days':
        return 'PAO ${paoValue}D';
      case 'months':
      default:
        return 'PAO ${paoValue}M';
    }
  }

  // 2. Tính hạn sử dụng thực tế (hỗ trợ cả Tháng, Ngày và Giờ)
  DateTime get effectiveExpiryDate {
    if (hasPao) {
      final DateTime paoExpiry;

      // Dùng switch để cộng thời gian đúng theo đơn vị đã chọn
      switch (paoUnit) {
        case 'hours':
          paoExpiry = openedDate!.add(Duration(hours: paoValue!));
          break;
        case 'days':
          paoExpiry = openedDate!.add(Duration(days: paoValue!));
          break;
        case 'months':
        default:
          paoExpiry = DateTime(
            openedDate!.year,
            openedDate!.month + paoValue!,
            openedDate!.day,
            openedDate!.hour,
            openedDate!.minute,
          );
          break;
      }

      // So sánh với mốc cuối ngày (23:59) của ngày hết hạn trên bao bì
      // để món mở ngay trong ngày cuối vẫn đếm đúng giờ PAO
      final endOfExpiryDay = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
        23,
        59,
      );

      if (paoExpiry.isBefore(endOfExpiryDay)) {
        return paoExpiry;
      }
      return isHourlyPao ? endOfExpiryDay : expiryDate;
    }
    return expiryDate;
  }

  // 3. Khoảng thời gian còn lại chính xác tới từng giờ/phút (dùng cho đồ theo giờ & sắp xếp)
  Duration get timeRemaining => effectiveExpiryDate.difference(DateTime.now());

  // 4. Tính số ngày còn lại (dùng cho đồ theo Ngày/Tháng như trước)
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      effectiveExpiryDate.year,
      effectiveExpiryDate.month,
      effectiveExpiryDate.day,
    );
    return target.difference(today).inDays;
  }

  // 5. Đóng gói dữ liệu để lưu vào SQLite hoặc xuất file JSON sao lưu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'expiryDate': expiryDate.toIso8601String(),
      'openedDate': openedDate?.toIso8601String(),
      // MẸO TƯƠNG THÍCH NGƯỢC: Giữ nguyên tên khóa 'paoMonths' trong SQLite/JSON
      // để không phải xóa bảng cũ và vẫn mở được file sao lưu từ phiên bản v1.0
      'paoMonths': paoValue,
      'paoUnit': paoUnit,
      'quantity': quantity,
      'imageBase64': imageBase64,
      'owner': owner,
      'alertDays': alertDays.join(','),
    };
  }

  // 6. Mở gói dữ liệu từ SQLite / file JSON
  factory HouseholdItem.fromMap(Map<String, dynamic> map) {
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
      paoValue: map['paoMonths'],
      // Nếu đọc file backup v1.0 chưa có 'paoUnit', toán tử '??' sẽ tự điền 'months'
      paoUnit: map['paoUnit'] ?? 'months',
      quantity: map['quantity'],
      imageBase64: map['imageBase64'],
      owner: map['owner'],
      alertDays: parsedAlerts,
    );
  }
}