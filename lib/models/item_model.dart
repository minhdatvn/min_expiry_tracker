import 'dart:convert';    // Thư viện có sẵn của Dart để chuyển đổi giữa Ảnh <-> Chuỗi Base64
import 'dart:typed_data'; // Thư viện cung cấp kiểu dữ liệu mảng byte (Uint8List) để vẽ ảnh

class HouseholdItem {
  // --- THÔNG TIN BẮT BUỘC ---
  final String name;
  final String category;
  final DateTime expiryDate;

  // --- THÔNG TIN TÙY CHỌN ---
  final int? id;
  final DateTime? openedDate;
  final int? paoMonths;
  final int? quantity;
  final String? imageBase64; // ĐÃ CẬP NHẬT: Lưu trực tiếp ảnh đã nén dưới dạng chuỗi văn bản
  final String? owner;

  // --- CẤU HÌNH CẢNH BÁO RIÊNG ---
  final List<int> alertDays;

  HouseholdItem({
    this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
    this.openedDate,
    this.paoMonths,
    this.quantity,
    this.imageBase64,
    this.owner,
    this.alertDays = const [30, 7],
  });

  // 1. Giải mã chuỗi imageBase64 thành dữ liệu ảnh thô (Uint8List) để Flutter vẽ lên màn hình
  Uint8List? get imageBytes {
    // Nếu không có ảnh thì trả về null (trống)
    if (imageBase64 == null || imageBase64!.isEmpty) {
      return null;
    }
    // Dịch ngược chuỗi văn bản về lại dữ liệu hình ảnh
    return base64Decode(imageBase64!);
  }

  // 2. Tính hạn sử dụng thực tế (so sánh HSD bao bì và HSD từ lúc mở nắp)
  DateTime get effectiveExpiryDate {
    if (openedDate != null && paoMonths != null) {
      final paoExpiry = DateTime(
        openedDate!.year,
        openedDate!.month + paoMonths!,
        openedDate!.day,
      );
      return paoExpiry.isBefore(expiryDate) ? paoExpiry : expiryDate;
    }
    return expiryDate;
  }

  // 3. Tính số ngày còn lại
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

  // 4. Đóng gói dữ liệu để lưu vào SQLite hoặc xuất file JSON sao lưu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'expiryDate': expiryDate.toIso8601String(),
      'openedDate': openedDate?.toIso8601String(),
      'paoMonths': paoMonths,
      'quantity': quantity,
      'imageBase64': imageBase64, // Lưu thẳng chuỗi ảnh vào dữ liệu app
      'owner': owner,
      'alertDays': alertDays.join(','),
    };
  }

  // 5. Mở gói dữ liệu từ SQLite / file JSON
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
      paoMonths: map['paoMonths'],
      quantity: map['quantity'],
      imageBase64: map['imageBase64'],
      owner: map['owner'],
      alertDays: parsedAlerts,
    );
  }
}
