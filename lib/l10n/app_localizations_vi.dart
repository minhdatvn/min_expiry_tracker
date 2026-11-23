// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'MinExpiryTracker';

  @override
  String get searchHint => 'Tìm theo tên, ghi chú, vị trí...';

  @override
  String get clearSearch => 'Xóa tìm kiếm';

  @override
  String get ownerStatistics => 'Thống kê chủ sở hữu';

  @override
  String get appLogs => 'Nhật ký hoạt động';

  @override
  String get settings => 'Cài đặt';

  @override
  String get all => 'Tất cả';

  @override
  String get allOwners => 'Mọi chủ sở hữu';

  @override
  String get allLocations => 'Mọi vị trí';

  @override
  String get unassigned => 'Chưa phân loại';

  @override
  String get noLocation => 'Chưa có vị trí';

  @override
  String get catMedicine => 'Thuốc';

  @override
  String get catCosmetics => 'Mỹ phẩm';

  @override
  String get catFood => 'Thực phẩm';

  @override
  String get catOther => 'Khác';

  @override
  String get ownerMe => 'Tôi';

  @override
  String get ownerFamily => 'Gia đình';

  @override
  String get locFridge => 'Tủ lạnh';

  @override
  String get locMedicineBox => 'Tủ thuốc';

  @override
  String get locBathroom => 'Phòng tắm';

  @override
  String get noItemsYet =>
      'Chưa có vật phẩm nào.\nNhấn \"+ Thêm đồ\" để bắt đầu theo dõi!';

  @override
  String get noItemsMatchFilters => 'Không có vật phẩm nào khớp với bộ lọc.';

  @override
  String get clearAllFilters => 'Xóa bộ lọc';

  @override
  String get addItem => 'Thêm đồ';

  @override
  String totalItems(int count) {
    return 'Tổng: $count món';
  }

  @override
  String get tapOwnerToFilter => 'Chạm vào chủ sở hữu để lọc nhanh danh sách.';

  @override
  String get noItemsToSummarize => 'Chưa có dữ liệu để thống kê.';

  @override
  String ownerStatsSubtitle(int expired, int soon) {
    return 'Hết hạn: $expired • Sắp hết (≤7 ngày): $soon';
  }

  @override
  String qtyLabel(int count) {
    return 'SL: $count';
  }

  @override
  String expLabel(String date) {
    return 'HSD: $date';
  }

  @override
  String get today => 'Hôm nay';

  @override
  String daysLeft(int count) {
    return 'Còn $count ngày';
  }

  @override
  String daysAgo(int count) {
    return 'Quá $count ngày';
  }

  @override
  String hoursLeft(int count) {
    return 'Còn $count giờ';
  }

  @override
  String hoursAgo(int count) {
    return 'Quá $count giờ';
  }

  @override
  String minutesLeft(int count) {
    return 'Còn $count phút';
  }

  @override
  String minutesAgo(int count) {
    return 'Quá $count phút';
  }

  @override
  String get editItem => 'Sửa vật phẩm';

  @override
  String get addNewItem => 'Thêm vật phẩm mới';

  @override
  String get saveChanges => 'Lưu thay đổi';

  @override
  String get delete => 'Xóa';

  @override
  String get cancel => 'Hủy';

  @override
  String get add => 'Thêm';

  @override
  String get addPhoto => 'Thêm ảnh';

  @override
  String get takePhoto => 'Chụp ảnh mới';

  @override
  String get chooseFromGallery => 'Chọn từ thư viện';

  @override
  String get removePhoto => 'Xóa ảnh';

  @override
  String get itemNameLabel => 'Tên vật phẩm *';

  @override
  String get itemNameHint => 'VD: Serum Vitamin C, Sữa tươi';

  @override
  String get itemNameError => 'Vui lòng nhập tên vật phẩm';

  @override
  String get categoryLabel => 'Danh mục *';

  @override
  String get quantityLabel => 'Số lượng';

  @override
  String get expiryDateLabel => 'Ngày hết hạn *';

  @override
  String get tapToSelectDate => 'Chạm để chọn ngày';

  @override
  String get selectExpiryDateError => 'Vui lòng chọn ngày hết hạn.';

  @override
  String get paoSectionTitle => 'Hạn sau mở nắp - PAO (Tùy chọn)';

  @override
  String get paoValueLabel => 'Thời hạn PAO';

  @override
  String get unitLabel => 'Đơn vị';

  @override
  String get unitMonths => 'Tháng';

  @override
  String get unitDays => 'Ngày';

  @override
  String get unitHours => 'Giờ';

  @override
  String get openedDateBtn => 'Ngày mở nắp';

  @override
  String get timeBtn => 'Giờ';

  @override
  String get clearOpenedDate => 'Xóa ngày mở nắp';

  @override
  String get ownerSectionTitle => 'Chủ sở hữu (Tùy chọn)';

  @override
  String get newOwner => 'Thêm người';

  @override
  String get addNewOwnerTitle => 'Thêm chủ sở hữu mới';

  @override
  String get addNewOwnerHint => 'VD: Mẹ, Bố, Bé';

  @override
  String get locationSectionTitle => 'Vị trí cất giữ (Tùy chọn)';

  @override
  String get newLocation => 'Thêm vị trí';

  @override
  String get addNewLocationTitle => 'Thêm vị trí mới';

  @override
  String get addNewLocationHint => 'VD: Kệ bếp, Phòng ngủ';

  @override
  String get alertsSectionTitle => 'Thông báo tùy chọn & Lịch điện thoại';

  @override
  String get alertsSectionHint =>
      'Nhập thời gian nhắc trước khi hết hạn rồi bấm +. Tick \"Thêm vào Lịch\" để tự đồng bộ.';

  @override
  String get beforeLabel => 'Trước';

  @override
  String get addAlertTooltip => 'Thêm mốc nhắc';

  @override
  String get noAlertsSet => 'Chưa cài đặt mốc nhắc nào.';

  @override
  String get addToCalendar => 'Thêm vào Lịch';

  @override
  String get removeAlertTooltip => 'Xóa mốc nhắc';

  @override
  String get invalidPositiveNumber => 'Vui lòng nhập số dương hợp lệ.';

  @override
  String get alertAlreadyExists => 'Mốc thông báo này đã tồn tại.';

  @override
  String hoursBeforeLabel(int count) {
    return 'Trước $count giờ';
  }

  @override
  String daysBeforeLabel(int count) {
    return 'Trước $count ngày';
  }

  @override
  String get notesSectionTitle => 'Ghi chú (Tùy chọn)';

  @override
  String get notesHint => 'Cách bảo quản, liều dùng, nơi mua...';

  @override
  String get deleteItemTitle => 'Xóa vật phẩm?';

  @override
  String deleteItemConfirm(String name) {
    return 'Xóa \"$name\" khỏi danh sách của bạn?';
  }

  @override
  String get appActivityLogs => 'Nhật ký hoạt động';

  @override
  String get sendTestNotification => 'Gửi thông báo thử';

  @override
  String get testNotificationSent => 'Đã gửi thông báo thử!';

  @override
  String get clearLogs => 'Xóa nhật ký';

  @override
  String get clearLogsTitle => 'Xóa toàn bộ nhật ký?';

  @override
  String get clearLogsConfirm =>
      'Thao tác này sẽ xóa sạch toàn bộ lịch sử hoạt động.';

  @override
  String get clear => 'Xóa sạch';

  @override
  String get noLogsYet => 'Chưa có nhật ký hoạt động nào.';

  @override
  String noActionLogsFound(String action) {
    return 'Không tìm thấy nhật ký nhóm \"$action\".';
  }

  @override
  String get logActionAdd => 'Thêm';

  @override
  String get logActionUpdate => 'Cập nhật';

  @override
  String get logActionDelete => 'Xóa';

  @override
  String get logActionNotify => 'Thông báo';

  @override
  String get logActionCalendar => 'Lịch';

  @override
  String get logActionBackup => 'Sao lưu';

  @override
  String get logActionError => 'Lỗi';

  @override
  String logItemAdded(String name, String category) {
    return 'Đã thêm \"$name\" ($category).';
  }

  @override
  String logItemUpdated(String name) {
    return 'Đã cập nhật \"$name\".';
  }

  @override
  String logItemDeleted(String name) {
    return 'Đã xóa \"$name\".';
  }

  @override
  String get logTestNotifySent => 'Đã gửi thông báo thử.';

  @override
  String logRemindersScheduled(int count, String name) {
    return 'Đã đặt $count nhắc nhở cho \"$name\".';
  }

  @override
  String get logCalendarDenied => 'Người dùng đã từ chối quyền truy cập Lịch.';

  @override
  String get logCalendarNoAccount =>
      'Không tìm thấy tài khoản Lịch trên thiết bị.';

  @override
  String get logCalendarNoWritable =>
      'Không tìm thấy Lịch khả dụng để ghi (cả Lịch mặc định và Google Calendar đều không khả dụng).';

  @override
  String logCalendarSkippedPast(String alert, String name) {
    return 'Đã bỏ qua nhắc nhở Lịch quá hạn ($alert) cho \"$name\".';
  }

  @override
  String logCalendarAdded(String name, String alert) {
    return 'Đã thêm sự kiện Lịch cho \"$name\" ($alert).';
  }

  @override
  String logCalendarFailed(String name) {
    return 'Không thể thêm sự kiện Lịch cho \"$name\".';
  }

  @override
  String logCalendarRemoved(int count, String name) {
    return 'Đã xóa $count sự kiện Lịch của \"$name\".';
  }

  @override
  String logBackupExported(int count, String fileName) {
    return 'Đã xuất $count vật phẩm ra file $fileName.';
  }

  @override
  String get logRestoreInvalid =>
      'Khôi phục thất bại: Định dạng file sao lưu không hợp lệ.';

  @override
  String logBackupRestored(int count) {
    return 'Đã khôi phục $count vật phẩm từ file sao lưu.';
  }

  @override
  String get languageSection => 'Ngôn ngữ';

  @override
  String get languageTitle => 'Ngôn ngữ ứng dụng';

  @override
  String get languageSystem => 'Theo điện thoại';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get dataAndBackup => 'Dữ liệu & Sao lưu';

  @override
  String get backupData => 'Sao lưu dữ liệu';

  @override
  String get backupSubtitle =>
      'Xuất toàn bộ vật phẩm & ảnh ra file .json để lưu vào Google Drive hoặc máy';

  @override
  String get restoreData => 'Khôi phục dữ liệu';

  @override
  String get restoreSubtitle =>
      'Nhập lại file sao lưu .json và tự động đặt lại thông báo';

  @override
  String backupReady(int count) {
    return 'File sao lưu đã sẵn sàng ($count món).';
  }

  @override
  String backupFailed(String error) {
    return 'Sao lưu thất bại: $error';
  }

  @override
  String get restoreDialogTitle => 'Khôi phục từ bản sao lưu?';

  @override
  String get restoreDialogContent =>
      'Toàn bộ dữ liệu hiện tại trên máy sẽ được thay thế bằng dữ liệu trong file sao lưu.';

  @override
  String get chooseFile => 'Chọn file';

  @override
  String restoreSuccess(int count) {
    return 'Đã khôi phục thành công $count vật phẩm!';
  }

  @override
  String get restoreError =>
      'Không thể khôi phục: Vui lòng chọn đúng file sao lưu .json của MinExpiryTracker.';

  @override
  String get aboutSection => 'Thông tin ứng dụng';

  @override
  String get versionSubtitle => 'Phiên bản 1.0.0 • Chế độ Offline';
}
