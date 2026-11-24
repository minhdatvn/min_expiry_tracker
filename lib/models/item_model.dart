import 'dart:convert';
import 'dart:typed_data';

// --- ĐỐI TƯỢNG MỐC CẢNH BÁO THÔNG MINH ---
class AlertMilestone {
  final int value;               // Con số (VD: 1, 3, 6, 30)
  final String unit;             // 'days' hoặc 'hours'
  final bool addToCalendar;      // True nếu người dùng tick ô "Thêm vào Lịch"
  final String? calendarEventId; // Mã sự kiện Android trả về để sau này tự xóa/sửa
  final String? calendarId;      // MỚI: Lưu luôn ID sổ Lịch đã ghi sự kiện để xóa đúng chỗ

  const AlertMilestone({
    required this.value,
    this.unit = 'days',
    this.addToCalendar = false,
    this.calendarEventId,
    this.calendarId,
  });

  // Hiển thị chữ mặc định cho tiêu đề sự kiện Lịch
  String get label {
    if (unit == 'hours') {
      return value == 1 ? '1 hour before' : '$value hours before';
    }
    return value == 1 ? '1 day before' : '$value days before';
  }

  // Quy đổi ra giờ để sắp xếp các mốc từ xa đến gần
  int get totalHours => unit == 'hours' ? value : value * 24;

  // Tạo bản sao có thay đổi một vài trường (cờ clearCalendarEventId xóa sạch cả ID sự kiện lẫn ID sổ Lịch)
  AlertMilestone copyWith({
    int? value,
    String? unit,
    bool? addToCalendar,
    String? calendarEventId,
    String? calendarId,
    bool clearCalendarEventId = false,
  }) {
    return AlertMilestone(
      value: value ?? this.value,
      unit: unit ?? this.unit,
      addToCalendar: addToCalendar ?? this.addToCalendar,
      calendarEventId: clearCalendarEventId
          ? null
          : (calendarEventId ?? this.calendarEventId),
      calendarId: clearCalendarEventId
          ? null
          : (calendarId ?? this.calendarId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'unit': unit,
      'addToCalendar': addToCalendar,
      'calendarEventId': calendarEventId,
      'calendarId': calendarId,
    };
  }

  factory AlertMilestone.fromMap(Map<String, dynamic> map) {
    return AlertMilestone(
      value: (map['value'] as num?)?.toInt() ?? 1,
      unit: (map['unit'] ?? 'days').toString(),
      addToCalendar: map['addToCalendar'] == true,
      calendarEventId: map['calendarEventId'] as String?,
      calendarId: map['calendarId'] as String?,
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

  // Bộ nhớ đệm giúp chỉ giải mã ảnh Base64 đúng 1 lần cho mỗi vật phẩm
  Uint8List? _cachedImageBytes;
  bool _hasDecodedImage = false;

  Uint8List? get imageBytes {
    if (!_hasDecodedImage) {
      _hasDecodedImage = true;
      if (imageBase64 != null && imageBase64!.isNotEmpty) {
        try {
          _cachedImageBytes = base64Decode(imageBase64!);
        } catch (_) {
          _cachedImageBytes = null;
        }
      }
    }
    return _cachedImageBytes;
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

  // Mốc hết hạn thực tế đầy đủ giờ/phút (vật phẩm theo ngày tính đến cuối ngày 23:59)
  DateTime get effectiveDeadline {
    final expiry = effectiveExpiryDate;
    if (isHourlyPao) return expiry;
    return DateTime(expiry.year, expiry.month, expiry.day, 23, 59);
  }

  // Tính chính xác thời điểm nhắc nhở (dùng chung cho cả Thông báo app & Lịch điện thoại)
  DateTime calculateAlertTime(AlertMilestone alert) {
    if (alert.unit == 'hours') {
      return effectiveDeadline.subtract(Duration(hours: alert.value));
    }
    // Với mốc theo ngày -> nhắc vào lúc 9:00 sáng của ngày đó
    final alertDay = effectiveExpiryDate.subtract(Duration(days: alert.value));
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

  // Nguồn kiểm tra trạng thái thống nhất cho toàn bộ ứng dụng
  bool get isExpired {
    if (isHourlyPao) return timeRemaining.isNegative;
    return daysRemaining < 0;
  }

  bool get isExpiringToday => !isExpired && daysRemaining == 0;

  bool isExpiringSoon({int withinDays = 7}) {
    if (isExpired) return false;
    return daysRemaining <= withinDays;
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

  // Mở gói dữ liệu an toàn: 1 dòng lỗi định dạng không làm văng toàn bộ danh sách
  factory HouseholdItem.fromMap(Map<String, dynamic> map) {
    final String rawAlerts = (map['alerts'] ?? '').toString().trim();
    List<AlertMilestone> parsedAlerts = [];
    if (rawAlerts.isNotEmpty) {
      try {
        parsedAlerts = (jsonDecode(rawAlerts) as List<dynamic>)
            .map((e) => AlertMilestone.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        parsedAlerts = [];
      }
    }

    return HouseholdItem(
      id: (map['id'] as num?)?.toInt(),
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? 'Other').toString(),
      expiryDate:
          DateTime.tryParse((map['expiryDate'] ?? '').toString()) ??
          DateTime.now(),
      openedDate: map['openedDate'] != null
          ? DateTime.tryParse(map['openedDate'].toString())
          : null,
      paoValue: (map['paoValue'] as num?)?.toInt(),
      paoUnit: (map['paoUnit'] ?? 'months').toString(),
      quantity: (map['quantity'] as num?)?.toInt(),
      imageBase64: map['imageBase64'] as String?,
      owner: map['owner'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      alerts: parsedAlerts,
    );
  }
}