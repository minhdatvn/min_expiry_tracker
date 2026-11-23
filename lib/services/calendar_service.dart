import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/item_model.dart';
import 'log_service.dart';

class CalendarService {
  static final CalendarService instance = CalendarService._init();
  CalendarService._init();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  // Tìm ID của Lịch mặc định có quyền ghi trên điện thoại Android
  Future<String?> _getWritableCalendarId() async {
    var permissionResult = await _plugin.hasPermissions();
    if (permissionResult.isSuccess && permissionResult.data != true) {
      permissionResult = await _plugin.requestPermissions();
      if (!permissionResult.isSuccess || permissionResult.data != true) {
        await LogService.instance.addLog(
          'CALENDAR',
          'Calendar permission denied by user.',
        );
        return null;
      }
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    if (!calendarsResult.isSuccess || calendars == null || calendars.isEmpty) {
      await LogService.instance.addLog(
        'CALENDAR',
        'No calendar account found on this device.',
      );
      return null;
    }

    // Lọc các Lịch cho phép ghi (bỏ qua lịch ngày lễ chỉ đọc)
    final writable = calendars
        .where((c) => c.isReadOnly == false && c.id != null)
        .toList();

    if (writable.isEmpty) {
      await LogService.instance.addLog(
        'CALENDAR',
        'No writable calendar available (sign in to a Google account on device).',
      );
      return null;
    }

    // Ưu tiên chọn Lịch mặc định (isDefault == true), nếu không có lấy lịch đầu tiên
    final selected = writable.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => writable.first,
    );
    return selected.id;
  }

  // Đồng bộ tự động các mốc được tick "Thêm vào Lịch" của 1 vật phẩm
  // Trả về danh sách AlertMilestone đã gắn mã calendarEventId mới
  Future<List<AlertMilestone>> syncItemCalendarEvents(
    HouseholdItem item, {
    List<AlertMilestone>? previousAlerts,
  }) async {
    final hasOldEvents = previousAlerts != null &&
        previousAlerts.any((a) => a.calendarEventId != null);
    final hasNewRequests = item.alerts.any((a) => a.addToCalendar);

    // Nếu không có lịch cũ cần xóa và cũng không tick mốc mới nào -> thoát luôn (không hỏi quyền)
    if (!hasOldEvents && !hasNewRequests) {
      return item.alerts;
    }

    final calendarId = await _getWritableCalendarId();
    if (calendarId == null) {
      return item.alerts
          .map((a) => a.copyWith(clearCalendarEventId: true))
          .toList();
    }

    // Bước A: Xóa các sự kiện cũ trên Lịch (nếu người dùng đang sửa món đồ)
    if (previousAlerts != null) {
      for (final oldAlert in previousAlerts) {
        if (oldAlert.calendarEventId != null) {
          await _plugin.deleteEvent(calendarId, oldAlert.calendarEventId!);
        }
      }
    }

    // Bước B: Tạo sự kiện mới chỉ cho các mốc được đánh dấu tick
    final List<AlertMilestone> updatedAlerts = [];
    final now = DateTime.now();
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');

    for (final alert in item.alerts) {
      if (!alert.addToCalendar) {
        updatedAlerts.add(alert.copyWith(clearCalendarEventId: true));
        continue;
      }

      final alertTime = item.calculateAlertTime(alert);
      if (!alertTime.isAfter(now)) {
        await LogService.instance.addLog(
          'CALENDAR',
          'Skipped past calendar alert (${alert.label}) for "${item.name}".',
        );
        updatedAlerts.add(alert.copyWith(clearCalendarEventId: true));
        continue;
      }

      final tzStart = tz.TZDateTime.from(alertTime, tz.local);
      final tzEnd = tzStart.add(const Duration(minutes: 30));

      // Ghép mô tả chi tiết cho sự kiện Lịch
      final details = <String>[
        'Item: ${item.name} (${item.category})',
        'Expires: ${dateFmt.format(item.effectiveExpiryDate)}',
        'Reminder: ${alert.label}',
        if (item.owner != null && item.owner!.isNotEmpty) 'Owner: ${item.owner}',
        if (item.location != null && item.location!.isNotEmpty)
          'Location: ${item.location}',
        if (item.notes != null && item.notes!.isNotEmpty) 'Notes: ${item.notes}',
      ].join('\n');

      final event = Event(
        calendarId,
        title: '[MinExpiry] ${item.name} (${alert.label})',
        description: details,
        start: tzStart,
        end: tzEnd,
        reminders: [Reminder(minutes: 0)], // Báo chuông Lịch đúng giờ sự kiện
      );

      final result = await _plugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true && result?.data != null) {
        updatedAlerts.add(alert.copyWith(calendarEventId: result!.data));
        await LogService.instance.addLog(
          'CALENDAR',
          'Added calendar event for "${item.name}" (${alert.label}).',
        );
      } else {
        updatedAlerts.add(alert.copyWith(clearCalendarEventId: true));
        await LogService.instance.addLog(
          'ERROR',
          'Failed to add calendar event for "${item.name}".',
        );
      }
    }

    return updatedAlerts;
  }

  // Xóa toàn bộ sự kiện Lịch gắn với 1 vật phẩm (dùng khi xóa món đồ)
  Future<void> deleteItemCalendarEvents(HouseholdItem item) async {
    final eventIds = item.alerts
        .map((a) => a.calendarEventId)
        .whereType<String>()
        .toList();

    if (eventIds.isEmpty) return;

    final calendarId = await _getWritableCalendarId();
    if (calendarId == null) return;

    for (final eventId in eventIds) {
      await _plugin.deleteEvent(calendarId, eventId);
    }

    await LogService.instance.addLog(
      'CALENDAR',
      'Removed ${eventIds.length} calendar event(s) for "${item.name}".',
    );
  }
}