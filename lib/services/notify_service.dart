import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// MỚI: Dùng dữ liệu múi giờ 10 năm thay vì latest_all -> nhẹ dung lượng APK và tiết kiệm RAM khởi động
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import 'database_service.dart';
import 'locale_service.dart';
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

  Future<void> init() async {
    tz_data.initializeTimeZones();
    _configureLocalTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings: initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Tự động thiết lập tz.local khớp múi giờ thiết bị mà không cần thêm plugin native
  void _configureLocalTimeZone() {
    final now = DateTime.now();
    final locations = tz.timeZoneDatabase.locations;

    // 1. Khớp trực tiếp nếu hệ thống trả về tên chuẩn IANA (VD: Asia/Ho_Chi_Minh)
    final directMatch = locations[now.timeZoneName];
    if (directMatch != null) {
      tz.setLocalLocation(directMatch);
      return;
    }

    final targetOffsetMs = now.timeZoneOffset.inMilliseconds;

    // 2. Với múi giờ chẵn giờ (VD: UTC+7), ưu tiên chuẩn Etc/GMT để lịch hiển thị gọn GMT+07:00
    if (targetOffsetMs % Duration.millisecondsPerHour == 0) {
      final offsetHours = targetOffsetMs ~/ Duration.millisecondsPerHour;
      final etcName = offsetHours == 0
          ? 'UTC'
          : 'Etc/GMT${offsetHours > 0 ? '-$offsetHours' : '+${offsetHours.abs()}'}';
      final etcMatch = locations[etcName];
      if (etcMatch != null &&
          etcMatch.currentTimeZone.offset == targetOffsetMs) {
        tz.setLocalLocation(etcMatch);
        return;
      }
    }

    // 3. Dự phòng cho múi giờ lẻ (VD: UTC+5:30): tìm khu vực khớp độ lệch offset
    tz.Location? fallbackByOffset;
    for (final location in locations.values) {
      final currentTz = location.currentTimeZone;
      if (currentTz.offset == targetOffsetMs) {
        if (currentTz.abbreviation == now.timeZoneName) {
          tz.setLocalLocation(location);
          return;
        }
        fallbackByOffset ??= location;
      }
    }

    if (fallbackByOffset != null) {
      tz.setLocalLocation(fallbackByOffset);
    }
  }

  Future<void> showTestNotification() async {
    final l10n = LocaleService.instance.currentL10n;

    await _plugin.show(
      id: 0,
      title: l10n.testNotifyTitle,
      body: l10n.testNotifyBody,
      notificationDetails: _notificationDetails,
    );
    await LogService.instance.addLog(
      'NOTIFY',
      encodeLogMessage('logTestNotifySent'),
    );
  }

  Future<void> cancelItemAlerts(int itemId) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id ~/ 100 == itemId) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  Future<void> scheduleItemAlerts(
    HouseholdItem item, {
    int? overrideId,
    bool cancelExisting = true,
    bool logAction = true,
  }) async {
    final int? itemId = overrideId ?? item.id;
    if (itemId == null) return;

    // Khi vừa chạy cancelAllAlerts() trước đó -> truyền cancelExisting: false để đỡ truy vấn lặp
    if (cancelExisting) {
      await cancelItemAlerts(itemId);
    }

    final l10n = LocaleService.instance.currentL10n;
    final categoryLabel = localizeCategory(l10n, item.category);
    final now = DateTime.now();
    int scheduledCount = 0;

    for (int i = 0; i < item.alerts.length; i++) {
      final alert = item.alerts[i];
      final scheduledLocalTime = item.calculateAlertTime(alert);

      if (!scheduledLocalTime.isAfter(now)) continue;

      final tzScheduledDate = tz.TZDateTime.from(scheduledLocalTime, tz.local);
      final notificationId = itemId * 100 + i;

      final String bodyText;
      if (alert.unit == 'hours') {
        bodyText = alert.value == 1
            ? l10n.expiresInOneHour(item.name)
            : l10n.expiresInHours(item.name, alert.value);
      } else {
        bodyText = alert.value == 1
            ? l10n.expiresTomorrow(item.name)
            : l10n.expiresInDays(item.name, alert.value);
      }

      await _plugin.zonedSchedule(
        id: notificationId,
        title: l10n.expiryAlertTitle(categoryLabel),
        body: bodyText,
        scheduledDate: tzScheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      scheduledCount++;
    }

    if (scheduledCount > 0 && logAction) {
      await LogService.instance.addLog(
        'NOTIFY',
        encodeLogMessage('logRemindersScheduled', {
          'count': scheduledCount,
          'name': item.name,
        }),
      );
    }
  }

  // MỚI: Tự đặt lại toàn bộ thông báo đang chờ sang ngôn ngữ hiện tại (dùng khi đổi ngôn ngữ)
  Future<void> rescheduleAllAlerts() async {
    try {
      final items = await DatabaseService.instance.getAllItems();
      await cancelAllAlerts();
      for (final item in items) {
        await scheduleItemAlerts(
          item,
          cancelExisting: false,
          logAction: false,
        );
      }
    } catch (_) {
      // Giữ thao tác đổi ngôn ngữ luôn mượt, không bị gián đoạn nếu có lỗi phụ
    }
  }

  Future<void> cancelAllAlerts() async {
    await _plugin.cancelAll();
  }
}