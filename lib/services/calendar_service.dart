import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import 'log_service.dart';

// MỚI: Gói kết quả đồng bộ Lịch để báo ngược trạng thái lỗi ra màn hình chính
class CalendarSyncResult {
  final List<AlertMilestone> alerts;
  final String? errorKey; // null nếu thành công hoặc không yêu cầu đồng bộ Lịch

  const CalendarSyncResult({
    required this.alerts,
    this.errorKey,
  });

  bool get hasError => errorKey != null;
}

// Lớp nội bộ chứa kết quả tìm kiếm sổ Lịch khả dụng
class _CalendarLookupResult {
  final String? calendarId;
  final String? errorKey;

  const _CalendarLookupResult({this.calendarId, this.errorKey});
}

class CalendarService {
  static final CalendarService instance = CalendarService._init();
  CalendarService._init();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  // Nhận diện sổ Lịch thuộc Google Calendar
  bool _isGoogleCalendar(Calendar c) {
    final type = (c.accountType ?? '').toLowerCase();
    final accName = (c.accountName ?? '').toLowerCase();
    return type.contains('google') || accName.contains('@gmail.com');
  }

  // Nhận diện Lịch mặc định của Samsung hoặc Lịch cục bộ trên điện thoại
  bool _isDeviceOrSamsungCalendar(Calendar c) {
    final type = (c.accountType ?? '').toLowerCase();
    final accName = (c.accountName ?? '').toLowerCase();
    final calName = (c.name ?? '').toLowerCase();

    return type.contains('local') ||
        type.contains('samsung') ||
        type.contains('osp') || // Tài khoản Samsung (com.osp.app.signin)
        type.contains('sec') || // Lịch nội bộ Samsung (vnd.sec.contact.phone)
        type.contains('phone') ||
        accName.contains('local') ||
        accName.contains('phone') ||
        accName.contains('samsung') ||
        calName.contains('my calendar') ||
        calName.contains('lịch của tôi') ||
        calName.contains('samsung');
  }

  // Chọn 1 sổ Lịch tốt nhất trong nhóm (ưu tiên sổ được đánh dấu isDefault == true)
  Calendar _pickDefaultOrFirst(List<Calendar> list) {
    return list.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => list.first,
    );
  }

  // Chọn sổ Lịch theo thứ tự ưu tiên:
  // 1. Lịch mặc định / Samsung / Lịch cục bộ -> 2. Google Calendar -> 3. Lịch khả dụng khác
  Calendar _pickPreferredCalendar(List<Calendar> writable) {
    // Ưu tiên 1A: Lịch Samsung / Lịch cục bộ của máy
    final deviceCalendars = writable.where(_isDeviceOrSamsungCalendar).toList();
    if (deviceCalendars.isNotEmpty) {
      return _pickDefaultOrFirst(deviceCalendars);
    }

    // Ưu tiên 1B: Lịch mặc định của hãng điện thoại khác (không phải Google)
    final defaultNonGoogle = writable
        .where((c) => c.isDefault == true && !_isGoogleCalendar(c))
        .toList();
    if (defaultNonGoogle.isNotEmpty) {
      return defaultNonGoogle.first;
    }

    // Ưu tiên 2: Google Calendar
    final googleCalendars = writable.where(_isGoogleCalendar).toList();
    if (googleCalendars.isNotEmpty) {
      return _pickDefaultOrFirst(googleCalendars);
    }

    // Ưu tiên 3: Bất kỳ Lịch nào khác có quyền ghi (Outlook, Exchange...)
    return _pickDefaultOrFirst(writable);
  }

  // Dự phòng: Tự tạo 1 sổ Lịch cục bộ nếu máy Samsung chưa khởi tạo sẵn sổ lịch nào
  Future<String?> _createLocalFallbackCalendar() async {
    try {
      final result = await _plugin.createCalendar(
        'MinExpiryTracker',
        localAccountName: 'MinExpiryTracker',
      );
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        return result.data;
      }
    } catch (_) {
      // Một số máy Android hạn chế tạo sổ lịch cục bộ -> bỏ qua để báo lỗi chuẩn
    }
    return null;
  }

  // Tìm ID của Lịch khả dụng kèm mã lỗi cụ thể nếu thất bại
  Future<_CalendarLookupResult> _getWritableCalendarId({
    bool allowCreateFallback = true,
  }) async {
    try {
      var permissionResult = await _plugin.hasPermissions();
      if (permissionResult.isSuccess && permissionResult.data != true) {
        permissionResult = await _plugin.requestPermissions();
        if (!permissionResult.isSuccess || permissionResult.data != true) {
          await LogService.instance.addLog(
            'CALENDAR',
            encodeLogMessage('logCalendarDenied'),
          );
          return const _CalendarLookupResult(errorKey: 'logCalendarDenied');
        }
      }

      final calendarsResult = await _plugin.retrieveCalendars();
      final List<Calendar> calendars = calendarsResult.data ?? <Calendar>[];

      final writable = calendars
          .where((c) => c.id != null && c.id!.isNotEmpty && c.isReadOnly != true)
          .toList();

      if (writable.isNotEmpty) {
        final selected = _pickPreferredCalendar(writable);
        return _CalendarLookupResult(calendarId: selected.id);
      }

      if (allowCreateFallback) {
        final localId = await _createLocalFallbackCalendar();
        if (localId != null) {
          return _CalendarLookupResult(calendarId: localId);
        }
      }
    } catch (_) {
      // Nếu hệ thống Lịch Android trả về lỗi ngoài dự kiến -> chuyển về báo lỗi chuẩn
    }

    await LogService.instance.addLog(
      'CALENDAR',
      encodeLogMessage('logCalendarNoWritable'),
    );
    return const _CalendarLookupResult(errorKey: 'logCalendarNoWritable');
  }

  // Đồng bộ tự động các mốc được tick "Thêm vào Lịch" của 1 vật phẩm
  Future<CalendarSyncResult> syncItemCalendarEvents(
    HouseholdItem item, {
    List<AlertMilestone>? previousAlerts,
  }) async {
    final hasOldEvents = previousAlerts != null &&
        previousAlerts.any((a) => a.calendarEventId != null);
    final hasNewRequests = item.alerts.any((a) => a.addToCalendar);

    // Nếu không có lịch cũ cần xóa và cũng không tick mốc mới nào -> thoát êm
    if (!hasOldEvents && !hasNewRequests) {
      return CalendarSyncResult(alerts: item.alerts);
    }

    final lookup = await _getWritableCalendarId(
      allowCreateFallback: hasNewRequests,
    );

    if (lookup.calendarId == null) {
      return CalendarSyncResult(
        alerts: item.alerts
            .map((a) => a.copyWith(clearCalendarEventId: true))
            .toList(),
        errorKey: lookup.errorKey ?? 'logCalendarNoWritable',
      );
    }

    final calendarId = lookup.calendarId!;

    // Bước A: Xóa các sự kiện cũ (bỏ qua êm nếu người dùng đã tự xóa sự kiện trên Lịch trước đó)
    if (previousAlerts != null) {
      for (final oldAlert in previousAlerts) {
        if (oldAlert.calendarEventId != null) {
          try {
            await _plugin.deleteEvent(calendarId, oldAlert.calendarEventId!);
          } catch (_) {}
        }
      }
    }

    // Bước B: Tạo sự kiện mới cho các mốc được đánh dấu tick
    final List<AlertMilestone> updatedAlerts = [];
    final now = DateTime.now();
    final dateFmt = DateFormat('MMM dd, yyyy HH:mm');
    String? eventErrorKey;

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

      try {
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
          eventErrorKey = 'logCalendarFailed';
          updatedAlerts.add(alert.copyWith(clearCalendarEventId: true));
          await LogService.instance.addLog(
            'ERROR',
            encodeLogMessage('logCalendarFailed', {'name': item.name}),
          );
        }
      } catch (_) {
        eventErrorKey = 'logCalendarFailed';
        updatedAlerts.add(alert.copyWith(clearCalendarEventId: true));
        await LogService.instance.addLog(
          'ERROR',
          encodeLogMessage('logCalendarFailed', {'name': item.name}),
        );
      }
    }

    return CalendarSyncResult(
      alerts: updatedAlerts,
      errorKey: eventErrorKey,
    );
  }

  // Xóa toàn bộ sự kiện Lịch gắn với 1 vật phẩm (dùng khi xóa món đồ)
  Future<void> deleteItemCalendarEvents(HouseholdItem item) async {
    final eventIds = item.alerts
        .map((a) => a.calendarEventId)
        .whereType<String>()
        .toList();

    if (eventIds.isEmpty) return;

    final lookup = await _getWritableCalendarId(allowCreateFallback: false);
    if (lookup.calendarId == null) return;

    int removedCount = 0;
    for (final eventId in eventIds) {
      try {
        await _plugin.deleteEvent(lookup.calendarId!, eventId);
        removedCount++;
      } catch (_) {}
    }

    if (removedCount > 0) {
      await LogService.instance.addLog(
        'CALENDAR',
        encodeLogMessage('logCalendarRemoved', {
          'count': removedCount,
          'name': item.name,
        }),
      );
    }
  }
}