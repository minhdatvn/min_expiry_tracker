import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../l10n/l10n_helpers.dart'; // MỚI: Hỗ trợ đóng gói nội dung Log đa ngôn ngữ
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

  Future<void> showTestNotification() async {
    await _plugin.show(
      id: 0,
      title: 'MinExpiryTracker is ready!',
      body: 'Offline expiry reminders are working properly on your phone.',
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

  Future<void> scheduleItemAlerts(HouseholdItem item, {int? overrideId}) async {
    final int? itemId = overrideId ?? item.id;
    if (itemId == null) return;

    await cancelItemAlerts(itemId);

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
        encodeLogMessage('logRemindersScheduled', {
          'count': scheduledCount,
          'name': item.name,
        }),
      );
    }
  }

  Future<void> cancelAllAlerts() async {
    await _plugin.cancelAll();
  }
}