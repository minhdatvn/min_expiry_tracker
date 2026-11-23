import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';
import 'app_localizations.dart';

// 1. Dịch Danh mục (giữ nguyên tên tự nhập nếu có)
String localizeCategory(AppLocalizations l10n, String category) {
  switch (category) {
    case 'All':
      return l10n.all;
    case 'Medicine':
      return l10n.catMedicine;
    case 'Cosmetics':
      return l10n.catCosmetics;
    case 'Food':
      return l10n.catFood;
    case 'Other':
      return l10n.catOther;
    default:
      return category;
  }
}

// 2. Dịch Chủ sở hữu gợi ý mặc định ('Me', 'Family'); giữ nguyên tên tự thêm (VD: 'Mẹ', 'Bé')
String localizeOwner(AppLocalizations l10n, String owner) {
  switch (owner) {
    case 'All':
      return l10n.allOwners;
    case 'Me':
      return l10n.ownerMe;
    case 'Family':
      return l10n.ownerFamily;
    case 'Unassigned':
      return l10n.unassigned;
    default:
      return owner;
  }
}

// 3. Dịch Vị trí gợi ý mặc định ('Fridge', 'Medicine Box', 'Bathroom'); giữ nguyên vị trí tự thêm
String localizeLocation(AppLocalizations l10n, String location) {
  switch (location) {
    case 'All':
      return l10n.allLocations;
    case 'Fridge':
      return l10n.locFridge;
    case 'Medicine Box':
      return l10n.locMedicineBox;
    case 'Bathroom':
      return l10n.locBathroom;
    case 'No Location':
      return l10n.noLocation;
    default:
      return location;
  }
}

// 4. Dịch nhóm hành động trên màn hình Log (ADD, UPDATE, NOTIFY, CALENDAR...)
String localizeLogAction(AppLocalizations l10n, String action) {
  switch (action) {
    case 'All':
      return l10n.all;
    case 'ADD':
      return l10n.logActionAdd;
    case 'UPDATE':
      return l10n.logActionUpdate;
    case 'DELETE':
      return l10n.logActionDelete;
    case 'NOTIFY':
      return l10n.logActionNotify;
    case 'CALENDAR':
      return l10n.logActionCalendar;
    case 'BACKUP':
      return l10n.logActionBackup;
    case 'ERROR':
      return l10n.logActionError;
    default:
      return action;
  }
}

// 5. Đóng gói thông điệp Log thành chuỗi JSON có cấu trúc để dịch được sang mọi ngôn ngữ
String encodeLogMessage(String key, [Map<String, dynamic>? params]) {
  return jsonEncode({
    'key': key,
    if (params != null) ...params,
  });
}

// 6. Giải mã chuỗi Log từ SQLite và hiển thị đúng ngôn ngữ hiện tại
String localizeLogMessage(AppLocalizations l10n, String rawMessage) {
  if (!rawMessage.startsWith('{')) {
    if (rawMessage == 'Sent test notification.') {
      return l10n.logTestNotifySent;
    }
    final addedMatch =
        RegExp(r'^Added "(.+)" \((.+)\)\.$').firstMatch(rawMessage);
    if (addedMatch != null) {
      return l10n.logItemAdded(
        addedMatch.group(1)!,
        localizeCategory(l10n, addedMatch.group(2)!),
      );
    }
    final updatedMatch = RegExp(r'^Updated "(.+)"\.$').firstMatch(rawMessage);
    if (updatedMatch != null) {
      return l10n.logItemUpdated(updatedMatch.group(1)!);
    }
    final deletedMatch = RegExp(r'^Deleted "(.+)"\.$').firstMatch(rawMessage);
    if (deletedMatch != null) {
      return l10n.logItemDeleted(deletedMatch.group(1)!);
    }
    final notifyMatch =
        RegExp(r'^Scheduled (\d+) reminder\(s\) for "(.+)"\.$')
            .firstMatch(rawMessage);
    if (notifyMatch != null) {
      return l10n.logRemindersScheduled(
        int.parse(notifyMatch.group(1)!),
        notifyMatch.group(2)!,
      );
    }
    return rawMessage;
  }

  try {
    final Map<String, dynamic> data = jsonDecode(rawMessage);
    final String key = data['key'] ?? '';

    // Tạo nhãn mốc thời gian song ngữ nếu log có lưu alertValue & alertUnit
    String formatAlertParam() {
      final int val = data['alertValue'] ?? 1;
      final String unit = data['alertUnit'] ?? 'days';
      return unit == 'hours'
          ? l10n.hoursBeforeLabel(val)
          : l10n.daysBeforeLabel(val);
    }

    switch (key) {
      case 'logItemAdded':
        return l10n.logItemAdded(
          data['name'] ?? '',
          localizeCategory(l10n, data['category'] ?? ''),
        );
      case 'logItemUpdated':
        return l10n.logItemUpdated(data['name'] ?? '');
      case 'logItemDeleted':
        return l10n.logItemDeleted(data['name'] ?? '');
      case 'logTestNotifySent':
        return l10n.logTestNotifySent;
      case 'logRemindersScheduled':
        return l10n.logRemindersScheduled(
          data['count'] ?? 0,
          data['name'] ?? '',
        );
      case 'logCalendarDenied':
        return l10n.logCalendarDenied;
      case 'logCalendarNoAccount':
        return l10n.logCalendarNoAccount;
      case 'logCalendarNoWritable':
        return l10n.logCalendarNoWritable;
      case 'logCalendarSkippedPast':
        return l10n.logCalendarSkippedPast(
          formatAlertParam(),
          data['name'] ?? '',
        );
      case 'logCalendarAdded':
        return l10n.logCalendarAdded(
          data['name'] ?? '',
          formatAlertParam(),
        );
      case 'logCalendarFailed':
        return l10n.logCalendarFailed(data['name'] ?? '');
      case 'logCalendarRemoved':
        return l10n.logCalendarRemoved(
          data['count'] ?? 0,
          data['name'] ?? '',
        );
      case 'logBackupExported':
        return l10n.logBackupExported(
          data['count'] ?? 0,
          data['fileName'] ?? '',
        );
      case 'logRestoreInvalid':
        return l10n.logRestoreInvalid;
      case 'logBackupRestored':
        return l10n.logBackupRestored(data['count'] ?? 0);
      default:
        return rawMessage;
    }
  } catch (_) {
    return rawMessage;
  }
}

// 7. Chuyển mốc cảnh báo sang nhãn song ngữ
String localizeAlertLabel(AppLocalizations l10n, AlertMilestone alert) {
  if (alert.unit == 'hours') {
    return l10n.hoursBeforeLabel(alert.value);
  }
  return l10n.daysBeforeLabel(alert.value);
}

// 8. Định dạng ngày/giờ theo ngôn ngữ
String formatDateByLocale(
  BuildContext context,
  DateTime date, {
  bool includeTime = false,
}) {
  final isVi = Localizations.localeOf(context).languageCode == 'vi';
  if (isVi) {
    return includeTime
        ? DateFormat('dd/MM, HH:mm').format(date)
        : DateFormat('dd/MM/yyyy').format(date);
  }
  return includeTime
      ? DateFormat('MMM dd, HH:mm').format(date)
      : DateFormat('MMM dd, yyyy').format(date);
}