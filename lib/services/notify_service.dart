import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/item_model.dart';
import 'log_service.dart';

class NotifyService {
  static final NotifyService instance = NotifyService._init();
  NotifyService._init();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'expiry_alerts_channel',
    'Expiry Reminders',
    channelDescription: 'Notifications before your household items expire',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
  );

  // 1. Khởi tạo hệ thống thông báo (chạy 1 lần trong main.dart)
  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings: initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // 2. Gửi thử 1 thông báo ngay lập tức (có thể gọi từ màn hình Log/Settings)
  Future<void> showTestNotification() async {
    await _plugin.show(
      id: 0,
      title: 'MinExpiryTracker is ready!',
      body: 'Offline expiry reminders are working properly on your phone.',
      notificationDetails: _notificationDetails,
    );
    await LogService.instance.addLog(
      'NOTIFY',
      'Sent test notification.',
    );
  }

  // 3. Hủy toàn bộ lịch nhắc cũ của 1 vật phẩm
  Future<void> cancelItemAlerts(int itemId) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id ~/ 100 == itemId) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  // 4. NÂNG CẤP: Lên lịch nhắc nhở theo danh sách AlertMilestone (hỗ trợ cả Giờ & Ngày)
  Future<void> scheduleItemAlerts(HouseholdItem item, {int? overrideId}) async {
    final int? itemId = overrideId ?? item.id;
    if (itemId == null) return;

    await cancelItemAlerts(itemId);

    final now = DateTime.now();
    int scheduledCount = 0;

    for (int i = 0; i < item.alerts.length; i++) {
      final alert = item.alerts[i];
      // Dùng công thức tính thời điểm dùng chung từ item_model.dart
      final scheduledLocalTime = item.calculateAlertTime(alert);

      // Bỏ qua các mốc đã trôi qua trong quá khứ
      if (!scheduledLocalTime.isAfter(now)) continue;

      final tzScheduledDate = tz.TZDateTime.from(scheduledLocalTime, tz.local);
      final notificationId = itemId * 100 + i;

      // Tạo câu thông báo tự nhiên tùy theo đơn vị Giờ hay Ngày
      final String bodyText;
      if (alert.unit == 'hours') {
        bodyText = alert.value == 1
            ? '${item.name} expires in 1 hour!'
            : '${item.name} expires in ${alert.value} hours!';
      } else {
        bodyText = alert.value == 1
            ? '${item.name} expires tomorrow!'
            : '${item.name} expires in ${alert.value} days.';
      }

      await _plugin.zonedSchedule(
        id: notificationId,
        title: 'Expiry Alert: ${item.category}',
        body: bodyText,
        scheduledDate: tzScheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      scheduledCount++;
    }

    if (scheduledCount > 0) {
      await LogService.instance.addLog(
        'NOTIFY',
        'Scheduled $scheduledCount reminder(s) for "${item.name}".',
      );
    }
  }

  // 5. Hủy toàn bộ thông báo đang chờ (dùng trước khi Restore)
  Future<void> cancelAllAlerts() async {
    await _plugin.cancelAll();
  }
}