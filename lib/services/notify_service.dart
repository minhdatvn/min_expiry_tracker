import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/item_model.dart';

class NotifyService {
  // Áp dụng mẫu Singleton: Cả ứng dụng chỉ dùng duy nhất 1 bộ quản lý thông báo
  static final NotifyService instance = NotifyService._init();
  NotifyService._init();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Định nghĩa "kênh thông báo" chuẩn của Android
  // (Người dùng có thể tự chỉnh âm thanh/rung riêng cho kênh này trong Cài đặt máy)
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'expiry_alerts_channel',        // Mã kênh duy nhất
    'Expiry Reminders',             // Tên kênh hiển thị trong Cài đặt Android
    channelDescription: 'Notifications before your household items expire',
    importance: Importance.high,    // Hiện banner nổi trên đầu màn hình
    priority: Priority.high,
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
  );

  // 1. KHỞI TẠO HỆ THỐNG THÔNG BÁO (Chạy 1 lần duy nhất trong main.dart khi mở app)
  Future<void> init() async {
    // Nạp dữ liệu múi giờ để hẹn lịch chính xác
    tz_data.initializeTimeZones();

    // Dùng icon mặc định của app Android làm biểu tượng nhỏ trên thanh trạng thái
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Tự động hiện hộp thoại xin quyền gửi thông báo trên Android 13 trở lên
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // 2. GỬI THỬ 1 THÔNG BÁO NGAY LẬP TỨC (Dùng cho nút chiếc chuông Test trên AppBar)
  Future<void> showTestNotification() async {
    await _plugin.show(
      0, // Mã ID 0 dành riêng cho thông báo test
      'MinExpiryTracker is ready!',
      'Offline expiry reminders are working properly on your phone.',
      _notificationDetails,
    );
  }

  // 3. HỦY TOÀN BỘ LỊCH NHẮC CŨ CỦA 1 VẬT PHẨM (Dùng khi Xóa hoặc trước khi Cập nhật)
  Future<void> cancelItemAlerts(int itemId) async {
    // Lấy danh sách tất cả lịch nhắc đang chờ trên máy
    final pending = await _plugin.pendingNotificationRequests();

    for (final request in pending) {
      // Phép chia lấy nguyên (~/ 100): VD 501 ~/ 100 == 5 -> đúng của vật phẩm số 5
      if (request.id ~/ 100 == itemId) {
        await _plugin.cancel(request.id);
      }
    }
  }

  // 4. LÊN LỊCH NHẮC NHỞ THEO ĐÚNG CÁC MỐC RIÊNG (alertDays) CỦA VẬT PHẨM
  Future<void> scheduleItemAlerts(HouseholdItem item, {int? overrideId}) async {
    final int? itemId = overrideId ?? item.id;
    if (itemId == null) return;

    // Bước A: Dọn sạch lịch nhắc cũ (nếu có) để tránh nhắc trùng khi người dùng sửa ngày
    await cancelItemAlerts(itemId);

    final now = DateTime.now();
    final expiry = item.effectiveExpiryDate;

    // Bước B: Duyệt qua từng mốc cảnh báo (VD: 30 ngày, 7 ngày, 1 ngày...)
    for (int i = 0; i < item.alertDays.length; i++) {
      final int daysBefore = item.alertDays[i];

      // Tính ra ngày cần nhắc: Lấy HSD thực tế trừ đi số ngày cảnh báo
      final alertDay = expiry.subtract(Duration(days: daysBefore));

      // Cố định giờ nhắc vào lúc 9:00 sáng của ngày đó theo giờ địa phương điện thoại
      final scheduledLocalTime = DateTime(
        alertDay.year,
        alertDay.month,
        alertDay.day,
        9, // 9 giờ sáng
        0, // 0 phút
      );

      // Nếu mốc nhắc này đã trôi qua trong quá khứ thì bỏ qua (Android cấm hẹn giờ quá khứ)
      if (!scheduledLocalTime.isAfter(now)) continue;

      // Chuyển đổi thời điểm hẹn sang định dạng TZDateTime chuẩn
      final tzScheduledDate = tz.TZDateTime.from(scheduledLocalTime, tz.local);

      // Tạo mã ID duy nhất cho từng mốc của vật phẩm (VD: món 5 -> 500, 501, 502...)
      final notificationId = itemId * 100 + i;

      // Nội dung thông báo tiếng Anh gọn gàng, rõ ràng
      final String bodyText = daysBefore == 1
          ? '${item.name} expires tomorrow!'
          : '${item.name} expires in $daysBefore days.';

      await _plugin.zonedSchedule(
        notificationId,
        'Expiry Alert: ${item.category}',
        bodyText,
        tzScheduledDate,
        _notificationDetails,
        // inexactAllowWhileIdle: Chạy bền bỉ kể cả khi khóa màn hình mà không cần quyền Exact Alarm
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // 5. HỦY TOÀN BỘ THÔNG BÁO ĐANG CHỜ TRÊN MÁY (Dùng trước khi khôi phục bản sao lưu)
  Future<void> cancelAllAlerts() async {
    await _plugin.cancelAll();
  }
}
