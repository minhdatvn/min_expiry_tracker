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
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    // Bản v20+ bắt buộc ghi rõ tên tham số "settings:"
    await _plugin.initialize(settings: initSettings);

    // Tự động hiện hộp thoại xin quyền gửi thông báo trên Android 13 trở lên
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // 2. GỬI THỬ 1 THÔNG BÁO NGAY LẬP TỨC (Dùng cho nút chiếc chuông Test trên AppBar)
  Future<void> showTestNotification() async {
    await _plugin.show(
      id: 0,
      title: 'MinExpiryTracker is ready!',
      body: 'Offline expiry reminders are working properly on your phone.',
      notificationDetails: _notificationDetails,
    );
  }

  // 3. HỦY TOÀN BỘ LỊCH NHẮC CŨ CỦA 1 VẬT PHẨM (Dùng khi Xóa hoặc trước khi Cập nhật)
  Future<void> cancelItemAlerts(int itemId) async {
    final pending = await _plugin.pendingNotificationRequests();

    for (final request in pending) {
      if (request.id ~/ 100 == itemId) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  // 4. LÊN LỊCH NHẮC NHỞ THEO ĐÚNG CÁC MỐC RIÊNG (alertDays) CỦA VẬT PHẨM
  Future<void> scheduleItemAlerts(HouseholdItem item, {int? overrideId}) async {
    final int? itemId = overrideId ?? item.id;
    if (itemId == null) return;

    await cancelItemAlerts(itemId);

    final now = DateTime.now();
    final expiry = item.effectiveExpiryDate;

    for (int i = 0; i < item.alertDays.length; i++) {
      final int daysBefore = item.alertDays[i];
      final alertDay = expiry.subtract(Duration(days: daysBefore));

      final scheduledLocalTime = DateTime(
        alertDay.year,
        alertDay.month,
        alertDay.day,
        9, // 9 giờ sáng
        0, // 0 phút
      );

      if (!scheduledLocalTime.isAfter(now)) continue;

      final tzScheduledDate = tz.TZDateTime.from(scheduledLocalTime, tz.local);
      final notificationId = itemId * 100 + i;

      final String bodyText = daysBefore == 1
          ? '${item.name} expires tomorrow!'
          : '${item.name} expires in $daysBefore days.';

      await _plugin.zonedSchedule(
        id: notificationId,
        title: 'Expiry Alert: ${item.category}',
        body: bodyText,
        scheduledDate: tzScheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  // 5. HỦY TOÀN BỘ THÔNG BÁO ĐANG CHỜ TRÊN MÁY (Dùng trước khi khôi phục bản sao lưu)
  Future<void> cancelAllAlerts() async {
    await _plugin.cancelAll();
  }
}