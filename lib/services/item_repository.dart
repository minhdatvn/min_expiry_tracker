import '../l10n/l10n_helpers.dart';
import '../models/item_model.dart';
import 'calendar_service.dart';
import 'database_service.dart';
import 'log_service.dart';
import 'notify_service.dart';

class ItemOperationResult {
  final HouseholdItem item;
  final String? calendarErrorKey;

  const ItemOperationResult({
    required this.item,
    this.calendarErrorKey,
  });

  bool get hasCalendarError => calendarErrorKey != null;
}

class ItemRepository {
  static final ItemRepository instance = ItemRepository._init();
  ItemRepository._init();

  final DatabaseService _db = DatabaseService.instance;
  final CalendarService _calendar = CalendarService.instance;
  final NotifyService _notify = NotifyService.instance;
  final LogService _log = LogService.instance;

  // Lấy toàn bộ danh sách vật phẩm
  Future<List<HouseholdItem>> getAllItems() {
    return _db.getAllItems();
  }

  // Lấy đồng thời gợi ý Chủ sở hữu và Vị trí đã từng lưu
  Future<({List<String> owners, List<String> locations})> getSavedTags() async {
    final results = await Future.wait([
      _db.getDistinctOwners(),
      _db.getDistinctLocations(),
    ]);
    return (owners: results[0], locations: results[1]);
  }

  // Luồng thêm mới trọn gói: DB -> Lịch -> Thông báo -> Log
  Future<ItemOperationResult> addItem(HouseholdItem item) async {
    final newId = await _db.insertItem(item);
    var savedItem = item.copyWith(id: newId);

    String? calendarErrorKey;
    if (savedItem.alerts.any((a) => a.addToCalendar)) {
      final syncResult = await _calendar.syncItemCalendarEvents(savedItem);
      savedItem = savedItem.copyWith(alerts: syncResult.alerts);
      await _db.updateItem(savedItem);
      calendarErrorKey = syncResult.errorKey;
    }

    await _notify.scheduleItemAlerts(savedItem);
    await _log.addLog(
      'ADD',
      encodeLogMessage('logItemAdded', {
        'name': savedItem.name,
        'category': savedItem.category,
      }),
    );

    return ItemOperationResult(
      item: savedItem,
      calendarErrorKey: calendarErrorKey,
    );
  }

  // Luồng cập nhật trọn gói: (Lịch ->) DB -> (Thông báo ->) Log
  // Đặt syncSchedule: false cho các thao tác nhanh không đổi hạn sử dụng (VD: chỉnh số lượng)
  Future<ItemOperationResult> updateItem(
    HouseholdItem updated, {
    required HouseholdItem previous,
    bool syncSchedule = true,
  }) async {
    var finalItem = updated;
    String? calendarErrorKey;

    if (syncSchedule) {
      final syncResult = await _calendar.syncItemCalendarEvents(
        updated,
        previousAlerts: previous.alerts,
      );
      finalItem = updated.copyWith(alerts: syncResult.alerts);
      calendarErrorKey = syncResult.errorKey;
    }

    await _db.updateItem(finalItem);

    if (syncSchedule) {
      await _notify.scheduleItemAlerts(finalItem);
    }

    await _log.addLog(
      'UPDATE',
      encodeLogMessage('logItemUpdated', {'name': finalItem.name}),
    );

    return ItemOperationResult(
      item: finalItem,
      calendarErrorKey: calendarErrorKey,
    );
  }

  // Luồng xóa trọn gói: DB -> Hủy thông báo -> Xóa sự kiện Lịch -> Log
  Future<void> deleteItem(HouseholdItem item) async {
    final itemId = item.id;
    if (itemId == null) return;

    await _db.deleteItem(itemId);
    await _notify.cancelItemAlerts(itemId);
    await _calendar.deleteItemCalendarEvents(item);
    await _log.addLog(
      'DELETE',
      encodeLogMessage('logItemDeleted', {'name': item.name}),
    );
  }
}