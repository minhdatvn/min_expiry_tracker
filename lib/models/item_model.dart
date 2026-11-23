import 'dart:convert';
import 'dart:typed_data';

// --- MỚI: ĐỐI TƯỢNG MỐC CẢNH BÁO THÔNG MINH ---
// Mỗi mốc không chỉ là 1 con số đơn thuần mà lưu đủ: Số + Đơn vị + Có thêm Lịch không + Mã sự kiện Lịch
class AlertMilestone {
  final int value;               // Con số (VD: 1, 3, 6, 30)
  final String unit;             // 'days' hoặc 'hours'
  final bool addToCalendar;      // True nếu người dùng tick ô "Thêm vào Lịch"
  final String? calendarEventId; // Mã sự kiện Android trả về để sau này tự xóa/sửa

  const AlertMilestone({
    required this.value,
    this.unit = 'days',
    this.addToCalendar = false,
    this.calendarEventId,
  });

  // Hiển thị chữ đẹp trên giao diện (VD: "6 hours before", "1 day before")
  String get label {
    if (unit == 'hours') {
      return value == 1 ? '1 hour before' : '$value hours before';
    }
    return value == 1 ? '1 day before' : '$value days before';
  }

  // Quy đổi ra giờ để sắp xếp các mốc từ xa đến gần
  int get totalHours => unit == 'hours' ? value : value * 24;

  // Tạo bản sao có thay đổi một vài trường (kèm cờ xóa hẳn calendarEventId khi cần)
  AlertMilestone copyWith({
    int? value,
    String? unit,
    bool? addToCalendar,
    String? calendarEventId,
    bool clearCalendarEventId = false,
  }) {
    return AlertMilestone(
      value: value ?? this.value,
      unit: unit ?? this.unit,
      addToCalendar: addToCalendar ?? this.addToCalendar,
      calendarEventId: clearCalendarEventId
          ? null
          : (calendarEventId ?? this.calendarEventId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'unit': unit,
      'addToCalendar': addToCalendar,
      'calendarEventId': calendarEventId,
    };
  }

  factory AlertMilestone.fromMap(Map<String, dynamic> map) {
    return AlertMilestone(
      value: map['value'] ?? 1,
      unit: map['unit'] ?? 'days',
      addToCalendar: map['addToCalendar'] ?? false,
      calendarEventId: map['calendarEventId'],
    );
  }
}

class HouseholdItem {
  // --- THÔNG TIN BẮT BUỘC ---
  final String name;
  final String category;
  final DateTime expiryDate;

  // --- THÔNG TIN TÙY CHỌN ---
  final int? id;
  final DateTime? openedDate;
  final int? paoValue;
  final String paoUnit;        // 'months', 'days', hoặc 'hours'
  final int? quantity;
  final String? imageBase64;
  final String? owner;         // Chủ sở hữu (chọn từ danh sách & thống kê)
  final String? location;      // MỚI: Vị trí cất giữ (VD: Tủ lạnh, Tủ thuốc)
  final String? notes;         // MỚI: Ghi chú tự do nhiều dòng

  // --- CẤU HÌNH CẢNH BÁO RIÊNG (ĐÃ NÂNG CẤP) ---
  final List<AlertMilestone> alerts;

  HouseholdItem({
    this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
    this.openedDate,
    this.paoValue,
    this.paoUnit = 'months',
    this.quantity,
    this.imageBase64,
    this.owner,
    this.location,
    this.notes,
    this.alerts = const [
      AlertMilestone(value: 30, unit: 'days'),
      AlertMilestone(value: 7, unit: 'days'),
    ],
  });

  // Giữ lại getter tương thích cho phần tô màu thẻ theo số ngày
  List<int> get alertDays => alerts
      .where((a) => a.unit == 'days')
      .map((a) => a.value)
      .toList();

  // Tạo bản sao vật phẩm (rất tiện khi cập nhật lại ID hoặc mã sự kiện Lịch)
  HouseholdItem copyWith({
    int? id,
    String? name,
    String? category,
    DateTime? expiryDate,
    DateTime? openedDate,
    int? paoValue,
    String? paoUnit,
    int? quantity,
    String? imageBase64,
    String? owner,
    String? location,
    String? notes,
    List<AlertMilestone>? alerts,
  }) {
    return HouseholdItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      openedDate: openedDate ?? this.openedDate,
      paoValue: paoValue ?? this.paoValue,
      paoUnit: paoUnit ?? this.paoUnit,
      quantity: quantity ?? this.quantity,
      imageBase64: imageBase64 ?? this.imageBase64,
      owner: owner ?? this.owner,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      alerts: alerts ?? this.alerts,
    );
  }

  Uint8List? get imageBytes {
    if (imageBase64 == null || imageBase64!.isEmpty) return null;
    return base64Decode(imageBase64!);
  }

  bool get hasPao => openedDate != null && paoValue != null && paoValue! > 0;
  bool get isHourlyPao => hasPao && paoUnit == 'hours';

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

  // Tính hạn sử dụng thực tế (Tháng / Ngày / Giờ)
  DateTime get effectiveExpiryDate {
    if (hasPao) {
      final DateTime paoExpiry;
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

  // Tính chính xác thời điểm nhắc nhở (dùng chung cho cả Thông báo app & Lịch điện thoại)
  DateTime calculateAlertTime(AlertMilestone alert) {
    final expiry = effectiveExpiryDate;
    if (alert.unit == 'hours') {
      return expiry.subtract(Duration(hours: alert.value));
    }
    // Với mốc theo ngày -> nhắc vào lúc 9:00 sáng của ngày đó
    final alertDay = expiry.subtract(Duration(days: alert.value));
    return DateTime(alertDay.year, alertDay.month, alertDay.day, 9, 0);
  }

  Duration get timeRemaining => effectiveExpiryDate.difference(DateTime.now());

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

  // Đóng gói dữ liệu để lưu vào SQLite hoặc xuất JSON sao lưu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'expiryDate': expiryDate.toIso8601String(),
      'openedDate': openedDate?.toIso8601String(),
      'paoValue': paoValue,   // Đổi tên cột chuẩn theo ý nghĩa mới
      'paoUnit': paoUnit,
      'quantity': quantity,
      'imageBase64': imageBase64,
      'owner': owner,
      'location': location,
      'notes': notes,
      // Lưu trực tiếp danh sách mốc cảnh báo dưới dạng chuỗi JSON
      'alerts': jsonEncode(alerts.map((a) => a.toMap()).toList()),
    };
  }

  // Mở gói dữ liệu thẳng từ định dạng JSON mới (không cần rẽ nhánh đọc bản cũ)
  factory HouseholdItem.fromMap(Map<String, dynamic> map) {
    final String rawAlerts = (map['alerts'] ?? '').toString().trim();
    final List<AlertMilestone> parsedAlerts = rawAlerts.isEmpty
        ? []
        : (jsonDecode(rawAlerts) as List<dynamic>)
            .map((e) => AlertMilestone.fromMap(Map<String, dynamic>.from(e)))
            .toList();

    return HouseholdItem(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      expiryDate: DateTime.parse(map['expiryDate']),
      openedDate: map['openedDate'] != null
          ? DateTime.parse(map['openedDate'])
          : null,
      paoValue: map['paoValue'],
      paoUnit: map['paoUnit'] ?? 'months',
      quantity: map['quantity'],
      imageBase64: map['imageBase64'],
      owner: map['owner'],
      location: map['location'],
      notes: map['notes'],
      alerts: parsedAlerts,
    );
  }
}