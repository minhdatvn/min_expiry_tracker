import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../l10n/l10n_helpers.dart'; // MỚI: Hỗ trợ đóng gói Log đa ngôn ngữ
import '../models/item_model.dart';
import 'log_service.dart';

class CalendarService {
  static final CalendarService instance = CalendarService._init();
  CalendarService._init();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  Future<String?> _getWritableCalendarId() async {
    var permissionResult = await _plugin.hasPermissions();
    if (permissionResult.isSuccess && permissionResult.data != true) {
      permissionResult = await _plugin.requestPermissions();
      if (!permissionResult.isSuccess || permissionResult.data != true) {
        await LogService.instance.addLog(
          'CALENDAR',
          encodeLogMessage('logCalendarDenied'),
        );
        return null;
      }
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    if (!calendarsResult.isSuccess || calendars == null || calendars.isEmpty) {
      await LogService.instance.addLog(
        'CALENDAR',
        encodeLogMessage('logCalendarNoAccount'),
      );
      return null;
    }

    final writable = calendars
        .where((c) => c.isReadOnly == false && c.id != null)
        .toList();

    if (writable.isEmpty) {
      await LogService.instance.addLog(
        'CALENDAR',
        encodeLogMessage('logCalendarNoWritable'),
      );
      return null;
    }

    final selected = writable.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => writable.first,
    );
    return selected.id;
  }

  Future<List<AlertMilestone>> syncItemCalendarEvents(
    HouseholdItem item, {
    List<AlertMilestone>? previousAlerts,
  }) async {
    final hasOldEvents = previousAlerts != null &&
        previousAlerts.any((a) => a.calendarEventId != null);
    final hasNewRequests = item.alerts.any((a) => a.addToCalendar);

    if (!hasOldEvents && !hasNewRequests) {
      return item.alerts;
    }

    final calendarId = await _getWritableCalendarId();
    if (calendarId == null) {
      return item.alerts
          .map((a) => a.copyWith(clearCalendarEventId: true))
          .toList();
    }

    if (previousAlerts != null) {
      for (final oldAlert in previousAlerts) {
        if (oldAlert.calendarEventId != null) {
          await _plugin.deleteEvent(calendarId, oldAlert.calendarEventId!);
        }
      }
    }

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
          encodeLogMessage('logCalendarSkippedPast', {
            'alertValue': alert.value,
            'alertUnit': alert.unit,
            'name': item.name,
          }),
        );
        updatedAlerts.add(alert.copyWith(clearCalendarEventId: true));
        continue;
      }

      final tzStart = tz.TZDateTime.from(alertTime, tz.local);
      final tzEnd = tzStart.add(const Duration(minutes: 30));

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
        reminders: [Reminder(minutes: 0)],
      );

      final result = await _plugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true && result?.data != null) {
        updatedAlerts.add(alert.copyWith(calendarEventId: result!.data));
        await LogService.instance.addLog(
          'CALENDAR',
          encodeLogMessage('logCalendarAdded', {
            'alertValue': alert.value,
            'alertUnit': alert.unit,
            'name': item.name,
          }),
        );
      } else {
        updatedAlerts.add(alert.copyWith(clearCalendarEventId: true));
        await LogService.instance.addLog(
          'ERROR',
          encodeLogMessage('logCalendarFailed', {'name': item.name}),
        );
      }
    }

    return updatedAlerts;
  }

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
      encodeLogMessage('logCalendarRemoved', {
        'count': eventIds.length,
        'name': item.name,
      }),
    );
  }
}