import '../models/item_model.dart';

// Nơi tập trung toàn bộ các giá trị cố định dùng chung trong toàn ứng dụng
// Giúp chỉnh sửa 1 chỗ là đồng bộ mọi màn hình, tránh gõ lệch chính tả
class AppConstants {
  // Constructor riêng tư: ngăn không cho tạo đối tượng thừa, chỉ gọi trực tiếp qua AppConstants.tenBien
  AppConstants._();

  // Các khóa đặc biệt dùng trong bộ lọc
  static const String filterAll = 'All';
  static const String ownerUnassigned = 'Unassigned';
  static const String locationNone = 'No Location';

  // Danh mục chuẩn lưu trong SQLite
  static const List<String> defaultCategories = [
    'Medicine',
    'Cosmetics',
    'Food',
    'Other',
  ];

  // Danh mục hiển thị trên thanh lọc của màn hình chính (thêm 'All' ở đầu)
  static const List<String> filterCategories = [
    filterAll,
    ...defaultCategories,
  ];

  // Các gợi ý mặc định cho Chủ sở hữu và Vị trí
  static const List<String> defaultOwners = ['Me', 'Family'];
  static const List<String> defaultLocations = [
    'Fridge',
    'Medicine Box',
    'Bathroom',
  ];

  // Danh sách nhóm hành động trên thanh lọc màn hình Nhật ký
  static const List<String> logActionFilters = [
    filterAll,
    'ADD',
    'UPDATE',
    'DELETE',
    'NOTIFY',
    'CALENDAR',
    'BACKUP',
    'ERROR',
  ];

  // Các mốc cảnh báo mặc định khi thêm vật phẩm mới
  static const List<AlertMilestone> defaultAlerts = [
    AlertMilestone(value: 30, unit: 'days'),
    AlertMilestone(value: 7, unit: 'days'),
  ];
}