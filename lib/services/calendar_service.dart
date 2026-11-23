import 'locale_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import 'log_service.dart';

// Gói kết quả đồng bộ Lịch để báo ngược trạng thái lỗi ra màn hình chính
class CalendarSyncResult {
  final List<AlertMilestone> alerts;
  final String? errorKey; // null nếu thành công hoặc chỉ đang bỏ tick Lịch

  const CalendarSyncResult({
    required this.alerts,
    this.errorKey,
  });

  bool get hasError => errorKey != null;
}

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
        type.contains('osp') ||
        type.contains('sec') ||
        type.contains('phone') ||
        accName.contains('local') ||
        accName.contains('phone') ||
        accName.contains('samsung') ||
        calName.contains('my calendar') ||
        calName.contains('lịch của tôi') ||
        calName.contains('samsung');
  }

  Calendar _pickDefaultOrFirst(List<Calendar> list) {
    return list.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => list.first,
    );
  }

  // Chọn sổ Lịch ưu tiên: Lịch máy/Samsung -> Google Calendar -> Lịch khả dụng khác
  Calendar _pickPreferredCalendar(List<Calendar> writable) {
    final deviceCalendars = writable.where(_isDeviceOrSamsungCalendar).toList();
    if (deviceCalendars.isNotEmpty) {
      return _pickDefaultOrFirst(deviceCalendars);
    }

    final defaultNonGoogle = writable
        .where((c) => c.isDefault == true && !_isGoogleCalendar(c))
        .toList();
    if (defaultNonGoogle.isNotEmpty) {
      return defaultNonGoogle.first;
    }

    final googleCalendars = writable.where(_isGoogleCalendar).toList();
    if (googleCalendars.isNotEmpty) {
      return _pickDefaultOrFirst(googleCalendars);
    }

    return _pickDefaultOrFirst(writable);
  }

  Future<String?> _createLocalFallbackCalendar() async {
    try {
      final result = await _plugin.createCalendar(
        'MinExpiryTracker',
        localAccountName: 'MinExpiryTracker',
      );
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        return result.data;
      }
    } catch (_) {}
    return null;
  }

  // Tìm ID của Lịch khả dụng (thêm cờ logFailure để không ghi log lỗi khi chỉ đang dọn sự kiện cũ)
  Future<_CalendarLookupResult> _getWritableCalendarId({
    bool allowCreateFallback = true,
    bool logFailure = true,
  }) async {
    try {
      var permissionResult = await _plugin.hasPermissions();
      if (permissionResult.isSuccess && permissionResult.data != true) {
        // Nếu không phải thao tác tạo mới (logFailure == false) thì không bật hộp thoại xin quyền
        if (!logFailure) {
          return const _CalendarLookupResult();
        }
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
    } catch (_) {}

    if (logFailure) {
      await LogService.instance.addLog(
        'CALENDAR',
        encodeLogMessage('logCalendarNoWritable'),
      );
      return const _CalendarLookupResult(errorKey: 'logCalendarNoWritable');
    }
    return const _CalendarLookupResult();
  }

  // Hàm dọn sự kiện cũ an toàn tuyệt đối (không bao giờ ném lỗi ra giao diện)
  Future<int> _deleteSavedEvents(
    List<AlertMilestone> alerts, {
    String? fallbackCalendarId,
  }) async {
    final alertsWithIds = alerts
        .where((a) => a.calendarEventId != null && a.calendarEventId!.isNotEmpty)
        .toList();
    if (alertsWithIds.isEmpty) return 0;

    try {
      final perm = await _plugin.hasPermissions();
      if (!perm.isSuccess || perm.data != true) return 0;
    } catch (_) {
      return 0;
    }

    String? sharedFallbackId = fallbackCalendarId;
    int removedCount = 0;

    for (final alert in alertsWithIds) {
      String? targetCalId = alert.calendarId;
      if (targetCalId == null || targetCalId.isEmpty) {
        sharedFallbackId ??= (await _getWritableCalendarId(
          allowCreateFallback: false,
          logFailure: false,
        ))
            .calendarId;
        targetCalId = sharedFallbackId;
      }

      if (targetCalId == null || targetCalId.isEmpty) continue;

      try {
        final res = await _plugin.deleteEvent(
          targetCalId,
          alert.calendarEventId!,
        );
        if (res.isSuccess || res.data == true) {
          removedCount++;
        }
      } catch (_) {
        // Bỏ qua êm ái nếu sự kiện đã bị người dùng xóa thủ công trên app Lịch
      }
    }

    return removedCount;
  }

  // Đồng bộ tự động các mốc được tick "Thêm vào Lịch" của 1 vật phẩm
  Future<CalendarSyncResult> syncItemCalendarEvents(
    HouseholdItem item, {
    List<AlertMilestone>? previousAlerts,
  }) async {
    final hasOldEvents = previousAlerts != null &&
        previousAlerts.any(
          (a) => a.calendarEventId != null && a.calendarEventId!.isNotEmpty,
        );
    final hasNewRequests = item.alerts.any((a) => a.addToCalendar);

    // Trường hợp 1: Không có lịch cũ và cũng không tick mới -> thoát êm
    if (!hasOldEvents && !hasNewRequests) {
      return CalendarSyncResult(alerts: item.alerts);
    }

    // Trường hợp 2 (ĐÃ SỬA LOGIC): Người dùng BỎ DẤU TICK tất cả mốc Lịch
    // -> Cố gắng dọn sự kiện cũ trong âm thầm, TUYỆT ĐỐI không báo lỗi lên màn hình
    if (!hasNewRequests) {
      if (previousAlerts != null) {
        final removedCount = await _deleteSavedEvents(previousAlerts);
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

      return CalendarSyncResult(
        alerts: item.alerts
            .map((a) => a.copyWith(clearCalendarEventId: true))
            .toList(),
        errorKey: null,
      );
    }

    // Trường hợp 3: Người dùng CÓ tick ít nhất 1 mốc muốn ghi lên Lịch
    final lookup = await _getWritableCalendarId(
      allowCreateFallback: true,
      logFailure: true,
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

    // Xóa các sự kiện cũ của lần lưu trước (nếu có) trước khi tạo bộ sự kiện mới
    if (previousAlerts != null) {
      await _deleteSavedEvents(previousAlerts, fallbackCalendarId: calendarId);
    }

    final List<AlertMilestone> updatedAlerts = [];
    final now = DateTime.now();
    // Lấy từ điển & định dạng ngày theo ngôn ngữ hiện tại (VN: dd/MM/yyyy, EN: MMM dd, yyyy)
    final l10n = LocaleService.instance.currentL10n;
    final isVi = LocaleService.instance.effectiveLocale.languageCode == 'vi';
    final dateFmt = DateFormat(isVi ? 'dd/MM/yyyy HH:mm' : 'MMM dd, yyyy HH:mm');
    final categoryLabel = localizeCategory(l10n, item.category);
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
      final alertLabel = localizeAlertLabel(l10n, alert);

      final details = <String>[
        l10n.calItemLine(item.name, categoryLabel),
        l10n.calExpiresLine(dateFmt.format(item.effectiveExpiryDate)),
        l10n.calReminderLine(alertLabel),
        if (item.owner != null && item.owner!.isNotEmpty)
          l10n.calOwnerLine(localizeOwner(l10n, item.owner!)),
        if (item.location != null && item.location!.isNotEmpty)
          l10n.calLocationLine(localizeLocation(l10n, item.location!)),
        if (item.notes != null && item.notes!.isNotEmpty)
          l10n.calNotesLine(item.notes!),
      ].join('\n');

      final event = Event(
        calendarId,
        title: '[MinExpiry] ${item.name} ($alertLabel)',
        description: details,
        start: tzStart,
        end: tzEnd,
        reminders: [Reminder(minutes: 0)],
      );

      try {
        final result = await _plugin.createOrUpdateEvent(event);

        // ĐÃ SỬA: Coi là thành công nếu plugin báo isSuccess HOẶC đã trả về mã sự kiện hợp lệ
        final String? createdEventId =
            (result?.data != null && result!.data!.trim().isNotEmpty)
                ? result.data!.trim()
                : null;
        final bool isCreated =
            (result?.isSuccess == true) || createdEventId != null;

        if (isCreated) {
          updatedAlerts.add(
            alert.copyWith(
              calendarEventId: createdEventId,
              calendarId: createdEventId != null ? calendarId : null,
            ),
          );
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
    final removedCount = await _deleteSavedEvents(item.alerts);
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